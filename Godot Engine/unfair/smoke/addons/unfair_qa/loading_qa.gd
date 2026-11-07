@tool
extends Node

# Observe the editor's actual import/scan tasks, including nested Main::iteration.
# This test never assigns a progress value or delays task completion for a capture.
var failures: Array[String] = []
var observations: Array[Dictionary] = []
var captures: Dictionary = {}
var phase := "startup"
var case_name := "installed"
var source_path := ""
var expected_hash := ""
var observing := false
var finished := false
var cancel_sent := false
var startup_seen := false
var compact_seen := false
var reimport_seen := false
var filesystem_changes := 0
var resources_reimported := 0
var started_msec := 0
var skipped_blank_frames := 0


func run() -> void:
	started_msec = Time.get_ticks_msec()
	for argument in OS.get_cmdline_user_args():
		if argument == "--unfair-loading-fallback":
			case_name = "embedded"
		if argument.begins_with("--unfair-loading-source="):
			source_path = argument.trim_prefix("--unfair-loading-source=")
	DirAccess.make_dir_recursive_absolute("res://qa-output")
	FileAccess.open("res://qa-output/.gdignore", FileAccess.WRITE).close()
	var reference := Image.load_from_file(source_path)
	if reference != null and not reference.is_empty():
		reference.convert(Image.FORMAT_RGBA8)
		expected_hash = _image_hash(reference)
	else:
		failures.append("Reference generated background cannot be loaded")
	get_tree().process_frame.connect(_observe)
	EditorInterface.get_resource_filesystem().filesystem_changed.connect(func(): filesystem_changes += 1)
	EditorInterface.get_resource_filesystem().resources_reimported.connect(func(_files: PackedStringArray): resources_reimported += 1)
	_exercise.call_deferred()


func _cards() -> Array[Node]:
	return get_tree().root.find_children("*", "UnfairLoadingCard", true, false)


func _image_hash(image: Image) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(image.get_data())
	return context.finish().hex_encode()


func _labels(card: Node) -> PackedStringArray:
	var texts := PackedStringArray()
	for label in card.find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	return texts


func _capture(card: Control, key: String) -> void:
	if captures.has(key) or card.size.x <= 0 or card.size.y <= 0:
		return
	card.queue_redraw()
	for item in card.find_children("*", "CanvasItem", true, false):
		(item as CanvasItem).queue_redraw()
	RenderingServer.force_draw()
	var image := card.get_window().get_texture().get_image()
	if image == null or image.is_empty():
		failures.append("Missing native viewport image: " + key)
		return
	var stem := "res://qa-output/loading-" + case_name + "-" + key
	var rect := Rect2i(card.get_global_rect()).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	if rect.size.x <= 0 or rect.size.y <= 0:
		failures.append("Loading card lies outside captured viewport: " + key)
		return
	var cropped := image.get_region(rect)
	var brightest := 0.0
	for y in range(0, cropped.get_height(), maxi(1, cropped.get_height() / 12)):
		for x in range(0, cropped.get_width(), maxi(1, cropped.get_width() / 12)):
			brightest = maxf(brightest, cropped.get_pixel(x, y).get_luminance())
	if brightest < 0.1:
		# During a viewport transition the synchronous readback can precede
		# child redraw. Observe the next real frame; never hold the task open.
		skipped_blank_frames += 1
		return
	if image.save_png(stem + "-window.png") != OK or cropped.save_png(stem + "-card.png") != OK:
		failures.append("Cannot save loading capture: " + key)
	else:
		captures[key] = stem + "-card.png"


