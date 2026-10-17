extends Node
# Сохранение и загрузка игры в JSON (файл лежит в user://save.json на телефоне).

const SAVE_PATH := "user://save.json"

# Описание 5 классов из ТЗ + боевые статы (Этап 2)
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
var data := {"class_id": "", "level": 1, "gold": 50, "exp": 0, "potions": 0}
# Класс, выбранный на экране выбора (пока не подтверждён)
var pending_class := ""


# Сколько опыта нужно для следующего уровня
func exp_needed(level: int) -> int:
	return level * 40


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
	var id := str(parsed.get("class_id", ""))
	if not (id in CLASSES):
		return false
	data["class_id"] = id
	data["level"] = int(parsed.get("level", 1))
	data["gold"] = int(parsed.get("gold", 50))
	data["exp"] = int(parsed.get("exp", 0))
	data["potions"] = int(parsed.get("potions", CLASSES[id]["potions"]))
	return true


# Начать новую игру: стартовые значения из ТЗ (золото 50, уровень 1)
func new_game(class_id: String) -> void:
	data = {
		"class_id": class_id, "level": 1, "gold": 50, "exp": 0,
		"potions": CLASSES[class_id]["potions"]
	}
	save_game()


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	data = {"class_id": "", "level": 1, "gold": 50, "exp": 0, "potions": 0}
