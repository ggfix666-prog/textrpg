extends Node
# Сохранение и загрузка игры в JSON (файл лежит в user://save.json на телефоне).

const SAVE_PATH := "user://save.json"

# Описание 5 классов из ТЗ
const CLASSES := {
	"gladiator": {
		"name": "Гладиатор", "hp": 150,
		"passive": "+20% к броне",
		"desc": "Много HP и брони, тяжёлое оружие."
	},
	"mage": {
		"name": "Маг", "hp": 70,
		"passive": "+20% к урону",
		"desc": "Высокий магический урон, мало HP."
	},
	"vampire": {
		"name": "Вампир", "hp": 100,
		"passive": "+5% вампиризма",
		"desc": "Средний урон, лечение от нанесённого урона."
	},
	"archer": {
		"name": "Лучник", "hp": 90,
		"passive": "+10% к криту",
		"desc": "Высокий шанс крита и ловкость."
	},
	"hunter": {
		"name": "Охотник", "hp": 110,
		"passive": "+15% к шансу дропа",
		"desc": "Баланс и бонус к луту."
	},
}

# Данные текущей игры
var data := {"class_id": "", "level": 1, "gold": 50}
# Класс, выбранный на экране выбора (пока не подтверждён)
var pending_class := ""


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
	data["class_id"] = str(parsed.get("class_id", ""))
	data["level"] = int(parsed.get("level", 1))
	data["gold"] = int(parsed.get("gold", 50))
	return data["class_id"] in CLASSES


# Начать новую игру: стартовые значения из ТЗ (золото 50, уровень 1)
func new_game(class_id: String) -> void:
	data = {"class_id": class_id, "level": 1, "gold": 50}
	save_game()


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	data = {"class_id": "", "level": 1, "gold": 50}
