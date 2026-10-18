extends Control
# ЭТАП 3: исследование мира.
# «Идти дальше» -> случайное событие: враг / пустой путь с добычей / торговец / кузнец / ведьма.
# Локации открываются по уровню героя. После 10-15 побед в локации появляется БОСС.

const REST_PER_LEVEL := 3     # цена привала: золото за каждый уровень героя
const POTION_HEAL := 0.35     # зелье лечит 35% максимального HP

var stats_label: RichTextLabel
var log_label: RichTextLabel
var bottom: VBoxContainer

var mode := "idle"            # idle / encounter / locations / rest
var enemy: Dictionary = {}    # враг, с которым столкнулись
var noticed := false          # заметил ли враг героя


func _ready() -> void:
	randomize()
	var id: String = SaveManager.data["class_id"]
	if not (id in SaveManager.CLASSES):
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
		return
	# Если локация закрыта по уровню (например, старое сохранение) — возвращаем на старт
	var cur := WorldData.location(SaveManager.data["location"])
	if int(cur["min_lvl"]) > int(SaveManager.data["level"]):
		SaveManager.data["location"] = "start"
	_build_ui()
	var loc := WorldData.location(SaveManager.data["location"])
	_log("Вы стоите на тропе. Локация: [color=#c9a961]%s[/color]." % loc["name"])
	if SaveManager.pending_msg != "":
		_log(SaveManager.pending_msg)
		SaveManager.pending_msg = ""
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


func _row() -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 10)
	bottom.add_child(r)
	return r


func _refresh() -> void:
	var c: Dictionary = SaveManager.CLASSES[SaveManager.data["class_id"]]
	var lvl: int = SaveManager.data["level"]
	var loc := WorldData.location(SaveManager.data["location"])
	var t := "[b][color=#c9a961]%s[/color][/b] ур.%d  (опыт %d/%d)\n" % [
		c["name"], lvl, SaveManager.data["exp"], SaveManager.exp_needed(lvl)]
	t += "HP [color=#d46a6a]%d/%d[/color]  Броня %d%% (проч. %d)\n" % [
		SaveManager.data["hp"], SaveManager.max_hp(),
		int(round(SaveManager.armor_value() * 100)), SaveManager.data["armor_dur"]]
	t += "Золото [color=#c9a961]%d[/color]  Зелья %d\n" % [SaveManager.data["gold"], SaveManager.data["potions"]]
	t += "Локация: %s  (побед здесь: %d)" % [loc["name"], SaveManager.kills(loc["id"])]
	stats_label.text = t

	_clear_bottom()
	match mode:
		"idle":
			_build_idle()
		"encounter":
			_build_encounter()
		"locations":
			_build_locations()
		"rest":
			_build_rest()


func _build_idle() -> void:
	var go := Style.make_button("Идти дальше", Style.MOSS)
	go.pressed.connect(_on_go)
	bottom.add_child(go)

	var row := _row()
	var potions: int = SaveManager.data["potions"]
	var pot := _small_button("Зелье (%d)" % potions, Style.MOSS)
	pot.disabled = potions <= 0 or int(SaveManager.data["hp"]) >= SaveManager.max_hp()
	pot.pressed.connect(_on_potion)
	row.add_child(pot)
	var rest := _small_button("Привал")
	rest.pressed.connect(func():
		mode = "rest"
		_refresh())
	row.add_child(rest)

	var row2 := _row()
	var loc := _small_button("Локация")
	loc.pressed.connect(func():
		mode = "locations"
		_refresh())
	row2.add_child(loc)
	var prof := _small_button("Профиль")
	prof.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Profile.tscn"))
	row2.add_child(prof)


