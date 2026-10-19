extends Node
# База предметов: редкости, шаблоны, самоцветы, зелья и генерация предметов.

const RARITY_NAMES := ["Обычный", "Редкий", "Сверхредкий", "Эпический", "Легендарный", "Боссовый"]
const RARITY_COLORS := ["#d9d2c3", "#6fcf6f", "#5aa7ff", "#c07bff", "#ffc83a", "#ff5a5a"]
const RARITY_CAP := [10, 25, 50, 75, 100, 5]            # предельный уровень предмета
const RARITY_MULT := [1.0, 1.3, 1.7, 2.2, 3.0, 3.5]     # множитель для урона/HP/статов
const RARITY_ARM := [1.0, 1.25, 1.5, 1.8, 2.2, 2.5]     # множитель для брони и процентных бонусов
const RARITY_PRICE := [1.0, 2.5, 6.0, 15.0, 40.0, 80.0]
const DISASSEMBLE := [1, 2, 5, 10, 20, 30]              # очки улучшения за разбор

const SLOTS := ["helmet", "armor", "weapon", "offhand", "gloves", "boots", "belt", "amulet", "ring1", "ring2"]
const SLOT_NAMES := {
	"helmet": "Шлем", "armor": "Броня", "weapon": "Оружие", "offhand": "Щит / 2-е оружие",
	"gloves": "Перчатки", "boots": "Сапоги", "belt": "Пояс", "amulet": "Амулет",
	"ring1": "Кольцо 1", "ring2": "Кольцо 2",
}
const STAT_NAMES := {
	"dmg": "Урон", "arm": "Броня", "hp": "HP", "str": "Сила", "agi": "Ловкость",
	"crit": "Крит", "vamp": "Вампиризм", "gold": "Золото", "drop": "Шанс дропа",
}
const PERCENT_STATS := ["arm", "crit", "vamp", "gold", "drop"]

# Любимое оружие классов (+10% к урону оружия)
const FAV_WEAPONS := {
	"gladiator": ["sword", "axe"], "mage": ["staff"], "vampire": ["dagger"],
	"archer": ["bow"], "hunter": ["bow", "sword"],
}

