extends Control
# Онлайн-дуэль двух игроков через Firebase. Хозяин комнаты (host) считает бой, гость (guest) шлёт свои ходы
# и видит результат. Ходы по очереди; в начале хода выпадает 1-3 действия.
# Победитель решает: забрать 10% золота и предмет или помиловать (проигравший получает +10% опыта).

var stats_label: RichTextLabel
var logv
var bottom: VBoxContainer

var role := ""
var code := ""
var phase := "ability"       # ability / connect / wait / fight / over / error
var alive := true

var my_snap: Dictionary = {}
var opp_snap: Dictionary = {}
var A: Dictionary = {}       # боец хозяина (настоящий — только у хозяина)
var B: Dictionary = {}       # боец гостя
var view_A: Dictionary = {}  # то, что показываем на экране
var view_B: Dictionary = {}
var n := 0                   # номер состояния
var last_n := -1             # какое состояние уже показано
var active := "host"
var actions := 1
var winner := ""
var queue: Array = []
var potion_menu := false
var sending := false
var result_done := false


func _ready() -> void:
	randomize()
	role = SaveManager.pvp_role
	code = SaveManager.pvp_code
	if SaveManager.data["class_id"] == "" or not Online.is_ready() or role == "":
		get_tree().change_scene_to_file("res://scenes/OnlineMenu.tscn")
		return
	var col := Style.screen(self, "")
	stats_label = Style.lbl("", 26)
	col.add_child(stats_label)
	logv = Style.make_log()
	col.add_child(logv)
	bottom = VBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	col.add_child(bottom)
	_log("[color=#c9a961][b]Дуэль[/b][/color]. Выбери способность на этот бой.")
	_refresh()


func _exit_tree() -> void:
	alive = false


func _log(t: String) -> void:
	logv.add_line(t)


func _p(sub: String) -> String:
	if sub == "":
		return "rooms/" + code
	return "rooms/%s/%s" % [code, sub]


func _fail(t: String) -> void:
	phase = "error"
	_log("[color=#e07a5f]%s[/color]" % t)
	_refresh()


func _me() -> Dictionary:
	return view_A if role == "host" else view_B


func _opp() -> Dictionary:
	return view_B if role == "host" else view_A


# ---------- Интерфейс ----------

func _refresh() -> void:
	var t := ""
	if view_A.is_empty():
		t = "Комната: [color=#c9a961]%s[/color]  (ты — %s)" % [code, "хозяин" if role == "host" else "гость"]
	else:
		var me: Dictionary = _me()
		var opp: Dictionary = _opp()
		t += ">> [b][color=#c9a961]%s[/color][/b] (%s) HP [color=#e07a5f]%d/%d[/color]\n" % [
			me["name"], me.get("cls", "?"), me["hp"], me["max_hp"]]
		t += "[b][color=#c9a961]%s[/color][/b] (%s) HP [color=#e07a5f]%d/%d[/color]\n" % [
			opp["name"], opp.get("cls", "?"), opp["hp"], opp["max_hp"]]
	stats_label.text = t
	Style.clear(bottom)
	match phase:
		"ability":
			_build_ability()
		"fight":
			if active == role and not sending:
				_build_turn()
			else:
				_wait_label("Ход соперника...")
				_exit_btn()
		"over":
			_build_over()
		_:
			_exit_btn()


func _wait_label(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 32)
	l.add_theme_color_override("font_color", Style.GOLD)
	bottom.add_child(l)


func _exit_btn() -> void:
	var b := Style.btn("Выйти", Style.BLOOD, 100)
	b.pressed.connect(_leave)
	bottom.add_child(b)


func _leave() -> void:
	alive = false
	if role == "host":
		Online.call_api(HTTPClient.METHOD_DELETE, _p(""))
	SaveManager.save_game()
	get_tree().change_scene_to_file("res://scenes/OnlineMenu.tscn")


func _build_ability() -> void:
	for a in Combat.ABILITIES[SaveManager.data["class_id"]]:
		var b := Style.btn("%s (КД %d)\n%s" % [a["name"], a["cd"], a["desc"]], Style.PLATE, 130, 28)
		b.pressed.connect(_on_pick.bind(a))
		bottom.add_child(b)
	_exit_btn()


