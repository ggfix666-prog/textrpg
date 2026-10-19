extends Node
# Сохранение игры (JSON в user://save.json), характеристики героя, инвентарь, задания, награды.

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 9
const BAG_CAP := 40

# 5 классов. start — стартовая экипировка (слот -> шаблон), potions — стартовые зелья
const CLASSES := {
	"gladiator": {
		"name": "Гладиатор", "hp": 150, "passive": "+20% к броне",
		"desc": "Много HP и брони, тяжёлое оружие.",
		"base_dmg": 8, "str": 15, "agi": 5, "arm": 0.05,
		"potions": {"heal_1": 2}, "start": {"weapon": "rusty_sword", "armor": "leather_cuirass"},
	},
	"mage": {
		"name": "Маг", "hp": 70, "passive": "+20% к урону",
		"desc": "Высокий магический урон, мало HP.",
		"base_dmg": 10, "str": 5, "agi": 6, "arm": 0.0,
		"potions": {"heal_1": 3}, "start": {"weapon": "wood_staff", "armor": "robe"},
	},
	"vampire": {
		"name": "Вампир", "hp": 100, "passive": "+5% вампиризма",
		"desc": "Средний урон, лечение от нанесённого урона.",
		"base_dmg": 8, "str": 8, "agi": 10, "arm": 0.02,
		"potions": {"heal_1": 1}, "start": {"weapon": "dagger", "armor": "light_armor"},
	},
	"archer": {
		"name": "Лучник", "hp": 90, "passive": "+10% к криту",
		"desc": "Высокий шанс крита и ловкость.",
		"base_dmg": 8, "str": 6, "agi": 15, "arm": 0.02,
		"potions": {"heal_1": 2}, "start": {"weapon": "short_bow", "armor": "light_armor"},
	},
	"hunter": {
		"name": "Охотник", "hp": 110, "passive": "+15% к шансу дропа",
		"desc": "Баланс и бонус к добыче.",
		"base_dmg": 8, "str": 8, "agi": 9, "arm": 0.03,
		"potions": {}, "start": {"weapon": "short_bow", "offhand": "rusty_sword", "armor": "leather_cuirass"},
	},
}

var data := {}
var pending_class := ""      # класс, выбранный на экране выбора
var encounter := {}          # враг для следующего боя
var pending_msg := ""        # сообщение для экрана исследования
var shop_mode := ""          # trader / smith / witch
var shop_stock: Array = []   # ассортимент торговца
var pvp_role := ""           # host / guest (для онлайн-дуэли)
var pvp_code := ""


func _init() -> void:
	data = _empty_data()


func _empty_data() -> Dictionary:
	return {
		"v": SAVE_VERSION, "class_id": "", "level": 1, "exp": 0, "gold": 50, "hp": 1,
		"equipped": {}, "inventory": [], "runes": {}, "gems": {}, "potions": {},
		"points": 0, "uid": 1, "location": "start",
		"kills": {}, "boss_at": {}, "trophies": [], "altar": 0,
		"stats": {"kills": 0, "bosses": 0, "pvp_wins": 0, "pvp_losses": 0, "gold_earned": 0},
		"quests": {"prog": {}, "claimed": [], "date": ""},
	}


func new_uid() -> int:
	var u: int = int(data["uid"])
	data["uid"] = u + 1
	return u


# JSON возвращает целые числа как дробные: приводим обратно
func norm(v):
	var t: int = typeof(v)
	if t == TYPE_FLOAT:
		if v == floor(v) and absf(v) < 1.0e15:
			return int(v)
		return v
	if t == TYPE_DICTIONARY:
		var out := {}
		for k in v:
			out[k] = norm(v[k])
		return out
	if t == TYPE_ARRAY:
		var out2: Array = []
		for x in v:
			out2.append(norm(x))
		return out2
	return v


# ---------- Сохранение ----------

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Не удалось открыть файл сохранения")
		return
	f.store_string(JSON.stringify(data))
	f.close()


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	parsed = norm(parsed)
	if int(parsed.get("v", 0)) < SAVE_VERSION:
		return false    # сохранение от старой версии игры
	if not (str(parsed.get("class_id", "")) in CLASSES):
		return false
	var d := _empty_data()
	for k in parsed:
		d[k] = parsed[k]
	for k in ["stats", "quests"]:
		var base: Dictionary = _empty_data()[k]
		for kk in base:
			if not d[k].has(kk):
				d[k][kk] = base[kk]
	data = d
	encounter = {}
	pending_msg = ""
	q_ensure_daily()
	data["hp"] = clampi(int(data["hp"]), 1, max_hp())
	return true


