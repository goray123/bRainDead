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
	var visible_people: int = 0
	var visual_only_canopies: bool = true
	for pedestrian in level.crowd:
		if pedestrian.position.x >= 0.0 and pedestrian.position.x <= 1280.0:
			visible_people += 1
		for body in pedestrian.find_children("*", "CollisionObject2D", true, false):
			visual_only_canopies = visual_only_canopies and body == pedestrian.walker
	_check(visible_people >= 25 and visible_people <= 45, "Stage 4 spreads the reduced crowd across the street (%d people visible)" % visible_people)
	_check(visual_only_canopies, "Every crowd canopy has no physics body or hitbox")
	var canopy_path := PhysicsShapeQueryParameters2D.new()
	canopy_path.shape = (level.umbrella.get_node("Canopy") as CollisionShape2D).shape
	canopy_path.transform = Transform2D(0.0, person.position + Vector2(-110, -115))
	canopy_path.motion = Vector2(220, 0)
	canopy_path.collision_mask = 1 | 2 | 4 | 8 | 16
	var travel: PackedFloat32Array = level.get_world_2d().direct_space_state.cast_motion(canopy_path)
	_check(travel.size() == 2 and is_equal_approx(travel[0], 1.0), "Player canopy can sweep straight through a crowd umbrella")
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
	var original_drops: Array[Vector3] = level.rain.drops.duplicate()
	level.rain.reset()
	_check(original_drops != level.rain.drops, "Rain gets a new scattered pattern on retry")
	level.rain.reset(41)
	var seeded_drops: Array[Vector3] = level.rain.drops.duplicate()
	level.rain.enabled = true
	for i in range(12):
		level.rain.advance(STEP, 0.0, 1280.0)
	var advanced_drops: Array[Vector3] = level.rain.drops.duplicate()
	level.rain.reset(41)
	_check(seeded_drops == level.rain.drops, "A test seed reproduces initial rain positions and speeds")
	for i in range(12):
		level.rain.advance(STEP, 0.0, 1280.0)
	_check(advanced_drops == level.rain.drops, "A test seed reproduces moving rain and future emissions")
	# Exercise actual drop collisions at two densities, not a mocked coverage flag.
	level.rain.reset(41)
	level.mint.active = true
	level.rain.enabled = true
	level.mint.wetness = 0.0
	level.mint.rain_contact_age = 100.0
	for i in range(60):
		level.rain.advance(STEP, 0.0, 1280.0)
	var normal_wetness: float = level.mint.wetness
	level.rain.reset(41)
	var duplicate_drops: Array[Vector3] = level.rain.drops.duplicate()
	level.rain.drops.append_array(duplicate_drops)
	level.rain.drops.append_array(duplicate_drops)
	level.mint.wetness = 0.0
	level.mint.rain_contact_age = 100.0
	for i in range(60):
		level.rain.advance(STEP, 0.0, 1280.0)
	_check(absf(level.mint.wetness - normal_wetness) <= STEP, "Tripling rain density does not triple wetness")
	_check(normal_wetness > 0.90 and normal_wetness <= 1.00001, "Actual uncovered drops produce one second per second (measured %.4f)" % normal_wetness)
	for pattern_seed in [7, 123, 4096]:
		level.rain.reset(pattern_seed)
		level.mint.wetness = 0.0
		level.mint.rain_contact_age = 100.0
		for i in range(60):
			level.rain.advance(STEP, 0.0, 1280.0)
		_check(level.mint.wetness > 0.90, "Random rain keeps uncovered wetness consistent (seed %d: %.4f)" % [pattern_seed, level.mint.wetness])
	level.umbrella.position.x = 190.0
	for canopy_angle in [0.0, PI]:
		level.umbrella.rotation = canopy_angle
		await _settle()
		level.rain.reset(123)
		level.mint.wetness = 0.0
		level.mint.rain_contact_age = 100.0
		for i in range(60):
			level.rain.advance(STEP, 0.0, 1280.0)
		_check(is_zero_approx(level.mint.wetness), "Scattered rain is intercepted by the canopy at angle %.2f" % canopy_angle)

	await _check_run_start_sequence(1)
	await _check_run_start_sequence(2)

	app._load_stage(0, true)
	await _settle()
	_check(app.screen == app.Screen.PLAYING, "Start enters gameplay")
	for key in [KEY_LEFT, KEY_RIGHT, KEY_A, KEY_D]:
		var key_event := InputEventKey.new()
		key_event.keycode = key
		key_event.physical_keycode = key
		key_event.pressed = true
		Input.parse_input_event(key_event)
		Input.flush_buffered_events()
		await _settle()
		var expected: float = -1.0 if key in [KEY_LEFT, KEY_A] else 1.0
		_check(is_equal_approx(app.stage.umbrella.wind, expected), "Keyboard key %s drives wind" % OS.get_keycode_string(key))
		var release_event := key_event.duplicate() as InputEventKey
		release_event.pressed = false
		Input.parse_input_event(release_event)
		Input.flush_buffered_events()
		await _settle()
		_check(is_zero_approx(app.stage.umbrella.wind), "Releasing %s stops wind input" % OS.get_keycode_string(key))
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
	var ad: VideoAd = app.ad_screen
	ad.set_process(false)
	_check(app.screen == app.Screen.AD and ad.remaining_seconds() == 10 and ad.skip_button.disabled, "Ad starts with a locked ten-second skip countdown")
	_check(not app.stage.active and (not app.sound.ambience.is_playing() or app.sound.ambience.stream_paused), "Ad pauses rain audio and stage simulation")
	ad.request_skip()
	_check(app.screen == app.Screen.AD, "Skip handler rejects attempts before ten seconds")
	for remaining in [9, 8, 7, 6, 5, 4, 3, 2, 1]:
		ad._process(1.0)
		_check(ad.remaining_seconds() == remaining and ad.skip_button.disabled and ad.skip_button.text == "%d초 뒤 스킵 가능" % remaining, "Ad counts down to %d with skip disabled" % remaining)
	ad._process(0.99)
	_check(ad.skip_button.disabled, "Skip remains locked just before ten seconds")
	ad._process(0.01)
	_check(not ad.skip_button.disabled and ad.skip_button.text == "건너뛰기", "At zero the countdown becomes an enabled skip button")
	ad._process(10.0)
	_check(app.screen == app.Screen.AD, "Ad waits for the player to press skip after the countdown")
	ad.skip_button.pressed.emit()
	_check(app.screen == app.Screen.SELECT and app.ad_screen == null and not app.sound.ambience.stream_paused, "Skip button returns to stage selection and restores rain audio")
	app._show_ad()
	ad = app.ad_screen
	ad.set_process(false)
	_check(ad.remaining_seconds() == 10 and ad.skip_button.disabled, "The next ad starts a fresh ten-second countdown")
	ad._on_web_message("invalid JSON")
	ad._on_web_message('{"type":"player_error","code":100}')
	ad._on_web_message('{"type":"skip"}')
	await _settle()
	_check(app.screen == app.Screen.AD and ad.skip_button.disabled, "Player errors and early web messages cannot bypass the skip gate")
	ad._process(5.0)
	ad.request_skip()
	_check(app.screen == app.Screen.AD and ad.skip_button.disabled, "Five seconds no longer unlocks ad skipping")
	ad._process(5.0)
	ad._on_web_message('{"type":"skip"}')
	await _settle()
	_check(app.screen == app.Screen.SELECT and app.ad_screen == null, "Web skip button returns to stage selection after ten seconds")
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
	await _check_umbrella_motion()
	app.queue_free()
	await process_frame
	await process_frame
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _check_run_start_sequence(stage_index: int) -> void:
	var prep_positions: Array[float] = []
	var run_positions: Array[float] = []
	var trip_positions: Array[float] = []
	for attempt in range(2):
		app._load_stage(stage_index)
		await _settle()
		var level: RainStage = app.stage
		level.set_physics_process(false)
		var mint: MintWalker = level.mint
		mint.active = true
		var prep_ticks: int = 0
		var trip_ticks: int = 0
		var stays_still: bool = true
		var announces_prep: bool = true
		for tick in range(2400):
			var prepared_before: bool = mint.has_prepared_run
			var preparing_before: bool = mint.run_prep_left > 0.0
			var ran_before: bool = mint.has_run
			var tripped_before: bool = mint.has_tripped
			var previous_x: float = mint.position.x
			mint.advance(STEP)
			if mint.has_prepared_run and not prepared_before:
				prep_positions.append(mint.position.x)
			if mint.run_prep_left > 0.0 or preparing_before:
				prep_ticks += 1
				stays_still = stays_still and is_zero_approx(mint.speed) and is_equal_approx(mint.position.x, previous_x)
			if mint.run_prep_left > 0.0:
				announces_prep = announces_prep and mint.behavior == "출발 준비!" and not mint.has_run
			if mint.has_run and not ran_before:
				run_positions.append(mint.position.x)
				_check((mint.shape_node.shape as RectangleShape2D).size == Vector2(25, 66), "Stage %d restores upright rain hitbox on sprint start" % (stage_index + 1))
			if mint.has_tripped and not tripped_before:
				trip_positions.append(mint.position.x)
			if mint.trip_left > 0.0:
				trip_ticks += 1
				_check_if_moving_while_tripped(mint)
			if mint.finished:
				break
		_check(prep_ticks > 0 and absf(prep_ticks * STEP - level.definition.run_prep_duration) <= STEP, "Stage %d holds the sprinter pose for the configured duration" % (stage_index + 1))
		_check(stays_still and announces_prep, "Stage %d stops and announces preparation before running" % (stage_index + 1))
		if stage_index == 2:
			_check(trip_ticks >= 154 and trip_ticks <= 157, "Trip stops Mint for the configured 2.6 seconds")
		_check(level.completion_pending, "Stage %d reaches home after preparing and running" % (stage_index + 1))
	_check(prep_positions.size() == 2 and is_equal_approx(prep_positions[0], prep_positions[1]), "Stage %d prepares at the same position on retry" % (stage_index + 1))
	_check(run_positions.size() == 2 and is_equal_approx(run_positions[0], run_positions[1]), "Stage %d runs at the same position on retry" % (stage_index + 1))
	if stage_index == 2:
		_check(trip_positions.size() == 2 and is_equal_approx(trip_positions[0], trip_positions[1]), "Trip event occurs at the same position on retry")


