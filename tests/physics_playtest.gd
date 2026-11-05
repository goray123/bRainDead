extends SceneTree
## Runs complete stages with only the same -1/0/+1 wind inputs as the player.
## The controller knows the fixed route; it never moves or shields Mint directly.

const MAIN: PackedScene = preload("res://scenes/main.tscn")
var app: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	app = MAIN.instantiate()
	root.add_child(app)
	app.disable_save = true
	var failures: int = 0
	for index in range(4):
		app._load_stage(index, true)
		var level: RainStage = app.stage
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
			var target: float = mint.position.x + mint.speed * rain_flight - sin(umbrella.rotation) * 18.0
			var desired_velocity: float = mint.speed + (target - umbrella.position.x) * 4.0
			# Brake in anticipation of the known, fixed trip position.
			if not mint.has_tripped and level.definition.trip_at > 0.0:
				var distance: float = level.definition.trip_at - mint.position.x
				if distance > 0.0 and distance < 45.0:
					desired_velocity *= distance / 45.0
			var error: float = desired_velocity - umbrella.linear_velocity.x
			if index == 1:
				# Take a high route before the first sign. This is achieved by
				# alternating both directions, increasing lift while retaining
				# the net horizontal wind needed to follow Mint.
				var desired_acceleration: float = error * 5.0
				var net_wind: float = clampf((desired_acceleration + 1.6 * umbrella.linear_velocity.x) / 480.0, -1.0, 1.0)
				var target_y: float = 180.0 if mint.position.x > 420.0 else 425.0
				var vertical_acceleration: float = (target_y - umbrella.position.y) * 3.0 - umbrella.linear_velocity.y * 3.0
				var lift_duty: float = clampf((44.8 - 1.6 * umbrella.linear_velocity.y - vertical_acceleration) / 154.0, absf(net_wind), 1.0)
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
			else:
				level.wind_override = 1.0 if error > 6.0 else (-1.0 if error < -45.0 else 0.0)
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
	print("PLAYTEST RESULT: %d/4 completed using wind input only" % (4 - failures))
	quit(1 if failures else 0)
