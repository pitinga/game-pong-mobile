extends SceneTree
## Simulação headless da mesma trajetória em três proporções.
## Registra diferenças de tempo; NÃO afirma equivalência de dificuldade.

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
	var results: Dictionary = {}
	for width in [720, 960, 1200]:
		seed(12345)
		root.size = Vector2i(width, 540)
		var game: Control = load("res://scenes/main.tscn").instantiate()
		game.is_pro = true
		var token := "%d_%d_%d" % [width, OS.get_process_id(), randi()]
		game.settings_file = "user://pong_aspect_%s_settings.cfg" % token
		game.stats_file = "user://pong_aspect_%s_stats.cfg" % token
		root.add_child(game)
		await process_frame
		_check(game._sound_players.is_empty(), "Runner headless não inicia canais de áudio sem saída")
		game._select_difficulty(1)
		game._start_match()
		game._serve_countdown = 0.0
		game.ball_position = Vector2(game.size.x * 0.5, game.size.y * 0.5)
		game.ball_velocity = Vector2(game.BASE_BALL_SPEED, 0)
		game.cpu_y = game.size.y * 0.5
		game._cpu_target_y = game.cpu_y
		game._cpu_aim_bias = 0.0
		game._cpu_reaction_timer = 0.0
		var ticks := 0
		while ticks < 180 and game.ball_velocity.x > 0.0 and game.player_score == 0:
			game._physics_process(1.0 / 60.0)
			ticks += 1
		results[width] = ticks
		var expected_width: int = 960 if width < 960 else width
		var expected_height: int = 720 if width == 720 else 540
		_check(game.size == Vector2(expected_width, expected_height) and game.state == 1 and game.ball_velocity.x < 0.0, "%dx540: área lógica expandida e contato real da raquete" % width)
		print("MATRIZ | tela %dx540 | lógica %.0fx%.0f | contato CPU %d ticks (%.3f s)" % [width, game.size.x, game.size.y, ticks, ticks / 60.0])
		game.free()
		for file in ["user://pong_aspect_%s_settings.cfg" % token, "user://pong_aspect_%s_stats.cfg" % token]:
			for suffix in ["", ".bak", ".tmp"]:
				var candidate: String = file + suffix
				if FileAccess.file_exists(candidate):
					DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
	_check(results[720] == results[960] and results[960] < results[1200], "Expand amplia altura em 4:3 e aumenta travessia horizontal em 20:9")
	print("Matriz de proporções: %d falha(s)." % failures)
	quit(1 if failures else 0)
