extends Node2D

enum Screen { TITLE, SELECT, READY, PLAYING, PAUSED, FAILED, CLEARED, AD }

const STAGES: Array[StageDefinition] = [
	preload("res://stages/01_walk.tres"),
	preload("res://stages/02_run.tres"),
	preload("res://stages/03_trip.tres"),
	preload("res://stages/04_crowd.tres"),
]
const PAPER := Color("ecede2")
const MUTED := Color("9bb0b5")
const MINT := Color("91dac1")
const INK := Color("10232d")
const VIDEO_AD: GDScript = preload("res://scripts/video_ad.gd")
var save_path: String = "user://progress.cfg"

var screen: Screen = Screen.TITLE
var stage: RainStage
var selected: int = 0
var completed: int = 0
var attempts: Array[int] = [0, 0, 0, 0]
var ui: Control
var overlay: Control
var layer: CanvasLayer
var regular_font: SystemFont
var bold_font: SystemFont
var sound: RainSound
var wet_fill: ColorRect
var wet_label: Label
var wet_status: Label
var progress_fill: ColorRect
var progress_label: Label
var wind_left_label: Label
var wind_right_label: Label
var timer_label: Label
var behavior_label: Label
var sound_button: Button
var ad_screen: VideoAd
var disable_save: bool = false


func _ready() -> void:
	regular_font = SystemFont.new()
	regular_font.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans CJK KR", "Apple SD Gothic Neo", "sans-serif"])
	regular_font.font_weight = 500
	bold_font = regular_font.duplicate() as SystemFont
	bold_font.font_weight = 800
	var theme := Theme.new()
	theme.default_font = regular_font
	theme.default_font_size = 16
	layer = CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = theme
	layer.add_child(ui)
	sound = RainSound.new()
	add_child(sound)
	disable_save = OS.get_cmdline_user_args().has("--no-save")
	_load_progress()
	_show_title()
	# Reproducible local previews, without changing the player's unlocks.
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--stage="):
			var index: int = clampi(argument.trim_prefix("--stage=").to_int() - 1, 0, STAGES.size() - 1)
			_load_stage(index)
		elif argument == "--select":
			_show_select()
		elif argument == "--ad":
			_show_ad()


func _clear_ui() -> void:
	if is_instance_valid(ad_screen):
		ad_screen.stop()
		ad_screen = null
		if is_instance_valid(sound):
			sound.ambience.stream_paused = false
	for child in ui.get_children():
		ui.remove_child(child)
		child.queue_free()
	overlay = null
	wet_fill = null
	wet_label = null
	progress_fill = null
	get_viewport().gui_release_focus()


func _remove_stage() -> void:
	if is_instance_valid(stage):
		remove_child(stage)
		stage.queue_free()
	stage = null


func _make_stage(index: int, title_preview: bool = false) -> void:
	_remove_stage()
	stage = RainStage.new()
	add_child(stage)
	stage.configure(STAGES[index], title_preview)
	stage.failed.connect(_on_failed)
	stage.cleared.connect(_on_cleared)
	stage.behavior_changed.connect(_on_behavior_changed)


func _show_title() -> void:
	screen = Screen.TITLE
	_clear_ui()
	_make_stage(0, true)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(INK, 0.99))
	gradient.set_color(1, Color(INK, 0.0))
	gradient.add_point(0.42, Color(INK, 0.92))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(1, 0)
	var shade := TextureRect.new()
	shade.texture = texture
	shade.position = Vector2.ZERO
	shade.size = Vector2(1280, 720)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(shade)
	_label(ui, "bRainDead  /  레인 데드", Vector2(72, 38), 16, PAPER)
	_label(ui, "A VERY BAD WEATHER GAME", Vector2(75, 137), 12, MINT)
	_label(ui, "RAIN", Vector2(66, 162), 112, PAPER, 0, true)
	_label(ui, "DEAD", Vector2(66, 269), 112, Color("e6b879"), 0, true)
	_label(ui, "민트는 집에 가고 싶다.\n우산은 당신 말을 듣고 싶지 않다.", Vector2(77, 418), 21, PAPER, 560)
	_button(ui, "게임 시작    →", Vector2(77, 513), Vector2(250, 58), _show_select, true)
	_label(ui, "A / D  또는  ← / →   바람 조작", Vector2(78, 590), 14, MUTED)
	_label(ui, "젖으면 끝. 다시 하면 그만.", Vector2(78, 617), 13, Color("70898f"))
	_label(ui, "01—04  /  NO LUCK. JUST WIND.", Vector2(920, 40), 12, MUTED)
	_label(ui, "MINT", Vector2(942, 624), 11, MINT)
	_label(ui, "버려진 우산 하나, 책임은 전부 당신에게.", Vector2(830, 671), 13, MUTED)
	_sound_control()


