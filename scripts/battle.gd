extends Control
# ЭТАП 2: пошаговый бой.
# В начале хода выпадает 1-3 действия. Игрок набирает комбо (Удар / Зелье / Способность),
# жмёт "Закончить ход" — действия выполняются по очереди, затем отвечает враг.

# Способности классов (выбираются ОДИН раз перед боем). cd — кулдаун в ходах.
const ABILITIES := {
	"gladiator": [
		{"id": "execute", "name": "Казнь", "cd": 5, "desc": "150% урона, игнорирует 30% брони"},
		{"id": "shield_wall", "name": "Стена щитов", "cd": 6, "desc": "Блок 100% урона в этот ход, лечит 10% HP"},
	],
	"mage": [
		{"id": "meteor", "name": "Метеор", "cd": 6, "desc": "120% урона по всем врагам"},
		{"id": "antimagic", "name": "Анти-магия", "cd": 7, "desc": "Враг не пьёт зелья 4 хода"},
	],
	"vampire": [
		{"id": "bloodthirst", "name": "Жажда крови", "cd": 5, "desc": "150% урона, лечит 50% от нанесённого"},
		{"id": "bats", "name": "Стая мышей", "cd": 6, "desc": "Враг -20% точности на 3 хода, вы +5% HP"},
	],
	"archer": [
		{"id": "double_shot", "name": "Двойной выстрел", "cd": 4, "desc": "2 удара по 80% урона"},
		{"id": "snipe", "name": "Снайперский выстрел", "cd": 5, "desc": "Гарантированный крит (175% урона)"},
	],
	"hunter": [
		{"id": "trap", "name": "Ядовитая ловушка", "cd": 6, "desc": "50% урона + яд 10% HP врага 3 хода"},
		{"id": "pet", "name": "Верный питомец", "cd": 8, "desc": "Волк бьёт врага 3 хода по 30% урона"},
	],
}

const CRIT_MULT := 1.75
const POTION_HEAL := 0.35

var P := {}                # герой
var E := {}                # враг
var ability := {}          # выбранная способность
var ability_cd := 0        # текущий кулдаун
var actions_total := 0     # сколько действий выпало в этом ходу
var queue: Array = []      # набранное комбо: "hit" / "potion" / "ability"
var phase := "pick"        # pick (выбор способности) / turn (ход игрока) / over (конец боя)
var turn := 1
var block_active := false  # Стена щитов

var stats_label: RichTextLabel
var log_label: RichTextLabel
var bottom: VBoxContainer


func _ready() -> void:
	randomize()
	var id: String = SaveManager.data["class_id"]
	if not (id in SaveManager.CLASSES):
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
		return
	_build_ui()
	_build_fighters()
	if E.get("boss", false):
		_log("[color=#7a1f1f][b]БОСС![/b][/color] Перед вами [color=#c9a961]%s[/color] (ур. %d)." % [E["name"], E["lvl"]])
	else:
		_log("Из тени выползает [color=#c9a961]%s[/color] (ур. %d)." % [E["name"], E["lvl"]])
	match E.get("first", ""):
		"player":
			_log("[color=#c9a961]Вы нападаете из засады![/color]")
			_hit_enemy(1.0, true)
		"enemy":
			_log("Враг не дал вам уйти и бьёт первым!")
			_enemy_turn()
	if E["hp"] <= 0:
		_victory()
		return
	if P["hp"] <= 0:
		_defeat()
		return
	_log("Выбери способность на этот бой. Сменить её в бою нельзя.")
	_refresh()


# ---------- Интерфейс ----------

func _build_ui() -> void:
	Style.add_bg(self)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", 24)
	m.add_theme_constant_override("margin_right", 24)
	m.add_theme_constant_override("margin_top", 60)
	m.add_theme_constant_override("margin_bottom", 24)
	add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	m.add_child(v)

	stats_label = Style.make_text("", 26)
	v.add_child(stats_label)

	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.scroll_following = true
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.add_theme_font_size_override("normal_font_size", 28)
	log_label.add_theme_font_size_override("bold_font_size", 28)
	log_label.add_theme_color_override("default_color", Style.TEXT)
	v.add_child(log_label)

	bottom = VBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	v.add_child(bottom)


func _log(text: String) -> void:
	log_label.append_text(text + "\n")


func _clear_bottom() -> void:
	for c in bottom.get_children():
		bottom.remove_child(c)
		c.queue_free()


func _small_button(text: String, color: Color = Color("#4a3520")) -> Button:
	var b := Style.make_button(text, color)
	b.add_theme_font_size_override("font_size", 26)
	b.custom_minimum_size = Vector2(0, 80)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


