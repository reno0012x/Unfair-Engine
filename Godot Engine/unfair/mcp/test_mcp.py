"""Native MCP compatibility checks against an isolated real Unfair project."""
import argparse
import ctypes
import json
import os
from pathlib import Path
import queue
import re
import shutil
import subprocess
import threading
import time


class Client:
    def __init__(self, node, server, engine):
        env = dict(os.environ, UNFAIR_PATH=str(engine), UNFAIR_HEADLESS="1")
        self.process = subprocess.Popen([str(node), str(server)], stdin=subprocess.PIPE,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env,
            creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
        self.messages = queue.Queue()
        self.errors = []
        self.serial = 0
        threading.Thread(target=self.read, daemon=True).start()
        threading.Thread(target=self.read_errors, daemon=True).start()
        self.request("initialize", {"protocolVersion":"2024-11-05", "capabilities":{},
            "clientInfo":{"name":"Unfair MCP native QA","version":"1.0.0"}})
        self.send({"jsonrpc":"2.0","method":"notifications/initialized"})

    def read(self):
        for line in self.process.stdout:
            try:
                self.messages.put(json.loads(line))
            except ValueError:
                self.messages.put({"protocol_error":line.decode("utf-8", "replace")})

    def read_errors(self):
        for line in self.process.stderr:
            self.errors.append(line.decode("utf-8", "replace").rstrip())
            self.errors = self.errors[-200:]

    def send(self, message):
        self.process.stdin.write((json.dumps(message, ensure_ascii=False)+"\n").encode())
        self.process.stdin.flush()

    def request(self, method, params=None, timeout=90):
        self.serial += 1
        number = self.serial
        self.send({"jsonrpc":"2.0","id":number,"method":method,"params":params or {}})
        deadline = time.monotonic()+timeout
        while time.monotonic()<deadline:
            try:
                result = self.messages.get(timeout=max(.01, deadline-time.monotonic()))
            except queue.Empty:
                break
            if "protocol_error" in result:
                raise AssertionError("Non-JSON stdout: "+result["protocol_error"])
            if result.get("id") == number:
                return result
        raise AssertionError(f"Timeout calling {method}: {self.errors[-8:]}")

    def call(self, name, args=None, ok=True):
        response = self.request("tools/call", {"name":name,"arguments":args or {}})
        if ok:
            assert "error" not in response, response
            assert not response["result"].get("isError"), response
        else:
            assert "error" in response or response.get("result",{}).get("isError"), response
        return response.get("result",response)

    def close(self):
        self.process.stdin.close()
        try:
            self.process.wait(timeout=8)
        except subprocess.TimeoutExpired:
            self.process.kill()
            raise AssertionError("MCP did not exit after stdin EOF")


def run(options):
    root = Path(options.output).resolve().parent / ("native-project-"+str(time.time_ns()))
    root.mkdir(parents=True)
    project = root / "project spaces ภาษาไทย"
    project.mkdir()
    (project/"project.godot").write_text('config_version=5\n[application]\nconfig/name="Unfair MCP Native QA"\nrun/main_scene="res://main.tscn"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding="utf-8")
    (project/"main.gd").write_text('extends Node\nfunc _ready():\n\tfor index in range(6000):\n\t\tprint("UNFAIR_LOG_%05d_%s" % [index, "x".repeat(50)])\n\tprint("UNFAIR_MCP_RUNNING")\n\tprint("UNFAIR_MCP_PID=%d" % OS.get_process_id())\n', encoding="utf-8")
    (project/"main.tscn").write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://main.gd" id="1"]\n[node name="Main" type="Node"]\nscript = ExtResource("1")\n', encoding="utf-8")
    (project/"mesh.tscn").write_text('[gd_scene load_steps=2 format=3]\n[sub_resource type="BoxMesh" id="Box"]\n[node name="Geometry" type="Node3D"]\n[node name="Cube" type="MeshInstance3D" parent="."]\nmesh = SubResource("Box")\n', encoding="utf-8")
    shutil.copyfile(options.image, project/"texture.png")
    prepared = subprocess.run([options.engine,"--headless","--editor","--path",str(project),"--import","--quit"],
        capture_output=True, timeout=90, creationflags=subprocess.CREATE_NO_WINDOW if os.name=="nt" else 0)
    assert prepared.returncode==0, prepared.stderr.decode("utf-8","replace")
    # Exercise UID creation for a newly added script, not only editor-made IDs.
    (project/"main.gd.uid").unlink(missing_ok=True)
    checks=[]
    eof_pid=None
    client=Client(Path(options.node),Path(options.server),Path(options.engine))
    try:
        tools=client.request("tools/list")["result"]["tools"]
        required={"launch_editor","run_project","get_debug_output","stop_project","get_godot_version","list_projects","get_project_info","create_scene","add_node","load_sprite","export_mesh_library","save_scene","get_uid","update_project_uids"}
        assert required <= {tool["name"] for tool in tools}
        assert all("annotations" in tool for tool in tools)
        checks.append("All 14 upstream tools retained with annotations")
        result=client.call("get_godot_version")
        assert "4.8" in json.dumps(result)
        checks.append("Version uses actual Unfair executable")
        result=client.call("list_projects",{"directory":str(root),"recursive":True})
        assert "project spaces" in json.dumps(result)
        checks.append("Project discovery with spaces and Unicode directory")
        result=client.call("get_project_info",{"project_path":str(project)})
        assert "Unfair MCP Native QA" in json.dumps(result)
        checks.append("Project info reads actual configured project name (ESM fs fix)")
        common={"projectPath":str(project)}
        client.call("create_scene",{**common,"scenePath":"scenes/test.tscn","rootNodeType":"Node2D"})
        assert '[node name=' in (project/"scenes/test.tscn").read_text()
        scene_uid=re.search(r'uid="(uid://[^"]+)"', (project/"scenes/test.tscn").read_text()).group(1)
        checks.append("create_scene persisted a loadable native scene")
        client.call("add_node",{"project_path":str(project),"scene_path":"scenes/test.tscn","node_type":"Sprite2D","node_name":"Sprite","properties":{"visible":True,"texture_filter":1}})
        assert 'name="Sprite" type="Sprite2D"' in (project/"scenes/test.tscn").read_text()
        checks.append("add_node supports snake_case operation arguments")
        client.call("load_sprite",{**common,"scenePath":"scenes/test.tscn","nodePath":"root/Sprite","texturePath":"texture.png"})
        assert 'texture.png' in (project/"scenes/test.tscn").read_text()
        checks.append("load_sprite persists imported Texture2D reference")
        client.call("save_scene",{**common,"scenePath":"scenes/test.tscn","newPath":"scenes/variant.tscn"})
        assert (project/"scenes/variant.tscn").exists()
        client.call("save_scene",{**common,"scenePath":"scenes/test.tscn"})
        assert scene_uid in (project/"scenes/test.tscn").read_text()
        checks.append("save_scene in place and variant both persist")
        client.call("export_mesh_library",{**common,"scenePath":"mesh.tscn","outputPath":"meshes/library.tres"})
        assert 'MeshLibrary' in (project/"meshes/library.tres").read_text()
        checks.append("export_mesh_library produces a real MeshLibrary resource")
        uid=client.call("get_uid",{**common,"filePath":"texture.png"})
        assert "uid://" in json.dumps(uid), uid
        updated=client.call("update_project_uids",common)
        update_text="\n".join(block.get("text","") for block in updated["content"])
        resave_data=[json.loads(line) for line in update_text.splitlines() if line.startswith('{') and 'resources_saved' in line]
        assert resave_data and resave_data[-1]["resources_saved"]>=5, updated
        assert (project/"main.gd.uid").read_text().strip().startswith("uid://")
        assert (project/"main.gd.uid").read_text().strip() in (project/"main.tscn").read_text()
        assert scene_uid in (project/"scenes/test.tscn").read_text()
        checks.append("get_uid and update_project_uids run against native resources")
        before=(project/"scenes/test.tscn").read_bytes()
        for path in ["../escape.tscn", str(root/"outside.tscn"), "res://../escape.tscn", "user://escape.tscn"]:
            client.call("create_scene",{**common,"scenePath":path},ok=False)
        client.call("add_node",{**common,"scenePath":"scenes/test.tscn","nodeType":"NoSuchUnfairType","nodeName":"Invalid"},ok=False)
        assert before==(project/"scenes/test.tscn").read_bytes()
        assert not (root/"outside.tscn").exists()
        checks.append("Escaping paths and invalid native classes reject without modifying scene")
        client.call("run_project",common)
        time.sleep(1.2)
        output=client.call("get_debug_output")
        assert "UNFAIR_MCP_RUNNING" in json.dumps(output), output
        captured=json.loads(output["content"][0]["text"])
        assert len(captured["output"])<=1500
        assert sum(len(line.encode()) for line in captured["output"])<=128*1024
        checks.append("Noisy project output stays within 1500 lines / 128 KiB per stream")
        client.call("stop_project")
        checks.append("run_project, actual debug output and stop_project lifecycle")
        plugin=project/"addons/qa_exit"
        plugin.mkdir(parents=True)
        (plugin/"plugin.cfg").write_text('[plugin]\nname="QA Exit"\ndescription="Test-owned editor exit"\nauthor="Unfair"\nversion="1"\nscript="plugin.gd"\n')
        (plugin/"plugin.gd").write_text('@tool\nextends EditorPlugin\nfunc _enter_tree():\n\t_exit_qa.call_deferred()\nfunc _exit_qa():\n\tawait get_tree().create_timer(1.0).timeout\n\tget_tree().quit()\n')
        with (project/"project.godot").open("a") as file:
            file.write('\n[editor_plugins]\nenabled=PackedStringArray("res://addons/qa_exit/plugin.cfg")\n')
        client.call("launch_editor",common)
        time.sleep(2)
        checks.append("launch_editor starts actual editor (test-owned plugin exits it)")
        if "get_engine_diagnostics" in {tool["name"] for tool in tools}:
            client.call("get_engine_diagnostics")
            checks.append("Engine diagnostics upgraded tool")
        if "search_tools" in {tool["name"] for tool in tools}:
            result=client.call("search_tools",{"query":"scene"})
            assert "create_scene" in json.dumps(result)
            assert 'inputSchema' not in json.dumps(result)
            result=client.call("search_tools",{"query":"create_scene","includeSchemas":True})
            assert 'inputSchema' in json.dumps(result)
            checks.append("Searchable compact tool directory")
        client.call("does_not_exist",ok=False)
        checks.append("Unknown tool returns protocol/tool error")
        client.call("run_project",common)
        time.sleep(1.2)
        output=client.call("get_debug_output")
        pid_match=re.search(r"UNFAIR_MCP_PID=(\d+)",json.dumps(output))
        assert pid_match, output
        eof_pid=int(pid_match.group(1))
    finally:
        client.close()
    checks.append("stdin EOF closes MCP cleanly")
    if os.name=="nt":
        kernel=ctypes.WinDLL("kernel32",use_last_error=True)
        kernel.OpenProcess.restype=ctypes.c_void_p
        kernel.OpenProcess.argtypes=[ctypes.c_uint32,ctypes.c_bool,ctypes.c_uint32]
        kernel.WaitForSingleObject.argtypes=[ctypes.c_void_p,ctypes.c_uint32]
        kernel.CloseHandle.argtypes=[ctypes.c_void_p]
        handle=kernel.OpenProcess(0x100000,False,eof_pid)
        if handle:
            try:
                assert kernel.WaitForSingleObject(handle,5000)==0,"EOF left the owned run process alive"
            finally:
                kernel.CloseHandle(handle)
        checks.append("stdin EOF terminates the exact QA-owned run process")
    return {"pass":True,"upstream_tool_count":14,"catalog_count":len(tools),"checks":checks,"fixture":str(project)}


if __name__=="__main__":
    parser=argparse.ArgumentParser()
    for name in ["node","server","engine","image","output"]:
        parser.add_argument("--"+name,required=True)
    opts=parser.parse_args()
    try:
        result=run(opts)
    except Exception as error:
        result={"pass":False,"error":str(error)}
        Path(opts.output).write_text(json.dumps(result,indent=2,ensure_ascii=False),encoding="utf-8")
        raise
    Path(opts.output).write_text(json.dumps(result,indent=2,ensure_ascii=False),encoding="utf-8")
    print(json.dumps(result,indent=2,ensure_ascii=False))
