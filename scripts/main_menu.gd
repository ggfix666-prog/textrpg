extends Control
# Главное меню: Новая игра / Продолжить / Онлайн / Выход


func _ready() -> void:
	var col := Style.screen(self, "")
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	col.add_child(Style.make_title("Хроники Мрака", 70))
	col.add_child(Style.lbl("[center]Текстовая RPG с онлайн-дуэлями[/center]", 30))

	var new_btn := Style.btn("Новая игра", Style.MOSS, 110)
	new_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ClassSelect.tscn"))
	col.add_child(new_btn)

	var cont_btn := Style.btn("Продолжить", Style.PLATE, 110)
	cont_btn.disabled = not SaveManager.has_save()
	cont_btn.pressed.connect(_on_continue)
	col.add_child(cont_btn)

	var online := Style.btn("Онлайн: дуэли и лидеры", Style.PLATE, 110)
	online.pressed.connect(_on_online)
	col.add_child(online)

	var exit_btn := Style.btn("Выход", Style.BLOOD, 110)
	exit_btn.pressed.connect(func(): get_tree().quit())
	col.add_child(exit_btn)


func _on_continue() -> void:
	if SaveManager.load_game():
		get_tree().change_scene_to_file("res://scenes/Explore.tscn")
	else:
		# сохранение от старой версии: начинаем заново
		get_tree().change_scene_to_file("res://scenes/ClassSelect.tscn")


func _on_online() -> void:
	if SaveManager.has_save():
		SaveManager.load_game()
	get_tree().change_scene_to_file("res://scenes/OnlineMenu.tscn")
