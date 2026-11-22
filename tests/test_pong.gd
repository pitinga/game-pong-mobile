extends SceneTree
## Testes de regras do jogo sem janela gráfica. Executar com:
## godot --headless --path . --script res://tests/test_pong.gd

const GameScript = preload("res://scripts/pong.gd")
const AdPolicy = preload("res://scripts/ad_policy.gd")

class FakeBilling:
	extends Node
	signal entitlement_checked(owned: bool)
	signal availability_changed(available: bool)
	signal purchase_message(message: String)
	signal ad_verification_result(request_id: int, confirmed_free: bool)
	signal entitlement_query_completed(query_id: int, owned: bool)
	var query_sequence := 1
	func start() -> void: pass
	func purchase() -> void: pass
	func refresh() -> void: pass
	func verify_free_before_ad(request_id: int) -> void:
		query_sequence += 1
		entitlement_checked.emit(false)
		entitlement_query_completed.emit(query_sequence, false)
		ad_verification_result.emit(request_id, true)

class FakeInterstitialAdapter:
	extends Node
	signal interstitial_opened(request_id: int)
	signal interstitial_impression(request_id: int)
	signal interstitial_closed(request_id: int)
	signal interstitial_failed(request_id: int)
	var loaded := true
	var accepts_show := true
	var show_calls := 0
	var state_when_shown := -1
	var active_request_id := -1
	var game: Control
	var ads_allowed := false

	func set_ads_allowed(allowed: bool) -> void:
		ads_allowed = allowed

	func is_interstitial_loaded() -> bool:
		return loaded and ads_allowed

	func show_interstitial(request_id: int) -> bool:
		active_request_id = request_id
		show_calls += 1
		state_when_shown = game.state
		return accepts_show

	func cancel_interstitial(_request_id: int) -> bool:
		return true

	func recover_interstitial(_request_id: int) -> bool:
		return true

	func confirm_impression() -> void:
		interstitial_impression.emit(active_request_id)

	func close_ad() -> void:
		interstitial_closed.emit(active_request_id)

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
	game.ball_position = Vector2(game.size.x * 0.5625, game.FIELD_MARGIN + 62.0)
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


func _expected_cpu_impact_y(game: Control) -> float:
	var impact_x: float = game.size.x - game.PADDLE_MARGIN - game.PADDLE_WIDTH * 0.5 - game._ball_radius()
	var time_to_impact: float = maxf(0.0, (impact_x - game.ball_position.x) / game.ball_velocity.x)
	time_to_impact = minf(time_to_impact, game.CPU_LOOKAHEAD[game.difficulty] * game._cpu_reach_factor())
	var expected_y: float = game.ball_position.y + game.ball_velocity.y * time_to_impact
	var top: float = game.FIELD_MARGIN + game._ball_radius()
	var bottom: float = game.size.y - top
	while expected_y < top or expected_y > bottom:
		if expected_y < top:
			expected_y = 2.0 * top - expected_y
		else:
			expected_y = 2.0 * bottom - expected_y
	return expected_y


func _finish_free_match(game: Control) -> void:
	game._start_match()
	for _point in range(game.WIN_SCORE):
		game._score_point(true)