func _check_card(card: Control) -> void:
	if not Rect2(Vector2.ZERO, Vector2(card.get_window().size)).encloses(card.get_global_rect()):
		failures.append("Loading card exceeds native viewport bounds: " + str(card.get_global_rect()))
	if not card.get_parent().is_class("ProgressDialog") and not is_equal_approx(card.custom_minimum_size.y, 230.0 * EditorInterface.get_editor_scale()):
		failures.append("Dock-local loading card lost its compact minimum height")
	if card.clip_children != CanvasItem.CLIP_CHILDREN_AND_DRAW:
		failures.append("Loading image is not masked with its rounded surface")
	var texts := "\n".join(_labels(card))
	if not texts.contains("Unfair compatibility smoke") or not texts.contains("Built on Godot Engine.") or not texts.contains("Unfair v"):
		failures.append("Loading project/version/fork credit is incomplete: " + texts)
	var background: TextureRect = null
	for child in card.get_children():
		if child is TextureRect:
			background = child
			break
	if background == null or background.texture == null:
		failures.append("Generated loading background texture is missing")
		return
	var image := background.texture.get_image()
	if image == null or image.get_width() < 1000 or image.get_height() < 500:
		failures.append("Loading background has unexpected dimensions")
		return
	image.convert(Image.FORMAT_RGBA8)
	if _image_hash(image) != expected_hash:
		failures.append("Loading background pixels differ from generated blurred artwork")
	if background.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_COVERED:
		failures.append("Background does not preserve its cover aspect ratio")


func _observe() -> void:
	if observing or finished:
		return
	observing = true
	for node in _cards():
		var card := node as Control
		if not card.is_visible_in_tree():
			continue
		var modal := card.get_parent().is_class("ProgressDialog")
		var texts := _labels(card)
		var key := phase + ("-modal" if modal else "-compact")
		if modal and "Opening project" in texts:
			key += "-opening-project"
		var bars: Array[Dictionary] = []
		for progress_node in card.find_children("*", "ProgressBar", true, false):
			var bar := progress_node as ProgressBar
			if bar.is_visible_in_tree():
				bars.append({"value": bar.value, "max": bar.max_value, "indeterminate": bar.indeterminate})
				if modal and bar.value > 0 and bar.value < bar.max_value:
					key += "-step-" + str(int(bar.value))
		if not captures.has(key):
			_check_card(card)
			observations.append({"phase": phase, "modal": modal, "elapsed_msec": Time.get_ticks_msec() - started_msec,
				"size": [card.size.x, card.size.y], "minimum_size": [card.custom_minimum_size.x, card.custom_minimum_size.y],
				"labels": texts, "progress": bars, "scanner_progress": EditorInterface.get_resource_filesystem().get_scanning_progress()})
			_capture(card, key)
		if not modal:
			compact_seen = true
			if card.size.x > card.get_window().size.x:
				failures.append("Compact scan card exceeds its native window width")
		if phase == "startup" and modal and "Opening project" in texts:
			startup_seen = true
		if phase == "reimport" and modal:
			reimport_seen = true
		if phase == "cancel" and modal and not cancel_sent:
			for button_node in card.find_children("*", "Button", true, false):
				var button := button_node as Button
				if button.text == "Cancel" and button.is_visible_in_tree() and not button.disabled:
					cancel_sent = true
					# Exercise the original native Cancel signal/handler while its real
					# cancellable project-class scan is inside Main::iteration.
					button.pressed.emit()
					break
	observing = false


