extends Control

const MAIN_MENU_SCENE := "res://scenes/MainMenu.tscn"

const PIXEL_FONT := preload("res://fonts/upheavtt.ttf")
const SELECT_SOUND := preload("res://sounds/select.mp3")

var _select_player: AudioStreamPlayer
var _tab_buttons: Dictionary = {}
var _content: VBoxContainer
var _active_tab := "audio"
var _tab_order := ["audio", "camera", "p1", "p2"]
var _tab_index := 0
var _nav_row := 0
var _camera_mode := "fixed_wide"
var _camera_buttons: Array[Button] = []
var _camera_button_modes: Array[String] = []
var _camera_focus_index := 1
var _back_button: Button


func _ready() -> void:
	_camera_mode = str(get_tree().get_meta("camera_mode", "fixed_wide"))
	_build_options()
	_show_tab("audio")


func _unhandled_input(event: InputEvent) -> void:
	if _is_menu_left(event):
		_move_horizontal(-1)
		_mark_input_handled()
	elif _is_menu_right(event):
		_move_horizontal(1)
		_mark_input_handled()
	elif _is_menu_up(event):
		_move_vertical(-1)
		_mark_input_handled()
	elif _is_menu_down(event):
		_move_vertical(1)
		_mark_input_handled()
	elif _is_menu_accept(event):
		_activate_current_selection()
		_mark_input_handled()
	elif event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		_mark_input_handled()


func _build_options() -> void:
	_select_player = AudioStreamPlayer.new()
	_select_player.stream = SELECT_SOUND
	add_child(_select_player)

	var background := ColorRect.new()
	background.color = Color("#d8e0e8")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	_add_side_banner(0.0)
	_add_side_banner(1.0)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 35.0
	center.offset_bottom = -35.0
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1120.0, 560.0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#f4f5f8"), Color("#c4cbd5"), 28.0, 2))
	center.add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 28)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(root)

	var title := Label.new()
	title.text = "OPTIONS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", PIXEL_FONT)
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color("#ffd84a"))
	title.add_theme_color_override("font_outline_color", Color("#c4657e"))
	title.add_theme_constant_override("outline_size", 6)
	root.add_child(title)

	var tab_wrap := PanelContainer.new()
	tab_wrap.add_theme_stylebox_override("panel", _panel_style(Color(0.0, 0.0, 0.0, 0.0), Color("#ffd84a"), 18.0, 3))
	root.add_child(tab_wrap)

	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 20)
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_wrap.add_child(tabs)

	_add_tab_button(tabs, "audio", "AUDIO")
	_add_tab_button(tabs, "camera", "CAMERA")
	_add_tab_button(tabs, "p1", "P1 KEYS")
	_add_tab_button(tabs, "p2", "P2 KEYS")

	var content_panel := PanelContainer.new()
	content_panel.custom_minimum_size = Vector2(1040.0, 210.0)
	content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_panel.add_theme_stylebox_override("panel", _panel_style(Color("#fbfbfd"), Color("#c9ced7"), 13.0, 2))
	root.add_child(content_panel)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 16)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_panel.add_child(_content)

	var back := Button.new()
	back.text = "< BACK"
	back.flat = true
	back.focus_mode = Control.FOCUS_NONE
	back.custom_minimum_size = Vector2(180.0, 42.0)
	back.add_theme_font_override("font", PIXEL_FONT)
	back.add_theme_font_size_override("font_size", 28)
	back.add_theme_color_override("font_color", Color("#8fd4ef"))
	back.add_theme_color_override("font_hover_color", Color("#ffd84a"))
	back.add_theme_color_override("font_outline_color", Color("#c4657e"))
	back.add_theme_constant_override("outline_size", 5)
	back.pressed.connect(_on_back_pressed)
	root.add_child(back)
	_back_button = back


