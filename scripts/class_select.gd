extends Control
# Выбор класса: 5 кнопок, описание выбранного класса и кнопка подтверждения

var info: RichTextLabel
var confirm_btn: Button


func _ready() -> void:
	Style.add_bg(self)
	SaveManager.pending_class = ""
	var col := Style.make_column(self)
	col.add_child(Style.make_title("Выбери класс", 52))

	# По кнопке на каждый класс
	for id in SaveManager.CLASSES:
		var c: Dictionary = SaveManager.CLASSES[id]
		var b := Style.make_button(c["name"])
		b.pressed.connect(_on_class.bind(id))
		col.add_child(b)

	info = Style.make_text("[center]Нажми на класс, чтобы узнать о нём[/center]")
	col.add_child(info)

	confirm_btn = Style.make_button("Начать путь", Style.MOSS)
	confirm_btn.disabled = true
	confirm_btn.pressed.connect(_on_confirm)
	col.add_child(confirm_btn)

	var back := Style.make_button("Назад", Style.BLOOD)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	col.add_child(back)


func _on_class(id: String) -> void:
	SaveManager.pending_class = id
	var c: Dictionary = SaveManager.CLASSES[id]
	info.text = "[b][color=#c9a961]%s[/color][/b]\n%s\nHP: %d\nПассивка: %s" % [c["name"], c["desc"], c["hp"], c["passive"]]
	confirm_btn.disabled = false


func _on_confirm() -> void:
	if SaveManager.pending_class == "":
		return
	SaveManager.new_game(SaveManager.pending_class)
	get_tree().change_scene_to_file("res://scenes/Profile.tscn")