func _combo_text() -> String:
	var parts: Array = []
	for k in queue:
		var s: String = str(k)
		if s == "hit":
			parts.append("Удар")
		elif s == "ability":
			parts.append(str(_me()["ability"].get("name", "Способность")))
		else:
			parts.append("Зелье")
	return " + ".join(parts) if parts.size() > 0 else "—"


func _queued(key: String) -> int:
	return queue.count("potion:" + key)


func _build_turn() -> void:
	var me: Dictionary = _me()
	var info := Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 28)
	info.add_theme_color_override("font_color", Style.GOLD)
	info.text = "Твой ход! Действий: %d, выбрано: %d\nКомбо: %s" % [actions, queue.size(), _combo_text()]
	bottom.add_child(info)
	var free: bool = queue.size() < actions
	if potion_menu:
		var plist := Style.fixed_scroll(bottom, 480)
		for key in me["potions"]:
			var left: int = int(me["potions"][key]) - _queued(str(key))
			if left <= 0:
				continue
			var pb := Style.btn("%s (%d)\n%s" % [ItemDB.potion_name(str(key)), left, ItemDB.potion_desc(str(key))], Style.MOSS, 100, 26)
			pb.disabled = not free
			pb.pressed.connect(_on_add.bind("potion:" + str(key)))
			plist.add_child(pb)
		var back := Style.btn("Назад", Style.PLATE, 90)
		back.pressed.connect(func():
			potion_menu = false
			_refresh())
		bottom.add_child(back)
		return
	var r1 := Style.row(bottom)
	var hit := Style.btn("Удар", Style.PLATE, 110)
	hit.disabled = not free
	hit.pressed.connect(_on_add.bind("hit"))
	r1.add_child(hit)
	var any_potion := false
	for key in me["potions"]:
		if int(me["potions"][key]) - _queued(str(key)) > 0:
			any_potion = true
	var pot := Style.btn("Зелья", Style.MOSS, 110)
	pot.disabled = (not free) or (not any_potion)
	pot.pressed.connect(func():
		potion_menu = true
		_refresh())
	r1.add_child(pot)
	var ab_text: String = str(me["ability"].get("name", "Способность"))
	if int(me["cd"]) > 0:
		ab_text += "\n(КД %d)" % int(me["cd"])
	var ab := Style.btn(ab_text, Style.BLOOD, 110, 28)
	ab.disabled = (not free) or int(me["cd"]) > 0 or queue.has("ability")
	ab.pressed.connect(_on_add.bind("ability"))
	r1.add_child(ab)
	var r2 := Style.row(bottom)
	var undo := Style.btn("Отменить", Style.PLATE, 110)
	undo.disabled = queue.is_empty()
	undo.pressed.connect(_on_undo)
	r2.add_child(undo)
	var end := Style.btn("Закончить ход", Style.MOSS, 110)
	end.pressed.connect(_submit_turn)
	r2.add_child(end)


func _on_add(kind: String) -> void:
	if queue.size() >= actions:
		return
	queue.append(kind)
	potion_menu = false
	_refresh()


func _on_undo() -> void:
	if not queue.is_empty():
		queue.pop_back()
		_refresh()


# ---------- Подключение ----------

func _on_pick(a: Dictionary) -> void:
	my_snap = Combat.snapshot(Online.nick, a)
	phase = "connect"
	_log("Выбрана способность: [color=#c9a961]%s[/color]." % a["name"])
	_refresh()
	if role == "host":
		_host_create()
	else:
		_guest_join()


func _host_create() -> void:
	var room := {"created": Time.get_unix_time_from_system(), "host": my_snap, "state": {"phase": "waiting"}}
	var r: Dictionary = await Online.call_api(HTTPClient.METHOD_PUT, _p(""), room)
	if not alive:
		return
	if not r["ok"]:
		_fail(str(r["error"]))
		return
	phase = "wait"
	_log("Комната создана. Код: [color=#c9a961][b]%s[/b][/color]. Назови его другу и жди..." % code)
	_refresh()
	_host_loop()


func _host_loop() -> void:
	while alive and phase != "over" and phase != "error":
		await get_tree().create_timer(1.3).timeout
		if not alive:
			return
		if phase == "wait":
			var r: Dictionary = await Online.call_api(HTTPClient.METHOD_GET, _p("guest"))
			if alive and r["ok"] and typeof(r["data"]) == TYPE_DICTIONARY:
				opp_snap = r["data"]
				await _host_start()
		elif phase == "fight" and active == "guest":
			var m: Dictionary = await Online.call_api(HTTPClient.METHOD_GET, _p("move"))
			if alive and m["ok"] and typeof(m["data"]) == TYPE_DICTIONARY and int(m["data"].get("n", -1)) == n:
				var q: Array = m["data"].get("q", [])
				await _run_turn("guest", q)


