extends Node3D

const MAIN_MENU_SCENE := "res://scenes/MainMenu.tscn"
const SPECIAL_SCRIPT := preload("res://scripts/special.gd")
const CHARACTER_NAMES := ["Akanee", "Kaito", "Jade", "Panya", "Wayoo", "Jekkie", "Roxy", "Cherri"]

const COURT_WIDTH := 13.5
const COURT_DEPTH := 26.0
const NET_HEIGHT := 2.35
const GRAVITY := -20.0
const PLAYER_GROUND_Y := 0.0
const BALL_GROUND_Y := 0.35
const COUNTDOWN_DURATION := 3.4
const HIT_RADIUS := 0.92
const HIT_HEIGHT := 1.85
const AUTO_COUNTER_RADIUS := 0.86
const AUTO_COUNTER_HEIGHT := 2.55
const AUTO_COUNTER_MAX_Y_VELOCITY := 0.55
const HIT_CHARGE_MAX := 0.9
const HIT_CHARGE_MIN_MULTIPLIER := 0.65
const HIT_CHARGE_MAX_MULTIPLIER := 1.75
const SPIKE_BASE_SPEED := 10.5
const SPIKE_MAX_SPEED := 24.0
const SPIKE_NET_CLEARANCE := 0.55

var _p1_char := 0
var _p2_char := 1
var _win_points := 21
var _ai_level := "normal"
var _match_type := "assistant"

var _p1: Node3D
var _p2: Node3D
var _p1_assist: Node3D
var _p2_assist: Node3D
var _p1_anim: AnimationPlayer
var _p2_anim: AnimationPlayer
var _p1_assist_anim: AnimationPlayer
var _p2_assist_anim: AnimationPlayer
var _ball: MeshInstance3D
var _landing_target: MeshInstance3D
var _ball_velocity := Vector3(0.0, 6.0, -8.0)
var _p1_y_velocity := 0.0
var _p2_y_velocity := 0.0
var _p1_grounded := true
var _p2_grounded := true
var _p1_hit_lock := 0.0
var _p2_hit_lock := 0.0
var _p1_assist_hit_lock := 0.0
var _p2_assist_hit_lock := 0.0
var _p1_slide_timer := 0.0
var _p1_hit_charging := false
var _p1_hit_charge_time := 0.0
var _ai_decision_timer := 0.0
var _ai_target_error := Vector3.ZERO
var _ai_hit_attempt_timer := 0.0
var _assistant_decision_timer := 0.0
var _assistant_target_error := Vector3.ZERO
var _assistant_hit_attempt_timer := 0.0
var _special_timer := 0.0
var _special_cooldown := 0.0
var _serve_power := 0.0
var _serve_charging := false
var _serve_target := Vector3.ZERO
var _special_label: Label
var _hud_label: Label
var _score_label: Label
var _score_p1_label: Label
var _score_p2_label: Label
var _countdown_label: Label
var _serve_ui: Control
var _serve_bar: ProgressBar
var _serve_prompt: Label
var _pause_overlay: Control
var _pause_resume_button: Button
var _ball_material: StandardMaterial3D
var _water_material: StandardMaterial3D
var _water_uv_offset := Vector3.ZERO
var _hit_effects: Array[Node3D] = []
var _ball_trail_effects: Array[MeshInstance3D] = []
var _ball_trail_timer := 0.0
var _score_p1 := 0
var _score_p2 := 0
var _phase := "countdown"
var _countdown_timer := COUNTDOWN_DURATION
var _serving_team := 1
var _is_paused := false


func _ready() -> void:
	_read_match_setup()
	_add_default_inputs()
	_build_scene()
	_build_hud()


func _physics_process(delta: float) -> void:
	if _is_paused:
		return
	_update_water_texture(delta)
	_update_hit_effects(delta)
	_update_ball_trail(delta)
	_update_countdown(delta)
	if _phase == "serve":
		_update_player(delta)
		_update_ai(delta)
		_update_assistants(delta)
		_update_serve(delta)
		_update_special(delta)
		_update_camera(delta)
		return
	if _phase != "playing":
		_update_camera(delta)
		return

	_update_player(delta)
	_update_ai(delta)
	_update_assistants(delta)
	_update_ball(delta)
	_update_special(delta)
	_update_camera(delta)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_set_paused(not _is_paused)
		get_viewport().set_input_as_handled()
		return
	if _is_paused:
		return
	if event.is_action_pressed("p1_jump"):
		if _phase == "serve" and _serving_team == 1:
			_serve_charging = true
		elif _phase == "playing":
			_jump_player(_p1, true)
	elif event.is_action_released("p1_jump"):
		if _phase == "serve" and _serving_team == 1 and _serve_charging:
			_release_serve()
	elif event.is_action_pressed("p1_hit"):
		if _phase == "serve" and _serving_team == 1:
			if not _serve_charging:
				_serve_power = 0.65
			_release_serve()
		elif _phase == "playing":
			_begin_player_hit_charge()
	elif event.is_action_released("p1_hit"):
		if _phase == "playing" and _p1_hit_charging:
			_release_player_hit_charge()
	elif event.is_action_pressed("p1_slide"):
		_p1_slide_timer = 0.24
	elif event.is_action_pressed("p1_special"):
		_trigger_special()


func _read_match_setup() -> void:
	_p1_char = int(get_tree().get_meta("player1_char", 0))
	_p2_char = int(get_tree().get_meta("player2_char", 1))
	_win_points = int(get_tree().get_meta("win_points", 21))
	_ai_level = str(get_tree().get_meta("ai_level", "normal"))
	_match_type = str(get_tree().get_meta("match_type", "assistant"))


func _assistant_character(base_char: int, offset: int) -> int:
	return wrapi(base_char + offset, 0, CHARACTER_NAMES.size())


