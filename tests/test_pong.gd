extends SceneTree
## Testes de regras do jogo sem janela gráfica. Executar com:
## godot --headless --path . --script res://tests/test_pong.gd

const GameScript = preload("res://scripts/pong.gd")

var _failures := 0


func _initialize() -> void:
	call_deferred("_run_tests")


func _check(condition: bool, description: String) -> void:
	if condition:
		print("OK  - " + description)
	else:
		_failures += 1
		push_error("FALHOU - " + description)


func _cpu_defends_shot(game: Control, level: int, speed: float) -> bool:
	game._select_difficulty(level)
	game._start_match()
	game._serve_countdown = 0.0
	game.ball_position = Vector2(540.0, 80.0)
	game.ball_velocity = Vector2(speed, 0.0)
	game.cpu_y = game.size.y * 0.5
	game._cpu_target_y = game.cpu_y
	game._cpu_aim_bias = 0.0
	game._cpu_reaction_timer = 0.0
	for _frame in range(100):
		game._physics_process(1.0 / 60.0)
		if game.ball_velocity.x < 0.0:
			return true
		if game.player_score > 0:
			return false
	return false


func _run_tests() -> void:
	var game: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame

	_check(game.state == GameScript.GameState.MENU, "Abre no menu inicial")
	_check(game.difficulty == 1, "Dificuldade padrão é média")
	game._select_difficulty(2)
	_check(game.difficulty == 2, "Seleciona dificuldade difícil")
	game._start_match()
	_check(game.state == GameScript.GameState.PLAYING, "Inicia a partida")
	_check(game.player_score == 0 and game.cpu_score == 0, "Placar inicia zerado")
	_check(game.ball_velocity == Vector2.ZERO, "Saque tem contagem regressiva")

	game._set_player_y(-300.0)
	_check(game.player_y >= game.FIELD_MARGIN + game.PADDLE_HEIGHT * 0.5, "Raquete respeita limite superior")
	game._set_player_y(3000.0)
	_check(game.player_y <= game.size.y - game.FIELD_MARGIN - game.PADDLE_HEIGHT * 0.5, "Raquete respeita limite inferior")

	game._toggle_pause()
	_check(game.state == GameScript.GameState.PAUSED, "Pausa a partida")
	game._toggle_pause()
	_check(game.state == GameScript.GameState.PLAYING, "Retoma a partida")

	_check(game.CPU_SPEEDS[0] < game.CPU_SPEEDS[1] and game.CPU_SPEEDS[1] < game.CPU_SPEEDS[2], "CPU tem velocidades diferentes por nível")
	_check(game.CPU_REACTION[0] > game.CPU_REACTION[1] and game.CPU_REACTION[1] > game.CPU_REACTION[2], "CPU reage mais rápido nos níveis difíceis")
	_check(game.CPU_LOOKAHEAD[0] < game.CPU_LOOKAHEAD[1] and game.CPU_LOOKAHEAD[1] < game.CPU_LOOKAHEAD[2], "CPU antecipa melhor a trajetória nos níveis difíceis")
	_check(game.CPU_ERROR[0] > game.CPU_ERROR[1] and game.CPU_ERROR[1] > game.CPU_ERROR[2], "CPU tem mira menos precisa nos níveis fáceis")
	_check(game.MAX_BALL_SPEED > game.CPU_SPEEDS[2] * 2.0, "Bola pode ficar bem mais rápida do que a CPU")

	game.ball_velocity = Vector2(game.BASE_BALL_SPEED, 0.0)
	game._accelerate_ball(2.0)
	_check(is_equal_approx(game.ball_velocity.length(), game.BASE_BALL_SPEED + 2.0 * game.BALL_ACCELERATION), "Bola acelera com o tempo")
	var before_bounce: float = game.ball_velocity.length()
	game.ball_position = Vector2(200.0, game.player_y)
	game._bounce_from_paddle(true)
	_check(is_equal_approx(game.ball_velocity.length(), before_bounce + game.PADDLE_SPEED_BONUS), "Bola acelera a cada rebatida")
	game.ball_velocity = Vector2(game.MAX_BALL_SPEED - 5.0, 0.0)
	game._accelerate_ball(2.0)
	game._bounce_from_paddle(true)
	_check(is_equal_approx(game.ball_velocity.length(), game.MAX_BALL_SPEED), "Bola respeita limite máximo de velocidade")
	game._reset_round(1.0)
	_check(game.ball_velocity == Vector2.ZERO and game._serve_countdown > 0.0, "Velocidade reinicia após cada ponto")

	_check(not _cpu_defends_shot(game, 0, 650.0), "Fácil: CPU erra uma bola que consegue alcançar no médio")
	_check(_cpu_defends_shot(game, 1, 650.0), "Médio: CPU defende uma bola de velocidade moderada")
	_check(not _cpu_defends_shot(game, 1, 850.0), "Médio: jogador consegue pontuar com bola rápida")
	_check(_cpu_defends_shot(game, 2, 850.0), "Difícil: CPU defende uma bola rápida que passa no médio")
	game._select_difficulty(2)
	game._start_match()
	game._serve_countdown = 0.0
	game.ball_position = Vector2(840.0, 270.0)
	game.ball_velocity = Vector2(game.MAX_BALL_SPEED, 0.0)
	game.cpu_y = 270.0
	for _frame in range(6):
		game._physics_process(1.0 / 60.0)
	_check(game.ball_velocity.x < 0.0, "Bola rápida não atravessa a raquete da CPU")

	game._start_match()
	game._score_point(false)
	_check(game.cpu_score == 1 and game.player_score == 0, "CPU pontua")
	game._score_point(true)
	_check(game.player_score == 1 and game.cpu_score == 1, "Jogador pontua")
	for i in range(game.WIN_SCORE - 1):
		game._score_point(true)
	_check(game.state == GameScript.GameState.FINISHED, "Finaliza ao atingir sete pontos")
	_check(game.player_won, "Reconhece vitória do jogador")

	game._start_match()
	for i in range(game.WIN_SCORE):
		game._score_point(false)
	_check(game.state == GameScript.GameState.FINISHED and not game.player_won, "Reconhece vitória da CPU")
	game._return_to_menu()
	_check(game.state == GameScript.GameState.MENU and game.player_score == 0, "Volta ao menu e limpa o placar")

	game.free()
	if _failures == 0:
		print("\nTodos os testes passaram.")
	else:
		push_error("%d teste(s) falharam." % _failures)
	quit(1 if _failures > 0 else 0)
