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
	game._launch_ball()
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

	game._set_mode(0)
	game._start_match()
	game._complete_match(true)
	_check(game._stats["streak"] == 1 and game._stats["played"] == 3, "Vitória clássica inicia sequência e conta uma partida")
	game._start_match()
	_check(game._stats["streak"] == 1, "Jogar novamente após concluir não quebra sequência")
	game._start_match()
	_check(game._stats["streak"] == 0 and game._stats["played"] == 3 and game._stats["standard_losses"] == 0, "Reiniciar clássico em andamento quebra sequência sem derrota artificial")
	game._complete_match(true)
	_check(game._stats["streak"] == 1 and game._stats["best_streak"] == 1, "Nova vitória após abandono reinicia sequência em um")
	game._return_to_menu()
	_check(game._stats["streak"] == 1, "Voltar ao menu depois da vitória conserva sequência")
	game._start_match()
	game._toggle_pause()
	game._return_to_menu()
	_check(game._stats["streak"] == 0 and game._stats["played"] == 4 and game._stats["standard_losses"] == 0, "Abandonar clássico pausado quebra sequência sem contabilizar derrota")
	var stored := ConfigFile.new()
	_check(stored.load(test_stats) == OK and int(stored.get_value("stats", "streak", -1)) == 0, "Abandono atualiza sequência persistida")

	game.free()
	for file in [test_settings, test_stats]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	print("Regras de produto: %d falha(s)." % failures)
	quit(1 if failures else 0)
