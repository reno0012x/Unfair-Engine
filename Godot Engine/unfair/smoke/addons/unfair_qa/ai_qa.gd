@tool
extends Node

var failures: Array[String] = []
var python := "C:/Users/LEONIDASxII/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe"

func click_button(button: Button) -> void:
	var target_window := button.get_window()
	var rect := button.get_global_rect()
	if not button.is_visible_in_tree() or not Rect2(Vector2.ZERO, Vector2(target_window.size)).encloses(rect):
		failures.append("Button is outside its visible window: " + str(button.name))
		return
	# Touch events exercise the viewport hit-test and button press/release without
	# moving the user's OS pointer or depending on which desktop app has focus.
	var event := InputEventScreenTouch.new()
	event.window_id = target_window.get_window_id()
	event.index = 0
	event.position = rect.get_center()
	event.pressed = true
	target_window.push_input(event, true)
	await get_tree().process_frame
	event = event.duplicate()
	event.pressed = false
	target_window.push_input(event, true)
	await get_tree().create_timer(0.1).timeout

func check_window_bounds(window: Window, stage: String) -> void:
	var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
	var outer := Rect2i(window.get_position_with_decorations(), window.get_size_with_decorations())
	if not usable.encloses(outer):
		failures.append("Native window exceeds screen work area at " + stage + ": " + str(outer))
	for name in ["UnfairAIEnable", "UnfairAICopyConfig", "UnfairAIExport"]:
		var control := window.find_child(name, true, false) as Control
		if control == null or not Rect2(Vector2.ZERO, Vector2(window.size)).encloses(control.get_global_rect()):
			failures.append("Fixed action is unreachable at " + stage + ": " + name)

func capture(window: Window, name: String) -> void:
	for item in window.find_children("*", "CanvasItem", true, false):
		(item as CanvasItem).queue_redraw()
	RenderingServer.force_draw()
	var image := window.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png("res://qa-output/" + name + ".png") != OK:
		failures.append("Capture failed: " + name)

