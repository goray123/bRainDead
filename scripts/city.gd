class_name RainCity
extends Node2D
## Original vector artwork. All decorative variation is index based.

var definition: StageDefinition
var font: Font


func _ready() -> void:
	var system_font := SystemFont.new()
	system_font.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans CJK KR", "sans-serif"])
	font = system_font
	z_index = -20
	queue_redraw()


func _draw() -> void:
	if definition == null:
		return
	var length: float = definition.length
	draw_rect(Rect2(-200, -250, length + 400, 1000), Color("12242e"))
	for i in range(16):
		var y: float = float(i) * 38.0
		draw_rect(Rect2(-200, y, length + 400, 39), Color("152c36").lerp(Color("29434a"), float(i) / 15.0))
	draw_circle(Vector2(1100, 128), 43.0, Color("9bb5ad", 0.08))
	draw_circle(Vector2(1100, 128), 30.0, Color("c8d0b8", 0.10))
	# Distant skyline.
	for i in range(int(length / 135.0) + 3):
		var x: float = float(i) * 135.0 - 100.0
		var height: float = 150.0 + float((i * 71) % 170)
		draw_rect(Rect2(x, 480 - height, 122, height), Color("1b333e"))
		for col in range(4):
			for row in range(int(height / 29.0) - 1):
				if (row * 3 + col * 7 + i) % 5 < 2:
					draw_rect(Rect2(x + 14 + col * 26, 495 - height + row * 29, 9, 13), Color("7d9991", 0.18))
	# Street-level shopfronts.
	for i in range(int(length / 320.0) + 2):
		_draw_shop(float(i) * 320.0 - 40.0, i)
	for i in range(int(length / 710.0) + 1):
		_draw_lamp(470.0 + float(i) * 710.0)
	# Pavement and reflective asphalt.
	draw_rect(Rect2(-150, 596, length + 300, 124), Color("152b35"))
	draw_rect(Rect2(-150, 597, length + 300, 6), Color("68817f"))
	draw_rect(Rect2(-150, 605, length + 300, 2), Color("0c1a25"))
	for i in range(int(length / 96.0) + 2):
		var x: float = float(i) * 96.0
		draw_line(Vector2(x, 598), Vector2(x + 27, 720), Color("3b5157", 0.48), 1.0)
	for i in range(int(length / 122.0) + 2):
		var x: float = float(i) * 122.0 + float((i * 37) % 70)
		_ellipse(Vector2(x, 627 + (i * 11) % 72), Vector2(35 + i % 3 * 12, 3), Color("719e9c", 0.12))
		if i % 3 == 0:
			draw_rect(Rect2(x, 616, 28, 2), Color("e6be83", 0.16))
	for i in range(9):
		var x: float = definition.length - 400 + float(i) * 35.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, 649), Vector2(x + 16, 649), Vector2(x + 35, 701), Vector2(x + 15, 701)]), Color("9aa99e", 0.20))
	# An obvious warm destination, without covering the route with a roof.
	var goal_x: float = length - 145.0
	draw_rect(Rect2(goal_x - 30, 485, 62, 112), Color("172d35"))
	draw_rect(Rect2(goal_x - 25, 490, 52, 105), Color("deb97e", 0.32))
	draw_rect(Rect2(goal_x - 21, 493, 43, 101), Color("e6bf82", 0.21))
	draw_circle(Vector2(goal_x + 13, 551), 2.0, Color("f7d797"))
	_draw_text(Vector2(goal_x - 27, 473), "HOME", 15, Color("f0d2a1"))
	for i in range(definition.sign_rects.size()):
		_draw_sign(definition.sign_rects[i], i)
	# Fixed trip hazard, visible but easy to miss.
	if definition.trip_at > 0.0:
		draw_colored_polygon(PackedVector2Array([Vector2(definition.trip_at - 12, 597), Vector2(definition.trip_at - 5, 588), Vector2(definition.trip_at + 12, 592), Vector2(definition.trip_at + 17, 598)]), Color("71827f"))