func _build_scene() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#8ee8ff")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#fff7d6")
	env.ambient_light_energy = 0.76
	env.fog_enabled = false
	env.tonemap_exposure = 0.82
	world.environment = env
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.light_energy = 0.58
	sun.light_color = Color("#fff0c8")
	sun.position = Vector3(10, 20, 10)
	sun.rotation_degrees = Vector3(-50, 38, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 32.0
	add_child(sun)

	var ambient := OmniLight3D.new()
	ambient.light_energy = 0.34
	ambient.omni_range = 45
	ambient.position = Vector3(0, 12, 0)
	add_child(ambient)

	_add_ground()
	_add_court()
	_add_net()
	_add_scenery()
	_add_crowd()

	_p1 = _spawn_character(_p1_char, Vector3(0, 0, 7.0), PI)
	_p2 = _spawn_character(_p2_char, Vector3(0, 0, -7.0), 0.0)
	if _match_type == "assistant":
		_p1_assist = _spawn_character(_assistant_character(_p1_char, 2), Vector3(3.0, 0, 8.8), PI)
		_p2_assist = _spawn_character(_assistant_character(_p2_char, 3), Vector3(-3.0, 0, -8.8), 0.0)
	_p1_anim = _find_animation_player(_p1)
	_p2_anim = _find_animation_player(_p2)
	_p1_assist_anim = _find_animation_player(_p1_assist) if _p1_assist != null else null
	_p2_assist_anim = _find_animation_player(_p2_assist) if _p2_assist != null else null
	_play_actor_animation(_p1_anim, "idle")
	_play_actor_animation(_p2_anim, "idle")
	_play_actor_animation(_p1_assist_anim, "idle")
	_play_actor_animation(_p2_assist_anim, "idle")
	_ball = _spawn_ball(Vector3(0.3, 4.0, 2.0))
	_serve_target = _make_serve_target(_serving_team)
	_landing_target = _spawn_landing_target()

	var camera := Camera3D.new()
	camera.name = "GameplayCamera"
	camera.fov = 45
	camera.position = Vector3(17.8, 9.4, 0.0)
	camera.look_at(Vector3(0.4, 0.72, 0.0), Vector3.UP)
	add_child(camera)
	camera.current = true


func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	_hud_label = Label.new()
	var match_label := "2 VS 2 ASSIST" if _match_type == "assistant" else "1 VS 1 DUEL"
	_build_team_hud(canvas, true, "TEAM 1", CHARACTER_NAMES[_p1_char], Color("#ff5b65"))
	_build_team_hud(canvas, false, "TEAM 2", "AI %s" % CHARACTER_NAMES[_p2_char], Color("#4f93ff"))

	_hud_label.text = "%s  |  %s  |  %s POINTS" % [
		match_label,
		_ai_level.to_upper(),
		_win_points,
	]
	_hud_label.add_theme_font_override("font", preload("res://fonts/upheavtt.ttf"))
	_hud_label.add_theme_font_size_override("font_size", 24)
	_hud_label.add_theme_color_override("font_color", Color.WHITE)
	_hud_label.add_theme_color_override("font_outline_color", Color("#f06969"))
	_hud_label.add_theme_constant_override("outline_size", 5)
	_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_hud_label.offset_top = 72
	canvas.add_child(_hud_label)

	_score_label = Label.new()
	_score_label.text = ":"
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.add_theme_font_override("font", preload("res://fonts/upheavtt.ttf"))
	_score_label.add_theme_font_size_override("font_size", 50)
	_score_label.add_theme_color_override("font_color", Color("#ffd84a"))
	_score_label.add_theme_color_override("font_outline_color", Color("#1f5fbf"))
	_score_label.add_theme_constant_override("outline_size", 8)
	_score_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_score_label.offset_top = 12
	canvas.add_child(_score_label)

	_score_p1_label = _score_number_label(Color("#ff5b65"), Color("#7e1f25"))
	_score_p1_label.text = "0"
	_score_p1_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_score_p1_label.offset_top = 18
	_score_p1_label.offset_left = -118
	_score_p1_label.offset_right = -118
	canvas.add_child(_score_p1_label)

	_score_p2_label = _score_number_label(Color("#4f93ff"), Color("#123d8f"))
	_score_p2_label.text = "0"
	_score_p2_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_score_p2_label.offset_top = 18
	_score_p2_label.offset_left = 118
	_score_p2_label.offset_right = 118
	canvas.add_child(_score_p2_label)

	_special_label = Label.new()
	_special_label.text = ""
	_special_label.visible = false
	_special_label.add_theme_font_override("font", preload("res://fonts/upheavtt.ttf"))
	_special_label.add_theme_font_size_override("font_size", 24)
	_special_label.add_theme_color_override("font_color", Color("#ffd84a"))
	_special_label.add_theme_color_override("font_outline_color", Color("#7c3200"))
	_special_label.add_theme_constant_override("outline_size", 5)
	_special_label.position = Vector2(24, 56)
	canvas.add_child(_special_label)

	_countdown_label = Label.new()
	_countdown_label.text = "3"
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_countdown_label.add_theme_font_override("font", preload("res://fonts/upheavtt.ttf"))
	_countdown_label.add_theme_font_size_override("font_size", 96)
	_countdown_label.add_theme_color_override("font_color", Color("#ffd84a"))
	_countdown_label.add_theme_color_override("font_outline_color", Color("#c4657e"))
	_countdown_label.add_theme_constant_override("outline_size", 10)
	_countdown_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(_countdown_label)

	_build_serve_ui(canvas)
	_build_side_portraits(canvas)
	_build_control_guide(canvas)
	_build_pause_overlay(canvas)


func _build_team_hud(canvas: CanvasLayer, left_side: bool, title: String, player_name: String, color: Color) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 58)
	if left_side:
		panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		panel.offset_left = 20
		panel.offset_right = 340
	else:
		panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		panel.offset_left = -340
		panel.offset_right = -20
	panel.offset_top = 12
	panel.offset_bottom = 70

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.38)
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	panel.add_theme_stylebox_override("panel", style)
	canvas.add_child(panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	panel.add_child(box)

	var title_label := _small_hud_label(title)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.add_theme_color_override("font_color", color)
	box.add_child(title_label)

	var name_label := _small_hud_label(player_name.to_upper())
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 22)
	box.add_child(name_label)


func _build_serve_ui(canvas: CanvasLayer) -> void:
	_serve_ui = Control.new()
	_serve_ui.visible = false
	_serve_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(_serve_ui)

	var title := Label.new()
	title.text = "SERVE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", preload("res://fonts/upheavtt.ttf"))
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color("#ffd200"))
	title.add_theme_color_override("font_outline_color", Color("#9b257c"))
	title.add_theme_constant_override("outline_size", 8)
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title.offset_top = 170
	title.offset_left = -320
	title.offset_right = 320
	_serve_ui.add_child(title)

	var shell := PanelContainer.new()
	shell.custom_minimum_size = Vector2(640, 58)
	shell.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	shell.offset_left = -320
	shell.offset_right = 320
	shell.offset_top = -10
	shell.offset_bottom = 48
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.16, 0.15, 0.72)
	style.border_color = Color("#58ffe0")
	style.set_border_width_all(2)
	style.set_corner_radius_all(28)
	shell.add_theme_stylebox_override("panel", style)
	_serve_ui.add_child(shell)

	_serve_bar = ProgressBar.new()
	_serve_bar.min_value = 0.0
	_serve_bar.max_value = 1.0
	_serve_bar.value = 0.0
	_serve_bar.show_percentage = false
	_serve_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color("#4dffd8")
	bar_fill.set_corner_radius_all(24)
	_serve_bar.add_theme_stylebox_override("background", bar_bg)
	_serve_bar.add_theme_stylebox_override("fill", bar_fill)
	shell.add_child(_serve_bar)

	_serve_prompt = Label.new()
	_serve_prompt.text = "HOLD JUMP, RELEASE TO SERVE"
	_serve_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_serve_prompt.add_theme_font_override("font", preload("res://fonts/upheavtt.ttf"))
	_serve_prompt.add_theme_font_size_override("font_size", 26)
	_serve_prompt.add_theme_color_override("font_color", Color.WHITE)
	_serve_prompt.add_theme_color_override("font_outline_color", Color("#9b257c"))
	_serve_prompt.add_theme_constant_override("outline_size", 6)
	_serve_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_serve_prompt.offset_left = -360
	_serve_prompt.offset_right = 360
	_serve_prompt.offset_top = 56
	_serve_prompt.offset_bottom = 100
	_serve_ui.add_child(_serve_prompt)


func _build_pause_overlay(canvas: CanvasLayer) -> void:
	_pause_overlay = Control.new()
	_pause_overlay.visible = false
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(_pause_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.58)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(430, 300)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.03, 0.13, 0.2, 0.92)
	panel_style.border_color = Color("#ffd84a")
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 36
	panel_style.content_margin_right = 36
	panel_style.content_margin_top = 28
	panel_style.content_margin_bottom = 32
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var menu := VBoxContainer.new()
	menu.alignment = BoxContainer.ALIGNMENT_CENTER
	menu.add_theme_constant_override("separation", 18)
	panel.add_child(menu)

	var title := Label.new()
	title.text = "PAUSE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", preload("res://fonts/upheavtt.ttf"))
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color("#ffd84a"))
	title.add_theme_color_override("font_outline_color", Color("#9b257c"))
	title.add_theme_constant_override("outline_size", 8)
	menu.add_child(title)

	_pause_resume_button = _pause_menu_button("RESUME")
	_pause_resume_button.pressed.connect(func() -> void: _set_paused(false))
	menu.add_child(_pause_resume_button)

	var new_game := _pause_menu_button("NEW GAME")
	new_game.pressed.connect(_restart_match)
	menu.add_child(new_game)


