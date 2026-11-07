"""Behavior tests: real MCP stdio subprocess and a fake authenticated TCP editor."""

import json
from pathlib import Path
import queue
import socket
import subprocess
import sys
import tempfile
import threading
import time
import unittest

import unfair_mcp_bridge as bridge

TOKEN = "test-only-editor-secret-never-print-7ad3"
TOOLS = [{"name": "files.read", "description": "Read project text", "inputSchema": {"type": "object", "properties": {"path": {"type": "string"}}}, "annotations": {"readOnlyHint": True, "destructiveHint": False, "openWorldHint": False}}]


class FakeEditor:
    def __init__(self, handler=None, token=TOKEN):
        self.handler = handler
        self.token = token
        self.requests = []
        self.connections = 0
        self.disconnected = threading.Event()
        self.stopped = threading.Event()
        self.listener = socket.socket()
        self.listener.bind(("127.0.0.1", 0))
        self.listener.listen()
        self.listener.settimeout(0.1)
        self.port = self.listener.getsockname()[1]
        self.clients = []
        self.thread = threading.Thread(target=self.serve, daemon=True)
        self.thread.start()

    def serve(self):
        while not self.stopped.is_set():
            try:
                connection, _ = self.listener.accept()
            except socket.timeout:
                continue
            except OSError:
                break
            self.clients.append(connection)
            self.connections += 1
            with connection:
                stream = connection.makefile("rb")
                try:
                    while not self.stopped.is_set():
                        raw = stream.readline(bridge.MAX_MESSAGE_BYTES + 4096)
                        if not raw:
                            self.disconnected.set()
                            break
                        request = json.loads(raw)
                        self.requests.append(request)
                        if request.get("token") != self.token:
                            response = {"id": request["id"], "error": {"code": -32001, "message": "Invalid token " + str(request.get("token"))}}
                        elif self.handler:
                            response = self.handler(request)
                        else:
                            response = None
                        if response == "disconnect":
                            break
                        if response == "timeout":
                            time.sleep(0.45)
                            break
                        if response is None:
                            result = {"connected": True}
                            if request["method"] == "catalog":
                                result = {"tools": TOOLS}
                            elif request["method"] == "call":
                                result = {"content": [{"type": "text", "text": "สวัสดี Unfair"}], "isError": False}
                            response = {"id": request["id"], "result": result}
                        connection.sendall(response if isinstance(response, bytes) else bridge.encode_message(response))
                except (ConnectionError, OSError, ValueError):
                    pass
                finally:
                    stream.close()

    def close(self):
        self.stopped.set()
        self.listener.close()
        for client in self.clients:
            try:
                client.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass
        self.thread.join(2)