func _add_side_banner(anchor: float) -> void:
	var banner := ColorRect.new()
	banner.color = Color("#f5cf38")
	banner.anchor_top = 0.0
	banner.anchor_bottom = 1.0
	banner.anchor_left = anchor
	banner.anchor_right = anchor
	banner.offset_top = 0.0
	banner.offset_bottom = 0.0
	if anchor == 0.0:
		banner.offset_left = 0.0
		banner.offset_right = 150.0
	else:
		banner.offset_left = -150.0
		banner.offset_right = 0.0
	add_child(banner)


func _add_tab_button(parent: Control, key: String, label: String) -> void:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(132.0, 54.0)
	button.add_theme_font_override("font", PIXEL_FONT)
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_outline_color", Color("#c4657e"))
	button.add_theme_constant_override("outline_size", 4)
	button.pressed.connect(func() -> void: _show_tab(key))
	parent.add_child(button)
	_tab_buttons[key] = button


func _show_tab(key: String) -> void:
	_active_tab = key
	_tab_index = _tab_order.find(key)
	_camera_buttons.clear()
	_camera_button_modes.clear()
	_camera_focus_index = 0 if _camera_mode == "classic" else 1
	_nav_row = mini(_nav_row, _max_nav_row())
	for tab_key in _tab_buttons:
		var button: Button = _tab_buttons[tab_key]
		var active: bool = str(tab_key) == key
		var focused: bool = _nav_row == 0 and active
		button.add_theme_stylebox_override("normal", _button_style(Color("#ffe46c") if focused else (Color("#ffd84a") if active else Color("#c8ced8"))))
		button.add_theme_stylebox_override("hover", _button_style(Color("#ffe46c")))
		button.add_theme_stylebox_override("pressed", _button_style(Color("#ffd84a")))

	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()

	match key:
		"audio":
			_build_audio_tab()
		"camera":
			_build_camera_tab()
		"p1":
			_build_keys_tab("PLAYER 1", {"MOVE LEFT": "A", "MOVE RIGHT": "D", "JUMP": "W", "SMASH": "F", "CRITICAL": "AUTO", "OVERHEAT": "AUTO"})
		"p2":
			_build_keys_tab("PLAYER 2", {"MOVE LEFT": "LEFT", "MOVE RIGHT": "RIGHT", "JUMP": "UP", "SMASH": "K", "CRITICAL": "AUTO", "OVERHEAT": "AUTO"})
	_update_nav_visuals()


func _build_audio_tab() -> void:
	_add_slider("BGM VOLUME", 70.0, func(value: float) -> void:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(max(value / 100.0, 0.001)))
	)
	_add_slider("SFX VOLUME", 100.0, func(_value: float) -> void: pass)


