class_name MintWalker
extends AnimatableBody2D

signal behavior_changed(behavior: String)
signal destination_reached
signal soaked

const MAX_WETNESS: float = 2.0
const RAIN_CONTACT_HOLD: float = 0.055
var definition: StageDefinition
var active: bool = false
var wetness: float = 0.0
var rain_contact_age: float = 100.0
var touching_rain: bool = false
var speed: float = 0.0
var has_run: bool = false
var has_prepared_run: bool = false
var run_prep_left: float = 0.0
var has_tripped: bool = false
var trip_left: float = 0.0
var gait: float = 0.0
var finished: bool = false
var soaked_emitted: bool = false
var behavior: String = "걷는 중"
var coat_color: Color = Color("91dac1")
var is_mint: bool = true

@onready var shape_node: CollisionShape2D = $BodyShape


func _ready() -> void:
	collision_layer = 4 if is_mint else 8
	collision_mask = 0
	sync_to_physics = false
	queue_redraw()


func mark_rain_contact() -> void:
	rain_contact_age = 0.0


func update_wetness(delta: float, exposed: bool) -> void:
	# Called exactly once per physics tick, never once per raindrop.
	touching_rain = exposed
	wetness = clampf(wetness + (delta if exposed else -delta), 0.0, MAX_WETNESS)
	if wetness >= MAX_WETNESS - 0.00001 and not soaked_emitted:
		soaked_emitted = true
		finished = true
		soaked.emit()


func advance(delta: float) -> void:
	if not active or finished or definition == null:
		return
	if not has_run and definition.run_at >= 0.0 and position.x >= definition.run_at:
		if not has_prepared_run:
			has_prepared_run = true
			run_prep_left = maxf(0.0, definition.run_prep_duration)
			if run_prep_left > 0.0:
				_set_behavior("출발 준비!")
				_set_body_shape(Vector2(-4, -32), Vector2(88, 64))
		if run_prep_left > 0.0:
			speed = 0.0
			run_prep_left = maxf(0.0, run_prep_left - delta)
			if run_prep_left < 0.00001:
				run_prep_left = 0.0
				has_run = true
				_set_body_shape(Vector2(0, -35), Vector2(25, 66))
				_set_behavior("달리는 중")
			queue_redraw()
			return
		has_run = true
		_set_behavior("달리는 중")
	if not has_tripped and definition.trip_at >= 0.0 and position.x >= definition.trip_at:
		has_tripped = true
		trip_left = definition.trip_duration
		_set_behavior("넘어짐!")
		_set_body_shape(Vector2(13, -14), Vector2(58, 26))
	if trip_left > 0.0:
		speed = 0.0
		trip_left = maxf(0.0, trip_left - delta)
		if trip_left <= 0.0:
			_set_body_shape(Vector2(0, -35), Vector2(25, 66))
			_set_behavior("걷는 중")
	else:
		speed = definition.run_speed if has_run and not has_tripped else definition.walk_speed
		position.x += speed * delta
		gait += delta * (13.0 if speed > definition.walk_speed + 1.0 else 7.5)
	if position.x >= definition.length - 145.0:
		finished = true
		destination_reached.emit()
	queue_redraw()


func _set_behavior(value: String) -> void:
	behavior = value
	behavior_changed.emit(value)


func _set_body_shape(at: Vector2, dimensions: Vector2) -> void:
	shape_node.position = at
	(shape_node.shape as RectangleShape2D).size = dimensions