func _show_select() -> void:
	screen = Screen.SELECT
	_clear_ui()
	_make_stage(0, true)
	_rect(ui, Vector2.ZERO, Vector2(1280, 720), Color(INK, 0.94))
	_label(ui, "THE WAY HOME", Vector2(90, 49), 12, MINT)
	_label(ui, "오늘도 무사히?", Vector2(86, 76), 40, PAPER, 0, true)
	_label(ui, "이전 길을 통과해야 다음 길이 열립니다.", Vector2(90, 139), 15, MUTED)
	var subtitles: Array[String] = ["일정한 걸음, 제멋대로인 우산", "예고 없는 가속", "가속했으면 멈추기도 해야지", "민트를 찾아라"]
	for i in range(STAGES.size()):
		var data: StageDefinition = STAGES[i]
		var unlocked: bool = i == 0 or (completed & (1 << (i - 1))) != 0
		var done: bool = (completed & (1 << i)) != 0
		var at := Vector2(90 + (i % 2) * 558, 196 + (i / 2) * 202)
		var card := _panel(ui, at, Vector2(538, 181), Color("1a313c") if unlocked else Color("152a34"))
		_rect(card, Vector2(0, 22), Vector2(3, 42), data.accent if unlocked else Color("3d535d"))
		_label(card, "%02d" % data.number, Vector2(24, 18), 40, data.accent if unlocked else Color("4d656f"), 0, true)
		_label(card, data.short_label, Vector2(101, 29), 12, MUTED if unlocked else Color("536a74"))
		_label(card, data.title, Vector2(101, 49), 23, PAPER if unlocked else Color("6e838b"), 0, true)
		_label(card, subtitles[i], Vector2(27, 101), 14, MUTED if unlocked else Color("536a74"))
		_label(card, "CLEAR ✓" if done else ("OPEN" if unlocked else "LOCKED"), Vector2(416, 27), 11, MINT if done else MUTED)
		var button := _button(card, "다시 걷기   ↗" if done else ("들어가기   ↗" if unlocked else "이전 스테이지 클리어 필요"), Vector2(24, 133), Vector2(490, 34), func() -> void: _load_stage(i), false)
		button.disabled = not unlocked
	_button(ui, "← 타이틀", Vector2(90, 637), Vector2(160, 39), _show_title)
	_label(ui, "%d / 4  길을 통과했습니다" % _completed_count(), Vector2(937, 649), 13, MUTED)
	_sound_control()


func _load_stage(index: int, immediately: bool = false) -> void:
	selected = index
	screen = Screen.READY
	_clear_ui()
	_make_stage(index)
	_build_hud()
	if immediately:
		_begin()
		return
	overlay = _full_overlay(Color(INK, 0.48))
	var panel := _panel(overlay, Vector2(390, 174), Vector2(500, 354), Color("142b35"))
	_label(panel, "STAGE %02d  /  %s" % [index + 1, STAGES[index].short_label], Vector2(36, 29), 12, STAGES[index].accent)
	_label(panel, STAGES[index].title, Vector2(33, 62), 32, PAPER, 0, true)
	_label(panel, STAGES[index].description, Vector2(36, 124), 18, MUTED, 430)
	_label(panel, "A / D · ← / →   누르는 동안 바람", Vector2(36, 212), 14, PAPER)
	_button(panel, "출발하기   ↗", Vector2(35, 260), Vector2(430, 54), _begin, true)
	_label(overlay, "ENTER 출발     ESC 스테이지 선택", Vector2(486, 551), 13, PAPER)


