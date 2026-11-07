#!/usr/bin/env python3
"""MCP stdio adapter for the authenticated, loopback-only Unfair editor bridge."""

import argparse
import json
import math
import os
from pathlib import Path
import socket
import sys

PROTOCOL_VERSION = "2025-11-25"
MAX_MESSAGE_BYTES = 1024 * 1024
MAX_CONFIG_BYTES = 64 * 1024
DEFAULT_TIMEOUT = 10.0


class BridgeError(Exception):
    """An operational failure with a deliberately non-secret message."""


def encode_message(value):
    return json.dumps(value, ensure_ascii=False, allow_nan=False, separators=(",", ":")).encode("utf-8") + b"\n"


def decode_message(raw):
    def reject_constant(_value):
        raise ValueError("Non-finite JSON number")

    return json.loads(raw.decode("utf-8"), parse_constant=reject_constant)


class EditorConnection:
    def __init__(self, config_path, client_info, agent=None, timeout=DEFAULT_TIMEOUT):
        self.config_path = Path(config_path)
        self.client_info = client_info
        self.agent = agent or {}
        self.timeout = timeout
        self.socket = None
        self.reader = None
        self.request_id = 0
        self.known_tokens = set()

    def redact(self, value):
        if isinstance(value, str):
            for token in self.known_tokens:
                value = value.replace(token, "[redacted]")
            return value
        if isinstance(value, list):
            return [self.redact(item) for item in value]
        if isinstance(value, dict):
            return {self.redact(key): self.redact(item) for key, item in value.items()}
        return value

    def close(self):
        if self.reader is not None:
            self.reader.close()
        if self.socket is not None:
            self.socket.close()
        self.reader = None
        self.socket = None

    def _load_config(self):
        try:
            with self.config_path.open("rb") as stream:
                raw = stream.read(MAX_CONFIG_BYTES + 1)
            if len(raw) > MAX_CONFIG_BYTES:
                raise BridgeError("Editor connection configuration is too large.")
            config = decode_message(raw)
        except (OSError, ValueError, UnicodeError, RecursionError):
            raise BridgeError("Cannot read a valid editor connection configuration.") from None
        if not isinstance(config, dict):
            raise BridgeError("Editor connection configuration must be an object.")
        token = config.get("token")
        if isinstance(token, str) and token:
            self.known_tokens.add(token)
        if config.get("host") != "127.0.0.1":
            raise BridgeError("Editor connection host must be 127.0.0.1.")
        port = config.get("port")
        if isinstance(port, bool) or not isinstance(port, int) or not 1 <= port <= 65535:
            raise BridgeError("Editor connection port is invalid.")
        if not isinstance(token, str) or not token or len(token) > 4096 or "\n" in token or "\r" in token:
            raise BridgeError("Editor connection authentication token is missing or invalid.")
        root = config.get("project_root")
        if not isinstance(root, str) or not root or not os.path.isabs(root):
            raise BridgeError("Editor connection project_root must be absolute.")
        return config

    def connect(self):
        if self.socket is not None:
            return
        config = self._load_config()
        self.token = config["token"]
        try:
            self.socket = socket.create_connection(("127.0.0.1", config["port"]), self.timeout)
            self.socket.settimeout(self.timeout)
            self.reader = self.socket.makefile("rb")
            self._exchange("connect", {"clientInfo": self.client_info, "agent": self.agent})
        except (OSError, TimeoutError):
            self.close()
            raise BridgeError("Cannot connect to the local Unfair editor. Check that its AI bridge is enabled.") from None
        except BridgeError:
            self.close()
            raise

    def _exchange(self, method, params):
        self.request_id += 1
        request_id = self.request_id
        request = {"id": request_id, "method": method, "params": params, "token": self.token}
        try:
            encoded = encode_message(request)
            if len(encoded) > MAX_MESSAGE_BYTES:
                raise BridgeError("Editor request exceeds the message size limit.")
            self.socket.sendall(encoded)
            raw = self.reader.readline(MAX_MESSAGE_BYTES + 1)
            if not raw:
                raise BridgeError("The editor disconnected. The operation was not retried; retry it to reconnect.")
            if len(raw) > MAX_MESSAGE_BYTES or not raw.endswith(b"\n"):
                raise BridgeError("Editor response exceeds the message size limit or is incomplete.")
            response = decode_message(raw)
            if not isinstance(response, dict) or isinstance(response.get("id"), bool) or response.get("id") != request_id:
                raise BridgeError("Editor returned an invalid response identifier.")
            if ("result" in response) == ("error" in response):
                raise BridgeError("Editor returned an invalid response envelope.")
            if "error" in response:
                error = response["error"]
                if not isinstance(error, dict) or isinstance(error.get("code"), bool) or not isinstance(error.get("code"), int) or not isinstance(error.get("message"), str):
                    raise BridgeError("Editor returned a malformed error.")
                raise BridgeError(self.redact(error["message"])[:2048])
            return response["result"]
        except (OSError, TimeoutError):
            self.close()
            raise BridgeError("Editor communication failed. The operation was not retried; retry it to reconnect.") from None
        except (ValueError, UnicodeError, RecursionError):
            self.close()
            raise BridgeError("Editor returned malformed JSON.") from None
        except BridgeError:
            self.close()
            raise

    def request(self, method, params):
        # Reconnect only for a new client request. Never replay an interrupted operation.
        self.connect()
        return self._exchange(method, params)