# Шаблоны предметов. kind: weapon / shield / helmet / armor / gloves / boots / belt / amulet / ring
const TEMPLATES := {
	# --- Оружие ---
	"rusty_sword": {"name": "Ржавый меч", "kind": "weapon", "wt": "sword", "base": {"dmg": 5}},
	"albion": {"name": "Albion", "kind": "weapon", "wt": "sword", "base": {"dmg": 7}},
	"burning_longsword": {"name": "Burning Longsword of Quakes", "kind": "weapon", "wt": "sword", "base": {"dmg": 9}},
	"enlightened_iron": {"name": "Enlightened Iron", "kind": "weapon", "wt": "sword", "base": {"dmg": 8, "crit": 0.02}},
	"elf_slayer": {"name": "Elf Slayer", "kind": "weapon", "wt": "sword", "base": {"dmg": 8, "str": 2}},
	"gotterdammerung": {"name": "Gotterdammerung", "kind": "weapon", "wt": "axe", "base": {"dmg": 11}},
	"braggis_hammer": {"name": "Braggi's Battle Hammer", "kind": "weapon", "wt": "axe", "base": {"dmg": 10, "str": 3}},
	"short_bow": {"name": "Короткий лук", "kind": "weapon", "wt": "bow", "base": {"dmg": 5}},
	"chillstring": {"name": "Chillstring", "kind": "weapon", "wt": "bow", "base": {"dmg": 8, "agi": 2}},
	"hunters_honour": {"name": "Hunter's Honour", "kind": "weapon", "wt": "bow", "base": {"dmg": 9, "drop": 0.05}},
	"wood_staff": {"name": "Деревянный посох", "kind": "weapon", "wt": "staff", "base": {"dmg": 6}},
	"hand_of_god": {"name": "Hand of God", "kind": "weapon", "wt": "staff", "base": {"dmg": 10}},
	"trident_of_honor": {"name": "Trident of Honor", "kind": "weapon", "wt": "staff", "base": {"dmg": 9, "hp": 20}},
	"dagger": {"name": "Кинжал", "kind": "weapon", "wt": "dagger", "base": {"dmg": 4, "crit": 0.02}},
	"binis_dirk": {"name": "Bini's Glowing Dirk", "kind": "weapon", "wt": "dagger", "base": {"dmg": 6, "crit": 0.03}},
	"dirk_pestilence": {"name": "Dirk of Pestilence", "kind": "weapon", "wt": "dagger", "base": {"dmg": 6, "vamp": 0.02}},
	# --- Шлемы ---
	"leather_cap": {"name": "Кожаная шапка", "kind": "helmet", "base": {"arm": 0.02}},
	"light_helm": {"name": "Лёгкий шлем", "kind": "helmet", "base": {"arm": 0.025}},
	"heavy_helm": {"name": "Тяжёлый шлем", "kind": "helmet", "base": {"arm": 0.04}},
	"hood": {"name": "Капюшон", "kind": "helmet", "base": {"arm": 0.015, "crit": 0.01}},
	"bahamut_thought": {"name": "Bahamut's Dark Thought", "kind": "helmet", "base": {"arm": 0.035, "dmg": 1}},
	"hood_madness": {"name": "Hood of Madness", "kind": "helmet", "base": {"arm": 0.015, "crit": 0.03}},
	# --- Броня ---
	"leather_cuirass": {"name": "Кожаный нагрудник", "kind": "armor", "base": {"arm": 0.05}},
	"robe": {"name": "Роба", "kind": "armor", "base": {"arm": 0.02, "hp": 10}},
	"light_armor": {"name": "Лёгкая броня", "kind": "armor", "base": {"arm": 0.04}},
	"heavy_plate": {"name": "Тяжёлая броня", "kind": "armor", "base": {"arm": 0.08}},
	"bahamut_breastplate": {"name": "Bahamut's Breastplate", "kind": "armor", "base": {"arm": 0.08, "hp": 15}},
	"heavenly_revenge": {"name": "Heavenly Armor of Revenge", "kind": "armor", "base": {"arm": 0.065, "vamp": 0.02}},
	# --- Щиты ---
	"light_shield": {"name": "Лёгкий щит", "kind": "shield", "base": {"arm": 0.03}},
	"heavy_shield": {"name": "Тяжёлый щит", "kind": "shield", "base": {"arm": 0.05}},
	"bright_ivory": {"name": "Bright Ivory Shield", "kind": "shield", "base": {"arm": 0.045, "hp": 10}},
	"dragon_shield": {"name": "Dragon Shield", "kind": "shield", "base": {"arm": 0.06}},
	"adornos_defense": {"name": "Adorno's Defense", "kind": "shield", "base": {"arm": 0.055, "crit": 0.01}},
	# --- Перчатки и сапоги ---
	"gauntlets": {"name": "Тяжёлые перчатки", "kind": "gloves", "base": {"arm": 0.02, "str": 1}},
	"light_gloves": {"name": "Лёгкие перчатки", "kind": "gloves", "base": {"arm": 0.01, "agi": 1}},
	"iron_boots": {"name": "Тяжёлые сапоги", "kind": "boots", "base": {"arm": 0.02}},
	"light_boots": {"name": "Лёгкие сапоги", "kind": "boots", "base": {"arm": 0.01, "agi": 1}},
	# --- Пояса ---
	"belt_power": {"name": "Пояс силы", "kind": "belt", "base": {"str": 2}},
	"belt_agility": {"name": "Пояс ловкости", "kind": "belt", "base": {"agi": 2}},
	"belt_mana": {"name": "Пояс маны", "kind": "belt", "base": {"dmg": 1, "hp": 5}},
	"belt_endurance": {"name": "Пояс выносливости", "kind": "belt", "base": {"hp": 20}},
	# --- Амулеты ---
	"amu_protection": {"name": "Амулет защиты", "kind": "amulet", "base": {"arm": 0.02}},
	"amu_intellect": {"name": "Амулет интеллекта", "kind": "amulet", "base": {"dmg": 2}},
	"amu_vampirism": {"name": "Амулет вампиризма", "kind": "amulet", "base": {"vamp": 0.02}},
	"amu_accuracy": {"name": "Амулет точности", "kind": "amulet", "base": {"crit": 0.02}},
	"amu_luck": {"name": "Амулет удачи", "kind": "amulet", "base": {"drop": 0.04}},
	# --- Кольца ---
	"ring_strength": {"name": "Кольцо силы", "kind": "ring", "base": {"str": 2}},
	"ring_magic": {"name": "Кольцо магии", "kind": "ring", "base": {"dmg": 1.5}},
	"ring_blood": {"name": "Кольцо крови", "kind": "ring", "base": {"vamp": 0.015}},
	"ring_crit": {"name": "Кольцо крита", "kind": "ring", "base": {"crit": 0.02}},
	"ring_loot": {"name": "Кольцо добычи", "kind": "ring", "base": {"gold": 0.08}},
	"amethyst_agility": {"name": "Amethyst of Agility", "kind": "ring", "base": {"agi": 3}},
	"black_ring": {"name": "Black Ring of Protection", "kind": "ring", "base": {"arm": 0.02}},
	"dragonslayer_ring": {"name": "Dragonslayer's Ring", "kind": "ring", "base": {"dmg": 2, "str": 1}},
	# --- Красные предметы боссов (уникальные) ---
	"boss_goblin_king": {"name": "Корона Короля гоблинов", "kind": "helmet", "boss": true, "base": {"arm": 0.05},
		"aff": [{"k": "str", "v": 4.0}, {"k": "gold", "v": 0.10}, {"k": "crit", "v": 0.03}]},
	"boss_orc_chief": {"name": "Топор Вожака орков", "kind": "weapon", "wt": "axe", "boss": true, "base": {"dmg": 12},
		"aff": [{"k": "str", "v": 6.0}, {"k": "vamp", "v": 0.03}, {"k": "hp", "v": 30.0}]},
	"boss_lich": {"name": "Посох Лича", "kind": "weapon", "wt": "staff", "boss": true, "base": {"dmg": 13},
		"aff": [{"k": "crit", "v": 0.05}, {"k": "hp", "v": 40.0}, {"k": "dmg", "v": 3.0}]},
	"boss_demon_lord": {"name": "Печать Владыки демонов", "kind": "amulet", "boss": true, "base": {"dmg": 6},
		"aff": [{"k": "vamp", "v": 0.04}, {"k": "crit", "v": 0.04}, {"k": "str", "v": 6.0}]},
	"boss_elder_dragon": {"name": "Чешуя Древнего дракона", "kind": "armor", "boss": true, "base": {"arm": 0.10},
		"aff": [{"k": "hp", "v": 100.0}, {"k": "str", "v": 8.0}, {"k": "drop", "v": 0.10}]},
}

