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