func _refresh() -> void:
	# Верхняя панель со статами героя и врага
	var t := "[b][color=#c9a961]%s[/color][/b] ур.%d  HP [color=#d46a6a]%d/%d[/color]  Броня %d%% (проч. %d)  Зелья %d\n" % [
		P["name"], P["lvl"], P["hp"], P["max_hp"], int(round(P["armor"] * 100)), P["armor_dur"], P["potions"]]
	t += "[b][color=#c9a961]%s[/color][/b] ур.%d  HP [color=#d46a6a]%d/%d[/color]" % [
		E["name"], E["lvl"], E["hp"], E["max_hp"]]
	var st := []
	if E["poison_turns"] > 0:
		st.append("яд")
	if E["miss_turns"] > 0:
		st.append("мыши")
	if E["nopotion_turns"] > 0:
		st.append("анти-магия")
	if E["wolf_turns"] > 0:
		st.append("волк")
	if st.size() > 0:
		t += "  [color=#7fb069](%s)[/color]" % ", ".join(st)
	stats_label.text = t

	_clear_bottom()
	if phase == "pick":
		_build_pick()
	elif phase == "turn":
		_build_turn()
	elif phase == "over":
		var back := Style.make_button("Продолжить путь", Style.MOSS)
		back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Explore.tscn"))
		bottom.add_child(back)


func _build_pick() -> void:
	var abilities: Array = ABILITIES[P["id"]]
	for a in abilities:
		var b := Style.make_button("%s (КД %d)\n%s" % [a["name"], a["cd"], a["desc"]])
		b.add_theme_font_size_override("font_size", 26)
		b.pressed.connect(_on_pick.bind(a))
		bottom.add_child(b)


func _build_turn() -> void:
	var names := {"hit": "Удар", "potion": "Зелье", "ability": ability["name"]}
	var parts := []
	for k in queue:
		parts.append(names[k])
	var info := Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 26)
	info.add_theme_color_override("font_color", Style.GOLD)
	info.text = "Ход %d. Действий: %d, выбрано: %d\nКомбо: %s" % [
		turn, actions_total, queue.size(), " + ".join(parts) if parts.size() > 0 else "—"]
	bottom.add_child(info)

	var free: bool = queue.size() < actions_total
	var potions_queued: int = queue.count("potion")

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	bottom.add_child(row)

	var hit := _small_button("Удар")
	hit.disabled = not free
	hit.pressed.connect(_on_add.bind("hit"))
	row.add_child(hit)

	var pot := _small_button("Зелье (%d)" % (P["potions"] - potions_queued), Style.MOSS)
	pot.disabled = (not free) or (P["potions"] - potions_queued <= 0)
	pot.pressed.connect(_on_add.bind("potion"))
	row.add_child(pot)

	var ab_text: String = ability["name"]
	if ability_cd > 0:
		ab_text += " (КД %d)" % ability_cd
	var ab := _small_button(ab_text, Style.BLOOD)
	ab.disabled = (not free) or ability_cd > 0 or queue.has("ability")
	ab.pressed.connect(_on_add.bind("ability"))
	row.add_child(ab)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	bottom.add_child(row2)

	var undo := _small_button("Отменить")
	undo.disabled = queue.is_empty()
	undo.pressed.connect(_on_undo)
	row2.add_child(undo)

	var end := _small_button("Закончить ход", Style.MOSS)
	end.pressed.connect(_end_turn)
	row2.add_child(end)


# ---------- Подготовка бойцов ----------

func _build_fighters() -> void:
	var id: String = SaveManager.data["class_id"]
	var c: Dictionary = SaveManager.CLASSES[id]
	var lvl: int = SaveManager.data["level"]
	P = {
		"id": id, "name": c["name"], "lvl": lvl,
		"max_hp": c["hp"] + (lvl - 1) * 12,
		"base": c["base_dmg"] + (lvl - 1) * 2,
		"weapon": c["weapon"],
		"str": c["str"] + (lvl - 1),
		"agi": c["agi"],
		"armor": c["armor"],
		"armor_dur": 100,
		"crit": 0.05 + c["agi"] * 0.004,   # шанс крита зависит от ловкости
		"vamp": 0.0,
		"dmg_mult": 1.0,
		"potions": SaveManager.data["potions"],
	}
	# Пассивки классов
	match id:
		"gladiator":
			P["armor"] = P["armor"] * 1.2
		"mage":
			P["dmg_mult"] = 1.2
		"vampire":
			P["vamp"] = 0.05
		"archer":
			P["crit"] = P["crit"] + 0.10
	P["max_hp"] = SaveManager.max_hp()
	P["hp"] = clampi(int(SaveManager.data["hp"]), 1, P["max_hp"])
	P["armor_dur"] = int(SaveManager.data["armor_dur"])

	# Враг приходит с экрана исследования (если его нет — тестовый гоблин)
	E = SaveManager.encounter.duplicate(true)
	if E.is_empty():
		E = WorldData.make_enemy("goblin", lvl)


