@tool
extends EditorPlugin


func _enter_tree() -> void:
	if "--unfair-loading-qa" in OS.get_cmdline_user_args():
		var loading_runner: Node = load("res://addons/unfair_qa/loading_qa.gd").new()
		add_child(loading_runner)
		loading_runner.run()
	_verify.call_deferred()


func _verify() -> void:
	await get_tree().create_timer(1.0).timeout
	var theme := EditorInterface.get_editor_theme()
	var settings := EditorInterface.get_editor_settings()
	var failures: Array[String] = []
	if settings.get_setting("interface/theme/color_preset") != "Unfair":
		failures.append("Default color preset is not Unfair")
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		if not theme.has_stylebox(state, "Button"):
			failures.append("Missing Button state: " + state)
	var normal := theme.get_stylebox("normal", "Button") as StyleBoxFlat
	var hover := theme.get_stylebox("hover", "Button") as StyleBoxFlat
	if normal == null or hover == null or hover.bg_color.get_luminance() <= normal.bg_color.get_luminance():
		failures.append("Hover surface does not separate from normal")
	var fill := theme.get_stylebox("fill", "ProgressBar") as StyleBoxFlat
	if fill == null or fill.bg_color.get_luminance() < 0.39:
		failures.append("Progress fill lacks intended contrast")
	if not theme.has_icon("Godot", "EditorIcons"):
		failures.append("Stable application icon key is missing")
	var result := {"pass": failures.is_empty(), "failures": failures, "preset": settings.get_setting("interface/theme/color_preset")}
	var file := FileAccess.open("res://editor-qa-result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	if failures.is_empty():
		print("UNFAIR_EDITOR_THEME_PASS: native preset, interaction states, loading fill, icon")
	else:
		push_error("UNFAIR_EDITOR_THEME_FAIL: " + str(failures))
	if "--unfair-ai-qa" in OS.get_cmdline_user_args():
		var ai_runner: Node = load("res://addons/unfair_qa/ai_qa.gd").new()
		add_child(ai_runner)
		ai_runner.run.call_deferred()
	if DisplayServer.get_name() != "headless" and not "--unfair-v4-qa" in OS.get_cmdline_user_args() and not "--unfair-ai-qa" in OS.get_cmdline_user_args() and not "--unfair-loading-qa" in OS.get_cmdline_user_args():
		# An idle editor can stop drawing; explicitly render the verification frame.
		RenderingServer.force_draw()
		var capture := EditorInterface.get_base_control().get_viewport().get_texture().get_image()
		var capture_result := capture.save_png("res://unfair-editor.png")
		print("UNFAIR_EDITOR_CAPTURE: ", capture_result)
	if "--unfair-v4-qa" in OS.get_cmdline_user_args():
		var runner: Node = load("res://addons/unfair_qa/workbench_qa.gd").new()
		add_child(runner)
		runner.run.call_deferred()
