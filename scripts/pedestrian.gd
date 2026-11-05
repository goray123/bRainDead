class_name CrowdWalker
extends Node2D

const MINT_SCENE: PackedScene = preload("res://scenes/mint.tscn")
const COLORS: Array[Color] = [Color("627a94"), Color("b37b81"), Color("8179a4"), Color("7b9887"), Color("c6a67e"), Color("789ba7")]
var route_start: float = 0.0
var route_span: float = 1000.0
var route_speed: float = 55.0
var route_phase: float = 0.0
var index: int = 0
var walker: MintWalker


func configure(person_index: int, level_length: float) -> void:
	index = person_index
	# Spread the larger crowd over the whole street, including the entrance.
	route_start = 40.0 + float(index % 14) * maxf(0.0, level_length - 620.0) / 13.0
	route_span = 470.0 + float(index % 4) * 50.0
	route_span = minf(route_span, level_length - route_start - 95.0)
	route_speed = 38.0 + float((index * 11) % 37)
	route_phase = float((index * 137) % 440)
	z_index = 12 if index % 3 == 0 else 5
	position.y = 600.0 + float(index % 3 - 1) * 4.0
	position.x = route_start
	walker = MINT_SCENE.instantiate() as MintWalker
	walker.is_mint = false
	walker.coat_color = COLORS[index % COLORS.size()].darkened(0.12)
	add_child(walker)
	# Canopies are visual only: no physics body, collision shape, or hitbox.
	queue_redraw()
	advance(0.0)


func advance(time: float) -> void:
	var distance: float = fposmod(route_phase + time * route_speed, route_span * 2.0)
	var outbound: bool = distance <= route_span
	position.x = route_start + (distance if outbound else route_span * 2.0 - distance)
	walker.gait = time * 7.0 + float(index)
	walker.speed = route_speed
	walker.scale.x = 1.0 if outbound else -1.0
	walker.queue_redraw()


func _draw() -> void:
	var top: float = -115.0 - float(index % 3) * 12.0
	var color: Color = COLORS[index % COLORS.size()]
	draw_line(Vector2(0, top), Vector2(0, -34), Color("354957"), 3.0, true)
	var polygon := PackedVector2Array()
	for i in range(19):
		var angle: float = PI + float(i) / 18.0 * PI
		polygon.append(Vector2(cos(angle) * 60.0, top + sin(angle) * 34.0))
	polygon.append(Vector2(-60, top))
	draw_colored_polygon(polygon, color)
	draw_polyline(polygon, color.lightened(0.25), 1.4, true)
	for x in [-60.0, -22.0, 22.0, 60.0]:
		draw_line(Vector2(0, top - 34), Vector2(x, top), color.darkened(0.25), 1.0, true)
