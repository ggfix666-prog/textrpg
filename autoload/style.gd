extends Node
# Стиль «средневекового фолианта»: цвета, глобальная тема (крупный жирный шрифт) и помощники интерфейса.

const BG := Color("#2b1d0e")      # тёмный пергамент
const TEXT := Color("#f3e7c9")    # слоновая кость
const GOLD := Color("#c9a961")    # золото
const BLOOD := Color("#7a1f1f")   # кровь
const MOSS := Color("#4a6a3a")    # мох
const PLATE := Color("#4a3520")   # металлическая пластина
const DARK := Color("#2f2417")

var font_bold: FontVariation


func _ready() -> void:
	font_bold = FontVariation.new()
	font_bold.base_font = ThemeDB.fallback_font
	font_bold.variation_embolden = 0.6
	var th := Theme.new()
	th.default_font = font_bold
	th.default_font_size = 32
	get_tree().root.theme = th


func add_bg(parent: Control) -> void:
	var r := ColorRect.new()
	r.color = BG
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(r)


# Экран: фон + отступы + колонка. Возвращает колонку (VBox), в неё кладём всё остальное.
func screen(parent: Control, title: String, fs: int = 46) -> VBoxContainer:
	add_bg(parent)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", 22)
	m.add_theme_constant_override("margin_right", 22)
	m.add_theme_constant_override("margin_top", 56)
	m.add_theme_constant_override("margin_bottom", 26)
	parent.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	m.add_child(v)
	if title != "":
		v.add_child(make_title(title, fs))
	return v


# Прокручиваемый список. Возвращает колонку внутри прокрутки.
func scroll_list(parent: Control) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.scroll_deadzone = 25
	parent.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	sc.add_child(v)
	return v


# Прокрутка фиксированной высоты (для длинных меню внутри нижней панели)
func fixed_scroll(parent: Control, h: int) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, h)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.scroll_deadzone = 25
	parent.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	sc.add_child(v)
	return v


func row(parent: Control) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 10)
	parent.add_child(r)
	return r


func clear(box: Control) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


func make_title(text: String, size: int = 52) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", GOLD)
	return l


# Кнопка-пластина. Высокая и широкая, чтобы удобно попадать пальцем.
func btn(text: String, color: Color = PLATE, h: int = 100, fs: int = 32) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, h)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", fs)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", TEXT)
	b.add_theme_color_override("font_pressed_color", TEXT)
	b.add_theme_color_override("font_disabled_color", Color("#8a7b62"))
	b.add_theme_stylebox_override("normal", _box(color))
	b.add_theme_stylebox_override("hover", _box(color.lightened(0.15)))
	b.add_theme_stylebox_override("pressed", _box(color.darkened(0.25)))
	b.add_theme_stylebox_override("disabled", _box(DARK))
	return b


func make_button(text: String, color: Color = PLATE) -> Button:
	return btn(text, color)


# Текстовый блок с BBCode
func lbl(bbcode: String, size: int = 30) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.text = bbcode
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_color_override("default_color", TEXT)
	return r


func make_text(bbcode: String, size: int = 30) -> RichTextLabel:
	return lbl(bbcode, size)


# Лог «пером по пергаменту»: текст появляется постепенно (скрипт log_view.gd)
func make_log():
	var r := RichTextLabel.new()
	r.set_script(load("res://scripts/log_view.gd"))
	r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	r.add_theme_font_size_override("normal_font_size", 34)
	r.add_theme_font_size_override("bold_font_size", 34)
	r.add_theme_color_override("default_color", TEXT)
	return r


func _box(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = GOLD
	s.set_border_width_all(3)
	s.set_corner_radius_all(10)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s
