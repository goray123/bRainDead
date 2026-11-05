class_name VideoAd
extends Control
## Native YouTube playback with a game-owned ten-second skip gate.

signal skipped

const VIDEO_ID: String = "liCoGtVaw_M"
const SKIP_DELAY: float = 10.0
const PAGE_URL: String = "res://ads/youtube_ad.html"

var elapsed: float = 0.0
var muted: bool = false
var skip_button: Button
var status_label: Label
var web_view: Control
var page_ready: bool = false
var playback_started: bool = false
var last_player_error: int = 0
var _last_remaining: int = -1
var _closing: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_fallback()
	_update_countdown()
	if DisplayServer.get_name() == "headless":
		return
	if not ClassDB.class_exists("WebView"):
		status_label.text = "영상 플레이어를 사용할 수 없습니다. 잠시 후 건너뛰기로 계속하세요."
		return
	web_view = ClassDB.instantiate("WebView") as Control
	web_view.set("full_window_size", true)
	web_view.set("url", PAGE_URL)
	web_view.set("autoplay", true)
	web_view.set("devtools", false)
	web_view.set("clipboard", false)
	web_view.set("forward_input_events", false)
	web_view.set("data_directory", "user://ad_webview")
	web_view.connect("ipc_message", _on_web_message)
	add_child(web_view)


func _build_fallback() -> void:
	var background := ColorRect.new()
	background.color = Color("080d12")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var title := Label.new()
	title.text = "ADVERTISEMENT"
	title.position = Vector2(32, 31)
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color("9bb0b5"))
	add_child(title)
	status_label = Label.new()
	status_label.text = "광고 영상을 불러오는 중입니다."
	status_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	status_label.position = Vector2(190, 340)
	status_label.size = Vector2(900, 48)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color("ecede2"))
	add_child(status_label)
	skip_button = Button.new()
	skip_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	skip_button.offset_left = -260
	skip_button.offset_right = -28
	skip_button.offset_top = 20
	skip_button.offset_bottom = 66
	skip_button.add_theme_font_size_override("font_size", 16)
	skip_button.pressed.connect(request_skip)
	add_child(skip_button)


func _process(delta: float) -> void:
	if not _closing:
		elapsed = minf(SKIP_DELAY, elapsed + delta)
		_update_countdown()


func remaining_seconds() -> int:
	return maxi(0, ceili(SKIP_DELAY - elapsed))


func _update_countdown() -> void:
	var remaining: int = remaining_seconds()
	if remaining == _last_remaining:
		return
	_last_remaining = remaining
	skip_button.disabled = remaining > 0
	skip_button.text = "%d초 뒤 스킵 가능" % remaining if remaining > 0 else "건너뛰기"
	if page_ready and is_instance_valid(web_view):
		web_view.call("eval", "window.ad.setRemaining(%d);" % remaining)


func _on_web_message(message: String) -> void:
	if _closing:
		return
	var json := JSON.new()
	if json.parse(message) != OK:
		return
	var payload: Variant = json.data
	if not payload is Dictionary:
		return
	match payload.get("type", ""):
		"ready":
			# Defer calls back into the extension until its IPC callback returns.
			_configure_page.call_deferred()
		"skip":
			request_skip.call_deferred()
		"playing":
			if not playback_started:
				playback_started = true
				print("[Ad] YouTube playback started.")
		"player_error":
			last_player_error = int(payload.get("code", 0))
			print("[Ad] YouTube player error: %d" % last_player_error)


func _configure_page() -> void:
	if _closing or not is_instance_valid(web_view):
		return
	page_ready = true
	var configuration := {"videoId": VIDEO_ID, "muted": muted, "remaining": remaining_seconds()}
	web_view.call("eval", "window.ad.configure(%s);" % JSON.stringify(configuration))


func request_skip() -> void:
	if _closing or elapsed < SKIP_DELAY:
		return
	_closing = true
	stop()
	skipped.emit()


func stop() -> void:
	_closing = true
	set_process(false)
	if is_instance_valid(web_view):
		web_view.hide()
		web_view.call("eval", "window.ad && window.ad.stop();")
		# Destroy the native player now so audio cannot outlive the ad screen.
		remove_child(web_view)
		web_view.queue_free()
		web_view = null


func _exit_tree() -> void:
	stop()
