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
		has_run = true
		_set_behavior("달리는 중")
	if not has_tripped and definition.trip_at >= 0.0 and position.x >= definition.trip_at:
		has_tripped = true
		trip_left = definition.trip_duration
		_set_behavior("넘어짐!")
		shape_node.position = Vector2(13, -14)
		(shape_node.shape as RectangleShape2D).size = Vector2(58, 26)
	if trip_left > 0.0:
		speed = 0.0
		trip_left = maxf(0.0, trip_left - delta)
		if trip_left <= 0.0:
			shape_node.position = Vector2(0, -35)
			(shape_node.shape as RectangleShape2D).size = Vector2(25, 66)
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


func _draw() -> void:
	var blue_amount: float = wetness / MAX_WETNESS
	var coat: Color = coat_color.lerp(Color("548be6"), blue_amount)
	var ink := Color("182d38")
	var skin := Color("f0ceb4").lerp(Color("8cb8e9"), blue_amount * 0.6)
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
	draw_circle(Vector2(1, -61), 12.0, skin)
	draw_colored_polygon(PackedVector2Array([Vector2(-12, -57), Vector2(-13, -68), Vector2(-5, -76), Vector2(8, -74), Vector2(14, -65), Vector2(5, -67), Vector2(-1, -59)]), ink)
	draw_circle(Vector2(10, -61), 1.5, ink)
	if is_mint:
		draw_colored_polygon(PackedVector2Array([Vector2(-12, -49), Vector2(13, -49), Vector2(13, -43), Vector2(-12, -43)]), Color("f5ca78"))
		draw_line(Vector2(-10, -46), Vector2(-19, -35), Color("f5ca78"), 5.0, true)
	draw_set_transform(Vector2.ZERO)
