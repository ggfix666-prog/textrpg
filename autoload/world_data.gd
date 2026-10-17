extends Node
# Данные мира: локации, враги, боссы и расчёты встреч (этап 3).

# Локации из ТЗ. min_lvl — с какого уровня героя локация открыта.
const LOCATIONS := [
	{"id": "start", "name": "Старт", "min_lvl": 1, "enemies": ["goblin", "rat"], "boss": "goblin_king"},
	{"id": "forest", "name": "Тёмный Лес", "min_lvl": 10, "enemies": ["orc", "wolf"], "boss": "orc_chief"},
	{"id": "ruins", "name": "Руины", "min_lvl": 25, "enemies": ["undead", "skeleton"], "boss": "lich"},
	{"id": "crypt", "name": "Забытый Склеп", "min_lvl": 50, "enemies": ["demon", "troll"], "boss": "demon_lord"},
	{"id": "dragon", "name": "Логово Дракона", "min_lvl": 100, "enemies": ["dragon"], "boss": "elder_dragon"},
]

# Шаблоны врагов. hp и dmg — множители от базовых формул, armor — доля поглощения урона,
# acc — меткость, alert — внимательность (чем больше, тем труднее подкрасться).
const ENEMIES := {
	"rat": {"name": "Крыса", "hp": 0.6, "dmg": 0.7, "armor": 0.0, "acc": 0.85, "alert": -0.05},
	"goblin": {"name": "Гоблин", "hp": 1.0, "dmg": 1.0, "armor": 0.10, "acc": 0.90, "alert": 0.0},
	"orc": {"name": "Орк", "hp": 1.4, "dmg": 1.25, "armor": 0.15, "acc": 0.88, "alert": 0.05},
	"wolf": {"name": "Волк", "hp": 0.9, "dmg": 1.3, "armor": 0.05, "acc": 0.95, "alert": 0.15},
	"undead": {"name": "Нежить", "hp": 1.3, "dmg": 1.1, "armor": 0.10, "acc": 0.85, "alert": -0.05},
	"skeleton": {"name": "Скелет", "hp": 1.0, "dmg": 1.3, "armor": 0.20, "acc": 0.90, "alert": 0.0},
	"demon": {"name": "Демон", "hp": 1.6, "dmg": 1.5, "armor": 0.15, "acc": 0.92, "alert": 0.10},
	"troll": {"name": "Тролль", "hp": 2.2, "dmg": 1.3, "armor": 0.25, "acc": 0.80, "alert": -0.05},
	"dragon": {"name": "Дракон", "hp": 3.0, "dmg": 1.8, "armor": 0.30, "acc": 0.95, "alert": 0.15},
	# Боссы (в конце каждой локации)
	"goblin_king": {"name": "Король гоблинов", "boss": true, "hp": 2.0, "dmg": 1.25, "armor": 0.20, "acc": 0.92, "alert": 1.0},
	"orc_chief": {"name": "Вожак орков", "boss": true, "hp": 2.2, "dmg": 1.3, "armor": 0.25, "acc": 0.92, "alert": 1.0},
	"lich": {"name": "Лич", "boss": true, "hp": 2.2, "dmg": 1.35, "armor": 0.20, "acc": 0.95, "alert": 1.0},
	"demon_lord": {"name": "Владыка демонов", "boss": true, "hp": 2.5, "dmg": 1.4, "armor": 0.30, "acc": 0.95, "alert": 1.0},
	"elder_dragon": {"name": "Древний дракон", "boss": true, "hp": 3.0, "dmg": 1.6, "armor": 0.35, "acc": 0.97, "alert": 1.0},
}


func location(id: String) -> Dictionary:
	for l in LOCATIONS:
		if l["id"] == id:
			return l
	return LOCATIONS[0]


# Создаёт врага для встречи. Уровень врага около уровня героя, босс на 2 уровня выше.
func make_enemy(type_id: String, player_lvl: int) -> Dictionary:
	var t: Dictionary = ENEMIES[type_id]
	var is_boss: bool = t.get("boss", false)
	var lvl: int = maxi(1, player_lvl + randi_range(-1, 1))
	if is_boss:
		lvl = player_lvl + 2
	var hp: int = int(round((40 + lvl * 15) * float(t["hp"])))
	var dmg: int = int(round((8 + lvl * 3) * float(t["dmg"])))
	return {
		"type": type_id, "name": t["name"], "lvl": lvl, "boss": is_boss,
		"max_hp": hp, "hp": hp, "dmg": dmg,
		"armor": t["armor"], "acc": t["acc"], "alert": t["alert"],
		"potions": 2 if is_boss else 1,
		"miss_turns": 0, "nopotion_turns": 0, "poison_turns": 0, "wolf_turns": 0,
		"first": "",
	}


# Шанс, что героя НЕ заметят (зависит от Ловкости героя и внимательности врага)
func sneak_chance(agi: int, enemy: Dictionary) -> float:
	return clampf(0.2 + agi * 0.02 - float(enemy["alert"]), 0.05, 0.8)


# Шанс сбежать, если героя заметили
func flee_chance(agi: int) -> float:
	return clampf(0.3 + agi * 0.03, 0.2, 0.85)