func _build_camera_tab() -> void:
	var title := _pixel_label("CAMERA TRACK", 28, Color("#ffd84a"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_content.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(row)

	var classic := _choice_button("CLASSIC TRACK", _camera_mode == "classic")
	classic.pressed.connect(func() -> void: _set_camera_mode("classic"))
	var fixed := _choice_button("FIXED WIDE", _camera_mode == "fixed_wide")
	fixed.pressed.connect(func() -> void: _set_camera_mode("fixed_wide"))
	row.add_child(classic)
	row.add_child(fixed)
	_camera_buttons = [classic, fixed]
	_camera_button_modes = ["classic", "fixed_wide"]

	var note := _pixel_label("FIXED WIDE IS DEFAULT AND SHOWS THE WHOLE COURT.", 17, Color.WHITE)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(note)


func _build_keys_tab(title_text: String, keys: Dictionary) -> void:
	var title := _pixel_label(title_text, 28, Color("#ffd84a"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_content.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 12)
	_content.add_child(grid)

	for action in keys:
		var action_label := _pixel_label(action, 21, Color.WHITE)
		var key_label := _pixel_label(str(keys[action]), 21, Color("#ffd84a"))
		grid.add_child(action_label)
		grid.add_child(key_label)


func _add_slider(label_text: String, value: float, callback: Callable) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(box)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(row)

	var label := _pixel_label(label_text, 26, Color.WHITE)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var percent := _pixel_label("%d%%" % int(value), 24, Color("#ffd84a"))
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(percent)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.value = value
	slider.step = 1.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(slider)
	slider.value_changed.connect(func(new_value: float) -> void:
		percent.text = "%d%%" % int(new_value)
		callback.call(new_value)
	)


func _choice_button(text: String, active: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0.0, 74.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_override("font", PIXEL_FONT)
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_outline_color", Color("#c4657e"))
	button.add_theme_constant_override("outline_size", 4)
	button.add_theme_stylebox_override("normal", _button_style(Color("#ffd84a") if active else Color("#c8ced8")))
	button.add_theme_stylebox_override("hover", _button_style(Color("#ffe46c")))
	button.add_theme_stylebox_override("pressed", _button_style(Color("#ffd84a")))
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


func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


func _panel_style(fill: Color, border: Color, radius: float, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 18.0
	style.content_margin_bottom = 18.0
	return style


func _on_back_pressed() -> void:
	_select_player.play()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _move_horizontal(direction: int) -> void:
	if _nav_row == 0:
		_select_player.play()
		_show_tab(_tab_order[wrapi(_tab_index + direction, 0, _tab_order.size())])
	elif _nav_row == 1 and _active_tab == "camera" and not _camera_buttons.is_empty():
		_camera_focus_index = clampi(_camera_focus_index + direction, 0, _camera_buttons.size() - 1)
		_select_player.play()
		_update_nav_visuals()


func _move_vertical(direction: int) -> void:
	_nav_row = clampi(_nav_row + direction, 0, _max_nav_row())
	_select_player.play()
	_update_nav_visuals()


func _activate_current_selection() -> void:
	if _nav_row == 0:
		_select_player.play()
		_show_tab(_tab_order[_tab_index])
	elif _nav_row == 1 and _active_tab == "camera" and not _camera_buttons.is_empty():
		_set_camera_mode(_camera_button_modes[_camera_focus_index])
	elif _nav_row == _max_nav_row():
		_on_back_pressed()


func _set_camera_mode(mode: String) -> void:
	_camera_mode = mode
	_camera_focus_index = 0 if mode == "classic" else 1
	get_tree().set_meta("camera_mode", mode)
	_select_player.play()
	_update_nav_visuals()


func _update_nav_visuals() -> void:
	for i in range(_tab_order.size()):
		var key: String = _tab_order[i]
		var button: Button = _tab_buttons.get(key)
		if button == null:
			continue
		var active := i == _tab_index
		var focused := _nav_row == 0 and active
		button.add_theme_stylebox_override("normal", _button_style(Color("#ffe46c") if focused else (Color("#ffd84a") if active else Color("#c8ced8"))))

	for i in range(_camera_buttons.size()):
		var button := _camera_buttons[i]
		var active := _camera_button_modes[i] == _camera_mode
		var focused := _nav_row == 1 and i == _camera_focus_index
		button.add_theme_stylebox_override("normal", _button_style(Color("#ffe46c") if focused else (Color("#ffd84a") if active else Color("#c8ced8"))))

	if _back_button != null:
		_back_button.add_theme_color_override("font_color", Color("#ffd84a") if _nav_row == _max_nav_row() else Color("#8fd4ef"))


func _max_nav_row() -> int:
	return 2 if _active_tab == "camera" else 1


func _mark_input_handled() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _is_menu_up(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_up") or event.is_action_pressed("menu_up")


func _is_menu_down(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_down") or event.is_action_pressed("menu_down")


func _is_menu_left(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_left") or event.is_action_pressed("menu_left")


func _is_menu_right(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_right") or event.is_action_pressed("menu_right")


func _is_menu_accept(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_accept") or event.is_action_pressed("menu_accept")
