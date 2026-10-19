extends Control
# Герой и рюкзак: характеристики, надетые вещи, рюкзак, зелья, руны и самоцветы.

var body: VBoxContainer
var view := "stats"       # stats / bag / misc / item
var sel_uid := -1
var msg := ""


func _ready() -> void:
	if SaveManager.data["class_id"] == "":
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
		return
	var col := Style.screen(self, "Герой", 48)
	var nav := Style.row(col)
	for pair in [["stats", "Герой"], ["bag", "Рюкзак"], ["misc", "Прочее"]]:
		var b := Style.btn(str(pair[1]), Style.PLATE, 90)
		b.pressed.connect(_set_view.bind(str(pair[0])))
		nav.add_child(b)
	body = Style.scroll_list(col)
	var back := Style.btn("Назад", Style.BLOOD, 100)
	back.pressed.connect(func():
		SaveManager.save_game()
		get_tree().change_scene_to_file("res://scenes/Explore.tscn"))
	col.add_child(back)
	_render()


func _set_view(v: String) -> void:
	view = v
	msg = ""
	_render()


func _item_button(text: String, it: Dictionary, h: int = 100) -> Button:
	var b := Style.btn(text, Style.PLATE, h, 28)
	var c := Color(ItemDB.rarity_color(int(it["rarity"])))
	b.add_theme_color_override("font_color", c)
	b.add_theme_color_override("font_hover_color", c)
	b.add_theme_color_override("font_pressed_color", c)
	return b


func _render() -> void:
	Style.clear(body)
	if msg != "":
		body.add_child(Style.lbl("[color=#e07a5f]%s[/color]" % msg, 28))
	match view:
		"stats":
			_render_stats()
		"bag":
			_render_bag()
		"misc":
			_render_misc()
		"item":
			_render_item()


# ---------- Герой ----------

func _render_stats() -> void:
	var id: String = SaveManager.data["class_id"]
	var c: Dictionary = SaveManager.CLASSES[id]
	var lvl: int = SaveManager.data["level"]
	var S: Dictionary = SaveManager.calc_stats()
	var hf: Dictionary = Combat.hero_fighter()
	var hit: int = int(round(Combat.raw_damage(hf, 1.0)))
	var t := "[b][color=#c9a961]%s[/color][/b]  ур.%d  (опыт %d/%d)\n" % [c["name"], lvl, SaveManager.data["exp"], SaveManager.exp_needed(lvl)]
	t += "Золото: [color=#c9a961]%d[/color]   Очки улучшения: %d\n" % [SaveManager.data["gold"], SaveManager.data["points"]]
	t += "HP: %d / %d\n" % [hf["hp"], S["max_hp"]]
	t += "Урон удара: ~%d\n" % hit
	t += "Сила %d, Ловкость %d\n" % [int(S["str"]), int(S["agi"])]
	t += "Крит %.0f%%, Вампиризм %.0f%%\n" % [float(S["crit"]) * 100.0, float(S["vamp"]) * 100.0]
	t += "Броня %.0f%%, Сопр. магии %.0f%%\n" % [Combat.arm_total(hf) * 100.0, float(S["mres"]) * 100.0]
	t += "Бонус золота +%.0f%%, дропа +%.0f%%\n" % [float(S["gold"]) * 100.0, float(S["drop"]) * 100.0]
	t += "Пассивка: %s\n" % c["passive"]
	t += "Рюкзак: %d / %d" % [SaveManager.bag_used(), SaveManager.BAG_CAP]
	body.add_child(Style.lbl(t, 30))
	body.add_child(Style.lbl("[color=#c9a961][b]Надето:[/b][/color]", 30))
	for slot in ItemDB.SLOTS:
		var it = SaveManager.data["equipped"].get(slot)
		if it == null:
			var e := Style.btn("%s: — пусто —" % ItemDB.SLOT_NAMES[slot], Style.DARK, 80, 28)
			e.disabled = true
			body.add_child(e)
		else:
			var dur := ""
			if float(ItemDB.item_stats(it).get("arm", 0.0)) > 0.0:
				dur = " [проч. %d]" % int(it.get("dur", 100))
			var b := _item_button("%s: %s%s" % [ItemDB.SLOT_NAMES[slot], ItemDB.plain_label(it), dur], it, 90)
			b.pressed.connect(_open_item.bind(int(it["uid"])))
			body.add_child(b)


# ---------- Рюкзак ----------

func _render_bag() -> void:
	body.add_child(Style.lbl("Рюкзак: %d / %d. Нажми на предмет." % [SaveManager.bag_used(), SaveManager.BAG_CAP], 28))
	var inv: Array = SaveManager.data["inventory"].duplicate()
	inv.sort_custom(func(a, b): return int(a["rarity"]) > int(b["rarity"]))
	if inv.is_empty():
		body.add_child(Style.lbl("[center]Пусто[/center]", 30))
	for it in inv:
		var b := _item_button("%s\n%s" % [ItemDB.plain_label(it), ItemDB.stats_lines(it)], it, 110)
		b.pressed.connect(_open_item.bind(int(it["uid"])))
		body.add_child(b)


