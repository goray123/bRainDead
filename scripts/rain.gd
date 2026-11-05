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
var drops: Array[Vector2] = []
var splashes: Array[Vector3] = []
var simulation_time: float = 0.0
var mint: MintWalker
var enabled: bool = false
var level_length: float = 2400.0
var spawn_clock: float = 0.0
var primed: bool = false


func configure(target: MintWalker, length: float) -> void:
	mint = target
	level_length = length
	reset()


func reset() -> void:
	drops.clear()
	splashes.clear()
	simulation_time = 0.0
	spawn_clock = 0.0
	primed = false
	# A fixed lattice, including phase offsets, is identical on every restart.
	for col in range(int(ceil(level_length / SPACING)) + 1):
		for row in range(27):
			var x: float = float(col) * SPACING + float((col * 11) % 7)
			drops.append(Vector2(x, TOP + float(row) * ROW_SPACING))
	queue_redraw()


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
			var at: Vector2 = drops[i]
			if at.x < left - 130.0 or at.x > right + 130.0:
				continue
			query.from = Vector2(at.x, TOP - 1.0)
			query.to = at
			if not space.intersect_ray(query).is_empty():
				drops[i] = drops[drops.size() - 1]
				drops.pop_back()
		primed = true
	# Emit on a fixed schedule, rather than recycling a hit drop immediately.
	# This keeps the stream evenly spaced regardless of where a drop collided.
	spawn_clock += delta
	while spawn_clock >= ROW_SPACING / FALL_SPEED:
		spawn_clock -= ROW_SPACING / FALL_SPEED
		for col in range(int(ceil(level_length / SPACING)) + 1):
			drops.append(Vector2(float(col) * SPACING + float((col * 11) % 7), TOP))
	for i in range(drops.size() - 1, -1, -1):
		var old: Vector2 = drops[i]
		var next: Vector2 = old + Vector2(0, FALL_SPEED * delta)
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
			drops[i] = next
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
		var at: Vector2 = drops[i]
		if at.x < left or at.x > right:
			continue
		var color := Color(0.63, 0.80, 0.84, 0.32 if i % 3 == 0 else 0.16)
		draw_line(at - Vector2(0, 10.0 + float(i % 3) * 4.0), at, color, 1.1, true)
	for splash in splashes:
		var radius: float = (0.13 - splash.z) * 38.0
		draw_arc(Vector2(splash.x, splash.y), maxf(radius, 1.0), PI, TAU, 6, Color(0.68, 0.87, 0.91, splash.z * 3.0), 1.0, true)