class MCPServer:
    def __init__(self, config_path, agent=None, timeout=DEFAULT_TIMEOUT, output=None, errors=None):
        self.config_path = config_path
        self.agent = agent or {}
        self.timeout = timeout
        self.output = output or sys.stdout.buffer
        self.errors = errors or sys.stderr
        self.state = "new"
        self.connection = None

    def diagnostic(self, message):
        if self.connection:
            message = self.connection.redact(message)
        self.errors.write(message + "\n")
        self.errors.flush()

    def send(self, message):
        if self.connection:
            message = self.connection.redact(message)
        try:
            raw = encode_message(message)
        except (ValueError, UnicodeError, RecursionError):
            raw = b""
        if not raw or len(raw) > MAX_MESSAGE_BYTES:
            raw = encode_message({"jsonrpc": "2.0", "id": message.get("id"), "error": {"code": -32603, "message": "Response exceeds the output limit or cannot be serialized."}})
        self.output.write(raw)
        self.output.flush()

    def error(self, request_id, code, message):
        self.send({"jsonrpc": "2.0", "id": request_id, "error": {"code": code, "message": message}})

    def handle(self, message):
        if not isinstance(message, dict) or message.get("jsonrpc") != "2.0" or not isinstance(message.get("method"), str):
            self.error(None, -32600, "Invalid JSON-RPC request.")
            return
        has_id = "id" in message
        request_id = message.get("id")
        if has_id and (isinstance(request_id, bool) or not isinstance(request_id, (str, int)) or len(str(request_id)) > 1024):
            self.error(None, -32600, "Request id must be a string or integer of at most 1024 characters.")
            return
        method = message["method"]
        params = message.get("params", {})
        if not isinstance(params, dict):
            if has_id:
                self.error(request_id, -32602, "Parameters must be an object.")
            return
        if not has_id:
            if method == "notifications/initialized" and self.state == "initializing":
                self.state = "ready"
                try:
                    self.connection.connect()
                except BridgeError as error:
                    self.diagnostic(str(error))
            # Notifications, including cancellation, receive no JSON-RPC response.
            return
        if method == "initialize":
            if self.state != "new":
                self.error(request_id, -32600, "This MCP session has already been initialized.")
                return
            info = params.get("clientInfo")
            if not isinstance(params.get("protocolVersion"), str) or not isinstance(params.get("capabilities"), dict) or not isinstance(info, dict) or not isinstance(info.get("name"), str) or not isinstance(info.get("version"), str):
                self.error(request_id, -32602, "initialize requires protocolVersion, capabilities, and clientInfo name/version.")
                return
            self.connection = EditorConnection(self.config_path, info, self.agent, self.timeout)
            self.state = "initializing"
            self.send({"jsonrpc": "2.0", "id": request_id, "result": {"protocolVersion": PROTOCOL_VERSION, "capabilities": {"tools": {}}, "serverInfo": {"name": "Unfair AI Bridge", "version": "0.1.0"}, "instructions": "Read-only access to the connected Unfair project. Agent provider/model labels are client-reported and unverified."}})
            return
        if self.state != "ready":
            self.error(request_id, -32002, "Initialize the MCP session and send notifications/initialized first.")
            return
        if method == "tools/call":
            if not isinstance(params.get("name"), str) or not params["name"] or not isinstance(params.get("arguments", {}), dict):
                self.error(request_id, -32602, "tools/call requires a tool name and object arguments.")
                return
        elif method not in ("tools/list", "ping"):
            self.error(request_id, -32601, "Method not found.")
            return
        try:
            if method == "tools/list":
                if params.get("cursor"):
                    self.error(request_id, -32602, "This bridge does not paginate the tool catalog.")
                    return
                result = self.connection.request("catalog", {})
                if not isinstance(result, dict) or not isinstance(result.get("tools"), list) or not all(isinstance(tool, dict) and isinstance(tool.get("name"), str) and isinstance(tool.get("inputSchema"), dict) for tool in result["tools"]):
                    raise BridgeError("Editor returned an invalid tool catalog.")
            elif method == "tools/call":
                result = self.connection.request("call", {"name": params["name"], "arguments": params.get("arguments", {})})
                if not isinstance(result, dict) or not isinstance(result.get("content"), list):
                    raise BridgeError("Editor returned an invalid tool result.")
            else:
                self.connection.request("ping", {})
                result = {}
            self.send({"jsonrpc": "2.0", "id": request_id, "result": result})
        except BridgeError as error:
            if method == "tools/call":
                self.send({"jsonrpc": "2.0", "id": request_id, "result": {"isError": True, "content": [{"type": "text", "text": str(error)}]}})
            else:
                self.error(request_id, -32603, str(error))

    def run(self, source=None):
        source = source or sys.stdin.buffer
        try:
            while True:
                raw = source.readline(MAX_MESSAGE_BYTES + 1)
                if not raw:
                    break
                if len(raw) > MAX_MESSAGE_BYTES:
                    while raw and not raw.endswith(b"\n"):
                        raw = source.readline(MAX_MESSAGE_BYTES + 1)
                    self.error(None, -32700, "Input exceeds the message size limit.")
                    continue
                if not raw.strip():
                    continue
                try:
                    message = decode_message(raw)
                except (ValueError, UnicodeError, RecursionError):
                    self.error(None, -32700, "Invalid UTF-8 JSON.")
                    continue
                self.handle(message)
        except BrokenPipeError:
            pass
        finally:
            if self.connection:
                self.connection.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", required=True, help="Absolute editor-generated connection.json path")
    parser.add_argument("--agent-name", help="Optional self-reported agent label (not verified)")
    parser.add_argument("--provider", help="Optional self-reported provider (not verified)")
    parser.add_argument("--model", help="Optional self-reported model (not verified)")
    parser.add_argument("--timeout", type=float, default=DEFAULT_TIMEOUT, help="Local editor response timeout in seconds (0.1 to 60)")
    args = parser.parse_args()
    if not os.path.isabs(args.config):
        parser.error("--config must be an absolute path")
    if not math.isfinite(args.timeout) or not 0.1 <= args.timeout <= 60:
        parser.error("--timeout must be between 0.1 and 60 seconds")
    agent = {key: value for key, value in {"name": args.agent_name, "provider": args.provider, "model": args.model}.items() if value}
    if any(len(value) > 256 for value in agent.values()):
        parser.error("Agent labels must be at most 256 characters")
    MCPServer(args.config, agent, args.timeout).run()


if __name__ == "__main__":
    main()
