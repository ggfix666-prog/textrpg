extends Control
# Главный экран пути: «Идти дальше» -> событие (враг, добыча, сундук, алтарь, торговец, кузнец, ведьма).
# Отсюда же: рюкзак, задания, привал, смена локации, онлайн.

const REST_PER_LEVEL := 3

var stats_label: RichTextLabel
var logv
var bottom: VBoxContainer

var mode := "idle"            # idle / encounter / visit / chest / altar / locations / rest
var enemy: Dictionary = {}
var noticed := false
var visit_kind := ""          # trader / smith / witch


func _ready() -> void:
	randomize()
	if SaveManager.data["class_id"] == "":
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
		return
	var cur: Dictionary = WorldData.location(SaveManager.data["location"])
	if int(cur["min_lvl"]) > int(SaveManager.data["level"]):
		SaveManager.data["location"] = "start"
	var col := Style.screen(self, "")
	stats_label = Style.lbl("", 28)
	col.add_child(stats_label)
	logv = Style.make_log()
	col.add_child(logv)
	bottom = VBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	col.add_child(bottom)

	var loc: Dictionary = WorldData.location(SaveManager.data["location"])
	logv.add_line("Вы стоите на тропе. Локация: [color=#c9a961]%s[/color]." % loc["name"])
	if SaveManager.pending_msg != "":
		logv.add_line(SaveManager.pending_msg)
		SaveManager.pending_msg = ""
	_refresh()


func _log(t: String) -> void:
	logv.add_line(t)


func _heal_count() -> int:
	var n := 0
	for k in SaveManager.data["potions"]:
		n += int(SaveManager.data["potions"][k])
	return n


func _refresh() -> void:
	var c: Dictionary = SaveManager.CLASSES[SaveManager.data["class_id"]]
	var lvl: int = SaveManager.data["level"]
	var loc: Dictionary = WorldData.location(SaveManager.data["location"])
	var hf: Dictionary = Combat.hero_fighter()
	var t := "[b][color=#c9a961]%s[/color][/b] ур.%d (опыт %d/%d)\n" % [c["name"], lvl, SaveManager.data["exp"], SaveManager.exp_needed(lvl)]
	t += "HP [color=#e07a5f]%d/%d[/color]  Броня %d%%  Золото [color=#c9a961]%d[/color]  Зелий %d\n" % [
		hf["hp"], hf["max_hp"], int(round(Combat.arm_total(hf) * 100)), SaveManager.data["gold"], _heal_count()]
	t += "%s (побед здесь: %d)" % [loc["name"], SaveManager.kills(loc["id"])]
	if int(SaveManager.data["altar"]) > 0:
		t += "  [color=#7fb069]Благословение: %d боя[/color]" % SaveManager.data["altar"]
	stats_label.text = t
	Style.clear(bottom)
	match mode:
		"idle":
			_build_idle()
		"encounter":
			_build_encounter()
		"visit":
			_build_visit()
		"chest":
			_build_chest()
		"altar":
			_build_altar()
		"locations":
			_build_locations()
		"rest":
			_build_rest()


func _set_mode(m: String) -> void:
	mode = m
	_refresh()


func _go_scene(path: String) -> void:
	SaveManager.save_game()
	get_tree().change_scene_to_file(path)


# ---------- Кнопки ----------

func _build_idle() -> void:
	var go := Style.btn("Идти дальше", Style.MOSS, 120, 38)
	go.pressed.connect(_on_go)
	bottom.add_child(go)
	var r1 := Style.row(bottom)
	var b1 := Style.btn("Герой и рюкзак")
	b1.pressed.connect(_go_scene.bind("res://scenes/Hero.tscn"))
	r1.add_child(b1)
	var b2 := Style.btn("Задания")
	b2.pressed.connect(_go_scene.bind("res://scenes/Quests.tscn"))
	r1.add_child(b2)
	var r2 := Style.row(bottom)
	var b3 := Style.btn("Привал")
	b3.pressed.connect(_set_mode.bind("rest"))
	r2.add_child(b3)
	var b4 := Style.btn("Локация")
	b4.pressed.connect(_set_mode.bind("locations"))
	r2.add_child(b4)
	var r3 := Style.row(bottom)
	var b5 := Style.btn("Онлайн")
	b5.pressed.connect(_go_scene.bind("res://scenes/OnlineMenu.tscn"))
	r3.add_child(b5)
	var b6 := Style.btn("В меню", Style.BLOOD)
	b6.pressed.connect(_go_scene.bind("res://scenes/MainMenu.tscn"))
	r3.add_child(b6)