func new_game(class_id: String) -> void:
	data = _empty_data()
	data["class_id"] = class_id
	var c: Dictionary = CLASSES[class_id]
	for slot in c["start"]:
		data["equipped"][slot] = ItemDB.gen_item(str(c["start"][slot]), 0, 1, false)
	data["potions"] = c["potions"].duplicate()
	data["hp"] = max_hp()
	encounter = {}
	pending_msg = ""
	q_ensure_daily()
	save_game()


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	data = _empty_data()
	encounter = {}
	pending_msg = ""


# ---------- Характеристики героя ----------

func exp_needed(level: int) -> int:
	return level * 40


func calc_stats() -> Dictionary:
	var id: String = data["class_id"]
	var lvl: int = int(data["level"])
	var c: Dictionary = CLASSES[id]
	var S := {
		"base": float(int(c["base_dmg"]) + (lvl - 1) * 2), "str": float(int(c["str"]) + (lvl - 1)),
		"agi": float(c["agi"]), "hp": float(int(c["hp"]) + (lvl - 1) * 12), "weapon": 0.0,
		"base_arm": float(c["arm"]), "crit": 0.05, "vamp": 0.0, "gold": 0.0, "drop": 0.0,
		"dmg_mult": 1.0, "hp_mult": 1.0, "arm_mult": 1.0, "acc": 1.0, "speed": 0.0,
		"mres": 0.25 if id == "mage" else 0.05, "taken": 1.0, "base_mult": 1.0,
		"skull": 0.0, "kill_heal": 0, "heal_mult": 1.0, "pieces": [],
	}
	var fav: Array = ItemDB.FAV_WEAPONS[id]
	var gems: Array = []
	for slot in ItemDB.SLOTS:
		var it = data["equipped"].get(slot)
		if it == null:
			continue
		var st: Dictionary = ItemDB.item_stats(it)
		var t: Dictionary = ItemDB.TEMPLATES[it["tpl"]]
		var dmg: float = float(st.get("dmg", 0.0))
		if t["kind"] == "weapon":
			if slot == "weapon":
				if str(t.get("wt", "")) in fav:
					dmg *= 1.10
				S["weapon"] += dmg
			else:
				S["weapon"] += dmg * 0.4    # второе оружие даёт 40% урона
		else:
			S["weapon"] += dmg
		S["hp"] += float(st.get("hp", 0.0))
		S["str"] += float(st.get("str", 0.0))
		S["agi"] += float(st.get("agi", 0.0))
		S["crit"] += float(st.get("crit", 0.0))
		S["vamp"] += float(st.get("vamp", 0.0))
		S["gold"] += float(st.get("gold", 0.0))
		S["drop"] += float(st.get("drop", 0.0))
		if float(st.get("arm", 0.0)) > 0.0:
			S["pieces"].append({"slot": slot, "arm": float(st["arm"]), "dur": int(it.get("dur", 100))})
		for g in it.get("sockets", []):
			if str(g) != "":
				gems.append(str(g))
	for g in gems:
		var mods: Dictionary = ItemDB.GEMS[g]["mods"]
		for k in mods:
			var key: String = str(k)
			var val: float = float(mods[k])
			if key == "all":
				S["str"] += val
				S["agi"] += val
				S["hp"] += val * 5.0
			elif key == "kill_heal":
				S["kill_heal"] += int(val)
			elif S.has(key):
				S[key] += val
	match id:
		"gladiator":
			S["arm_mult"] += 0.20
		"mage":
			S["dmg_mult"] += 0.20
		"vampire":
			S["vamp"] += 0.05
		"archer":
			S["crit"] += 0.10
		"hunter":
			S["drop"] += 0.15
	S["crit"] += float(S["agi"]) * 0.004
	S["speed"] += float(S["agi"]) * 0.002
	S["base"] = float(S["base"]) * float(S["base_mult"])
	S["max_hp"] = maxi(10, int(round(float(S["hp"]) * float(S["hp_mult"]))))
	return S


