extends Control
## Pong Mobile: jogo 2D em uma única cena, sem dependências externas.

enum GameState { MENU, PLAYING, PAUSED, FINISHED, PRIVACY, SETTINGS, STATS, OTHER_GAMES }
enum MatchMode { CLASSIC, SURVIVAL, TWO_PLAYERS }
enum InterstitialState { IDLE, REQUESTED, SHOWING }
enum EntitlementStatus { UNKNOWN, FREE_CONFIRMED, PRO, PENDING, CHECKOUT }

const AdPolicy = preload("res://scripts/ad_policy.gd")
const PlayBillingBridge = preload("res://scripts/play_billing_bridge.gd")
const SETTINGS_FILE := "user://pong_pro_settings.cfg"
const STATS_FILE := "user://pong_pro_stats.cfg"
const AD_POLICY_FILE := "user://pong_free_ad_policy.cfg"
const PRO_ENTITLEMENT_FILE := "user://pong_pro_entitlement.cfg"
const PRO_REVOKE_GRACE_SEC := 48 * 60 * 60
const PRO_NEGATIVE_INTERVAL_SEC := 24 * 60 * 60
const FREE_CONFIRMATIONS_FOR_ADS := 2
# Adicionar URL da Play Store somente após o título estar publicado. Nunca
# oferecer links de instalação para apps inexistentes ou para este próprio jogo.
const RELEASED_GAME_CATALOG := []
const AD_REQUEST_TIMEOUT_MSEC := 8000
const AD_SHOWING_TIMEOUT_MSEC := 120000
const AD_RECOVERY_RETRY_MSEC := 4000
const AD_VERIFY_TIMEOUT_MSEC := 4000
const IMPACT_EPSILON := 0.000001
const MAX_IMPACTS_PER_SUBSTEP := 12

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
const THEMES := [
	{"name": "NEON", "player": Color("#31e4ed"), "cpu": Color("#ff658d"), "ball": Color("#f5faff")},
	{"name": "CLÁSSICO", "player": Color.WHITE, "cpu": Color.WHITE, "ball": Color.WHITE},
	{"name": "VERDE", "player": Color("#8fea5b"), "cpu": Color("#8fea5b"), "ball": Color("#d9ff68")},
]

var is_pro := false
var entitlement_status: EntitlementStatus = EntitlementStatus.UNKNOWN
# Caminhos substituiveis nos testes: nunca gravar nas preferencias reais.
var settings_file := SETTINGS_FILE
var stats_file := STATS_FILE
var ad_policy_file := AD_POLICY_FILE
var pro_entitlement_file := PRO_ENTITLEMENT_FILE
var published_games: Array[Dictionary] = []
var match_mode: MatchMode = MatchMode.CLASSIC
var point_limit := WIN_SCORE
var ball_scale := 1.0
var paddle_scale := 1.0
var theme_index := 0
var survival_hits := 0
var _stats := {
	"played": 0, "streak": 0,
	"best_streak": 0, "best_survival": 0, "survival_matches": 0, "two_player_matches": 0,
	"standard_wins": 0, "standard_losses": 0,
	"custom_wins": 0, "custom_losses": 0,
}
# Marcador durável de tentativa competitiva não finalizada. Pausa não limpa.
var _active_classic_match := false
var _ad_policy = AdPolicy.new()
# O SDK será conectado por um adaptador apenas na edição Free. Sem adaptador,
# nenhum anúncio é solicitado ou exibido.
var _interstitial_adapter: Node
var _billing_adapter: Node
var _billing_purchase_available := false
var _billing_status := "Compras disponíveis quando o Google Play estiver configurado."
var _pro_price := ""
var _cached_pro_owned := false
var _last_positive_unix := 0
var _negative_first_unix := 0
var _negative_last_unix := 0
var _negative_count := 0
var _ads_consent_granted := false
var _session_free_confirmations := 0
var _last_free_query_id := 0
var _pending_pro_preferences := false
var _pending_pro_revocation := false
var _interstitial_attempted_this_match := false
var _interstitial_state: InterstitialState = InterstitialState.IDLE
var _ad_request_sequence := 0
var _ad_verification_sequence := 0
var _ad_verification_id := -1
var _ad_verification_match_id := -1
var _ad_verification_start_ticks := 0
var _active_ad_request_id := -1
var _ad_requested_at_ticks := 0
var _ad_next_recovery_attempt_ticks := 0
var _ad_recovery_needed := false
var _ad_requests: Dictionary = {}
var _match_id := 0
var _finished_match_id := -1

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
var _serve_speed := BASE_BALL_SPEED
var _cpu_target_y := 270.0
var _cpu_reaction_timer := 0.0
var _cpu_aim_bias := 0.0
var _trail: Array[Vector2] = []
# Um dedo pode possuir apenas uma raquete; o índice só muda num novo press.
var _touch_owners: Dictionary = {}
var _paddle_touch_ids: Array[int] = [-1, -1]

var _menu: CenterContainer
var _pause_menu: CenterContainer
var _finish_menu: CenterContainer
var _privacy_menu: CenterContainer
var _settings_menu: CenterContainer
var _stats_menu: CenterContainer
var _other_games_menu: CenterContainer
var _other_games_content: VBoxContainer
var _finish_title: Label
var _finish_score: Label
var _finish_again_button: Button
var _finish_exit_button: Button
var _ad_status_label: Label
var _ad_safe_exit_button: Button
var _pause_button: Button
var _ball_value_label: Label
var _paddle_value_label: Label
var _ball_slider: HSlider
var _paddle_slider: HSlider
var _mode_selector: OptionButton
var _points_selector: OptionButton
var _theme_selector: OptionButton
var _stats_text: Label
var _pro_button: Button
var _restore_purchase_button: Button
var _pro_row: HBoxContainer
var _pro_status_label: Label
var _menu_content: VBoxContainer
var _edition_title: Label
var _edition_subtitle: Label
var _features_label: Label
var _privacy_edition_label: Label
var _privacy_storage_label: Label
var _other_games_button: Button
var _difficulty_buttons: Array[Button] = []
var _sound_players := {}


func _ready() -> void:
	if OS.get_name() == "Android":
		_load_cached_pro_entitlement()
	_ad_policy.load_state(ad_policy_file)
	if is_pro:
		_load_pro_settings()
		_load_pro_stats()
	_build_sounds()
	_build_interface()
	set_published_games(RELEASED_GAME_CATALOG)
	_reset_positions()
	_show_interface()
	resized.connect(_on_resized)
	queue_redraw()
	if OS.get_name() == "Android":
		set_billing_adapter(PlayBillingBridge.new())


func _process(_delta: float) -> void:
	if _ad_verification_id != -1 and Time.get_ticks_msec() - _ad_verification_start_ticks >= AD_VERIFY_TIMEOUT_MSEC:
		_on_ad_verification_timeout()
	if _active_ad_request_id == -1:
		return
	if not is_instance_valid(_interstitial_adapter):
		_mark_ad_request_canceled(_active_ad_request_id)
		_finish_ad_request(_active_ad_request_id)
		return
	var now := Time.get_ticks_msec()
	var elapsed := now - _ad_requested_at_ticks
	var timeout := AD_REQUEST_TIMEOUT_MSEC if _interstitial_state == InterstitialState.REQUESTED else AD_SHOWING_TIMEOUT_MSEC
	if elapsed < timeout or now < _ad_next_recovery_attempt_ticks:
		return
	_ad_next_recovery_attempt_ticks = now + AD_RECOVERY_RETRY_MSEC
	# REQUESTED pode cancelar; SHOWING só pode ser liberado por fechamento
	# nativo ou recuperação explicitamente confirmada como terminal.
	if _interstitial_state == InterstitialState.REQUESTED and _interstitial_adapter.cancel_interstitial(_active_ad_request_id):
		_mark_ad_request_canceled(_active_ad_request_id)
		_finish_ad_request(_active_ad_request_id)
		return
	_ad_recovery_needed = true
	_update_ad_status()
	# True significa que a camada nativa já desmontou a tela cheia e
	# impede qualquer apresentação atrasada deste request_id.
	if _interstitial_adapter.recover_interstitial(_active_ad_request_id):
		_mark_ad_request_canceled(_active_ad_request_id)
		_finish_ad_request(_active_ad_request_id)


func _physics_process(delta: float) -> void:
	if state != GameState.PLAYING:
		return

	var player_y_before := player_y
	var cpu_y_before := cpu_y
	var axis := Input.get_axis("ui_up", "ui_down") if match_mode != MatchMode.TWO_PLAYERS else 0.0
	if Input.is_key_pressed(KEY_W):
		axis -= 1.0
	if Input.is_key_pressed(KEY_S):
		axis += 1.0
	if not is_zero_approx(axis):
		_set_player_y(player_y + clampf(axis, -1.0, 1.0) * PLAYER_SPEED * delta)
	if match_mode == MatchMode.TWO_PLAYERS:
		var second_axis := Input.get_axis("ui_up", "ui_down")
		if not is_zero_approx(second_axis):
			_set_cpu_y(cpu_y + second_axis * PLAYER_SPEED * delta)

	if match_mode != MatchMode.TWO_PLAYERS:
		_update_cpu(delta)
	if _serve_countdown > 0.0:
		_serve_countdown -= delta
		if _serve_countdown <= 0.0:
			_launch_ball()
		queue_redraw()
		return

	_accelerate_ball(delta)
	# Passos curtos evitam atravessar as raquetes quando a bola estiver rápida.
	var ball_radius := _ball_radius()
	var substeps := maxi(1, ceili(ball_velocity.length() * delta / ball_radius))
	var step_delta := delta / float(substeps)
	for step_index in range(substeps):
		var start_progress := float(step_index) / float(substeps)
		var end_progress := float(step_index + 1) / float(substeps)
		var player_start := lerpf(player_y_before, player_y, start_progress)
		var player_end := lerpf(player_y_before, player_y, end_progress)
		var cpu_start := lerpf(cpu_y_before, cpu_y, start_progress)
		var cpu_end := lerpf(cpu_y_before, cpu_y, end_progress)
		if _advance_ball_substep(step_delta, player_start, player_end, cpu_start, cpu_end):
			queue_redraw()
			return

	_trail.push_front(ball_position)
	if _trail.size() > 12:
		_trail.pop_back()
	queue_redraw()