# Самоцветы для сокетов. mods — как они меняют характеристики героя.
const GEMS := {
	"ruby": {"name": "Рубин", "plus": "+10% урона", "minus": "-5% макс. HP", "price": 300,
		"mods": {"dmg_mult": 0.10, "hp_mult": -0.05}},
	"sapphire": {"name": "Сапфир", "plus": "+15% брони", "minus": "-5% скорости атаки", "price": 300,
		"mods": {"arm_mult": 0.15, "speed": -0.05}},
	"emerald": {"name": "Изумруд", "plus": "+5% вампиризма", "minus": "-10% сопротивления магии", "price": 300,
		"mods": {"vamp": 0.05, "mres": -0.10}},
	"amethyst": {"name": "Аметист", "plus": "+10% крита", "minus": "-5% точности", "price": 300,
		"mods": {"crit": 0.10, "acc": -0.05}},
	"topaz": {"name": "Топаз", "plus": "+20% золота", "minus": "-5% базового урона", "price": 300,
		"mods": {"gold": 0.20, "base_mult": -0.05}},
	"skull": {"name": "Череп", "plus": "+15% урона при HP<30%", "minus": "+10% получаемого урона", "price": 300,
		"mods": {"skull": 0.15, "taken": 0.10}},
	"diamond": {"name": "Алмаз", "plus": "+5 ко всем статам", "minus": "нет", "price": 2000,
		"mods": {"all": 5.0}},
	"bloodstone": {"name": "Кровавый камень", "plus": "+2 HP за убийство", "minus": "зелья лечат на 50% слабее", "price": 300,
		"mods": {"kill_heal": 2.0, "heal_mult": -0.5}},
}

# Зелья: тип -> название, значения по трём уровням (малое / среднее / большое), цена малого
const POTION_TYPES := ["heal", "poison", "bomb", "bleed", "crit"]
const POTION_NAMES := {
	"heal": "лечения", "poison": "яда", "bomb": "чистого урона",
	"bleed": "кровопускания", "crit": "критического удара",
}
const POTION_DESC := {
	"heal": "лечит %s макс. HP", "poison": "яд на 3 хода: %s HP врага за ход",
	"bomb": "чистый урон (игнорирует броню): %s от удара", "bleed": "враг теряет %s текущего HP",
	"crit": "гарантированные криты на ближайшие %s ударов",
}
const POTION_VAL := {
	"heal": [0.25, 0.45, 0.70], "poison": [0.04, 0.06, 0.09], "bomb": [0.8, 1.3, 2.0],
	"bleed": [0.10, 0.20, 0.30], "crit": [1, 2, 3],
}
const POTION_PRICE := {"heal": 25, "poison": 35, "bomb": 45, "bleed": 40, "crit": 55}
const TIER_NAMES := ["Малое", "Среднее", "Большое"]


