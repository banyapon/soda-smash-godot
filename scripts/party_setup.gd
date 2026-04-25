extends Control

const MAIN_MENU_SCENE := "res://scenes/MainMenu.tscn"
const GAME_SCENE := "res://scenes/Loading.tscn"
const PIXEL_FONT := preload("res://fonts/upheavtt.ttf")
const SELECT_SOUND := preload("res://sounds/select.mp3")
const CHARACTER_NAMES := ["AKANEE", "KAITO", "JADE", "PANYA", "MAYOO", "JEKKIE", "ROXY", "CHERRI"]
const PARTY_COLORS := [Color("#ff5867"), Color("#4f93ff"), Color("#33d17a"), Color("#b259ff")]
const TEAM_NAMES := ["RED", "BLUE"]
const CONTROL_HINTS := [
	"A / D",
	"LEFT / RIGHT",
	"F / H",
	"NP4 / NP6",
]

var _select_player: AudioStreamPlayer
var _connected_gamepads := 0
var _step := 0
var _focus_player := 0
var _player_chars := [0, 1, 2, 3]
var _player_teams := [0, 1, 0, 1]
var _player_cards: Array[PanelContainer] = []
var _char_buttons: Array[Array] = []
var _team_buttons: Array[Array] = []
var _step_label: Label
var _summary_label: Label
var _start_button: Button


func _ready() -> void:
	_connected_gamepads = Input.get_connected_joypads().size()
	_build_screen()
	_update_visuals()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _step == 0:
			_go_back()
		else:
			_step = 0
			_play_select()
			_update_visuals()
		_mark_input_handled()
		return
	if event.is_action_pressed("ui_left"):
		_focus_player = wrapi(_focus_player - 1, 0, 4)
		_play_select()
		_update_visuals()
		_mark_input_handled()
		return
	if event.is_action_pressed("ui_right"):
		_focus_player = wrapi(_focus_player + 1, 0, 4)
		_play_select()
		_update_visuals()
		_mark_input_handled()
		return
	if event.is_action_pressed("ui_up"):
		if _step == 0:
			_cycle_char(_focus_player, -1)
		else:
			_set_team(_focus_player, 0)
		_mark_input_handled()
		return
	if event.is_action_pressed("ui_down"):
		if _step == 0:
			_cycle_char(_focus_player, 1)
		else:
			_set_team(_focus_player, 1)
		_mark_input_handled()
		return
	if event.is_action_pressed("ui_accept"):
		_start_match()
		_mark_input_handled()


func _build_screen() -> void:
	_select_player = AudioStreamPlayer.new()
	_select_player.stream = SELECT_SOUND
	add_child(_select_player)

	var bg := ColorRect.new()
	bg.color = Color("#d8dce2")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 16.0
	scroll.offset_top = 16.0
	scroll.offset_right = -16.0
	scroll.offset_bottom = -16.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var root := VBoxContainer.new()
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 12)
	root.custom_minimum_size = Vector2(1180.0, 0.0)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(root)

	var back := Button.new()
	back.text = "< BACK"
	back.flat = true
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_override("font", PIXEL_FONT)
	back.add_theme_font_size_override("font_size", 28)
	back.add_theme_color_override("font_color", Color("#8fd4ef"))
	back.add_theme_color_override("font_outline_color", Color("#c4657e"))
	back.add_theme_constant_override("outline_size", 5)
	back.pressed.connect(_go_back)
	root.add_child(back)

	var title := _pixel_label("4 PLAYERS PARTY", 46, Color("#ffd84a"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	_step_label = _pixel_label("STEP 1 CHARACTER  |  STEP 2 TEAM", 22, Color("#c4657e"))
	_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_step_label)

	var row_wrap := CenterContainer.new()
	row_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(row_wrap)

	var row := GridContainer.new()
	row.columns = 4
	row.custom_minimum_size = Vector2(928.0, 0.0)
	row.add_theme_constant_override("h_separation", 16)
	row.add_theme_constant_override("v_separation", 16)
	row_wrap.add_child(row)

	for i in range(4):
		var card := _player_card(i)
		row.add_child(card)
		_player_cards.append(card)

	_summary_label = _pixel_label("", 18, Color("#434a54"))
	_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_summary_label)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 20)
	root.add_child(actions)

	var back_button := Button.new()
	back_button.text = "BACK"
	back_button.custom_minimum_size = Vector2(180, 68)
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.add_theme_font_override("font", PIXEL_FONT)
	back_button.add_theme_font_size_override("font_size", 28)
	back_button.add_theme_color_override("font_color", Color.WHITE)
	back_button.add_theme_color_override("font_outline_color", Color("#c4657e"))
	back_button.add_theme_constant_override("outline_size", 5)
	back_button.add_theme_stylebox_override("normal", _button_style(Color("#c0c6d1")))
	back_button.pressed.connect(_on_back_step_pressed)
	actions.add_child(back_button)

	_start_button = Button.new()
	_start_button.text = "START MATCH!"
	_start_button.custom_minimum_size = Vector2(300, 68)
	_start_button.focus_mode = Control.FOCUS_NONE
	_start_button.add_theme_font_override("font", PIXEL_FONT)
	_start_button.add_theme_font_size_override("font_size", 32)
	_start_button.add_theme_color_override("font_color", Color.WHITE)
	_start_button.add_theme_color_override("font_outline_color", Color("#c4657e"))
	_start_button.add_theme_constant_override("outline_size", 5)
	_start_button.add_theme_stylebox_override("normal", _button_style(Color("#15cc57")))
	_start_button.pressed.connect(_start_match)
	actions.add_child(_start_button)