func _advance_ball_substep(step_delta: float, player_start: float, player_end: float, cpu_start: float, cpu_end: float) -> bool:
	## Resolve eventos na ordem temporal: parede, face/canto da raquete e gol.
	## Cada evento consome apenas seu tempo; o restante segue com nova direção.
	var elapsed := 0.0
	var remaining := step_delta
	var impacts := 0
	var radius := _ball_radius()
	var top := FIELD_MARGIN + radius
	var bottom := size.y - FIELD_MARGIN - radius
	while remaining > IMPACT_EPSILON and impacts < MAX_IMPACTS_PER_SUBSTEP:
		var start := ball_position
		var finish := start + ball_velocity * remaining
		var paddle_progress := elapsed / step_delta if step_delta > 0.0 else 0.0
		var current_player_y := lerpf(player_start, player_end, paddle_progress)
		var current_cpu_y := lerpf(cpu_start, cpu_end, paddle_progress)
		var first_t := 1.0 + IMPACT_EPSILON
		var event := 0 # 0=nada, 1=raquete, 2=parede, 3=gol
		var hit_player := false
		if ball_velocity.x < 0.0:
			var t := _sweep_paddle_contact(start, finish, PADDLE_MARGIN, current_player_y, player_end, true)
			if t >= 0.0 and t <= 1.0:
				first_t = t
				event = 1
				hit_player = true
		elif ball_velocity.x > 0.0:
			var t := _sweep_paddle_contact(start, finish, size.x - PADDLE_MARGIN, current_cpu_y, cpu_end, false)
			if t >= 0.0 and t <= 1.0:
				first_t = t
				event = 1

		# Empate é resolvido pela parede primeiro, depois pela raquete no t=0.
		if ball_velocity.y < -IMPACT_EPSILON and finish.y <= top:
			var t := clampf((top - start.y) / (finish.y - start.y), 0.0, 1.0)
			if t <= first_t + IMPACT_EPSILON:
				first_t = t
				event = 2
		elif ball_velocity.y > IMPACT_EPSILON and finish.y >= bottom:
			var t := clampf((bottom - start.y) / (finish.y - start.y), 0.0, 1.0)
			if t <= first_t + IMPACT_EPSILON:
				first_t = t
				event = 2

		if ball_velocity.x < -IMPACT_EPSILON and finish.x <= -radius:
			var t := clampf((-radius - start.x) / (finish.x - start.x), 0.0, 1.0)
			if t < first_t - IMPACT_EPSILON:
				first_t = t
				event = 3
		elif ball_velocity.x > IMPACT_EPSILON and finish.x >= size.x + radius:
			var t := clampf((size.x + radius - start.x) / (finish.x - start.x), 0.0, 1.0)
			if t < first_t - IMPACT_EPSILON:
				first_t = t
				event = 3

		if event == 0:
			ball_position = finish
			return false
		ball_position = start.lerp(finish, first_t)
		elapsed += remaining * first_t
		remaining *= 1.0 - first_t
		impacts += 1
		match event:
			1:
				var contact_progress := elapsed / step_delta if step_delta > 0.0 else 0.0
				var paddle_y: float = lerpf(player_start, player_end, contact_progress) if hit_player else lerpf(cpu_start, cpu_end, contact_progress)
				_separate_from_paddle_front(hit_player, paddle_y)
				_bounce_from_paddle(hit_player, paddle_y)
			2:
				ball_position.y = top if ball_velocity.y < 0.0 else bottom
				ball_velocity.y = -ball_velocity.y
				_play_sound("wall")
			3:
				_score_point(ball_velocity.x > 0.0)
				return true
	if remaining > IMPACT_EPSILON:
		# Falha defensiva explícita: não permitir atravessar paredes/raquetes
		# sem diagnóstico se um estado patológico gerar impactos infinitos.
		push_warning("Limite de impactos por subpasso alcançado; movimento interrompido nesta física.")
	return false


func _separate_from_paddle_front(is_player: bool, paddle_y: float) -> void:
	## Resolve sobreposições introduzidas por teleporte do toque imediato.
	## A bola não pode ser recuperada depois de cruzar a face da raquete.
	var radius := _ball_radius()
	var outside_y := maxf(0.0, absf(ball_position.y - paddle_y) - _paddle_height() * 0.5)
	var front_clearance := sqrt(maxf(0.0, radius * radius - outside_y * outside_y))
	if is_player:
		ball_position.x = maxf(ball_position.x, PADDLE_MARGIN + PADDLE_WIDTH * 0.5 + front_clearance)
	else:
		ball_position.x = minf(ball_position.x, size.x - PADDLE_MARGIN - PADDLE_WIDTH * 0.5 - front_clearance)



func _sweep_paddle_contact(start: Vector2, finish: Vector2, paddle_x: float, start_y: float, finish_y: float, is_player: bool) -> float:
	## Primeiro instante de contato entre um círculo em movimento e o retângulo
	## da raquete. Resolver no referencial da raquete inclui seu deslocamento.
	## A borda traseira não pode resgatar uma bola que já ultrapassou a face.
	var front_sign := 1.0 if is_player else -1.0
	var half_width := PADDLE_WIDTH * 0.5
	var half_height := _paddle_height() * 0.5
	var radius := _ball_radius()
	var p := Vector2(start.x - paddle_x, start.y - start_y)
	var d := Vector2(finish.x - start.x, finish.y - start.y - (finish_y - start_y))
	if front_sign * p.x < half_width - 0.0001 or front_sign * d.x >= 0.0:
		return -1.0
	# O toque é instantâneo: pode posicionar a raquete já sobre uma bola
	# ainda à frente da face. Contato válido apenas se ela estiver chegando.
	var nearest_on_rect := Vector2(clampf(p.x, -half_width, half_width), clampf(p.y, -half_height, half_height))
	if p.distance_squared_to(nearest_on_rect) <= radius * radius + IMPACT_EPSILON:
		return 0.0
	var nearest := 2.0
	# Face frontal reta.
	if absf(d.x) > 0.000001:
		var t := (front_sign * (half_width + radius) - p.x) / d.x
		if t >= 0.0 and t <= 1.0 and absf(p.y + d.y * t) <= half_height:
			nearest = t
	# Faces superior/inferior, apenas na metade da frente da raquete.
	if absf(d.y) > 0.000001:
		for side in [-1.0, 1.0]:
			if d.y * side >= 0.0:
				continue
			var t: float = (side * (half_height + radius) - p.y) / d.y
			var x: float = p.x + d.x * t
			if t >= 0.0 and t <= 1.0 and front_sign * x >= 0.0 and front_sign * x <= half_width + 0.0001:
				nearest = minf(nearest, t)
	# Cantos arredondados pela geometria real do círculo: distância euclidiana.
	var speed_squared := d.length_squared()
	if speed_squared > 0.00000001:
		for side in [-1.0, 1.0]:
			var corner: Vector2 = Vector2(front_sign * half_width, side * half_height)
			var offset := p - corner
			var b := 2.0 * offset.dot(d)
			var c := offset.length_squared() - radius * radius
			var discriminant := b * b - 4.0 * speed_squared * c
			if discriminant < 0.0 or b >= 0.0:
				continue
			var t := maxf(0.0, (-b - sqrt(discriminant)) / (2.0 * speed_squared))
			var contact := p + d * t
			if t <= 1.0 and front_sign * contact.x >= half_width - 0.0001 and side * contact.y >= half_height - 0.0001:
				nearest = minf(nearest, t)
	return nearest if nearest <= 1.0 else -1.0


func _input(event: InputEvent) -> void:
	# Release/cancel deve chegar mesmo quando a GUI consumiu o evento.
	if event is InputEventScreenTouch and (not event.pressed or event.canceled):
		_release_touch(event.index)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_BACK:
			# No Android o SO já entrega WM_GO_BACK_REQUEST; evitar
			# processar duas vezes o mesmo pressionamento (pausa + menu).
			if OS.get_name() != "Android":
				_handle_back_request()
				get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_P:
			if state == GameState.PLAYING or state == GameState.PAUSED:
				_toggle_pause()
				get_viewport().set_input_as_handled()
			elif state in [GameState.PRIVACY, GameState.SETTINGS, GameState.STATS, GameState.OTHER_GAMES]:
				_return_to_menu()
				get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ENTER and state == GameState.MENU and get_viewport().gui_get_focus_owner() == null:
			_start_match()
			get_viewport().set_input_as_handled()
			return