func max_hp() -> int:
	return int(calc_stats()["max_hp"])


# ---------- Золото, опыт, очки ----------

func add_gold(n: int, track: bool = false) -> void:
	data["gold"] = int(data["gold"]) + n
	if track and n > 0:
		data["stats"]["gold_earned"] = int(data["stats"]["gold_earned"]) + n
		q_event("gold", "", n)


# Добавляет опыт, повышает уровни. Возвращает сколько уровней получено.
func add_exp(n: int) -> int:
	data["exp"] = int(data["exp"]) + n
	var gained := 0
	while int(data["exp"]) >= exp_needed(int(data["level"])):
		data["exp"] = int(data["exp"]) - exp_needed(int(data["level"]))
		data["level"] = int(data["level"]) + 1
		gained += 1
	if gained > 0:
		data["hp"] = max_hp()    # новый уровень лечит до максимума
		q_event("level", "", int(data["level"]))
	return gained


func score() -> int:
	var s: Dictionary = data["stats"]
	return int(data["level"]) * 100 + int(s["bosses"]) * 150 + int(s["pvp_wins"]) * 250 + int(s["kills"])


# ---------- Рюкзак ----------

func bag_used() -> int:
	var n: int = data["inventory"].size()
	for r in data["runes"]:
		n += ceili(float(data["runes"][r]) / 10.0)
	for g in data["gems"]:
		n += ceili(float(data["gems"][g]) / 10.0)
	return n


func bag_free() -> int:
	return BAG_CAP - bag_used()


func add_item(it: Dictionary) -> bool:
	if bag_free() <= 0:
		return false
	data["inventory"].append(it)
	return true


func _stack_room(cur: int, n: int) -> bool:
	return ceili(float(cur + n) / 10.0) - ceili(float(cur) / 10.0) <= bag_free()


func add_rune(r: int, n: int = 1) -> bool:
	var cur: int = int(data["runes"].get(str(r), 0))
	if not _stack_room(cur, n):
		return false
	data["runes"][str(r)] = cur + n
	return true


func add_gem(g: String, n: int = 1) -> bool:
	var cur: int = int(data["gems"].get(g, 0))
	if not _stack_room(cur, n):
		return false
	data["gems"][g] = cur + n
	return true


func add_potion(key: String, n: int = 1) -> void:
	data["potions"][key] = int(data["potions"].get(key, 0)) + n


func rune_count(r: int) -> int:
	return int(data["runes"].get(str(r), 0))


func use_rune(r: int) -> bool:
	var c: int = rune_count(r)
	if c <= 0:
		return false
	if c == 1:
		data["runes"].erase(str(r))
	else:
		data["runes"][str(r)] = c - 1
	return true


func use_gem(g: String) -> bool:
	var c: int = int(data["gems"].get(g, 0))
	if c <= 0:
		return false
	if c == 1:
		data["gems"].erase(g)
	else:
		data["gems"][g] = c - 1
	return true


func inv_index(uid: int) -> int:
	var inv: Array = data["inventory"]
	for i in inv.size():
		if int(inv[i]["uid"]) == uid:
			return i
	return -1


# Ищет предмет в рюкзаке и на герое. Возвращает {"it": предмет, "where": "bag" или слот} либо {}
func find_item(uid: int) -> Dictionary:
	var i: int = inv_index(uid)
	if i >= 0:
		return {"it": data["inventory"][i], "where": "bag"}
	for slot in data["equipped"]:
		var it = data["equipped"][slot]
		if it != null and int(it["uid"]) == uid:
			return {"it": it, "where": slot}
	return {}


func equip(uid: int, slot_pick: String = "") -> bool:
	var i: int = inv_index(uid)
	if i < 0:
		return false
	var it: Dictionary = data["inventory"][i]
	var slots: Array = ItemDB.slots_for(it)
	var target: String = slot_pick if slot_pick in slots else ""
	if target == "":
		for s in slots:
			if data["equipped"].get(s) == null:
				target = s
				break
		if target == "":
			target = slots[0]
	var old = data["equipped"].get(target)
	data["inventory"].remove_at(i)
	data["equipped"][target] = it
	if old != null:
		data["inventory"].append(old)
	data["hp"] = clampi(int(data["hp"]), 1, max_hp())
	_equip_events()
	return true


