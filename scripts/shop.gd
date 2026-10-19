extends Control
# Одна сцена для трёх встреч: торговец, кузнец, ведьма.

const TABS := {
	"trader": [["buy", "Купить"], ["sell", "Продать"]],
	"smith": [["repair", "Ремонт"], ["upgrade", "Улучшить"], ["disassemble", "Разобрать"], ["sockets", "Камни"]],
	"witch": [["buy", "Купить"], ["upgrade", "Улучшить"]],
}
const TITLES := {"trader": "Торговец", "smith": "Кузнец", "witch": "Ведьма"}

var mode := ""
var tab := ""
var sel_uid := -1
var msg := ""
var info: RichTextLabel
var body: VBoxContainer


func _ready() -> void:
	randomize()
	mode = SaveManager.shop_mode
	if SaveManager.data["class_id"] == "" or not TABS.has(mode):
		get_tree().change_scene_to_file("res://scenes/Explore.tscn")
		return
	tab = str(TABS[mode][0][0])
	var col := Style.screen(self, str(TITLES[mode]), 48)
	info = Style.lbl("", 28)
	col.add_child(info)
	var nav := Style.row(col)
	for pair in TABS[mode]:
		var b := Style.btn(str(pair[1]), Style.PLATE, 85, 27)
		b.pressed.connect(_set_tab.bind(str(pair[0])))
		nav.add_child(b)
	body = Style.scroll_list(col)
	var leave := Style.btn("Уйти", Style.BLOOD, 100)
	leave.pressed.connect(_leave)
	col.add_child(leave)
	_render()


func _leave() -> void:
	SaveManager.save_game()
	SaveManager.pending_msg = "Вы прощаетесь и идёте дальше."
	get_tree().change_scene_to_file("res://scenes/Explore.tscn")


func _set_tab(t: String) -> void:
	tab = t
	sel_uid = -1
	msg = ""
	_render()


func _note(t: String) -> void:
	msg = t
	_render()


func _item_button(text: String, it: Dictionary, h: int = 110) -> Button:
	var b := Style.btn(text, Style.PLATE, h, 27)
	var c := Color(ItemDB.rarity_color(int(it["rarity"])))
	b.add_theme_color_override("font_color", c)
	b.add_theme_color_override("font_hover_color", c)
	b.add_theme_color_override("font_pressed_color", c)
	return b


# Все предметы героя: сначала надетые, потом рюкзак
func _all_items() -> Array:
	var out: Array = []
	for slot in ItemDB.SLOTS:
		var it = SaveManager.data["equipped"].get(slot)
		if it != null:
			out.append({"it": it, "where": slot})
	for it2 in SaveManager.data["inventory"]:
		out.append({"it": it2, "where": "bag"})
	return out


func _render() -> void:
	Style.clear(body)
	info.text = "Золото: [color=#c9a961]%d[/color]   Очки улучшения: %d   Рюкзак: %d/%d" % [
		SaveManager.data["gold"], SaveManager.data["points"], SaveManager.bag_used(), SaveManager.BAG_CAP]
	if msg != "":
		body.add_child(Style.lbl("[color=#e07a5f]%s[/color]" % msg, 28))
	if mode == "trader":
		if tab == "buy":
			_trader_buy()
		else:
			_trader_sell()
	elif mode == "smith":
		match tab:
			"repair":
				_smith_repair()
			"upgrade":
				_smith_upgrade()
			"disassemble":
				_smith_disassemble()
			"sockets":
				_smith_sockets()
	elif mode == "witch":
		if tab == "buy":
			_witch_buy()
		else:
			_witch_upgrade()


# ================= Торговец =================