func _begin() -> void:
	if screen != Screen.READY:
		return
	if is_instance_valid(overlay):
		overlay.queue_free()
		overlay = null
	screen = Screen.PLAYING
	attempts[selected] += 1
	_save_progress()
	get_viewport().gui_release_focus()
	stage.start()
	sound.play_cue("start")


func _build_hud() -> void:
	var top := _panel(ui, Vector2(24, 22), Vector2(1232, 70), Color("112832", 0.94))
	_label(top, "%02d" % (selected + 1), Vector2(21, 9), 32, STAGES[selected].accent, 0, true)
	_label(top, STAGES[selected].title, Vector2(84, 13), 18, PAPER, 0, true)
	behavior_label = _label(top, "걷는 중", Vector2(85, 40), 11, MUTED)
	_rect(top, Vector2(419, 36), Vector2(363, 3), Color("344c56"))
	progress_fill = _rect(top, Vector2(419, 36), Vector2(0, 3), MINT)
	progress_label = _label(top, "HOME  0%", Vector2(803, 24), 13, MUTED)
	timer_label = _label(top, "00:00", Vector2(960, 23), 16, PAPER)
	_button(top, "Ⅱ", Vector2(1060, 14), Vector2(44, 40), _pause)
	_button(top, "나가기", Vector2(1116, 14), Vector2(95, 40), _show_select)
	var bottom := _panel(ui, Vector2(24, 632), Vector2(1232, 65), Color("112832", 0.95))
	wet_status = _label(bottom, "젖음", Vector2(20, 12), 12, MUTED)
	_rect(bottom, Vector2(20, 40), Vector2(250, 5), Color("314955"))
	wet_fill = _rect(bottom, Vector2(20, 40), Vector2(0, 5), Color("79b8dc"))
	wet_label = _label(bottom, "0.00 / 2.00 s", Vector2(150, 10), 13, PAPER)
	wind_left_label = _label(bottom, "[ A / ← ]  왼바람", Vector2(362, 21), 16, MUTED)
	wind_right_label = _label(bottom, "[ D / → ]  오른바람", Vector2(589, 21), 16, MUTED)
	_label(bottom, "R  즉시 재시작", Vector2(900, 22), 13, MUTED)
	_label(bottom, "ESC  일시정지", Vector2(1064, 22), 13, MUTED)


func _pause() -> void:
	if screen != Screen.PLAYING:
		return
	screen = Screen.PAUSED
	stage.process_mode = Node.PROCESS_MODE_DISABLED
	stage.umbrella.freeze = true
	overlay = _full_overlay(Color(INK, 0.72))
	var panel := _panel(overlay, Vector2(420, 216), Vector2(440, 292), Color("172f39"))
	_label(panel, "잠깐, 바람도 쉬자.", Vector2(34, 30), 28, PAPER, 0, true)
	_button(panel, "계속하기", Vector2(34, 107), Vector2(372, 48), _resume, true)
	_button(panel, "처음부터 다시", Vector2(34, 166), Vector2(372, 42), _retry)
	_button(panel, "스테이지 선택", Vector2(34, 218), Vector2(372, 42), _show_select)


func _resume() -> void:
	if screen != Screen.PAUSED:
		return
	screen = Screen.PLAYING
	stage.process_mode = Node.PROCESS_MODE_INHERIT
	stage.umbrella.freeze = false
	if is_instance_valid(overlay):
		overlay.queue_free()
		overlay = null
	get_viewport().gui_release_focus()


func _retry() -> void:
	_load_stage(selected, true)


