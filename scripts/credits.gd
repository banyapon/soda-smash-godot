extends Control

const MAIN_MENU_SCENE := "res://scenes/MainMenu.tscn"
const PIXEL_FONT := preload("res://fonts/upheavtt.ttf")
const SELECT_SOUND := preload("res://sounds/select.mp3")

var _select_player: AudioStreamPlayer


func _ready() -> void:
	_build_screen()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") or event is InputEventJoypadButton:
		_go_back()


func _build_screen() -> void:
	_select_player = AudioStreamPlayer.new()
	_select_player.stream = SELECT_SOUND
	add_child(_select_player)

	var bg := ColorRect.new()
	bg.color = Color("#d6deea")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_left = 24.0
	center.offset_top = 20.0
	center.offset_right = -24.0
	center.offset_bottom = -20.0
	add_child(center)

	var shell := PanelContainer.new()
	shell.custom_minimum_size = Vector2(900, 640)
	shell.add_theme_stylebox_override("panel", _panel_style(Color("#efedf1"), Color("#c7ccd6"), 34.0, 2))
	center.add_child(shell)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	shell.add_child(root)

	var title := _pixel_label("CREDIT & LICENSES", 40, Color("#ffd84a"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	root.add_child(_section_panel("GAME DEVELOPER & DESIGN", [
		"BANYAPON POOLSAWAS (DAYDEV)",
		"BHUMINTRA CHANTANASEVI (YOMA)",
		"## ANIMATION RIGGING",
		"YANAWUT KHROPHALP (NYANIMATION)",
		"## TESTING & BALANCE",
		"TANANUT UTHASUNTORN (ROBIKY)",
		"NUTTANANT SAPKASETRIN (SSPR)",
	]))
	root.add_child(_section_panel("SOME CHARACTER DESIGN", [
		"CHARACTER DESIGN BY LARI",
		"\"ROXY\" AND \"CHERRI\"",
	]))
	root.add_child(_section_panel("3D ENVIRONMENT", [
		"3D ENVIRONMENT BY PYEERZ",
		"## SOUNDS & MUSICS",
		"SUNO PAID LICENSES & PIXABAY.COM",
	]))

	var back := Button.new()
	back.text = "BACK TO TITLE"
	back.custom_minimum_size = Vector2(0.0, 62.0)
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_override("font", PIXEL_FONT)
	back.add_theme_font_size_override("font_size", 28)
	back.add_theme_color_override("font_color", Color.WHITE)
	back.add_theme_color_override("font_outline_color", Color("#c4657e"))
	back.add_theme_constant_override("outline_size", 5)
	back.add_theme_stylebox_override("normal", _button_style(Color("#ffd84a")))
	back.add_theme_stylebox_override("hover", _button_style(Color("#ffe46c")))
	back.pressed.connect(_go_back)
	root.add_child(back)

	var note := _pixel_label("PRESS ANY KEY OR BUTTON TO RETURN", 14, Color("#c4657e"))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(note)


func _section_panel(title_text: String, lines: Array) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#f8f7fa"), Color("#cad0da"), 24.0, 1))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := _pixel_label(title_text, 24, Color("#ffd84a"))
	box.add_child(title)

	for line in lines:
		var raw_line := str(line)
		var is_heading := raw_line.begins_with("## ")
		var display_line := raw_line.trim_prefix("## ")
		var label := _pixel_label(display_line, 19 if not is_heading else 24, Color("#434a54") if not is_heading else Color("#ffd84a"))
		box.add_child(label)
	return panel


func _pixel_label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", PIXEL_FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("#c4657e"))
	label.add_theme_constant_override("outline_size", 4)
	return label


func _panel_style(fill: Color, border: Color, radius: float, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	return style


func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(18)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style


func _go_back() -> void:
	if _select_player != null and not _select_player.playing:
		_select_player.play()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
