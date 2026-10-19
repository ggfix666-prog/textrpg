extends Node
# Боевой движок. Бойцы — обычные словари (их же шлём по сети в дуэлях).
# Лог боя — массив строк (BBCode), который экран потом выводит «пером».

const CRIT_MULT := 1.75

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


func new_eff() -> Dictionary:
	return {"miss": 0, "nopot": 0, "poison": 0, "poison_pct": 0.0, "wolf": 0, "wolf_dmg": 0.0, "block": false, "critn": 0, "drank": false}


# Заполняет пропущенные поля (после загрузки по сети пустые массивы и словари пропадают)
func fix(f: Dictionary) -> Dictionary:
	var d := {
		"me": false, "name": "?", "acc_name": "?", "id": "", "lvl": 1, "hp": 1, "max_hp": 1,
		"base": 1.0, "weapon": 0.0, "str": 0.0, "crit": 0.05, "vamp": 0.0,
		"base_arm": 0.0, "pieces": [], "arm_mult": 1.0, "dmg_mult": 1.0, "acc": 1.0, "speed": 0.0,
		"mres": 0.0, "taken_mult": 1.0, "skull": 0.0, "heal_mult": 1.0, "kill_heal": 0,
		"potions": {}, "enemy_potions": 0, "ability": {}, "cd": 0, "magic": 0.0,
		"boss": false, "elite": false, "first": "", "alert": 0.0,
	}
	for k in d:
		if not f.has(k):
			f[k] = d[k]
	var e: Dictionary = new_eff()
	if not f.has("eff"):
		f["eff"] = e
	else:
		for k in e:
			if not f["eff"].has(k):
				f["eff"][k] = e[k]
	return f


func subj(f: Dictionary) -> String:
	return "Вы" if f["me"] else str(f["name"])


func obj(f: Dictionary) -> String:
	return "вас" if f["me"] else str(f["acc_name"])


func v(f: Dictionary, you: String, he: String) -> String:
	return you if f["me"] else he


func arm_total(f: Dictionary) -> float:
	var a: float = float(f["base_arm"])
	for p in f["pieces"]:
		if int(p["dur"]) > 0:
			a += float(p["arm"])
	return minf(a * float(f["arm_mult"]), 0.75)


# Сколько действий выпадает в начале хода (1-3), скорость увеличивает шанс на 3
func roll_actions(f: Dictionary) -> int:
	var s: float = float(f["speed"])
	var w1: float = clampf(0.4 - s, 0.1, 0.6)
	var w3: float = clampf(0.2 + s, 0.05, 0.5)
	var r: float = randf()
	if r < w1:
		return 1
	if r < 1.0 - w3:
		return 2
	return 3


# Урон = (База + Оружие) * (1 + Сила/100) * множитель
func raw_damage(att: Dictionary, mult: float) -> float:
	var d: float = (float(att["base"]) + float(att["weapon"])) * (1.0 + float(att["str"]) / 100.0) * mult * float(att["dmg_mult"])
	if float(att["skull"]) > 0.0 and float(att["hp"]) < float(att["max_hp"]) * 0.3:
		d *= 1.0 + float(att["skull"])
	return d


func _wear(def: Dictionary) -> void:
	var live: Array = []
	for p in def["pieces"]:
		if int(p["dur"]) > 0:
			live.append(p)
	if live.is_empty():
		return
	var p2: Dictionary = live.pick_random()
	p2["dur"] = int(p2["dur"]) - 1


func heal(f: Dictionary, n: int, log: Array, potion: bool = false) -> void:
	var amount: int = n
	if potion:
		amount = int(round(n * float(f["heal_mult"])))
	var before: int = int(f["hp"])
	f["hp"] = mini(int(f["max_hp"]), before + maxi(0, amount))
	log.append("[color=#7fb069]%s %s %d HP.[/color]" % [subj(f), v(f, "восстанавливаете", "восстанавливает"), int(f["hp"]) - before])


