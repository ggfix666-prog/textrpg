extends Control
# Бой с врагом (оффлайн). В начале хода выпадает 1-3 действия: Удар / Зелье / Способность.
# Игрок набирает комбо и жмёт «Закончить ход» — затем отвечает враг.

var stats_label: RichTextLabel
var logv
var bottom: VBoxContainer

var P: Dictionary = {}
var E: Dictionary = {}
var phase := "pick"            # pick / turn / busy / over
var queue: Array = []
var actions_total := 1
var turn := 1
var potion_menu := false
var level_before := 1


func _ready() -> void:
	randomize()
	if SaveManager.data["class_id"] == "":
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
		return
	level_before = SaveManager.data["level"]
	var col := Style.screen(self, "")
	stats_label = Style.lbl("", 26)
	col.add_child(stats_label)
	logv = Style.make_log()
	col.add_child(logv)
	bottom = VBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	col.add_child(bottom)

	P = Combat.hero_fighter()
	E = SaveManager.encounter.duplicate(true)
	if E.is_empty():
		E = WorldData.make_enemy("goblin", int(SaveManager.data["level"]))
	E = Combat.fix(E)
	if E["boss"]:
		_log("[color=#ff5a5a][b]БОСС![/b][/color] Перед вами [color=#c9a961]%s[/color] (ур. %d)." % [E["name"], E["lvl"]])
	else:
		_log("Из тени выступает [color=#c9a961]%s[/color] (ур. %d)." % [E["name"], E["lvl"]])
	var pre: Array = []
	if E["first"] == "player":
		pre.append("[color=#c9a961]Вы нападаете из засады![/color]")
		Combat.attack(P, E, 1.0, pre, true)
	elif E["first"] == "enemy":
		pre.append("Враг не дал вам уйти и бьёт первым!")
		Combat.enemy_turn(E, P, pre)
	_flush(pre)
	if int(E["hp"]) <= 0:
		_victory()
		return
	if int(P["hp"]) <= 0:
		_defeat()
		return
	_log("Выбери способность на этот бой. Сменить её в бою нельзя.")
	_refresh()


func _log(t: String) -> void:
	logv.add_line(t)


func _flush(lines: Array) -> void:
	for l in lines:
		logv.add_line(str(l))


# ---------- Интерфейс ----------

func _refresh() -> void:
	var t := "[b][color=#c9a961]%s[/color][/b] ур.%d  HP [color=#e07a5f]%d/%d[/color]  Броня %d%%\n" % [
		P["name"], P["lvl"], P["hp"], P["max_hp"], int(round(Combat.arm_total(P) * 100))]
	t += "[b][color=#c9a961]%s[/color][/b] ур.%d  HP [color=#e07a5f]%d/%d[/color]" % [E["name"], E["lvl"], E["hp"], E["max_hp"]]
	var st: Array = []
	if int(E["eff"]["poison"]) > 0:
		st.append("яд")
	if int(E["eff"]["miss"]) > 0:
		st.append("мыши")
	if int(E["eff"]["nopot"]) > 0:
		st.append("анти-магия")
	if int(E["eff"]["wolf"]) > 0:
		st.append("волк")
	if st.size() > 0:
		t += "  [color=#7fb069](%s)[/color]" % ", ".join(st)
	stats_label.text = t
	Style.clear(bottom)
	if phase == "pick":
		_build_pick()
	elif phase == "turn":
		_build_turn()
	elif phase == "over":
		var back := Style.btn("Продолжить путь", Style.MOSS, 120, 38)
		back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Explore.tscn"))
		bottom.add_child(back)


func _build_pick() -> void:
	for a in Combat.ABILITIES[P["id"]]:
		var b := Style.btn("%s (КД %d)\n%s" % [a["name"], a["cd"], a["desc"]], Style.PLATE, 130, 28)
		b.pressed.connect(_on_pick.bind(a))
		bottom.add_child(b)


func _combo_text() -> String:
	var parts: Array = []
	for k in queue:
		var s: String = str(k)
		if s == "hit":
			parts.append("Удар")
		elif s == "ability":
			parts.append(str(P["ability"]["name"]))
		else:
			parts.append("Зелье")
	return " + ".join(parts) if parts.size() > 0 else "—"


