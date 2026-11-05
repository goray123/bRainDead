extends SceneTree
## Opt-in desktop check: real WebView2/YouTube playback and HTML skip button.
## Run with a window and Internet access; not part of headless integration tests.

const MAIN: PackedScene = preload("res://scenes/main.tscn")
var app: Node
var report: Dictionary = {}
var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)


func _wait_for(predicate: Callable, seconds: float = 20.0) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	return bool(predicate.call())


func _on_message(message: String) -> void:
	var json := JSON.new()
	if json.parse(message) == OK and json.data is Dictionary and json.data.get("type") == "ad_test_state":
		report = json.data


func _read_button(ad: VideoAd) -> void:
	report = {}
	ad.web_view.call("eval", """
		(() => {
			const button = document.getElementById('skip');
			const frame = document.getElementById('player');
			const bounds = button.getBoundingClientRect();
			ipc.postMessage(JSON.stringify({
				type: 'ad_test_state', text: button.textContent, disabled: button.disabled,
				video: frame.src || '', rightGap: innerWidth - bounds.right, top: bounds.top
			}));
		})();
	""")
	await _wait_for(func() -> bool: return not report.is_empty(), 3.0)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("This smoke test needs a desktop window and Internet access.")
		quit(1)
		return
	root.title = "bRainDead · 광고 재생 검사"
	app = MAIN.instantiate()
	root.add_child(app)
	app.disable_save = true
	app._show_ad()
	var ad: VideoAd = app.ad_screen
	# Drive exact countdown boundaries without relying on network load time.
	ad.set_process(false)
	if not is_instance_valid(ad.web_view):
		_check(false, "Native WebView is available")
		app.queue_free()
		quit(1)
		return
	ad.web_view.connect("ipc_message", _on_message)
	var started: bool = await _wait_for(func() -> bool: return ad.playback_started or ad.last_player_error != 0)
	_check(started and ad.playback_started, "Requested YouTube video autoplays in the native game WebView")
	for remaining in [10, 9, 8, 7, 6, 5, 4, 3, 2, 1]:
		if remaining < 10:
			ad._process(1.0)
		await _read_button(ad)
		_check(report.get("text") == "%d초 뒤 스킵 가능" % remaining and report.get("disabled") == true, "Native HTML shows a locked %d-second countdown" % remaining)
	_check(str(report.get("video", "")).contains(VideoAd.VIDEO_ID), "Embedded player uses the requested video ID")
	_check(float(report.get("rightGap", 999)) < 40.0 and float(report.get("top", 999)) < 40.0, "Countdown is placed in the top-right corner")
	ad.web_view.call("eval", "document.getElementById('skip').click();")
	await process_frame
	await process_frame
	_check(app.screen == app.Screen.AD, "Disabled HTML button cannot leave the ad early")
	ad._process(1.0)
	await _read_button(ad)
	_check(report.get("text") == "건너뛰기" and report.get("disabled") == false, "At zero the real HTML button becomes clickable")
	ad.web_view.call("eval", "document.getElementById('skip').click();")
	var returned: bool = await _wait_for(func() -> bool: return app.screen == app.Screen.SELECT, 3.0)
	_check(returned and app.ad_screen == null, "Real HTML skip returns to stage selection")
	await process_frame
	await process_frame
	_check(not is_instance_valid(ad), "Skipping destroys the native ad player")
	app.queue_free()
	await process_frame
	await process_frame
	print("AD PLAYBACK RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
