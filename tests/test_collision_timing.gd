extends SceneTree
## Regressões do tempo restante e da ordem de impactos (sem APK/SDK).

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


func _near(actual: float, expected: float, tolerance: float = 0.03) -> bool:
	return absf(actual - expected) <= tolerance


func _prepare(game: Control, position: Vector2, velocity: Vector2) -> void:
	game._start_match()
	game._serve_countdown = 0.0
	game.ball_position = position
	game.ball_velocity = velocity
	game._trail.clear()


func _run() -> void:
	root.size = Vector2i(960, 540)
	var token := "%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var game: Control = load("res://scenes/main.tscn").instantiate()
	game.is_pro = true
	game.settings_file = "user://pong_toi_%s_settings.cfg" % token
	game.stats_file = "user://pong_toi_%s_stats.cfg" % token
	root.add_child(game)
	await process_frame
	game._set_mode(2)
	var top: float = game.FIELD_MARGIN + game._ball_radius()
	var bottom: float = game.size.y - top
	var dt := 1.0 / 60.0
	var initial_speed := 300.0
	var displaced: float = (initial_speed + game.BALL_ACCELERATION * dt) * dt
	_prepare(game, Vector2(480, top + 1.0), Vector2(0.0, -initial_speed))
	game._physics_process(dt)
	_check(_near(game.ball_position.y, top + displaced - 1.0), "Parede superior devolve todo o deslocamento restante")
	_check(_near(game.ball_velocity.length(), initial_speed + game.BALL_ACCELERATION * dt), "Parede superior não altera o módulo da velocidade além da aceleração")
	_prepare(game, Vector2(480, bottom - 1.0), Vector2(0.0, initial_speed))
	game._physics_process(dt)
	_check(_near(game.ball_position.y, bottom - (displaced - 1.0)), "Parede inferior é simétrica")

	_prepare(game, Vector2(480, top + 1.0), Vector2(-300.0, -300.0))
	var start: Vector2 = game.ball_position
	var speed: float = game.ball_velocity.length() + game.BALL_ACCELERATION * dt
	var vx: float = -speed / sqrt(2.0)
	game._physics_process(dt)
	_check(_near(game.ball_position.x, start.x + vx * dt) and game.ball_position.y > top, "Impacto diagonal conserva movimento horizontal e vertical refletido")

	# A velocidade máxima isola a integração da aceleração.
	_prepare(game, Vector2(480, top + 1.0), Vector2(0.0, -game.MAX_BALL_SPEED))
	game._physics_process(0.006)
	var one_step: Vector2 = game.ball_position
	_prepare(game, Vector2(480, top + 1.0), Vector2(0.0, -game.MAX_BALL_SPEED))
	game._physics_process(0.003)
	game._physics_process(0.003)
	_check(_near(one_step.y, top + game.MAX_BALL_SPEED * 0.006 - 1.0) and _near(one_step.y, game.ball_position.y), "Um passo e dois meios passos produzem o mesmo rebote")

	# Dois eventos por intervalo de física, em ambas as ordens.
	for side in [-1, 1]:
		var is_left: bool = side == -1
		var x: float = 74.0 if is_left else game.size.x - 74.0
		var y: float = top + 1.0 if is_left else bottom - 1.0
		var direction := -1.0 if is_left else 1.0
		_prepare(game, Vector2(x, y), Vector2(direction * 500.0, direction * 500.0))
		game.player_y = top + game._paddle_height() * 0.5
		game.cpu_y = bottom - game._paddle_height() * 0.5
		game._physics_process(0.006)
		_check((game.ball_velocity.x > 0.0 if is_left else game.ball_velocity.x < 0.0) and absf(game.ball_position.y - (top if is_left else bottom)) > 0.5, "Parede antes da raquete no %s com tempo restante" % ("lado esquerdo" if is_left else "lado direito"))
		# Raquete antes da parede: inverter a prioridade fixa também falharia.
		x = 73.1 if is_left else game.size.x - 73.1
		_prepare(game, Vector2(x, y), Vector2(direction * 500.0, direction * 200.0))
		game.player_y = top + game._paddle_height() * 0.5
		game.cpu_y = bottom - game._paddle_height() * 0.5
		game._physics_process(0.006)
		_check((game.ball_velocity.x > 0.0 if is_left else game.ball_velocity.x < 0.0) and absf(game.ball_position.y - (top if is_left else bottom)) > 0.5, "Raquete antes da parede no %s com tempo restante" % ("lado esquerdo" if is_left else "lado direito"))

	for scale in [0.7, 1.0, 1.5]:
		game.ball_scale = scale
		game.paddle_scale = scale
		var radius: float = game._ball_radius()
		var scaled_top: float = game.FIELD_MARGIN + radius
		var left_face: float = game.PADDLE_MARGIN + game.PADDLE_WIDTH * 0.5 + radius
		_prepare(game, Vector2(left_face + 1.5, scaled_top + 1.0), Vector2(-800.0, -800.0))
		game.player_y = game.FIELD_MARGIN + game._paddle_height() * 0.5
		game._physics_process(0.006)
		_check(game.ball_velocity.x > 0.0 and game.ball_position.y >= scaled_top - 0.01 and game.ball_position.y <= game.size.y - scaled_top + 0.01, "Alta velocidade, canto superior e escalas %.1fx" % scale)
	game.ball_scale = 1.0
	game.paddle_scale = 1.0

	# Uma bola já atrás da face não é resgatada pelo contato da raquete.
	_prepare(game, Vector2(60.0, 270.0), Vector2(-350.0, 0.0))
	game.player_y = 270.0
	game._physics_process(0.006)
	_check(game.ball_velocity.x < 0.0, "A colisão temporal não recupera bola atrás da face")

	var settings_path: String = game.settings_file
	var stats_path: String = game.stats_file
	game.free()
	for path in [settings_path, stats_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("Tempo de impacto: %d falha(s)." % failures)
	quit(1 if failures else 0)