# Обычная атака. Возвращает нанесённый урон (0 при промахе или блоке).
func attack(att: Dictionary, def: Dictionary, mult: float, log: Array, force_crit: bool = false,
		armor_ignore: float = 0.0, steal: bool = true, verbs: Array = ["бьёте", "бьёт"]) -> int:
	var eff: Dictionary = att["eff"]
	var acc: float = float(att["acc"]) - (0.2 if int(eff["miss"]) > 0 else 0.0)
	if randf() > acc:
		log.append("%s %s!" % [subj(att), v(att, "промахиваетесь", "промахивается")])
		return 0
	if def["eff"]["block"]:
		log.append("[color=#c9a961]Стена щитов[/color] полностью отражает удар!")
		return 0
	var d: float = raw_damage(att, mult) * randf_range(0.92, 1.08)
	var crit: bool = force_crit
	if int(eff["critn"]) > 0:
		crit = true
		eff["critn"] = int(eff["critn"]) - 1
	elif randf() < float(att["crit"]):
		crit = true
	if crit:
		d *= CRIT_MULT
	var tag := ""
	if float(att["magic"]) > 0.0 and randf() < float(att["magic"]):
		d *= 1.0 - clampf(float(def["mres"]), -0.5, 0.8)
		tag = " [color=#c07bff]Магия![/color]"
	else:
		d *= 1.0 - arm_total(def) * (1.0 - armor_ignore)
		_wear(def)
	d *= float(def["taken_mult"])
	var n: int = maxi(1, int(round(d)))
	def["hp"] = maxi(0, int(def["hp"]) - n)
	var ct := " [color=#c9a961]КРИТ![/color]" if crit else ""
	log.append("%s %s %s: [color=#e07a5f][b]%d[/b][/color] урона.%s%s" % [subj(att), v(att, verbs[0], verbs[1]), obj(def), n, ct, tag])
	if steal and float(att["vamp"]) > 0.0:
		heal(att, maxi(1, int(round(n * float(att["vamp"])))), log)
	return n


func use_ability(att: Dictionary, def: Dictionary, log: Array) -> void:
	var ab: Dictionary = att["ability"]
	if ab.is_empty() or int(att["cd"]) > 0:
		return
	att["cd"] = int(ab["cd"])
	log.append("[color=#c9a961]%s применяет «%s»![/color]" % [subj(att), ab["name"]])
	match str(ab["id"]):
		"execute":
			attack(att, def, 1.5, log, false, 0.3)
		"shield_wall":
			att["eff"]["block"] = true
			log.append("Прячется за стеной щитов: следующий удар будет отражён.")
			heal(att, int(round(int(att["max_hp"]) * 0.10)), log)
		"meteor":
			attack(att, def, 1.2, log)
		"antimagic":
			def["eff"]["nopot"] = 4
			log.append("Противник не сможет пить зелья 4 хода.")
		"bloodthirst":
			var d: int = attack(att, def, 1.5, log, false, 0.0, false)
			heal(att, int(round(d * 0.5)), log)
		"bats":
			def["eff"]["miss"] = 3
			log.append("Стая мышей кружит вокруг противника (-20% точности на 3 хода).")
			heal(att, int(round(int(att["max_hp"]) * 0.05)), log)
		"double_shot":
			attack(att, def, 0.8, log)
			if int(def["hp"]) > 0:
				attack(att, def, 0.8, log)
		"snipe":
			attack(att, def, 1.0, log, true)
		"trap":
			attack(att, def, 0.5, log)
			def["eff"]["poison"] = 3
			def["eff"]["poison_pct"] = 0.10
			log.append("Противник отравлен на 3 хода.")
		"pet":
			def["eff"]["wolf"] = 3
			def["eff"]["wolf_dmg"] = raw_damage(att, 0.3)
			log.append("Верный волк прыгает в бой на 3 хода.")


func use_potion(att: Dictionary, def: Dictionary, key: String, log: Array) -> void:
	var cnt: int = int(att["potions"].get(key, 0))
	if cnt <= 0:
		return
	if int(att["eff"]["nopot"]) > 0:
		log.append("[color=#c07bff]Анти-магия мешает пить зелья![/color]")
		return
	att["potions"][key] = cnt - 1
	var p: PackedStringArray = key.split("_")
	var tier: int = int(p[1]) - 1
	var val: float = float(ItemDB.POTION_VAL[p[0]][tier])
	log.append("%s %s [color=#c9a961]%s[/color]." % [subj(att), v(att, "пьёте", "пьёт"), ItemDB.potion_name(key)])
	match p[0]:
		"heal":
			heal(att, int(round(int(att["max_hp"]) * val)), log, true)
		"poison":
			def["eff"]["poison"] = 3
			def["eff"]["poison_pct"] = val
			log.append("Противник отравлен на 3 хода.")
		"bomb":
			var n: int = maxi(1, int(round(raw_damage(att, val))))
			def["hp"] = maxi(0, int(def["hp"]) - n)
			log.append("Взрыв! Чистый урон: [color=#e07a5f][b]%d[/b][/color]." % n)
		"bleed":
			var n2: int = maxi(1, int(round(int(def["hp"]) * val)))
			def["hp"] = maxi(0, int(def["hp"]) - n2)
			log.append("Кровопускание: противник теряет [color=#e07a5f][b]%d[/b][/color] HP." % n2)
		"crit":
			att["eff"]["critn"] = int(val)
			log.append("Ближайшие удары будут критическими (%d)." % int(val))


# Одно действие игрока: "hit", "ability" или "potion:<ключ>"
func do_action(att: Dictionary, def: Dictionary, kind: String, log: Array) -> void:
	if int(def["hp"]) <= 0 or int(att["hp"]) <= 0:
		return
	if kind == "hit":
		attack(att, def, 1.0, log)
	elif kind == "ability":
		use_ability(att, def, log)
	elif kind.begins_with("potion:"):
		use_potion(att, def, kind.substr(7), log)