func _pause_menu_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(300, 48)
	button.add_theme_font_override("font", preload("res://fonts/upheavtt.ttf"))
	button.add_theme_font_size_override("font_size", 30)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color("#ffd84a"))
	button.add_theme_color_override("font_focus_color", Color("#ffd84a"))
	button.add_theme_color_override("font_pressed_color", Color("#ffffff"))
	button.add_theme_color_override("font_outline_color", Color("#1f5fbf"))
	button.add_theme_constant_override("outline_size", 6)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.28, 0.4, 0.86)
	normal.border_color = Color("#58ffe0")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)
	button.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.16, 0.38, 0.52, 0.96)
	hover.border_color = Color("#ffd84a")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.04, 0.2, 0.31, 0.96)
	button.add_theme_stylebox_override("pressed", pressed)
	return button


func _set_paused(value: bool) -> void:
	_is_paused = value
	_serve_charging = false
	_p1_hit_charging = false
	_p1_hit_charge_time = 0.0
	if _pause_overlay != null:
		_pause_overlay.visible = _is_paused
	if _is_paused and _pause_resume_button != null:
		_pause_resume_button.grab_focus()


func _restart_match() -> void:
	_set_paused(false)
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _build_side_portraits(canvas: CanvasLayer) -> void:
	_add_arena_portrait(canvas, _p1_char, true)
	_add_arena_portrait(canvas, _p2_char, false)


func _add_arena_portrait(canvas: CanvasLayer, char_id: int, left_side: bool) -> void:
	var portrait := TextureRect.new()
	portrait.texture = load("res://arena/%d.png" % (char_id + 1))
	portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.modulate = Color(1, 1, 1, 0.78)
	portrait.custom_minimum_size = Vector2(250, 260)
	if left_side:
		portrait.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		portrait.offset_left = -24
		portrait.offset_right = 250
		portrait.flip_h = true
	else:
		portrait.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		portrait.offset_left = -250
		portrait.offset_right = 24
		portrait.flip_h = false
	portrait.offset_top = -265
	portrait.offset_bottom = 8
	canvas.add_child(portrait)


func _build_control_guide(canvas: CanvasLayer) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(184, 158)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = 22
	panel.offset_right = 206
	panel.offset_top = -384
	panel.offset_bottom = -226
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.34)
	style.border_color = Color(1.0, 1.0, 1.0, 0.12)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	canvas.add_child(panel)

	var text := _small_hud_label("W/S UP-DOWN\nA/D LEFT-RIGHT\nARROWS / STICK MOVE\nI JUMP\nO HIT\nP SLIDE\nL SPECIAL\nESC PAUSE")
	text.add_theme_font_size_override("font_size", 12)
	panel.add_child(text)