func _build_encounter() -> void:
	var agi: int = int(SaveManager.calc_stats()["agi"])
	if enemy["boss"]:
		var fight := Style.btn("К бою!", Style.BLOOD, 120, 38)
		fight.pressed.connect(_start_battle.bind(""))
		bottom.add_child(fight)
	elif noticed:
		var f2 := Style.btn("Сражаться", Style.BLOOD, 110, 36)
		f2.pressed.connect(_start_battle.bind(""))
		bottom.add_child(f2)
		var ch: int = int(round(WorldData.flee_chance(agi) * 100))
		var fl := Style.btn("Сбежать (шанс %d%%)" % ch, Style.PLATE, 110, 34)
		fl.pressed.connect(_on_flee)
		bottom.add_child(fl)
	else:
		var sn := Style.btn("Напасть из засады (крит)", Style.BLOOD, 110, 34)
		sn.pressed.connect(_start_battle.bind("player"))
		bottom.add_child(sn)
		var fl2 := Style.btn("Сбежать (100%)", Style.PLATE, 110, 34)
		fl2.pressed.connect(_on_flee_free)
		bottom.add_child(fl2)


func _build_visit() -> void:
	var names := {"trader": "Подойти к торговцу", "smith": "Подойти к кузнецу", "witch": "Подойти к ведьме"}
	var go := Style.btn(str(names[visit_kind]), Style.MOSS, 120, 36)
	go.pressed.connect(_open_shop)
	bottom.add_child(go)
	var pass_by := Style.btn("Пройти мимо", Style.PLATE, 110)
	pass_by.pressed.connect(_leave)
	bottom.add_child(pass_by)


func _build_chest() -> void:
	var o := Style.btn("Открыть сундук", Style.MOSS, 120, 36)
	o.pressed.connect(_open_chest)
	bottom.add_child(o)
	var p := Style.btn("Пройти мимо", Style.PLATE, 110)
	p.pressed.connect(_leave)
	bottom.add_child(p)


func _build_altar() -> void:
	var o := Style.btn("Принести жертву (-10% HP)", Style.BLOOD, 120, 34)
	o.pressed.connect(_use_altar)
	bottom.add_child(o)
	var p := Style.btn("Уйти", Style.PLATE, 110)
	p.pressed.connect(_leave)
	bottom.add_child(p)


func _build_locations() -> void:
	var lvl: int = SaveManager.data["level"]
	for l in WorldData.LOCATIONS:
		var ok: bool = lvl >= int(l["min_lvl"])
		var txt: String = str(l["name"])
		if l["id"] == SaveManager.data["location"]:
			txt = "> " + txt
		if not ok:
			txt += " (с %d ур.)" % l["min_lvl"]
		var b := Style.btn(txt, Style.BLOOD if ok else Style.DARK, 100)
		b.disabled = not ok
		b.pressed.connect(_on_pick_location.bind(l["id"]))
		bottom.add_child(b)
	var back := Style.btn("Назад", Style.PLATE, 100)
	back.pressed.connect(_set_mode.bind("idle"))
	bottom.add_child(back)


func _rest_cost() -> int:
	return int(SaveManager.data["level"]) * REST_PER_LEVEL


func _build_rest() -> void:
	var hp: int = SaveManager.data["hp"]
	var mhp: int = SaveManager.max_hp()
	var rest := Style.btn("Отдохнуть: HP до максимума (%d зол.)" % _rest_cost(), Style.MOSS, 100, 30)
	rest.disabled = hp >= mhp
	rest.pressed.connect(_on_rest)
	bottom.add_child(rest)
	var rc: int = SaveManager.repair_cost() * 2
	var rep := Style.btn("Починить снаряжение (%d зол., в лагере x2)" % rc, Style.PLATE, 100, 28)
	rep.disabled = rc <= 0
	rep.pressed.connect(_on_repair)
	bottom.add_child(rep)
	for key in SaveManager.data["potions"]:
		if str(key).begins_with("heal_") and int(SaveManager.data["potions"][key]) > 0:
			var pb := Style.btn("Выпить: %s (%d)" % [ItemDB.potion_name(str(key)), SaveManager.data["potions"][key]], Style.MOSS, 90, 28)
			pb.disabled = hp >= mhp
			pb.pressed.connect(_on_drink.bind(str(key)))
			bottom.add_child(pb)
	var back := Style.btn("Назад", Style.PLATE, 100)
	back.pressed.connect(_set_mode.bind("idle"))
	bottom.add_child(back)