func _exercise() -> void:
	var filesystem := EditorInterface.get_resource_filesystem()
	var deadline := Time.get_ticks_msec() + 45000
	var idle_frames := 0
	while idle_frames < 3 and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		var modal_visible := false
		for node in _cards():
			if node.get_parent().is_class("ProgressDialog") and (node as Control).is_visible_in_tree():
				modal_visible = true
		# Nested Main::iteration can resume this coroutine while editor layout is
		# still loading. Wait for genuine modal/scan completion, not a fixed delay.
		idle_frames = idle_frames + 1 if startup_seen and not filesystem.is_scanning() and not modal_visible else 0
	if filesystem.is_scanning():
		failures.append("Initial resource scan did not finish")
		_finish()
		return
	phase = "scan"
	var before_changes := filesystem_changes
	filesystem.scan()
	while (filesystem.is_scanning() or filesystem_changes == before_changes) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if filesystem_changes == before_changes:
		failures.append("Explicit EditorFileSystem scan did not emit filesystem_changed")
	var paths := PackedStringArray()
	for index in 4:
		var path := "res://loading-fixture/" + case_name + "-" + str(index) + ".png"
		if FileAccess.file_exists(path):
			paths.append(path)
	if paths.size() != 4:
		failures.append("Four real PNG import fixtures were not prepared by verify-loading.ps1")
	else:
		phase = "reimport"
		var before_reimport := resources_reimported
		filesystem.reimport_files(paths)
		if resources_reimported <= before_reimport:
			failures.append("Native resource reimport completion was not observed")
		for path in paths:
			if not FileAccess.file_exists(path + ".import"):
				failures.append("Real texture import sidecar is missing: " + path)
	phase = "cancel"
	var managers := get_tree().root.find_children("*", "EditorBuildProfileManager", true, false)
	if managers.is_empty():
		failures.append("Native cancellable project-class scan manager is missing")
	else:
		var manager := managers[0] as Window
		manager.theme = EditorInterface.get_editor_theme()
		# This existing native manager already belongs to EditorNode. The
		# EditorInterface helper expects an unparented plugin-created dialog.
		manager.popup_centered_clamped(Vector2i(900, 680), 0.85)
		await get_tree().process_frame
		var detect: Button = null
		for button in manager.find_children("*", "Button", true, false):
			if (button as Button).text == "Detect from Project":
				detect = button
		if detect == null:
			failures.append("Native Detect from Project action is missing")
		else:
			detect.pressed.emit()
			await get_tree().process_frame
			var confirmed := false
			for dialog in manager.find_children("*", "ConfirmationDialog", true, false):
				if (dialog as Window).visible:
					confirmed = true
					(dialog as ConfirmationDialog).get_ok_button().pressed.emit()
					break
			if not confirmed:
				failures.append("Class scan confirmation was not presented")
		manager.hide()
	if not cancel_sent:
		failures.append("Native Cancel handler was not exercised during cancellable scan")
	for node in _cards():
		if node.get_parent().is_class("ProgressDialog") and (node as Control).is_visible_in_tree():
			failures.append("Progress modal remains visible after native task completion/cancellation")
	if not startup_seen:
		failures.append("Real Opening project startup card was not observed")
	if not compact_seen:
		failures.append("Real dock-local filesystem loading card was not observed")
	if not reimport_seen:
		failures.append("Real asset reimport loading card was not observed")
	_finish()


func _finish() -> void:
	finished = true
	if get_tree().process_frame.is_connected(_observe):
		get_tree().process_frame.disconnect(_observe)
	for required_prefix in ["startup-modal-opening-project", "startup-compact", "reimport-modal", "cancel-modal"]:
		var found := false
		for key in captures:
			if str(key).begins_with(required_prefix):
				found = true
		if not found:
			failures.append("Native nonblank capture is missing: " + required_prefix)
	var result := {"pass": failures.is_empty(), "case": case_name, "failures": failures, "captures": captures,
		"observations": observations, "filesystem_changes": filesystem_changes, "resources_reimported": resources_reimported,
		"startup_observed": startup_seen, "compact_observed": compact_seen, "reimport_observed": reimport_seen,
		"native_cancel_exercised": cancel_sent, "background_pixel_sha256": expected_hash,
		"skipped_blank_frames": skipped_blank_frames, "editor_scale": EditorInterface.get_editor_scale()}
	var file := FileAccess.open("res://qa-output/loading-" + case_name + "-qa-result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("UNFAIR_LOADING_QA_RESULT: ", case_name, " pass=", failures.is_empty(), " captures=", captures.size(), " failures=", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