func _add_ground() -> void:
	var sand := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(96, 82)
	sand.mesh = mesh
	sand.position = Vector3(0, -0.1, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = preload("res://images/sea.jpg")
	mat.albedo_color = Color("#d9b56d")
	mat.roughness = 1.0
	sand.material_override = mat
	add_child(sand)

	var water := MeshInstance3D.new()
	var water_mesh := PlaneMesh.new()
	water_mesh.size = Vector2(120, 170)
	water.mesh = water_mesh
	water.position = Vector3(-42, -0.18, 0)
	_water_material = StandardMaterial3D.new()
	_water_material.albedo_texture = preload("res://images/water.jpg")
	_water_material.albedo_color = Color("#36a9d5")
	_water_material.roughness = 0.82
	_water_material.texture_repeat = 1
	_water_material.uv1_scale = Vector3(4.0, 6.5, 1.0)
	water.material_override = _water_material
	add_child(water)


func _add_court() -> void:
	var court := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(COURT_WIDTH, COURT_DEPTH)
	court.mesh = mesh
	court.position = Vector3(0, 0.03, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = preload("res://images/groundV.png")
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.82, 0.68, 0.36, 0.88)
	court.material_override = mat
	add_child(court)

	var center_line := MeshInstance3D.new()
	var line_mesh := BoxMesh.new()
	line_mesh.size = Vector3(COURT_WIDTH, 0.025, 0.07)
	center_line.mesh = line_mesh
	center_line.position = Vector3(0, 0.07, 0)
	var line_mat := StandardMaterial3D.new()
	line_mat.albedo_color = Color("#dec878")
	center_line.material_override = line_mat
	add_child(center_line)


func _add_net() -> void:
	var net_scene := load("res://levels/volleyball_net.glb") as PackedScene
	if net_scene == null:
		return
	var net := net_scene.instantiate() as Node3D
	net.position = Vector3(0, -3, 0)
	net.scale = Vector3(0.2, 0.2, 0.2)
	add_child(net)


func _add_scenery() -> void:
	for i in range(12):
		var tree_id := (i % 3) + 1
		var tree_scene := load("res://levels/tree%d.glb" % tree_id) as PackedScene
		if tree_scene == null:
			continue
		var tree := tree_scene.instantiate() as Node3D
		var row := -20.0 if i % 2 == 0 else 20.0
		var x := -20.0 + float(i % 6) * 8.0
		tree.position = Vector3(x, 0, row)
		tree.rotation.y = randf_range(-0.8, 0.8)
		tree.scale = Vector3.ONE * randf_range(1.0, 1.45)
		add_child(tree)


func _add_crowd() -> void:
	for i in range(28):
		var sprite := Sprite3D.new()
		var texture := load("res://images/people%d.png" % ((i % 2) + 1)) as Texture2D
		sprite.texture = texture
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.pixel_size = 0.0075
		sprite.modulate = Color(1, 1, 1, 0.84)
		var lane := -1.0 if i < 14 else 1.0
		var row_index := i % 14
		var crowd_scale := randf_range(0.72, 0.96)
		var texture_height := float(texture.get_height()) if texture != null else 128.0
		sprite.position = Vector3(
			-16.0 + row_index * 2.45,
			texture_height * sprite.pixel_size * crowd_scale * 0.5,
			lane * randf_range(17.0, 22.5)
		)
		sprite.rotation_degrees.y = 180.0 if lane > 0.0 else 0.0
		sprite.scale = Vector3.ONE * crowd_scale
		add_child(sprite)


func _spawn_character(char_id: int, pos: Vector3, rotation_y: float) -> Node3D:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = rotation_y
	add_child(holder)

	var scene := load("res://characters/%d.glb" % (char_id + 1)) as PackedScene
	if scene != null:
		var model := scene.instantiate() as Node3D
		model.scale = Vector3.ONE * 1.7
		model.position = Vector3(0, 0, 0)
		holder.add_child(model)
		_soften_character_shadows(model)

	var ring := MeshInstance3D.new()
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 1.0
	ring_mesh.bottom_radius = 1.0
	ring_mesh.height = 0.025
	ring_mesh.radial_segments = 64
	ring.mesh = ring_mesh
	ring.position.y = 0.025
	var mat := StandardMaterial3D.new()
	mat.albedo_color = SPECIAL_SCRIPT.ball_color(char_id)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var ring_color := mat.albedo_color
	ring_color.a = 0.34
	mat.albedo_color = ring_color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = mat
	holder.add_child(ring)
	return holder


func _soften_character_shadows(root: Node) -> void:
	if root is GeometryInstance3D:
		var geometry := root as GeometryInstance3D
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for child in root.get_children():
		_soften_character_shadows(child)


func _spawn_ball(pos: Vector3) -> MeshInstance3D:
	var ball := MeshInstance3D.new()
	ball.name = "volleyball"
	var mesh := SphereMesh.new()
	mesh.radius = 0.3
	mesh.height = 0.6
	ball.mesh = mesh
	ball.position = pos
	_ball_material = StandardMaterial3D.new()
	_ball_material.albedo_texture = preload("res://images/volley.jpg")
	_ball_material.albedo_color = Color.WHITE
	ball.material_override = _ball_material
	add_child(ball)
	return ball


func _spawn_landing_target() -> MeshInstance3D:
	var target := MeshInstance3D.new()
	target.name = "LandingTarget"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.55
	mesh.bottom_radius = 0.55
	mesh.height = 0.035
	mesh.radial_segments = 48
	target.mesh = mesh
	target.position = Vector3(0, 0.11, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 1.0, 0.85, 0.52)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color("#3fffe1")
	mat.emission_energy_multiplier = 0.55
	target.material_override = mat
	target.visible = false
	add_child(target)
	return target


func _update_player(delta: float) -> void:
	_p1_hit_lock = maxf(0.0, _p1_hit_lock - delta)
	_p1_slide_timer = maxf(0.0, _p1_slide_timer - delta)
	if _p1_hit_charging:
		_p1_hit_charge_time = minf(HIT_CHARGE_MAX, _p1_hit_charge_time + delta)
	_update_vertical_motion(_p1, true, delta)

	var move := Vector3.ZERO
	if Input.is_action_pressed("p1_left"):
		move.z += 1.0
	if Input.is_action_pressed("p1_right"):
		move.z -= 1.0
	if Input.is_action_pressed("p1_up"):
		move.x -= 1.0
	if Input.is_action_pressed("p1_down"):
		move.x += 1.0
	if move.length() > 0.0:
		move = move.normalized()
	var speed := 12.5 if _p1_slide_timer > 0.0 else 7.5
	_p1.position += move * speed * delta
	_p1.position.x = clampf(_p1.position.x, -COURT_WIDTH * 0.5 + 0.6, COURT_WIDTH * 0.5 - 0.6)
	_p1.position.z = clampf(_p1.position.z, 0.6, COURT_DEPTH * 0.5 - 0.8)
	if _p1_hit_lock > 0.0:
		_play_actor_animation(_p1_anim, "hit")
	elif not _p1_grounded:
		_play_actor_animation(_p1_anim, "jump")
	elif _p1_slide_timer > 0.0:
		_play_actor_animation(_p1_anim, "jog")
	elif move.length() > 0.0:
		_play_actor_animation(_p1_anim, "run")
	else:
		_play_actor_animation(_p1_anim, "idle")


func _update_ai(delta: float) -> void:
	_p2_hit_lock = maxf(0.0, _p2_hit_lock - delta)
	_ai_decision_timer = maxf(0.0, _ai_decision_timer - delta)
	_ai_hit_attempt_timer = maxf(0.0, _ai_hit_attempt_timer - delta)
	_update_vertical_motion(_p2, false, delta)
	var target := _get_ai_move_target()
	var speed := _ai_move_speed()
	_p2.position = _p2.position.move_toward(target, speed * delta)
	_p2.position.x = clampf(_p2.position.x, -COURT_WIDTH * 0.5 + 0.6, COURT_WIDTH * 0.5 - 0.6)
	_p2.position.z = clampf(_p2.position.z, -COURT_DEPTH * 0.5 + 0.8, -0.6)
	if _should_ai_jump():
		_jump_player(_p2, false)
	if _should_ai_counter():
		_hit_ball_from(_p2, 1.0, false, _ai_charge_ratio())
	if _p2_hit_lock > 0.0:
		_play_actor_animation(_p2_anim, "hit")
	elif not _p2_grounded:
		_play_actor_animation(_p2_anim, "jump")
	elif _p2.position.distance_to(target) > 0.08:
		_play_actor_animation(_p2_anim, "run")
	else:
		_play_actor_animation(_p2_anim, "idle")


func _update_assistants(delta: float) -> void:
	if _match_type != "assistant":
		return
	_p1_assist_hit_lock = maxf(0.0, _p1_assist_hit_lock - delta)
	_p2_assist_hit_lock = maxf(0.0, _p2_assist_hit_lock - delta)
	_assistant_decision_timer = maxf(0.0, _assistant_decision_timer - delta)
	_assistant_hit_attempt_timer = maxf(0.0, _assistant_hit_attempt_timer - delta)
	_update_assistant(_p1_assist, _p1, _p1_assist_anim, 1.0, -1.0, delta)
	_update_assistant(_p2_assist, _p2, _p2_assist_anim, -1.0, 1.0, delta)


func _update_assistant(assistant: Node3D, teammate: Node3D, anim: AnimationPlayer, team_side: float, side_dir: float, delta: float) -> void:
	if assistant == null:
		return
	var target := _get_assistant_target(assistant, teammate, team_side)
	var speed := _assistant_move_speed()
	assistant.position = assistant.position.move_toward(target, speed * delta)
	assistant.position.x = clampf(assistant.position.x, -COURT_WIDTH * 0.5 + 0.6, COURT_WIDTH * 0.5 - 0.6)
	if team_side > 0.0:
		assistant.position.z = clampf(assistant.position.z, 0.8, COURT_DEPTH * 0.5 - 0.8)
	else:
		assistant.position.z = clampf(assistant.position.z, -COURT_DEPTH * 0.5 + 0.8, -0.8)

	if _should_assistant_counter(assistant, teammate, team_side):
		_hit_ball_from(assistant, side_dir, false, _assistant_charge_ratio())
	if _is_hit_locked(assistant):
		_play_actor_animation(anim, "hit")
	elif assistant.position.distance_to(target) > 0.08:
		_play_actor_animation(anim, "run")
	else:
		_play_actor_animation(anim, "idle")


func _get_assistant_target(assistant: Node3D, teammate: Node3D, team_side: float) -> Vector3:
	var home := Vector3(3.0, PLAYER_GROUND_Y, 8.8)
	if team_side < 0.0:
		home = Vector3(-3.0, PLAYER_GROUND_Y, -8.8)
	var target := home
	var landing: Variant = _predict_ball_landing()
	var ball_incoming := _ball_velocity.z * team_side > 0.0
	if landing != null and ball_incoming:
		var landing_pos: Vector3 = landing
		if landing_pos.z * team_side > 0.0:
			var assistant_xz := Vector2(assistant.position.x, assistant.position.z)
			var teammate_xz := Vector2(teammate.position.x, teammate.position.z)
			var landing_xz := Vector2(landing_pos.x, landing_pos.z)
			if assistant_xz.distance_to(landing_xz) <= teammate_xz.distance_to(landing_xz) + 1.2:
				target = Vector3(landing_pos.x, PLAYER_GROUND_Y, landing_pos.z)
	if _assistant_decision_timer <= 0.0:
		_assistant_decision_timer = _ai_decision_interval() * 1.2
		_assistant_target_error = _ai_target_noise() * 0.85
	target += _assistant_target_error
	target.x = clampf(target.x, -COURT_WIDTH * 0.5 + 0.75, COURT_WIDTH * 0.5 - 0.75)
	if team_side > 0.0:
		target.z = clampf(target.z, 0.8, COURT_DEPTH * 0.5 - 0.8)
	else:
		target.z = clampf(target.z, -COURT_DEPTH * 0.5 + 0.8, -0.8)
	return target


func _should_assistant_counter(assistant: Node3D, teammate: Node3D, team_side: float) -> bool:
	if _phase != "playing":
		return false
	if _is_hit_locked(assistant):
		return false
	if _ball_velocity.z * team_side <= 0.0:
		return false
	if assistant.position.z * team_side <= 0.0:
		return false
	if not _can_hit(assistant):
		return false
	if _assistant_hit_attempt_timer > 0.0:
		return false
	var assistant_xz := Vector2(assistant.position.x, assistant.position.z)
	var teammate_xz := Vector2(teammate.position.x, teammate.position.z)
	var ball_xz := Vector2(_ball.position.x, _ball.position.z)
	var best_position := assistant_xz.distance_to(ball_xz) <= teammate_xz.distance_to(ball_xz) + 0.45
	if not best_position or _ball_velocity.y >= _ai_hit_height_limit():
		return false
	if randf() > _assistant_hit_chance():
		_assistant_hit_attempt_timer = _ai_miss_recovery_time()
		return false
	return true


func _get_ai_move_target() -> Vector3:
	var target := Vector3(_ball.position.x, PLAYER_GROUND_Y, clampf(_ball.position.z, -COURT_DEPTH * 0.5 + 0.8, -0.6))
	var landing: Variant = _predict_ball_landing()
	if landing != null and _ball_velocity.z < 0.0:
		var landing_pos: Vector3 = landing
		target.x = landing_pos.x
		target.z = landing_pos.z
	elif _ball_velocity.z >= 0.0:
		target.z = -7.0

	target.x += clampf(_ball_velocity.x * _ai_anticipation(), -1.4, 1.4)
	if _ai_decision_timer <= 0.0:
		_ai_decision_timer = _ai_decision_interval()
		_ai_target_error = _ai_target_noise()
	target += _ai_target_error
	target.x = clampf(target.x, -COURT_WIDTH * 0.5 + 0.75, COURT_WIDTH * 0.5 - 0.75)
	target.z = clampf(target.z, -COURT_DEPTH * 0.5 + 0.8, -0.6)
	return target


func _should_ai_counter() -> bool:
	if _p2_hit_lock > 0.0:
		return false
	if _ball_velocity.z >= 0.0:
		return false
	if not _can_hit(_p2) or _ball_velocity.y >= _ai_hit_height_limit():
		return false
	if _ai_hit_attempt_timer > 0.0:
		return false
	if randf() > _ai_hit_chance():
		_ai_hit_attempt_timer = _ai_miss_recovery_time()
		return false
	return true


func _should_ai_jump() -> bool:
	if _p2_hit_lock > 0.0 or not _p2_grounded or _ball_velocity.z >= 0.0:
		return false
	if _ball.position.y < 2.2 or _ball.position.y > 4.0:
		return false
	var p2_xz := Vector2(_p2.position.x, _p2.position.z)
	var ball_xz := Vector2(_ball.position.x, _ball.position.z)
	if p2_xz.distance_to(ball_xz) > HIT_RADIUS + 0.36:
		return false
	return randf() <= _ai_jump_chance()


func _update_ball(delta: float) -> void:
	_ball_velocity.y += GRAVITY * delta
	_ball.position += _ball_velocity * delta
	_ball.rotate_x(_ball_velocity.z * delta * 0.2)
	_ball.rotate_z(-_ball_velocity.x * delta * 0.2)

	if _p1_hit_charging and _can_hit(_p1):
		_release_player_hit_charge()
		_update_landing_target()
		return

	if _try_jump_block(_p1, -1.0) or _try_jump_block(_p2, 1.0):
		_update_landing_target()
		return

	if _try_auto_counter(_p1, -1.0) or _try_auto_counter(_p2, 1.0):
		_update_landing_target()
		return

	if _ball.position.y < BALL_GROUND_Y:
		_award_point(2 if _ball.position.z > 0.0 else 1)
		return
	if abs(_ball.position.x) > COURT_WIDTH * 0.5:
		_ball_velocity.x *= -0.85
	if abs(_ball.position.z) > COURT_DEPTH * 0.5:
		_ball_velocity.z *= -0.85
	if abs(_ball.position.z) < 0.35 and _ball.position.y < NET_HEIGHT:
		_ball_velocity.z *= -1.0
		_ball_velocity.y = maxf(_ball_velocity.y, 2.4)

	if _phase == "playing" and abs(_ball.position.z) > COURT_DEPTH * 0.5:
		_award_point(1 if _ball.position.z < 0.0 else 2)
		return
	_update_landing_target()


func _hit_ball(use_special: bool, charge_ratio: float = 0.0) -> void:
	if not _can_hit(_p1):
		return
	_hit_ball_from(_p1, -1.0, use_special, charge_ratio)


func _begin_player_hit_charge() -> void:
	_p1_hit_charging = true
	_p1_hit_charge_time = 0.0


func _release_player_hit_charge() -> void:
	var charge_ratio := clampf(_p1_hit_charge_time / HIT_CHARGE_MAX, 0.0, 1.0)
	_p1_hit_charging = false
	_p1_hit_charge_time = 0.0
	_hit_ball(false, charge_ratio)


func _can_hit(player: Node3D) -> bool:
	var player_xz := Vector2(player.position.x, player.position.z)
	var ball_xz := Vector2(_ball.position.x, _ball.position.z)
	var vertical_ok := absf(_ball.position.y - (player.position.y + 1.2)) <= HIT_HEIGHT
	return player_xz.distance_to(ball_xz) <= HIT_RADIUS and vertical_ok


func _try_auto_counter(player: Node3D, side_dir: float) -> bool:
	if player == null or _ball == null:
		return false
	if _is_player_airborne(player):
		return false
	if _ball_velocity.y > AUTO_COUNTER_MAX_Y_VELOCITY:
		return false
	if side_dir < 0.0 and _ball.position.z < -0.35:
		return false
	if side_dir > 0.0 and _ball.position.z > 0.35:
		return false
	if _is_hit_locked(player):
		return false

	var landing: Variant = _predict_ball_landing()
	if landing == null:
		return false
	var landing_pos: Vector3 = landing
	var player_xz := Vector2(player.position.x, player.position.z)
	var landing_xz := Vector2(landing_pos.x, landing_pos.z)
	if player_xz.distance_to(landing_xz) > AUTO_COUNTER_RADIUS:
		return false
	if _ball.position.y > player.position.y + AUTO_COUNTER_HEIGHT and not _can_hit(player):
		return false

	_hit_ball_from(player, side_dir, false)
	return true


func _try_jump_block(player: Node3D, side_dir: float) -> bool:
	if player == null or _ball == null:
		return false
	if player == _p1 and _p1_hit_charging:
		return false
	if not _is_player_airborne(player):
		return false
	if _is_hit_locked(player):
		return false
	if _ball_velocity.z * side_dir >= 0.0:
		return false
	if not _can_hit(player):
		return false

	var target := _pick_safe_landing_target(player, side_dir)
	_ball_velocity = _velocity_to_land_at(_ball.position, target, 10.8)
	_ball_velocity.y = maxf(_ball_velocity.y, 5.2)
	_set_hit_lock(player, 0.16)
	_spawn_hit_effect(_ball.position, "HIT!")
	return true


func _hit_ball_from(player: Node3D, side_dir: float, use_special: bool, charge_ratio: float = -1.0) -> void:
	var target := _pick_safe_landing_target(player, side_dir)
	var charge_multiplier := 1.0
	if not use_special and charge_ratio >= 0.0:
		charge_multiplier = lerpf(HIT_CHARGE_MIN_MULTIPLIER, HIT_CHARGE_MAX_MULTIPLIER, clampf(charge_ratio, 0.0, 1.0))
	if _is_player_airborne(player) and not use_special:
		target = _pick_spike_landing_target(player, side_dir)
		_ball_velocity = _spike_velocity(player, target, charge_ratio)
	else:
		var arc_speed := SPECIAL_SCRIPT.arc_speed(_p1_char) if use_special else 12.8
		_ball_velocity = _velocity_to_land_at(_ball.position, target, arc_speed)
		_ball_velocity *= charge_multiplier
	_set_hit_lock(player, 0.22)
	var effect_text := "SMASH!" if _is_player_airborne(player) or use_special or charge_ratio > 0.7 else "HIT!"
	_spawn_hit_effect(_ball.position, effect_text)
	if use_special:
		_ball_velocity = SPECIAL_SCRIPT.apply_velocity(_p1_char, _ball_velocity, side_dir)
		_special_timer = 1.6
		_special_cooldown = 5.0
		_ball_material.emission_enabled = true
		_ball_material.emission = SPECIAL_SCRIPT.ball_color(_p1_char)
		_ball_material.albedo_color = SPECIAL_SCRIPT.ball_color(_p1_char)
		_ball_material.emission_energy_multiplier = 2.0
		_special_label.text = "%s - %s" % [CHARACTER_NAMES[_p1_char].to_upper(), SPECIAL_SCRIPT.move_name(_p1_char)]
		_special_label.visible = true


func _spike_velocity(player: Node3D, target: Vector3, charge_ratio: float) -> Vector3:
	var speed := lerpf(SPIKE_BASE_SPEED, SPIKE_MAX_SPEED, clampf(charge_ratio, 0.0, 1.0))
	var horizontal := Vector2(target.x - _ball.position.x, target.z - _ball.position.z)
	if horizontal.length() <= 0.01:
		horizontal = Vector2(0.0, -1.0 if player == _p1 else 1.0)
	var time := clampf(horizontal.length() / speed, 0.34, 0.92)
	var velocity := Vector3(horizontal.x / time, 0.0, horizontal.y / time)
	velocity.y = (target.y - _ball.position.y - 0.5 * GRAVITY * time * time) / time
	velocity.y = clampf(velocity.y, -speed * 0.7, speed * 0.28)

	var net_distance := absf(_ball.position.z)
	var forward_speed := absf(velocity.z)
	if forward_speed > 0.01 and net_distance > 0.0:
		var time_to_net := net_distance / forward_speed
		if time_to_net > 0.0 and time_to_net < time:
			var net_y := _ball.position.y + velocity.y * time_to_net + 0.5 * GRAVITY * time_to_net * time_to_net
			var minimum_net_y := NET_HEIGHT + SPIKE_NET_CLEARANCE
			if net_y < minimum_net_y:
				velocity.y += (minimum_net_y - net_y) / time_to_net
	return velocity


func _pick_spike_landing_target(player: Node3D, side_dir: float) -> Vector3:
	var own_side_depth := COURT_DEPTH * 0.25
	var deep_in_own_side := absf(player.position.z) > own_side_depth or absf(_ball.position.z) > own_side_depth
	var target_x := clampf(_ball.position.x + randf_range(-1.15, 1.15), -COURT_WIDTH * 0.5 + 1.0, COURT_WIDTH * 0.5 - 1.0)
	var target_z := side_dir * randf_range(2.4, 6.2)
	if deep_in_own_side:
		target_z = side_dir * randf_range(4.8, 9.2)
	return Vector3(target_x, BALL_GROUND_Y, target_z)


func _is_player_airborne(player: Node3D) -> bool:
	if player == _p1:
		return not _p1_grounded
	if player == _p2:
		return not _p2_grounded
	return false


func _ai_move_speed() -> float:
	if _ai_level == "hard":
		return 8.2
	if _ai_level == "easy":
		return 3.8
	return 5.6


func _assistant_move_speed() -> float:
	if _ai_level == "hard":
		return 6.2
	if _ai_level == "easy":
		return 3.2
	return 4.7


func _ai_anticipation() -> float:
	if _ai_level == "hard":
		return 0.95
	if _ai_level == "easy":
		return 0.22
	return 0.56


func _ai_decision_interval() -> float:
	if _ai_level == "hard":
		return 0.14
	if _ai_level == "easy":
		return 0.5
	return 0.28


func _ai_target_noise() -> Vector3:
	var amount := 0.42
	if _ai_level == "hard":
		amount = 0.12
	elif _ai_level == "easy":
		amount = 1.25
	return Vector3(randf_range(-amount, amount), 0.0, randf_range(-amount * 0.75, amount * 0.75))


func _ai_hit_chance() -> float:
	if _ai_level == "hard":
		return 0.96
	if _ai_level == "easy":
		return 0.42
	return 0.82


func _assistant_hit_chance() -> float:
	return clampf(_ai_hit_chance() - 0.1, 0.25, 0.9)


func _ai_jump_chance() -> float:
	if _ai_level == "hard":
		return 0.72
	if _ai_level == "easy":
		return 0.18
	return 0.38


func _ai_hit_height_limit() -> float:
	if _ai_level == "hard":
		return 3.05
	if _ai_level == "easy":
		return 2.15
	return 2.65


func _ai_miss_recovery_time() -> float:
	if _ai_level == "hard":
		return 0.06
	if _ai_level == "easy":
		return 0.34
	return 0.16


func _ai_charge_ratio() -> float:
	if _ai_level == "hard":
		return randf_range(0.58, 0.92)
	if _ai_level == "easy":
		return randf_range(0.0, 0.38)
	return randf_range(0.25, 0.68)


func _assistant_charge_ratio() -> float:
	return clampf(_ai_charge_ratio() - 0.12, 0.0, 0.8)


func _is_hit_locked(player: Node3D) -> bool:
	if player == _p1:
		return _p1_hit_lock > 0.0
	if player == _p2:
		return _p2_hit_lock > 0.0
	if player == _p1_assist:
		return _p1_assist_hit_lock > 0.0
	if player == _p2_assist:
		return _p2_assist_hit_lock > 0.0
	return false


func _set_hit_lock(player: Node3D, value: float) -> void:
	if player == _p1:
		_p1_hit_lock = value
	elif player == _p2:
		_p2_hit_lock = value
	elif player == _p1_assist:
		_p1_assist_hit_lock = value
	elif player == _p2_assist:
		_p2_assist_hit_lock = value


func _trigger_special() -> void:
	if _special_cooldown > 0.0:
		return
	_p1_hit_charging = false
	_p1_hit_charge_time = 0.0
	_hit_ball(true)


func _update_special(delta: float) -> void:
	_special_cooldown = maxf(0.0, _special_cooldown - delta)
	_special_timer = maxf(0.0, _special_timer - delta)
	if _special_timer <= 0.0:
		_ball_material.emission_energy_multiplier = lerpf(_ball_material.emission_energy_multiplier, 0.0, delta * 4.0)
		_ball_material.albedo_color = _ball_material.albedo_color.lerp(Color.WHITE, delta * 4.0)
	if _special_cooldown > 0.0:
		_special_label.text = "SPECIAL CHARGING %.1f" % _special_cooldown
		_special_label.visible = true
	elif _special_timer <= 0.0:
		_special_label.text = ""
		_special_label.visible = false


func _update_camera(delta: float) -> void:
	var camera := get_node_or_null("GameplayCamera") as Camera3D
	if camera == null:
		return
	var zoom := maxf(0.0, _ball.position.y - 5.0) * 0.28 + absf(_ball.position.z) * 0.12
	var target_pos := Vector3(17.8 + zoom, 9.4 + zoom * 0.38, 0.0)
	camera.position = camera.position.lerp(target_pos, delta * 3.0)
	camera.look_at(Vector3(0.4, maxf(0.72, _ball.position.y * 0.16), _ball.position.z * 0.2), Vector3.UP)


func _update_water_texture(delta: float) -> void:
	if _water_material == null:
		return
	_water_uv_offset.x = fmod(_water_uv_offset.x + delta * 0.018, 1.0)
	_water_uv_offset.y = fmod(_water_uv_offset.y + delta * 0.007, 1.0)
	_water_material.uv1_offset = _water_uv_offset


func _update_ball_trail(delta: float) -> void:
	_ball_trail_timer = maxf(0.0, _ball_trail_timer - delta)
	if _phase == "playing" and _ball != null and _ball_velocity.length() > 0.25 and _ball_trail_timer <= 0.0:
		_spawn_ball_trail_point(_ball.position, _ball_velocity.length())
		_ball_trail_timer = 0.035

	for i in range(_ball_trail_effects.size() - 1, -1, -1):
		var point := _ball_trail_effects[i]
		if point == null:
			_ball_trail_effects.remove_at(i)
			continue
		var age := float(point.get_meta("age", 0.0)) + delta
		var duration := float(point.get_meta("duration", 0.24))
		var t := clampf(age / duration, 0.0, 1.0)
		point.set_meta("age", age)
		point.scale = Vector3.ONE * lerpf(1.0, 0.45, t)
		var mat := point.material_override as StandardMaterial3D
		if mat != null:
			var color := mat.albedo_color
			color.a = lerpf(0.28, 0.0, t)
			mat.albedo_color = color
			mat.emission_energy_multiplier = lerpf(0.65, 0.0, t)
		if age >= duration:
			_ball_trail_effects.remove_at(i)
			point.queue_free()


func _spawn_ball_trail_point(position: Vector3, speed: float) -> void:
	var point := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = clampf(speed * 0.012, 0.08, 0.16)
	mesh.height = mesh.radius * 2.0
	point.mesh = mesh
	point.position = position

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.98, 0.92, 0.42, 0.28)
	mat.emission_enabled = true
	mat.emission = Color("#ffe86a")
	mat.emission_energy_multiplier = 0.65
	point.material_override = mat
	point.set_meta("age", 0.0)
	point.set_meta("duration", 0.24)
	add_child(point)
	_ball_trail_effects.append(point)