func _build_encounter() -> void:
	var is_boss: bool = enemy.get("boss", false)
	var agi: int = SaveManager.CLASSES[SaveManager.data["class_id"]]["agi"]
	if is_boss:
		var fight := Style.make_button("К бою!", Style.BLOOD)
		fight.pressed.connect(_start_battle.bind(""))
		bottom.add_child(fight)
	elif noticed:
		var fight2 := Style.make_button("Сражаться", Style.BLOOD)
		fight2.pressed.connect(_start_battle.bind(""))
		bottom.add_child(fight2)
		var chance := int(round(WorldData.flee_chance(agi) * 100))
		var flee := Style.make_button("Сбежать (шанс %d%%)" % chance)
		flee.pressed.connect(_on_flee)
		bottom.add_child(flee)
	else:
		var sneak := Style.make_button("Напасть из засады (крит)", Style.BLOOD)
		sneak.pressed.connect(_start_battle.bind("player"))
		bottom.add_child(sneak)
		var flee2 := Style.make_button("Сбежать (100%)")
		flee2.pressed.connect(_on_flee_free)
		bottom.add_child(flee2)


func _build_locations() -> void:
	var lvl: int = SaveManager.data["level"]
	for l in WorldData.LOCATIONS:
		var ok: bool = lvl >= int(l["min_lvl"])
		var txt: String = str(l["name"])
		if l["id"] == SaveManager.data["location"]:
			txt = "> " + txt
		if not ok:
			txt += "  (закрыто: с %d ур.)" % l["min_lvl"]
		var b := _small_button(txt, Style.BLOOD if ok else Color("#2f2417"))
		b.disabled = not ok
		b.pressed.connect(_on_pick_location.bind(l["id"]))
		bottom.add_child(b)
	var back := _small_button("Назад")
	back.pressed.connect(func():
		mode = "idle"
		_refresh())
	bottom.add_child(back)


func _build_rest() -> void:
	var rest_cost := _rest_cost()
	var rest := _small_button("Отдохнуть: HP до максимума (%d зол.)" % rest_cost, Style.MOSS)
	rest.disabled = int(SaveManager.data["hp"]) >= SaveManager.max_hp()
	rest.pressed.connect(_on_rest)
	bottom.add_child(rest)

	var rep_cost := _repair_cost()
	var rep := _small_button("Починить броню (%d зол.)" % rep_cost)
	rep.disabled = rep_cost <= 0
	rep.pressed.connect(_on_repair)
	bottom.add_child(rep)

	var back := _small_button("Назад")
	back.pressed.connect(func():
		mode = "idle"
		_refresh())
	bottom.add_child(back)


# ---------- Привал ----------

func _rest_cost() -> int:
	return int(SaveManager.data["level"]) * REST_PER_LEVEL


# Ремонт брони по ТЗ: (макс. прочность - текущая) * 0.5 золота
func _repair_cost() -> int:
	return int(round((100 - int(SaveManager.data["armor_dur"])) * 0.5))


func _on_rest() -> void:
	var cost := _rest_cost()
	if int(SaveManager.data["gold"]) < cost:
		_log("[color=#d46a6a]Не хватает золота на привал.[/color]")
		return
	SaveManager.data["gold"] -= cost
	SaveManager.data["hp"] = SaveManager.max_hp()
	SaveManager.save_game()
	_log("Вы отдыхаете у костра и восстанавливаете силы (-%d золота)." % cost)
	_refresh()


func _on_repair() -> void:
	var cost := _repair_cost()
	if int(SaveManager.data["gold"]) < cost:
		_log("[color=#d46a6a]Не хватает золота на ремонт.[/color]")
		return
	SaveManager.data["gold"] -= cost
	SaveManager.data["armor_dur"] = 100
	SaveManager.save_game()
	_log("Броня починена (-%d золота)." % cost)
	_refresh()


func _on_potion() -> void:
	if int(SaveManager.data["potions"]) <= 0:
		return
	var before: int = SaveManager.data["hp"]
	var heal := int(round(SaveManager.max_hp() * POTION_HEAL))
	SaveManager.data["potions"] -= 1
	SaveManager.data["hp"] = mini(SaveManager.max_hp(), before + heal)
	SaveManager.save_game()
	_log("[color=#7fb069]Вы пьёте зелье: +%d HP.[/color]" % (int(SaveManager.data["hp"]) - before))
	_refresh()