func _player_card(index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 388)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#eef0f4"), PARTY_COLORS[index], 22.0, 3))

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var title := _pixel_label("PLAYER %d" % (index + 1), 24, PARTY_COLORS[index])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var control_text := "GAMEPAD AUTO" if index < _connected_gamepads else "KEYBOARD"
	var control := _pixel_label(control_text, 16, Color("#6b7280"))
	control.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(control)

	var avatar_frame := PanelContainer.new()
	avatar_frame.custom_minimum_size = Vector2(120, 126)
	avatar_frame.add_theme_stylebox_override("panel", _panel_style(PARTY_COLORS[index], Color("#b8c2d1"), 18.0, 1))
	box.add_child(avatar_frame)

	var avatar := TextureRect.new()
	avatar.name = "Avatar"
	avatar.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	avatar_frame.add_child(avatar)

	var name := _pixel_label("", 20, Color.WHITE)
	name.name = "Name"
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name)

	var choose_row := HBoxContainer.new()
	choose_row.alignment = BoxContainer.ALIGNMENT_CENTER
	choose_row.add_theme_constant_override("separation", 8)
	box.add_child(choose_row)

	var left := _mini_button("<", Callable(self, "_on_char_left").bind(index))
	var right := _mini_button(">", Callable(self, "_on_char_right").bind(index))
	var hint := _pixel_label(CONTROL_HINTS[index], 14, Color("#6b7280"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	choose_row.add_child(left)
	choose_row.add_child(hint)
	choose_row.add_child(right)
	_char_buttons.append([left, right])

	var team_row := HBoxContainer.new()
	team_row.alignment = BoxContainer.ALIGNMENT_CENTER
	team_row.add_theme_constant_override("separation", 8)
	box.add_child(team_row)

	var red := _team_button("RED", Color("#ff5867"), Callable(self, "_on_team_red").bind(index))
	var blue := _team_button("BLUE", Color("#4f93ff"), Callable(self, "_on_team_blue").bind(index))
	team_row.add_child(red)
	team_row.add_child(blue)
	_team_buttons.append([red, blue])

	panel.set_meta("avatar", avatar)
	panel.set_meta("name", name)
	return panel


func _cycle_char(index: int, direction: int) -> void:
	if _step != 0:
		return
	_player_chars[index] = wrapi(_player_chars[index] + direction, 0, CHARACTER_NAMES.size())
	_play_select()
	_update_visuals()


func _set_team(index: int, team: int) -> void:
	if _step != 1:
		return
	_player_teams[index] = team
	_play_select()
	_update_visuals()


func _update_visuals() -> void:
	_step_label.text = "STEP 1 CHARACTER  |  STEP 2 TEAM" if _step == 0 else "STEP 1 CHARACTER  |  STEP 2 TEAM ASSIGNMENT"
	for i in range(4):
		var panel_card := _player_cards[i]
		var avatar := panel_card.get_meta("avatar") as TextureRect
		var name := panel_card.get_meta("name") as Label
		avatar.texture = load("res://arena/%d.png" % (_player_chars[i] + 1))
		name.text = CHARACTER_NAMES[_player_chars[i]]
		var border_color: Color = PARTY_COLORS[i]
		var fill_color: Color = Color("#eef0f4")
		if i == _focus_player:
			border_color = Color("#ffd84a")
			fill_color = Color("#f8f4d6") if _step == 0 else Color("#e7f0fb")
		panel_card.add_theme_stylebox_override("panel", _panel_style(fill_color, border_color, 22.0, 4 if i == _focus_player else 3))
		panel_card.scale = Vector2(1.03, 1.03) if i == _focus_player else Vector2.ONE
		for button in _char_buttons[i]:
			button.visible = _step == 0
		for j in range(2):
			var button: Button = _team_buttons[i][j]
			button.visible = _step == 1
			button.modulate = Color.WHITE if _player_teams[i] == j else Color(1, 1, 1, 0.45)

	var red_count := _player_teams.count(0)
	var blue_count := _player_teams.count(1)
	if _step == 0:
		_summary_label.text = "GAMEPADS %d  |  SELECT PLAYER %d  |  LEFT/RIGHT TO CHOOSE CARD  |  UP/DOWN TO CHANGE CHARACTER" % [_connected_gamepads, _focus_player + 1]
	else:
		_summary_label.text = "GAMEPADS %d  |  RED %d  BLUE %d  |  LEFT/RIGHT TO CHOOSE CARD  |  UP = RED / DOWN = BLUE" % [_connected_gamepads, red_count, blue_count]
	_start_button.disabled = _step == 0 or red_count != 2 or blue_count != 2
	_start_button.modulate = Color.WHITE if not _start_button.disabled else Color(1, 1, 1, 0.45)
	_start_button.text = "NEXT" if _step == 0 else "START MATCH!"


func _start_match() -> void:
	if _step == 0:
		_step = 1
		_play_select()
		_update_visuals()
		return
	var red_players := []
	var blue_players := []
	for i in range(4):
		if _player_teams[i] == 0:
			red_players.append(_player_chars[i])
		else:
			blue_players.append(_player_chars[i])
	if red_players.size() != 2 or blue_players.size() != 2:
		return
	get_tree().set_meta("player1_char", int(red_players[0]))
	get_tree().set_meta("team1_assist_char", int(red_players[1]))
	get_tree().set_meta("player2_char", int(blue_players[0]))
	get_tree().set_meta("team2_assist_char", int(blue_players[1]))
	get_tree().set_meta("ai_level", "normal")
	get_tree().set_meta("win_points", 21)
	get_tree().set_meta("match_type", "party4")
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_back_step_pressed() -> void:
	if _step == 0:
		_go_back()
	else:
		_step = 0
		_play_select()
		_update_visuals()


func _on_char_left(index: int) -> void:
	_cycle_char(index, -1)


func _on_char_right(index: int) -> void:
	_cycle_char(index, 1)


func _on_team_red(index: int) -> void:
	_set_team(index, 0)


func _on_team_blue(index: int) -> void:
	_set_team(index, 1)


func _mini_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(44, 44)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", PIXEL_FONT)
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_outline_color", Color("#c4657e"))
	button.add_theme_constant_override("outline_size", 4)
	button.add_theme_stylebox_override("normal", _button_style(Color("#c0c6d1")))
	button.pressed.connect(callback)
	return button


func _team_button(text: String, color: Color, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(90, 48)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", PIXEL_FONT)
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_outline_color", Color("#c4657e"))
	button.add_theme_constant_override("outline_size", 4)
	button.add_theme_stylebox_override("normal", _button_style(color))
	button.pressed.connect(callback)
	return button


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
	style.set_corner_radius_all(14)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


func _play_select() -> void:
	if _select_player != null:
		_select_player.play()


func _go_back() -> void:
	_play_select()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _mark_input_handled() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
