extends Control

const MAIN_MENU_SCENE := "res://scenes/MainMenu.tscn"
const GAME_SCENE := "res://scenes/Loading.tscn"

const PIXEL_FONT := preload("res://fonts/upheavtt.ttf")
const SELECT_SOUND := preload("res://sounds/select.mp3")

const MATCH_TYPES := ["DUEL 1 VS 1", "ASSISTANT + AI PLAYER"]
const AI_LEVELS := ["EASY", "NORMAL", "HARD"]
const POINTS := ["5", "7", "11", "15", "21"]
const CHARACTER_NAMES := ["AKANEE", "KAITO", "JADE", "PANYA", "MAYOO", "JEKKIE", "ROXY", "CHERRI"]
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

var _select_player: AudioStreamPlayer
var _focus_zone := 0
var _match_index := 1
var _ai_index := 1
var _points_index := 4
var _avatar_index := 0
var _match_buttons: Array[Button] = []
var _ai_buttons: Array[Button] = []
var _points_buttons: Array[Button] = []
var _avatar_cards: Array[PanelContainer] = []
var _back_button: Button
var _status_label: Label
var _p1_label: Label


func _ready() -> void:
	_add_default_inputs()
	_build_character_select()
	_update_visuals()


func _unhandled_input(event: InputEvent) -> void:
	if _is_up(event):
		_move_focus(-1)
		_mark_input_handled()
	elif _is_down(event):
		_move_focus(1)
		_mark_input_handled()
	elif _is_left(event):
		_move_choice(-1)
		_mark_input_handled()
	elif _is_right(event):
		_move_choice(1)
		_mark_input_handled()
	elif _is_accept(event):
		_mark_input_handled()
		_accept_focus()
	elif event.is_action_pressed("ui_cancel"):
		_mark_input_handled()
		_go_back()


func _build_character_select() -> void:
	_select_player = AudioStreamPlayer.new()
	_select_player.stream = SELECT_SOUND
	add_child(_select_player)

	var background := ColorRect.new()
	background.color = Color("#d8dce2")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var back_wrap := MarginContainer.new()
	back_wrap.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	back_wrap.offset_left = 26.0
	back_wrap.offset_top = 26.0
	back_wrap.offset_right = -26.0
	back_wrap.custom_minimum_size = Vector2(0.0, 60.0)
	add_child(back_wrap)

	_back_button = _flat_pixel_button("< BACK", 27, Color("#8fd4ef"))
	_back_button.custom_minimum_size = Vector2(190.0, 48.0)
	_back_button.pressed.connect(_go_back)
	back_wrap.add_child(_back_button)

	var main := VBoxContainer.new()
	main.alignment = BoxContainer.ALIGNMENT_CENTER
	main.add_theme_constant_override("separation", 16)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main.offset_left = 42.0
	main.offset_top = 52.0
	main.offset_right = -42.0
	main.offset_bottom = -34.0
	add_child(main)

	var title := _pixel_label("SELECT CHARACTER", 50, Color("#ffd84a"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main.add_child(title)

	var match_panel := PanelContainer.new()
	match_panel.custom_minimum_size = Vector2(860.0, 80.0)
	match_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.0, 0.0, 0.0, 0.0), Color("#ffd84a"), 18.0, 3))
	main.add_child(match_panel)

	var match_row := HBoxContainer.new()
	match_row.alignment = BoxContainer.ALIGNMENT_CENTER
	match_row.add_theme_constant_override("separation", 14)
	match_panel.add_child(match_row)

	var match_label := _pixel_label("MATCH TYPE", 25, Color.WHITE)
	match_row.add_child(match_label)
	for i in range(MATCH_TYPES.size()):
		var button := _block_button(MATCH_TYPES[i], 23)
		button.pressed.connect(_on_match_pressed.bind(i))
		match_row.add_child(button)
		_match_buttons.append(button)

	var ai_panel := PanelContainer.new()
	ai_panel.custom_minimum_size = Vector2(830.0, 78.0)
	ai_panel.add_theme_stylebox_override("panel", _panel_style(Color("#f7f8fb"), Color("#c6ccd5"), 14.0, 2))
	main.add_child(ai_panel)

	var ai_row := HBoxContainer.new()
	ai_row.alignment = BoxContainer.ALIGNMENT_CENTER
	ai_row.add_theme_constant_override("separation", 14)
	ai_panel.add_child(ai_row)

	var left_arrow := _block_button("<", 37, Vector2(68.0, 52.0), false)
	ai_row.add_child(left_arrow)
	var ai_label := _pixel_label("AI LEVEL", 26, Color.WHITE)
	ai_row.add_child(ai_label)
	for i in range(AI_LEVELS.size()):
		var button := _block_button(AI_LEVELS[i], 23, Vector2(128.0, 52.0))
		button.pressed.connect(_on_ai_pressed.bind(i))
		ai_row.add_child(button)
		_ai_buttons.append(button)
	var right_arrow := _block_button(">", 37, Vector2(68.0, 52.0), false)
	ai_row.add_child(right_arrow)

	var points_panel := PanelContainer.new()
	points_panel.custom_minimum_size = Vector2(704.0, 78.0)
	points_panel.add_theme_stylebox_override("panel", _panel_style(Color("#f7f8fb"), Color("#c6ccd5"), 14.0, 2))
	main.add_child(points_panel)

	var points_row := HBoxContainer.new()
	points_row.alignment = BoxContainer.ALIGNMENT_CENTER
	points_row.add_theme_constant_override("separation", 18)
	points_panel.add_child(points_row)

	var points_label := _pixel_label("POINTS / SET", 26, Color.WHITE)
	points_row.add_child(points_label)
	for i in range(POINTS.size()):
		var button := _block_button(POINTS[i], 26, Vector2(72.0, 52.0))
		button.pressed.connect(_on_points_pressed.bind(i))
		points_row.add_child(button)
		_points_buttons.append(button)

	var player_margin := MarginContainer.new()
	player_margin.add_theme_constant_override("margin_left", 92)
	player_margin.add_theme_constant_override("margin_right", 92)
	player_margin.custom_minimum_size = Vector2(1240.0, 44.0)
	main.add_child(player_margin)

	var player_row := HBoxContainer.new()
	player_row.alignment = BoxContainer.ALIGNMENT_CENTER
	player_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_margin.add_child(player_row)

	_p1_label = _pixel_label("1P AKANEE", 31, Color("#ffd84a"))
	_p1_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_row.add_child(_p1_label)
	var p2 := _pixel_label("2P AUTO", 31, Color("#ffd84a"))
	p2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	p2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_row.add_child(p2)

	var roster_panel := PanelContainer.new()
	roster_panel.custom_minimum_size = Vector2(1180.0, 158.0)
	roster_panel.add_theme_stylebox_override("panel", _panel_style(Color("#f0f1f5"), Color("#c6ccd5"), 24.0, 2))
	main.add_child(roster_panel)

	var roster := HBoxContainer.new()
	roster.alignment = BoxContainer.ALIGNMENT_CENTER
	roster.add_theme_constant_override("separation", 14)
	roster_panel.add_child(roster)

	for i in range(CHARACTER_NAMES.size()):
		var card := _avatar_card(i)
		card.gui_input.connect(_on_avatar_gui_input.bind(i))
		roster.add_child(card)
		_avatar_cards.append(card)

	_status_label = _pixel_label("ENTER / START TO CONFIRM", 20, Color.WHITE)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main.add_child(_status_label)