func _on_failed() -> void:
	screen = Screen.FAILED
	sound.play_cue("fail")
	overlay = _full_overlay(Color(INK, 0.72))
	var panel := _panel(overlay, Vector2(370, 177), Vector2(540, 360), Color("172d37"))
	_label(panel, "SOAKED  /  TRY %02d" % attempts[selected], Vector2(35, 27), 12, Color("ed9792"))
	_label(panel, "민트가 젖었습니다.", Vector2(32, 64), 34, PAPER, 0, true)
	var messages: Array[String] = ["우산은 거기 있는데, 민트는 여기 있네요.", "민트가 뛴다고는 말 안 했던가요?", "넘어질 줄은 민트도 몰랐을 거예요.", "남의 우산은 당신 편이 아닙니다."]
	_label(panel, messages[selected], Vector2(36, 132), 16, MUTED, 470)
	_label(panel, "진행 %d%%   ·   젖음 2.00초" % int(_progress() * 100.0), Vector2(36, 180), 14, Color("b1c6cb"))
	_button(panel, "다시 도전    R", Vector2(35, 233), Vector2(470, 50), _retry, true)
	_button(panel, "스테이지 선택", Vector2(35, 295), Vector2(470, 37), _show_select)


func _on_cleared() -> void:
	screen = Screen.CLEARED
	completed |= 1 << selected
	_save_progress()
	sound.play_cue("clear")
	overlay = _full_overlay(Color(INK, 0.66))
	var panel := _panel(overlay, Vector2(370, 177), Vector2(540, 360), Color("172f37"))
	_label(panel, "MADE IT HOME  /  STAGE %02d" % (selected + 1), Vector2(35, 27), 12, MINT)
	_label(panel, "어쨌든, 도착.", Vector2(32, 64), 38, PAPER, 0, true)
	_label(panel, "민트는 무사합니다. 당신은요?", Vector2(36, 133), 17, MUTED)
	_label(panel, "%s   ·   도전 %d회   ·   남은 젖음 %.2f초" % [_time_text(stage.elapsed), attempts[selected], stage.mint.wetness], Vector2(36, 182), 14, PAPER)
	_button(panel, "다음으로    →", Vector2(35, 237), Vector2(470, 50), _show_ad, true)
	_label(panel, "모든 길을 통과했습니다. 수고했어요, 바람." if _completed_count() == 4 else "다음 스테이지가 열렸습니다.", Vector2(36, 309), 13, MINT)


func _show_ad() -> void:
	screen = Screen.AD
	_clear_ui()
	if is_instance_valid(stage):
		stage.stop()
		stage.attract = false
	sound.ambience.stream_paused = true
	ad_screen = VIDEO_AD.new()
	ad_screen.muted = sound.muted
	ad_screen.skipped.connect(_show_select)
	ui.add_child(ad_screen)


func _on_behavior_changed(value: String) -> void:
	if is_instance_valid(behavior_label):
		behavior_label.text = value
		behavior_label.modulate = Color("f1bd78") if value != "걷는 중" else PAPER
	if value == "넘어짐!":
		sound.play_cue("trip")


func _process(_delta: float) -> void:
	if screen not in [Screen.PLAYING, Screen.PAUSED, Screen.READY]:
		return
	if is_instance_valid(wet_fill) and is_instance_valid(stage):
		var wet: float = stage.mint.wetness
		wet_fill.size.x = 250.0 * wet / 2.0
		wet_fill.color = Color("ed9792") if wet > 1.35 else Color("79b8dc")
		wet_label.text = "%.2f / 2.00 s" % wet
		wet_status.text = "비 맞는 중" if stage.mint.touching_rain else "젖음"
		wet_status.modulate = Color("ed9792") if stage.mint.touching_rain else PAPER
		progress_fill.size.x = 363.0 * _progress()
		progress_label.text = "HOME  %d%%" % int(_progress() * 100.0)
		timer_label.text = _time_text(stage.elapsed)
		var wind: float = stage.umbrella.wind if screen == Screen.PLAYING else 0.0
		wind_left_label.modulate = MINT if wind < 0.0 else Color("758d97")
		wind_right_label.modulate = MINT if wind > 0.0 else Color("758d97")


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if screen == Screen.READY:
				_begin()
			elif screen == Screen.TITLE:
				_show_select()
		KEY_R:
			if screen in [Screen.PLAYING, Screen.PAUSED, Screen.FAILED]:
				_retry()
		KEY_ESCAPE:
			if screen == Screen.PLAYING:
				_pause()
			elif screen == Screen.PAUSED:
				_resume()
			elif screen in [Screen.READY, Screen.FAILED, Screen.CLEARED]:
				_show_select()
			elif screen == Screen.SELECT:
				_show_title()
		KEY_M:
			_toggle_sound()


