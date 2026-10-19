extends Node
# Данные мира: локации, враги, боссы, задания.

const LOCATIONS := [
	{"id": "start", "name": "Старт", "min_lvl": 1, "enemies": ["goblin", "rat"], "boss": "goblin_king"},
	{"id": "forest", "name": "Тёмный Лес", "min_lvl": 10, "enemies": ["orc", "wolf"], "boss": "orc_chief"},
	{"id": "ruins", "name": "Руины", "min_lvl": 25, "enemies": ["undead", "skeleton"], "boss": "lich"},
	{"id": "crypt", "name": "Забытый Склеп", "min_lvl": 50, "enemies": ["demon", "troll"], "boss": "demon_lord"},
	{"id": "dragon", "name": "Логово Дракона", "min_lvl": 100, "enemies": ["dragon"], "boss": "elder_dragon"},
]

# hp / dmg — множители от базовых формул, armor — поглощение, acc — меткость,
# alert — внимательность, magic — шанс магической атаки (игнорирует броню), acc_name — винительный падеж
const ENEMIES := {
	"rat": {"name": "Крыса", "acc_name": "Крысу", "hp": 0.6, "dmg": 0.7, "armor": 0.0, "acc": 0.85, "alert": -0.05, "magic": 0.0},
	"goblin": {"name": "Гоблин", "acc_name": "Гоблина", "hp": 1.0, "dmg": 1.0, "armor": 0.10, "acc": 0.90, "alert": 0.0, "magic": 0.0},
	"orc": {"name": "Орк", "acc_name": "Орка", "hp": 1.4, "dmg": 1.25, "armor": 0.15, "acc": 0.88, "alert": 0.05, "magic": 0.0},
	"wolf": {"name": "Волк", "acc_name": "Волка", "hp": 0.9, "dmg": 1.3, "armor": 0.05, "acc": 0.95, "alert": 0.15, "magic": 0.0},
	"undead": {"name": "Нежить", "acc_name": "Нежить", "hp": 1.3, "dmg": 1.1, "armor": 0.10, "acc": 0.85, "alert": -0.05, "magic": 0.2},
	"skeleton": {"name": "Скелет", "acc_name": "Скелета", "hp": 1.0, "dmg": 1.3, "armor": 0.20, "acc": 0.90, "alert": 0.0, "magic": 0.0},
	"demon": {"name": "Демон", "acc_name": "Демона", "hp": 1.6, "dmg": 1.5, "armor": 0.15, "acc": 0.92, "alert": 0.10, "magic": 0.35},
	"troll": {"name": "Тролль", "acc_name": "Тролля", "hp": 2.2, "dmg": 1.3, "armor": 0.25, "acc": 0.80, "alert": -0.05, "magic": 0.0},
	"dragon": {"name": "Дракон", "acc_name": "Дракона", "hp": 3.0, "dmg": 1.8, "armor": 0.30, "acc": 0.95, "alert": 0.15, "magic": 0.3},
	"goblin_king": {"name": "Король гоблинов", "acc_name": "Короля гоблинов", "boss": true, "hp": 2.0, "dmg": 1.25, "armor": 0.20, "acc": 0.92, "alert": 1.0, "magic": 0.0},
	"orc_chief": {"name": "Вожак орков", "acc_name": "Вожака орков", "boss": true, "hp": 2.2, "dmg": 1.3, "armor": 0.25, "acc": 0.92, "alert": 1.0, "magic": 0.0},
	"lich": {"name": "Лич", "acc_name": "Лича", "boss": true, "hp": 2.2, "dmg": 1.35, "armor": 0.20, "acc": 0.95, "alert": 1.0, "magic": 0.5},
	"demon_lord": {"name": "Владыка демонов", "acc_name": "Владыку демонов", "boss": true, "hp": 2.5, "dmg": 1.4, "armor": 0.30, "acc": 0.95, "alert": 1.0, "magic": 0.4},
	"elder_dragon": {"name": "Древний дракон", "acc_name": "Древнего дракона", "boss": true, "hp": 3.0, "dmg": 1.6, "armor": 0.35, "acc": 0.97, "alert": 1.0, "magic": 0.4},
}

