extends Control

const GAME_SCENE := "res://scenes/Game.tscn"
const PIXEL_FONT := preload("res://fonts/upheavtt.ttf")

const CHARACTER_NAMES := ["Akanee", "Kaito", "Jade", "Panya", "Wayoo", "Jekkie", "Roxy", "Cherri"]
const AVATAR_PATHS := [
	"res://avatars/1.jpg",
	"res://avatars/2.jpg",
	"res://avatars/3.jpg",
	"res://avatars/4.jpg",
	"res://avatars/5.jpg",
	"res://avatars/6.jpg",
	"res://avatars/7.jpg",
	"res://avatars/8.jpg",
]

var _progress := 0.0
var _bar: ProgressBar
var _status: Label


func _ready() -> void:
	_build_loading()


func _process(delta: float) -> void:
	_progress = minf(1.0, _progress + delta * 0.55)
	_bar.value = _progress
	if _progress >= 1.0:
		_status.text = "READY!"
		set_process(false)
		await get_tree().create_timer(0.35).timeout
		get_tree().change_scene_to_file(GAME_SCENE)


func _build_loading() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#101416")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var root := VBoxContainer.new()
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 28)
	root.custom_minimum_size = Vector2(640, 440)
	center.add_child(root)

	var title := _label("LOADING...", 46, Color.WHITE, Color("#202020"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var versus := HBoxContainer.new()
	versus.alignment = BoxContainer.ALIGNMENT_CENTER
	versus.add_theme_constant_override("separation", 72)
	root.add_child(versus)

	var p1 := int(get_tree().get_meta("player1_char", 0))
	var p2 := int(get_tree().get_meta("player2_char", 1))
	var has_assist := str(get_tree().get_meta("match_type", "assistant")) == "assistant"
	versus.add_child(_portrait_block(p1, Color("#ff4d5b"), CHARACTER_NAMES[p1].to_upper(), has_assist))
	versus.add_child(_label("VS", 44, Color("#ffd200"), Color("#352000")))
	versus.add_child(_portrait_block(p2, Color("#4f93ff"), "AI " + CHARACTER_NAMES[p2].to_upper(), has_assist))

	var shell := PanelContainer.new()
	shell.custom_minimum_size = Vector2(500, 24)
	var shell_style := StyleBoxFlat.new()
	shell_style.bg_color = Color("#242424")
	shell_style.border_color = Color("#c46a24")
	shell_style.set_border_width_all(2)
	shell_style.set_corner_radius_all(10)
	shell.add_theme_stylebox_override("panel", shell_style)
	root.add_child(shell)

	_bar = ProgressBar.new()
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.value = 0.0
	_bar.show_percentage = false
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color("#ffb21d")
	bar_fill.set_corner_radius_all(8)
	_bar.add_theme_stylebox_override("background", bar_bg)
	_bar.add_theme_stylebox_override("fill", bar_fill)
	shell.add_child(_bar)

	_status = _label("PREPARING MATCH...", 20, Color("#c8c8c8"), Color("#202020"))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_status)


func _portrait_block(char_id: int, color: Color, name: String, has_assist: bool) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)

	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(126, 126)
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = color
	style.set_border_width_all(5)
	style.set_corner_radius_all(14)
	frame.add_theme_stylebox_override("panel", style)
	box.add_child(frame)

	var avatar := TextureRect.new()
	avatar.texture = load(AVATAR_PATHS[char_id])
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	avatar.custom_minimum_size = Vector2(116, 116)
	frame.add_child(avatar)

	var label := _label(name, 24, color, Color("#202020"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)

	if has_assist:
		var assist := _label("+ NPC ASSISTANT", 14, Color("#cfcfcf"), Color("#202020"))
		assist.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(assist)
	return box


func _label(text: String, size: int, color: Color, outline: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", PIXEL_FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", outline)
	label.add_theme_constant_override("outline_size", 5)
	return label