class Client:
    def __init__(self, config, extra=()):
        self.process = subprocess.Popen([sys.executable, "-X", "utf8", str(Path(bridge.__file__).resolve()), "--config", str(config), *extra], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.lines = queue.Queue()
        self.raw_output = []

        def read():
            for raw in self.process.stdout:
                self.raw_output.append(raw)
                self.lines.put(raw)

        self.reader = threading.Thread(target=read, daemon=True)
        self.reader.start()

    def send(self, method, params=None, request_id=1):
        request = {"jsonrpc": "2.0", "method": method}
        if params is not None:
            request["params"] = params
        if request_id is not None:
            request["id"] = request_id
        self.raw(bridge.encode_message(request))

    def raw(self, raw):
        self.process.stdin.write(raw)
        self.process.stdin.flush()

    def receive(self):
        try:
            raw = self.lines.get(timeout=4)
        except queue.Empty:
            raise AssertionError("No MCP response; subprocess status=" + str(self.process.poll())) from None
        value = json.loads(raw.decode("utf-8"))
        assert value["jsonrpc"] == "2.0", value
        return value

    def initialize(self, version=bridge.PROTOCOL_VERSION):
        self.send("initialize", {"protocolVersion": version, "capabilities": {}, "clientInfo": {"name": "Test MCP Client", "version": "1.2"}})
        response = self.receive()
        self.send("notifications/initialized", request_id=None)
        return response

    def close(self):
        if self.process.poll() is None:
            self.process.stdin.close()
            try:
                self.process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait(timeout=2)
        self.reader.join(2)
        stderr = self.process.stderr.read().decode("utf-8")
        self.process.stdout.close()
        self.process.stderr.close()
        return stderr


class BridgeIntegrationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="unfair-mcp-test-")
        self.root = Path(self.temp.name)
        self.config = self.root / "connection.json"
        self.editors = []
        self.clients = []

    def tearDown(self):
        for client in self.clients:
            client.close()
        for editor in self.editors:
            editor.close()
        self.temp.cleanup()

    def editor(self, handler=None, token=TOKEN):
        editor = FakeEditor(handler, token)
        self.editors.append(editor)
        self.config.write_text(json.dumps({"host": "127.0.0.1", "port": editor.port, "token": token, "project_root": str(self.root)}), encoding="utf-8")
        return editor

    def client(self, extra=()):
        client = Client(self.config, extra)
        self.clients.append(client)
        return client

    def test_full_handshake_catalog_call_ping_persistent_and_eof(self):
        editor = self.editor()
        client = self.client(("--provider", "local-test", "--model", "unverified", "--agent-name", "helper"))
        result = client.initialize("unsupported-version")["result"]
        self.assertEqual(result["protocolVersion"], bridge.PROTOCOL_VERSION)
        self.assertEqual(result["capabilities"], {"tools": {}})
        client.send("tools/list", request_id="list")
        self.assertEqual(client.receive()["result"]["tools"], TOOLS)
        client.send("tools/call", {"name": "files.read", "arguments": {"path": "test.gd"}}, request_id=3)
        self.assertEqual(client.receive()["result"]["content"][0]["text"], "สวัสดี Unfair")
        client.send("ping", request_id=4)
        self.assertEqual(client.receive()["result"], {})
        self.assertEqual(editor.connections, 1)
        self.assertEqual([r["method"] for r in editor.requests], ["connect", "catalog", "call", "ping"])
        self.assertEqual(editor.requests[0]["params"]["clientInfo"]["name"], "Test MCP Client")
        self.assertEqual(editor.requests[0]["params"]["agent"]["model"], "unverified")
        self.assertEqual(client.close(), "")
        self.clients.remove(client)
        self.assertTrue(editor.disconnected.wait(2), "Editor session should end when MCP stdin closes")

    def test_state_machine_and_invalid_requests_do_not_connect(self):
        editor = self.editor()
        client = self.client()
        client.send("tools/list")
        self.assertEqual(client.receive()["error"]["code"], -32002)
        client.send("initialize", {})
        self.assertEqual(client.receive()["error"]["code"], -32602)
        client.send("initialize", {"protocolVersion": bridge.PROTOCOL_VERSION, "capabilities": {}, "clientInfo": {"name": "x", "version": "1"}})
        self.assertIn("result", client.receive())
        client.send("tools/list")
        self.assertEqual(client.receive()["error"]["code"], -32002)
        self.assertEqual(editor.connections, 0)
        client.send("notifications/initialized", request_id=None)
        client.send("initialize", {})
        self.assertEqual(client.receive()["error"]["code"], -32600)
        client.send("unknown")
        self.assertEqual(client.receive()["error"]["code"], -32601)
        client.send("tools/call", {"name": "files.read", "arguments": []})
        self.assertEqual(client.receive()["error"]["code"], -32602)
        client.send("tools/list", {"cursor": "next"})
        self.assertEqual(client.receive()["error"]["code"], -32602)
        client.raw(b"[]\n{bad json}\n")
        self.assertEqual(client.receive()["error"]["code"], -32600)
        self.assertEqual(client.receive()["error"]["code"], -32700)

    def test_disconnect_not_replayed_and_new_request_reloads_config(self):
        def disconnect_call(request):
            return "disconnect" if request["method"] == "call" else None

        first = self.editor(disconnect_call)
        client = self.client()
        client.initialize()
        client.send("tools/call", {"name": "files.read", "arguments": {}})
        self.assertTrue(client.receive()["result"]["isError"])
        self.assertEqual(len([r for r in first.requests if r["method"] == "call"]), 1)
        second = self.editor(token="rotated-local-test-token")
        client.send("tools/list", request_id=8)
        self.assertEqual(client.receive()["result"]["tools"], TOOLS)
        self.assertEqual(second.requests[0]["method"], "connect")
        self.assertEqual(second.requests[0]["token"], "rotated-local-test-token")

    def test_token_redaction_on_native_error_and_tool_content(self):
        def response(request):
            if request["method"] == "catalog":
                return {"id": request["id"], "error": {"code": -32001, "message": "Do not expose " + TOKEN}}
            if request["method"] == "call":
                return {"id": request["id"], "result": {"content": [{"type": "text", "text": TOKEN}]}}
            return None

        self.editor(response)
        client = self.client()
        client.initialize()
        client.send("tools/list")
        self.assertIn("[redacted]", client.receive()["error"]["message"])
        client.send("tools/call", {"name": "files.read"})
        self.assertEqual(client.receive()["result"]["content"][0]["text"], "[redacted]")
        errors = client.close()
        self.clients.remove(client)
        self.assertNotIn(TOKEN, errors + b"".join(client.raw_output).decode("utf-8"))

    def test_remote_host_and_missing_token_are_rejected(self):
        editor = self.editor()
        config = json.loads(self.config.read_text())
        for invalid in ({"host": "example.com"}, {"token": ""}, {"port": True}, {"project_root": "relative"}):
            self.config.write_text(json.dumps({**config, **invalid}), encoding="utf-8")
            client = self.client()
            client.initialize()
            client.send("tools/call", {"name": "project.overview"})
            self.assertTrue(client.receive()["result"]["isError"])
            errors = client.close()
            self.clients.remove(client)
            self.assertNotIn(TOKEN, errors)
        self.assertEqual(editor.connections, 0)

    def test_input_limit_and_malformed_json_preserve_stdio_framing(self):
        client = self.client()
        client.raw(b"x" * (bridge.MAX_MESSAGE_BYTES + 10) + b"\n")
        self.assertEqual(client.receive()["error"]["code"], -32700)
        client.raw(b'{"jsonrpc":"2.0","id":1,"method":"ping","params":{"bad":NaN}}\n')
        self.assertEqual(client.receive()["error"]["code"], -32700)
        client.send("ping", request_id=12)
        self.assertEqual(client.receive()["id"], 12)

    def test_config_limit_and_identifier_limit_are_enforced(self):
        editor = self.editor()
        self.config.write_bytes(b"x" * (bridge.MAX_CONFIG_BYTES + 1))
        client = self.client()
        client.initialize()
        client.send("tools/call", {"name": "project.overview"})
        self.assertTrue(client.receive()["result"]["isError"])
        self.assertEqual(editor.connections, 0)
        client.send("ping", request_id="x" * 2048)
        response = client.receive()
        self.assertEqual(response["error"]["code"], -32600)
        self.assertIsNone(response["id"])

    def test_invalid_catalog_and_call_payload_do_not_escape_as_valid_results(self):
        def response(request):
            if request["method"] == "catalog":
                return {"id": request["id"], "result": {"tools": [{"name": "broken"}]}}
            if request["method"] == "call":
                return {"id": request["id"], "result": {"content": "not an array"}}
            return None

        self.editor(response)
        client = self.client()
        client.initialize()
        client.send("tools/list")
        self.assertEqual(client.receive()["error"]["code"], -32603)
        client.send("tools/call", {"name": "files.read"})
        self.assertTrue(client.receive()["result"]["isError"])

    def test_oversized_native_response_is_bounded_tool_failure(self):
        def response(request):
            if request["method"] == "call":
                return bridge.encode_message({"id": request["id"], "result": {"content": [{"type": "text", "text": "x" * bridge.MAX_MESSAGE_BYTES}]}})
            return None

        self.editor(response)
        client = self.client()
        client.initialize()
        client.send("tools/call", {"name": "files.read"})
        result = client.receive()["result"]
        self.assertTrue(result["isError"])
        self.assertIn("size limit", result["content"][0]["text"])
        self.assertTrue(all(len(raw) <= bridge.MAX_MESSAGE_BYTES for raw in client.raw_output))

    def test_wrong_id_malformed_native_json_and_timeout(self):
        cases = (lambda r: {"id": 999, "result": {}}, lambda r: b"not-json\n", lambda r: "timeout")
        for behavior in cases:
            def response(request):
                return behavior(request) if request["method"] == "call" else None

            self.editor(response)
            client = self.client(("--timeout", "0.1"))
            client.initialize()
            client.send("tools/call", {"name": "files.read"})
            self.assertTrue(client.receive()["result"]["isError"])
            client.close()
            self.clients.remove(client)

    def test_native_tool_errors_remain_tool_errors(self):
        def response(request):
            if request["method"] == "call":
                return {"id": request["id"], "result": {"isError": True, "content": [{"type": "text", "text": "File is outside the project."}]}}
            return None

        self.editor(response)
        client = self.client()
        client.initialize()
        client.send("tools/call", {"name": "files.read", "arguments": {"path": "../private"}})
        result = client.receive()
        self.assertNotIn("error", result)
        self.assertTrue(result["result"]["isError"])


if __name__ == "__main__":
    unittest.main()
