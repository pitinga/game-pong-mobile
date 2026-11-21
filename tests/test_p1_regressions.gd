extends SceneTree
## Regressões de colisão e multitouch. Execução independente do perfil real:
## godot --headless --path . --script res://tests/test_p1_regressions.gd

const GameScript = preload("res://scripts/pong.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	if ok:
		print("OK  - " + label)
	else:
		failures += 1
		push_error("FALHOU - " + label)


func _touch(index: int, pos: Vector2, pressed: bool = true, canceled: bool = false) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	e.canceled = canceled
	Input.parse_input_event(e)


func _drag(index: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	Input.parse_input_event(e)


func _run() -> void:
	root.size = Vector2i(960, 540)
	var game: Control = load("res://scenes/main.tscn").instantiate()
	game.is_pro = true
	var token := "%d_%d_%d" % [OS.get_process_id(), int(Time.get_unix_time_from_system() * 1000000.0), randi()]
	game.settings_file = "user://pong_p1_%s_settings.cfg" % token
	game.stats_file = "user://pong_p1_%s_stats.cfg" % token
	root.add_child(game)
	await process_frame
	game._start_match()
	# Eventos de toque reais, mas física somente quando chamada pelo teste;
	# assim o resultado não depende do instante do frame no runner headless.
	game.set_physics_process(false)
	game._serve_countdown = 0.0
	game.player_y = 270.0
	game.ball_position = Vector2(72.0, 329.0)
	game.ball_velocity = Vector2(-345.0, 0.0)
	game._physics_process(0.0001)
	_check(game.ball_velocity.x < 0.0, "Canto esquerdo: sem contato a 13,09 px do vértice, raio 10")
	game._start_match()
	game._serve_countdown = 0.0
	game.cpu_y = 270.0
	game.ball_position = Vector2(game.size.x - 72.0, 329.0)
	game.ball_velocity = Vector2(345.0, 0.0)
	game._physics_process(0.0001)
	_check(game.ball_velocity.x > 0.0, "Canto direito simétrico não rebate antes do contato")
	game._start_match()
	game._serve_countdown = 0.0
	game.player_y = 270.0
	game.ball_position = Vector2(60.0, 270.0)
	game.ball_velocity = Vector2(-345.0, 0.0)
	game._physics_process(0.01)
	_check(game.ball_velocity.x < 0.0, "Bola já atrás da face esquerda não é recuperada")
	var front_left: float = game._sweep_paddle_contact(Vector2(100, 270), Vector2(50, 270), 55, 270, 270, true)
	var front_right: float = game._sweep_paddle_contact(Vector2(860, 270), Vector2(910, 270), 905, 270, 270, false)
	_check(is_equal_approx(front_left, 0.55) and is_equal_approx(front_right, 0.55), "Contato frontal varrido é simétrico e usa a face real da raquete")
	var tangent: float = game._sweep_paddle_contact(Vector2(100, 330), Vector2(50, 330), 55, 270, 270, true)
	var outside: float = game._sweep_paddle_contact(Vector2(100, 330.1), Vector2(50, 330.1), 55, 270, 270, true)
	_check(tangent >= 0.0 and outside < 0.0, "Tangência exata é contato; 0,1 px além do canto não é")
	var moving: float = game._sweep_paddle_contact(Vector2(100, 335), Vector2(60, 335), 55, 270, 300, true)
	var still: float = game._sweep_paddle_contact(Vector2(100, 335), Vector2(60, 335), 55, 270, 270, true)
	_check(moving >= 0.0 and still < 0.0, "Contato varrido considera o deslocamento real da raquete")
	for scale in [0.7, 1.0, 1.5]:
		game.paddle_scale = scale
		game.ball_scale = scale
		var half_height: float = game._paddle_height() * 0.5
		var radius: float = game._ball_radius()
		var contact: float = game._sweep_paddle_contact(Vector2(100, 270 + half_height + radius), Vector2(50, 270 + half_height + radius), 55, 270, 270, true)
		var miss: float = game._sweep_paddle_contact(Vector2(100, 271 + half_height + radius), Vector2(50, 271 + half_height + radius), 55, 270, 270, true)
		_check(contact >= 0.0 and miss < 0.0, "Escala %.1fx preserva tangência e rejeita canto distante" % scale)
	game.paddle_scale = 1.0
	game.ball_scale = 1.0
	game._start_match()
	game._serve_countdown = 0.0
	game.player_y = 270.0
	game.ball_position = Vector2(80.0, 270.0)
	game.ball_velocity = Vector2(-345.0, 0.0)
	game._physics_process(0.05)
	_check(game.ball_velocity.x > 0.0 and game.ball_position.x > 72.5, "Após impacto frontal, percorre o tempo restante já rebatida")

	game._set_mode(2)
	game._start_match()
	_touch(0, Vector2(120, 145))
	_touch(1, Vector2(825, 400))
	await process_frame
	_check(is_equal_approx(game.player_y, 145.0) and is_equal_approx(game.cpu_y, 400.0), "Dois dedos movimentam independentemente P1 e P2")
	_drag(0, Vector2(850, 155))
	await process_frame
	_check(is_equal_approx(game.player_y, 155.0) and is_equal_approx(game.cpu_y, 400.0), "P1 conserva captura ao cruzar o centro")
	_drag(1, Vector2(100, 405))
	await process_frame
	_check(is_equal_approx(game.player_y, 155.0) and is_equal_approx(game.cpu_y, 405.0), "P2 conserva captura ao cruzar o centro")
	_touch(2, Vector2(80, 300))
	_drag(2, Vector2(80, 330))
	await process_frame
	_check(is_equal_approx(game.player_y, 155.0), "Terceiro dedo não rouba controle da raquete ocupada")
	_touch(0, Vector2(850, 155), false, true)
	_drag(0, Vector2(100, 190))
	await process_frame
	_check(is_equal_approx(game.player_y, 155.0), "Cancelamento libera dedo e drag órfão não movimenta")
	_touch(2, Vector2(80, 330), false)
	_touch(0, Vector2(130, 200))
	await process_frame
	_check(is_equal_approx(game.player_y, 200.0), "Novo press captura raquete novamente")
	var before_round: float = game.player_y
	var before_cpu: float = game.cpu_y
	game._reset_round(-1)
	_check(is_equal_approx(game.player_y, before_round) and is_equal_approx(game.cpu_y, before_cpu), "Novo saque mantém ambas as raquetes na posição atual")
	_drag(0, Vector2(120, 300))
	_drag(1, Vector2(825, 350))
	await process_frame
	_check(is_equal_approx(game.player_y, 300.0) and is_equal_approx(game.cpu_y, 350.0), "Dedos mantidos continuam controlando P1 e P2 após ponto")
	_touch(2, Vector2(100, 200))
	_drag(2, Vector2(100, 250))
	await process_frame
	_check(is_equal_approx(game.player_y, 300.0), "Terceiro dedo continua sem roubar captura após outro saque")
	_touch(2, Vector2(100, 250), false)
	_touch(0, Vector2(130, 250), false)
	_touch(1, Vector2(150, 400), false)

	# O teleporte do toque não varre toda a quadra; só a posição final
	# intercepta a bola. Uma bola já atrás da face continua indefensável.
	game._start_match()
	game._serve_countdown = 0.0
	_touch(0, Vector2(120, 400))
	await process_frame
	game.ball_position = Vector2(67.0, 270.0)
	game.ball_velocity = Vector2(-500.0, 0.0)
	_drag(0, Vector2(120, 270))
	await process_frame
	game._physics_process(0.003)
	_check(game.ball_velocity.x > 0.0 and game.ball_position.x >= 72.49, "Toque imediato sobre bola à frente da face rebate uma vez e separa")
	var bounced_x: float = game.ball_position.x
	game._physics_process(0.002)
	_check(game.ball_velocity.x > 0.0 and game.ball_position.x > bounced_x, "Sobreposição frontal não gera múltiplos rebotes")
	game._start_match()
	game._serve_countdown = 0.0
	_touch(0, Vector2(120, 400))
	await process_frame
	game.ball_position = Vector2(67.0, 328.0)
	game.ball_velocity = Vector2(-500.0, 0.0)
	_drag(0, Vector2(120, 270))
	await process_frame
	game._physics_process(0.003)
	_check(game.ball_velocity.x > 0.0, "Teleporte do toque respeita colisão circular no canto da raquete")
	game._start_match()
	game._serve_countdown = 0.0
	_touch(0, Vector2(120, 400))
	await process_frame
	game.ball_position = Vector2(60.0, 270.0)
	game.ball_velocity = Vector2(-500.0, 0.0)
	_drag(0, Vector2(120, 270))
	await process_frame
	game._physics_process(0.003)
	_check(game.ball_velocity.x < 0.0, "Toque imediato não resgata bola atrás da face")
	_touch(0, Vector2(120, 270), false)
	game._start_match()
	game._serve_countdown = 0.0
	_touch(1, Vector2(825, 400))
	await process_frame
	game.ball_position = Vector2(game.size.x - 67.0, 270.0)
	game.ball_velocity = Vector2(500.0, 0.0)
	_drag(1, Vector2(825, 270))
	await process_frame
	game._physics_process(0.003)
	_check(game.ball_velocity.x < 0.0 and game.ball_position.x <= game.size.x - 72.49, "Toque imediato do P2 é simétrico ao P1")
	_touch(1, Vector2(825, 270), false)
	game.set_physics_process(true)
	game.free()
	for file in ["user://pong_p1_%s_settings.cfg" % token, "user://pong_p1_%s_stats.cfg" % token]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	print("Regressões P1: %d falha(s)." % failures)
	quit(1 if failures else 0)