# ---------- Привал и локации ----------

func _on_rest() -> void:
	var cost := _rest_cost()
	if int(SaveManager.data["gold"]) < cost:
		_log("[color=#e07a5f]Не хватает золота на привал.[/color]")
		return
	SaveManager.data["gold"] -= cost
	SaveManager.data["hp"] = SaveManager.max_hp()
	SaveManager.save_game()
	_log("Вы отдыхаете у костра и восстанавливаете силы (-%d золота)." % cost)
	_refresh()


func _on_repair() -> void:
	var cost: int = SaveManager.repair_cost() * 2
	if int(SaveManager.data["gold"]) < cost:
		_log("[color=#e07a5f]Не хватает золота на ремонт.[/color]")
		return
	SaveManager.data["gold"] -= cost
	SaveManager.repair_all()
	SaveManager.save_game()
	_log("Снаряжение починено (-%d золота)." % cost)
	_refresh()


func _on_drink(key: String) -> void:
	var cnt: int = int(SaveManager.data["potions"].get(key, 0))
	if cnt <= 0:
		return
	var tier: int = int(key.split("_")[1]) - 1
	var S: Dictionary = SaveManager.calc_stats()
	var heal_n: int = int(round(int(S["max_hp"]) * float(ItemDB.POTION_VAL["heal"][tier]) * float(S["heal_mult"])))
	var before: int = SaveManager.data["hp"]
	SaveManager.data["potions"][key] = cnt - 1
	if cnt - 1 <= 0:
		SaveManager.data["potions"].erase(key)
	SaveManager.data["hp"] = mini(int(S["max_hp"]), before + heal_n)
	SaveManager.save_game()
	_log("[color=#7fb069]Вы пьёте зелье: +%d HP.[/color]" % (int(SaveManager.data["hp"]) - before))
	_refresh()


func _on_pick_location(id: String) -> void:
	SaveManager.data["location"] = id
	SaveManager.save_game()
	_log("Вы отправляетесь в локацию: [color=#c9a961]%s[/color]." % WorldData.location(id)["name"])
	_set_mode("idle")


# ---------- События ----------

func _on_go() -> void:
	var lvl: int = SaveManager.data["level"]
	var loc_id: String = SaveManager.data["location"]
	var loc: Dictionary = WorldData.location(loc_id)

	if SaveManager.kills(loc_id) >= SaveManager.boss_threshold(loc_id):
		enemy = WorldData.make_enemy(str(loc["boss"]), lvl)
		noticed = true
		_log("[color=#ff5a5a][b]Земля дрожит...[/b][/color] Путь преграждает БОСС: [color=#c9a961]%s[/color] (ур. %d)!" % [enemy["name"], enemy["lvl"]])
		mode = "encounter"
		_refresh()
		return

	# Кубик событий: враг 60%, пустой путь 20% (добыча / сундук / алтарь), торговец 10%, кузнец 5%, ведьма 5%
	var r: float = randf()
	if r < 0.60:
		_event_enemy(loc, lvl)
	elif r < 0.72:
		_event_loot(lvl)
	elif r < 0.76:
		_log("Среди камней стоит [color=#c9a961]старый сундук[/color]. Он выглядит подозрительно.")
		mode = "chest"
	elif r < 0.80:
		_log("Вы находите [color=#c9a961]древний алтарь[/color]. Он требует жертвы кровью, взамен даёт силу.")
		mode = "altar"
	elif r < 0.90:
		_visit("trader", "Вы встречаете [color=#c9a961]бродячего торговца[/color]. Он раскладывает товар на плаще.")
	elif r < 0.95:
		_visit("smith", "Среди деревьев дымит [color=#c9a961]походная кузница[/color]. Кузнец кивает вам.")
	else:
		_visit("witch", "Из тумана выходит [color=#c9a961]ведьма[/color] со склянками на поясе.")
	_refresh()


func _visit(kind: String, text: String) -> void:
	visit_kind = kind
	_log(text)
	mode = "visit"