func _host_start() -> void:
	A = Combat.from_snapshot(my_snap)
	B = Combat.from_snapshot(opp_snap)
	for f in [A, B]:
		f.erase("inv")      # рюкзак и золото в состояние боя не нужны
		f.erase("gold")
	A["hp"] = A["max_hp"]
	B["hp"] = B["max_hp"]
	A["cd"] = 0
	B["cd"] = 0
	phase = "fight"
	active = "host"
	actions = Combat.roll_actions(A)
	n = 1
	var lines: Array = ["[color=#c9a961][b]Дуэль началась![/b][/color] %s против %s." % [A["name"], B["name"]]]
	lines.append("[color=#c9a961]— Ход: %s, действий: %d —[/color]" % [A["name"], actions])
	await _publish(lines, false)


func _guest_join() -> void:
	var h: Dictionary = await Online.call_api(HTTPClient.METHOD_GET, _p("host"))
	if not alive:
		return
	if not h["ok"]:
		_fail(str(h["error"]))
		return
	if typeof(h["data"]) != TYPE_DICTIONARY:
		_fail("Комната с таким кодом не найдена.")
		return
	opp_snap = h["data"]
	var g: Dictionary = await Online.call_api(HTTPClient.METHOD_GET, _p("guest"))
	if alive and g["ok"] and typeof(g["data"]) == TYPE_DICTIONARY:
		_fail("В комнате уже есть второй игрок.")
		return
	var r: Dictionary = await Online.call_api(HTTPClient.METHOD_PUT, _p("guest"), my_snap)
	if not alive:
		return
	if not r["ok"]:
		_fail(str(r["error"]))
		return
	phase = "wait"
	_log("Ты в комнате %s. Против тебя: [color=#c9a961]%s[/color]. Ждём начала..." % [code, opp_snap.get("name", "?")])
	_refresh()
	_guest_loop()


func _guest_loop() -> void:
	while alive and phase != "over" and phase != "error":
		await get_tree().create_timer(1.3).timeout
		if not alive:
			return
		var r: Dictionary = await Online.call_api(HTTPClient.METHOD_GET, _p("state"))
		if alive and r["ok"] and typeof(r["data"]) == TYPE_DICTIONARY and r["data"].has("A"):
			if int(r["data"].get("n", 0)) != last_n:
				_apply_state(r["data"])


# ---------- Состояние боя ----------

# Публикует новое состояние (хозяин) и показывает его у себя
func _publish(lines: Array, over: bool) -> void:
	var st := {
		"phase": "fight", "n": n, "active": active, "actions": actions,
		"A": A.duplicate(true), "B": B.duplicate(true), "log": lines,
		"over": over, "winner": winner,
	}
	_apply_state(st)
	await Online.call_api(HTTPClient.METHOD_PUT, _p("state"), st)


func _apply_state(st: Dictionary) -> void:
	var s: Dictionary = SaveManager.norm(st)
	last_n = int(s["n"])
	n = last_n
	active = str(s["active"])
	actions = int(s["actions"])
	winner = str(s.get("winner", ""))
	view_A = Combat.fix(s["A"])
	view_B = Combat.fix(s["B"])
	if phase == "wait":
		phase = "fight"
	for l in s.get("log", []):
		_log(str(l))
	sending = false
	queue.clear()
	potion_menu = false
	if s.get("over", false):
		phase = "over"
		_log("[color=#c9a961][b]Победил: %s![/b][/color]" % (view_A["name"] if winner == "host" else view_B["name"]))
		_on_over()
	_refresh()


# Ход (хозяин считает за обоих)
func _run_turn(who: String, q: Array) -> void:
	var att: Dictionary = A if who == "host" else B
	var def: Dictionary = B if who == "host" else A
	var lines: Array = []
	var done := 0
	for k in q:
		if done >= actions or int(def["hp"]) <= 0:
			break
		Combat.do_action(att, def, str(k), lines)
		done += 1
	if int(def["hp"]) > 0:
		Combat.end_turn(att, def, lines)
	var over := false
	if int(def["hp"]) <= 0:
		over = true
		winner = who
	else:
		active = "guest" if who == "host" else "host"
		var nxt: Dictionary = B if active == "guest" else A
		actions = Combat.roll_actions(nxt)
		lines.append("[color=#c9a961]— Ход: %s, действий: %d —[/color]" % [nxt["name"], actions])
	n += 1
	await _publish(lines, over)