func _spawn_hit_effect(position: Vector3, text: String) -> void:
	var effect := Node3D.new()
	effect.position = position

	var ring := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.78
	mesh.bottom_radius = 0.78
	mesh.height = 0.025
	mesh.radial_segments = 56
	ring.mesh = mesh
	ring.rotation_degrees.x = 90.0
	ring.scale = Vector3.ONE * 0.35

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.93, 0.35, 0.42)
	mat.emission_enabled = true
	mat.emission = Color("#ffe85a")
	mat.emission_energy_multiplier = 0.7
	ring.material_override = mat
	effect.add_child(ring)

	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font = preload("res://fonts/upheavtt.ttf")
	label.font_size = 56
	label.modulate = Color("#ffd84a")
	label.outline_modulate = Color("#7c3200")
	label.outline_size = 8
	label.position = Vector3(0.0, 0.74, 0.0)
	effect.add_child(label)

	effect.set_meta("age", 0.0)
	effect.set_meta("duration", 0.42)
	add_child(effect)
	_hit_effects.append(effect)


func _update_hit_effects(delta: float) -> void:
	for i in range(_hit_effects.size() - 1, -1, -1):
		var effect := _hit_effects[i]
		if effect == null:
			_hit_effects.remove_at(i)
			continue
		var age := float(effect.get_meta("age", 0.0)) + delta
		var duration := float(effect.get_meta("duration", 0.34))
		var t := clampf(age / duration, 0.0, 1.0)
		effect.set_meta("age", age)
		effect.position.y += delta * 1.4
		for child in effect.get_children():
			if child is MeshInstance3D:
				var ring := child as MeshInstance3D
				ring.scale = Vector3.ONE * lerpf(0.35, 1.75, t)
				var mat := ring.material_override as StandardMaterial3D
				if mat != null:
					var color := mat.albedo_color
					color.a = lerpf(0.42, 0.0, t)
					mat.albedo_color = color
					mat.emission_energy_multiplier = lerpf(0.7, 0.0, t)
			elif child is Label3D:
				var label := child as Label3D
				var label_color := label.modulate
				label_color.a = lerpf(1.0, 0.0, t)
				label.modulate = label_color
				var outline_color := label.outline_modulate
				outline_color.a = lerpf(1.0, 0.0, t)
				label.outline_modulate = outline_color
		if age >= duration:
			_hit_effects.remove_at(i)
			effect.queue_free()