# Конец хода att: яд и волк бьют def, блок def пропадает, у att идут вниз эффекты и кулдаун
func end_turn(att: Dictionary, def: Dictionary, log: Array) -> void:
	var de: Dictionary = def["eff"]
	if int(de["poison"]) > 0 and int(def["hp"]) > 0:
		var pd: int = maxi(1, int(round(int(def["max_hp"]) * float(de["poison_pct"]))))
		def["hp"] = maxi(0, int(def["hp"]) - pd)
		de["poison"] = int(de["poison"]) - 1
		log.append("[color=#7fb069]Яд наносит %d урона.[/color]" % pd)
	if int(de["wolf"]) > 0 and int(def["hp"]) > 0:
		var wd: int = maxi(1, int(round(float(de["wolf_dmg"]) * (1.0 - arm_total(def)))))
		def["hp"] = maxi(0, int(def["hp"]) - wd)
		de["wolf"] = int(de["wolf"]) - 1
		log.append("Волк кусает: [color=#e07a5f][b]%d[/b][/color] урона." % wd)
	de["block"] = false
	var ae: Dictionary = att["eff"]
	for k in ["miss", "nopot"]:
		if int(ae[k]) > 0:
			ae[k] = int(ae[k]) - 1
	att["cd"] = maxi(0, int(att["cd"]) - 1)


# Ход врага (PvE): иногда пьёт зелье при низком HP, иначе бьёт
func enemy_turn(att: Dictionary, def: Dictionary, log: Array) -> void:
	var e: Dictionary = att["eff"]
	var low: bool = float(att["hp"]) < float(att["max_hp"]) * 0.30
	if low and int(att["enemy_potions"]) > 0 and not e["drank"] and randf() < 0.5:
		if int(e["nopot"]) > 0:
			log.append("%s тянется к зелью, но магия мешает!" % subj(att))
			return
		att["enemy_potions"] = int(att["enemy_potions"]) - 1
		e["drank"] = true
		log.append("%s пьёт зелье." % subj(att))
		heal(att, int(round(int(att["max_hp"]) * 0.25)), log)
		return
	e["drank"] = false
	attack(att, def, 1.0, log)


# ---------- Герой как боец ----------

func hero_fighter() -> Dictionary:
	var S: Dictionary = SaveManager.calc_stats()
	var id: String = SaveManager.data["class_id"]
	var c: Dictionary = SaveManager.CLASSES[id]
	var dm: float = float(S["dmg_mult"])
	if int(SaveManager.data["altar"]) > 0:
		dm *= 1.15    # благословение алтаря
	var f := {
		"me": true, "name": c["name"], "acc_name": c["name"], "id": id, "lvl": SaveManager.data["level"],
		"max_hp": S["max_hp"], "hp": clampi(int(SaveManager.data["hp"]), 1, int(S["max_hp"])),
		"base": S["base"], "weapon": S["weapon"], "str": S["str"], "crit": S["crit"], "vamp": S["vamp"],
		"base_arm": S["base_arm"], "pieces": S["pieces"].duplicate(true), "arm_mult": S["arm_mult"],
		"dmg_mult": dm, "acc": S["acc"], "speed": S["speed"], "mres": S["mres"], "taken_mult": S["taken"],
		"skull": S["skull"], "heal_mult": S["heal_mult"], "kill_heal": S["kill_heal"],
		"potions": SaveManager.data["potions"].duplicate(true),
	}
	return fix(f)


# Переносит итог боя героя в сохранение (HP, зелья, прочность брони)
func commit_hero(f: Dictionary) -> void:
	SaveManager.data["hp"] = int(f["hp"])
	SaveManager.data["potions"] = f["potions"].duplicate(true)
	for p in f["pieces"]:
		var it = SaveManager.data["equipped"].get(p["slot"])
		if it != null:
			it["dur"] = int(p["dur"])
	for k in SaveManager.data["potions"].keys():
		if int(SaveManager.data["potions"][k]) <= 0:
			SaveManager.data["potions"].erase(k)


# Снимок героя для онлайн-дуэли (боец + ник + золото + рюкзак для добычи)
func snapshot(nick: String, ability: Dictionary) -> Dictionary:
	var f: Dictionary = hero_fighter()
	f["me"] = false
	f["name"] = nick
	f["acc_name"] = nick
	f["ability"] = ability.duplicate(true)
	f["cls"] = SaveManager.CLASSES[SaveManager.data["class_id"]]["name"]
	f["gold"] = SaveManager.data["gold"]
	f["inv"] = SaveManager.data["inventory"].duplicate(true)
	f["hp"] = f["max_hp"]    # в дуэли оба бойца выходят с полным HP
	return f


func from_snapshot(s: Dictionary) -> Dictionary:
	var f: Dictionary = SaveManager.norm(s)
	f["me"] = false
	return fix(f)
