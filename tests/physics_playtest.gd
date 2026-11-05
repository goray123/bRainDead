extends SceneTree
## Runs complete stages with only the same -1/0/+1 wind inputs as the player.
## The controller knows the fixed route; it never moves or shields Mint directly.

const MAIN: PackedScene = preload("res://scenes/main.tscn")
var app: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var stage_indices: Array[int] = [0, 1, 2, 3]
	var rain_seed: int = 731
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--playtest-stage="):
			stage_indices.assign([clampi(argument.trim_prefix("--playtest-stage=").to_int() - 1, 0, 3)])
		elif argument.begins_with("--rain-seed="):
			rain_seed = argument.trim_prefix("--rain-seed=").to_int()
	app = MAIN.instantiate()
	root.add_child(app)
	app.disable_save = true
	var failures: int = 0
	for index in stage_indices:
		app._load_stage(index, true)
		var level: RainStage = app.stage
		level.rain.reset(rain_seed + index)
		level.wind_override = 0.0
		var maximum_wetness: float = 0.0
		var horizontal_residual: float = 0.0
		var lift_residual: float = 0.0
		for tick in range(3600):
			await physics_frame
			if not level.active:
				break
			var mint: MintWalker = level.mint
			var umbrella: WindUmbrella = level.umbrella
			var rain_flight: float = maxf(0.0, mint.position.y - 67.0 - umbrella.position.y) / PhysicalRain.FALL_SPEED
			# Account for route changes while rain travels from canopy to Mint.
			var future_x: float = _predict_mint_x(mint, rain_flight)
			var target: float = future_x - sin(umbrella.rotation) * 18.0
			var target_speed: float = (_predict_mint_x(mint, rain_flight + 0.25) - future_x) / 0.25
			var desired_velocity: float = target_speed + (target - umbrella.position.x) * 4.0
			var error: float = desired_velocity - umbrella.linear_velocity.x
			# Pulse both directions to control the stronger lift independently
			# of average horizontal force. Running stages take a high route.
			var desired_acceleration: float = error * 5.0
			var net_wind: float = clampf((desired_acceleration + umbrella.linear_damp * umbrella.linear_velocity.x) / umbrella.horizontal_force, -1.0, 1.0)
			var target_y: float = 180.0 if index in [1, 2] and mint.position.x > 420.0 else 425.0
			var vertical_acceleration: float = (target_y - umbrella.position.y) * 3.0 - umbrella.linear_velocity.y * 3.0
			var gravity: float = float(ProjectSettings.get_setting("physics/2d/default_gravity")) * umbrella.gravity_scale
			var lift_duty: float = clampf((gravity - umbrella.linear_damp * umbrella.linear_velocity.y - vertical_acceleration) / umbrella.lift_force, absf(net_wind), 1.0)
			horizontal_residual += net_wind
			lift_residual += lift_duty
			var best_wind: float = 0.0
			var best_cost: float = INF
			for candidate in [-1.0, 0.0, 1.0]:
				var cost: float = pow(horizontal_residual - candidate, 2.0) * 2.0 + pow(lift_residual - absf(candidate), 2.0)
				if cost < best_cost:
					best_cost = cost
					best_wind = candidate
			level.wind_override = best_wind
			horizontal_residual -= best_wind
			lift_residual -= absf(best_wind)
			maximum_wetness = maxf(maximum_wetness, mint.wetness)
			if tick % 300 == 0:
				print("TRACE stage=%d t=%.1f mint=%.1f umbrella=(%.1f,%.1f) angle=%.2f wet=%.2f" % [index + 1, level.elapsed, mint.position.x, umbrella.position.x, umbrella.position.y, umbrella.rotation, mint.wetness])
		var passed: bool = app.screen == app.Screen.CLEARED
		if not passed:
			failures += 1
		print("PLAYTEST stage=%d %s time=%.2f progress=%.1f%% wet_max=%.2f umbrella=(%.1f,%.1f)" % [index + 1, "PASS" if passed else "FAIL", level.elapsed, app._progress() * 100.0, maximum_wetness, level.umbrella.position.x, level.umbrella.position.y])
		level.stop()
	app.queue_free()
	await process_frame
	await process_frame
	print("PLAYTEST RESULT: %d/%d completed using wind input only" % [stage_indices.size() - failures, stage_indices.size()])
	quit(1 if failures else 0)


func _predict_mint_x(mint: MintWalker, seconds: float) -> float:
	var x: float = mint.position.x
	var has_run: bool = mint.has_run
	var has_prepared_run: bool = mint.has_prepared_run
	var run_prep_left: float = mint.run_prep_left
	var has_tripped: bool = mint.has_tripped
	var trip_left: float = mint.trip_left
	var remaining: float = seconds
	while remaining > 0.00001:
		var step: float = minf(remaining, 1.0 / 60.0)
		if not has_run and mint.definition.run_at >= 0.0 and x >= mint.definition.run_at:
			if not has_prepared_run:
				has_prepared_run = true
				run_prep_left = maxf(0.0, mint.definition.run_prep_duration)
			if run_prep_left > 0.0:
				run_prep_left = maxf(0.0, run_prep_left - step)
				if run_prep_left < 0.00001:
					run_prep_left = 0.0
					has_run = true
				remaining -= step
				continue
			has_run = true
		if not has_tripped and mint.definition.trip_at >= 0.0 and x >= mint.definition.trip_at:
			has_tripped = true
			trip_left = mint.definition.trip_duration
		if trip_left > 0.0:
			trip_left = maxf(0.0, trip_left - step)
		else:
			x += (mint.definition.run_speed if has_run and not has_tripped else mint.definition.walk_speed) * step
		remaining -= step
	return minf(x, mint.definition.length - 145.0)
