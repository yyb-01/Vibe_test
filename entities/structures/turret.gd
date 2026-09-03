class_name Turret
extends StructureBase

# res://entities/structures/turret.gd
# Automatic sentry turret targeting nearest enemy and firing projectiles per Section E.3

const ProjectileScene = preload("res://entities/combat/projectile.tscn")

var attack_range: float = 250.0
var attack_damage: float = 15.0
var attacks_per_second: float = 2.0

var current_target: Node2D = null
var _attack_timer: float = 0.0

@onready var detection_area: Area2D = $DetectionArea

var _enemies_in_range: Array[Node2D] = []

func _ready() -> void:
	super._ready()
	if structure_data != null:
		attack_range = structure_data.attack_range
		attack_damage = structure_data.attack_damage
		attacks_per_second = structure_data.attacks_per_second
		
	if detection_area != null:
		var circle := CircleShape2D.new()
		circle.radius = attack_range
		var col := CollisionShape2D.new()
		col.shape = circle
		detection_area.add_child(col)
		detection_area.collision_layer = 0
		detection_area.collision_mask = 4 # Layer 3: Enemy
		detection_area.body_entered.connect(_on_enemy_entered)
		detection_area.body_exited.connect(_on_enemy_exited)

func _physics_process(delta: float) -> void:
	if attacks_per_second <= 0.0:
		return
		
	if _attack_timer > 0.0:
		_attack_timer -= delta
		
	_validate_target()
	
	if current_target == null:
		_acquire_nearest_target()
		
	if current_target != null and _attack_timer <= 0.0:
		_fire_at_target()

func _validate_target() -> void:
	if current_target == null:
		return
	if not is_instance_valid(current_target) or not current_target.is_inside_tree():
		current_target = null
		return
		
	var health: Node = current_target.find_child("HealthComponent", true, false)
	if health != null and health.get("is_dead"):
		current_target = null
		return
		
	var dist_sq: float = global_position.distance_squared_to(current_target.global_position)
	if dist_sq > attack_range * attack_range:
		current_target = null

func _acquire_nearest_target() -> void:
	var closest_target: Node2D = null
	var min_dist_sq: float = INF
	
	var i := _enemies_in_range.size() - 1
	while i >= 0:
		var enemy: Node2D = _enemies_in_range[i]
		if not is_instance_valid(enemy) or not enemy.is_inside_tree():
			_enemies_in_range.remove_at(i)
		else:
			var health: Node = enemy.find_child("HealthComponent", true, false)
			if health != null and health.get("is_dead"):
				_enemies_in_range.remove_at(i)
			else:
				var d_sq: float = global_position.distance_squared_to(enemy.global_position)
				if d_sq <= attack_range * attack_range and d_sq < min_dist_sq:
					min_dist_sq = d_sq
					closest_target = enemy
		i -= 1
		
	current_target = closest_target

func _fire_at_target() -> void:
	if current_target == null:
		return
	_attack_timer = 1.0 / attacks_per_second
	
	var dir: Vector2 = (current_target.global_position - global_position).normalized()
	var spawn_pos: Vector2 = global_position + Vector2(0, -48) + dir * 14.0
	
	var proj = ProjectileScene.instantiate()
	proj.setup(spawn_pos, dir, attack_damage, 700.0, self)
	get_parent().add_child(proj)
	
	# Small recoil wobble
	if visual != null:
		var tween = create_tween()
		tween.tween_property(visual, "position", -dir * 2.0, 0.03)
		tween.tween_property(visual, "position", Vector2.ZERO, 0.05)

func _on_enemy_entered(body: Node2D) -> void:
	if body not in _enemies_in_range:
		_enemies_in_range.append(body)

func _on_enemy_exited(body: Node2D) -> void:
	_enemies_in_range.erase(body)
	if current_target == body:
		current_target = null
