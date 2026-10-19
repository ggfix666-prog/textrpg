extends Node
# Онлайн через Firebase Realtime Database (простые REST-запросы без SDK).
# Нужен адрес базы вида https://имя-проекта-default-rtdb.firebaseio.com (вводится в игре один раз).

const SETTINGS_PATH := "user://online.json"

var db_url := ""
var nick := ""


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(d) == TYPE_DICTIONARY:
		db_url = str(d.get("url", ""))
		nick = str(d.get("nick", ""))


func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"url": db_url, "nick": nick}))
	f.close()


func is_ready() -> bool:
	return db_url != "" and nick != ""


func clean_url(u: String) -> String:
	var s: String = u.strip_edges()
	while s.ends_with("/"):
		s = s.substr(0, s.length() - 1)
	return s


# Ключ в базе из ника (нельзя . $ # [ ] /)
func nick_key() -> String:
	var out := ""
	for ch in nick.strip_edges():
		if ch in ".$#[]/\\":
			out += "_"
		else:
			out += ch
	return out


# Один запрос. method: HTTPClient.METHOD_GET / METHOD_PUT / METHOD_DELETE. Возвращает {ok, data, error}
func call_api(method: int, path: String, body = null) -> Dictionary:
	if db_url == "":
		return {"ok": false, "error": "Не задан адрес сервера"}
	var url: String = db_url + "/" + path + ".json"
	var http := HTTPRequest.new()
	http.timeout = 12.0
	add_child(http)
	var payload := ""
	if body != null:
		payload = JSON.stringify(body)
	var err: int = http.request(url, ["Content-Type: application/json"], method, payload)
	if err != OK:
		http.queue_free()
		return {"ok": false, "error": "Ошибка запроса (код %d)" % err}
	var res: Array = await http.request_completed
	http.queue_free()
	var code: int = res[1]
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
		return {"ok": false, "error": "Нет связи с сервером (код %d)" % code}
	var text: String = (res[3] as PackedByteArray).get_string_from_utf8()
	var parsed = JSON.parse_string(text)
	return {"ok": true, "data": SaveManager.norm(parsed)}


func make_code() -> String:
	return "%06d" % randi_range(0, 999999)


# Отправка результата героя в общую таблицу лидеров
func push_score() -> void:
	if not is_ready() or SaveManager.data["class_id"] == "":
		return
	var s: Dictionary = SaveManager.data["stats"]
	var rec := {
		"name": nick, "cls": SaveManager.CLASSES[SaveManager.data["class_id"]]["name"],
		"lvl": SaveManager.data["level"], "score": SaveManager.score(),
		"bosses": s["bosses"], "pvp": s["pvp_wins"], "kills": s["kills"],
	}
	await call_api(HTTPClient.METHOD_PUT, "leaderboard/" + nick_key(), rec)


# Таблица лидеров: массив записей, отсортированный по очкам
func fetch_board() -> Dictionary:
	var r: Dictionary = await call_api(HTTPClient.METHOD_GET, "leaderboard")
	if not r["ok"]:
		return r
	var rows: Array = []
	if typeof(r["data"]) == TYPE_DICTIONARY:
		for k in r["data"]:
			if typeof(r["data"][k]) == TYPE_DICTIONARY:
				rows.append(r["data"][k])
	rows.sort_custom(func(a, b): return int(a.get("score", 0)) > int(b.get("score", 0)))
	return {"ok": true, "rows": rows}