func _update_landing_target() -> void:
	if _landing_target == null:
		return
	if _phase == "serve":
		_show_landing_target_at(_serve_target)
		return
	if _phase != "playing":
		_landing_target.visible = false
		return
	var landing: Variant = _predict_ball_landing()
	if landing == null:
		_landing_target.visible = false
		return
	var landing_pos: Vector3 = landing
	_show_landing_target_at(landing_pos)


func _show_landing_target_at(landing: Vector3) -> void:
	_landing_target.visible = true
	_landing_target.position = Vector3(
		clampf(landing.x, -COURT_WIDTH * 0.5 + 0.45, COURT_WIDTH * 0.5 - 0.45),
		0.11,
		clampf(landing.z, -COURT_DEPTH * 0.5 + 0.45, COURT_DEPTH * 0.5 - 0.45)
	)


func _predict_ball_landing() -> Variant:
	if _ball == null or _ball_velocity == Vector3.ZERO:
		return null
	var time := _time_to_ground(_ball.position.y, _ball_velocity.y)
	if time <= 0.0:
		return null
	return _ball.position + Vector3(_ball_velocity.x * time, BALL_GROUND_Y - _ball.position.y, _ball_velocity.z * time)


func _time_to_ground(start_y: float, velocity_y: float) -> float:
	var a := 0.5 * GRAVITY
	var b := velocity_y
	var c := start_y - BALL_GROUND_Y
	var discriminant := b * b - 4.0 * a * c
	if discriminant < 0.0:
		return -1.0
	var root := sqrt(discriminant)
	var t1 := (-b + root) / (2.0 * a)
	var t2 := (-b - root) / (2.0 * a)
	var result := INF
	if t1 > 0.0:
		result = minf(result, t1)
	if t2 > 0.0:
		result = minf(result, t2)
	return -1.0 if result == INF else result


