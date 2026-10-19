extends Control
# Онлайн: адрес сервера и ник, таблица лидеров, создание комнаты и вход в комнату для дуэли.

var url_edit: LineEdit
var nick_edit: LineEdit
var code_edit: LineEdit
var out: VBoxContainer      # сюда выводятся статусы и таблица


func _ready() -> void:
	var col := Style.screen(self, "Онлайн", 48)
	var body := Style.scroll_list(col)

	body.add_child(Style.lbl("[b]Адрес сервера[/b] (Firebase Realtime Database):", 27))
	url_edit = _edit("https://имя-проекта-default-rtdb.firebaseio.com", Online.db_url)
	body.add_child(url_edit)
	body.add_child(Style.lbl("[b]Твой ник[/b] (его увидят другие игроки):", 27))
	nick_edit = _edit("Ник", Online.nick)
	body.add_child(nick_edit)
	var save := Style.btn("Сохранить настройки", Style.MOSS, 90)
	save.pressed.connect(_save)
	body.add_child(save)
	var test := Style.btn("Проверить связь", Style.PLATE, 90)
	test.pressed.connect(_test)
	body.add_child(test)

	body.add_child(Style.lbl("[color=#c9a961][b]Таблица лидеров[/b][/color]", 32))
	var send := Style.btn("Отправить мой результат", Style.PLATE, 90)
	send.pressed.connect(_send_score)
	body.add_child(send)
	var board := Style.btn("Показать таблицу лидеров", Style.PLATE, 90)
	board.pressed.connect(_show_board)
	body.add_child(board)

	body.add_child(Style.lbl("[color=#c9a961][b]Дуэль с другом[/b][/color]\nОдин создаёт комнату и называет код, второй вводит его.", 28))
	var create := Style.btn("Создать комнату", Style.BLOOD, 100)
	create.pressed.connect(_create_room)
	body.add_child(create)
	code_edit = _edit("Код комнаты (6 цифр)", "")
	body.add_child(code_edit)
	var join := Style.btn("Войти в комнату", Style.BLOOD, 100)
	join.pressed.connect(_join_room)
	body.add_child(join)

	out = VBoxContainer.new()
	out.add_theme_constant_override("separation", 8)
	body.add_child(out)

	body.add_child(Style.lbl("[color=#c9a961][b]Как подключить сервер[/b][/color]\n1) Открой console.firebase.google.com, создай проект.\n2) Создай Realtime Database (режим тестирования).\n3) На вкладке «Правила» поставь: .read и .write равны true.\n4) Скопируй адрес базы и вставь выше.", 25))

	var back := Style.btn("Назад", Style.BLOOD, 100)
	back.pressed.connect(_back)
	col.add_child(back)


func _edit(hint: String, text: String) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = hint
	e.text = text
	e.custom_minimum_size = Vector2(0, 90)
	e.add_theme_font_size_override("font_size", 28)
	return e


func _back() -> void:
	if SaveManager.data["class_id"] != "":
		get_tree().change_scene_to_file("res://scenes/Explore.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _say(t: String) -> void:
	Style.clear(out)
	out.add_child(Style.lbl(t, 28))


func _save() -> void:
	Online.db_url = Online.clean_url(url_edit.text)
	Online.nick = nick_edit.text.strip_edges()
	Online.save_settings()
	_say("[color=#7fb069]Настройки сохранены.[/color]")


func _need_ready() -> bool:
	_save_quiet()
	if not Online.is_ready():
		_say("[color=#e07a5f]Сначала укажи адрес сервера и ник.[/color]")
		return false
	return true


func _save_quiet() -> void:
	Online.db_url = Online.clean_url(url_edit.text)
	Online.nick = nick_edit.text.strip_edges()
	Online.save_settings()


func _test() -> void:
	if not _need_ready():
		return
	_say("Проверяю связь...")
	var r: Dictionary = await Online.call_api(HTTPClient.METHOD_PUT, "ping/" + Online.nick_key(), {"t": Time.get_unix_time_from_system()})
	if r["ok"]:
		_say("[color=#7fb069]Связь есть! Сервер отвечает.[/color]")
	else:
		_say("[color=#e07a5f]%s[/color]\nПроверь адрес и правила базы." % r["error"])


func _send_score() -> void:
	if not _need_ready():
		return
	if SaveManager.data["class_id"] == "":
		_say("[color=#e07a5f]Сначала начни игру: нет героя.[/color]")
		return
	_say("Отправляю...")
	await Online.push_score()
	_say("[color=#7fb069]Результат отправлен: %d очков.[/color]" % SaveManager.score())


func _show_board() -> void:
	if not _need_ready():
		return
	_say("Загружаю таблицу...")
	var r: Dictionary = await Online.fetch_board()
	if not r["ok"]:
		_say("[color=#e07a5f]%s[/color]" % r["error"])
		return
	var rows: Array = r["rows"]
	if rows.is_empty():
		_say("Таблица пока пуста. Отправь свой результат первым!")
		return
	var t := "[b]Лучшие герои:[/b]\n"
	var i := 1
	for row in rows:
		if i > 20:
			break
		var line := "%d. %s (%s) ур.%d — очки %d, боссов %d, дуэлей %d" % [
			i, row.get("name", "?"), row.get("cls", "?"), int(row.get("lvl", 0)), int(row.get("score", 0)),
			int(row.get("bosses", 0)), int(row.get("pvp", 0))]
		if str(row.get("name", "")) == Online.nick:
			line = "[color=#c9a961]%s[/color]" % line
		t += line + "\n"
		i += 1
	_say(t)


func _create_room() -> void:
	if not _need_ready():
		return
	if SaveManager.data["class_id"] == "":
		_say("[color=#e07a5f]Сначала начни игру: нужен герой.[/color]")
		return
	SaveManager.pvp_role = "host"
	SaveManager.pvp_code = Online.make_code()
	get_tree().change_scene_to_file("res://scenes/Pvp.tscn")


func _join_room() -> void:
	if not _need_ready():
		return
	if SaveManager.data["class_id"] == "":
		_say("[color=#e07a5f]Сначала начни игру: нужен герой.[/color]")
		return
	var code: String = code_edit.text.strip_edges()
	if code.length() < 4:
		_say("[color=#e07a5f]Введи код комнаты.[/color]")
		return
	SaveManager.pvp_role = "guest"
	SaveManager.pvp_code = code
	get_tree().change_scene_to_file("res://scenes/Pvp.tscn")