func _trader_buy() -> void:
	body.add_child(Style.lbl("Товары торговца (цены у него свои):", 28))
	var stock: Array = SaveManager.shop_stock
	if stock.is_empty():
		body.add_child(Style.lbl("[center]Всё распродано[/center]", 30))
	for i in stock.size():
		var o: Dictionary = stock[i]
		var b: Button
		if o["type"] == "item":
			var it: Dictionary = o["item"]
			b = _item_button("%s — %d зол.\n%s" % [ItemDB.plain_label(it), o["price"], ItemDB.stats_lines(it)], it, 120)
		elif o["type"] == "rune":
			b = Style.btn("%s — %d зол." % [ItemDB.rune_name(int(o["r"])), o["price"]], Style.PLATE, 100, 27)
		else:
			var gd: Dictionary = ItemDB.GEMS[o["id"]]
			b = Style.btn("Самоцвет: %s — %d зол.\n%s / %s" % [gd["name"], o["price"], gd["plus"], gd["minus"]], Style.PLATE, 120, 26)
		b.pressed.connect(_buy.bind(i))
		body.add_child(b)


func _buy(i: int) -> void:
	var stock: Array = SaveManager.shop_stock
	if i >= stock.size():
		return
	var o: Dictionary = stock[i]
	var price: int = int(o["price"])
	if int(SaveManager.data["gold"]) < price:
		_note("Не хватает золота.")
		return
	var ok := false
	if o["type"] == "item":
		ok = SaveManager.add_item(o["item"])
	elif o["type"] == "rune":
		ok = SaveManager.add_rune(int(o["r"]), 1)
	else:
		ok = SaveManager.add_gem(str(o["id"]), 1)
	if not ok:
		_note("Рюкзак полон!")
		return
	SaveManager.data["gold"] = int(SaveManager.data["gold"]) - price
	stock.remove_at(i)
	SaveManager.save_game()
	_note("Покупка совершена (-%d зол.)." % price)


func _trader_sell() -> void:
	body.add_child(Style.lbl("Торговец платит 25% цены. Нажми на предмет, чтобы продать.", 28))
	var inv: Array = SaveManager.data["inventory"]
	var whites := 0
	for it in inv:
		if int(it["rarity"]) == 0:
			whites += 1
	if whites > 0:
		var all := Style.btn("Продать все обычные (%d шт.)" % whites, Style.BLOOD, 90, 28)
		all.pressed.connect(_sell_whites)
		body.add_child(all)
	var sorted_inv: Array = inv.duplicate()
	sorted_inv.sort_custom(func(a, b): return int(a["rarity"]) > int(b["rarity"]))
	if sorted_inv.is_empty():
		body.add_child(Style.lbl("[center]Рюкзак пуст[/center]", 30))
	for it2 in sorted_inv:
		var b := _item_button("%s — %d зол." % [ItemDB.plain_label(it2), ItemDB.sell_price(it2)], it2, 95)
		b.pressed.connect(_sell.bind(int(it2["uid"])))
		body.add_child(b)


func _sell(uid: int) -> void:
	var it: Dictionary = SaveManager.remove_item(uid)
	if it.is_empty():
		return
	var p: int = ItemDB.sell_price(it)
	SaveManager.add_gold(p)
	SaveManager.q_event("sell")
	SaveManager.save_game()
	_note("Продано: %s (+%d зол.)." % [ItemDB.plain_label(it), p])


func _sell_whites() -> void:
	var inv: Array = SaveManager.data["inventory"]
	var total := 0
	var n := 0
	var keep: Array = []
	for it in inv:
		if int(it["rarity"]) == 0:
			total += ItemDB.sell_price(it)
			n += 1
		else:
			keep.append(it)
	SaveManager.data["inventory"] = keep
	SaveManager.add_gold(total)
	SaveManager.q_event("sell", "", n)
	SaveManager.save_game()
	_note("Продано предметов: %d (+%d зол.)." % [n, total])


# ================= Кузнец =================

func _smith_repair() -> void:
	var cost: int = SaveManager.repair_cost()
	body.add_child(Style.lbl("Ремонт брони: (100 - прочность) x 0,5 золота за вещь.\nСейчас всё починить стоит: [color=#c9a961]%d[/color] зол." % cost, 30))
	var b := Style.btn("Починить всё (%d зол.)" % cost, Style.MOSS, 110)
	b.disabled = cost <= 0
	b.pressed.connect(_repair)
	body.add_child(b)


