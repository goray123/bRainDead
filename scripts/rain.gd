class_name PhysicalRain
extends Node2D
## Each drop is swept vertically through Godot's physics space. This avoids
## tunnelling at high speed without hundreds of independent rigid bodies.

const COLLISION_MASK: int = 1 | 2 | 4
const SPACING: float = 18.0
const ROW_SPACING: float = 27.0
const FALL_SPEED: float = 900.0
const TOP: float = -80.0
const BOTTOM: float = 640.0
# Each drop stores its position in x/y and its individual fall speed in z.
var drops: Array[Vector3] = []
var splashes: Array[Vector3] = []
var simulation_time: float = 0.0
var mint: MintWalker
var enabled: bool = false
var level_length: float = 2400.0
var spawn_clock: float = 0.0
var spawn_interval: float = 0.0
var primed: bool = false
var rng := RandomNumberGenerator.new()


func configure(target: MintWalker, length: float) -> void:
	mint = target
	level_length = length
	reset()


func reset(pattern_seed: int = -1) -> void:
	if pattern_seed < 0:
		rng.randomize()
	else:
		rng.seed = pattern_seed
	drops.clear()
	splashes.clear()
	simulation_time = 0.0
	spawn_clock = 0.0
	spawn_interval = _next_spawn_interval()
	primed = false
	# Keep coverage even, but scatter each drop independently within its cell.
	for col in range(int(ceil(level_length / SPACING)) + 1):
		for row in range(int(ceil((BOTTOM - TOP) / ROW_SPACING))):
			_add_drop(col, TOP + float(row) * ROW_SPACING + rng.randf_range(0.0, ROW_SPACING))
	queue_redraw()


func _next_spawn_interval() -> float:
	return ROW_SPACING / FALL_SPEED * rng.randf_range(0.8, 1.2)


func _add_drop(column: int, y: float) -> void:
	var x: float = float(column) * SPACING + rng.randf_range(-SPACING * 0.45, SPACING * 0.45)
	drops.append(Vector3(x, y, FALL_SPEED * rng.randf_range(0.88, 1.12)))


func advance(delta: float, left: float, right: float) -> void:
	if not enabled:
		return
	simulation_time += delta
	mint.rain_contact_age += delta
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.new()
	query.collision_mask = COLLISION_MASK
	query.hit_from_inside = true
	# Remove pre-filled drops already underneath cover on the first tick.
	if not primed:
		for i in range(drops.size() - 1, -1, -1):
			var at := Vector2(drops[i].x, drops[i].y)
			if at.x < left - 130.0 or at.x > right + 130.0:
				continue
			query.from = Vector2(at.x, TOP - 1.0)
			query.to = at
			if not space.intersect_ray(query).is_empty():
				drops[i] = drops[drops.size() - 1]
				drops.pop_back()
		primed = true
	# Vary timing and starting height without tying emission to collisions.
	spawn_clock += delta
	while spawn_clock >= spawn_interval:
		spawn_clock -= spawn_interval
		spawn_interval = _next_spawn_interval()
		for col in range(int(ceil(level_length / SPACING)) + 1):
			_add_drop(col, TOP - rng.randf_range(0.0, ROW_SPACING))
	for i in range(drops.size() - 1, -1, -1):
		var old := Vector2(drops[i].x, drops[i].y)
		var next: Vector2 = old + Vector2(0, drops[i].z * delta)
		query.from = old
		query.to = next
		var hit: Dictionary = {}
		if old.x >= left - 130.0 and old.x <= right + 130.0:
			hit = space.intersect_ray(query)
		if not hit.is_empty():
			if hit["collider"] == mint:
				mint.mark_rain_contact()
			if splashes.size() < 120:
				var at: Vector2 = hit["position"]
				splashes.append(Vector3(at.x, at.y, 0.13))
		if not hit.is_empty() or next.y > BOTTOM:
			drops[i] = drops[drops.size() - 1]
			drops.pop_back()
		else:
			drops[i].y = next.y
	for i in range(splashes.size() - 1, -1, -1):
		splashes[i].z -= delta
		if splashes[i].z <= 0.0:
			splashes.remove_at(i)
	if mint.active:
		mint.update_wetness(delta, mint.rain_contact_age <= MintWalker.RAIN_CONTACT_HOLD)
	queue_redraw()


func _draw() -> void:
	var camera: Camera2D = get_viewport().get_camera_2d()
	var center: float = camera.global_position.x if camera else 640.0
	var left: float = center - 710.0
	var right: float = center + 710.0
	for i in range(drops.size()):
		var drop: Vector3 = drops[i]
		var at := Vector2(drop.x, drop.y)
		if at.x < left or at.x > right:
			continue
		var variation: float = inverse_lerp(FALL_SPEED * 0.88, FALL_SPEED * 1.12, drop.z)
		var color := Color(0.63, 0.80, 0.84, lerpf(0.14, 0.32, variation))
		draw_line(at - Vector2(0, lerpf(10.0, 20.0, variation)), at, color, 1.1, true)
	for splash in splashes:
		var radius: float = (0.13 - splash.z) * 38.0
		draw_arc(Vector2(splash.x, splash.y), maxf(radius, 1.0), PI, TAU, 6, Color(0.68, 0.87, 0.91, splash.z * 3.0), 1.0, true)