func _progress() -> float:
	return clampf((stage.mint.position.x - 190.0) / (STAGES[selected].length - 335.0), 0.0, 1.0)


func _time_text(seconds: float) -> String:
	return "%02d:%02d" % [int(seconds) / 60, int(seconds) % 60]


func _completed_count() -> int:
	var count: int = 0
	for i in range(4):
		if completed & (1 << i):
			count += 1
	return count


func _load_progress() -> void:
	if disable_save:
		return
	var config := ConfigFile.new()
	if config.load(save_path) != OK:
		return
	completed = clampi(int(config.get_value("progress", "completed", 0)), 0, 15)
	for i in range(4):
		attempts[i] = maxi(0, int(config.get_value("attempts", str(i), 0)))


func _save_progress() -> void:
	if disable_save:
		return
	var config := ConfigFile.new()
	config.set_value("progress", "completed", completed)
	for i in range(4):
		config.set_value("attempts", str(i), attempts[i])
	var error: Error = config.save(save_path)
	if error != OK:
		push_warning("Could not save progress: %s" % error_string(error))


func _full_overlay(color: Color) -> Control:
	var control := Control.new()
	control.position = Vector2.ZERO
	control.size = Vector2(1280, 720)
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(control)
	_rect(control, Vector2.ZERO, control.size, color)
	return control


func _panel(parent: Node, at: Vector2, dimensions: Vector2, color: Color) -> Panel:
	var panel := Panel.new()
	panel.position = at
	panel.size = dimensions
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(color, Color("36505a"), 12))
	parent.add_child(panel)
	return panel


func _rect(parent: Node, at: Vector2, dimensions: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = at
	rect.size = dimensions
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect


func _label(parent: Node, value: String, at: Vector2, size: int, color: Color, width: float = 0, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = value
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if bold:
		label.add_theme_font_override("font", bold_font)
	if width > 0.0:
		label.size.x = width
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _button(parent: Node, value: String, at: Vector2, dimensions: Vector2, callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = value
	button.position = at
	button.size = dimensions
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 16 if dimensions.y >= 48 else 14)
	button.add_theme_font_override("font", bold_font if primary else regular_font)
	button.add_theme_color_override("font_color", INK if primary else PAPER)
	button.add_theme_color_override("font_hover_color", INK if primary else PAPER)
	button.add_theme_color_override("font_pressed_color", INK if primary else MINT)
	button.add_theme_color_override("font_disabled_color", Color("536b75"))
	var base: Color = MINT if primary else Color("213c47")
	button.add_theme_stylebox_override("normal", _style(base, base if primary else Color("3b5660"), 7))
	button.add_theme_stylebox_override("hover", _style(base.lightened(0.12), MINT, 7))
	button.add_theme_stylebox_override("pressed", _style(base.darkened(0.12), MINT, 7))
	button.add_theme_stylebox_override("disabled", _style(Color("1c323d"), Color("2c424d"), 7))
	button.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), Color("f5ca87"), 7))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _style(color: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12
	style.content_margin_right = 12
	return style


func _sound_control() -> void:
	sound_button = _button(ui, "음향 OFF" if sound.muted else "음향 ON", Vector2(1120, 37), Vector2(94, 32), _toggle_sound)


func _toggle_sound() -> void:
	sound.toggle()
	if is_instance_valid(sound_button):
		sound_button.text = "음향 OFF" if sound.muted else "음향 ON"