func _repair() -> void:
	var cost: int = SaveManager.repair_cost()
	if int(SaveManager.data["gold"]) < cost:
		_note("Не хватает золота.")
		return
	SaveManager.data["gold"] = int(SaveManager.data["gold"]) - cost
	SaveManager.repair_all()
	SaveManager.save_game()
	_note("Всё снаряжение починено.")


func _upgrade_gold(it: Dictionary) -> int:
	return int(it["lvl"]) * 20 + (int(it["rarity"]) + 1) * 50


func _upgrade_points(it: Dictionary) -> int:
	return int(it["lvl"]) * 2


func _smith_upgrade() -> void:
	if sel_uid >= 0:
		_upgrade_detail()
		return
	body.add_child(Style.lbl("Выбери предмет для улучшения (уровень растёт до предела редкости).", 28))
	for e in _all_items():
		var it: Dictionary = e["it"]
		var pre := "[надето] " if e["where"] != "bag" else ""
		var b := _item_button("%s%s  (до ур.%d)" % [pre, ItemDB.plain_label(it), ItemDB.item_cap(it)], it, 90)
		b.pressed.connect(_select.bind(int(it["uid"])))
		body.add_child(b)


func _select(uid: int) -> void:
	sel_uid = uid
	msg = ""
	_render()


func _upgrade_detail() -> void:
	var f: Dictionary = SaveManager.find_item(sel_uid)
	if f.is_empty():
		sel_uid = -1
		_render()
		return
	var it: Dictionary = f["it"]
	var r: int = int(it["rarity"])
	var lvl: int = int(it["lvl"])
	var cap: int = ItemDB.item_cap(it)
	var t := "%s\nУровень %d / %d\n%s\n" % [ItemDB.item_label(it), lvl, cap, ItemDB.stats_lines(it)]
	if lvl >= cap:
		t += "[color=#c9a961]Достигнут предел улучшения.[/color]"
	body.add_child(Style.lbl(t, 30))
	if lvl < cap:
		if r < 5:
			var pts: int = _upgrade_points(it)
			var g: int = _upgrade_gold(it)
			var b := Style.btn("Улучшить: %d очков + %d зол.\n(у вас очков: %d)" % [pts, g, SaveManager.data["points"]], Style.MOSS, 110, 28)
			b.disabled = int(SaveManager.data["points"]) < pts or int(SaveManager.data["gold"]) < g
			b.pressed.connect(_do_upgrade.bind(false))
			body.add_child(b)
		var rc: int = SaveManager.rune_count(r)
		var rb := Style.btn("Руна: +1 уровень (у вас рун: %d)" % rc, Style.PLATE, 100, 28)
		rb.disabled = rc <= 0
		rb.pressed.connect(_do_upgrade.bind(true))
		body.add_child(rb)
	var back := Style.btn("К списку", Style.PLATE, 90)
	back.pressed.connect(_set_tab.bind("upgrade"))
	body.add_child(back)


func _do_upgrade(with_rune: bool) -> void:
	var f: Dictionary = SaveManager.find_item(sel_uid)
	if f.is_empty():
		return
	var it: Dictionary = f["it"]
	if int(it["lvl"]) >= ItemDB.item_cap(it):
		return
	if with_rune:
		if not SaveManager.use_rune(int(it["rarity"])):
			return
	else:
		var pts: int = _upgrade_points(it)
		var g: int = _upgrade_gold(it)
		if int(SaveManager.data["points"]) < pts or int(SaveManager.data["gold"]) < g:
			_note("Не хватает очков или золота.")
			return
		SaveManager.data["points"] = int(SaveManager.data["points"]) - pts
		SaveManager.data["gold"] = int(SaveManager.data["gold"]) - g
	it["lvl"] = int(it["lvl"]) + 1
	SaveManager.q_event("upgrade")
	SaveManager.data["hp"] = clampi(int(SaveManager.data["hp"]), 1, SaveManager.max_hp())
	SaveManager.save_game()
	_note("Предмет улучшен до уровня %d!" % int(it["lvl"]))