func _pick_safe_landing_target(player: Node3D, side_dir: float) -> Vector3:
	var x_influence := clampf((_ball.position.x - player.position.x) * 2.2, -3.0, 3.0)
	var target_x := clampf(player.position.x + x_influence, -COURT_WIDTH * 0.5 + 1.1, COURT_WIDTH * 0.5 - 1.1)
	var target_z := clampf(7.2 + randf_range(-1.8, 1.8), 1.4, COURT_DEPTH * 0.5 - 1.15)
	if side_dir < 0.0:
		target_z = -target_z
	return Vector3(target_x, BALL_GROUND_Y, target_z)


func _velocity_to_land_at(start: Vector3, target: Vector3, velocity_y: float) -> Vector3:
	var time := _time_to_ground(start.y, velocity_y)
	if time <= 0.0:
		time = 1.0
	return Vector3(
		(target.x - start.x) / time,
		velocity_y,
		(target.z - start.z) / time
	)


func _update_countdown(delta: float) -> void:
	if _phase != "countdown":
		return
	_update_landing_target()
	_countdown_timer -= delta
	if _countdown_timer > 2.4:
		_countdown_label.text = "3"
	elif _countdown_timer > 1.4:
		_countdown_label.text = "2"
	elif _countdown_timer > 0.4:
		_countdown_label.text = "1"
	elif _countdown_timer > 0.0:
		_countdown_label.text = "START"
	else:
		_countdown_label.visible = false
		_phase = "serve"
		_serve_power = 0.0
		_serve_charging = false
		_serve_target = _make_serve_target(_serving_team)
		_serve_ui.visible = true
		_serve_prompt.text = "HOLD JUMP, RELEASE TO SERVE" if _serving_team == 1 else "AI SERVE"


func _start_countdown() -> void:
	_phase = "countdown"
	_countdown_timer = COUNTDOWN_DURATION
	_countdown_label.visible = true
	_countdown_label.text = "3"
	_serve_ui.visible = false


