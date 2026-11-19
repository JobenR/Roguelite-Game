extends Control
## Reclaim mode's race: your clean ground on the left, the horde's ink on the
## right, bare paper between. The ticks mark the share that wins the page.

var reclaim: ReclaimSystem
var ink: InkSystem

const WIDTH := 560.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.5
	anchor_right = 0.5
	offset_left = -WIDTH * 0.5
	offset_right = WIDTH * 0.5
	offset_top = 84.0
	offset_bottom = 132.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if reclaim == null or ink == null or ink.grid == null:
		return
	var mine := ink.ownership()
	var theirs := ink.enemy_share()
	var goal := float(reclaim.level.get("win_share", 0.9))
	var bar := Rect2(0.0, 6.0, WIDTH, 22.0)
	draw_rect(bar.grow(3.0), Sumi.INK)
	draw_rect(bar, Color(Sumi.PAPER_SHADE, 0.95))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * mine, bar.size.y)), Color.WHITE)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * mine, 5.0)), GameState.ink_color)
	var hot := Color("#ff3d8b")
	draw_rect(Rect2(Vector2(bar.end.x - bar.size.x * theirs, bar.position.y), Vector2(bar.size.x * theirs, bar.size.y)), hot)
	for tick: float in [goal, 1.0 - goal]:
		draw_line(Vector2(bar.size.x * tick, 2.0), Vector2(bar.size.x * tick, 32.0), Sumi.INK, 3.0)
	var font: Font = Sumi.TITLE_FONT
	draw_string(font, Vector2(2.0, 52.0), "YOU %d%%" % int(mine * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Sumi.INK)
	var enemy_text := "INK %d%%" % int(theirs * 100.0)
	draw_string(font, Vector2(WIDTH - 2.0 - font.get_string_size(enemy_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x, 52.0), enemy_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, hot.darkened(0.25))
	var mid := "SOURCES %d/%d" % [reclaim.sources_left(), reclaim.sources.size()]
	draw_string(font, Vector2((WIDTH - font.get_string_size(mid, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x) * 0.5, 52.0), mid, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Sumi.FADED)
