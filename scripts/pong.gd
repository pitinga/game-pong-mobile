extends Control
## Pong Mobile: jogo 2D em uma única cena, sem dependências externas.

enum GameState { MENU, PLAYING, PAUSED, FINISHED }

const BG := Color("#081526")
const GRID := Color("#183047")
const WHITE := Color("#f5faff")
const MUTED := Color("#8aa5bc")
const CYAN := Color("#31e4ed")
const PINK := Color("#ff658d")

const PADDLE_WIDTH := 15.0
const PADDLE_HEIGHT := 100.0
const PADDLE_MARGIN := 55.0
const BALL_RADIUS := 10.0
const FIELD_MARGIN := 18.0
const PLAYER_SPEED := 640.0
const BASE_BALL_SPEED := 345.0
const BALL_ACCELERATION := 38.0
const PADDLE_SPEED_BONUS := 55.0
const MAX_BALL_SPEED := 1150.0
const WIN_SCORE := 7

const CPU_SPEEDS := [185.0, 260.0, 370.0]
const CPU_REACTION := [0.48, 0.30, 0.15]
const CPU_ERROR := [115.0, 80.0, 18.0]
const CPU_LOOKAHEAD := [0.10, 0.30, 0.85]
const DIFFICULTIES := ["FÁCIL", "MÉDIO", "DIFÍCIL"]

var state: GameState = GameState.MENU
var difficulty := 1
var player_score := 0
var cpu_score := 0
var player_won := false

var player_y := 270.0
var cpu_y := 270.0
var ball_position := Vector2(480.0, 270.0)
var ball_velocity := Vector2.ZERO
var _serve_countdown := 0.0
var _serve_direction := 1.0
var _cpu_target_y := 270.0
var _cpu_reaction_timer := 0.0
var _cpu_aim_bias := 0.0
var _trail: Array[Vector2] = []

var _menu: CenterContainer
var _pause_menu: CenterContainer
var _finish_menu: CenterContainer
var _finish_title: Label
var _finish_score: Label
var _pause_button: Button
var _difficulty_buttons: Array[Button] = []
var _sound_players := {}


func _ready() -> void:
	_build_sounds()
	_build_interface()
	_reset_positions()
	_show_interface()
	resized.connect(queue_redraw)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if state != GameState.PLAYING:
		return

	var axis := Input.get_axis("ui_up", "ui_down")
	if Input.is_key_pressed(KEY_W):
		axis -= 1.0
	if Input.is_key_pressed(KEY_S):
		axis += 1.0
	if not is_zero_approx(axis):
		_set_player_y(player_y + clampf(axis, -1.0, 1.0) * PLAYER_SPEED * delta)

	_update_cpu(delta)
	if _serve_countdown > 0.0:
		_serve_countdown -= delta
		if _serve_countdown <= 0.0:
			_launch_ball()
		queue_redraw()
		return

	_accelerate_ball(delta)
	# Passos curtos evitam atravessar as raquetes quando a bola estiver rápida.
	var substeps := maxi(1, ceili(ball_velocity.length() * delta / BALL_RADIUS))
	var step_delta := delta / float(substeps)
	for _step in range(substeps):
		ball_position += ball_velocity * step_delta
		_check_ball_collisions()
		if ball_position.x < -BALL_RADIUS:
			_score_point(false)
			queue_redraw()
			return
		elif ball_position.x > size.x + BALL_RADIUS:
			_score_point(true)
			queue_redraw()
			return

	_trail.push_front(ball_position)
	if _trail.size() > 12:
		_trail.pop_back()
	queue_redraw()