# ---------- Зелья ----------

func potion_key(type: String, tier: int) -> String:
	return "%s_%d" % [type, tier]


func potion_name(key: String) -> String:
	var p: PackedStringArray = key.split("_")
	return "%s зелье %s" % [TIER_NAMES[int(p[1]) - 1], POTION_NAMES[p[0]]]


func potion_desc(key: String) -> String:
	var p: PackedStringArray = key.split("_")
	var val = POTION_VAL[p[0]][int(p[1]) - 1]
	var s: String
	if p[0] == "crit":
		s = str(int(val))
	else:
		s = "%d%%" % int(round(float(val) * 100.0))
	return POTION_DESC[p[0]] % s


func potion_price(key: String) -> int:
	var p: PackedStringArray = key.split("_")
	var mult := [1, 3, 8]
	return int(POTION_PRICE[p[0]]) * int(mult[int(p[1]) - 1])


# ---------- Руны и самоцветы ----------

func rune_name(r: int) -> String:
	return "Руна улучшения (%s)" % RARITY_NAMES[r]


func rune_price(r: int) -> int:
	var prices := [100, 300, 900, 3000, 5000, 20000]
	return int(prices[r])


# ---------- Предметы ----------

func rarity_color(r: int) -> String:
	return RARITY_COLORS[clampi(r, 0, 5)]


func slots_for(it: Dictionary) -> Array:
	var kind: String = TEMPLATES[it["tpl"]]["kind"]
	match kind:
		"weapon":
			return ["weapon", "offhand"]
		"shield":
			return ["offhand"]
		"ring":
			return ["ring1", "ring2"]
		_:
			return [kind]


func item_name(it: Dictionary) -> String:
	return str(TEMPLATES[it["tpl"]]["name"])


func item_cap(it: Dictionary) -> int:
	return int(RARITY_CAP[int(it["rarity"])])


# Короткое название с цветом редкости: «Albion ур.3»
func item_label(it: Dictionary) -> String:
	return "[color=%s][b]%s[/b][/color] ур.%d" % [rarity_color(int(it["rarity"])), item_name(it), int(it["lvl"])]


func plain_label(it: Dictionary) -> String:
	return "%s ур.%d" % [item_name(it), int(it["lvl"])]


func _scale(k: String, v: float, lvl: int, r: int) -> float:
	match k:
		"arm":
			return v * (1.0 + 0.03 * (lvl - 1)) * float(RARITY_ARM[r])
		"crit", "vamp", "gold", "drop":
			return v * (1.0 + 0.04 * (lvl - 1)) * float(RARITY_ARM[r])
		_:
			return v * (1.0 + 0.12 * (lvl - 1)) * float(RARITY_MULT[r])


# Итоговые бонусы предмета (с учётом уровня, редкости и доп. свойств)
func item_stats(it: Dictionary) -> Dictionary:
	var t: Dictionary = TEMPLATES[it["tpl"]]
	var lvl: int = int(it.get("lvl", 1))
	var r: int = int(it.get("rarity", 0))
	var out := {}
	var base: Dictionary = t["base"]
	for k in base:
		out[k] = _scale(str(k), float(base[k]), lvl, r)
	for a in it.get("aff", []):
		var k2: String = a["k"]
		var v: float = float(a["v"]) * (1.0 + 0.06 * (lvl - 1))
		out[k2] = float(out.get(k2, 0.0)) + v
	return out


func stat_text(k: String, v: float) -> String:
	if k in PERCENT_STATS:
		return "%s +%.1f%%" % [STAT_NAMES[k], v * 100.0]
	return "%s +%d" % [STAT_NAMES[k], int(round(v))]


func stats_lines(it: Dictionary) -> String:
	var st: Dictionary = item_stats(it)
	var parts: Array = []
	for k in st:
		parts.append(stat_text(str(k), float(st[k])))
	return ", ".join(parts)


func sockets_text(it: Dictionary) -> String:
	var sk: Array = it.get("sockets", [])
	if sk.is_empty():
		return ""
	var parts: Array = []
	for g in sk:
		if str(g) == "":
			parts.append("[пусто]")
		else:
			parts.append(str(GEMS[g]["name"]))
	return "Сокеты: " + ", ".join(parts)


# Базовая стоимость предмета (продажа торговцу = 25%)
func value(it: Dictionary) -> int:
	return int(round((20 + int(it["lvl"]) * 15) * float(RARITY_PRICE[int(it["rarity"])])))


func sell_price(it: Dictionary) -> int:
	return maxi(1, int(round(value(it) * 0.25)))