func _smith_disassemble() -> void:
	body.add_child(Style.lbl("Разбери ненужный предмет из рюкзака на очки улучшения.", 28))
	var inv: Array = SaveManager.data["inventory"]
	if inv.is_empty():
		body.add_child(Style.lbl("[center]Рюкзак пуст[/center]", 30))
	for it in inv:
		var pts: int = int(ItemDB.DISASSEMBLE[int(it["rarity"])])
		var b := _item_button("%s → +%d очков" % [ItemDB.plain_label(it), pts], it, 90)
		b.pressed.connect(_disassemble.bind(int(it["uid"])))
		body.add_child(b)


func _disassemble(uid: int) -> void:
	var it: Dictionary = SaveManager.remove_item(uid)
	if it.is_empty():
		return
	var pts: int = int(ItemDB.DISASSEMBLE[int(it["rarity"])])
	SaveManager.data["points"] = int(SaveManager.data["points"]) + pts
	SaveManager.save_game()
	_note("Разобрано: %s (+%d очков)." % [ItemDB.plain_label(it), pts])


func _smith_sockets() -> void:
	if sel_uid >= 0:
		_sockets_detail()
		return
	body.add_child(Style.lbl("Выбери предмет с сокетами. Вставить самоцвет можно бесплатно, достать стоит 100 золота.", 28))
	var n := 0
	for e in _all_items():
		var it: Dictionary = e["it"]
		if it.get("sockets", []).size() > 0:
			n += 1
			var pre := "[надето] " if e["where"] != "bag" else ""
			var b := _item_button("%s%s\n%s" % [pre, ItemDB.plain_label(it), ItemDB.sockets_text(it)], it, 110)
			b.pressed.connect(_select.bind(int(it["uid"])))
			body.add_child(b)
	if n == 0:
		body.add_child(Style.lbl("[center]Ни у одного предмета нет сокетов[/center]", 30))


func _sockets_detail() -> void:
	var f: Dictionary = SaveManager.find_item(sel_uid)
	if f.is_empty():
		sel_uid = -1
		_render()
		return
	var it: Dictionary = f["it"]
	body.add_child(Style.lbl("%s\n%s" % [ItemDB.item_label(it), ItemDB.sockets_text(it)], 30))
	var sk: Array = it.get("sockets", [])
	for i in sk.size():
		var cur: String = str(sk[i])
		if cur != "":
			var gd: Dictionary = ItemDB.GEMS[cur]
			var rb := Style.btn("Сокет %d: извлечь «%s» (100 зол.)" % [i + 1, gd["name"]], Style.BLOOD, 90, 27)
			rb.pressed.connect(_remove_gem.bind(i))
			body.add_child(rb)
		else:
			var any_gem := false
			for g in SaveManager.data["gems"]:
				any_gem = true
				var gd2: Dictionary = ItemDB.GEMS[g]
				var b := Style.btn("Сокет %d: вставить «%s» (x%d)\n%s / %s" % [i + 1, gd2["name"], SaveManager.data["gems"][g], gd2["plus"], gd2["minus"]], Style.MOSS, 110, 26)
				b.pressed.connect(_insert_gem.bind(i, str(g)))
				body.add_child(b)
			if not any_gem:
				body.add_child(Style.lbl("Сокет %d пуст. Самоцветов нет." % [i + 1], 28))
	var back := Style.btn("К списку", Style.PLATE, 90)
	back.pressed.connect(_set_tab.bind("sockets"))
	body.add_child(back)


func _insert_gem(i: int, g: String) -> void:
	var f: Dictionary = SaveManager.find_item(sel_uid)
	if f.is_empty() or not SaveManager.use_gem(g):
		return
	f["it"]["sockets"][i] = g
	SaveManager.data["hp"] = clampi(int(SaveManager.data["hp"]), 1, SaveManager.max_hp())
	SaveManager.save_game()
	_note("Самоцвет вставлен.")


