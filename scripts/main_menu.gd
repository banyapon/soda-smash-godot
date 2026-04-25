extends Control

const CHARACTER_SCENE := "res://scenes/Character.tscn"
const PARTY_SCENE := "res://scenes/PartySetup.tscn"
const CREDITS_SCENE := "res://scenes/Credits.tscn"
const OPTIONS_SCENE := "res://scenes/Options.tscn"

const BEACH_BG := preload("res://images/title.jpg")
const LOGO := preload("res://images/logo.png")
const PIXEL_FONT := preload("res://fonts/upheavtt.ttf")
const SELECT_SOUND := preload("res://sounds/select.mp3")
const TITLE_MUSIC := preload("res://sounds/title.mp3")

var _select_player: AudioStreamPlayer
var _menu_buttons: Array[Button] = []
var _selected_index := 0
var _gamepad_label: Label


func _ready() -> void:
	_build_menu()
	_select_menu_button(0, false)


func _unhandled_input(event: InputEvent) -> void:
	if _is_menu_up(event):
		_select_menu_button(_selected_index - 1, true)
		_mark_input_handled()
	elif _is_menu_down(event):
		_select_menu_button(_selected_index + 1, true)
		_mark_input_handled()
	elif _is_menu_accept(event):
		_mark_input_handled()
		_menu_buttons[_selected_index].emit_signal("pressed")
	elif event.is_action_pressed("ui_cancel"):
		_mark_input_handled()
		get_tree().quit()


func _build_menu() -> void:
	_select_player = AudioStreamPlayer.new()
	_select_player.stream = SELECT_SOUND
	add_child(_select_player)

	var music := AudioStreamPlayer.new()
	music.stream = TITLE_MUSIC
	music.autoplay = true
	music.volume_db = -8.0
	add_child(music)

	var background := TextureRect.new()
	background.texture = BEACH_BG
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var shade := ColorRect.new()
	shade.color = Color(1.0, 1.0, 1.0, 0.16)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 10)
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_top = 35.0
	layout.offset_bottom = -28.0
	add_child(layout)

	var logo_wrap := CenterContainer.new()
	logo_wrap.custom_minimum_size = Vector2(900.0, 315.0)
	layout.add_child(logo_wrap)

	var logo := TextureRect.new()
	logo.texture = LOGO
	logo.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(820.0, 300.0)
	logo_wrap.add_child(logo)

	var menu_panel := PanelContainer.new()
	menu_panel.custom_minimum_size = Vector2(690.0, 250.0)
	menu_panel.add_theme_stylebox_override("panel", _panel_style(Color.TRANSPARENT, Color.TRANSPARENT, 0.0, 0))
	layout.add_child(menu_panel)

	var buttons := VBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 10)
	buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu_panel.add_child(buttons)

	_add_menu_button(buttons, "START GAME", _on_start_game_pressed)
	_add_menu_button(buttons, "PLAYER VS PLAYER", _on_player_vs_player_pressed)
	_add_menu_button(buttons, "4 PLAYERS PARTY", _on_party_pressed)
	_add_menu_button(buttons, "CREDIT & LICENSES", _on_credits_pressed)
	_add_menu_button(buttons, "OPTIONS", _on_options_pressed)

	_gamepad_label = Label.new()
	_gamepad_label.text = "GAMEPADS CONNECTED: %d" % Input.get_connected_joypads().size()
	_gamepad_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gamepad_label.add_theme_font_override("font", PIXEL_FONT)
	_gamepad_label.add_theme_font_size_override("font_size", 18)
	_gamepad_label.add_theme_color_override("font_color", Color("#ffe46c"))
	_gamepad_label.add_theme_color_override("font_outline_color", Color("#f36d80"))
	_gamepad_label.add_theme_constant_override("outline_size", 4)
	layout.add_child(_gamepad_label)

	var footer := Label.new()
	footer.text = "DAYDEV CO., LTD. 2026 IN ASSOCIATION WITH N4ANIMATION ART"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_override("font", PIXEL_FONT)
	footer.add_theme_font_size_override("font_size", 18)
	footer.add_theme_color_override("font_color", Color.WHITE)
	footer.add_theme_color_override("font_outline_color", Color(0.25, 0.28, 0.35, 0.45))
	footer.add_theme_constant_override("outline_size", 4)
	layout.add_child(footer)


func _add_menu_button(parent: Control, text: String, callback: Callable, color: Color = Color.WHITE) -> void:
	var button := Button.new()
	button.text = text
	button.set_meta("menu_text", text)
	button.set_meta("default_color", color)
	button.flat = true
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(520.0, 34.0)
	button.add_theme_font_override("font", PIXEL_FONT)
	button.add_theme_font_size_override("font_size", 26)
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", color)
	button.add_theme_color_override("font_focus_color", color)
	button.add_theme_color_override("font_pressed_color", Color("#ffffff"))
	button.add_theme_color_override("font_outline_color", Color("#f36d80"))
	button.add_theme_constant_override("outline_size", 5)
	var empty_style := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty_style)
	button.add_theme_stylebox_override("hover", empty_style)
	button.add_theme_stylebox_override("pressed", empty_style)
	button.add_theme_stylebox_override("focus", empty_style)
	button.pressed.connect(callback)
	parent.add_child(button)
	_menu_buttons.append(button)


func _select_menu_button(index: int, play_sound: bool = true) -> void:
	if _menu_buttons.is_empty():
		return

	var next_index := wrapi(index, 0, _menu_buttons.size())
	var changed := next_index != _selected_index
	_selected_index = next_index
	if play_sound and changed:
		_play_select()
	for i in range(_menu_buttons.size()):
		var button := _menu_buttons[i]
		var selected: bool = i == _selected_index
		button.text = str(button.get_meta("menu_text"))
		button.scale = Vector2.ONE
		var font_color := Color("#ffe46c") if selected else Color(button.get_meta("default_color", Color.WHITE))
		if selected:
			button.grab_focus()
		button.add_theme_color_override("font_color", font_color)
		button.add_theme_color_override("font_hover_color", font_color)
		button.add_theme_color_override("font_focus_color", font_color)
		button.add_theme_color_override("font_pressed_color", font_color)


func _mark_input_handled() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _is_menu_up(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left") or event.is_action_pressed("menu_up") or event.is_action_pressed("menu_left")


func _is_menu_down(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right") or event.is_action_pressed("menu_down") or event.is_action_pressed("menu_right")


func _is_menu_accept(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_accept") or event.is_action_pressed("menu_accept")


func _panel_style(fill: Color, border: Color, radius: float, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	return style


func _play_select() -> void:
	_select_player.play()


func _on_start_game_pressed() -> void:
	_play_select()
	get_tree().set_meta("menu_mode", "assistant")
	get_tree().change_scene_to_file(CHARACTER_SCENE)


func _on_player_vs_player_pressed() -> void:
	_play_select()
	get_tree().set_meta("menu_mode", "pvp")
	get_tree().change_scene_to_file(CHARACTER_SCENE)


func _on_party_pressed() -> void:
	_play_select()
	get_tree().change_scene_to_file(PARTY_SCENE)


func _on_credits_pressed() -> void:
	_play_select()
	get_tree().change_scene_to_file(CREDITS_SCENE)


func _on_options_pressed() -> void:
	_play_select()
	get_tree().change_scene_to_file(OPTIONS_SCENE)