func _unhandled_input(event: InputEvent) -> void:
	if state != GameState.PLAYING:
		return

	if event is InputEventScreenTouch:
		if not event.pressed or event.canceled or _touch_owners.has(event.index):
			return
		if _pause_button.visible and _pause_button.get_global_rect().has_point(event.position):
			return
		var position: Vector2 = make_input_local(event).position
		var owner := 1 if match_mode == MatchMode.TWO_PLAYERS and position.x >= size.x * 0.5 else 0
		if _paddle_touch_ids[owner] != -1:
			return
		_touch_owners[event.index] = owner
		_paddle_touch_ids[owner] = event.index
		_set_paddle_owned_y(owner, position.y)
		get_viewport().set_input_as_handled()
		return
	elif event is InputEventScreenDrag:
		if not _touch_owners.has(event.index):
			return
		var owner: int = _touch_owners[event.index]
		_set_paddle_owned_y(owner, make_input_local(event).position.y)
		get_viewport().set_input_as_handled()
		return
	var is_mouse_move: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	is_mouse_move = is_mouse_move or (event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	if not is_mouse_move:
		return

	# A GUI recebe primeiro; o retangulo de pausa protege tambem eventos
	# que possam passar pela GUI em dispositivos especificos.
	if _pause_button.visible and _pause_button.get_global_rect().has_point(event.position):
		return
	var local_event := make_input_local(event)
	_set_touch_paddle(local_event.position)
	get_viewport().set_input_as_handled()


func _set_paddle_owned_y(owner: int, target_y: float) -> void:
	if owner == 1:
		_set_cpu_y(target_y)
	else:
		_set_player_y(target_y)


func _release_touch(index: int) -> void:
	if not _touch_owners.has(index):
		return
	var owner: int = _touch_owners[index]
	_touch_owners.erase(index)
	_paddle_touch_ids[owner] = -1


func _clear_touch_captures() -> void:
	_touch_owners.clear()
	_paddle_touch_ids[0] = -1
	_paddle_touch_ids[1] = -1


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_back_request()
		return
	if what == NOTIFICATION_APPLICATION_RESUMED and _active_ad_request_id != -1:
		_ad_next_recovery_attempt_ticks = 0
		_process(0.0)
	if what == NOTIFICATION_APPLICATION_RESUMED and is_instance_valid(_billing_adapter):
		_billing_adapter.refresh()
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT] and state == GameState.PLAYING:
		state = GameState.PAUSED
		_clear_touch_captures()
		_show_interface()
		queue_redraw()


func _handle_back_request() -> void:
	match state:
		GameState.PLAYING:
			_toggle_pause()
		GameState.MENU:
			get_tree().quit()
		_:
			_return_to_menu()


func _on_resized() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	_set_player_y(player_y)
	_set_cpu_y(cpu_y)
	_cpu_target_y = clampf(_cpu_target_y, FIELD_MARGIN, size.y - FIELD_MARGIN)
	ball_position = ball_position.clamp(Vector2.ZERO, size)
	if state == GameState.MENU:
		ball_position = size * 0.5
	queue_redraw()


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

	_draw_paddle(Vector2(PADDLE_MARGIN, player_y), THEMES[theme_index]["player"])
	_draw_paddle(Vector2(w - PADDLE_MARGIN, cpu_y), THEMES[theme_index]["cpu"])
	var radius := _ball_radius()
	for i in range(_trail.size() - 1, -1, -1):
		var opacity := (1.0 - float(i) / 12.0) * 0.22
		draw_circle(_trail[i], maxf(2.0, radius - float(i) * 0.5), Color(1, 1, 1, opacity))
	draw_circle(ball_position, radius + 6.0, Color(1, 1, 1, 0.12))
	draw_circle(ball_position, radius, THEMES[theme_index]["ball"])

	_draw_centered(str(survival_hits).pad_zeros(2) if match_mode == MatchMode.SURVIVAL else str(player_score).pad_zeros(2), Vector2(w * 0.42, 79), 54, CYAN)
	_draw_centered(str(cpu_score).pad_zeros(2), Vector2(w * 0.58, 79), 54, PINK)
	_draw_centered("REBATIDAS" if match_mode == MatchMode.SURVIVAL else "P1" if match_mode == MatchMode.TWO_PLAYERS else "VOCÊ", Vector2(w * 0.42, 106), 13, MUTED)
	_draw_centered("P2" if match_mode == MatchMode.TWO_PLAYERS else "COMPUTADOR", Vector2(w * 0.58, 106), 13, MUTED)
	if state == GameState.PLAYING:
		var speed_label := "PRÓXIMA BOLA" if _serve_countdown > 0.0 else "BOLA"
		var speed_caption := "%s %.1fx" % [speed_label, _displayed_ball_speed_ratio()]
		_draw_centered("2 JOGADORES   •   %s" % speed_caption if match_mode == MatchMode.TWO_PLAYERS else "NÍVEL %s   •   %s" % [DIFFICULTIES[difficulty], speed_caption], Vector2(w * 0.5, 143), 14, MUTED)
		_draw_centered("CADA JOGADOR CONTROLA SUA METADE" if match_mode == MatchMode.TWO_PLAYERS else "DESLIZE O DEDO PARA MOVER A RAQUETE", Vector2(w * 0.5, h - 31), 14, MUTED)
		if _serve_countdown > 0.0:
			_draw_centered("PREPARE-SE", Vector2(w * 0.5, h * 0.39), 26, WHITE)


func _displayed_ball_speed_ratio() -> float:
	var speed: float = _serve_speed if state == GameState.PLAYING and _serve_countdown > 0.0 else ball_velocity.length()
	return maxf(1.0, speed / BASE_BALL_SPEED)


func _draw_paddle(center: Vector2, color: Color) -> void:
	var paddle_height := _paddle_height()
	var rectangle := Rect2(center - Vector2(PADDLE_WIDTH, paddle_height) * 0.5, Vector2(PADDLE_WIDTH, paddle_height))
	draw_rect(rectangle.grow(8.0), Color(color.r, color.g, color.b, 0.09))
	draw_rect(rectangle.grow(3.0), Color(color.r, color.g, color.b, 0.21))
	draw_rect(rectangle, color)
	draw_rect(Rect2(rectangle.position + Vector2(3, 7), Vector2(3, paddle_height - 14)), Color(1, 1, 1, 0.24))