func unequip(slot: String) -> bool:
	var it = data["equipped"].get(slot)
	if it == null or bag_free() <= 0:
		return false
	data["equipped"].erase(slot)
	data["inventory"].append(it)
	data["hp"] = clampi(int(data["hp"]), 1, max_hp())
	return true


func _equip_events() -> void:
	var count := 0
	var best := 0
	for slot in data["equipped"]:
		var it = data["equipped"][slot]
		if it != null:
			count += 1
			best = maxi(best, int(it["rarity"]) + 1)
	q_event("slots", "", count)
	if best >= 2:
		q_event("equip_rarity", "", 1)


func remove_item(uid: int) -> Dictionary:
	var i: int = inv_index(uid)
	if i < 0:
		return {}
	var it: Dictionary = data["inventory"][i]
	data["inventory"].remove_at(i)
	return it


# ---------- Прогресс по локациям ----------

func kills(loc_id: String) -> int:
	return int(data["kills"].get(loc_id, 0))


func boss_threshold(loc_id: String) -> int:
	if not data["boss_at"].has(loc_id):
		data["boss_at"][loc_id] = randi_range(10, 15)
		save_game()
	return int(data["boss_at"][loc_id])


func add_kill(loc_id: String) -> void:
	data["kills"][loc_id] = kills(loc_id) + 1


func on_boss_defeated(loc_id: String, boss_name: String) -> void:
	data["kills"][loc_id] = 0
	data["boss_at"][loc_id] = randi_range(10, 15)
	data["trophies"].append(boss_name)


# ---------- Задания ----------

func q_ensure_daily() -> void:
	var today: String = Time.get_date_string_from_system()
	var q: Dictionary = data["quests"]
	if str(q.get("date", "")) != today:
		q["date"] = today
		for qq in WorldData.QUESTS:
			if qq["daily"]:
				q["prog"].erase(qq["id"])
				q["claimed"].erase(qq["id"])


func q_event(kind: String, arg: String = "", n: int = 1) -> void:
	var q: Dictionary = data["quests"]
	for qq in WorldData.QUESTS:
		if qq["kind"] != kind:
			continue
		if str(qq["arg"]) != "" and str(qq["arg"]) != arg:
			continue
		if q["claimed"].has(qq["id"]):
			continue
		var cur: int = int(q["prog"].get(qq["id"], 0))
		if qq.get("set", false):
			cur = maxi(cur, n)
		else:
			cur += n
		q["prog"][qq["id"]] = mini(cur, int(qq["goal"]))


func q_progress(id: String) -> int:
	return int(data["quests"]["prog"].get(id, 0))


func q_claim(qq: Dictionary) -> String:
	var q: Dictionary = data["quests"]
	if q["claimed"].has(qq["id"]) or q_progress(qq["id"]) < int(qq["goal"]):
		return ""
	q["claimed"].append(qq["id"])
	add_gold(int(qq["gold"]))
	var lv: int = add_exp(int(qq["exp"]))
	var s := "Награда: золото +%d, опыт +%d." % [qq["gold"], qq["exp"]]
	if lv > 0:
		s += " Новый уровень: %d!" % int(data["level"])
	save_game()
	return s


# ---------- Награды и смерть ----------

# Автопродажа, если рюкзак полон. Возвращает строку для лога.
func _stash_item(it: Dictionary) -> String:
	if add_item(it):
		return "Добыча: %s (%s)" % [ItemDB.item_label(it), ItemDB.stats_lines(it)]
	var p: int = ItemDB.sell_price(it)
	add_gold(p)
	return "Рюкзак полон: %s продан за %d зол." % [ItemDB.plain_label(it), p]


