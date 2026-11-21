extends SceneTree
## Testes de regras do jogo sem janela gráfica. Executar com:
## godot --headless --path . --script res://tests/test_pong.gd

const GameScript = preload("res://scripts/pong.gd")
const AdPolicy = preload("res://scripts/ad_policy.gd")

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
	_check(not game.is_pro, "Execução padrão é edição Free")
	_check(game._pro_button != null, "Free divulga Pong Pro no menu")
	_check((game._menu.get_child(0) as PanelContainer).get_combined_minimum_size().y <= 530.0, "Menu Free com promoção Pro cabe na tela")
	game._open_settings()
	_check(game.state == GameScript.GameState.MENU, "Free não abre a personalização Pro")
	game._open_pro_store()
	_check(game._pro_button.text.contains("EM BREVE"), "Free avisa antes de a ficha Pro estar publicada")
	game._open_privacy()
	_check(game.state == GameScript.GameState.PRIVACY and game._privacy_menu.visible, "Política de privacidade acessível pelo menu")
	game._return_to_menu()
	_check(game.state == GameScript.GameState.MENU, "Volta da privacidade para o menu")
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

	var ad_policy = AdPolicy.new()
	for _i in range(3):
		ad_policy.note_finished_match()
	_check(not ad_policy.can_show(0), "Free não mostra anúncio antes da quarta partida")
	ad_policy.note_finished_match()
	_check(ad_policy.can_show(0), "Quarta partida torna anúncio elegível")
	ad_policy.record_impression(0)
	for _i in range(4):
		ad_policy.note_finished_match()
	_check(not ad_policy.can_show(599999), "Intersticial respeita espera mínima de dez minutos")
	_check(ad_policy.can_show(600000), "Intersticial libera após dez minutos")
	ad_policy.record_impression(600000)
	for _i in range(4):
		ad_policy.note_finished_match()
	_check(not ad_policy.can_show(1200000), "Limite de dois intersticiais por hora")
	_check(ad_policy.can_show(3600000), "Teto horário expira após sessenta minutos")

	game.is_pro = true
	var settings_panel := game._settings_menu.get_child(0) as PanelContainer
	_check(settings_panel.get_combined_minimum_size().y <= 530.0, "Painel de personalização cabe no celular em paisagem")
	game._open_settings()
	_check(game.state == GameScript.GameState.SETTINGS, "Pro abre tela de personalização")
	game._set_ball_size(140)
	game._set_paddle_size(150)
	_check(is_equal_approx(game._ball_radius(), 14.0), "Pro aumenta raio e colisão da bola")
	_check(is_equal_approx(game._paddle_height(), 150.0), "Pro altera as duas raquetes")
	game._set_player_y(-100)
	_check(game.player_y >= game.FIELD_MARGIN + 75.0, "Raquete personalizada respeita limites")
	game._select_theme(2)
	_check(game.theme_index == 2, "Pro muda cores")
	game._set_mode(1)
	_check(game.match_mode == GameScript.MatchMode.SURVIVAL, "Pro habilita modo Sobrevivência")
	game._start_match()
	game.ball_velocity = Vector2(500, 0)
	game.ball_position = Vector2(100, game.player_y)
	game._bounce_from_paddle(true)
	_check(game.survival_hits == 1, "Sobrevivência contabiliza rebatidas")
	game._score_point(false)
	_check(game.state == GameScript.GameState.FINISHED and int(game._stats["best_survival"]) >= 1, "Sobrevivência acaba ao perder e guarda recorde")
	game._set_mode(2)
	game._start_match()
	game._set_touch_paddle(Vector2(800, 100))
	_check(game.cpu_y <= 100.0 and game.player_y != game.cpu_y, "Dois jogadores controlam metades independentes")
	game._set_touch_paddle(Vector2(100, 400))
	_check(game.player_y >= 400.0, "Jogador 1 recebe toque no lado esquerdo")
	game._set_points(1)
	_check(game.point_limit == 11, "Pro permite partida até onze pontos")
	game._set_mode(0)
	game._start_match()
	for _point in range(10):
		game._score_point(true)
	_check(game.state == GameScript.GameState.PLAYING, "Partida de 11 pontos não termina ao chegar a dez")
	game._score_point(true)
	_check(game.state == GameScript.GameState.FINISHED, "Partida de 11 pontos termina no décimo primeiro")
	game._set_points(2)
	_check(game.point_limit == 21, "Pro também permite partidas de 21 pontos")
	_check(not game._is_standard_rules(), "Regras personalizadas não entram nos recordes padrão")
	game._restore_pro_defaults()
	_check(game.ball_scale == 1.0 and game.paddle_scale == 1.0 and game.theme_index == 0, "Restaura dimensões e cores originais com um toque")
	_check(game.match_mode == GameScript.MatchMode.CLASSIC and game.point_limit == 7, "Restaurar padrão também recupera as regras clássicas")
	var stored := ConfigFile.new()
	_check(stored.load(game.SETTINGS_FILE) == OK and is_equal_approx(float(stored.get_value("visual", "ball_scale", 0.0)), 1.0), "Preferências Pro são guardadas localmente")
	game._set_ball_size(120)
	game._select_theme(1)
	game._load_pro_settings()
	_check(is_equal_approx(game.ball_scale, 1.2) and game.theme_index == 1, "Preferências Pro restauradas do arquivo após atualização")
	game._restore_pro_defaults()

	var real_pro: Control = load("res://scenes/main.tscn").instantiate()
	real_pro.is_pro = true
	root.add_child(real_pro)
	await process_frame
	_check(real_pro.is_pro and real_pro._pro_button == null, "Menu Pro não possui botão de compra ou anúncios")
	var pro_menu_panel := real_pro._menu.get_child(0) as PanelContainer
	_check(pro_menu_panel.get_combined_minimum_size().y <= 530.0, "Menu Pro cabe no celular em paisagem")
	var stats_panel := real_pro._stats_menu.get_child(0) as PanelContainer
	_check(stats_panel.get_combined_minimum_size().y <= 530.0, "Estatísticas Pro cabem no celular em paisagem")
	real_pro.free()

	game.free()
	if _failures == 0:
		print("\nTodos os testes passaram.")
	else:
		push_error("%d teste(s) falharam." % _failures)
	quit(1 if _failures > 0 else 0)