func _avatar_card(index: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(132.0, 132.0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_theme_stylebox_override("panel", _panel_style(Color.WHITE, Color("#cfd4dc"), 12.0, 0))

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	card.add_child(box)

	var image := TextureRect.new()
	var texture := load(AVATAR_PATHS[index]) as Texture2D
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.custom_minimum_size = Vector2(118.0, 88.0)
	box.add_child(image)

	var name := _pixel_label(CHARACTER_NAMES[index], 20, Color("#ffd84a"))
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name)
	return card


func _on_match_pressed(index: int) -> void:
	_match_index = index
	_focus_zone = 0
	_play_select()
	_update_visuals()


func _on_ai_pressed(index: int) -> void:
	_ai_index = index
	_focus_zone = 1
	_play_select()
	_update_visuals()


func _on_points_pressed(index: int) -> void:
	_points_index = index
	_focus_zone = 2
	_play_select()
	_update_visuals()


func _on_avatar_gui_input(event: InputEvent, index: int) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event != null and mouse_event.pressed:
		_avatar_index = index
		_focus_zone = 3
		_play_select()
		_update_visuals()


func _move_focus(direction: int) -> void:
	_focus_zone = wrapi(_focus_zone + direction, 0, 5)
	_play_select()
	_update_visuals()


func _move_choice(direction: int) -> void:
	match _focus_zone:
		0:
			_match_index = wrapi(_match_index + direction, 0, MATCH_TYPES.size())
		1:
			_ai_index = wrapi(_ai_index + direction, 0, AI_LEVELS.size())
		2:
			_points_index = wrapi(_points_index + direction, 0, POINTS.size())
		3:
			_avatar_index = wrapi(_avatar_index + direction, 0, CHARACTER_NAMES.size())
		4:
			pass
	_play_select()
	_update_visuals()


func _accept_focus() -> void:
	if _focus_zone == 4:
		_go_back()
	else:
		_confirm_selection()


func _confirm_selection() -> void:
	_play_select()
	get_tree().set_meta("player1_char", _avatar_index)
	get_tree().set_meta("player2_char", _pick_ai_character())
	get_tree().set_meta("ai_level", AI_LEVELS[_ai_index].to_lower())
	get_tree().set_meta("win_points", int(POINTS[_points_index]))
	get_tree().set_meta("match_type", "assistant" if _match_index == 1 else "dual")
	get_tree().change_scene_to_file(GAME_SCENE)


func _pick_ai_character() -> int:
	var candidates: Array[int] = []
	for i in range(CHARACTER_NAMES.size()):
		if i != _avatar_index:
			candidates.append(i)
	return int(candidates.pick_random())


func _update_visuals() -> void:
	for i in range(_match_buttons.size()):
		_apply_button_state(_match_buttons[i], i == _match_index, _focus_zone == 0 and i == _match_index)
	for i in range(_ai_buttons.size()):
		_apply_button_state(_ai_buttons[i], i == _ai_index, _focus_zone == 1 and i == _ai_index)
	for i in range(_points_buttons.size()):
		_apply_button_state(_points_buttons[i], i == _points_index, _focus_zone == 2 and i == _points_index)
	for i in range(_avatar_cards.size()):
		var selected: bool = i == _avatar_index
		var focused: bool = _focus_zone == 3 and selected
		_avatar_cards[i].add_theme_stylebox_override("panel", _panel_style(
			Color.WHITE,
			Color("#ffd84a") if focused else Color("#cfd4dc"),
			12.0,
			5 if selected else 0
		))
		_avatar_cards[i].modulate = Color.WHITE if selected else Color(1.0, 1.0, 1.0, 0.62)
		_avatar_cards[i].scale = Vector2(1.08, 1.08) if focused else Vector2.ONE

	_apply_back_state(_focus_zone == 4)
	_p1_label.text = "1P %s" % CHARACTER_NAMES[_avatar_index]


func _apply_button_state(button: Button, selected: bool, focused: bool) -> void:
	var color: Color = Color("#ffd84a") if selected else Color("#c8ced8")
	if focused:
		color = Color("#ffe46c")
	button.add_theme_stylebox_override("normal", _button_style(color))
	button.add_theme_stylebox_override("hover", _button_style(Color("#ffe46c")))
	button.add_theme_color_override("font_color", Color.WHITE)
	button.scale = Vector2(1.04, 1.04) if focused else Vector2.ONE


func _apply_back_state(focused: bool) -> void:
	_back_button.add_theme_color_override("font_color", Color("#ffe46c") if focused else Color("#8fd4ef"))
	_back_button.scale = Vector2(1.08, 1.08) if focused else Vector2.ONE


func _flat_pixel_button(text: String, size: int, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", PIXEL_FONT)
	button.add_theme_font_size_override("font_size", size)
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", Color("#ffe46c"))
	button.add_theme_color_override("font_outline_color", Color("#c4657e"))
	button.add_theme_constant_override("outline_size", 5)
	return button


func _block_button(text: String, size: int, minimum_size: Vector2 = Vector2(180.0, 60.0), outlined: bool = true) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = minimum_size
	button.add_theme_font_override("font", PIXEL_FONT)
	button.add_theme_font_size_override("font_size", size)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_outline_color", Color("#c4657e"))
	button.add_theme_constant_override("outline_size", 4)
	if outlined:
		button.add_theme_stylebox_override("normal", _button_style(Color("#c8ced8")))
		button.add_theme_stylebox_override("hover", _button_style(Color("#ffe46c")))
	else:
		button.add_theme_stylebox_override("normal", _panel_style(Color("#f7f8fb"), Color("#b8c2d1"), 8.0, 1))
		button.add_theme_stylebox_override("hover", _panel_style(Color("#f7f8fb"), Color("#ffd84a"), 8.0, 2))
	return button


func _pixel_label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", PIXEL_FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("#c4657e"))
	label.add_theme_constant_override("outline_size", 5)
	return label


func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


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


func _add_default_inputs() -> void:
	if not InputMap.has_action("menu_accept"):
		InputMap.add_action("menu_accept")
	if not InputMap.action_has_event("menu_accept", _key_event(KEY_ENTER)):
		InputMap.action_add_event("menu_accept", _key_event(KEY_ENTER))
	if not InputMap.action_has_event("menu_accept", _key_event(KEY_KP_ENTER)):
		InputMap.action_add_event("menu_accept", _key_event(KEY_KP_ENTER))


func _key_event(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	return event


func _is_up(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_up") or event.is_action_pressed("menu_up")


func _is_down(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_down") or event.is_action_pressed("menu_down")


func _is_left(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_left") or event.is_action_pressed("menu_left")


func _is_right(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_right") or event.is_action_pressed("menu_right")


func _is_accept(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_accept") or event.is_action_pressed("menu_accept")


func _play_select() -> void:
	_select_player.play()


func _go_back() -> void:
	_play_select()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _mark_input_handled() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