# Победа: золото, опыт, очки улучшения, добыча. Возвращает строки для лога.
func grant_victory(E: Dictionary, loc_id: String) -> Array:
	var S: Dictionary = calc_stats()
	var lines: Array = []
	var lvl: int = int(E["lvl"])
	var boss: bool = E["boss"]
	var elite: bool = E["elite"]
	var gold_mult: float = (1.0 + float(S["gold"])) * (5.0 if boss else 1.0) * (1.5 if elite else 1.0)
	var gold: int = int(round((lvl * 5 + randi_range(1, 10)) * gold_mult))
	var xp: int = int(round((20 + lvl * 5) * (3.0 if boss else 1.0) * (1.5 if elite else 1.0)))
	var pts: int = 1 + lvl / 10 + (3 if boss else 0)
	add_gold(gold, true)
	data["points"] = int(data["points"]) + pts
	data["stats"]["kills"] = int(data["stats"]["kills"]) + 1
	lines.append("[color=#c9a961][b]Победа![/b][/color] Золото +%d, опыт +%d, очки улучшения +%d." % [gold, xp, pts])

	var luck: float = float(S["drop"])
	if int(S["kill_heal"]) > 0:
		data["hp"] = mini(int(S["max_hp"]), int(data["hp"]) + int(S["kill_heal"]))
	if boss:
		data["stats"]["bosses"] = int(data["stats"]["bosses"]) + 1
		on_boss_defeated(loc_id, str(E["name"]))
		var bi: Dictionary = ItemDB.gen_boss_item(str(E["id"]))
		lines.append("[color=#ff5a5a][b]С босса падает красный предмет![/b][/color]")
		lines.append(_stash_item(bi))
		if add_rune(5, 1):
			lines.append("Руна босса (+1 уровень красному предмету).")
		lines.append(_stash_item(ItemDB.gen_drop(lvl, luck + 0.5)))
		q_event("boss")
	else:
		add_kill(loc_id)
		if randf() < (0.60 if elite else 0.30) * (1.0 + luck):
			lines.append(_stash_item(ItemDB.gen_drop(lvl, luck)))
		if randf() < 0.10 * (1.0 + luck):
			var rr: int = ItemDB.roll_rarity(lvl, luck)
			if add_rune(rr, 1):
				lines.append("Найдена: %s." % ItemDB.rune_name(rr))
		if randf() < 0.05 * (1.0 + luck):
			var g: String = ItemDB.roll_gem()
			if add_gem(g, 1):
				lines.append("Найден самоцвет: %s." % ItemDB.GEMS[g]["name"])
		if randf() < 0.10:
			var tier: int = 1 if lvl < 15 else (randi_range(1, 2) if lvl < 50 else randi_range(1, 3))
			var pt: String = ["heal", "heal", "poison", "bomb", "bleed", "crit"].pick_random()
			var key: String = ItemDB.potion_key(pt, tier)
			add_potion(key, 1)
			lines.append("Найдено: %s." % ItemDB.potion_name(key))
	q_event("kill", str(E["id"]))
	var gl: int = add_exp(xp)
	for i in gl:
		lines.append("[color=#c9a961][b]Новый уровень: %d![/b][/color] Здоровье восстановлено." % (int(data["level"]) - gl + 1 + i))
	if int(data["altar"]) > 0:
		data["altar"] = int(data["altar"]) - 1
	return lines


# Смерть: -20% золота, пропадают 3-7 случайных предмета из рюкзака, надетая броня ломается
func apply_death() -> Array:
	var lines: Array = []
	var lost: int = int(int(data["gold"]) * 0.2)
	data["gold"] = int(data["gold"]) - lost
	lines.append("Потеряно золота: %d." % lost)
	var inv: Array = data["inventory"]
	inv.shuffle()
	var n: int = randi_range(3, 7)
	var names: Array = []
	while names.size() < n and not inv.is_empty():
		var it: Dictionary = inv.pop_back()
		names.append(ItemDB.plain_label(it))
	if names.size() > 0:
		lines.append("Потеряно из рюкзака: " + ", ".join(names) + ".")
	for slot in data["equipped"]:
		var eq = data["equipped"][slot]
		if eq != null:
			eq["dur"] = 0
	lines.append("Надетое снаряжение сломалось: его нужно починить.")
	data["hp"] = max_hp()
	return lines


# ---------- Ремонт ----------
# Ремонт по ТЗ: (макс. прочность - текущая) * 0.5 золота за каждую надетую вещь с бронёй

func repair_cost() -> int:
	var total := 0.0
	for slot in data["equipped"]:
		var it = data["equipped"][slot]
		if it != null and float(ItemDB.item_stats(it).get("arm", 0.0)) > 0.0:
			total += (100 - int(it.get("dur", 100))) * 0.5
	return int(round(total))


func repair_all() -> void:
	for slot in data["equipped"]:
		var it = data["equipped"][slot]
		if it != null:
			it["dur"] = 100
