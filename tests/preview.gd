extends SceneTree
## Render a real game screen for visual QA, outside the player's save profile.

const MAIN: PackedScene = preload("res://scenes/main.tscn")


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	print("PREVIEW: constructing game")
	var game: Node = MAIN.instantiate()
	root.add_child(game)
	game.disable_save = true
	var output: String = "user://preview.png"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		elif argument == "--preview-run-start":
			game._load_stage(1, true)
			game.stage.set_physics_process(false)
			game.stage.mint.position.x = game.stage.definition.run_at
			game.stage.mint.advance(1.0 / 60.0)
			game.stage.umbrella.freeze = true
			game.stage.umbrella.position.x = game.stage.mint.position.x
			game.stage.camera.position.x = game.stage.mint.position.x + 310.0
			game.stage.camera.force_update_scroll()
		elif argument == "--preview-crowd":
			game._load_stage(3, true)
			game.stage.set_physics_process(false)
			game.stage.umbrella.freeze = true
	print("PREVIEW: waiting for rendered frame")
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var result: Error = image.save_png(output)
	print("PREVIEW: saved %s (%dx%d), result=%s" % [output, image.get_width(), image.get_height(), error_string(result)])
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if result == OK else 1)
