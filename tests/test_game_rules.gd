extends SceneTree
## Regras acordadas: Sobrevivência progressiva e sequência competitiva Pro.

const GameScript = preload("res://scripts/pong.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, description: String) -> void:
	if ok:
		print("OK  - " + description)
	else:
		failures += 1
		push_error("FALHOU - " + description)


func _run() -> void:
	root.size = Vector2i(960, 540)
	var token := "%d_%d_%d" % [OS.get_process_id(), int(Time.get_unix_time_from_system() * 1000000.0), randi()]
	var test_settings := "user://pong_rules_%s_settings.cfg" % token
	var test_stats := "user://pong_rules_%s_stats.cfg" % token
	var game: Control = load("res://scenes/main.tscn").instantiate()
	game.is_pro = true
	game.settings_file = test_settings
	game.stats_file = test_stats
	root.add_child(game)
	await process_frame

	game._set_mode(1)
	game._start_match()
	game.ball_velocity = Vector2(780.0, 0.0)
	game.survival_hits = 9
	game._score_point(true)
	_check(game.state == GameScript.GameState.PLAYING and game.survival_hits == 9 and game._serve_countdown > 0.0, "Ponto contra computador não encerra Sobrevivência nem perde rebatidas")
	_check(is_equal_approx(float(game.call("_displayed_ball_speed_ratio")) if game.has_method("_displayed_ball_speed_ratio") else -1.0, 780.0 / game.BASE_BALL_SPEED), "Indicador do countdown informa a velocidade do próximo saque")
	game._physics_process(1.0)
	_check(is_equal_approx(game.ball_velocity.length(), 780.0), "Sobrevivência mantém a velocidade de 780 após pontuar")
	game.ball_velocity = Vector2(game.MAX_BALL_SPEED, 0.0)
	game._score_point(true)
	game._launch_ball()
	_check(is_equal_approx(game.ball_velocity.length(), game.MAX_BALL_SPEED), "Sobrevivência conserva limite máximo após novas reposições")
	game._score_point(false)
	_check(game._stats["best_survival"] == 9, "Perda após reposições salva recorde de nove rebatidas")
	game._start_match()
	game._launch_ball()
	_check(is_equal_approx(game.ball_velocity.length(), game.BASE_BALL_SPEED) and game.survival_hits == 0, "Nova tentativa de Sobrevivência reinicia velocidade e rebatidas")
	game._score_point(false)
	_check(game.state == GameScript.GameState.FINISHED and game._stats["best_survival"] == 9, "Perda encerra nova Sobrevivência e preserva recorde anterior")
	game._start_match()
	game.survival_hits = 3
	game._serve_countdown = 0.0
	game.ball_position = Vector2(game.size.x + game._ball_radius() - 1.0, game.size.y * 0.5)
	game.ball_velocity = Vector2(780.0, 0.0)
	game._physics_process(0.006)
	_check(game.state == GameScript.GameState.PLAYING and game.survival_hits == 3 and game._serve_speed >= 780.0, "Gol integrado preserva velocidade e rebatidas na Sobrevivência")
	game._physics_process(1.0)
	_check(is_equal_approx(game.ball_velocity.length(), game._serve_speed), "Countdown real lança Sobrevivência na velocidade preservada")
	game._score_point(false)

	game._set_mode(0)
	game._start_match()
	game._complete_match(true)
	_check(game._stats["streak"] == 1 and game._stats["played"] == 4, "Vitória clássica inicia sequência e conta uma partida")
	game._start_match()
	_check(game._stats["streak"] == 1, "Jogar novamente após concluir não quebra sequência")
	game._start_match()
	_check(game._stats["streak"] == 0 and game._stats["played"] == 4 and game._stats["standard_losses"] == 0, "Reiniciar clássico em andamento quebra sequência sem derrota artificial")
	game._complete_match(true)
	_check(game._stats["streak"] == 1 and game._stats["best_streak"] == 1, "Nova vitória após abandono reinicia sequência em um")
	game._return_to_menu()
	_check(game._stats["streak"] == 1, "Voltar ao menu depois da vitória conserva sequência")
	game._start_match()
	game._toggle_pause()
	game._return_to_menu()
	_check(game._stats["streak"] == 0 and game._stats["played"] == 5 and game._stats["standard_losses"] == 0, "Abandonar clássico pausado quebra sequência sem contabilizar derrota")
	var stored := ConfigFile.new()
	_check(stored.load(test_stats) == OK and int(stored.get_value("stats", "streak", -1)) == 0, "Abandono atualiza sequência persistida")
	game._start_match()
	game._complete_match(true)
	stored.load(test_stats)
	_check(not bool(stored.get_value("stats", "active_classic_match", false)), "Partida concluída limpa marcador persistente")
	game._start_match()
	stored.load(test_stats)
	_check(bool(stored.get_value("stats", "active_classic_match", false)), "Clássico iniciado registra tentativa em andamento")
	game._notification(game.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(game.state == GameScript.GameState.PAUSED and game._stats["streak"] == 1, "Perda temporária de foco preserva sequência até encerramento do processo")

	game.free()
	var reopened: Control = load("res://scenes/main.tscn").instantiate()
	reopened.is_pro = true
	reopened.settings_file = test_settings
	reopened.stats_file = test_stats
	root.add_child(reopened)
	await process_frame
	stored.load(test_stats)
	_check(reopened._stats["streak"] == 0 and not bool(stored.get_value("stats", "active_classic_match", false)), "Reabertura após partida interrompida quebra sequência sem registrar derrota")
	_check(reopened._stats["standard_losses"] == 0 and reopened._stats["best_streak"] >= 1, "Recuperação preserva recorde e não cria derrota falsa")
	reopened.free()
	for file in [test_settings, test_stats]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	print("Regras de produto: %d falha(s)." % failures)
	quit(1 if failures else 0)
