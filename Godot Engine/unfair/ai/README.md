# Unfair AI Bridge — local MCP stdio companion

This Python companion exposes the running editor's read-only AI tools to an
external MCP client. It does not contain a model, call an AI provider, send HTTP
requests, or execute project code. Python 3.9 or newer is sufficient; no pip
packages or SDKs are required. Python 3.10 or newer is recommended for the editor UI.

## Connect an MCP client

1. Open the intended project in Unfair and enable its local AI bridge.
2. Locate the editor-generated connection configuration at the absolute path
   `<project>/.godot/editor/unfair_ai/connection-<editorPID>-<instance>.json`. Use the AI Hub's
   **Copy MCP Config** action to obtain the path for the current editor instance.
   Keep this file private: it contains
   the editor's authentication token. The companion reads this file itself; do
   not paste its token into a chat or into the client configuration.
3. Configure a stdio MCP server in your client using an absolute Python executable,
   this companion script, and that connection configuration. A generic example
   for clients that accept an `mcpServers` JSON object is:

```json
{
  "mcpServers": {
    "unfair-project": {
      "command": "C:/Path/To/python.exe",
      "args": [
        "-X", "utf8",
        "A:/Game Engine/Godot Engine Remake/Godot Engine/unfair/ai/unfair_mcp_bridge.py",
        "--config", "A:/YourProject/.godot/editor/unfair_ai/connection-12345-67890.json"
      ]
    }
  }
}
```

Replace both example paths and follow your client's configuration format. Other
clients may present the same command and arguments in a settings form. This is a
stdio subprocess, not an HTTP server URL. Use the current editor PID's generated
configuration; separate editor instances have separate connection files.

The MCP handshake advertises protocol version `2025-11-25`, tool capability, and
server name `Unfair AI Bridge`. Clients that offer another version receive the
supported version and must decide whether to continue. After `initialize`, the
client must send `notifications/initialized` before requesting tools.

Optional arguments `--agent-name`, `--provider`, and `--model` supply display
labels to the editor. They are **self-reported and unverified**. The bridge also
forwards the MCP client's own `clientInfo`; it does not infer or authenticate an
AI model's identity. The editor should show a connected session only while its
actual TCP connection exists. A process launched without a successful editor
connection is not a connected AI agent.

## Available tools

`tools/list` requests the editor's live catalog and retains the supplied schemas
and annotations. The initial native implementation provides:

| Tool | Purpose |
| --- | --- |
| `project.overview` | Read project and editor overview |
| `scene.inspect` | Inspect the edited scene structure |
| `editor.selection` | Read the current editor selection |
| `files.search` | Search allowed project files |
| `files.read` | Read bounded project text |
| `tools.search` | Find tools in the native catalog |

The native editor enforces project boundaries, file size limits, and tool
arguments. This adapter does not add arbitrary filesystem, shell, write, or
external network tools. A read-only tool annotation describes the supplied tool;
it is not permission for additional actions.

## Connection and failure behavior

- Only the literal host `127.0.0.1` is accepted. Configuration requires a valid
  TCP port, nonempty token, and absolute `project_root`.
- One persistent authenticated TCP session is held after MCP initialization.
  Closing the client's stdin or stopping the subprocess closes that session.
- Each new TCP connection rereads configuration and sends a fresh `connect`
  registration, supporting editor restarts and token/port rotation.
- An interrupted request is **never replayed automatically**. The client receives
  an error; a later new request may reconnect. A disconnected session is not
  reported as still connected by this companion.
- Tool execution failures use MCP `isError: true` results. Protocol errors use
  JSON-RPC error objects. `ping` checks the actual editor connection.
- UTF-8 newline-delimited messages are bounded to 1 MiB in both directions;
  configuration is bounded to 64 KiB. Response timeout defaults to 10 seconds and
  can be set with `--timeout` between 0.1 and 60 seconds.
- Stdout contains MCP messages only. Diagnostics go to stderr. Known editor tokens
  are redacted from diagnostics and outgoing results, including native errors.

If tools fail to connect, check that the intended editor project is open, its
bridge is enabled, and `--config` points to its current file. If the editor
restarts during an operation, retry the operation explicitly. If the client does
not support the offered MCP version, use a compatible client; the adapter does
not silently pretend that a different protocol was negotiated.

## Native TCP contract

The companion sends one JSON line per request:

```json
{"id":1,"method":"connect","params":{"clientInfo":{"name":"Client","version":"1"},"agent":{}},"token":"PRIVATE"}
```

Native methods are `connect`, `ping`, `catalog`, and `call`. Each response must
have the matching `id` and exactly one of `result` or `error: {code, message}`.
`catalog` returns `{tools: [...]}`. `call` receives `{name, arguments}` and returns
the native MCP tool result `{content: [...], isError?: boolean}`. The token in
this illustrative example is not a real credential.

## Validate the companion

From this directory, run:

```powershell
& 'C:/Path/To/python.exe' -X utf8 -m unittest -v test_mcp_bridge.py
```

Tests start actual stdio subprocesses and a fake loopback editor. They exercise
initialization ordering, schema and annotation forwarding, UTF-8 tool results,
persistent connections, EOF shutdown, interruption without replay, configuration
reload, host/authentication validation, malformed responses, timeout, token
redaction, and input/output size limits. They do not claim to test the real native
editor; integration with a running Unfair build is a separate check.
