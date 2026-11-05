class_name RainStage
extends Node2D

signal failed
signal cleared
signal behavior_changed(value: String)

const MINT_SCENE: PackedScene = preload("res://scenes/mint.tscn")
const UMBRELLA_SCENE: PackedScene = preload("res://scenes/umbrella.tscn")
var definition: StageDefinition
var mint: MintWalker
var umbrella: WindUmbrella
var rain: PhysicalRain
var camera: Camera2D
var crowd: Array[CrowdWalker] = []
var active: bool = false
var attract: bool = false
var elapsed: float = 0.0
var completion_pending: bool = false
var fail_pending: bool = false
var wind_override: float = NAN


func configure(data: StageDefinition, title_preview: bool = false) -> void:
	definition = data
	attract = title_preview
	var art := RainCity.new()
	art.definition = definition
	add_child(art)
	_add_solid(Rect2(-180, 600, definition.length + 360, 150))
	_add_solid(Rect2(-180, -170, 60, 850))
	_add_solid(Rect2(definition.length + 120, -170, 60, 850))
	_add_solid(Rect2(-180, -170, definition.length + 360, 35))
	for rect in definition.sign_rects:
		_add_solid(rect)
	mint = MINT_SCENE.instantiate() as MintWalker
	mint.position = Vector2(190, 600)
	mint.definition = definition
	mint.z_index = 10
	add_child(mint)
	mint.destination_reached.connect(func() -> void: completion_pending = true)
	mint.soaked.connect(func() -> void: fail_pending = true)
	mint.behavior_changed.connect(func(value: String) -> void: behavior_changed.emit(value))
	umbrella = UMBRELLA_SCENE.instantiate() as WindUmbrella
	umbrella.position = definition.umbrella_start
	umbrella.z_index = 15
	add_child(umbrella)
	for i in range(definition.crowd_count):
		var person := CrowdWalker.new()
		add_child(person)
		person.configure(i, definition.length)
		crowd.append(person)
	rain = PhysicalRain.new()
	rain.z_index = 25
	add_child(rain)
	rain.configure(mint, definition.length)
	camera = Camera2D.new()
	camera.position = Vector2(640, 360)
	camera.position_smoothing_enabled = false
	add_child(camera)
	camera.make_current()
	if attract:
		mint.position.x = 966.0
		umbrella.position = Vector2(966, 438)
		rain.enabled = true
	queue_redraw()


func start() -> void:
	active = true
	attract = false
	mint.active = true
	umbrella.active = true
	umbrella.freeze = false
	rain.enabled = true
	mint.rain_contact_age = 100.0


func stop() -> void:
	active = false
	mint.active = false
	umbrella.active = false
	umbrella.freeze = true
	rain.enabled = false


func _physics_process(delta: float) -> void:
	if not active and not attract:
		return
	elapsed += delta
	if active:
		mint.advance(delta)
		for person in crowd:
			person.advance(elapsed)
		umbrella.wind = Input.get_axis("wind_left", "wind_right") if is_nan(wind_override) else wind_override
		camera.position.x = clampf(mint.position.x + 310.0, 640.0, definition.length - 640.0)
		camera.force_update_scroll()
	rain.advance(delta, camera.position.x - 640.0, camera.position.x + 640.0)
	if active:
		if fail_pending:
			stop()
			failed.emit()
		elif completion_pending:
			stop()
			cleared.emit()
	queue_redraw()


func _add_solid(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 2
	body.position = rect.get_center()
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = rect.size
	shape.shape = rectangle
	body.add_child(shape)
	add_child(body)


func _draw() -> void:
	if mint == null:
		return
	# Only the shadow is marked, so stage 4 still hides Mint in the crowd.
	draw_set_transform(Vector2(mint.position.x, 602), 0, Vector2(24, 3))
	draw_circle(Vector2.ZERO, 1.0, Color("08151c", 0.40))
	draw_set_transform(Vector2.ZERO)
	if active and absf(umbrella.wind) > 0.1:
		for i in range(5):
			var phase: float = fposmod(elapsed * 150.0 + i * 39.0, 150.0)
			var start := umbrella.position + Vector2((phase - 120.0) * umbrella.wind, -60 + i * 23)
			draw_line(start, start + Vector2(25.0 * umbrella.wind, 0), Color("b7e2d5", 0.35), 1.5, true)