func _check_ball_collisions() -> void:
	var top := FIELD_MARGIN + BALL_RADIUS
	var bottom := size.y - FIELD_MARGIN - BALL_RADIUS
	if ball_position.y <= top and ball_velocity.y < 0.0:
		ball_position.y = top
		ball_velocity.y = -ball_velocity.y
		_play_sound("wall")
	elif ball_position.y >= bottom and ball_velocity.y > 0.0:
		ball_position.y = bottom
		ball_velocity.y = -ball_velocity.y
		_play_sound("wall")

	var player_x := PADDLE_MARGIN
	var cpu_x := size.x - PADDLE_MARGIN
	if ball_velocity.x < 0.0 \
		and ball_position.x - BALL_RADIUS <= player_x + PADDLE_WIDTH * 0.5 \
		and ball_position.x > player_x \
		and absf(ball_position.y - player_y) <= PADDLE_HEIGHT * 0.5 + BALL_RADIUS:
		ball_position.x = player_x + PADDLE_WIDTH * 0.5 + BALL_RADIUS
		_bounce_from_paddle(true)
	elif ball_velocity.x > 0.0 \
		and ball_position.x + BALL_RADIUS >= cpu_x - PADDLE_WIDTH * 0.5 \
		and ball_position.x < cpu_x \
		and absf(ball_position.y - cpu_y) <= PADDLE_HEIGHT * 0.5 + BALL_RADIUS:
		ball_position.x = cpu_x - PADDLE_WIDTH * 0.5 - BALL_RADIUS
		_bounce_from_paddle(false)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_P:
			if state == GameState.PLAYING or state == GameState.PAUSED:
				_toggle_pause()
				get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ENTER and state == GameState.MENU:
			_start_match()
			return

	if state != GameState.PLAYING:
		return

	if event is InputEventScreenTouch and event.pressed:
		_set_player_y(event.position.y)
	elif event is InputEventScreenDrag:
		_set_player_y(event.position.y)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_set_player_y(event.position.y)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_set_player_y(event.position.y)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED and state == GameState.PLAYING:
		state = GameState.PAUSED
		_show_interface()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	for x in range(32, int(w), 48):
		draw_line(Vector2(x, 0), Vector2(x, h), GRID, 1.0)
	for y in range(28, int(h), 48):
		draw_line(Vector2(0, y), Vector2(w, y), GRID, 1.0)

	draw_line(Vector2(0, FIELD_MARGIN), Vector2(w, FIELD_MARGIN), GRID.lightened(0.15), 2.0)
	draw_line(Vector2(0, h - FIELD_MARGIN), Vector2(w, h - FIELD_MARGIN), GRID.lightened(0.15), 2.0)
	for y in range(28, int(h) - 20, 30):
		draw_rect(Rect2(w * 0.5 - 2.0, y, 4.0, 17.0), Color("#31506a"))

	_draw_paddle(Vector2(PADDLE_MARGIN, player_y), CYAN)
	_draw_paddle(Vector2(w - PADDLE_MARGIN, cpu_y), PINK)
	for i in range(_trail.size() - 1, -1, -1):
		var opacity := (1.0 - float(i) / 12.0) * 0.22
		draw_circle(_trail[i], maxf(2.0, BALL_RADIUS - float(i) * 0.5), Color(1, 1, 1, opacity))
	draw_circle(ball_position, BALL_RADIUS + 6.0, Color(1, 1, 1, 0.12))
	draw_circle(ball_position, BALL_RADIUS, WHITE)

	_draw_centered(str(player_score).pad_zeros(2), Vector2(w * 0.42, 79), 54, CYAN)
	_draw_centered(str(cpu_score).pad_zeros(2), Vector2(w * 0.58, 79), 54, PINK)
	_draw_centered("VOCÊ", Vector2(w * 0.42, 106), 13, MUTED)
	_draw_centered("CPU", Vector2(w * 0.58, 106), 13, MUTED)
	if state == GameState.PLAYING:
		var speed_ratio := maxf(1.0, ball_velocity.length() / BASE_BALL_SPEED)
		_draw_centered("NÍVEL %s   •   BOLA %.1fx" % [DIFFICULTIES[difficulty], speed_ratio], Vector2(w * 0.5, 143), 14, MUTED)
		_draw_centered("DESLIZE O DEDO PARA MOVER A RAQUETE", Vector2(w * 0.5, h - 31), 14, MUTED)
		if _serve_countdown > 0.0:
			_draw_centered("PREPARE-SE", Vector2(w * 0.5, h * 0.39), 26, WHITE)