func _open_item(uid: int) -> void:
	sel_uid = uid
	view = "item"
	msg = ""
	_render()


func _render_item() -> void:
	var found: Dictionary = SaveManager.find_item(sel_uid)
	if found.is_empty():
		view = "bag"
		_render()
		return
	var it: Dictionary = found["it"]
	var where: String = found["where"]
	var r: int = int(it["rarity"])
	var t := "%s\n[color=%s]%s[/color]  ур. %d / %d\n" % [ItemDB.item_label(it), ItemDB.rarity_color(r), ItemDB.RARITY_NAMES[r], int(it["lvl"]), ItemDB.item_cap(it)]
	t += "Слот: %s\n" % ItemDB.SLOT_NAMES[ItemDB.slots_for(it)[0]]
	var st: Dictionary = ItemDB.item_stats(it)
	for k in st:
		t += "%s\n" % ItemDB.stat_text(str(k), float(st[k]))
	var sk: String = ItemDB.sockets_text(it)
	if sk != "":
		t += sk + "\n"
	if float(st.get("arm", 0.0)) > 0.0:
		t += "Прочность: %d / 100\n" % int(it.get("dur", 100))
	t += "Цена: %d зол." % ItemDB.value(it)
	body.add_child(Style.lbl(t, 30))

	if where == "bag":
		var slots: Array = ItemDB.slots_for(it)
		for s in slots:
			var cur = SaveManager.data["equipped"].get(s)
			var label := "Надеть: %s" % ItemDB.SLOT_NAMES[s]
			if cur != null:
				label += "\n(заменит: %s)" % ItemDB.plain_label(cur)
			var b := Style.btn(label, Style.MOSS, 100, 28)
			b.pressed.connect(_equip.bind(sel_uid, str(s)))
			body.add_child(b)
		var d := Style.btn("Выбросить", Style.BLOOD, 90)
		d.pressed.connect(_drop.bind(sel_uid))
		body.add_child(d)
	else:
		var u := Style.btn("Снять", Style.PLATE, 100)
		u.pressed.connect(_unequip.bind(where))
		body.add_child(u)
	var back := Style.btn("К списку", Style.PLATE, 90)
	back.pressed.connect(_set_view.bind("stats" if where != "bag" else "bag"))
	body.add_child(back)


func _equip(uid: int, slot: String) -> void:
	SaveManager.equip(uid, slot)
	SaveManager.save_game()
	view = "stats"
	msg = ""
	_render()


func _unequip(slot: String) -> void:
	if SaveManager.unequip(slot):
		SaveManager.save_game()
		view = "stats"
		msg = ""
	else:
		msg = "Рюкзак полон!"
	_render()


func _drop(uid: int) -> void:
	SaveManager.remove_item(uid)
	SaveManager.save_game()
	view = "bag"
	_render()


# ---------- Прочее ----------

func _render_misc() -> void:
	var t := "[b][color=#c9a961]Зелья[/color][/b]\n"
	var has_any := false
	for key in SaveManager.data["potions"]:
		var n: int = int(SaveManager.data["potions"][key])
		if n > 0:
			has_any = true
			t += "%s x%d: %s\n" % [ItemDB.potion_name(str(key)), n, ItemDB.potion_desc(str(key))]
	if not has_any:
		t += "нет\n"
	t += "\n[b][color=#c9a961]Руны улучшения[/color][/b]\n"
	has_any = false
	for r in range(6):
		var n2: int = SaveManager.rune_count(r)
		if n2 > 0:
			has_any = true
			t += "%s x%d\n" % [ItemDB.rune_name(r), n2]
	if not has_any:
		t += "нет\n"
	t += "\n[b][color=#c9a961]Самоцветы[/color][/b]\n"
	has_any = false
	for g in SaveManager.data["gems"]:
		has_any = true
		var gd: Dictionary = ItemDB.GEMS[g]
		t += "%s x%d: %s / %s\n" % [gd["name"], SaveManager.data["gems"][g], gd["plus"], gd["minus"]]
	if not has_any:
		t += "нет\n"
	var s: Dictionary = SaveManager.data["stats"]
	t += "\n[b][color=#c9a961]Достижения[/color][/b]\n"
	t += "Побед: %d, боссов: %d\nДуэли: побед %d, поражений %d\n" % [s["kills"], s["bosses"], s["pvp_wins"], s["pvp_losses"]]
	if SaveManager.data["trophies"].size() > 0:
		t += "Трофеи: " + ", ".join(SaveManager.data["trophies"]) + "\n"
	t += "Очки для таблицы лидеров: %d" % SaveManager.score()
	body.add_child(Style.lbl(t, 28))
