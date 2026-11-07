@tool
extends Node

var failures: Array[String] = []
var folder_result := ""

func capture(window: Window, name: String) -> void:
	for item in window.find_children("*", "CanvasItem", true, false):
		(item as CanvasItem).queue_redraw()
	RenderingServer.force_draw()
	var image := window.get_texture().get_image()
	if image == null or image.is_empty():
		failures.append("Empty capture: " + name)
		return
	if image.save_png("res://qa-output/" + name + ".png") != OK:
		failures.append("Capture failed: " + name)

func run() -> void:
	var base := EditorInterface.get_base_control()
	var settings := EditorInterface.get_editor_settings()
	var old_preset: String = settings.get_setting("interface/theme/color_preset")
	var old_native: bool = settings.get_setting("interface/editor/appearance/use_native_file_dialogs")
	var old_size := get_window().size
	DirAccess.make_dir_recursive_absolute("res://qa-output")
	var ignore := FileAccess.open("res://qa-output/.gdignore", FileAccess.WRITE)
	ignore.close()
	var menu := base.find_child("UnfairWindowsMenu", true, false) as MenuButton
	var command := base.find_child("UnfairCommandBar", true, false) as Container
	if command == null or menu == null:
		failures.append("Native command bar/windows menu is missing")
		finish()
		return
	menu.get_popup().id_pressed.emit(20)
	EditorInterface.set_main_screen_editor("3D")
	get_window().mode = Window.MODE_MAXIMIZED
	await get_tree().create_timer(0.2).timeout
	if get_window().mode != Window.MODE_MAXIMIZED:
		failures.append("Native maximize failed")
	get_window().mode = Window.MODE_MINIMIZED
	await get_tree().create_timer(0.2).timeout
	if get_window().mode != Window.MODE_MINIMIZED:
		failures.append("Native minimize failed")
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1600, 980)
	await get_tree().create_timer(1.0).timeout
	var undo_button := base.find_child("UnfairUndo", true, false) as Button
	var redo_button := base.find_child("UnfairRedo", true, false) as Button
	if undo_button == null or redo_button == null:
		failures.append("Undo/Redo toolbar buttons are missing")
	else:
		var history: EditorUndoRedoManager = (get_parent() as EditorPlugin).get_undo_redo()
		set_meta("qa_history_value", 0)
		history.create_action("Unfair toolbar QA", UndoRedo.MERGE_DISABLE, self, false, false)
		history.add_do_method(self, "set_meta", "qa_history_value", 1)
		history.add_undo_method(self, "set_meta", "qa_history_value", 0)
		history.commit_action()
		await get_tree().process_frame
		if undo_button.disabled:
			failures.append("Undo toolbar did not track committed history")
		undo_button.pressed.emit()
		if get_meta("qa_history_value") != 0 or redo_button.disabled:
			failures.append("Undo toolbar did not execute existing history command")
		redo_button.pressed.emit()
		if get_meta("qa_history_value") != 1:
			failures.append("Redo toolbar did not execute existing history command")
		undo_button.pressed.emit()
	var project_title := base.find_child("UnfairProjectTitle", true, false) as Label
	if project_title == null or project_title.get_global_rect().end.x < get_window().size.x - 80:
		failures.append("Project title is not anchored on the right")
	for item in menu.get_popup().item_count:
		if not menu.get_popup().is_item_separator(item) and menu.get_popup().get_item_icon(item) == null:
			failures.append("Windows menu item has no icon")
	menu.get_popup().prefer_native_menu = false
	menu.show_popup()
	await get_tree().create_timer(0.3).timeout
	capture(menu.get_popup(), "unfair-v4-windows-menu")
	menu.get_popup().hide()
	var content := base.find_child("UnfairContentBrowser", true, false) as Button
	if content == null:
		failures.append("Content Browser drawer toggle is missing")
	else:
		if content.button_pressed:
			failures.append("Reset workspace should start with the content drawer collapsed")
		content.pressed.emit()
		await get_tree().create_timer(0.4).timeout
		if not content.button_pressed:
			failures.append("Content drawer did not open")
		capture(get_window(), "unfair-v4-content-open")
		var output_tabs: TabBar
		var output_index := -1
		for candidate in base.find_children("*", "TabBar", true, false):
			for index in candidate.tab_count:
				if candidate.get_tab_title(index) == "Output":
					output_tabs = candidate
					output_index = index
		if output_tabs != null:
			output_tabs.current_tab = output_index
			await get_tree().create_timer(0.4).timeout
			if content.button_pressed:
				failures.append("Output should collapse the horizontal content drawer")
			capture(get_window(), "unfair-v4-output-open")
		else:
			failures.append("Output tab was not found")
		content.pressed.emit()
		await get_tree().create_timer(0.3).timeout
		content.pressed.emit()
		await get_tree().create_timer(0.3).timeout
		if content.button_pressed:
			failures.append("Content drawer did not close on second activation")
	var center_region := command.get_child(1) as Control
	var center_delta := absf(center_region.get_global_rect().get_center().x - command.get_global_rect().get_center().x)
	if center_delta > 2.0:
		failures.append("Workspace tabs are not centered at desktop width: " + str(center_delta))
	var brand := base.find_child("UnfairBrand", true, false) as Button
	if brand == null or brand.theme_type_variation != "UnfairBrandButton":
		failures.append("Brand has no interactive button state")
	var theme := EditorInterface.get_editor_theme()
	for kind in ["UnfairPlayButton", "UnfairPauseButton", "UnfairStopButton"]:
		if not theme.has_stylebox("hover", kind) or not theme.has_stylebox("pressed", kind):
			failures.append("Transport interaction style missing: " + kind)
	if brand != null:
		brand.notification(Control.NOTIFICATION_MOUSE_ENTER)
		await get_tree().create_timer(0.3).timeout
		capture(get_window(), "unfair-v4-brand-hover")
		brand.notification(Control.NOTIFICATION_MOUSE_EXIT)
	capture(get_window(), "unfair-v4-workbench")
	var tabs: Array[Node] = command.find_children("*", "TabBar", true, false)
	if tabs.is_empty() or (tabs[0] as Control).size.x < 300:
		failures.append("Workspace tabs are clipped")
	get_window().size = Vector2i(1152, 800)
	await get_tree().create_timer(0.5).timeout
	if get_window().size.x > 1152:
		failures.append("Workbench minimum width exceeds 1152")
	if command.get_global_rect().end.x > get_window().size.x + 1:
		failures.append("Command bar extends outside compact viewport")
	capture(get_window(), "unfair-v4-workbench-compact")
	get_window().size = Vector2i(1600, 980)
	settings.set_setting("interface/editor/appearance/use_native_file_dialogs", false)
	for tool_id in [30, 31, 32, 33, 34]:
		menu.get_popup().id_pressed.emit(tool_id)
		await get_tree().create_timer(0.3).timeout
		var tool_window: Window
		var tool_name := {30:"Output", 31:"Debugger", 32:"Audio", 33:"Animation", 34:"Shader Editor"}[tool_id] as String
		for window in get_tree().root.find_children("*", "Window", true, false):
			if window.visible and window.title.begins_with(tool_name + " - "):
				tool_window = window
		if tool_window == null:
			failures.append("Bottom tool failed to detach: " + tool_name)
		else:
			capture(tool_window, "unfair-v4-detached-" + tool_name.to_lower().replace(" ", "-"))
			tool_window.close_requested.emit()
			await get_tree().create_timer(0.2).timeout
			if is_instance_valid(tool_window) and tool_window.visible:
				failures.append("Bottom tool did not redock on close: " + tool_name)
	var detach_button := base.find_child("UnfairDetachBottomTool", true, false) as Button
	if detach_button == null or detach_button.disabled:
		failures.append("Selected bottom tool has no usable Open in Window button")
	else:
		detach_button.pressed.emit()
		await get_tree().create_timer(0.3).timeout
		menu.get_popup().id_pressed.emit(21)
		await get_tree().create_timer(0.2).timeout
	menu.get_popup().id_pressed.emit(20)
	var dialog := EditorFileDialog.new()
	dialog.title = "Choose Project Folder"
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dialog.current_dir = ProjectSettings.globalize_path("res://")
	dialog.dir_selected.connect(func(path: String) -> void: folder_result = path)
	EditorInterface.popup_dialog_centered_clamped(dialog, Vector2i(1080, 720), 0.9)
	await get_tree().create_timer(1.0).timeout
	if dialog.get_ok_button().text != "Select Folder":
		failures.append("Folder primary action is unclear")
	if dialog.size.y > 800:
		failures.append("Folder dialog minimum height exceeds 800")
	capture(dialog, "unfair-v4-folder")
	print("UNFAIR_V4_QA_STAGE: dark folder dialog")
	await get_tree().create_timer(3.0).timeout
	dialog.get_ok_button().pressed.emit()
	if folder_result.simplify_path().trim_suffix("/") != ProjectSettings.globalize_path("res://").simplify_path().trim_suffix("/"):
		failures.append("Folder confirmation emitted wrong path: " + folder_result)
	dialog.hide()
	menu.get_popup().id_pressed.emit(3)
	await get_tree().create_timer(1.0).timeout
	var detached: Window
	for window in get_tree().root.find_children("*", "Window", true, false):
		if window is Window and window.visible and "Script" in window.title:
			detached = window
	if detached == null:
		failures.append("Script tool did not open in a separate window")
	else:
		capture(detached, "unfair-v4-script-window")
		detached.mode = Window.MODE_MINIMIZED
		await get_tree().create_timer(0.2).timeout
		menu.get_popup().id_pressed.emit(3)
		await get_tree().create_timer(0.2).timeout
		if detached.mode == Window.MODE_MINIMIZED:
			failures.append("Windows menu did not restore minimized Script window")
		print("UNFAIR_V4_QA_STAGE: detached script window")
		await get_tree().create_timer(3.0).timeout
		if is_instance_valid(detached):
			menu.get_popup().id_pressed.emit(21)
			await get_tree().create_timer(0.4).timeout
			if is_instance_valid(detached) and detached.visible:
				failures.append("Return All Tool Windows left Script detached")
	EditorInterface.play_custom_scene("res://run_fixture.tscn")
	await get_tree().create_timer(3.0).timeout
	if not EditorInterface.is_playing_scene():
		failures.append("Transport fixture did not start")
	var pause: Button
	var stop: Button
	for button in command.find_children("*", "Button", true, false):
		if button.theme_type_variation == "UnfairPauseButton":
			pause = button
		if button.theme_type_variation == "UnfairStopButton":
			stop = button
	if pause == null or stop == null or pause.disabled or stop.disabled:
		failures.append("Running transport controls are not enabled")
	else:
		capture(get_window(), "unfair-v4-transport-running")
		pause.button_pressed = true
		pause.pressed.emit()
		await get_tree().create_timer(1.0).timeout
		if not pause.button_pressed:
			failures.append("Pause state was not retained")
		capture(get_window(), "unfair-v4-transport-paused")
		stop.pressed.emit()
		await get_tree().create_timer(0.5).timeout
	if EditorInterface.is_playing_scene():
		failures.append("Stop did not end transport fixture")
		EditorInterface.stop_playing_scene()
	menu.get_popup().id_pressed.emit(20)
	EditorInterface.set_main_screen_editor("3D")
	settings.set_setting("interface/theme/color_preset", "Light")
	# Match the Editor Settings dialog's apply path; set_setting alone saves a
	# value but does not notify the existing editor tree to regenerate its theme.
	get_tree().root.get_child(0).propagate_notification(EditorSettings.NOTIFICATION_EDITOR_SETTINGS_CHANGED)
	await get_tree().create_timer(1.0).timeout
	var light_background := EditorInterface.get_editor_theme().get_color("background", "Editor")
	if light_background.get_luminance() < 0.5:
		failures.append("Light theme did not regenerate")
	capture(get_window(), "unfair-v4-light")
	dialog.popup_centered_clamped(Vector2i(1080, 720), 0.9)
	await get_tree().create_timer(0.5).timeout
	capture(dialog, "unfair-v4-folder-light")
	print("UNFAIR_V4_QA_STAGE: light folder dialog")
	await get_tree().create_timer(3.0).timeout
	dialog.hide()
	dialog.queue_free()
	settings.set_setting("interface/theme/color_preset", old_preset)
	settings.set_setting("interface/editor/appearance/use_native_file_dialogs", old_native)
	get_tree().root.get_child(0).propagate_notification(EditorSettings.NOTIFICATION_EDITOR_SETTINGS_CHANGED)
	get_window().size = old_size
	await get_tree().create_timer(0.5).timeout
	finish()

func finish() -> void:
	var file := FileAccess.open("res://qa-output/workbench-qa-result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"pass": failures.is_empty(), "failures": failures}, "\t"))
	file.close()
	print("UNFAIR_V4_WORKBENCH_RESULT: ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