func _draw_shop(x: float, index: int) -> void:
	var height: float = 255.0 + float(index % 3) * 38.0
	var facade: Color = [Color("283f48"), Color("30474c"), Color("263e48")][index % 3]
	draw_rect(Rect2(x, 596 - height, 307, height), facade)
	draw_rect(Rect2(x + 9, 599 - height, 289, height - 3), facade.lightened(0.025), false, 1.0)
	for row in range(2):
		for col in range(4):
			var at := Vector2(x + 24 + col * 68, 359 + row * 53 - float(index % 3) * 32)
			draw_rect(Rect2(at, Vector2(41, 35)), Color("142c37"))
			if (col + row + index) % 3 != 0:
				draw_rect(Rect2(at + Vector2(3, 3), Vector2(35, 29)), Color("a09a72", 0.20))
			draw_line(at + Vector2(20, 0), at + Vector2(20, 35), facade, 3.0)
	draw_rect(Rect2(x + 15, 476, 276, 111), Color("112932"))
	draw_rect(Rect2(x + 25, 490, 165, 90), Color("4a6462", 0.45))
	for col in range(3):
		draw_rect(Rect2(x + 32 + col * 52, 500, 43, 66), Color("a9ad86", 0.15))
	draw_rect(Rect2(x + 205, 490, 65, 106), Color("30474d"))
	draw_rect(Rect2(x + 211, 497, 52, 70), Color("9ea887", 0.16))
	draw_line(Vector2(x + 239, 498), Vector2(x + 239, 568), Color("30474d"), 3.0)
	draw_rect(Rect2(x + 9, 451, 289, 30), Color("20353d"))
	var names: Array[String] = ["NIGHT OWL", "COFFEE & RAIN", "24 / 편의점", "레코드 상점", "AFTER HOURS"]
	_draw_text(Vector2(x + 30, 472), names[index % names.size()], 15, Color("c8c7ab", 0.7))
	for stripe in range(12):
		draw_rect(Rect2(x + 9 + stripe * 24, 479, 24, 9), Color("627f75") if stripe % 2 == 0 else Color("3d5d5b"))
	draw_rect(Rect2(x + 9, 488, 289, 3), Color("132832"))
	# Window reflections, drain pipes and a small planter.
	draw_line(Vector2(x + 299, 596 - height), Vector2(x + 299, 595), Color("1d333c"), 4.0)
	draw_rect(Rect2(x + 274, 576, 22, 20), Color("8c7861"))
	for leaf in range(4):
		draw_line(Vector2(x + 284, 580), Vector2(x + 274 + leaf * 7, 554 - leaf % 2 * 8), Color("668678"), 5.0, true)


func _draw_lamp(x: float) -> void:
	for i in range(6):
		_ellipse(Vector2(x + 42, 382 + i * 24), Vector2(22 + i * 13, 30), Color(0.96, 0.84, 0.57, 0.018))
	draw_line(Vector2(x, 598), Vector2(x, 347), Color("132b35"), 7.0, true)
	draw_line(Vector2(x, 348), Vector2(x + 38, 338), Color("132b35"), 6.0, true)
	draw_rect(Rect2(x + 24, 336, 35, 9), Color("a2a890"))
	draw_rect(Rect2(x + 26, 345, 31, 3), Color("ead49c"))
	_ellipse(Vector2(x + 39, 634), Vector2(39, 4), Color("e5c587", 0.13))


func _draw_sign(rect: Rect2, index: int) -> void:
	draw_line(rect.position + Vector2(13, 0), rect.position + Vector2(13, -95), Color("172d37"), 4.0)
	draw_line(rect.position + Vector2(rect.size.x - 13, 0), rect.position + Vector2(rect.size.x - 13, -95), Color("172d37"), 4.0)
	draw_rect(rect.grow(3), Color("152a35"))
	draw_rect(rect, Color("a46f68") if index % 2 == 0 else Color("527f79"))
	draw_rect(rect.grow(-5), Color("f0c58e", 0.25), false, 1.0)
	var text_value: String = "간판 / SLOW DOWN" if index % 2 == 0 else "우산 주의 · OPEN"
	_draw_text(rect.position + Vector2(15, rect.size.y * 0.65), text_value, 15, Color("f0dbc1"))


func _draw_text(at: Vector2, value: String, size: int, color: Color) -> void:
	if font != null:
		draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _ellipse(at: Vector2, radii: Vector2, color: Color) -> void:
	draw_set_transform(at, 0, radii)
	draw_circle(Vector2.ZERO, 1, color)
	draw_set_transform(Vector2.ZERO)