func _draw_centered(message: String, baseline: Vector2, font_size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(baseline.x - width * 0.5, baseline.y), message, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _start_match() -> void:
	if _active_ad_request_id != -1:
		return
	_on_ad_verification_timeout()
	_break_streak_on_abandon()
	# Uma revogação recebida durante a partida anterior só entra na
	# próxima partida; não mudar regras/raquetes em pleno rally.
	_settle_pro_transition(true)
	_match_id += 1
	_clear_touch_captures()
	_interstitial_attempted_this_match = false
	player_score = 0
	cpu_score = 0
	player_won = false
	survival_hits = 0
	_reset_positions()
	state = GameState.PLAYING
	_reset_round(1.0 if randf() > 0.5 else -1.0)
	if is_pro and match_mode == MatchMode.CLASSIC:
		_active_classic_match = true
		_save_pro_stats()
	_show_interface()
	queue_redraw()


func _select_difficulty(value: int) -> void:
	difficulty = clampi(value, 0, 2)
	for i in range(_difficulty_buttons.size()):
		var selected := i == difficulty
		_style_button(_difficulty_buttons[i], CYAN if selected else GRID, selected)
	_play_sound("wall")


func _set_player_y(target: float) -> void:
	player_y = clampf(target, FIELD_MARGIN + _paddle_height() * 0.5, size.y - FIELD_MARGIN - _paddle_height() * 0.5)


func _set_cpu_y(target: float) -> void:
	cpu_y = clampf(target, FIELD_MARGIN + _paddle_height() * 0.5, size.y - FIELD_MARGIN - _paddle_height() * 0.5)


func _set_touch_paddle(position: Vector2) -> void:
	if match_mode == MatchMode.TWO_PLAYERS and position.x >= size.x * 0.5:
		_set_cpu_y(position.y)
	else:
		_set_player_y(position.y)


func _ball_radius() -> float:
	return BALL_RADIUS * ball_scale


func _paddle_height() -> float:
	return PADDLE_HEIGHT * paddle_scale


func _cpu_reach_factor() -> float:
	# Raquetes/bolas pequenas reduzem a margem de colisao. Compensar parte
	# dessa perda evita mudar a dificuldade da IA ao personalizar a Pro.
	var standard_margin := PADDLE_HEIGHT * 0.5 + BALL_RADIUS
	var actual_margin := _paddle_height() * 0.5 + _ball_radius()
	return clampf(standard_margin / maxf(actual_margin, 1.0), 1.0, 1.25)


func _cpu_aim_error() -> float:
	# O erro da mira deve acompanhar a zona de acerto, nao ter pixels fixos.
	var standard_margin := PADDLE_HEIGHT * 0.5 + BALL_RADIUS
	var actual_margin := _paddle_height() * 0.5 + _ball_radius()
	return CPU_ERROR[difficulty] * minf(1.0, actual_margin / standard_margin)


func _cpu_reaction_delay() -> float:
	return CPU_REACTION[difficulty] / _cpu_reach_factor()


func _reset_positions() -> void:
	player_y = size.y * 0.5
	cpu_y = size.y * 0.5
	_reset_ball_for_serve()


func _reset_ball_for_serve() -> void:
	# Pontos e novos saques não mudam a posição nem a posse dos dedos.
	_cpu_target_y = cpu_y
	_cpu_aim_bias = 0.0
	ball_position = size * 0.5
	ball_velocity = Vector2.ZERO
	_trail.clear()


func _reset_round(direction: float, next_serve_speed: float = BASE_BALL_SPEED) -> void:
	_reset_ball_for_serve()
	_serve_direction = direction
	_serve_speed = clampf(next_serve_speed, BASE_BALL_SPEED, MAX_BALL_SPEED)
	_serve_countdown = 0.9
	_cpu_reaction_timer = 0.0


func _launch_ball() -> void:
	var angle := randf_range(-0.55, 0.55)
	ball_velocity = Vector2(cos(angle) * _serve_direction, sin(angle)) * _serve_speed
	if _serve_direction > 0.0:
		_cpu_aim_bias = randf_range(-_cpu_aim_error(), _cpu_aim_error())
		_cpu_reaction_timer = _cpu_reaction_delay()
	_play_sound("serve")


func _accelerate_ball(delta: float) -> void:
	var speed := ball_velocity.length()
	if speed > 0.0 and speed < MAX_BALL_SPEED:
		ball_velocity *= minf(speed + BALL_ACCELERATION * delta, MAX_BALL_SPEED) / speed


func _bounce_from_paddle(is_player: bool, contact_paddle_y: float = -1.0) -> void:
	var paddle_center := contact_paddle_y if contact_paddle_y >= 0.0 else player_y if is_player else cpu_y
	var offset := clampf((ball_position.y - paddle_center) / (_paddle_height() * 0.5), -1.0, 1.0)
	var angle := offset * 0.98
	var direction := 1.0 if is_player else -1.0
	var speed := minf(ball_velocity.length() + PADDLE_SPEED_BONUS, MAX_BALL_SPEED)
	ball_velocity = Vector2(direction * cos(angle), sin(angle)) * speed
	if is_player and match_mode == MatchMode.SURVIVAL:
		survival_hits += 1
	if is_player:
		# O erro é sorteado uma vez por devolução, sem teletransporte da mira.
		_cpu_aim_bias = randf_range(-_cpu_aim_error(), _cpu_aim_error())
		_cpu_reaction_timer = _cpu_reaction_delay()
	else:
		_cpu_reaction_timer = 0.0
	_play_sound("paddle")


func _update_cpu(delta: float) -> void:
	_cpu_reaction_timer -= delta
	if _cpu_reaction_timer <= 0.0:
		_cpu_reaction_timer = _cpu_reaction_delay()
		if ball_velocity.x > 0.0:
			# Prever o impacto na FACE da raquete, considerando o raio real
			# da bola. A previsao antiga mirava no centro da raquete.
			var destination_x := size.x - PADDLE_MARGIN - PADDLE_WIDTH * 0.5 - _ball_radius()
			var flight_time := maxf(0.0, (destination_x - ball_position.x) / ball_velocity.x)
			flight_time = minf(flight_time, CPU_LOOKAHEAD[difficulty] * _cpu_reach_factor())
			var top := FIELD_MARGIN + _ball_radius()
			var span := maxf(1.0, size.y - 2.0 * top)
			var projected_y := ball_position.y + flight_time * ball_velocity.y
			var mirrored := fposmod(projected_y - top, span * 2.0)
			_cpu_target_y = top + (mirrored if mirrored <= span else span * 2.0 - mirrored)
			_cpu_target_y += _cpu_aim_bias
		else:
			_cpu_target_y = size.y * 0.5 + randf_range(-30.0, 30.0)
	var step: float = CPU_SPEEDS[difficulty] * _cpu_reach_factor() * delta
	cpu_y = move_toward(cpu_y, clampf(_cpu_target_y, FIELD_MARGIN + _paddle_height() * 0.5, size.y - FIELD_MARGIN - _paddle_height() * 0.5), step)


func _score_point(for_player: bool) -> void:
	if state != GameState.PLAYING:
		return
	if match_mode == MatchMode.SURVIVAL:
		_play_sound("point")
		if for_player:
			# Marcar ponto não reduz a pressão: a próxima bola mantém a
			# velocidade alcançada nesta tentativa de Sobrevivência.
			_reset_round(-1.0, ball_velocity.length())
		else:
			cpu_score = 1
			_complete_match(false)
		return
	if for_player:
		player_score += 1
	else:
		cpu_score += 1
	_play_sound("point")
	if player_score >= point_limit or cpu_score >= point_limit:
		_complete_match(player_score >= point_limit)
	else:
		_reset_round(-1.0 if for_player else 1.0)


func _complete_match(won: bool) -> void:
	if state != GameState.PLAYING or _finished_match_id == _match_id:
		return
	_finished_match_id = _match_id
	_clear_touch_captures()
	player_won = won
	state = GameState.FINISHED
	if match_mode == MatchMode.SURVIVAL:
		_finish_title.text = "FIM DA SOBREVIVÊNCIA"
		_finish_score.text = "%d REBATIDAS" % survival_hits
	elif match_mode == MatchMode.TWO_PLAYERS:
		_finish_title.text = "JOGADOR 1 VENCEU!" if won else "JOGADOR 2 VENCEU!"
		_finish_score.text = "%02d   :   %02d" % [player_score, cpu_score]
	else:
		_finish_title.text = "VOCÊ VENCEU!" if won else "COMPUTADOR VENCEU!"
		_finish_score.text = "%02d   :   %02d" % [player_score, cpu_score]
	if is_pro:
		_record_pro_stats(won)
	elif entitlement_status == EntitlementStatus.FREE_CONFIRMED:
		_ad_policy.note_finished_match()
		if _ad_policy.save_state(ad_policy_file) != OK:
			push_warning("Não foi possível guardar o limite local de anúncios.")
	_show_interface()
	queue_redraw()
	if _can_check_ads_after_match():
		# Oportunidade exclusiva de transição: após o placar final aparecer.
		call_deferred("_try_show_interstitial_after_match", _match_id)


func set_ad_consent_granted(granted: bool) -> void:
	## O SDK/gerenciador de consentimento futuro deve chamar isto depois da
	## autorização real. A política começa SEM consentimento por segurança.
	_ads_consent_granted = granted
	if not granted:
		_on_ad_verification_timeout()
	_refresh_ads_allowed()


func _ads_allowed_now() -> bool:
	return _can_check_ads_after_match() and _session_free_confirmations >= FREE_CONFIRMATIONS_FOR_ADS


func _can_check_ads_after_match() -> bool:
	# Uma primeira consulta negativa apenas habilita a rechecagem; não
	# permite sequer pré-carregar anúncios. A segunda deve ser de outra
	# solicitação real à Play, identificada por query_id na mesma sessão.
	return entitlement_status == EntitlementStatus.FREE_CONFIRMED and not is_pro \
			and _ads_consent_granted and _session_free_confirmations >= 1


func _refresh_ads_allowed() -> void:
	if is_instance_valid(_interstitial_adapter):
		_interstitial_adapter.set_ads_allowed(_ads_allowed_now())


func set_interstitial_adapter(adapter: Node) -> void:
	## Contrato do adaptador: is_interstitial_loaded() -> bool,
	## show_interstitial(id) -> bool, cancel_interstitial(id) -> bool,
	## recover_interstitial(id) -> bool [garantia nativa terminal],
	## set_ads_allowed(bool) proíbe INCLUSIVE pré-carregamento sem
	## titularidade Free confirmada na sessão e consentimento explícito,
	## sinais interstitial_opened/impression/closed/failed(id).
	## Só conectar ao terminar o SDK/consentimento. Com Pro ativo,
	## não solicitar anúncios, mas conservar o adaptador para reembolso.
	if _interstitial_adapter != adapter:
		_on_ad_verification_timeout()
	if _active_ad_request_id != -1:
		if is_instance_valid(_interstitial_adapter) and not _interstitial_adapter.cancel_interstitial(_active_ad_request_id):
			push_warning("Não é seguro substituir o adaptador durante uma exibição pendente.")
			return
		_mark_ad_request_canceled(_active_ad_request_id)
		_finish_ad_request(_active_ad_request_id)
	if is_instance_valid(_interstitial_adapter):
		_interstitial_adapter.set_ads_allowed(false)
		for connection in [
			["interstitial_opened", Callable(self, "_on_interstitial_opened")],
			["interstitial_impression", Callable(self, "_on_interstitial_impression")],
			["interstitial_closed", Callable(self, "_on_interstitial_closed")],
			["interstitial_failed", Callable(self, "_on_interstitial_failed")],
		]:
			if _interstitial_adapter.is_connected(connection[0], connection[1]):
				_interstitial_adapter.disconnect(connection[0], connection[1])
	_interstitial_adapter = null
	if adapter == null:
		return
	if not adapter.has_signal("interstitial_opened") or not adapter.has_signal("interstitial_impression") \
			or not adapter.has_signal("interstitial_closed") or not adapter.has_signal("interstitial_failed") \
			or not adapter.has_method("is_interstitial_loaded") or not adapter.has_method("show_interstitial") \
			or not adapter.has_method("cancel_interstitial") or not adapter.has_method("recover_interstitial") \
			or not adapter.has_method("set_ads_allowed"):
		push_warning("Adaptador de intersticiais inválido; publicidade desativada.")
		return
	_interstitial_adapter = adapter
	_interstitial_adapter.set_ads_allowed(_ads_allowed_now())
	_interstitial_adapter.interstitial_opened.connect(_on_interstitial_opened)
	_interstitial_adapter.interstitial_impression.connect(_on_interstitial_impression)
	_interstitial_adapter.interstitial_closed.connect(_on_interstitial_closed)
	_interstitial_adapter.interstitial_failed.connect(_on_interstitial_failed)


func _try_show_interstitial_after_match(match_id: int = -1) -> void:
	# Nunca iniciar anúncio durante a partida, em pausa ou no menu.
	if not _can_check_ads_after_match() or state != GameState.FINISHED or _interstitial_attempted_this_match \
			or _active_ad_request_id != -1 or (match_id >= 0 and match_id != _match_id):
		return
	if not is_instance_valid(_interstitial_adapter):
		return
	if not _ad_policy.can_show(_ad_now_msec()) \
			or (_ads_allowed_now() and not _interstitial_adapter.is_interstitial_loaded()):
		return
	# Falhar fechado: se a Play não responder a uma consulta NOVA e exclusiva,
	# nenhum anúncio será solicitado, mesmo se o cache disser Free.
	if not is_instance_valid(_billing_adapter) or not _billing_adapter.has_method("verify_free_before_ad") \
			or not _billing_adapter.has_signal("ad_verification_result"):
		return
	_interstitial_attempted_this_match = true
	_ad_verification_sequence += 1
	_ad_verification_id = _ad_verification_sequence
	_ad_verification_match_id = _match_id
	_ad_verification_start_ticks = Time.get_ticks_msec()
	_billing_adapter.verify_free_before_ad(_ad_verification_id)


func _on_ad_verification_timeout() -> void:
	if _ad_verification_id == -1:
		return
	var old_id := _ad_verification_id
	_ad_verification_id = -1
	_ad_verification_match_id = -1
	if is_instance_valid(_billing_adapter) and _billing_adapter.has_method("cancel_ad_verification"):
		_billing_adapter.cancel_ad_verification(old_id)


func _on_ad_verification_result(request_id: int, confirmed_free: bool) -> void:
	if request_id != _ad_verification_id:
		return
	var match_id := _ad_verification_match_id
	_ad_verification_id = -1
	_ad_verification_match_id = -1
	if not confirmed_free or match_id != _match_id or state != GameState.FINISHED \
			or not _ads_allowed_now() or _active_ad_request_id != -1 \
			or not is_instance_valid(_interstitial_adapter) or not _interstitial_adapter.is_interstitial_loaded() \
			or not _ad_policy.can_show(_ad_now_msec()):
		return
	# Ao contrário da verificação, só a solicitação nativa efetiva bloqueia
	# os botões. O jogador pode navegar enquanto a Play está consultando.
	_ad_request_sequence += 1
	var interstitial_request_id := _ad_request_sequence
	_ad_requests[interstitial_request_id] = {"impressed": false, "canceled": false, "failed": false}
	_active_ad_request_id = interstitial_request_id
	_interstitial_state = InterstitialState.REQUESTED
	_ad_requested_at_ticks = Time.get_ticks_msec()
	_ad_next_recovery_attempt_ticks = 0
	_ad_recovery_needed = false
	_set_ad_buttons_busy(true)
	if not _interstitial_adapter.show_interstitial(interstitial_request_id):
		_on_interstitial_failed(interstitial_request_id)
	# Manter somente um histórico recente de IDs para ignorar callbacks
	# duplicados/antigos sem acumular dados durante meses de partidas.
	if _ad_requests.size() > 32:
		var ids := _ad_requests.keys()
		ids.sort()
		for old_id in ids.slice(0, ids.size() - 32):
			_ad_requests.erase(old_id)


func _on_interstitial_opened(request_id: int) -> void:
	if request_id == _active_ad_request_id and _interstitial_state == InterstitialState.REQUESTED:
		_interstitial_state = InterstitialState.SHOWING
		_update_ad_status()


func _on_interstitial_impression(request_id: int) -> void:
	# Aceita impressão de uma solicitação real mesmo após close/navegação;
	# ID impede que callback antigo seja atribuído a outra tentativa.
	if not _ad_requests.has(request_id):
		return
	var record: Dictionary = _ad_requests[request_id]
	if record["impressed"] or record["canceled"] or record["failed"]:
		return
	if request_id == _active_ad_request_id:
		# O SDK pode sinalizar impressão antes do callback de abertura.
		_interstitial_state = InterstitialState.SHOWING
		_update_ad_status()
	record["impressed"] = true
	_ad_requests[request_id] = record
	_ad_policy.record_impression(_ad_now_msec())
	if _ad_policy.save_state(ad_policy_file) != OK:
		push_warning("Não foi possível guardar a impressão do anúncio.")


func _on_interstitial_closed(request_id: int) -> void:
	_finish_ad_request(request_id)


func _on_interstitial_failed(request_id: int) -> void:
	if not _ad_requests.has(request_id):
		return
	var record: Dictionary = _ad_requests[request_id]
	if not record["impressed"]:
		record["failed"] = true
		_ad_requests[request_id] = record
	_finish_ad_request(request_id)


func _mark_ad_request_canceled(request_id: int) -> void:
	if _ad_requests.has(request_id):
		var record: Dictionary = _ad_requests[request_id]
		record["canceled"] = true
		_ad_requests[request_id] = record


func _finish_ad_request(request_id: int) -> void:
	if request_id != _active_ad_request_id:
		return
	_active_ad_request_id = -1
	_interstitial_state = InterstitialState.IDLE
	_ad_recovery_needed = false
	_ad_next_recovery_attempt_ticks = 0
	_set_ad_buttons_busy(false)
	if _pending_pro_revocation and state not in [GameState.PLAYING, GameState.PAUSED]:
		_settle_pro_transition()


func _set_ad_buttons_busy(busy: bool) -> void:
	if is_instance_valid(_finish_again_button):
		_finish_again_button.disabled = busy
	if is_instance_valid(_finish_exit_button):
		_finish_exit_button.disabled = busy
	_update_ad_status()


func _update_ad_status() -> void:
	if not is_instance_valid(_ad_status_label):
		return
	var pending := _active_ad_request_id != -1
	_ad_status_label.visible = pending
	_ad_safe_exit_button.visible = pending and _ad_recovery_needed
	if pending:
		_ad_status_label.text = "SEM RESPOSTA DO ANÚNCIO — TENTE FECHAR O JOGO" if _ad_recovery_needed else "ANÚNCIO EM EXIBIÇÃO" if _interstitial_state == InterstitialState.SHOWING else "AGUARDANDO ANÚNCIO..."


func _quit_after_ad_failure() -> void:
	# Saída de emergência: nunca retomar gameplay se o SDK não assegurar
	# que o pedido foi encerrado. O jogador pode abrir o app novamente.
	get_tree().quit()


func _ad_now_msec() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)