func _draw() -> void:
	var blue_amount: float = wetness / MAX_WETNESS
	var coat: Color = coat_color.lerp(Color("548be6"), blue_amount)
	var ink := Color("182d38")
	var skin := Color("f0ceb4").lerp(Color("8cb8e9"), blue_amount * 0.6)
	if run_prep_left > 0.0:
		_draw_run_start_pose(coat, skin, ink)
		return
	draw_set_transform(Vector2(13, -13) if trip_left > 0.0 else Vector2.ZERO, -PI / 2.0 if trip_left > 0.0 else 0.0)
	var step: float = sin(gait) * (10.0 if speed > 0.0 else 0.0)
	draw_line(Vector2(-7, -22), Vector2(-8 + step, -3), ink, 7.0, true)
	draw_line(Vector2(7, -22), Vector2(8 - step, -3), ink, 7.0, true)
	draw_line(Vector2(-8 + step, -2), Vector2(-2 + step, -2), Color("dce9db"), 5.0, true)
	draw_line(Vector2(8 - step, -2), Vector2(14 - step, -2), Color("dce9db"), 5.0, true)
	var torso := PackedVector2Array([Vector2(-13, -49), Vector2(9, -49), Vector2(17, -21), Vector2(-17, -21)])
	draw_colored_polygon(torso, coat)
	draw_line(Vector2(-2, -46), Vector2(1, -22), coat.darkened(0.18), 1.3, true)
	draw_line(Vector2(11, -44), Vector2(18 + step * 0.35, -30), coat.darkened(0.16), 6.0, true)
	_draw_head(Vector2(1, -61), skin, ink)
	if is_mint:
		draw_colored_polygon(PackedVector2Array([Vector2(-12, -49), Vector2(13, -49), Vector2(13, -43), Vector2(-12, -43)]), Color("f5ca78"))
		draw_line(Vector2(-10, -46), Vector2(-19, -35), Color("f5ca78"), 5.0, true)
	draw_set_transform(Vector2.ZERO)


func _draw_run_start_pose(coat: Color, skin: Color, ink: Color) -> void:
	# Sprinter's crouch: rear leg extended, front knee bent, fingertips down.
	draw_polyline(PackedVector2Array([Vector2(-11, -32), Vector2(-28, -17), Vector2(-43, -4)]), ink, 7.0, true)
	draw_line(Vector2(-45, -3), Vector2(-32, -3), Color("dce9db"), 5.0, true)
	draw_polyline(PackedVector2Array([Vector2(-9, -31), Vector2(12, -21), Vector2(1, -4)]), ink, 7.0, true)
	draw_line(Vector2(-2, -3), Vector2(12, -3), Color("dce9db"), 5.0, true)
	draw_polyline(PackedVector2Array([Vector2(9, -39), Vector2(19, -20), Vector2(15, -4)]), coat.darkened(0.25), 5.0, true)
	draw_line(Vector2(14, -3), Vector2(21, -2), skin, 3.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(-18, -35), Vector2(12, -47), Vector2(22, -32), Vector2(-6, -22)]), coat)
	draw_line(Vector2(-11, -32), Vector2(13, -39), coat.darkened(0.18), 1.3, true)
	draw_polyline(PackedVector2Array([Vector2(18, -37), Vector2(28, -21), Vector2(28, -4)]), coat.darkened(0.12), 6.0, true)
	draw_line(Vector2(27, -3), Vector2(36, -2), skin, 3.5, true)
	_draw_head(Vector2(28, -48), skin, ink)
	if is_mint:
		draw_line(Vector2(12, -45), Vector2(21, -39), Color("f5ca78"), 6.0, true)
		draw_polyline(PackedVector2Array([Vector2(14, -44), Vector2(1, -48), Vector2(-10, -45)]), Color("f5ca78"), 4.0, true)


func _draw_head(at: Vector2, skin: Color, ink: Color) -> void:
	draw_circle(at, 12.0, skin)
	var hair := PackedVector2Array()
	for offset in [Vector2(-13, 4), Vector2(-14, -7), Vector2(-6, -15), Vector2(7, -13), Vector2(13, -4), Vector2(4, -6), Vector2(-2, 2)]:
		hair.append(at + offset)
	draw_colored_polygon(hair, ink)
	draw_circle(at + Vector2(9, 0), 1.5, ink)
