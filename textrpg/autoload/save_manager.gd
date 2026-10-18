extends Node
# Сохранение и загрузка игры в JSON (файл лежит в user://save.json на телефоне).

const SAVE_PATH := "user://save.json"

# Описание 5 классов из ТЗ + боевые статы
# armor — доля поглощаемого урона (0.25 = 25%), potions — стартовые зелья
const CLASSES := {
	"gladiator": {
		"name": "Гладиатор", "hp": 150,
		"passive": "+20% к броне",
		"desc": "Много HP и брони, тяжёлое оружие.",
		"base_dmg": 8, "weapon": 6, "str": 15, "agi": 5, "armor": 0.25, "potions": 2
	},
	"mage": {
		"name": "Маг", "hp": 70,
		"passive": "+20% к урону",
		"desc": "Высокий магический урон, мало HP.",
		"base_dmg": 10, "weapon": 8, "str": 5, "agi": 6, "armor": 0.05, "potions": 3
	},
	"vampire": {
		"name": "Вампир", "hp": 100,
		"passive": "+5% вампиризма",
		"desc": "Средний урон, лечение от нанесённого урона.",
		"base_dmg": 8, "weapon": 5, "str": 8, "agi": 10, "armor": 0.10, "potions": 1
	},
	"archer": {
		"name": "Лучник", "hp": 90,
		"passive": "+10% к криту",
		"desc": "Высокий шанс крита и ловкость.",
		"base_dmg": 8, "weapon": 7, "str": 6, "agi": 15, "armor": 0.10, "potions": 2
	},
	"hunter": {
		"name": "Охотник", "hp": 110,
		"passive": "+15% к шансу дропа",
		"desc": "Баланс и бонус к луту.",
		"base_dmg": 8, "weapon": 6, "str": 8, "agi": 9, "armor": 0.15, "potions": 0
	},
}

# Данные текущей игры
var data := {}
# Класс, выбранный на экране выбора (пока не подтверждён)
var pending_class := ""
# Враг для следующего боя (его создаёт экран исследования)
var encounter := {}
# Сообщение для экрана исследования (итог последнего боя)
var pending_msg := ""


func _init() -> void:
	data = _empty_data()


# Пустые данные игры. Новые поля (этап 3): hp, armor_dur, location, kills, boss_at, trophies
func _empty_data() -> Dictionary:
	return {
		"class_id": "", "level": 1, "gold": 50, "exp": 0, "potions": 0,
		"hp": 1, "armor_dur": 100,
		"location": "start",
		"kills": {},      # победы над врагами в каждой локации (до босса)
		"boss_at": {},    # после скольких побед появится босс (10-15)
		"trophies": [],   # побеждённые боссы (красные предметы появятся на этапе предметов)
	}


# Сколько опыта нужно для следующего уровня
func exp_needed(level: int) -> int:
	return level * 40


func max_hp_for(id: String, lvl: int) -> int:
	if not (id in CLASSES):
		return 1
	return int(CLASSES[id]["hp"]) + (lvl - 1) * 12


func max_hp() -> int:
	return max_hp_for(str(data["class_id"]), int(data["level"]))


# Броня героя (доля поглощения) с учётом пассивки Гладиатора
func armor_value() -> float:
	var id: String = data["class_id"]
	if not (id in CLASSES):
		return 0.0
	var a: float = CLASSES[id]["armor"]
	if id == "gladiator":
		a *= 1.2
	return a


func kills(loc_id: String) -> int:
	return int(data["kills"].get(loc_id, 0))


# Порог побед до босса для локации (выбирается случайно 10-15 один раз)
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


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Не удалось открыть файл сохранения")
		return
	f.store_string(JSON.stringify(data))
	f.close()


func _int_dict(v) -> Dictionary:
	var out := {}
	if typeof(v) == TYPE_DICTIONARY:
		for k in v:
			out[str(k)] = int(v[k])
	return out


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
	var id := str(parsed.get("class_id", ""))
	if not (id in CLASSES):
		return false
	var d := _empty_data()
	d["class_id"] = id
	d["level"] = int(parsed.get("level", 1))
	d["gold"] = int(parsed.get("gold", 50))
	d["exp"] = int(parsed.get("exp", 0))
	d["potions"] = int(parsed.get("potions", CLASSES[id]["potions"]))
	var mhp: int = max_hp_for(id, d["level"])
	d["hp"] = clampi(int(parsed.get("hp", mhp)), 1, mhp)
	d["armor_dur"] = int(parsed.get("armor_dur", 100))
	var loc := str(parsed.get("location", "start"))
	if WorldData.location(loc)["id"] != loc:
		loc = "start"
	d["location"] = loc
	d["kills"] = _int_dict(parsed.get("kills", {}))
	d["boss_at"] = _int_dict(parsed.get("boss_at", {}))
	var tr = parsed.get("trophies", [])
	d["trophies"] = tr if typeof(tr) == TYPE_ARRAY else []
	data = d
	return true


# Начать новую игру: стартовые значения из ТЗ (золото 50, уровень 1)
func new_game(class_id: String) -> void:
	var d := _empty_data()
	d["class_id"] = class_id
	d["potions"] = CLASSES[class_id]["potions"]
	d["hp"] = max_hp_for(class_id, 1)
	data = d
	encounter = {}
	pending_msg = ""
	save_game()


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	data = _empty_data()
	encounter = {}
	pending_msg = ""