func _toggle_pause() -> void:
	if state == GameState.PLAYING:
		state = GameState.PAUSED
	elif state == GameState.PAUSED:
		state = GameState.PLAYING
	_clear_touch_captures()
	_show_interface()
	queue_redraw()


func _return_to_menu() -> void:
	if _active_ad_request_id != -1:
		return
	_on_ad_verification_timeout()
	_break_streak_on_abandon()
	_clear_touch_captures()
	state = GameState.MENU
	_settle_pro_transition()
	player_score = 0
	cpu_score = 0
	_reset_positions()
	_show_interface()
	queue_redraw()


func _open_privacy() -> void:
	state = GameState.PRIVACY
	_show_interface()
	queue_redraw()


func _open_settings() -> void:
	if not is_pro:
		return
	state = GameState.SETTINGS
	_show_interface()


func _open_stats() -> void:
	if not is_pro:
		return
	_refresh_stats()
	state = GameState.STATS
	_show_interface()


func set_billing_adapter(adapter: Node) -> void:
	## Adaptador injetável: além dos sinais antigos, checkout_changed(bool)
	## e ad_verification_result(id, free). Métodos: start/purchase/refresh,
	## restore() e verify_free_before_ad(id), cancel_ad_verification(id).
	if _billing_adapter == adapter:
		return
	_on_ad_verification_timeout()
	_session_free_confirmations = 0
	_last_free_query_id = 0
	if not is_pro:
		entitlement_status = EntitlementStatus.UNKNOWN
	_refresh_ads_allowed()
	if is_instance_valid(_billing_adapter):
		for connection in [
			["entitlement_checked", Callable(self, "_on_entitlement_checked")],
			["purchase_pending", Callable(self, "_on_purchase_pending")],
			["checkout_changed", Callable(self, "_on_checkout_changed")],
			["ad_verification_result", Callable(self, "_on_ad_verification_result")],
			["entitlement_query_completed", Callable(self, "_on_entitlement_query_completed")],
			["entitlement_verification_failed", Callable(self, "_on_entitlement_verification_failed")],
			["availability_changed", Callable(self, "_on_billing_availability")],
			["purchase_message", Callable(self, "_on_billing_message")],
			["price_changed", Callable(self, "_on_pro_price_changed")],
		]:
			if _billing_adapter.has_signal(connection[0]) and _billing_adapter.is_connected(connection[0], connection[1]):
				_billing_adapter.disconnect(connection[0], connection[1])
		if _billing_adapter.get_parent() == self:
			_billing_adapter.queue_free()
	_billing_adapter = null
	_billing_purchase_available = false
	_pro_price = ""
	if adapter == null:
		_update_pro_ui()
		return
	if not adapter.has_signal("entitlement_checked") or not adapter.has_signal("availability_changed") \
			or not adapter.has_signal("purchase_message") or not adapter.has_method("start") \
			or not adapter.has_method("purchase") or not adapter.has_method("refresh"):
		push_warning("Adaptador de compras inválido. A compra Pro não estará disponível.")
		return
	_billing_adapter = adapter
	if adapter.get_parent() == null:
		add_child(adapter)
	adapter.entitlement_checked.connect(_on_entitlement_checked)
	if adapter.has_signal("purchase_pending"):
		adapter.purchase_pending.connect(_on_purchase_pending)
	if adapter.has_signal("checkout_changed"):
		adapter.checkout_changed.connect(_on_checkout_changed)
	if adapter.has_signal("ad_verification_result"):
		adapter.ad_verification_result.connect(_on_ad_verification_result)
	if adapter.has_signal("entitlement_query_completed"):
		adapter.entitlement_query_completed.connect(_on_entitlement_query_completed)
	if adapter.has_signal("entitlement_verification_failed"):
		adapter.entitlement_verification_failed.connect(_on_entitlement_verification_failed)
	adapter.availability_changed.connect(_on_billing_availability)
	adapter.purchase_message.connect(_on_billing_message)
	if adapter.has_signal("price_changed"):
		adapter.price_changed.connect(_on_pro_price_changed)
	_update_pro_ui()
	adapter.start()


func _save_pro_entitlement_cache() -> void:
	var config := ConfigFile.new()
	config.set_value("purchase", "pro_owned", _cached_pro_owned)
	config.set_value("purchase", "last_positive_unix", _last_positive_unix)
	config.set_value("purchase", "negative_first_unix", _negative_first_unix)
	config.set_value("purchase", "negative_last_unix", _negative_last_unix)
	config.set_value("purchase", "negative_count", _negative_count)
	if _save_config_with_backup(config, pro_entitlement_file) != OK:
		push_warning("Não foi possível armazenar o estado de confirmação Pro.")


