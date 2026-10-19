extends Control
# Выбор класса: 5 кнопок, описание и подтверждение

var info: RichTextLabel
var confirm_btn: Button


func _ready() -> void:
	SaveManager.pending_class = ""
	var col := Style.screen(self, "Выбери класс", 50)
	for id in SaveManager.CLASSES:
		var c: Dictionary = SaveManager.CLASSES[id]
		var b := Style.btn(str(c["name"]), Style.PLATE, 100)
		b.pressed.connect(_on_class.bind(id))
		col.add_child(b)
	info = Style.lbl("[center]Нажми на класс, чтобы узнать о нём[/center]", 30)
	col.add_child(info)
	confirm_btn = Style.btn("Начать путь", Style.MOSS, 110)
	confirm_btn.disabled = true
	confirm_btn.pressed.connect(_on_confirm)
	col.add_child(confirm_btn)
	var back := Style.btn("Назад", Style.BLOOD, 100)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	col.add_child(back)


func _on_class(id: String) -> void:
	SaveManager.pending_class = id
	var c: Dictionary = SaveManager.CLASSES[id]
	var abil: Array = Combat.ABILITIES[id]
	var t := "[b][color=#c9a961]%s[/color][/b]\n%s\nHP: %d\nПассивка: %s\n" % [c["name"], c["desc"], c["hp"], c["passive"]]
	for a in abil:
		t += "• %s: %s\n" % [a["name"], a["desc"]]
	info.text = t
	confirm_btn.disabled = false


func _on_confirm() -> void:
	if SaveManager.pending_class == "":
		return
	SaveManager.new_game(SaveManager.pending_class)
	get_tree().change_scene_to_file("res://scenes/Explore.tscn")
