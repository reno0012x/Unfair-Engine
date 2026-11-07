extends SceneTree


func _initialize() -> void:
	var values: Array[int] = [1, 2, 3]
	assert(values.reduce(func(total: int, value: int) -> int: return total + value, 0) == 6)
	var node := Node2D.new()
	node.name = "CompatibilityNode"
	node.position = Vector2(12, 24)
	var packed := PackedScene.new()
	assert(packed.pack(node) == OK)
	var scene_path := "res://.unfair_compatibility_%s.tscn" % Time.get_ticks_usec()
	assert(ResourceSaver.save(packed, scene_path) == OK)
	var restored := load(scene_path) as PackedScene
	assert(restored != null)
	var instance := restored.instantiate() as Node2D
	assert(instance.name == "CompatibilityNode")
	assert(instance.position == Vector2(12, 24))
	var theme := Theme.new()
	theme.set_color("font_color", "Button", Color.WHITE)
	assert(theme.get_color("font_color", "Button") == Color.WHITE)
	instance.free()
	node.free()
	assert(DirAccess.remove_absolute(scene_path) == OK)
	print("UNFAIR_SMOKE_PASS: typed GDScript, lambda, native classes, theme, scene save/load")
	quit(0)