func _on_entitlement_checked(owned: bool) -> void:
	# Uma resposta negativa isolada não apaga uma compra previamente
	# confirmada. Exigir 2 negativas separadas por >=24h e pelo menos 48h
	# desde a primeira, preservando o histórico entre sessões.
	var now := int(Time.get_unix_time_from_system())
	if owned:
		_on_ad_verification_timeout()
		_session_free_confirmations = 0
		_last_free_query_id = 0
		_cached_pro_owned = true
		_last_positive_unix = now
		_negative_first_unix = 0
		_negative_last_unix = 0
		_negative_count = 0
		entitlement_status = EntitlementStatus.PRO
		_save_pro_entitlement_cache()
		_apply_pro_entitlement(true)
		return
	if entitlement_status == EntitlementStatus.CHECKOUT:
		return
	if _cached_pro_owned:
		if _negative_first_unix <= 0 or now < _negative_first_unix:
			_negative_first_unix = now
			_negative_last_unix = now
			_negative_count = 1
		elif now - _negative_last_unix >= PRO_NEGATIVE_INTERVAL_SEC:
			_negative_count = mini(_negative_count + 1, 100)
			_negative_last_unix = now
		if _negative_count < 2 or now - _negative_first_unix < PRO_REVOKE_GRACE_SEC:
			entitlement_status = EntitlementStatus.PRO
			_save_pro_entitlement_cache()
			_billing_status = "PRO MANTIDO: confira a conta Google da compra ou toque RESTAURAR."
			_refresh_ads_allowed()
			_update_pro_ui()
			return
	# Revogação confirmada depois da carência, ou instalação Free que nunca
	# teve Pro. Só agora a sessão está confirmada como sem compra.
	_cached_pro_owned = false
	entitlement_status = EntitlementStatus.FREE_CONFIRMED
	_save_pro_entitlement_cache()
	_apply_pro_entitlement(false)


func _on_entitlement_query_completed(query_id: int, owned: bool) -> void:
	if owned or query_id <= _last_free_query_id:
		return
	_last_free_query_id = query_id
	if entitlement_status != EntitlementStatus.FREE_CONFIRMED or is_pro:
		return
	_session_free_confirmations = mini(_session_free_confirmations + 1, FREE_CONFIRMATIONS_FOR_ADS)
	_refresh_ads_allowed()


func _on_entitlement_verification_failed() -> void:
	# Qualquer falha/reconexão invalida o par de confirmações Free. Falhar
	# fechado protege usuários que compraram Pro em outro dispositivo.
	if is_pro:
		return
	_session_free_confirmations = 0
	_last_free_query_id = 0
	if entitlement_status == EntitlementStatus.FREE_CONFIRMED:
		entitlement_status = EntitlementStatus.UNKNOWN
	_on_ad_verification_timeout()
	_refresh_ads_allowed()
	_update_pro_ui()


func _load_cached_pro_entitlement() -> void:
	# Cache para evitar que os anúncios voltem durante uma queda da Play Store.
	# Mesmo um cache Free NÃO autoriza anúncios: exige verificação nesta sessão.
	var config := _load_config_with_backup(pro_entitlement_file)
	if config != null:
		_cached_pro_owned = bool(config.get_value("purchase", "pro_owned", false))
		_last_positive_unix = maxi(0, int(config.get_value("purchase", "last_positive_unix", 0)))
		_negative_first_unix = maxi(0, int(config.get_value("purchase", "negative_first_unix", 0)))
		_negative_last_unix = maxi(0, int(config.get_value("purchase", "negative_last_unix", 0)))
		_negative_count = clampi(int(config.get_value("purchase", "negative_count", 0)), 0, 100)
		is_pro = _cached_pro_owned
	entitlement_status = EntitlementStatus.PRO if is_pro else EntitlementStatus.UNKNOWN
	_refresh_ads_allowed()


func _on_purchase_pending(pending: bool) -> void:
	# Uma compra ainda não aprovada não libera funcionalidades, mas suprime
	# qualquer carga ou impressão publicitária até uma resposta definitiva.
	if is_pro:
		return
	_session_free_confirmations = 0
	_last_free_query_id = 0
	if pending:
		_on_ad_verification_timeout()
	entitlement_status = EntitlementStatus.PENDING if pending else EntitlementStatus.UNKNOWN
	_billing_status = "PAGAMENTO EM ANÁLISE — sem anúncios enquanto estiver pendente." if pending else "Verificando compra na conta Google..."
	_refresh_ads_allowed()
	_update_pro_ui()


func _on_checkout_changed(in_progress: bool) -> void:
	if is_pro:
		return
	_session_free_confirmations = 0
	_last_free_query_id = 0
	if in_progress:
		_on_ad_verification_timeout()
	entitlement_status = EntitlementStatus.CHECKOUT if in_progress else EntitlementStatus.UNKNOWN
	_billing_status = "COMPRA EM ANDAMENTO — aguardando a Play Store." if in_progress else "Verificando compra na conta Google..."
	_refresh_ads_allowed()
	_update_pro_ui()


func _apply_pro_entitlement(owned: bool, settle_between_matches: bool = false) -> void:
	if owned:
		_pending_pro_revocation = false
	elif is_pro and ((state in [GameState.PLAYING, GameState.PAUSED] and not settle_between_matches) or _active_ad_request_id != -1):
		# A titularidade já foi persistida como revogada. A experiência
		# iniciada permanece íntegra até o menu/fechamento do anúncio.
		_pending_pro_revocation = true
		_pending_pro_preferences = false
		_billing_status = "Pro não confirmado; a partida atual será preservada."
		_refresh_ads_allowed()
		_update_pro_ui()
		return
	if is_pro != owned:
		is_pro = owned
		if owned:
			if state in [GameState.PLAYING, GameState.PAUSED]:
				# A restauração assíncrona não muda o tamanho das raquetes
				# nem as regras no meio de um rally.
				_pending_pro_preferences = true
			else:
				_load_pro_settings()
				_load_pro_stats()
				_sync_pro_controls()
			# Um adaptador existente fica conectado, mas Pro nunca solicita
			# anúncios. Se houver reembolso, a versão Free o reutiliza.
		else:
			_pending_pro_revocation = false
			_pending_pro_preferences = false
			match_mode = MatchMode.CLASSIC
			point_limit = WIN_SCORE
			ball_scale = 1.0
			paddle_scale = 1.0
			theme_index = 0
			_sync_pro_controls()
			if state in [GameState.SETTINGS, GameState.STATS]:
				state = GameState.MENU
	_billing_status = "PRO ATIVO — SEM ANÚNCIOS" if is_pro else "Pro disponível como compra única na Play Store."
	_refresh_ads_allowed()
	_update_pro_ui()
	_show_interface()
	queue_redraw()


func _settle_pro_transition(between_matches: bool = false) -> void:
	if _active_ad_request_id != -1:
		return
	if _pending_pro_revocation:
		_pending_pro_revocation = false
		_apply_pro_entitlement(false, between_matches)
	elif _pending_pro_preferences and is_pro:
		_load_pro_settings()
		_load_pro_stats()
		_sync_pro_controls()
	_pending_pro_preferences = false


func _sync_pro_controls() -> void:
	if is_instance_valid(_ball_slider):
		_ball_slider.set_value_no_signal(ball_scale * 100.0)
		_paddle_slider.set_value_no_signal(paddle_scale * 100.0)
		_ball_value_label.text = "TAMANHO DA BOLA: %d%%" % roundi(ball_scale * 100.0)
		_paddle_value_label.text = "ALTURA DAS RAQUETES: %d%%" % roundi(paddle_scale * 100.0)
		_theme_selector.select(theme_index)
		_mode_selector.select(int(match_mode))
		_points_selector.select(_points_index())


func _on_billing_availability(available: bool) -> void:
	_billing_purchase_available = available
	_update_pro_ui()


func _on_billing_message(message: String) -> void:
	_billing_status = message
	_update_pro_ui()


func _on_pro_price_changed(formatted_price: String) -> void:
	_pro_price = formatted_price
	_update_pro_ui()


func _buy_pro() -> void:
	if entitlement_status == EntitlementStatus.FREE_CONFIRMED and not is_pro \
			and _billing_purchase_available and is_instance_valid(_billing_adapter):
		_billing_adapter.purchase()


func _restore_purchase() -> void:
	if is_instance_valid(_billing_adapter):
		if _billing_adapter.has_method("restore"):
			_billing_adapter.restore()
		else:
			_billing_adapter.refresh()


func _update_pro_ui() -> void:
	if not is_instance_valid(_pro_button):
		return
	_edition_title.text = "PONG PRO" if is_pro else "PONG"
	_edition_subtitle.text = "SEM ANÚNCIOS  /  MAIS MODOS" if is_pro else "GRÁTIS  /  MOBILE"
	_features_label.text = "MODOS EXTRAS E AJUSTES PERSONALIZADOS" if is_pro else "1 JOGADOR  •  PRIMEIRO A 7 PONTOS"
	_pro_row.visible = is_pro
	_pro_button.visible = not is_pro
	_pro_button.text = "★  PRO  •  %s  ★" % _pro_price if not _pro_price.is_empty() else "★  DESBLOQUEAR PRO  ★"
	_pro_button.disabled = not _billing_purchase_available or entitlement_status != EntitlementStatus.FREE_CONFIRMED
	_restore_purchase_button.visible = not is_pro or _negative_count > 0
	_restore_purchase_button.disabled = not is_instance_valid(_billing_adapter)
	# Durante a carência de revogação o botão Restaurar volta ao menu Pro;
	# reduzir o espaçamento evita cortar ações em telas baixas.
	_menu_content.add_theme_constant_override("separation", 3 if is_pro and _negative_count > 0 else 5)
	_pro_status_label.text = "Verificação Pro pendente; partida atual preservada." if _pending_pro_revocation \
			else "PRO MANTIDO — confira conta Google e toque RESTAURAR." if is_pro and _negative_count > 0 \
			else "PRO ATIVO — SEM ANÚNCIOS" if is_pro \
			else "PAGAMENTO EM ANÁLISE — sem anúncios." if entitlement_status == EntitlementStatus.PENDING \
			else "COMPRA EM ANDAMENTO — aguardando a Play Store." if entitlement_status == EntitlementStatus.CHECKOUT \
			else _billing_status
	_privacy_edition_label.text = "Pro funciona sem anúncios; a compra é verificada na Play Store." if is_pro else "O jogo funciona offline; anúncios ainda não estão ativos."
	_privacy_storage_label.text = "Preferências e estatísticas ficam no aparelho." if is_pro else "O direito Pro é restaurado pela conta da Play Store."


