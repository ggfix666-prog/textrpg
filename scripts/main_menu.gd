extends Control
# Главное меню: Новая игра / Продолжить / Выход


func _ready() -> void:
	Style.add_bg(self)
	var col := Style.make_column(self)
	col.add_child(Style.make_title("Хроники Мрака", 64))
	col.add_child(Style.make_text("[center]Текстовая RPG[/center]"))

	var new_btn := Style.make_button("Новая игра", Style.MOSS)
	new_btn.pressed.connect(_on_new)
	col.add_child(new_btn)

	var cont_btn := Style.make_button("Продолжить")
	cont_btn.disabled = not SaveManager.has_save()  # нет сохранения — кнопка серая
	cont_btn.pressed.connect(_on_continue)
	col.add_child(cont_btn)

	var exit_btn := Style.make_button("Выход", Style.BLOOD)
	exit_btn.pressed.connect(func(): get_tree().quit())
	col.add_child(exit_btn)


func _on_new() -> void:
	get_tree().change_scene_to_file("res://scenes/ClassSelect.tscn")


func _on_continue() -> void:
	if SaveManager.load_game():
		get_tree().change_scene_to_file("res://scenes/Profile.tscn")
