class_name StageDefinition
extends Resource
## All stage events are position based. No random numbers are used.

@export var number: int = 1
@export var title: String = "평범한 퇴근길"
@export_multiline var description: String = "민트는 걸어갑니다. 우산은 당신 담당."
@export var short_label: String = "WALK"
@export var length: float = 2500.0
@export var walk_speed: float = 86.0
@export var run_speed: float = 210.0
@export var run_at: float = -1.0
@export var trip_at: float = -1.0
@export var trip_duration: float = 2.6
@export var umbrella_start: Vector2 = Vector2(190, 425)
@export var sign_rects: Array[Rect2] = []
@export var crowd_count: int = 0
@export var accent: Color = Color("8fdec6")