func _check_umbrella_motion() -> void:
	# Measure actual engine motion in free space, without stage collisions.
	var falling := RainStage.UMBRELLA_SCENE.instantiate() as WindUmbrella
	falling.position = Vector2(-2000, -2000)
	root.add_child(falling)
	falling.collision_mask = 0
	falling.active = true
	falling.freeze = false
	falling.linear_velocity = Vector2(200, 0)
	for i in range(60):
		await physics_frame
	_check(falling.linear_velocity.x > 160.0 and falling.linear_velocity.x < 200.0, "Released umbrella retains over 80 percent of horizontal speed after one second (%.1f)" % falling.linear_velocity.x)
	_check(falling.position.x > -1840.0, "Momentum carries the released umbrella over 160 pixels")
	_check(falling.linear_velocity.y > 300.0 and falling.position.y > -1850.0, "Unpowered umbrella falls rapidly (%.1f px/s)" % falling.linear_velocity.y)
	falling.queue_free()
	var rising := RainStage.UMBRELLA_SCENE.instantiate() as WindUmbrella
	rising.position = Vector2(-3000, -3000)
	root.add_child(rising)
	rising.collision_mask = 0
	rising.active = true
	rising.freeze = false
	rising.wind = 1.0
	for i in range(60):
		await physics_frame
	var rise_distance: float = -3000.0 - rising.position.y
	_check(rising.linear_velocity.y < -200.0 and rising.linear_velocity.y >= -215.0 and rise_distance > 110.0 and rise_distance < 150.0, "Reduced lift reaches about 210 px/s and rises about 130 pixels in one second (%.1f px/s, %.1f px)" % [-rising.linear_velocity.y, rise_distance])
	_check(rising.linear_velocity.x > 300.0, "Ascent preserves horizontal speed (%.1f px/s)" % rising.linear_velocity.x)
	rising.queue_free()


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
