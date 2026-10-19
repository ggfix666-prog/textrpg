extends RichTextLabel
# Лог «пером по пергаменту»: строки появляются постепенно, как будто их пишут.

var shown: float = 0.0
var speed: float = 150.0


func _ready() -> void:
	bbcode_enabled = true
	scroll_following = true


func add_line(t: String) -> void:
	append_text(t + "\n")
	visible_characters = int(shown)


func skip() -> void:
	shown = float(get_total_character_count())
	visible_characters = -1


func _process(delta: float) -> void:
	var total: int = get_total_character_count()
	if shown >= float(total):
		if visible_characters != -1:
			visible_characters = -1
		return
	var backlog: float = float(total) - shown
	shown += delta * maxf(speed, backlog * 2.5)
	visible_characters = int(shown)