# ---------- Ввод игрока ----------

func _on_pick(a: Dictionary) -> void:
	ability = a
	ability_cd = 0
	phase = "turn"
	turn = 1
	_log("Выбрана способность: [color=#c9a961]%s[/color]." % a["name"])
	_roll_actions()
	_refresh()


func _roll_actions() -> void:
	actions_total = randi_range(1, 3)
	queue.clear()
	_log("[color=#c9a961]— Ход %d: выпало действий — %d —[/color]" % [turn, actions_total])


func _on_add(kind: String) -> void:
	if queue.size() >= actions_total:
		return
	queue.append(kind)
	_refresh()


func _on_undo() -> void:
	if not queue.is_empty():
		queue.pop_back()
		_refresh()


# ---------- Ход ----------

func _end_turn() -> void:
	phase = "busy"
	for k in queue:
		if E["hp"] <= 0:
			break
		_do_action(k)
	queue.clear()
	if E["hp"] <= 0:
		_victory()
		return

	_end_effects()
	if E["hp"] <= 0:
		_victory()
		return

	_enemy_turn()
	if P["hp"] <= 0:
		_defeat()
		return

	_tick()
	turn += 1
	phase = "turn"
	_roll_actions()
	_refresh()


func _do_action(kind: String) -> void:
	match kind:
		"hit":
			_hit_enemy(1.0)
		"potion":
			if P["potions"] > 0:
				P["potions"] -= 1
				var h := int(round(P["max_hp"] * POTION_HEAL))
				_log("Вы пьёте зелье.")
				_heal_player(h)
		"ability":
			_use_ability()


# Расчёт урона: (База + Оружие) * (1 + Сила/100) * Крит, затем броня врага
func _player_hit(mult: float, force_crit: bool, armor_ignore: float) -> Dictionary:
	var dmg: float = (P["base"] + P["weapon"]) * (1.0 + P["str"] / 100.0) * mult * P["dmg_mult"]
	var is_crit: bool = force_crit or randf() < P["crit"]
	if is_crit:
		dmg *= CRIT_MULT
	var arm: float = E["armor"] * (1.0 - armor_ignore)
	dmg *= (1.0 - arm)
	return {"dmg": maxi(1, int(round(dmg))), "crit": is_crit}


func _hit_enemy(mult: float, force_crit: bool = false, armor_ignore: float = 0.0,
		label: String = "Вы наносите", lifesteal: bool = true) -> int:
	var r := _player_hit(mult, force_crit, armor_ignore)
	E["hp"] = maxi(0, E["hp"] - r["dmg"])
	var crit_txt := ""
	if r["crit"]:
		crit_txt = " [color=#c9a961]КРИТ![/color]"
	_log("%s [b]%d[/b] урона.%s" % [label, r["dmg"], crit_txt])
	if lifesteal and P["vamp"] > 0.0:
		_heal_player(maxi(1, int(round(r["dmg"] * P["vamp"]))))
	return r["dmg"]


func _heal_player(n: int) -> void:
	var before: int = P["hp"]
	P["hp"] = mini(P["max_hp"], P["hp"] + n)
	_log("[color=#7fb069]Вы восстанавливаете %d HP.[/color]" % (P["hp"] - before))


func _use_ability() -> void:
	ability_cd = ability["cd"]
	_log("[color=#c9a961]Способность: %s![/color]" % ability["name"])
	match ability["id"]:
		"execute":
			_hit_enemy(1.5, false, 0.3)
		"shield_wall":
			block_active = true
			_log("Вы прячетесь за щитами: следующий удар будет заблокирован.")
			_heal_player(int(round(P["max_hp"] * 0.10)))
		"meteor":
			_hit_enemy(1.2)
		"antimagic":
			E["nopotion_turns"] = 4
			_log("Враг не сможет пить зелья 4 хода.")
		"bloodthirst":
			var d := _hit_enemy(1.5)
			_heal_player(int(round(d * 0.5)))
		"bats":
			E["miss_turns"] = 3
			_log("Стая мышей кружит вокруг врага (-20% точности на 3 хода).")
			_heal_player(int(round(P["max_hp"] * 0.05)))
		"double_shot":
			_hit_enemy(0.8)
			if E["hp"] > 0:
				_hit_enemy(0.8)
		"snipe":
			_hit_enemy(1.0, true)
		"trap":
			_hit_enemy(0.5)
			E["poison_turns"] = 3
			_log("Враг отравлен на 3 хода.")
		"pet":
			E["wolf_turns"] = 3
			_log("Верный волк прыгает в бой на 3 хода.")


