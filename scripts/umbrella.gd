class_name WindUmbrella
extends RigidBody2D
## Rotation never disables rain blocking, including when upside down.

@export var horizontal_force: float = 480.0
@export var lift_force: float = 688.8
@export var turn_force: float = 1600.0
@export var max_horizontal_speed: float = 330.0
@export var max_rise_speed: float = 210.0
@export var max_fall_speed: float = 850.0
@export var canopy_color: Color = Color("f3be68")
var wind: float = 0.0
var active: bool = false


func _ready() -> void:
	mass = 1.0
	inertia = 1300.0
	gravity_scale = 2.4
	linear_damp = 0.18
	linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	angular_damp = 1.9
	angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	collision_layer = 2
	collision_mask = 1 | 2
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	can_sleep = false
	var material := PhysicsMaterial.new()
	material.friction = 0.32
	material.bounce = 0.12
	physics_material_override = material
	freeze = true
	queue_redraw()


func _physics_process(_delta: float) -> void:
	if active and not freeze:
		apply_central_force(Vector2(wind * horizontal_force, -absf(wind) * lift_force))
		apply_torque(wind * turn_force)


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# Fast vertical motion must not consume the horizontal speed budget.
	state.linear_velocity.x = clampf(state.linear_velocity.x, -max_horizontal_speed, max_horizontal_speed)
	state.linear_velocity.y = clampf(state.linear_velocity.y, -max_rise_speed, max_fall_speed)
	state.angular_velocity = clampf(state.angular_velocity, -2.2, 2.2)


func _draw() -> void:
	draw_line(Vector2(0, -9), Vector2(0, 60), Color("35474f"), 4.0, true)
	draw_arc(Vector2(8, 59), 8.0, 0.0, PI, 14, Color("35474f"), 4.0, true)
	draw_line(Vector2(16, 59), Vector2(16, 54), Color("35474f"), 4.0, true)
	var canopy := PackedVector2Array()
	for i in range(25):
		var angle: float = PI + float(i) / 24.0 * PI
		canopy.append(Vector2(cos(angle) * 76.0, sin(angle) * 40.0))
	canopy.append(Vector2(76, 0))
	canopy.append(Vector2(-76, 0))
	draw_colored_polygon(canopy, canopy_color)
	var left_panel := PackedVector2Array([Vector2(-76, 0), Vector2(-52, -29), Vector2(0, -40), Vector2(-27, 0)])
	draw_colored_polygon(left_panel, canopy_color.darkened(0.13))
	var right_panel := PackedVector2Array([Vector2(0, -40), Vector2(53, -29), Vector2(76, 0), Vector2(29, 0)])
	draw_colored_polygon(right_panel, canopy_color.lightened(0.09))
	draw_polyline(canopy, Color("ffe6b5"), 1.5, true)
	for x in [-76.0, -27.0, 29.0, 76.0]:
		draw_line(Vector2(0, -40), Vector2(x, 0), Color(0.36, 0.30, 0.21, 0.35), 1.2, true)
	draw_circle(Vector2(0, -42), 3.0, Color("ffedc9"))
	for i in range(3):
		var start := Vector2(-76 + i * 50.7, 0)
		draw_arc(start + Vector2(25.3, -7), 26.3, 0.27, PI - 0.27, 12, canopy_color.darkened(0.24), 2.0, true)
