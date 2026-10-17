extends Control
# Профиль героя: класс, уровень, золото, базовые статы


func _ready() -> void:
	Style.add_bg(self)
	var col := Style.make_column(self)
	col.add_child(Style.make_title("Профиль героя", 52))

	var id: String = SaveManager.data["class_id"]
	if id in SaveManager.CLASSES:
		var c: Dictionary = SaveManager.CLASSES[id]
		var lvl: int = SaveManager.data["level"]
		var t := "[b][color=#c9a961]Класс:[/color][/b] %s\n" % c["name"]
		t += "[b][color=#c9a961]Уровень:[/color][/b] %d\n" % lvl
		t += "[b][color=#c9a961]Опыт:[/color][/b] %d / %d\n" % [SaveManager.data["exp"], SaveManager.exp_needed(lvl)]
		t += "[b][color=#c9a961]Золото:[/color][/b] %d\n" % SaveManager.data["gold"]
		t += "[b][color=#c9a961]Зелья:[/color][/b] %d\n" % SaveManager.data["potions"]
		t += "[b][color=#c9a961]HP:[/color][/b] %d / %d\n" % [SaveManager.data["hp"], SaveManager.max_hp()]
		t += "[b][color=#c9a961]Прочность брони:[/color][/b] %d\n" % SaveManager.data["armor_dur"]
		t += "[b][color=#c9a961]Пассивка:[/color][/b] %s" % c["passive"]
		col.add_child(Style.make_text(t, 34))
	else:
		col.add_child(Style.make_text("Герой не создан."))

	# Этап 3: отправиться в путь (исследование)
	var fight := Style.make_button("Отправиться в путь", Style.MOSS)
	fight.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Explore.tscn"))
	col.add_child(fight)

	# Тестовая кнопка, чтобы проверить сохранение: +10 золота
	var gold := Style.make_button("+10 золота (тест сохранения)", Style.MOSS)
	gold.pressed.connect(_on_gold)
	col.add_child(gold)

	var menu := Style.make_button("В главное меню")
	menu.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	col.add_child(menu)

	var reset := Style.make_button("Удалить сохранение", Style.BLOOD)
	reset.pressed.connect(func():
		SaveManager.delete_save()
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	col.add_child(reset)


func _on_gold() -> void:
	SaveManager.data["gold"] += 10
	SaveManager.save_game()
	get_tree().reload_current_scene()
