#!/usr/bin/env python3
"""Native GUI-QA helper. Keep a real MCP session alive until the capture release signal."""

import argparse
import json
import os
from pathlib import Path
import queue
import socket
import subprocess
import sys
import threading
import time

sys.path.insert(0, str(Path(__file__).resolve().parent))
import unfair_mcp_bridge as bridge

EXPECTED_TOOLS = {"project.overview", "scene.inspect", "editor.selection", "files.search", "files.read", "tools.search"}


class NativeQA:
    def __init__(self, args):
        self.args = args
        self.failures = []
        self.cases = []
        self.token = ""
        self.config = {}
        self.process = None
        self.stdout_lines = queue.Queue()
        self.stdout_messages = []
        self.stderr_chunks = []
        self.readers = []
        self.next_id = 0
        self.tool_calls = 0
        self.tool_errors = 0
        self.tool_names = []
        self.max_message_bytes = 0
        self.released = False

    def clean(self, value):
        if isinstance(value, str):
            return value.replace(self.token, "[redacted]") if self.token else value
        if isinstance(value, list):
            return [self.clean(item) for item in value]
        if isinstance(value, dict):
            return {self.clean(key): self.clean(item) for key, item in value.items()}
        return value

    def report(self, **extra):
        return self.clean({"pass": not self.failures, "failures": list(self.failures), "cases": list(self.cases), "client": "Unfair QA client", "provider": "QA", "model": "test-fixture", "identity_verified": False, "stats": {"mcp_requests": self.next_id, "tool_calls": self.tool_calls, "expected_tool_errors": self.tool_errors, "stdout_message_count": len(self.stdout_messages), "max_stdout_message_bytes": self.max_message_bytes}, "tools": self.tool_names, **extra})

    def write(self, target, value):
        target = Path(target)
        target.parent.mkdir(parents=True, exist_ok=True)
        encoded = json.dumps(self.clean(value), ensure_ascii=False, indent=2, allow_nan=False)
        if self.token and self.token in encoded:
            raise AssertionError("Authentication token escaped result redaction.")
        temporary = target.with_name(target.name + ".tmp")
        temporary.write_text(encoded, encoding="utf-8")
        temporary.replace(target)

    def check(self, condition, message):
        if not condition:
            raise AssertionError(message)

    def case(self, name, operation):
        try:
            operation()
            self.cases.append({"name": name, "pass": True})
        except Exception as error:
            # Never copy raw native messages, process arguments, or configuration into reports.
            detail = str(error) if isinstance(error, AssertionError) else type(error).__name__
            self.failures.append(self.clean(name + ": " + detail))
            self.cases.append({"name": name, "pass": False})

    def start(self):
        loader = bridge.EditorConnection(self.args.config, {})
        self.config = loader._load_config()
        self.token = self.config["token"]
        self.process = subprocess.Popen([sys.executable, "-X", "utf8", str(Path(__file__).with_name("unfair_mcp_bridge.py").resolve()), "--config", str(self.args.config), "--provider", "QA", "--model", "test-fixture", "--agent-name", "Unfair QA client"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

        def read_stdout():
            while True:
                raw = self.process.stdout.readline(bridge.MAX_MESSAGE_BYTES + 1)
                if not raw:
                    self.stdout_lines.put(None)
                    break
                self.stdout_messages.append(raw)
                self.max_message_bytes = max(self.max_message_bytes, len(raw))
                self.stdout_lines.put(raw)

        def read_stderr():
            while True:
                raw = self.process.stderr.read(4096)
                if not raw:
                    break
                if sum(map(len, self.stderr_chunks)) < 65536:
                    self.stderr_chunks.append(raw)

        self.readers = [threading.Thread(target=read_stdout, daemon=True), threading.Thread(target=read_stderr, daemon=True)]
        for reader in self.readers:
            reader.start()
        result = self.request("initialize", {"protocolVersion": bridge.PROTOCOL_VERSION, "capabilities": {}, "clientInfo": {"name": "Unfair QA client", "version": "1"}})
        self.check(result.get("protocolVersion") == bridge.PROTOCOL_VERSION, "Unexpected MCP protocol version.")
        self.check(result.get("capabilities") == {"tools": {}}, "Unexpected MCP capabilities.")
        self.send({"jsonrpc": "2.0", "method": "notifications/initialized"})

    def send(self, value):
        self.process.stdin.write(bridge.encode_message(value))
        self.process.stdin.flush()

    def request(self, method, params=None):
        self.next_id += 1
        expected_id = self.next_id
        self.send({"jsonrpc": "2.0", "id": expected_id, "method": method, "params": params or {}})
        try:
            raw = self.stdout_lines.get(timeout=15)
        except queue.Empty:
            raise AssertionError("MCP response timed out.") from None
        self.check(raw is not None, "MCP subprocess closed its output unexpectedly.")
        self.check(len(raw) <= bridge.MAX_MESSAGE_BYTES and raw.endswith(b"\n"), "MCP output size/framing limit was violated.")
        self.check(self.token.encode("utf-8") not in raw, "MCP output contained the authentication token.")
        response = bridge.decode_message(raw)
        self.check(isinstance(response, dict) and response.get("jsonrpc") == "2.0" and response.get("id") == expected_id, "MCP response envelope or request identifier was invalid.")
        self.check("error" not in response and "result" in response, "MCP request returned a protocol error.")
        return response["result"]

    def call(self, name, arguments=None, expected_error=False):
        self.tool_calls += 1
        result = self.request("tools/call", {"name": name, "arguments": arguments or {}})
        self.check(isinstance(result, dict) and isinstance(result.get("content"), list), "Tool response has no MCP content array.")
        failed = result.get("isError", False)
        self.check(isinstance(failed, bool) and failed == expected_error, "Tool error status did not match the expected result.")
        if failed:
            self.tool_errors += 1
        data = result.get("structuredContent")
        if data is None:
            blocks = [item for item in result["content"] if isinstance(item, dict) and item.get("type") == "text"]
            self.check(bool(blocks), "Tool response has neither structured content nor text.")
            data = json.loads(blocks[0]["text"])
        self.check(isinstance(data, dict), "Native tool content is not a JSON object.")
        return data

    def catalog(self):
        result = self.request("tools/list")
        self.check(isinstance(result, dict) and isinstance(result.get("tools"), list), "Native catalog is invalid.")
        tools = result["tools"]
        self.tool_names = sorted(item.get("name", "") for item in tools)
        self.check(set(self.tool_names) == EXPECTED_TOOLS and len(tools) == 6, "Expected exactly the six read-only native tools.")
        for tool in tools:
            self.check(isinstance(tool.get("inputSchema"), dict), "Tool input schema missing.")
            annotation = tool.get("annotations", {})
            self.check(annotation.get("readOnlyHint") is True and annotation.get("destructiveHint") is False, "Read-only annotations missing or changed.")

    def overview(self):
        data = self.call("project.overview")
        self.check(data.get("read_only") is True and data.get("path") == "res://", "Project overview boundaries are incorrect.")
        self.check(isinstance(data.get("engine"), dict) and isinstance(data.get("open_scenes"), list), "Project overview shape is incorrect.")

    def selection(self):
        data = self.call("editor.selection")
        self.check(isinstance(data.get("nodes"), list) and len(data["nodes"]) <= 256, "Editor selection result is invalid or unbounded.")

    def scene(self):
        data = self.call("scene.inspect", {"path": ".", "limit": 16})
        self.check(isinstance(data.get("nodes"), list) and len(data["nodes"]) <= 16, "Scene inspect result is invalid or unbounded.")
        for node in data["nodes"]:
            self.check(isinstance(node.get("name"), str) and isinstance(node.get("type"), str), "Scene node metadata is missing.")

    def search(self):
        data = self.call("files.search", {"query": "smoke", "limit": 20})
        self.check(isinstance(data.get("files"), list) and len(data["files"]) <= 20, "File search result is invalid or unbounded.")
        self.check(any(item.get("path") == "res://smoke.gd" for item in data["files"]), "Cached search did not find the smoke.gd fixture.")
        self.check(all(str(item.get("path", "")).startswith("res://") for item in data["files"]), "Search exposed an outside-project path.")

    def read(self):
        data = self.call("files.read", {"path": "res://smoke.gd", "start_line": 1, "line_count": 3})
        self.check(data.get("path") == "res://smoke.gd" and data.get("start_line") == 1, "File read selected the wrong path/range.")
        self.check(isinstance(data.get("text"), str) and len(data["text"].split("\n")) <= 3, "File read returned more than three requested lines.")
        self.check(data.get("end_line", 999) <= 3 and data["text"].startswith("extends SceneTree"), "File read did not return the expected smoke fixture prefix.")
        self.check(isinstance(data.get("revision"), str) and len(data["revision"]) == 64, "File revision is not a SHA-256 fingerprint.")

    def search_tools(self):
        data = self.call("tools.search", {"query": "files", "include_schemas": False})
        self.check(isinstance(data.get("tools"), list), "Tool search result is invalid.")
        self.check({"files.search", "files.read"}.issubset({item.get("name") for item in data["tools"]}), "Tool search omitted file tools.")
        self.check(all("inputSchema" not in item for item in data["tools"]), "Tool search ignored include_schemas=false.")

    def direct_reject(self, malformed=False):
        # Neither request uses the real token. These sockets must never register sessions.
        with socket.create_connection(("127.0.0.1", self.config["port"]), timeout=5) as connection:
            connection.settimeout(5)
            raw = b"{invalid-json}\n" if malformed else bridge.encode_message({"id": 987, "method": "connect", "params": {"clientInfo": {"name": "Invalid auth QA", "version": "1"}}, "token": "intentionally-wrong-qa-token"})
            connection.sendall(raw)
            with connection.makefile("rb") as reader:
                response_raw = reader.readline(bridge.MAX_MESSAGE_BYTES + 1)
            self.check(len(response_raw) <= bridge.MAX_MESSAGE_BYTES, "Native error response exceeds output bounds.")
            self.check(self.token.encode("utf-8") not in response_raw, "Native error exposed the authentication token.")
            response = bridge.decode_message(response_raw)
            self.check(isinstance(response, dict) and isinstance(response.get("error"), dict), "Invalid request was not rejected by native transport.")
            self.check(response["error"].get("code") == (-32700 if malformed else -32001), "Unexpected native parse/auth rejection code.")

    def tests(self):
        self.case("native catalog and read-only annotations", self.catalog)
        self.case("project overview", self.overview)
        self.case("editor selection", self.selection)
        self.case("scene inspection", self.scene)
        self.case("cached file search", self.search)
        self.case("bounded fixture read", self.read)
        self.case("schema-free tool search", self.search_tools)
        negatives = [
            ("unknown tool rejected", "tool.does_not_exist", {}),
            ("traversal rejected", "files.read", {"path": "res://../smoke.gd"}),
            ("absolute path rejected", "files.read", {"path": str(Path(self.config["project_root"]) / "smoke.gd")}),
            ("editor private path rejected", "files.read", {"path": "res://.godot/editor/unfair_ai/connection.json"}),
            ("environment file rejected", "files.read", {"path": "res://.env"}),
            ("invalid line type rejected", "files.read", {"path": "res://smoke.gd", "line_count": "3"}),
            ("fractional line count rejected", "files.read", {"path": "res://smoke.gd", "line_count": 1.5}),
            ("boolean line count rejected", "files.read", {"path": "res://smoke.gd", "line_count": True}),
            ("huge line count rejected", "files.read", {"path": "res://smoke.gd", "line_count": 1000000000}),
            ("zero start line rejected", "files.read", {"path": "res://smoke.gd", "start_line": 0}),
            ("huge scene limit rejected", "scene.inspect", {"limit": 1000000000}),
            ("huge search limit rejected", "files.search", {"query": "smoke", "limit": 1000000000}),
        ]
        for label, name, arguments in negatives:
            self.case(label, lambda name=name, arguments=arguments: self.call(name, arguments, expected_error=True))
        self.case("native wrong-token rejection", self.direct_reject)
        self.case("native malformed JSON rejection", lambda: self.direct_reject(malformed=True))
        self.case("persistent session ping", lambda: self.check(self.request("ping") == {}, "MCP ping response is invalid."))
        self.case("successful queries recover after rejected requests", lambda: (self.overview(), self.read(), self.scene(), self.search_tools()))

    def wait_release(self):
        self.write(self.args.ready, self.report(stage="connected-for-ui-capture", subprocess_alive=self.process is not None and self.process.poll() is None))
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            if Path(self.args.release).is_file():
                self.released = True
                return
            if self.process is not None and self.process.poll() is not None:
                self.failures.append("MCP subprocess exited before the UI capture release signal.")
                return
            time.sleep(0.1)
        self.failures.append("UI capture release signal did not arrive within 30 seconds.")

    def close(self):
        if self.process:
            if self.process.poll() is None:
                self.process.stdin.close()
                try:
                    self.process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    self.failures.append("MCP subprocess did not stop cleanly after stdin EOF.")
                    self.process.kill()
                    self.process.wait(timeout=3)
            if self.process.returncode != 0:
                self.failures.append("MCP subprocess returned a nonzero exit code.")
            for reader in self.readers:
                reader.join(timeout=2)
            if self.token:
                secret = self.token.encode("utf-8")
                if any(secret in part for part in self.stdout_messages + self.stderr_chunks):
                    self.failures.append("Subprocess output contained the authentication token.")
            self.process.stdout.close()
            self.process.stderr.close()

    def run(self):
        try:
            self.start()
            self.tests()
            self.wait_release()
        except Exception as error:
            detail = str(error) if isinstance(error, AssertionError) else type(error).__name__
            self.failures.append(self.clean("Native integration harness: " + detail))
            self.write(self.args.ready, self.report(stage="failed-before-capture", subprocess_alive=False))
        finally:
            self.close()
            self.write(self.args.output, self.report(stage="closed-after-eof", released=self.released, subprocess_exit_code=self.process.returncode if self.process else None))
        return 0 if not self.failures else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for argument in ("config", "output", "ready", "release"):
        parser.add_argument("--" + argument, required=True, type=Path)
    args = parser.parse_args()
    for argument in ("config", "output", "ready", "release"):
        if not os.path.isabs(getattr(args, argument)):
            parser.error("--" + argument + " must be absolute")
    return NativeQA(args).run()


if __name__ == "__main__":
    sys.exit(main())