func _award_point(team: int) -> void:
	if _phase != "playing":
		return
	if team == 1:
		_score_p1 += 1
	else:
		_score_p2 += 1
	_update_score_label()
	_reset_rally(team)


func _update_score_label() -> void:
	_score_p1_label.text = str(_score_p1)
	_score_p2_label.text = str(_score_p2)


func _score_number_label(color: Color, outline: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", preload("res://fonts/upheavtt.ttf"))
	label.add_theme_font_size_override("font_size", 50)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", outline)
	label.add_theme_constant_override("outline_size", 8)
	return label


func _small_hud_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", preload("res://fonts/upheavtt.ttf"))
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color("#111111"))
	label.add_theme_constant_override("outline_size", 3)
	return label


func _reset_rally(serving_team: int) -> void:
	_serving_team = serving_team
	_p1.position = Vector3(0, PLAYER_GROUND_Y, 7.0)
	_p2.position = Vector3(0, PLAYER_GROUND_Y, -7.0)
	if _p1_assist != null:
		_p1_assist.position = Vector3(3.0, PLAYER_GROUND_Y, 8.8)
	if _p2_assist != null:
		_p2_assist.position = Vector3(-3.0, PLAYER_GROUND_Y, -8.8)
	_p1_y_velocity = 0.0
	_p2_y_velocity = 0.0
	_p1_grounded = true
	_p2_grounded = true
	_p1_hit_lock = 0.0
	_p2_hit_lock = 0.0
	_p1_assist_hit_lock = 0.0
	_p2_assist_hit_lock = 0.0
	_p1_hit_charging = false
	_p1_hit_charge_time = 0.0
	_ai_decision_timer = 0.0
	_ai_target_error = Vector3.ZERO
	_ai_hit_attempt_timer = 0.0
	_assistant_decision_timer = 0.0
	_assistant_target_error = Vector3.ZERO
	_assistant_hit_attempt_timer = 0.0
	_ball.position = Vector3(0.3, 4.0, 2.0 if serving_team == 1 else -2.0)
	_ball_velocity = Vector3.ZERO
	_serve_target = _make_serve_target(serving_team)
	_update_landing_target()
	_special_timer = 0.0
	_ball_material.emission_energy_multiplier = 0.0
	_ball_material.albedo_color = Color.WHITE
	_start_countdown()


func _update_serve(delta: float) -> void:
	var server := _p1 if _serving_team == 1 else _p2
	var direction := -1.0 if _serving_team == 1 else 1.0
	_ball.position = server.position + Vector3(0.2, 1.85, direction * 0.25)
	_ball_velocity = Vector3.ZERO
	_serve_target.x = clampf(server.position.x + 0.2, -COURT_WIDTH * 0.5 + 1.1, COURT_WIDTH * 0.5 - 1.1)
	_update_landing_target()

	if _serving_team == 2:
		_serve_power += delta * 0.65
		_serve_bar.value = clampf(_serve_power, 0.0, 1.0)
		if _serve_power >= 0.72:
			_release_serve()
		return

	if _serve_charging:
		_serve_power = fmod(_serve_power + delta * 0.85, 1.0)
	_serve_bar.value = clampf(_serve_power, 0.0, 1.0)


func _release_serve() -> void:
	var power := clampf(_serve_power, 0.15, 1.0)
	_phase = "playing"
	_serve_ui.visible = false
	_serve_charging = false
	_ball_velocity = _velocity_to_land_at(_ball.position, _serve_target, lerpf(8.0, 14.5, power))
	_update_landing_target()
	_jump_player(_p1 if _serving_team == 1 else _p2, _serving_team == 1)
	_serve_power = 0.0


func _make_serve_target(serving_team: int) -> Vector3:
	var target_z := -7.2 if serving_team == 1 else 7.2
	return Vector3(randf_range(-3.2, 3.2), BALL_GROUND_Y, target_z + randf_range(-1.6, 1.6))


func _jump_player(player: Node3D, is_p1: bool) -> void:
	if is_p1:
		if not _p1_grounded:
			return
		_p1_y_velocity = 8.5
		_p1_grounded = false
		_play_actor_animation(_p1_anim, "jump")
	else:
		if not _p2_grounded:
			return
		_p2_y_velocity = 8.5
		_p2_grounded = false
		_play_actor_animation(_p2_anim, "jump")


func _update_vertical_motion(player: Node3D, is_p1: bool, delta: float) -> void:
	if is_p1:
		if _p1_grounded:
			return
		_p1_y_velocity += GRAVITY * delta
		player.position.y += _p1_y_velocity * delta
		if player.position.y <= PLAYER_GROUND_Y:
			player.position.y = PLAYER_GROUND_Y
			_p1_y_velocity = 0.0
			_p1_grounded = true
	else:
		if _p2_grounded:
			return
		_p2_y_velocity += GRAVITY * delta
		player.position.y += _p2_y_velocity * delta
		if player.position.y <= PLAYER_GROUND_Y:
			player.position.y = PLAYER_GROUND_Y
			_p2_y_velocity = 0.0
			_p2_grounded = true


func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root
	for child in root.get_children():
		var found: AnimationPlayer = _find_animation_player(child)
		if found != null:
			return found
	return null


func _play_actor_animation(anim: AnimationPlayer, action: String) -> void:
	if anim == null:
		return
	if anim.get_meta("current_action", "") == action and anim.is_playing():
		return
	var animation_name: StringName = _pick_animation_name(anim, action)
	if animation_name == "":
		return
	anim.set_meta("current_action", action)
	anim.speed_scale = 1.85 if action == "hit" else 1.12 if action == "jump" else 1.0
	anim.play(animation_name)


func _pick_animation_name(anim: AnimationPlayer, action: String) -> StringName:
	var preferred: Dictionary = {
		"idle": ["idle", "stand", "standing", "rest"],
		"run": ["run", "running", "walk", "walking", "jog", "jogging"],
		"jog": ["jog", "jogging", "run", "running", "walk", "walking"],
		"jump": ["jump", "jumping"],
		"hit": ["hit", "punch", "attack", "smash"],
	}
	var names: PackedStringArray = anim.get_animation_list()
	for target in preferred.get(action, ["idle"]):
		for animation_name in names:
			var normalized := String(animation_name).to_lower().replace("_", "").replace("-", "").replace(" ", "")
			if normalized == target or normalized.contains(target):
				return animation_name
	if not names.is_empty():
		return names[0]
	return &""


func _add_default_inputs() -> void:
	_ensure_key_action("p1_left", [KEY_A, KEY_LEFT])
	_ensure_key_action("p1_right", [KEY_D, KEY_RIGHT])
	_ensure_key_action("p1_up", [KEY_W, KEY_UP])
	_ensure_key_action("p1_down", [KEY_S, KEY_DOWN])
	_ensure_key_action("p1_jump", [KEY_I])
	_ensure_key_action("p1_hit", [KEY_O])
	_ensure_key_action("p1_slide", [KEY_P])
	_ensure_key_action("p1_special", [KEY_L])
	_ensure_joy_button("p1_jump", [0])
	_ensure_joy_button("p1_hit", [2, 3])
	_ensure_joy_button("p1_slide", [1])
	_ensure_joy_button("p1_special", [4, 5])
	_ensure_joy_axis("p1_left", JOY_AXIS_LEFT_X, -1.0)
	_ensure_joy_axis("p1_right", JOY_AXIS_LEFT_X, 1.0)
	_ensure_joy_axis("p1_up", JOY_AXIS_LEFT_Y, -1.0)
	_ensure_joy_axis("p1_down", JOY_AXIS_LEFT_Y, 1.0)


func _ensure_key_action(action: StringName, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.keycode = key
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)


func _ensure_joy_button(action: StringName, buttons: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for button in buttons:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)


func _ensure_joy_axis(action: StringName, axis: int, value: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)