func _submit_turn() -> void:
	sending = true
	var q: Array = queue.duplicate()
	queue.clear()
	if role == "host":
		_refresh()
		await _run_turn("host", q)
	else:
		_refresh()
		var r: Dictionary = await Online.call_api(HTTPClient.METHOD_PUT, _p("move"), {"n": n, "q": q})
		if alive and not r["ok"]:
			sending = false
			_log("[color=#e07a5f]%s. Попробуй ещё раз.[/color]" % r["error"])
			_refresh()


# ---------- Итог дуэли ----------

func _on_over() -> void:
	result_done = false
	if winner != role:
		_wait_result()


func _build_over() -> void:
	if winner == role:
		if result_done:
			_exit_btn()
			return
		var loot := Style.btn("Забрать добычу (10% золота и предмет)", Style.BLOOD, 110, 28)
		loot.pressed.connect(_choose.bind("loot"))
		bottom.add_child(loot)
		var mercy := Style.btn("Помиловать (проигравший получит опыт)", Style.MOSS, 110, 28)
		mercy.pressed.connect(_choose.bind("mercy"))
		bottom.add_child(mercy)
	else:
		_wait_label("Победитель решает судьбу...")
		_exit_btn()


# Победитель выбирает: добыча или помилование
func _choose(choice: String) -> void:
	if result_done:
		return
	result_done = true
	var res := {"by": role, "choice": choice, "gold": 0, "uid": -1}
	if choice == "loot":
		var g: int = int(int(opp_snap.get("gold", 0)) * 0.10)
		res["gold"] = g
		SaveManager.add_gold(g, true)
		var inv: Array = opp_snap.get("inv", [])
		var line := "Добыча: %d золота." % g
		if inv.size() > 0:
			var it: Dictionary = SaveManager.norm(inv.pick_random())
			res["uid"] = int(it["uid"])
			it["uid"] = SaveManager.new_uid()
			for k in ["sockets", "aff"]:
				if not it.has(k):
					it[k] = []
			line += " " + SaveManager._stash_item(it)
		_log(line)
	else:
		_log("Ты проявил милосердие.")
	var s: Dictionary = SaveManager.data["stats"]
	s["pvp_wins"] = int(s["pvp_wins"]) + 1
	SaveManager.q_event("pvp_win")
	SaveManager.save_game()
	_refresh()
	await Online.call_api(HTTPClient.METHOD_PUT, _p("result"), res)
	Online.push_score()


# Проигравший ждёт решения победителя
func _wait_result() -> void:
	var s: Dictionary = SaveManager.data["stats"]
	s["pvp_losses"] = int(s["pvp_losses"]) + 1
	for i in 60:
		await get_tree().create_timer(1.5).timeout
		if not alive:
			return
		var r: Dictionary = await Online.call_api(HTTPClient.METHOD_GET, _p("result"))
		if alive and r["ok"] and typeof(r["data"]) == TYPE_DICTIONARY:
			var d: Dictionary = r["data"]
			if str(d.get("choice", "")) == "loot":
				var g: int = mini(int(d.get("gold", 0)), int(SaveManager.data["gold"]))
				SaveManager.data["gold"] = int(SaveManager.data["gold"]) - g
				var lost_item := ""
				var uid: int = int(d.get("uid", -1))
				if uid >= 0:
					var it: Dictionary = SaveManager.remove_item(uid)
					if not it.is_empty():
						lost_item = " и предмет «%s»" % ItemDB.plain_label(it)
				_log("[color=#e07a5f]Победитель забрал у тебя %d золота%s.[/color]" % [g, lost_item])
			else:
				var xp: int = int(SaveManager.exp_needed(int(SaveManager.data["level"])) * 0.10)
				SaveManager.add_exp(xp)
				_log("[color=#7fb069]Тебя помиловали. Ты получаешь %d опыта.[/color]" % xp)
			SaveManager.save_game()
			result_done = true
			Online.push_score()
			return
	_log("Победитель не ответил. Дуэль окончена без последствий.")
	SaveManager.save_game()