func write_native_probe(window: Window, stage: String) -> void:
	var file := FileAccess.open("res://qa-output/ai-window-probe.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"handle": DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE, window.get_window_id()), "stage":stage, "size":str(window.size)}))
	file.close()

func run() -> void:
	var bundled := OS.get_executable_path().get_base_dir().path_join("runtime/python/python.exe")
	if FileAccess.file_exists(bundled):
		python = bundled
	DirAccess.make_dir_recursive_absolute("res://qa-output")
	FileAccess.open("res://qa-output/.gdignore", FileAccess.WRITE).close()
	get_window().mode = Window.MODE_MAXIMIZED
	await get_tree().create_timer(0.1).timeout
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1600, 980)
	EditorInterface.open_scene_from_path("res://run_fixture.tscn")
	await get_tree().create_timer(0.4).timeout
	var fixture := EditorInterface.get_edited_scene_root()
	if fixture != null:
		EditorInterface.get_selection().add_node(fixture)
	var base := EditorInterface.get_base_control()
	var ai_button := base.find_child("UnfairAIAssistButton", true, false) as Button
	var content_button := base.find_child("UnfairContentBrowser", true, false) as Button
	var undo_button := base.find_child("UnfairUndo", true, false) as Button
	if ai_button == null or content_button == null or ai_button.get_parent() != content_button.get_parent() or ai_button.get_index() >= content_button.get_index() or content_button.get_index() >= undo_button.get_index():
		failures.append("AI Assist is not before Content Browser / Undo / Redo in the command toolbar")
	capture(get_window(), "unfair-v8-workspace-toolbar")
	var menu := base.find_child("UnfairWindowsMenu", true, false) as MenuButton
	if menu == null:
		failures.append("Windows menu is missing")
		finish()
		return
	menu.get_popup().id_pressed.emit(40)
	await get_tree().create_timer(0.5).timeout
	var dock := get_tree().root.find_child("UnfairAIAssistance", true, false)
	if dock == null:
		failures.append("AI Assistance dock is missing")
		finish()
		return
	var window := dock.get_window() as Window
	# Initial geometry is intentionally NOT assigned: catch real opening overflow.
	check_window_bounds(window, "initial open")
	if window.transparent or window.transparent_bg:
		failures.append("AI native window must be opaque to preserve its DWM caption")
	if not ai_button.button_pressed:
		failures.append("AI toolbar button does not show its open state")
	capture(window, "unfair-v6-ai-initial-size")
	window.mode = Window.MODE_WINDOWED
	window.size = Vector2i(640, 480)
	await get_tree().create_timer(0.3).timeout
	check_window_bounds(window, "640x480 compact")
	capture(window, "unfair-v6-ai-compact")
	window.size = Vector2i(6000, 6000)
	window.position = Vector2i(-10000, -10000)
	await get_tree().create_timer(0.3).timeout
	check_window_bounds(window, "oversized saved rectangle recovery")
	window.close_requested.emit()
	await get_tree().create_timer(0.2).timeout
	menu.get_popup().id_pressed.emit(40)
	await get_tree().create_timer(0.3).timeout
	window = dock.get_window()
	check_window_bounds(window, "reopen")
	await get_tree().create_timer(0.3).timeout
	write_native_probe(window, "dark")
	var rounded := dock.find_child("UnfairAIRoundedSurface", true, false) as CanvasItem
	if rounded.clip_children != CanvasItem.CLIP_CHILDREN_AND_DRAW:
		failures.append("AI surface has no actual child alpha mask")
	# Prove the parent's rounded mask clips child content, even on an opaque HWND.
	var clip_probe := Polygon2D.new()
	var surface_size := (rounded as Control).size
	clip_probe.polygon = PackedVector2Array([Vector2.ZERO, Vector2(surface_size.x, 0), surface_size, Vector2(0, surface_size.y)])
	clip_probe.color = Color(1, 0, 1)
	rounded.add_child(clip_probe)
	await get_tree().process_frame
	RenderingServer.force_draw()
	var clip_image := window.get_texture().get_image()
	var surface_origin := Vector2i((rounded as Control).global_position)
	var clip_corner := clip_image.get_pixelv(surface_origin + Vector2i(1, 1))
	var clip_center := clip_image.get_pixelv(surface_origin + Vector2i(surface_size / 2))
	if clip_corner.r > 0.9 and clip_corner.b > 0.9 or clip_center.r < 0.9 or clip_center.b < 0.9:
		failures.append("Rounded surface did not genuinely clip its child content")
	clip_probe.free()
	await get_tree().process_frame
	RenderingServer.force_draw()
	var status: Dictionary = dock.get_bridge_status()
	if status.enabled or status.session_count != 0:
		failures.append("AI bridge must start offline with no invented clients")
	capture(window, "unfair-ai-offline")
	var advanced := dock.find_child("UnfairAIAdvanced", true, false) as Button
	var python_field := dock.find_child("UnfairAIPythonPath", true, false) as LineEdit
	if python_field.is_visible_in_tree():
		failures.append("Advanced Python settings should start collapsed")
	await click_button(advanced)
	if not python_field.is_visible_in_tree():
		failures.append("Connection settings did not reveal the Python field")
	await click_button(advanced)
	for empty_name in ["UnfairAISessionsEmpty", "UnfairAIActivityEmpty"]:
		if not (dock.find_child(empty_name, true, false) as Control).is_visible_in_tree():
			failures.append("Missing honest empty state: " + empty_name)
	var enable := dock.find_child("UnfairAIEnable", true, false) as Button
	await click_button(enable)
	await get_tree().create_timer(0.3).timeout
	var config: String = dock.get_connection_config_path()
	if config.is_empty() or not FileAccess.file_exists(config):
		failures.append("Bridge did not save its local connection config")
		finish()
		return
	(dock.find_child("UnfairAIPythonPath", true, false) as LineEdit).text = python
	await click_button(dock.find_child("UnfairAICopyConfig", true, false) as Button)
	var copied = JSON.parse_string(DisplayServer.clipboard_get())
	if not copied is Dictionary or not copied.has("mcpServers"):
		failures.append("Copied MCP configuration is invalid")
	capture(window, "unfair-ai-ready")
	var out := ProjectSettings.globalize_path("res://qa-output")
	var config_reference := FileAccess.open(out.path_join("ai-config-path.txt"), FileAccess.WRITE)
	config_reference.store_string(config)
	config_reference.close()
	var stem := "native-" + str(Time.get_ticks_msec())
	var ready := out.path_join(stem + "-ready.json")
	var result := out.path_join(stem + "-result.json")
	var release := out.path_join(stem + "-release")
	var script := ProjectSettings.globalize_path("res://../ai/test_native_bridge.py")
	var pid := OS.create_process(python, ["-X", "utf8", script, "--config", config, "--output", result, "--ready", ready, "--release", release], false)
	if pid < 0:
		failures.append("Could not start native MCP integration client")
	else:
		for tick in 300:
			if FileAccess.file_exists(ready) or FileAccess.file_exists(result):
				break
			await get_tree().create_timer(0.1).timeout
		if not FileAccess.file_exists(ready):
			failures.append("MCP client did not reach the connected activity stage")
		else:
			status = dock.get_bridge_status()
			if status.session_count < 1 or status.activity.size() < 6:
				failures.append("Actual MCP calls did not populate sessions and activity")
			await get_tree().create_timer(0.4).timeout
			capture(window, "unfair-ai-connected-activity")
			var tool_tabs := dock.find_children("*", "TabContainer", true, false)[0] as TabContainer
			tool_tabs.current_tab = 1
			await get_tree().create_timer(0.2).timeout
			capture(window, "unfair-ai-tool-directory")
			tool_tabs.current_tab = 0
			var yellow := dock.find_child("UnfairAIYellowCompact", true, false) as Button
			await click_button(yellow)
			if tool_tabs.visible:
				failures.append("Yellow compact control did not collapse activity")
			await click_button(yellow)
		FileAccess.open(release, FileAccess.WRITE).close()
		for tick in 100:
			if FileAccess.file_exists(result):
				break
			await get_tree().create_timer(0.1).timeout
		if FileAccess.file_exists(result):
			var native_result = JSON.parse_string(FileAccess.get_file_as_string(result))
			if not native_result is Dictionary or not native_result.get("pass", false):
				failures.append("Native MCP protocol test failed: " + str(native_result.get("failures", [])))
		else:
			failures.append("Native MCP client did not finish")
			if OS.is_process_running(pid):
				OS.kill(pid)
	await get_tree().create_timer(0.5).timeout
	status = dock.get_bridge_status()
	if status.session_count != 0:
		failures.append("Disconnected MCP client is still counted as connected")
	capture(window, "unfair-ai-disconnected")
	await click_button(dock.find_child("UnfairAIExport", true, false) as Button)
	await get_tree().create_timer(0.2).timeout
	var export_dialog := dock.find_child("UnfairAIExportDialog", true, false) as EditorFileDialog
	var export_path := out.path_join("unfair-ai-activity-" + stem + ".md")
	export_dialog.current_path = export_path
	export_dialog.get_ok_button().pressed.emit()
	await get_tree().create_timer(0.2).timeout
	if not FileAccess.file_exists(export_path):
		failures.append("Activity Markdown export did not create its file")
	var export_text := FileAccess.get_file_as_string(export_path)
	if not export_text.contains("files.read") or not export_text.contains("res://smoke.gd:1-3"):
		failures.append("Activity export is missing the actual tool and line-range records")
	var export_artifact := FileAccess.open(out.path_join("unfair-ai-activity.md"), FileAccess.WRITE)
	export_artifact.store_string(export_text)
	export_artifact.close()
	var config_data = JSON.parse_string(FileAccess.get_file_as_string(config))
	if export_text.contains(config_data.get("token", "no-token")):
		failures.append("Authentication token leaked into Markdown activity")
	await click_button(dock.find_child("UnfairAIRedStop", true, false) as Button)
	await get_tree().create_timer(0.3).timeout
	if FileAccess.file_exists(config) or dock.get_bridge_status().enabled:
		failures.append("Stopping the bridge did not revoke the config and listener")
	var settings := EditorInterface.get_editor_settings()
	var old_preset: String = settings.get_setting("interface/theme/color_preset")
	settings.set_setting("interface/theme/color_preset", "Light")
	get_tree().root.get_child(0).propagate_notification(EditorSettings.NOTIFICATION_EDITOR_SETTINGS_CHANGED)
	await get_tree().create_timer(0.6).timeout
	capture(window, "unfair-ai-light")
	write_native_probe(window, "light")
	await get_tree().create_timer(1.0).timeout
	settings.set_setting("interface/theme/color_preset", old_preset)
	get_tree().root.get_child(0).propagate_notification(EditorSettings.NOTIFICATION_EDITOR_SETTINGS_CHANGED)
	window.close_requested.emit()
	await get_tree().create_timer(0.2).timeout
	if ai_button.button_pressed != dock.is_visible_in_tree():
		failures.append("AI toolbar button did not follow the returned dock's visibility")
	finish()

func finish() -> void:
	var file := FileAccess.open("res://qa-output/ai-qa-result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"pass": failures.is_empty(), "failures": failures}, "\t"))
	file.close()
	print("UNFAIR_AI_QA_RESULT: ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