func _open_shop() -> void:
	SaveManager.shop_mode = visit_kind
	if visit_kind == "trader":
		SaveManager.shop_stock = ItemDB.gen_trader_stock(int(SaveManager.data["level"]))
	_go_scene("res://scenes/Shop.tscn")


func _leave() -> void:
	_log("Вы идёте дальше.")
	_set_mode("idle")


func _event_enemy(loc: Dictionary, lvl: int) -> void:
	var type_id: String = loc["enemies"].pick_random()
	enemy = WorldData.make_enemy(type_id, lvl)
	var agi: int = int(SaveManager.calc_stats()["agi"])
	noticed = randf() > WorldData.sneak_chance(agi, enemy)
	var head := "Впереди [color=#c9a961]%s[/color] (ур. %d). " % [enemy["name"], enemy["lvl"]]
	if noticed:
		_log(head + "[color=#e07a5f]Вас заметили![/color]")
	else:
		_log(head + "[color=#7fb069]Вас не заметили.[/color]")
	mode = "encounter"


# Пустой путь: немного золота, иногда зелье, самоцвет или руна
func _event_loot(lvl: int) -> void:
	var S: Dictionary = SaveManager.calc_stats()
	var luck: float = float(S["drop"])
	var gold: int = int(round((randi_range(5, 15) + lvl * 2) * (1.0 + float(S["gold"]))))
	SaveManager.add_gold(gold, true)
	var txt := "Путь пуст. В пыли блестит добыча: [color=#c9a961]+%d золота[/color]." % gold
	if randf() < 0.15 * (1.0 + luck):
		SaveManager.add_potion("heal_1", 1)
		txt += " И целое [color=#7fb069]зелье лечения[/color]!"
	elif randf() < 0.08 * (1.0 + luck):
		var g: String = ItemDB.roll_gem()
		if SaveManager.add_gem(g, 1):
			txt += " И самоцвет: [color=#c07bff]%s[/color]!" % ItemDB.GEMS[g]["name"]
	_log(txt)
	SaveManager.save_game()


func _open_chest() -> void:
	var lvl: int = SaveManager.data["level"]
	var r: float = randf()
	if r < 0.55:
		var S: Dictionary = SaveManager.calc_stats()
		var it: Dictionary = ItemDB.gen_drop(lvl + 5, float(S["drop"]) + 0.3)
		_log("Сундук открывается! " + SaveManager._stash_item(it))
		var gold: int = lvl * 8 + randi_range(5, 25)
		SaveManager.add_gold(gold, true)
		_log("Внутри лежит ещё [color=#c9a961]%d золота[/color]." % gold)
	elif r < 0.80:
		var dmg: int = maxi(1, int(int(SaveManager.max_hp()) * randf_range(0.10, 0.20)))
		SaveManager.data["hp"] = maxi(1, int(SaveManager.data["hp"]) - dmg)
		_log("[color=#e07a5f]Ловушка![/color] Из сундука бьёт шип: -%d HP." % dmg)
	else:
		_log("Сундук оказывается пустым. Только паутина.")
	SaveManager.save_game()
	_set_mode("idle")


func _use_altar() -> void:
	var cost: int = maxi(1, int(int(SaveManager.max_hp()) * 0.10))
	SaveManager.data["hp"] = maxi(1, int(SaveManager.data["hp"]) - cost)
	SaveManager.data["altar"] = 3
	SaveManager.save_game()
	_log("Алтарь вспыхивает. [color=#7fb069]Благословение: +15%% урона на 3 боя.[/color] (-%d HP)" % cost)
	_set_mode("idle")


func _on_flee_free() -> void:
	_log("Вы тихо обходите врага стороной.")
	_set_mode("idle")


func _on_flee() -> void:
	var agi: int = int(SaveManager.calc_stats()["agi"])
	if randf() < WorldData.flee_chance(agi):
		_log("[color=#7fb069]Вам удалось ускользнуть.[/color]")
		_set_mode("idle")
	else:
		_log("[color=#e07a5f]Побег не удался![/color] Враг бьёт первым.")
		_start_battle("enemy")


# first: "" — обычный бой, "player" — засада (крит), "enemy" — враг бьёт первым
func _start_battle(first: String) -> void:
	enemy["first"] = first
	SaveManager.encounter = enemy
	_go_scene("res://scenes/Battle.tscn")
