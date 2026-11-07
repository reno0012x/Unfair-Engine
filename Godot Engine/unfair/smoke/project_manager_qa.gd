@tool
extends SceneTree

var failures: Array[String] = []
var out_dir: String

func _initialize() -> void:
	out_dir = (get_script().resource_path as String).get_base_dir().path_join("qa-output")
	_run.call_deferred()

func capture(window: Window, name: String) -> void:
	RenderingServer.force_draw()
	var image := window.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(out_dir.path_join(name + ".png")) != OK:
		failures.append("Capture failed: " + name)

func _run() -> void:
	# Exercise native restore as well as consuming the hidden helper startup hint.
	root.mode = Window.MODE_MAXIMIZED
	await process_frame
	root.mode = Window.MODE_WINDOWED
	await create_timer(1.0).timeout
	DirAccess.make_dir_recursive_absolute(out_dir)
	var ignore := FileAccess.open(out_dir.path_join(".gdignore"), FileAccess.WRITE)
	ignore.close()
	root.size = Vector2i(1280, 860)
	await create_timer(0.5).timeout
	capture(root, "unfair-v4-project-manager")
	var rows := root.find_children("*", "ProjectListItemControl", true, false)
	if not rows.is_empty():
		var row := rows[0] as Control
		row.warp_mouse(Vector2(minf(row.size.x - 10, 300), 30))
		await create_timer(0.3).timeout
		capture(root, "unfair-v4-pm-project-hover")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = row.global_position + Vector2(minf(row.size.x - 10, 300), 30)
		click.pressed = true
		root.push_input(click)
		click = click.duplicate()
		click.pressed = false
		root.push_input(click)
		await create_timer(0.3).timeout
		capture(root, "unfair-v4-pm-project-selected")
	var library: Button
	var brand: Button
	var settings_button: Button
	for button in root.find_children("*", "Button", true, false):
		if button.text == "Library":
			library = button
		if button.text == "UNFAIR":
			brand = button
		if button.text == "Settings":
			settings_button = button
	if library == null or library.flat or not library.button_pressed:
		failures.append("Library has no persistent selected surface")
	if brand == null or brand.flat or brand.icon == null or brand.icon.get_width() < 30:
		failures.append("Brand is not using the larger Unfair mark")
	else:
		brand.warp_mouse(brand.size * 0.5)
		await create_timer(0.3).timeout
		capture(root, "unfair-v4-pm-brand-hover")
		brand.pressed.emit()
		await create_timer(0.3).timeout
		if not brand.button_pressed:
			failures.append("Brand did not remain active while About is open")
		for dialog in root.find_children("*", "Window", true, false):
			if dialog.visible and "About" in dialog.title:
				(dialog as AcceptDialog).get_ok_button().pressed.emit()
		await create_timer(0.2).timeout
		if brand.button_pressed:
			failures.append("Brand active state did not clear after About closed")
	if settings_button == null or settings_button.flat:
		failures.append("Settings is missing visible interaction surfaces")
	else:
		settings_button.warp_mouse(settings_button.size * 0.5)
		await create_timer(0.3).timeout
		capture(root, "unfair-v4-pm-settings-hover")
		settings_button.pressed.emit()
		await create_timer(0.3).timeout
		if not settings_button.button_pressed:
			failures.append("Settings did not remain active while its dialog is open")
		for dialog in root.find_children("*", "Window", true, false):
			if dialog.visible and "Settings" in dialog.title:
				(dialog as AcceptDialog).get_ok_button().pressed.emit()
		await create_timer(0.2).timeout
		if settings_button.button_pressed:
			failures.append("Settings active state did not clear after closing")
	print("UNFAIR_PM_QA_STAGE: project library")
	await create_timer(3.0).timeout
	var create_button: Button
	for button in root.find_children("*", "Button", true, false):
		if button.text == "New Project" and button.is_visible_in_tree():
			create_button = button
			break
	if create_button == null:
		failures.append("New Project action not found")
		finish()
		return
	create_button.pressed.emit()
	await create_timer(1.0).timeout
	var project_dialog: Window
	for window in root.find_children("*", "Window", true, false):
		if window.visible and "Create" in window.title and "Project" in window.title:
			project_dialog = window
	if project_dialog == null:
		failures.append("New Project dialog did not open")
		finish()
		return
	capture(project_dialog, "unfair-v4-new-project")
	if project_dialog.size.y > 900:
		failures.append("New Project dialog is too tall")
	print("UNFAIR_PM_QA_STAGE: new project dialog")
	await create_timer(3.0).timeout
	var browse: Button
	for button in project_dialog.find_children("*", "Button", true, false):
		if button.text == "Browse" and button.is_visible_in_tree():
			browse = button
			break
	if browse:
		browse.pressed.emit()
		await create_timer(1.0).timeout
		var folder: Window
		for window in root.find_children("*", "EditorFileDialog", true, false):
			if window.visible:
				folder = window
		if folder:
			capture(folder, "unfair-v4-project-folder")
			print("UNFAIR_PM_QA_STAGE: project folder dialog")
			await create_timer(3.0).timeout
			folder.close_requested.emit()
		else:
			failures.append("Project folder dialog did not open")
	else:
		failures.append("Browse action not found")
	project_dialog.close_requested.emit()
	finish()

func finish() -> void:
	var file := FileAccess.open(out_dir.path_join("project-manager-qa-result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"pass": failures.is_empty(), "failures": failures}, "\t"))
	file.close()
	print("UNFAIR_PM_QA_RESULT: ", failures)
	quit(0 if failures.is_empty() else 1)
