extends Node
# Общий стиль "средневекового фолианта": цвета и помощники для создания интерфейса из кода.

const BG := Color("#2b1d0e")      # тёмный пергамент
const TEXT := Color("#e8d9b8")    # слоновая кость
const GOLD := Color("#c9a961")    # золото
const BLOOD := Color("#7a1f1f")   # кровь
const MOSS := Color("#4a6a3a")    # мох


# Заливает весь экран цветом фона
func add_bg(parent: Control) -> void:
	var r := ColorRect.new()
	r.color = BG
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(r)


# Создаёт колонку с отступами по краям и возвращает её (в неё кладём элементы)
func make_column(parent: Control) -> VBoxContainer:
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 40)
	parent.add_child(m)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 20)
	m.add_child(v)
	return v


# Заголовок золотого цвета
func make_title(text: String, size: int = 56) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", GOLD)
	return l


# Кнопка в виде металлической пластины
func make_button(text: String, color: Color = Color("#4a3520")) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 90)
	b.add_theme_font_size_override("font_size", 32)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_disabled_color", Color("#7a6c55"))
	b.add_theme_stylebox_override("normal", _box(color))
	b.add_theme_stylebox_override("hover", _box(color.lightened(0.15)))
	b.add_theme_stylebox_override("pressed", _box(color.darkened(0.25)))
	b.add_theme_stylebox_override("disabled", _box(Color("#2f2417")))
	return b


# Текстовый блок с поддержкой BBCode (цвета, жирный и т.п.)
func make_text(bbcode: String, size: int = 30) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.text = bbcode
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_color_override("default_color", TEXT)
	return r


func _box(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = GOLD
	s.set_border_width_all(3)
	s.set_corner_radius_all(8)
	s.content_margin_left = 16
	s.content_margin_right = 16
	return s