func _draw_paddle(center: Vector2, color: Color) -> void:
	var rectangle := Rect2(center - Vector2(PADDLE_WIDTH, PADDLE_HEIGHT) * 0.5, Vector2(PADDLE_WIDTH, PADDLE_HEIGHT))
	draw_rect(rectangle.grow(8.0), Color(color.r, color.g, color.b, 0.09))
	draw_rect(rectangle.grow(3.0), Color(color.r, color.g, color.b, 0.21))
	draw_rect(rectangle, color)
	draw_rect(Rect2(rectangle.position + Vector2(3, 7), Vector2(3, PADDLE_HEIGHT - 14)), Color(1, 1, 1, 0.24))


func _draw_centered(message: String, baseline: Vector2, font_size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(baseline.x - width * 0.5, baseline.y), message, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _start_match() -> void:
	player_score = 0
	cpu_score = 0
	player_won = false
	_reset_positions()
	state = GameState.PLAYING
	_reset_round(1.0 if randf() > 0.5 else -1.0)
	_show_interface()
	queue_redraw()


func _select_difficulty(value: int) -> void:
	difficulty = clampi(value, 0, 2)
	for i in range(_difficulty_buttons.size()):
		var selected := i == difficulty
		_style_button(_difficulty_buttons[i], CYAN if selected else GRID, selected)
	_play_sound("wall")


func _set_player_y(target: float) -> void:
	player_y = clampf(target, FIELD_MARGIN + PADDLE_HEIGHT * 0.5, size.y - FIELD_MARGIN - PADDLE_HEIGHT * 0.5)


func _reset_positions() -> void:
	player_y = size.y * 0.5
	cpu_y = size.y * 0.5
	_cpu_target_y = cpu_y
	_cpu_aim_bias = 0.0
	ball_position = size * 0.5
	ball_velocity = Vector2.ZERO
	_trail.clear()


func _reset_round(direction: float) -> void:
	_reset_positions()
	_serve_direction = direction
	_serve_countdown = 0.9
	_cpu_reaction_timer = 0.0


func _launch_ball() -> void:
	var angle := randf_range(-0.55, 0.55)
	ball_velocity = Vector2(cos(angle) * _serve_direction, sin(angle)) * BASE_BALL_SPEED
	if _serve_direction > 0.0:
		_cpu_aim_bias = randf_range(-CPU_ERROR[difficulty], CPU_ERROR[difficulty])
		_cpu_reaction_timer = CPU_REACTION[difficulty]
	_play_sound("serve")


func _accelerate_ball(delta: float) -> void:
	var speed := ball_velocity.length()
	if speed > 0.0 and speed < MAX_BALL_SPEED:
		ball_velocity *= minf(speed + BALL_ACCELERATION * delta, MAX_BALL_SPEED) / speed


func _bounce_from_paddle(is_player: bool) -> void:
	var paddle_center := player_y if is_player else cpu_y
	var offset := clampf((ball_position.y - paddle_center) / (PADDLE_HEIGHT * 0.5), -1.0, 1.0)
	var angle := offset * 0.98
	var direction := 1.0 if is_player else -1.0
	var speed := minf(ball_velocity.length() + PADDLE_SPEED_BONUS, MAX_BALL_SPEED)
	ball_velocity = Vector2(direction * cos(angle), sin(angle)) * speed
	if is_player:
		# O erro é sorteado uma vez por devolução, sem teletransporte da mira.
		_cpu_aim_bias = randf_range(-CPU_ERROR[difficulty], CPU_ERROR[difficulty])
		_cpu_reaction_timer = CPU_REACTION[difficulty]
	else:
		_cpu_reaction_timer = 0.0
	_play_sound("paddle")


func _update_cpu(delta: float) -> void:
	_cpu_reaction_timer -= delta
	if _cpu_reaction_timer <= 0.0:
		_cpu_reaction_timer = CPU_REACTION[difficulty]
		if ball_velocity.x > 0.0:
			var destination_x := size.x - PADDLE_MARGIN
			var flight_time := maxf(0.0, (destination_x - ball_position.x) / ball_velocity.x)
			flight_time = minf(flight_time, CPU_LOOKAHEAD[difficulty])
			var top := FIELD_MARGIN + BALL_RADIUS
			var span := size.y - 2.0 * top
			var projected_y := ball_position.y + flight_time * ball_velocity.y
			var mirrored := fposmod(projected_y - top, span * 2.0)
			_cpu_target_y = top + (mirrored if mirrored <= span else span * 2.0 - mirrored)
			_cpu_target_y += _cpu_aim_bias
		else:
			_cpu_target_y = size.y * 0.5 + randf_range(-30.0, 30.0)
	var step: float = CPU_SPEEDS[difficulty] * delta
	cpu_y = move_toward(cpu_y, clampf(_cpu_target_y, FIELD_MARGIN + PADDLE_HEIGHT * 0.5, size.y - FIELD_MARGIN - PADDLE_HEIGHT * 0.5), step)


func _score_point(for_player: bool) -> void:
	if for_player:
		player_score += 1
	else:
		cpu_score += 1
	_play_sound("point")
	if player_score >= WIN_SCORE or cpu_score >= WIN_SCORE:
		player_won = player_score >= WIN_SCORE
		state = GameState.FINISHED
		_finish_title.text = "VOCÊ VENCEU!" if player_won else "CPU VENCEU!"
		_finish_score.text = "%02d   :   %02d" % [player_score, cpu_score]
		_show_interface()
	else:
		_reset_round(-1.0 if for_player else 1.0)


func _toggle_pause() -> void:
	if state == GameState.PLAYING:
		state = GameState.PAUSED
	elif state == GameState.PAUSED:
		state = GameState.PLAYING
	_show_interface()
	queue_redraw()


func _return_to_menu() -> void:
	state = GameState.MENU
	player_score = 0
	cpu_score = 0
	_reset_positions()
	_show_interface()
	queue_redraw()


func _show_interface() -> void:
	_menu.visible = state == GameState.MENU
	_pause_menu.visible = state == GameState.PAUSED
	_finish_menu.visible = state == GameState.FINISHED
	_pause_button.visible = state == GameState.PLAYING


func _build_interface() -> void:
	_menu = _new_overlay()
	var menu_content := _overlay_content(_menu)
	_add_label(menu_content, "PONG", 72, WHITE)
	_add_label(menu_content, "ARCADE  /  MOBILE", 17, CYAN)
	_add_space(menu_content, 12)
	_add_label(menu_content, "ESCOLHA A DIFICULDADE", 15, MUTED)
	var levels := HBoxContainer.new()
	levels.add_theme_constant_override("separation", 12)
	menu_content.add_child(levels)
	for i in range(DIFFICULTIES.size()):
		var button := _new_button(DIFFICULTIES[i], CYAN if i == difficulty else GRID, i == difficulty)
		button.custom_minimum_size = Vector2(146, 50)
		levels.add_child(button)
		button.pressed.connect(_select_difficulty.bind(i))
		_difficulty_buttons.append(button)
	_add_space(menu_content, 10)
	var start_button := _new_button("JOGAR  ▶", CYAN, true)
	start_button.custom_minimum_size = Vector2(0, 58)
	menu_content.add_child(start_button)
	start_button.pressed.connect(_start_match)
	_add_label(menu_content, "1 JOGADOR  •  PRIMEIRO A 7 PONTOS", 14, MUTED)

	_pause_menu = _new_overlay()
	var pause_content := _overlay_content(_pause_menu)
	_add_label(pause_content, "PAUSADO", 49, WHITE)
	_add_label(pause_content, "A PARTIDA ESTÁ EM PAUSA", 16, MUTED)
	_add_space(pause_content, 12)
	var resume_button := _new_button("CONTINUAR", CYAN, true)
	pause_content.add_child(resume_button)
	resume_button.pressed.connect(_toggle_pause)
	var restart_button := _new_button("REINICIAR PARTIDA", GRID, false)
	pause_content.add_child(restart_button)
	restart_button.pressed.connect(_start_match)
	var menu_button := _new_button("MENU PRINCIPAL", GRID, false)
	pause_content.add_child(menu_button)
	menu_button.pressed.connect(_return_to_menu)

	_finish_menu = _new_overlay()
	var finish_content := _overlay_content(_finish_menu)
	_finish_title = _add_label(finish_content, "FIM DE JOGO", 49, WHITE)
	_finish_score = _add_label(finish_content, "00   :   00", 35, CYAN)
	_add_space(finish_content, 12)
	var again_button := _new_button("JOGAR NOVAMENTE", CYAN, true)
	finish_content.add_child(again_button)
	again_button.pressed.connect(_start_match)
	var exit_button := _new_button("MENU PRINCIPAL", GRID, false)
	finish_content.add_child(exit_button)
	exit_button.pressed.connect(_return_to_menu)

	_pause_button = _new_button("Ⅱ  PAUSAR", GRID, false)
	_pause_button.set_anchors_preset(PRESET_TOP_RIGHT)
	_pause_button.offset_left = -151
	_pause_button.offset_top = 27
	_pause_button.offset_right = -23
	_pause_button.offset_bottom = 72
	add_child(_pause_button)
	_pause_button.pressed.connect(_toggle_pause)


func _new_overlay() -> CenterContainer:
	var overlay := CenterContainer.new()
	overlay.set_anchors_preset(PRESET_FULL_RECT)
	overlay.mouse_filter = MOUSE_FILTER_STOP
	add_child(overlay)
	return overlay


func _overlay_content(overlay: CenterContainer) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(515, 0)
	var background := StyleBoxFlat.new()
	background.bg_color = Color("#10243c")
	background.border_color = Color("#264962")
	background.set_border_width_all(2)
	background.set_corner_radius_all(20)
	background.set_content_margin_all(24)
	background.shadow_color = Color(0, 0, 0, 0.35)
	background.shadow_size = 18
	panel.add_theme_stylebox_override("panel", background)
	overlay.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 13)
	panel.add_child(content)
	return content


