extends SceneTree
## Integration checks run inside the actual Godot physics engine.

const MAIN: PackedScene = preload("res://scenes/main.tscn")
const STEP: float = 1.0 / 60.0
var failures: int = 0
var checks: int = 0
var app: Node


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)


func _settle() -> void:
	await physics_frame
	await physics_frame


func _run() -> void:
	app = MAIN.instantiate()
	root.add_child(app)
	app.disable_save = true
	await _settle()
	_check(app.screen == app.Screen.TITLE, "Main scene opens on title")
	app._show_select()
	_check(app.screen == app.Screen.SELECT, "Title opens stage selection")
	_check(app._completed_count() == 0, "New game starts without completed stages")
	var locked: int = _count_disabled_buttons(app.ui)
	_check(locked == 3, "Only stage 1 is initially unlocked")

	app._load_stage(0)
	await _settle()
	var level: RainStage = app.stage
	level.set_physics_process(false)
	_check(app.screen == app.Screen.READY and level.umbrella.freeze, "Ready screen freezes simulation")
	var hit := _rain_ray(level, 190.0)
	_check(not hit.is_empty() and hit["collider"] == level.umbrella, "Player canopy physically intercepts rain")
	level.umbrella.rotation = PI
	await _settle()
	hit = _rain_ray(level, 190.0)
	_check(not hit.is_empty() and hit["collider"] == level.umbrella, "Upside-down player canopy still intercepts rain")
	level.umbrella.position.x = 600.0
	await _settle()
	hit = _rain_ray(level, 190.0)
	_check(not hit.is_empty() and hit["collider"] == level.mint, "Uncovered rain reaches Mint")

	var mint: MintWalker = level.mint
	for i in range(60):
		mint.update_wetness(STEP, true)
	_check(is_equal_approx(mint.wetness, 1.0), "One second of rain gives exactly one second of wetness")
	for i in range(30):
		mint.update_wetness(STEP, false)
	_check(is_equal_approx(mint.wetness, 0.5), "Half a second sheltered removes half a second of wetness")
	for i in range(120):
		mint.update_wetness(STEP, false)
	_check(is_zero_approx(mint.wetness), "Drying clamps at zero")
	for i in range(120):
		mint.update_wetness(STEP, true)
	_check(is_equal_approx(mint.wetness, 2.0) and mint.soaked_emitted, "Game over fires at two seconds")

	app._load_stage(3)
	await _settle()
	level = app.stage
	level.set_physics_process(false)
	level.umbrella.position.x = 600.0
	var person: CrowdWalker = level.crowd[0]
	person.position = Vector2(190, 600)
	await _settle()
	hit = _rain_ray(level, 190.0)
	_check(not hit.is_empty() and hit["collider"] == level.mint, "Crowd umbrella and pedestrian do not shelter Mint")
	var first_positions: Array[float] = []
	for pedestrian in level.crowd:
		pedestrian.advance(6.25)
		first_positions.append(pedestrian.position.x)
	var same_routes: bool = true
	for i in range(level.crowd.size()):
		level.crowd[i].advance(0.0)
		level.crowd[i].advance(6.25)
		same_routes = same_routes and is_equal_approx(level.crowd[i].position.x, first_positions[i])
	_check(same_routes, "Every pedestrian follows a reproducible route")
	var original_drops: Array[Vector2] = level.rain.drops.duplicate()
	level.rain.reset()
	_check(original_drops == level.rain.drops, "Rain starts from the identical fixed pattern")
	# Exercise actual drop collisions at two densities, not a mocked coverage flag.
	level.mint.active = true
	level.rain.enabled = true
	level.mint.wetness = 0.0
	level.mint.rain_contact_age = 100.0
	for i in range(60):
		level.rain.advance(STEP, 0.0, 1280.0)
	var normal_wetness: float = level.mint.wetness
	level.rain.reset()
	var duplicate_drops: Array[Vector2] = level.rain.drops.duplicate()
	level.rain.drops.append_array(duplicate_drops)
	level.rain.drops.append_array(duplicate_drops)
	level.mint.wetness = 0.0
	level.mint.rain_contact_age = 100.0
	for i in range(60):
		level.rain.advance(STEP, 0.0, 1280.0)
	_check(absf(level.mint.wetness - normal_wetness) <= STEP, "Tripling rain density does not triple wetness")
	_check(normal_wetness > 0.90 and normal_wetness <= 1.00001, "Actual uncovered drops produce one second per second (measured %.4f)" % normal_wetness)

	var run_positions: Array[float] = []
	var trip_positions: Array[float] = []
	for attempt in range(2):
		app._load_stage(2)
		await _settle()
		level = app.stage
		level.set_physics_process(false)
		level.mint.active = true
		var trip_ticks: int = 0
		for tick in range(2400):
			var ran_before: bool = level.mint.has_run
			var tripped_before: bool = level.mint.has_tripped
			level.mint.advance(STEP)
			if level.mint.has_run and not ran_before:
				run_positions.append(level.mint.position.x)
			if level.mint.has_tripped and not tripped_before:
				trip_positions.append(level.mint.position.x)
			if level.mint.trip_left > 0.0:
				trip_ticks += 1
				_check_if_moving_while_tripped(level.mint)
			if level.mint.finished:
				break
		_check(trip_ticks >= 154 and trip_ticks <= 157, "Trip stops Mint for the configured 2.6 seconds")
		_check(level.completion_pending, "Mint can reach the destination after getting up")
	_check(run_positions.size() == 2 and is_equal_approx(run_positions[0], run_positions[1]), "Run event occurs at the same position on retry")
	_check(trip_positions.size() == 2 and is_equal_approx(trip_positions[0], trip_positions[1]), "Trip event occurs at the same position on retry")

	app._load_stage(0, true)
	await _settle()
	_check(app.screen == app.Screen.PLAYING, "Start enters gameplay")
	app._pause()
	var paused_time: float = app.stage.elapsed
	await _settle()
	_check(app.screen == app.Screen.PAUSED and is_equal_approx(app.stage.elapsed, paused_time), "Pause freezes stage time and physics")
	app._resume()
	_check(app.screen == app.Screen.PLAYING and not app.stage.umbrella.freeze, "Resume restores physics")
	app._retry()
	_check(app.stage.mint.position == Vector2(190, 600) and app.stage.mint.wetness == 0.0, "Retry resets Mint and wetness")
	_check(app.stage.umbrella.rotation == 0.0 and app.stage.umbrella.linear_velocity == Vector2.ZERO, "Retry resets umbrella rotation and momentum")
	app.stage.stop()
	app._on_cleared()
	_check(app.completed == 1, "Clear records completion")
	app._show_ad()
	app._process(2.01)
	_check(app.screen == app.Screen.SELECT, "Ad placeholder returns to stage selection")
	_check(_count_disabled_buttons(app.ui) == 2, "Stage 1 clear unlocks exactly stage 2")
	app.save_path = "user://integration-test-progress.cfg"
	app.disable_save = false
	app.completed = 3
	app.attempts.assign([2, 3, 0, 0])
	app._save_progress()
	app.completed = 0
	app.attempts.assign([0, 0, 0, 0])
	app._load_progress()
	_check(app.completed == 3 and app.attempts == [2, 3, 0, 0], "Completion and attempts persist across reload")
	app.disable_save = true
	app.queue_free()
	await process_frame
	await process_frame
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _check_if_moving_while_tripped(mint: MintWalker) -> void:
	if mint.speed != 0.0:
		failures += 1
		push_error("Mint moved during a trip")


func _rain_ray(level: RainStage, x: float) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(Vector2(x, 330), Vector2(x, 595), PhysicalRain.COLLISION_MASK)
	return level.get_world_2d().direct_space_state.intersect_ray(query)


func _count_disabled_buttons(node: Node) -> int:
	var count: int = 1 if node is Button and node.disabled else 0
	for child in node.get_children():
		count += _count_disabled_buttons(child)
	return count