func _on_pick_location(id: String) -> void:
	SaveManager.data["location"] = id
	SaveManager.save_game()
	var loc := WorldData.location(id)
	_log("Вы отправляетесь в локацию: [color=#c9a961]%s[/color]." % loc["name"])
	mode = "idle"
	_refresh()


# ---------- Идти дальше: события ----------

func _on_go() -> void:
	var lvl: int = SaveManager.data["level"]
	var loc_id: String = SaveManager.data["location"]
	var loc := WorldData.location(loc_id)

	# Пора на босса?
	if SaveManager.kills(loc_id) >= SaveManager.boss_threshold(loc_id):
		enemy = WorldData.make_enemy(loc["boss"], lvl)
		noticed = true
		_log("[color=#7a1f1f][b]Земля дрожит...[/b][/color] Путь преграждает БОСС: [color=#c9a961]%s[/color] (ур. %d)!" % [enemy["name"], enemy["lvl"]])
		mode = "encounter"
		_refresh()
		return

	# Кубик событий из ТЗ: враг 60%, пустой путь 20%, торговец 10%, кузнец 5%, ведьма 5%
	var r := randf()
	if r < 0.60:
		_event_enemy(loc, lvl)
	elif r < 0.80:
		_event_loot(lvl)
	elif r < 0.90:
		_log("Вы встречаете [color=#c9a961]бродячего торговца[/color]. Он разводит руками: товар ещё не привезли (лавка откроется позже).")
	elif r < 0.95:
		_log("Вы замечаете дымок [color=#c9a961]кузницы[/color], но кузнеца нет на месте (кузница откроется позже).")
	else:
		_log("Из тумана выходит [color=#c9a961]ведьма[/color], хихикает и растворяется в воздухе (зелья появятся позже).")
	_refresh()


func _event_enemy(loc: Dictionary, lvl: int) -> void:
	var type_id: String = loc["enemies"].pick_random()
	enemy = WorldData.make_enemy(type_id, lvl)
	var agi: int = SaveManager.CLASSES[SaveManager.data["class_id"]]["agi"]
	noticed = randf() > WorldData.sneak_chance(agi, enemy)
	var head := "Впереди [color=#c9a961]%s[/color] (ур. %d). " % [enemy["name"], enemy["lvl"]]
	if noticed:
		_log(head + "[color=#d46a6a]Вас заметили![/color]")
	else:
		_log(head + "[color=#7fb069]Вас не заметили.[/color]")
	mode = "encounter"


# Пустой путь + добыча (предметы появятся на следующем этапе: пока золото и зелья)
func _event_loot(lvl: int) -> void:
	var gold := randi_range(5, 15) + lvl * 2
	SaveManager.data["gold"] += gold
	var txt := "Путь пуст. В пыли блестит добыча: [color=#c9a961]+%d золота[/color]." % gold
	var chance := 0.15
	if SaveManager.data["class_id"] == "hunter":
		chance *= 1.15    # пассивка Охотника: +15% к шансу дропа
	if randf() < chance:
		SaveManager.data["potions"] += 1
		txt += " И целое [color=#7fb069]зелье[/color]!"
	_log(txt)
	SaveManager.save_game()


func _on_flee_free() -> void:
	_log("Вы тихо обходите врага стороной.")
	mode = "idle"
	_refresh()


func _on_flee() -> void:
	var agi: int = SaveManager.CLASSES[SaveManager.data["class_id"]]["agi"]
	if randf() < WorldData.flee_chance(agi):
		_log("[color=#7fb069]Вам удалось ускользнуть.[/color]")
		mode = "idle"
		_refresh()
	else:
		_log("[color=#d46a6a]Побег не удался![/color] Враг бьёт первым.")
		_start_battle("enemy")


# Переход в бой. first: "" — обычный бой, "player" — вы нападаете (крит), "enemy" — враг бьёт первым
func _start_battle(first: String) -> void:
	enemy["first"] = first
	SaveManager.encounter = enemy
	SaveManager.save_game()
	get_tree().change_scene_to_file("res://scenes/Battle.tscn")