func set_published_games(entries: Array) -> void:
	published_games.clear()
	for entry in entries:
		if not entry is Dictionary:
			continue
		var url := str(entry.get("play_url", ""))
		var package_id := url.trim_prefix("https://play.google.com/store/apps/details?id=").get_slice("&", 0)
		if url.begins_with("https://play.google.com/store/apps/details?id=") \
				and not package_id.is_empty() and package_id not in ["com.pitinga.pongmobile", "com.pitinga.pongmobile.pro"] \
				and not str(entry.get("name", "")).is_empty():
			published_games.append({"name": str(entry["name"]), "play_url": url})
	_refresh_other_games()


func _refresh_other_games() -> void:
	if not is_instance_valid(_other_games_button):
		return
	_other_games_button.disabled = published_games.is_empty()
	_other_games_button.text = "OUTROS JOGOS  •  EM BREVE" if published_games.is_empty() else "🎮  INSTALE OUTROS JOGOS"
	for child in _other_games_content.get_children():
		_other_games_content.remove_child(child)
		child.queue_free()
	for entry in published_games:
		var button := _new_button("INSTALE  " + entry["name"], GRID, false)
		button.custom_minimum_size.y = 42
		_other_games_content.add_child(button)
		button.pressed.connect(_open_game_store.bind(entry["play_url"]))


func _open_other_games() -> void:
	if published_games.is_empty():
		return
	state = GameState.OTHER_GAMES
	_show_interface()


func _open_game_store(url: String) -> void:
	if url.begins_with("https://play.google.com/store/apps/details?id="):
		OS.shell_open(url)


func _show_interface() -> void:
	_menu.visible = state == GameState.MENU
	_pause_menu.visible = state == GameState.PAUSED
	_finish_menu.visible = state == GameState.FINISHED
	_privacy_menu.visible = state == GameState.PRIVACY
	_settings_menu.visible = state == GameState.SETTINGS
	_stats_menu.visible = state == GameState.STATS
	_other_games_menu.visible = state == GameState.OTHER_GAMES
	_pause_button.visible = state == GameState.PLAYING


func _load_pro_settings() -> void:
	var config := _load_config_with_backup(settings_file)
	if config == null:
		return
	ball_scale = clampf(float(config.get_value("visual", "ball_scale", 1.0)), 0.7, 1.5)
	paddle_scale = clampf(float(config.get_value("visual", "paddle_scale", 1.0)), 0.7, 1.5)
	theme_index = clampi(int(config.get_value("visual", "theme", 0)), 0, THEMES.size() - 1)
	point_limit = _points_from_index(int(config.get_value("rules", "points", 0)))
	_set_mode(int(config.get_value("rules", "mode", 0)), false)


func _save_pro_settings() -> void:
	if not is_pro:
		return
	var config := ConfigFile.new()
	config.set_value("visual", "ball_scale", ball_scale)
	config.set_value("visual", "paddle_scale", paddle_scale)
	config.set_value("visual", "theme", theme_index)
	config.set_value("rules", "mode", int(match_mode))
	config.set_value("rules", "points", _points_index())
	if _save_config_with_backup(config, settings_file) != OK:
		push_warning("Não foi possível guardar a personalização do Pong Pro.")


func _load_pro_stats() -> void:
	var config := _load_config_with_backup(stats_file)
	if config == null:
		return
	for key in _stats.keys():
		_stats[key] = maxi(0, int(config.get_value("stats", key, 0)))
	# Compatibilidade com instalações antigas que só guardavam o total.
	if not config.has_section_key("stats", "survival_matches"):
		var classic_count := int(_stats["standard_wins"]) + int(_stats["standard_losses"]) + int(_stats["custom_wins"]) + int(_stats["custom_losses"])
		_stats["survival_matches"] = maxi(0, int(_stats["played"]) - classic_count - int(_stats["two_player_matches"]))
	_stats["played"] = _count_pro_matches()
	_active_classic_match = bool(config.get_value("stats", "active_classic_match", false))
	if _active_classic_match:
		# Encerrar processo (inclusive crash) é abandono, não derrota.
		# Apenas na próxima abertura: suspender/retomar não remove a sequência.
		_stats["streak"] = 0
		_active_classic_match = false
		_save_pro_stats()


func _save_pro_stats() -> void:
	var config := ConfigFile.new()
	for key in _stats.keys():
		config.set_value("stats", key, _stats[key])
	config.set_value("stats", "active_classic_match", _active_classic_match)
	if _save_config_with_backup(config, stats_file) != OK:
		push_warning("Não foi possível guardar as estatísticas do Pong Pro.")


func _load_config_with_backup(path: String) -> ConfigFile:
	var config := ConfigFile.new()
	if config.load(path) == OK:
		return config
	var backup := ConfigFile.new()
	if backup.load(path + ".bak") == OK:
		push_warning("Arquivo local indisponível ou corrompido; recuperando backup: " + path.get_file())
		return backup
	return null


func _save_config_with_backup(config: ConfigFile, path: String) -> Error:
	# Salvar temporário no mesmo diretório antes de substituir o arquivo.
	# Nunca apagar o original se a gravação ou a troca falhar.
	var temp_path := path + ".tmp"
	var result := config.save(temp_path)
	if result != OK:
		return result
	if FileAccess.file_exists(path):
		# Um arquivo já corrompido não pode substituir o último backup válido.
		var existing := ConfigFile.new()
		if existing.load(path) == OK:
			result = DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".bak"))
			if result != OK:
				DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
				return result
	result = DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(path))
	if result != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
	return result


func _record_pro_stats(won: bool) -> void:
	_active_classic_match = false
	_stats["played"] += 1
	match match_mode:
		MatchMode.SURVIVAL:
			_stats["survival_matches"] += 1
			_stats["best_survival"] = maxi(int(_stats["best_survival"]), survival_hits)
		MatchMode.TWO_PLAYERS:
			_stats["two_player_matches"] += 1
		MatchMode.CLASSIC:
			var stat_prefix := "standard" if _is_standard_rules() else "custom"
			if won:
				_stats[stat_prefix + "_wins"] += 1
				_stats["streak"] += 1
				_stats["best_streak"] = maxi(int(_stats["best_streak"]), int(_stats["streak"]))
			else:
				_stats[stat_prefix + "_losses"] += 1
				_stats["streak"] = 0
	_save_pro_stats()


func _break_streak_on_abandon() -> void:
	# Sequência competitiva vale apenas para o Clássico. Reinício/saída
	# de tentativa ativa quebra a sequência, mas não cria uma derrota.
	if not is_pro or match_mode != MatchMode.CLASSIC or state not in [GameState.PLAYING, GameState.PAUSED]:
		return
	if int(_stats["streak"]) > 0 or _active_classic_match:
		_stats["streak"] = 0
		_active_classic_match = false
		_save_pro_stats()


func _count_pro_matches() -> int:
	return int(_stats["standard_wins"]) + int(_stats["standard_losses"]) + int(_stats["custom_wins"]) + int(_stats["custom_losses"]) + int(_stats["survival_matches"]) + int(_stats["two_player_matches"])


func _is_standard_rules() -> bool:
	return is_equal_approx(ball_scale, 1.0) and is_equal_approx(paddle_scale, 1.0) and point_limit == WIN_SCORE


func _refresh_stats() -> void:
	_stats_text.text = "PARTIDAS TOTAIS: %d\nCLÁSSICO PADRÃO: %dV / %dD\nCLÁSSICO PERSONALIZADO: %dV / %dD\nPARTIDAS DE SOBREVIVÊNCIA: %d\nPARTIDAS COM 2 JOGADORES: %d\nSEQUÊNCIA ATUAL: %d\nMELHOR SEQUÊNCIA: %d\nRECORDE SOBREVIVÊNCIA: %d" % [
		_stats["played"], _stats["standard_wins"], _stats["standard_losses"],
		_stats["custom_wins"], _stats["custom_losses"],
		_stats["survival_matches"], _stats["two_player_matches"],
		_stats["streak"], _stats["best_streak"],
		_stats["best_survival"]
	]


func _set_ball_size(value: float) -> void:
	ball_scale = clampf(roundf(value / 10.0) / 10.0, 0.7, 1.5)
	if _ball_value_label != null:
		_ball_value_label.text = "TAMANHO DA BOLA: %d%%" % roundi(ball_scale * 100.0)
	_save_pro_settings()
	queue_redraw()


func _set_paddle_size(value: float) -> void:
	paddle_scale = clampf(roundf(value / 10.0) / 10.0, 0.7, 1.5)
	if _paddle_value_label != null:
		_paddle_value_label.text = "ALTURA DAS RAQUETES: %d%%" % roundi(paddle_scale * 100.0)
	_save_pro_settings()
	queue_redraw()


func _select_theme(value: int) -> void:
	theme_index = clampi(value, 0, THEMES.size() - 1)
	_save_pro_settings()
	queue_redraw()


func _set_mode(value: int, persist: bool = true) -> void:
	match value:
		1: match_mode = MatchMode.SURVIVAL
		2: match_mode = MatchMode.TWO_PLAYERS
		_: match_mode = MatchMode.CLASSIC
	if persist:
		_save_pro_settings()
	queue_redraw()


func _points_from_index(index: int) -> int:
	match index:
		1: return 11
		2: return 21
		_: return 7


func _points_index() -> int:
	return 0 if point_limit == 7 else 1 if point_limit == 11 else 2


func _set_points(index: int) -> void:
	point_limit = _points_from_index(index)
	_save_pro_settings()


func _restore_pro_defaults() -> void:
	if not is_pro:
		return
	ball_scale = 1.0
	paddle_scale = 1.0
	theme_index = 0
	match_mode = MatchMode.CLASSIC
	point_limit = WIN_SCORE
	_ball_slider.set_value_no_signal(100)
	_paddle_slider.set_value_no_signal(100)
	_ball_value_label.text = "TAMANHO DA BOLA: 100%"
	_paddle_value_label.text = "ALTURA DAS RAQUETES: 100%"
	_theme_selector.select(0)
	_mode_selector.select(0)
	_points_selector.select(0)
	_save_pro_settings()
	queue_redraw()