func _add_label(parent: Node, message: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _add_space(parent: Node, height: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	spacer.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(spacer)


func _new_button(message: String, color: Color, emphasized: bool) -> Button:
	var button := Button.new()
	button.text = message
	button.custom_minimum_size = Vector2(0, 52)
	button.focus_mode = FOCUS_NONE
	button.add_theme_font_size_override("font_size", 17)
	_style_button(button, color, emphasized)
	return button


func _style_button(button: Button, color: Color, emphasized: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(11)
	style.set_content_margin_all(10)
	if not emphasized:
		style.border_color = Color("#41617b")
		style.set_border_width_all(1)
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = color.lightened(0.17)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_color_override("font_color", BG if emphasized else WHITE)
	button.add_theme_color_override("font_hover_color", BG if emphasized else WHITE)
	button.add_theme_color_override("font_pressed_color", BG if emphasized else WHITE)


func _build_sounds() -> void:
	for config in [["paddle", 540.0, 0.065], ["wall", 350.0, 0.055], ["point", 210.0, 0.22], ["serve", 680.0, 0.075]]:
		var player := AudioStreamPlayer.new()
		player.stream = _make_tone(config[1], config[2])
		player.volume_db = -11.0
		add_child(player)
		_sound_players[config[0]] = player


func _make_tone(frequency: float, duration: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var count := int(sample_rate * duration)
	var raw := PackedByteArray()
	raw.resize(count * 2)
	for index in range(count):
		var progress := float(index) / float(count)
		var fade := pow(1.0 - progress, 1.7)
		var sample := int(sin(TAU * frequency * float(index) / float(sample_rate)) * fade * 10000.0)
		raw[index * 2] = sample & 0xff
		raw[index * 2 + 1] = (sample >> 8) & 0xff
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = sample_rate
	audio.stereo = false
	audio.data = raw
	return audio


func _play_sound(name: String) -> void:
	if _sound_players.has(name):
		(_sound_players[name] as AudioStreamPlayer).play()