# Эффекты в конце хода: яд и волк
func _end_effects() -> void:
	if E["poison_turns"] > 0:
		var pd := maxi(1, int(round(E["max_hp"] * 0.10)))
		E["hp"] = maxi(0, E["hp"] - pd)
		E["poison_turns"] -= 1
		_log("[color=#7fb069]Яд наносит %d урона.[/color]" % pd)
	if E["hp"] > 0 and E["wolf_turns"] > 0:
		E["wolf_turns"] -= 1
		_hit_enemy(0.3, false, 0.0, "Волк кусает врага на", false)


func _enemy_turn() -> void:
	# Враг пьёт зелье при низком HP (если ему не мешает Анти-магия)
	if E["hp"] < E["max_hp"] * 0.3 and E["potions"] > 0:
		if E["nopotion_turns"] > 0:
			_log("Враг тянется к зелью, но магия мешает ему!")
		else:
			E["potions"] -= 1
			var h := int(round(E["max_hp"] * 0.35))
			E["hp"] = mini(E["max_hp"], E["hp"] + h)
			_log("%s пьёт зелье и лечится на %d." % [E["name"], h])
			return

	var acc: float = E["acc"]
	if E["miss_turns"] > 0:
		acc -= 0.2
	if randf() > acc:
		_log("%s промахивается!" % E["name"])
		return
	if block_active:
		_log("Стена щитов полностью отражает удар!")
		return

	var dmg: float = E["dmg"] * randf_range(0.85, 1.15)
	if P["armor_dur"] > 0:
		dmg *= (1.0 - P["armor"])
		P["armor_dur"] -= 1
	else:
		_log("Ваша броня разрушена и не защищает!")
	var final := maxi(1, int(round(dmg)))
	P["hp"] = maxi(0, P["hp"] - final)
	_log("%s бьёт вас на [color=#d46a6a][b]%d[/b][/color] урона." % [E["name"], final])


# Конец хода: уменьшаем счётчики эффектов и кулдаун
func _tick() -> void:
	block_active = false
	for k in ["nopotion_turns", "miss_turns"]:
		if E[k] > 0:
			E[k] -= 1
	ability_cd = maxi(0, ability_cd - 1)


# ---------- Итог боя ----------

func _victory() -> void:
	phase = "over"
	var is_boss: bool = E.get("boss", false)
	var gold: int = E["lvl"] * 5 + randi_range(1, 10)   # формула из ТЗ
	var xp: int = 20 + E["lvl"] * 5
	if is_boss:
		gold *= 5
		xp *= 3
	SaveManager.data["gold"] += gold
	SaveManager.data["exp"] += xp
	SaveManager.data["potions"] = P["potions"]
	SaveManager.data["hp"] = P["hp"]
	SaveManager.data["armor_dur"] = P["armor_dur"]
	_log("[color=#c9a961][b]Победа![/b][/color] Золото: +%d, опыт: +%d." % [gold, xp])

	var loc: String = SaveManager.data["location"]
	if is_boss:
		SaveManager.on_boss_defeated(loc, E["name"])
		_log("[color=#c9a961][b]Босс повержен![/b][/color] С него падает уникальный красный предмет. Трофей записан (предметы появятся на следующем этапе).")
	else:
		SaveManager.add_kill(loc)

	while SaveManager.data["exp"] >= SaveManager.exp_needed(SaveManager.data["level"]):
		SaveManager.data["exp"] -= SaveManager.exp_needed(SaveManager.data["level"])
		SaveManager.data["level"] += 1
		SaveManager.data["hp"] = SaveManager.max_hp()   # новый уровень лечит до максимума
		_log("[color=#c9a961][b]Новый уровень: %d![/b][/color] Здоровье восстановлено." % SaveManager.data["level"])

	SaveManager.pending_msg = "Вы победили: %s. Золото +%d." % [E["name"], gold]
	SaveManager.encounter = {}
	SaveManager.save_game()
	_refresh()


func _defeat() -> void:
	phase = "over"
	var lost := int(SaveManager.data["gold"] * 0.2)   # смерть: -20% золота
	SaveManager.data["gold"] -= lost
	SaveManager.data["potions"] = P["potions"]
	SaveManager.data["hp"] = SaveManager.max_hp()     # возрождение в лагере
	SaveManager.data["armor_dur"] = 0                 # надетое снаряжение ломается (по ТЗ)
	_log("[color=#d46a6a][b]Вы пали в бою...[/b][/color] Потеряно золота: %d." % lost)
	_log("Вы приходите в себя в лагере. Броня сломана: починить её можно на привале. (Потеря 3-7 предметов из инвентаря появится вместе с инвентарём.)")
	SaveManager.pending_msg = "Вы очнулись в лагере после поражения."
	SaveManager.encounter = {}
	SaveManager.save_game()
	_refresh()