func _potions_queued(key: String) -> int:
	return queue.count("potion:" + key)


func _build_turn() -> void:
	var info := Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 28)
	info.add_theme_color_override("font_color", Style.GOLD)
	info.text = "Ход %d. Действий: %d, выбрано: %d\nКомбо: %s" % [turn, actions_total, queue.size(), _combo_text()]
	bottom.add_child(info)
	var free: bool = queue.size() < actions_total

	if potion_menu:
		var plist := Style.fixed_scroll(bottom, 480)
		for key in P["potions"]:
			var left: int = int(P["potions"][key]) - _potions_queued(str(key))
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
	for key in P["potions"]:
		if int(P["potions"][key]) - _potions_queued(str(key)) > 0:
			any_potion = true
	var pot := Style.btn("Зелья", Style.MOSS, 110)
	pot.disabled = (not free) or (not any_potion)
	pot.pressed.connect(func():
		potion_menu = true
		_refresh())
	r1.add_child(pot)
	var ab_text: String = str(P["ability"]["name"])
	if int(P["cd"]) > 0:
		ab_text += "\n(КД %d)" % int(P["cd"])
	var ab := Style.btn(ab_text, Style.BLOOD, 110, 28)
	ab.disabled = (not free) or int(P["cd"]) > 0 or queue.has("ability")
	ab.pressed.connect(_on_add.bind("ability"))
	r1.add_child(ab)

	var r2 := Style.row(bottom)
	var undo := Style.btn("Отменить", Style.PLATE, 110)
	undo.disabled = queue.is_empty()
	undo.pressed.connect(_on_undo)
	r2.add_child(undo)
	var end := Style.btn("Закончить ход", Style.MOSS, 110)
	end.pressed.connect(_end_turn)
	r2.add_child(end)


# ---------- Ввод игрока ----------

func _on_pick(a: Dictionary) -> void:
	P["ability"] = a.duplicate(true)
	P["cd"] = 0
	phase = "turn"
	turn = 1
	_log("Выбрана способность: [color=#c9a961]%s[/color]." % a["name"])
	_roll()
	_refresh()


func _roll() -> void:
	actions_total = Combat.roll_actions(P)
	queue.clear()
	potion_menu = false
	_log("[color=#c9a961]— Ход %d: выпало действий — %d —[/color]" % [turn, actions_total])


func _on_add(kind: String) -> void:
	if queue.size() >= actions_total:
		return
	queue.append(kind)
	potion_menu = false
	_refresh()


func _on_undo() -> void:
	if not queue.is_empty():
		queue.pop_back()
		_refresh()


# ---------- Ход ----------

func _end_turn() -> void:
	phase = "busy"
	Style.clear(bottom)
	var lines: Array = []
	for k in queue:
		if int(E["hp"]) <= 0:
			break
		Combat.do_action(P, E, str(k), lines)
	queue.clear()
	if int(E["hp"]) > 0:
		Combat.end_turn(P, E, lines)
	_flush(lines)
	if int(E["hp"]) <= 0:
		_victory()
		return
	var l2: Array = []
	Combat.enemy_turn(E, P, l2)
	if int(P["hp"]) > 0:
		Combat.end_turn(E, P, l2)
	_flush(l2)
	if int(P["hp"]) <= 0:
		_defeat()
		return
	turn += 1
	phase = "turn"
	_roll()
	_refresh()


# ---------- Итог боя ----------

func _victory() -> void:
	phase = "over"
	Combat.commit_hero(P)
	var lines: Array = SaveManager.grant_victory(E, str(SaveManager.data["location"]))
	_flush(lines)
	SaveManager.pending_msg = "Вы победили: %s." % E["name"]
	SaveManager.encounter = {}
	SaveManager.save_game()
	if E["boss"] or int(SaveManager.data["level"]) > level_before:
		Online.push_score()
	_refresh()


func _defeat() -> void:
	phase = "over"
	Combat.commit_hero(P)
	_log("[color=#e07a5f][b]Вы пали в бою...[/b][/color]")
	_flush(SaveManager.apply_death())
	_log("Вы приходите в себя в лагере.")
	SaveManager.pending_msg = "Вы очнулись в лагере после поражения."
	SaveManager.encounter = {}
	SaveManager.save_game()
	_refresh()