func _remove_gem(i: int) -> void:
	var f: Dictionary = SaveManager.find_item(sel_uid)
	if f.is_empty():
		return
	if int(SaveManager.data["gold"]) < 100:
		_note("Не хватает золота.")
		return
	var g: String = str(f["it"]["sockets"][i])
	if g == "":
		return
	if not SaveManager.add_gem(g, 1):
		_note("Рюкзак полон!")
		return
	SaveManager.data["gold"] = int(SaveManager.data["gold"]) - 100
	f["it"]["sockets"][i] = ""
	SaveManager.data["hp"] = clampi(int(SaveManager.data["hp"]), 1, SaveManager.max_hp())
	SaveManager.save_game()
	_note("Самоцвет извлечён.")


# ================= Ведьма =================

func _witch_buy() -> void:
	body.add_child(Style.lbl("Зелья ведьмы. Лучшие появляются с уровнем героя.", 28))
	var lvl: int = SaveManager.data["level"]
	var max_tier: int = 1 if lvl < 20 else (2 if lvl < 50 else 3)
	for tier in range(1, max_tier + 1):
		for ptype in ItemDB.POTION_TYPES:
			var key: String = ItemDB.potion_key(str(ptype), tier)
			var price: int = ItemDB.potion_price(key)
			var have: int = int(SaveManager.data["potions"].get(key, 0))
			var b := Style.btn("%s — %d зол. (есть %d)\n%s" % [ItemDB.potion_name(key), price, have, ItemDB.potion_desc(key)], Style.PLATE, 110, 26)
			b.pressed.connect(_buy_potion.bind(key))
			body.add_child(b)


func _buy_potion(key: String) -> void:
	var price: int = ItemDB.potion_price(key)
	if int(SaveManager.data["gold"]) < price:
		_note("Не хватает золота.")
		return
	SaveManager.data["gold"] = int(SaveManager.data["gold"]) - price
	SaveManager.add_potion(key, 1)
	SaveManager.save_game()
	_note("Куплено: %s." % ItemDB.potion_name(key))


func _witch_upgrade() -> void:
	body.add_child(Style.lbl("Ведьма сварит одно зелье покрепче из двух одинаковых за плату.", 28))
	var n := 0
	for key in SaveManager.data["potions"]:
		var p: PackedStringArray = str(key).split("_")
		var tier: int = int(p[1])
		var cnt: int = int(SaveManager.data["potions"][key])
		if tier < 3 and cnt >= 2:
			n += 1
			var nxt: String = ItemDB.potion_key(p[0], tier + 1)
			var cost: int = int(ItemDB.potion_price(nxt) * 0.5)
			var b := Style.btn("2x %s → %s\n(%d зол., есть %d)" % [ItemDB.potion_name(str(key)), ItemDB.potion_name(nxt), cost, cnt], Style.MOSS, 110, 26)
			b.pressed.connect(_upgrade_potion.bind(str(key)))
			body.add_child(b)
	if n == 0:
		body.add_child(Style.lbl("[center]Нужно два одинаковых зелья (не высшего уровня)[/center]", 28))


func _upgrade_potion(key: String) -> void:
	var p: PackedStringArray = key.split("_")
	var tier: int = int(p[1])
	var cnt: int = int(SaveManager.data["potions"].get(key, 0))
	if tier >= 3 or cnt < 2:
		return
	var nxt: String = ItemDB.potion_key(p[0], tier + 1)
	var cost: int = int(ItemDB.potion_price(nxt) * 0.5)
	if int(SaveManager.data["gold"]) < cost:
		_note("Не хватает золота.")
		return
	SaveManager.data["gold"] = int(SaveManager.data["gold"]) - cost
	SaveManager.data["potions"][key] = cnt - 2
	if cnt - 2 <= 0:
		SaveManager.data["potions"].erase(key)
	SaveManager.add_potion(nxt, 1)
	SaveManager.save_game()
	_note("Сварено: %s." % ItemDB.potion_name(nxt))
