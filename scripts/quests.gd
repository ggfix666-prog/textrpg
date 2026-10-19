extends Control
# Доска заданий на базе: сюжетные (один раз) и ежедневные (обновляются каждый день).

var body: VBoxContainer
var note := ""


func _ready() -> void:
	if SaveManager.data["class_id"] == "":
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
		return
	SaveManager.q_ensure_daily()
	var col := Style.screen(self, "Доска заданий", 48)
	body = Style.scroll_list(col)
	var back := Style.btn("Назад", Style.BLOOD, 100)
	back.pressed.connect(func():
		SaveManager.save_game()
		get_tree().change_scene_to_file("res://scenes/Explore.tscn"))
	col.add_child(back)
	_render()


func _render() -> void:
	Style.clear(body)
	if note != "":
		body.add_child(Style.lbl("[color=#7fb069]%s[/color]" % note, 28))
	body.add_child(Style.lbl("[color=#c9a961][b]Сюжетные задания[/b][/color]", 32))
	for q in WorldData.QUESTS:
		if not q["daily"]:
			_add_quest(q)
	body.add_child(Style.lbl("[color=#c9a961][b]Ежедневные задания[/b][/color] (сбрасываются каждый день)", 32))
	for q in WorldData.QUESTS:
		if q["daily"]:
			_add_quest(q)


func _add_quest(q: Dictionary) -> void:
	var claimed: bool = SaveManager.data["quests"]["claimed"].has(q["id"])
	var prog: int = SaveManager.q_progress(str(q["id"]))
	var goal: int = int(q["goal"])
	var t := "[b]%s[/b]\n%s\nПрогресс: %d / %d   Награда: %d зол., %d опыта" % [q["title"], q["desc"], prog, goal, q["gold"], q["exp"]]
	if claimed:
		t = "[color=#7a7a7a]%s\nВыполнено, награда получена[/color]" % t
	body.add_child(Style.lbl(t, 27))
	if not claimed and prog >= goal:
		var b := Style.btn("Забрать награду", Style.MOSS, 90)
		b.pressed.connect(_claim.bind(str(q["id"])))
		body.add_child(b)


func _claim(id: String) -> void:
	for q in WorldData.QUESTS:
		if q["id"] == id:
			var s: String = SaveManager.q_claim(q)
			note = s
			break
	_render()