func gen_item(tpl: String, rarity: int, lvl: int, rolled: bool = true) -> Dictionary:
	var t: Dictionary = TEMPLATES[tpl]
	var it := {
		"uid": SaveManager.new_uid(), "tpl": tpl, "rarity": rarity,
		"lvl": clampi(lvl, 1, int(RARITY_CAP[rarity])), "dur": 100, "sockets": [], "aff": [],
	}
	if t.get("boss", false):
		it["aff"] = t["aff"].duplicate(true)
		it["sockets"] = ["", ""]
		return it
	if not rolled:
		return it
	var n_sock: int = [0, randi_range(0, 1), randi_range(1, 2), 2, 3, 2][rarity]
	for i in n_sock:
		it["sockets"].append("")
	var n_aff: int = [0, 0, 1, 2, 3, 3][rarity]
	var pool := ["str", "agi", "hp", "crit", "vamp", "gold", "drop", "dmg", "arm"]
	var vals := {"str": 3.0, "agi": 3.0, "hp": 20.0, "crit": 0.03, "vamp": 0.02, "gold": 0.08, "drop": 0.05, "dmg": 2.0, "arm": 0.01}
	pool.shuffle()
	for i in n_aff:
		var k: String = pool[i]
		it["aff"].append({"k": k, "v": float(vals[k]) * float(RARITY_MULT[rarity])})
	return it


func gen_boss_item(boss_id: String) -> Dictionary:
	return gen_item("boss_" + boss_id, 5, 1)


# Шанс редкости зависит от уровня врага и удачи (luck >= 0)
func roll_rarity(enemy_lvl: int, luck: float) -> int:
	var u: float = randf() / (1.0 + luck)
	var lv: float = float(enemy_lvl)
	var pg: float = 0.01 + lv * 0.0005
	var pp: float = 0.04 + lv * 0.001
	var pb: float = 0.10 + lv * 0.002
	var pgr: float = 0.25
	var r := 0
	if u < pg:
		r = 4
	elif u < pg + pp:
		r = 3
	elif u < pg + pp + pb:
		r = 2
	elif u < pg + pp + pb + pgr:
		r = 1
	# Высокие редкости открываются с определённого уровня врага
	if r == 4 and enemy_lvl < 20:
		r = 3
	if r == 3 and enemy_lvl < 8:
		r = 2
	if r == 2 and enemy_lvl < 3:
		r = 1
	return r


func random_template(kinds: Array = []) -> String:
	var ids: Array = []
	for id in TEMPLATES:
		var t: Dictionary = TEMPLATES[id]
		if t.get("boss", false):
			continue
		if kinds.is_empty() or t["kind"] in kinds:
			ids.append(id)
	return ids.pick_random()


# Предмет-дроп для врага данного уровня
func gen_drop(enemy_lvl: int, luck: float, kinds: Array = []) -> Dictionary:
	var r: int = roll_rarity(enemy_lvl, luck)
	var lvl: int = clampi(int(ceil(enemy_lvl * 0.5)) + randi_range(-1, 1), 1, int(RARITY_CAP[r]))
	return gen_item(random_template(kinds), r, lvl)


func roll_gem() -> String:
	if randf() < 0.01:
		return "diamond"
	var ids: Array = []
	for g in GEMS:
		if g != "diamond":
			ids.append(g)
	return ids.pick_random()


# Ассортимент торговца: предметы, руна, самоцвет. Цены +/- 20%.
func gen_trader_stock(player_lvl: int) -> Array:
	var stock: Array = []
	var groups := [["weapon"], ["weapon", "shield"], ["helmet", "armor", "gloves", "boots"],
		["helmet", "armor", "gloves", "boots", "belt"], ["ring", "amulet"], ["ring", "amulet", "belt"]]
	for kinds in groups:
		var it: Dictionary = gen_drop(player_lvl, 0.1, kinds)
		var price: int = int(round(value(it) * randf_range(0.8, 1.2)))
		stock.append({"type": "item", "item": it, "price": maxi(5, price)})
	var rr: int = roll_rarity(player_lvl, 0.0)
	stock.append({"type": "rune", "r": rr, "price": int(round(rune_price(rr) * randf_range(0.8, 1.2)))})
	var g: String = roll_gem()
	stock.append({"type": "gem", "id": g, "price": int(round(int(GEMS[g]["price"]) * randf_range(0.8, 1.2)))})
	if player_lvl >= 70:
		stock.append({"type": "rune", "r": 4, "price": int(round(5000 * randf_range(0.8, 1.2)))})
	return stock