func _run_tests() -> void:
	# Sem janela, o aspecto expand pode abrir uma area quadrada dependendo do host.
	# Fixamos o viewport de teste antes de criar a cena.
	root.size = Vector2i(960, 540)
	var presets := ConfigFile.new()
	_check(presets.load("res://export_presets.cfg") == OK, "Presets Android são válidos")
	_check(presets.get_value("preset.0", "custom_features", "") == "pong_unified" and presets.get_value("preset.1", "custom_features", "") == "pong_unified", "APK e AAB usam o mesmo código unificado")
	_check(not presets.has_section("preset.2") and not presets.has_section("preset.3"), "Somente um aplicativo; não há presets Pro separados")
	_check(presets.get_value("preset.0.options", "package/unique_name", "") == "com.pitinga.pongmobile" and presets.get_value("preset.1.options", "package/unique_name", "") == "com.pitinga.pongmobile", "APK e AAB têm o mesmo identificador Android")
	var exports_consistent := true
	for index in range(2):
		var values: String = presets.get_value("preset.%d" % index, "exclude_filter", "")
		exports_consistent = exports_consistent and values.contains("tests/*")
		var options_section := "preset.%d.options" % index
		exports_consistent = exports_consistent and presets.get_value(options_section, "architectures/arm64-v8a", false)
		exports_consistent = exports_consistent and not presets.get_value(options_section, "architectures/armeabi-v7a", true)
		exports_consistent = exports_consistent and not presets.get_value(options_section, "architectures/x86_64", true)
	exports_consistent = exports_consistent and presets.get_value("preset.0.options", "version/code", -1) == presets.get_value("preset.1.options", "version/code", -2)
	exports_consistent = exports_consistent and presets.get_value("preset.0.options", "version/name", "") == presets.get_value("preset.1.options", "version/name", "")
	exports_consistent = exports_consistent and presets.get_value("preset.0.options", "gradle_build/use_gradle_build", false)
	_check(exports_consistent, "Exports excluem testes, usam somente ARM64 e mantêm versões consistentes")
	_check(presets.get_value("preset.1.options", "gradle_build/min_sdk", "") == "24" and presets.get_value("preset.1.options", "gradle_build/target_sdk", "") == "36", "Publicação única mantém Android 7 e alvo API 36")
	_check(ProjectSettings.get_setting("display/window/stretch/aspect") == "expand", "Jogo aproveita telas fora do formato 16:9")
	_check((ProjectSettings.get_setting("application/config/features") as PackedStringArray).has("4.7"), "Projeto declara Godot 4.7, alinhado ao ambiente de CI")
	# Cada processo tem caminhos exclusivos para execução paralela no mesmo PC.
	var test_token := "%d_%d_%d" % [OS.get_process_id(), int(Time.get_unix_time_from_system() * 1000000.0), randi()]
	var test_settings_file := "user://pong_tests_%s_settings.cfg" % test_token
	var test_stats_file := "user://pong_tests_%s_stats.cfg" % test_token
	var test_ads_file := "user://pong_tests_%s_ads.cfg" % test_token
	var test_entitlement_file := "user://pong_tests_%s_entitlement.cfg" % test_token
	for test_file in [test_settings_file, test_stats_file, test_ads_file, test_entitlement_file]:
		for suffix in ["", ".bak", ".tmp"]:
			var candidate: String = test_file + suffix
			if FileAccess.file_exists(candidate):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
	var game: Control = load("res://scenes/main.tscn").instantiate()
	game.settings_file = test_settings_file
	game.stats_file = test_stats_file
	game.ad_policy_file = test_ads_file
	game.pro_entitlement_file = test_entitlement_file
	root.add_child(game)
	await process_frame

	_check(game.state == GameScript.GameState.MENU, "Abre no menu inicial")
	_check(game.difficulty == 1, "Dificuldade padrão é média")
	_check(not game.is_pro, "Execução padrão é edição Free")
	_check(game._pro_button != null and game._pro_button.visible and game._pro_button.disabled, "Free mostra compra interna Pro, desativada até existir Billing")
	_check((game._menu.get_child(0) as PanelContainer).get_combined_minimum_size().y <= 530.0, "Menu Free cabe na tela")
	game._open_settings()
	_check(game.state == GameScript.GameState.MENU, "Free não abre a personalização Pro")
	game._open_privacy()
	_check(game.state == GameScript.GameState.PRIVACY and game._privacy_menu.visible, "Política de privacidade acessível pelo menu")
	game._return_to_menu()
	_check(game.state == GameScript.GameState.MENU, "Volta da privacidade para o menu")
	game._difficulty_buttons[0].focus_mode = Control.FOCUS_ALL
	game._difficulty_buttons[0].grab_focus()
	var enter_key := InputEventKey.new()
	enter_key.keycode = KEY_ENTER
	enter_key.pressed = true
	game._input(enter_key)
	_check(game.state == GameScript.GameState.MENU, "Enter não inicia jogo quando outro botão possui foco")
	game._difficulty_buttons[0].release_focus()
	game._difficulty_buttons[0].focus_mode = Control.FOCUS_NONE
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
	_check(not ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch"), "Toque Android não gera segundo evento de mouse")
	game._set_player_y(game.size.y * 0.42)
	var before_touch: float = game.player_y
	var pause_touch := InputEventScreenTouch.new()
	pause_touch.position = game._pause_button.get_global_rect().get_center()
	pause_touch.pressed = true
	game._unhandled_input(pause_touch)
	_check(is_equal_approx(game.player_y, before_touch), "Toque em Pausar não desloca a raquete")
	var field_touch := InputEventScreenTouch.new()
	field_touch.position = Vector2(game.size.x * 0.18, game.size.y * 0.75)
	field_touch.pressed = true
	game._unhandled_input(field_touch)
	_check(is_equal_approx(game.player_y, field_touch.position.y), "Toque fora da GUI continua controlando a raquete")
	var prior_to_pause: float = game.player_y
	Input.parse_input_event(pause_touch)
	var pause_release := InputEventScreenTouch.new()
	pause_release.position = pause_touch.position
	pause_release.pressed = false
	Input.parse_input_event(pause_release)
	await process_frame
	_check(game.state == GameScript.GameState.PAUSED and is_equal_approx(game.player_y, prior_to_pause), "Toque real no botão Pausar é consumido pela interface")
	if game.state == GameScript.GameState.PAUSED:
		game._toggle_pause()
	game._notification(game.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(game.state == GameScript.GameState.PAUSED, "Perda de foco pausa a partida no computador")
	game._toggle_pause()
	var viewport_size: Vector2 = game.size
	game.cpu_y = -100.0
	game.player_y = game.size.y * 2.0
	game.ball_position = Vector2(game.size.x * 2.0, -50.0)
	game.size = Vector2(viewport_size.x * 1.3, viewport_size.y)
	game._on_resized()
	_check(game.player_y <= game.size.y and game.cpu_y >= 0.0 and game.ball_position.x <= game.size.x, "Redimensionamento mantém jogadores e bola dentro da quadra")
	game.size = viewport_size
	game._on_resized()

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
	_check(game._finish_title.text == "COMPUTADOR VENCEU!", "Placar final chama adversário de Computador")
	game._return_to_menu()
	_check(game.state == GameScript.GameState.MENU and game.player_score == 0, "Volta ao menu e limpa o placar")

	var ad_policy = AdPolicy.new()
	_check(ad_policy.MAX_ADS_PER_HOUR == 6, "Teto Free é de seis intersticiais por hora")
	for _i in range(3):
		ad_policy.note_finished_match()
	_check(not ad_policy.can_show(0), "Primeira, segunda e terceira partidas não permitem anúncio")
	ad_policy.note_finished_match()
	_check(ad_policy.can_show(0), "Quarta partida torna anúncio elegível")
	ad_policy.record_impression(0)
	_check(ad_policy.matches_since_ad == 0, "Impressão confirmada reinicia o contador de quatro partidas")
	for _i in range(4):
		ad_policy.note_finished_match()
	_check(not ad_policy.can_show(599999), "Intersticial respeita espera mínima de dez minutos")
	_check(ad_policy.can_show(600000), "Intersticial libera após dez minutos")
	ad_policy.record_impression(600000)
	for _i in range(4):
		ad_policy.note_finished_match()
	_check(ad_policy.can_show(1200000), "Limite de seis permite terceiro anúncio após dez minutos")
	_check(ad_policy.can_show(3600000), "Primeira impressão expira na fronteira exata de sessenta minutos")
	_check(ad_policy._impressions_msec.size() == 1 and ad_policy._impressions_msec[0] == 600000, "Poda descarta apenas impressões que completaram uma hora")
	_check(ad_policy.can_show(4200000) and ad_policy._impressions_msec.is_empty(), "Poda remove múltiplos registros vencidos na fronteira exata")
	var capped_policy = AdPolicy.new()
	for _i in range(4):
		capped_policy.note_finished_match()
	for _i in range(6):
		capped_policy.record_impression(0)
	# Simula seis impressões da rede no mesmo intervalo para testar o teto
	# independentemente da regra de dez minutos.
	for _i in range(4):
		capped_policy.note_finished_match()
	_check(not capped_policy.can_show(600000), "Seis impressões na última hora bloqueiam uma sétima")
	_check(capped_policy.can_show(3600000), "Após uma hora as seis impressões vencidas são removidas")
	_check(ad_policy.save_state(test_ads_file) == OK, "Limites de anúncios são salvos em arquivo de teste")
	var restored_policy = AdPolicy.new()
	_check(restored_policy.load_state(test_ads_file) == OK, "Limites de anúncios são recarregados após reiniciar")
	_check(restored_policy.matches_since_ad == ad_policy.MATCHES_PER_AD and restored_policy._last_impression_msec == 600000, "Recarrega contador e último anúncio sem zerar limites")
	_check(not restored_policy.can_show(599999), "Relógio local retrocedendo não libera anúncio")
	_check(restored_policy.can_show(4200000), "Após reinício, janela de publicidade expirada libera novo anúncio")

	# Integração de evento real de fim de partida com adaptador injetável.
	# Não carrega SDK, faz solicitações à rede nem usa identificadores reais.
	var fake_billing := FakeBilling.new()
	game.set_billing_adapter(fake_billing)
	fake_billing.entitlement_checked.emit(false)
	fake_billing.entitlement_query_completed.emit(1, false)
	game.set_ad_consent_granted(true)
	var fake_ad := FakeInterstitialAdapter.new()
	fake_ad.game = game
	game.add_child(fake_ad)
	game.set_interstitial_adapter(fake_ad)
	_check(not fake_ad.ads_allowed, "Mesmo após primeira confirmação Free e consentimento, não pré-carrega anúncios")
	game._ad_policy = AdPolicy.new()
	for match_number in range(3):
		_finish_free_match(game)
		await process_frame
		_check(fake_ad.show_calls == 0, "Partida %d: nenhum intersticial solicitado" % (match_number + 1))
	_finish_free_match(game)
	await process_frame
	_check(fake_ad.show_calls == 1 and fake_ad.state_when_shown == GameScript.GameState.FINISHED, "Só oferece intersticial ao concluir a quarta partida")
	game._try_show_interstitial_after_match()
	_check(fake_ad.show_calls == 1, "Não oferece intersticial duas vezes no mesmo fim de partida")
	_check(game._ad_policy.matches_since_ad == 4, "Solicitar exibição não conta como impressão")
	fake_ad.confirm_impression()
	_check(game._ad_policy.matches_since_ad == 0 and game._ad_policy._impressions_msec.size() == 1, "Callback de impressão consome crédito e registra frequência")
	var saved_ad_policy := AdPolicy.new()
	_check(saved_ad_policy.load_state(test_ads_file) == OK and saved_ad_policy._impressions_msec.size() == 1 and saved_ad_policy.matches_since_ad == 0, "Impressão de verdade é persistida imediatamente")
	fake_ad.confirm_impression()
	_check(game._ad_policy._impressions_msec.size() == 1, "Callback duplicado não duplica impressão")
	fake_ad.close_ad()
	_finish_free_match(game)
	await process_frame
	_check(fake_ad.show_calls == 1, "Não oferece novo anúncio na primeira partida após impressão")
	# Bloqueios de contexto, indisponibilidade e falha de SDK não consomem
	# partidas acumuladas; o próximo término pode tentar novamente.
	game._ad_policy = AdPolicy.new()
	for _i in range(4):
		game._ad_policy.note_finished_match()
	game._start_match()
	game._try_show_interstitial_after_match()
	_check(fake_ad.show_calls == 1, "Nenhum intersticial inicia durante uma partida")
	game._toggle_pause()
	game._try_show_interstitial_after_match()
	_check(fake_ad.show_calls == 1, "Nenhum intersticial inicia durante pausa")
	fake_ad.loaded = false
	_finish_free_match(game)
	await process_frame
	_check(fake_ad.show_calls == 1 and game._ad_policy.matches_since_ad == 4, "Sem anúncio carregado, jogo segue e contador continua elegível")
	fake_ad.loaded = true
	fake_ad.accepts_show = false
	_finish_free_match(game)
	await process_frame
	_check(fake_ad.show_calls == 2 and game._ad_policy.matches_since_ad == 4, "Falha do SDK não consome quatro partidas")
	fake_ad.accepts_show = true
	_finish_free_match(game)
	await process_frame
	_check(fake_ad.show_calls == 3, "Nova partida concluída permite nova tentativa após falha")
	fake_ad.close_ad()
	_check(game._ad_policy.matches_since_ad == 4, "Fechamento sem impressão não reinicia o contador")
	fake_ad.confirm_impression()
	_check(game._ad_policy.matches_since_ad == 0, "Impressão confirmada após fechamento continua atribuída à sua requisição")
	game.set_interstitial_adapter(null)
	game._return_to_menu()
	game._try_show_interstitial_after_match()
	_check(fake_ad.show_calls == 3, "Nenhum intersticial inicia no menu")

	game.free()
	game = load("res://scenes/main.tscn").instantiate()
	game.is_pro = true
	game.settings_file = test_settings_file
	game.stats_file = test_stats_file
	game.pro_entitlement_file = test_entitlement_file
	root.add_child(game)
	await process_frame
	_check(game._stats["played"] == 0 and game._stats["best_survival"] == 0, "Pro começa com estatísticas de teste vazias")
	var settings_panel := game._settings_menu.get_child(0) as PanelContainer
	_check(settings_panel.get_combined_minimum_size().y <= 530.0, "Painel de personalização cabe no celular em paisagem")
	game._open_settings()
	_check(game.state == GameScript.GameState.SETTINGS, "Pro abre tela de personalização")
	game._set_ball_size(140)
	game._set_paddle_size(150)
	_check(is_equal_approx(game._ball_radius(), 14.0), "Pro aumenta raio e colisão da bola")
	_check(is_equal_approx(game._paddle_height(), 150.0), "Pro altera as duas raquetes")
	_check(game._mode_selector.get_item_text(0) == "CLÁSSICO VS COMPUTADOR", "Modo clássico usa nome Computador")
	game._set_ball_size(70)
	game._set_paddle_size(70)
	game._select_difficulty(1)
	_check(is_equal_approx(game._cpu_aim_error(), 56.0), "Margem de erro da CPU reduz com bola e raquete menores")
	_check(is_equal_approx(game._cpu_reach_factor(), 1.25), "CPU compensa alcance menor dentro de limite seguro")
	_check(_cpu_defends_shot(game, 1, 650.0), "Médio ainda defende lance moderado com bola e raquete a 70%")
	_check(not _cpu_defends_shot(game, 1, 850.0), "Médio ainda pode sofrer ponto com bola rápida a 70%")
	game._select_difficulty(2)
	game._start_match()
	game._serve_countdown = 0.0
	game.ball_position = Vector2(800.0, 40.0)
	game.ball_velocity = Vector2(400.0, -250.0)
	game._cpu_aim_bias = 0.0
	game._cpu_reaction_timer = 0.0
	game._update_cpu(0.0)
	_check(is_equal_approx(game._cpu_target_y, _expected_cpu_impact_y(game)), "CPU prevê rebote e colisão com bola a 70%")
	game._set_ball_size(150)
	game._cpu_reaction_timer = 0.0
	game._update_cpu(0.0)
	_check(is_equal_approx(game._cpu_target_y, _expected_cpu_impact_y(game)), "CPU recalcula rebote e colisão com bola a 150%")
	game._set_ball_size(140)
	game._set_paddle_size(150)
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
	_check(game.state == GameScript.GameState.FINISHED and int(game._stats["best_survival"]) == 1, "Sobrevivência acaba ao perder e guarda recorde exato")
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
	_check(game._stats["played"] == game._count_pro_matches() and game._stats["survival_matches"] == 1 and game._stats["custom_wins"] == 1, "Total de partidas Pro corresponde à soma dos modos")
	game._set_points(2)
	_check(game.point_limit == 21, "Pro também permite partidas de 21 pontos")
	_check(not game._is_standard_rules(), "Regras personalizadas não entram nos recordes padrão")
	game._restore_pro_defaults()
	_check(game.ball_scale == 1.0 and game.paddle_scale == 1.0 and game.theme_index == 0, "Restaura dimensões e cores originais com um toque")
	_check(game.match_mode == GameScript.MatchMode.CLASSIC and game.point_limit == 7, "Restaurar padrão também recupera as regras clássicas")
	var stored := ConfigFile.new()
	_check(stored.load(game.settings_file) == OK and is_equal_approx(float(stored.get_value("visual", "ball_scale", 0.0)), 1.0), "Preferências Pro são guardadas localmente")
	game._set_ball_size(120)
	game._select_theme(1)
	game.ball_scale = 0.7
	game.theme_index = 2
	game._load_pro_settings()
	_check(is_equal_approx(game.ball_scale, 1.2) and game.theme_index == 1, "Round-trip restaura arquivo mesmo após alterar apenas a memória")
	game._restore_pro_defaults()

	var real_pro: Control = load("res://scenes/main.tscn").instantiate()
	real_pro.is_pro = true
	real_pro.settings_file = test_settings_file
	real_pro.stats_file = test_stats_file
	real_pro.pro_entitlement_file = test_entitlement_file
	root.add_child(real_pro)
	await process_frame
	_check(real_pro.is_pro and real_pro._pro_button != null and not real_pro._pro_button.visible and real_pro._pro_row.visible, "Menu Pro troca compra interna pelos recursos adquiridos")
	var pro_fake_ad := FakeInterstitialAdapter.new()
	pro_fake_ad.game = real_pro
	real_pro.add_child(pro_fake_ad)
	real_pro.set_interstitial_adapter(pro_fake_ad)
	real_pro._start_match()
	real_pro._complete_match(true)
	await process_frame
	_check(real_pro._interstitial_adapter == pro_fake_ad and pro_fake_ad.show_calls == 0, "Pro preserva adaptador para eventual reembolso, mas nunca solicita anúncio")
	_check(real_pro._stats["best_survival"] == 1, "Nova instância Pro carrega estatísticas do teste isolado")
	var pro_menu_panel := real_pro._menu.get_child(0) as PanelContainer
	_check(pro_menu_panel.get_combined_minimum_size().y <= 530.0, "Menu Pro cabe no celular em paisagem")
	var stats_panel := real_pro._stats_menu.get_child(0) as PanelContainer
	_check(stats_panel.get_combined_minimum_size().y <= 530.0, "Estatísticas Pro cabem no celular em paisagem")
	real_pro.free()

	game.free()
	var legacy_stats := ConfigFile.new()
	legacy_stats.set_value("stats", "played", 3)
	legacy_stats.set_value("stats", "standard_wins", 1)
	legacy_stats.set_value("stats", "two_player_matches", 1)
	_check(legacy_stats.save(test_stats_file) == OK, "Prepara arquivo antigo de estatísticas para migração")
	var migrated_game: Control = GameScript.new()
	migrated_game.stats_file = test_stats_file
	migrated_game._load_pro_stats()
	_check(migrated_game._stats["survival_matches"] == 1 and migrated_game._stats["played"] == 3, "Pro migra totais antigos sem perder as partidas de sobrevivência")
	migrated_game.free()
	for test_file in [test_settings_file, test_stats_file, test_ads_file, test_entitlement_file]:
		for suffix in ["", ".bak", ".tmp"]:
			var candidate: String = test_file + suffix
			if FileAccess.file_exists(candidate):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
			_check(not FileAccess.file_exists(candidate), "Apaga arquivo temporário de teste: " + candidate.get_file())
	if _failures == 0:
		print("\nTodos os testes passaram.")
	else:
		push_error("%d teste(s) falharam." % _failures)
	quit(1 if _failures > 0 else 0)