# Задания. kind: kill (arg — тип врага), boss, level, equip_rarity, slots, sell, upgrade, pvp_win, gold.
# set=true — прогресс «выставляется» (максимум), иначе накапливается.
const QUESTS := [
	{"id": "s_goblins", "daily": false, "title": "Охота на гоблинов", "desc": "Убей 5 гоблинов", "kind": "kill", "arg": "goblin", "goal": 5, "gold": 100, "exp": 50},
	{"id": "s_magic", "daily": false, "title": "Магическая вещь", "desc": "Надень предмет редкости «Редкий» или выше", "kind": "equip_rarity", "arg": "", "goal": 1, "gold": 150, "exp": 60, "set": true},
	{"id": "s_slots", "daily": false, "title": "В полном облачении", "desc": "Надень предметы в 6 слотов", "kind": "slots", "arg": "", "goal": 6, "gold": 250, "exp": 100, "set": true},
	{"id": "s_sell", "daily": false, "title": "Торговая жилка", "desc": "Продай 3 предмета торговцу", "kind": "sell", "arg": "", "goal": 3, "gold": 120, "exp": 60},
	{"id": "s_upgrade", "daily": false, "title": "Рука кузнеца", "desc": "Улучши предметы 3 раза", "kind": "upgrade", "arg": "", "goal": 3, "gold": 200, "exp": 90},
	{"id": "s_boss", "daily": false, "title": "Первая кровь босса", "desc": "Победи любого босса", "kind": "boss", "arg": "", "goal": 1, "gold": 400, "exp": 200},
	{"id": "s_lvl10", "daily": false, "title": "Закалённый воин", "desc": "Достигни 10 уровня", "kind": "level", "arg": "", "goal": 10, "gold": 500, "exp": 250, "set": true},
	{"id": "d_kill", "daily": true, "title": "Ежедневно: резня", "desc": "Убей 20 существ", "kind": "kill", "arg": "", "goal": 20, "gold": 200, "exp": 120},
	{"id": "d_pvp", "daily": true, "title": "Ежедневно: дуэлянт", "desc": "Выиграй 1 дуэль онлайн", "kind": "pvp_win", "arg": "", "goal": 1, "gold": 300, "exp": 150},
	{"id": "d_gold", "daily": true, "title": "Ежедневно: золотая лихорадка", "desc": "Добудь 1000 золота", "kind": "gold", "arg": "", "goal": 1000, "gold": 300, "exp": 100},
]


func location(id: String) -> Dictionary:
	for l in LOCATIONS:
		if l["id"] == id:
			return l
	return LOCATIONS[0]


# Враг создаётся сразу в формате бойца (см. Combat.fix). Уровень около уровня героя, босс на 2 выше.
func make_enemy(type_id: String, player_lvl: int) -> Dictionary:
	var t: Dictionary = ENEMIES[type_id]
	var is_boss: bool = t.get("boss", false)
	var lvl: int = maxi(1, player_lvl + randi_range(-1, 1))
	var elite: bool = false
	if is_boss:
		lvl = player_lvl + 2
	elif randf() < 0.10:
		elite = true    # элитный враг: крепче и ценнее
	var hp_mult: float = 1.5 if elite else 1.0
	var hp: int = int(round((40 + lvl * 15) * float(t["hp"]) * hp_mult))
	var dmg: float = round((8 + lvl * 3) * float(t["dmg"]) * (1.25 if elite else 1.0))
	var nm: String = str(t["name"])
	var an: String = str(t["acc_name"])
	if elite:
		nm += " [Элита]"
		an += " [Элита]"
	var f := {
		"me": false, "name": nm, "acc_name": an, "id": type_id, "lvl": lvl,
		"hp": hp, "max_hp": hp, "base": dmg, "crit": 0.10 if elite else 0.05,
		"base_arm": t["armor"], "acc": t["acc"], "magic": t["magic"], "alert": t["alert"],
		"boss": is_boss, "elite": elite,
		"enemy_potions": 2 if is_boss else (1 if randf() < 0.4 else 0),
		"first": "",
	}
	return Combat.fix(f)


# Шанс, что героя НЕ заметят
func sneak_chance(agi: int, enemy: Dictionary) -> float:
	return clampf(0.2 + agi * 0.02 - float(enemy["alert"]), 0.05, 0.8)


func flee_chance(agi: int) -> float:
	return clampf(0.3 + agi * 0.03, 0.2, 0.85)