func _build_interface() -> void:
	_menu = _new_overlay()
	var menu_content := _overlay_content(_menu)
	_menu_content = menu_content
	menu_content.add_theme_constant_override("separation", 5)
	_edition_title = _add_label(menu_content, "PONG", 60, WHITE)
	_edition_subtitle = _add_label(menu_content, "GRÁTIS  /  MOBILE", 15, CYAN)
	_add_space(menu_content, 6)
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
	_add_space(menu_content, 5)
	var start_button := _new_button("JOGAR  ▶", CYAN, true)
	start_button.custom_minimum_size = Vector2(0, 52)
	menu_content.add_child(start_button)
	start_button.pressed.connect(_start_match)
	_features_label = _add_label(menu_content, "1 JOGADOR  •  PRIMEIRO A 7 PONTOS", 13, MUTED)
	_pro_row = HBoxContainer.new()
	_pro_row.add_theme_constant_override("separation", 10)
	menu_content.add_child(_pro_row)
	var config_button := _new_button("PERSONALIZAR / MODOS", GRID, false)
	config_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	config_button.custom_minimum_size.y = 40
	config_button.add_theme_font_size_override("font_size", 14)
	_pro_row.add_child(config_button)
	config_button.pressed.connect(_open_settings)
	var stats_button := _new_button("ESTATÍSTICAS", GRID, false)
	stats_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_button.custom_minimum_size.y = 40
	stats_button.add_theme_font_size_override("font_size", 14)
	_pro_row.add_child(stats_button)
	stats_button.pressed.connect(_open_stats)
	var billing_row := HBoxContainer.new()
	billing_row.add_theme_constant_override("separation", 8)
	menu_content.add_child(billing_row)
	_pro_button = _new_button("★  DESBLOQUEAR PRO  ★", GRID, false)
	_pro_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pro_button.custom_minimum_size.y = 39
	_pro_button.add_theme_font_size_override("font_size", 13)
	billing_row.add_child(_pro_button)
	_pro_button.pressed.connect(_buy_pro)
	_restore_purchase_button = _new_button("RESTAURAR", GRID, false)
	_restore_purchase_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_restore_purchase_button.custom_minimum_size.y = 39
	_restore_purchase_button.add_theme_font_size_override("font_size", 12)
	billing_row.add_child(_restore_purchase_button)
	_restore_purchase_button.pressed.connect(_restore_purchase)
	_pro_status_label = _add_label(menu_content, _billing_status, 11, MUTED)
	_pro_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_other_games_button = _new_button("OUTROS JOGOS  •  EM BREVE", GRID, false)
	_other_games_button.custom_minimum_size.y = 35
	_other_games_button.add_theme_font_size_override("font_size", 13)
	menu_content.add_child(_other_games_button)
	_other_games_button.pressed.connect(_open_other_games)
	var privacy_button := _new_button("PRIVACIDADE", GRID, false)
	privacy_button.custom_minimum_size.y = 34
	privacy_button.add_theme_font_size_override("font_size", 14)
	menu_content.add_child(privacy_button)
	privacy_button.pressed.connect(_open_privacy)

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
	_finish_again_button = _new_button("JOGAR NOVAMENTE", CYAN, true)
	finish_content.add_child(_finish_again_button)
	_finish_again_button.pressed.connect(_start_match)
	_finish_exit_button = _new_button("MENU PRINCIPAL", GRID, false)
	finish_content.add_child(_finish_exit_button)
	_finish_exit_button.pressed.connect(_return_to_menu)
	_ad_status_label = _add_label(finish_content, "AGUARDANDO ANÚNCIO...", 12, MUTED)
	_ad_status_label.visible = false
	_ad_safe_exit_button = _new_button("FECHAR JOGO", GRID, false)
	_ad_safe_exit_button.custom_minimum_size.y = 36
	finish_content.add_child(_ad_safe_exit_button)
	_ad_safe_exit_button.visible = false
	_ad_safe_exit_button.pressed.connect(_quit_after_ad_failure)

	_privacy_menu = _new_overlay()
	var privacy_content := _overlay_content(_privacy_menu)
	privacy_content.add_theme_constant_override("separation", 10)
	_add_label(privacy_content, "PRIVACIDADE", 40, WHITE)
	_privacy_edition_label = _add_label(privacy_content, "O jogo funciona offline; anúncios ainda não estão ativos.", 15, MUTED)
	_add_label(privacy_content, "Não há cadastro nem análise de comportamento.", 15, MUTED)
	_privacy_storage_label = _add_label(privacy_content, "O direito Pro é restaurado pela conta da Play Store.", 15, MUTED)
	_add_label(privacy_content, "Dúvidas: github.com/pitinga/game-pong-mobile/issues", 14, CYAN)
	_add_space(privacy_content, 8)
	var privacy_back_button := _new_button("VOLTAR AO MENU", CYAN, true)
	privacy_content.add_child(privacy_back_button)
	privacy_back_button.pressed.connect(_return_to_menu)

	_other_games_menu = _new_overlay()
	var other_content := _overlay_content(_other_games_menu)
	_add_label(other_content, "CONHEÇA NOSSOS JOGOS", 32, WHITE)
	_add_label(other_content, "TOQUE PARA INSTALAR PELA PLAY STORE", 13, MUTED)
	var other_scroll := ScrollContainer.new()
	other_scroll.custom_minimum_size.y = 240
	other_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	other_content.add_child(other_scroll)
	_other_games_content = VBoxContainer.new()
	_other_games_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	other_scroll.add_child(_other_games_content)
	var other_back_button := _new_button("VOLTAR AO MENU", CYAN, true)
	other_content.add_child(other_back_button)
	other_back_button.pressed.connect(_return_to_menu)

	_settings_menu = _new_overlay()
	var settings_content := _overlay_content(_settings_menu)
	settings_content.add_theme_constant_override("separation", 5)
	_add_label(settings_content, "PERSONALIZAÇÃO PRO", 34, WHITE)
	_ball_value_label = _add_label(settings_content, "TAMANHO DA BOLA: %d%%" % roundi(ball_scale * 100.0), 14, MUTED)
	_ball_slider = _new_pro_slider(settings_content, ball_scale * 100.0)
	_ball_slider.value_changed.connect(_set_ball_size)
	_paddle_value_label = _add_label(settings_content, "ALTURA DAS RAQUETES: %d%%" % roundi(paddle_scale * 100.0), 14, MUTED)
	_paddle_slider = _new_pro_slider(settings_content, paddle_scale * 100.0)
	_paddle_slider.value_changed.connect(_set_paddle_size)
	_add_label(settings_content, "CORES DA QUADRA", 14, MUTED)
	_theme_selector = _new_option(settings_content)
	for theme in THEMES:
		_theme_selector.add_item(theme["name"])
	_theme_selector.select(theme_index)
	_theme_selector.item_selected.connect(_select_theme)
	_add_label(settings_content, "MODO DE JOGO", 14, MUTED)
	_mode_selector = _new_option(settings_content)
	for mode_name in ["CLÁSSICO VS COMPUTADOR", "SOBREVIVÊNCIA", "2 JOGADORES LOCAIS"]:
		_mode_selector.add_item(mode_name)
	_mode_selector.select(int(match_mode))
	_mode_selector.item_selected.connect(_set_mode)
	_add_label(settings_content, "PONTOS PARA VENCER (CLÁSSICO / 2 JOGADORES)", 13, MUTED)
	_points_selector = _new_option(settings_content)
	for score_name in ["7 PONTOS", "11 PONTOS", "21 PONTOS"]:
		_points_selector.add_item(score_name)
	_points_selector.select(_points_index())
	_points_selector.item_selected.connect(_set_points)
	_add_space(settings_content, 5)
	var restore_button := _new_button("↺  RESTAURAR TUDO AO PADRÃO", GRID, false)
	restore_button.custom_minimum_size.y = 39
	settings_content.add_child(restore_button)
	restore_button.pressed.connect(_restore_pro_defaults)
	var settings_back_button := _new_button("VOLTAR AO MENU", CYAN, true)
	settings_back_button.custom_minimum_size.y = 40
	settings_content.add_child(settings_back_button)
	settings_back_button.pressed.connect(_return_to_menu)

	_stats_menu = _new_overlay()
	var stats_content := _overlay_content(_stats_menu)
	_add_label(stats_content, "ESTATÍSTICAS PRO", 37, WHITE)
	_stats_text = _add_label(stats_content, "", 20, MUTED)
	_stats_text.add_theme_constant_override("line_spacing", 10)
	_refresh_stats()
	var stats_back_button := _new_button("VOLTAR AO MENU", CYAN, true)
	stats_content.add_child(stats_back_button)
	stats_back_button.pressed.connect(_return_to_menu)

	_pause_button = _new_button("Ⅱ  PAUSAR", GRID, false)
	_pause_button.set_anchors_preset(PRESET_TOP_RIGHT)
	_pause_button.offset_left = -151
	_pause_button.offset_top = 27
	_pause_button.offset_right = -23
	_pause_button.offset_bottom = 72
	add_child(_pause_button)
	_pause_button.pressed.connect(_toggle_pause)
	_update_pro_ui()
	_refresh_other_games()


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


func _new_pro_slider(parent: Node, initial_value: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = 70
	slider.max_value = 150
	slider.step = 10
	slider.value = initial_value
	slider.custom_minimum_size = Vector2(350, 26)
	parent.add_child(slider)
	return slider


func _new_option(parent: Node) -> OptionButton:
	var selector := OptionButton.new()
	selector.custom_minimum_size = Vector2(350, 34)
	selector.add_theme_font_size_override("font_size", 15)
	parent.add_child(selector)
	return selector


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
	# O runner headless não tem saída de áudio. Evitar iniciar canais que
	# deixam AudioStreamPlaybackWAV pendente ao encerrar os testes.
	if DisplayServer.get_name() == "headless":
		return
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
