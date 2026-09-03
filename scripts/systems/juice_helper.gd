class_name JuiceHelper
extends RefCounted

const HitFlashShader = preload("res://assets/shaders/hit_flash.gdshader")

static func vfx(source: Node) -> VFXPool:
	if source == null or source.get_tree() == null:
		return null
	return source.get_tree().get_first_node_in_group("vfx_pool") as VFXPool

static func shot_feedback(source: Node, muzzle_position: Vector2, direction: Vector2) -> void:
	var pool := vfx(source)
	if pool != null:
		pool.spawn_muzzle_flash(muzzle_position, direction)
		pool.spawn_casing(muzzle_position, direction)
	add_trauma(source, 0.075, -direction)

static func hit_feedback(source: Node, hit_position: Vector2, direction: Vector2, damage: float, critical: bool = false) -> void:
	var pool := vfx(source)
	if pool != null:
		pool.spawn_impact(hit_position, direction, Color(0.95, 0.28, 0.2, 1.0))
		pool.spawn_damage_text(hit_position, damage, critical)
	add_trauma(source, 0.035 if not critical else 0.06, direction)

static func white_flash(item: CanvasItem, duration: float = 0.05) -> void:
	if item == null:
		return
	var material := item.material as ShaderMaterial
	if material == null or material.shader != HitFlashShader:
		material = ShaderMaterial.new()
		material.shader = HitFlashShader
		item.material = material
	material.set_shader_parameter("flash_amount", 1.0)
	var tween := item.create_tween()
	tween.tween_method(func(value: float): material.set_shader_parameter("flash_amount", value), 1.0, 0.0, duration)

static func hitstop(source: Node, duration: float = 0.045) -> void:
	if source == null or source.get_tree() == null:
		return
	var tree := source.get_tree()
	var token := int(tree.get_meta("juice_hitstop_token", 0)) + 1
	if token == 1:
		tree.set_meta("juice_hitstop_scale", Engine.time_scale)
	tree.set_meta("juice_hitstop_token", token)
	Engine.time_scale = 0.04
	var timer := tree.create_timer(duration, true, false, true)
	timer.timeout.connect(func():
		if is_instance_valid(tree) and int(tree.get_meta("juice_hitstop_token", 0)) == token:
			Engine.time_scale = float(tree.get_meta("juice_hitstop_scale", 1.0))
			tree.set_meta("juice_hitstop_token", 0)
	)

static func add_trauma(source: Node, amount: float, direction: Vector2 = Vector2.ZERO) -> void:
	if source == null or source.get_tree() == null:
		return
	var camera := source.get_tree().get_first_node_in_group("camera_trauma") as CameraTrauma
	if camera != null:
		camera.add_trauma(amount, direction)
