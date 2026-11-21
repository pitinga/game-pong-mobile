extends SceneTree
## Oráculo geométrico independente para a varredura da bola contra a raquete.
## Execute: godot --headless --path . --script res://tests/test_sweep_geometry.gd

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


func _distance_to_paddle(point: Vector2, paddle_x: float, paddle_y: float, half_height: float, half_width: float) -> float:
	# Oráculo: distância euclidiana do centro à posição mais próxima no retângulo.
	var nearest := Vector2(clampf(point.x, paddle_x - half_width, paddle_x + half_width), clampf(point.y, paddle_y - half_height, paddle_y + half_height))
	return point.distance_to(nearest)


func _run() -> void:
	root.size = Vector2i(960, 540)
	var token := "%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var ads_file := "user://pong_sweep_%s_ads.cfg" % token
	var game: Control = load("res://scenes/main.tscn").instantiate()
	game.is_pro = false
	game.ad_policy_file = ads_file
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)

	# Regressões que antes devolviam t=0,5 sem contato geométrico.
	var false_top: float = game._sweep_paddle_contact(Vector2(100, 208), Vector2(98, 212), 55, 270, 270, true)
	var false_bottom: float = game._sweep_paddle_contact(Vector2(100, 332), Vector2(98, 328), 55, 270, 270, true)
	var false_right_top: float = game._sweep_paddle_contact(Vector2(860, 208), Vector2(862, 212), 905, 270, 270, false)
	var false_right_bottom: float = game._sweep_paddle_contact(Vector2(860, 332), Vector2(862, 328), 905, 270, 270, false)
	_check(false_top < 0.0 and false_bottom < 0.0, "P1: sem contato fantasma nas bordas superior e inferior distantes")
	_check(false_right_top < 0.0 and false_right_bottom < 0.0, "P2: espelhos superior/inferior sem contato fantasma")
	var genuine: float = game._sweep_paddle_contact(Vector2(63, 200), Vector2(59, 230), 55, 270, 270, true)
	_check(absf(genuine - 1.0 / 3.0) < 0.001, "Contato legítimo com borda superior preserva t=1/3")
	for scale in [0.7, 1.0, 1.5]:
		game.ball_scale = scale
		game.paddle_scale = scale
		var edge: float = game._paddle_height() * 0.5 + game._ball_radius()
		var upper: float = game._sweep_paddle_contact(Vector2(63, 270.0 - edge - 10.0), Vector2(59, 270.0 - edge + 20.0), 55, 270, 270, true)
		var lower: float = game._sweep_paddle_contact(Vector2(63, 270.0 + edge + 10.0), Vector2(59, 270.0 + edge - 20.0), 55, 270, 270, true)
		var right_upper: float = game._sweep_paddle_contact(Vector2(897, 270.0 - edge - 10.0), Vector2(901, 270.0 - edge + 20.0), 905, 270, 270, false)
		var right_lower: float = game._sweep_paddle_contact(Vector2(897, 270.0 + edge + 10.0), Vector2(901, 270.0 + edge - 20.0), 905, 270, 270, false)
		_check(absf(upper - 1.0 / 3.0) < 0.001 and absf(lower - 1.0 / 3.0) < 0.001 and absf(right_upper - 1.0 / 3.0) < 0.001 and absf(right_lower - 1.0 / 3.0) < 0.001, "%.1fx: contato válido na superfície plana, quatro lados simétricos" % scale)

	# Independente da implementação: no t devolvido, a distância ao
	# retângulo desenhado deve ser <= raio. Amostragem determinística ampla.
	for scale in [0.7, 1.0, 1.5]:
		game.ball_scale = scale
		game.paddle_scale = scale
		var radius: float = game._ball_radius()
		var half_height: float = game._paddle_height() * 0.5
		var half_width: float = game.PADDLE_WIDTH * 0.5
		var invalid_contacts := 0
		var evaluated := 0
		for is_player in [true, false]:
			var sign := 1.0 if is_player else -1.0
			var paddle_x := 55.0 if is_player else 905.0
			for relative_x in [half_width + radius + 1.0, half_width + radius + 10.0, half_width + radius + 35.0, half_width + radius + 65.0, half_width + radius + 100.0]:
				for relative_y in [-half_height - radius - 15.0, -half_height - radius - 3.0, -half_height - radius - 1.0, -half_height, 0.0, half_height, half_height + radius + 1.0, half_height + radius + 3.0, half_height + radius + 15.0]:
					for movement_y in [-35.0, -15.0, 0.0, 15.0, 35.0]:
						for movement_x in [12.0, 35.0, 85.0]:
							var start := Vector2(paddle_x + sign * relative_x, 270.0 + relative_y)
							var finish := start + Vector2(-sign * movement_x, movement_y)
							var impact: float = game._sweep_paddle_contact(start, finish, paddle_x, 270.0, 270.0, is_player)
							evaluated += 1
							if impact >= 0.0:
								var contact := start.lerp(finish, impact)
								if _distance_to_paddle(contact, paddle_x, 270.0, half_height, half_width) > radius + 0.05:
									invalid_contacts += 1
		_check(invalid_contacts == 0, "%.1fx: %d trajetórias/escalas sem falso positivo (incompatíveis: %d)" % [scale, evaluated, invalid_contacts])

	# Regressão integrada do solver: falso contato não pode inverter vx.
	game.ball_scale = 1.0
	game.paddle_scale = 1.0
	game._start_match()
	game._serve_countdown = 0.0
	game.player_y = 270.0
	game.ball_position = Vector2(100, 208)
	game.ball_velocity = Vector2(-500, 1000)
	var scored: bool = game._advance_ball_substep(0.004, 270.0, 270.0, 270.0, 270.0)
	_check(not scored and game.ball_velocity == Vector2(-500, 1000) and game.ball_position.distance_to(Vector2(98, 212)) < 0.01, "Solver não inventa rebote distante da raquete")

	game.free()
	if FileAccess.file_exists(ads_file):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ads_file))
	print("Geometria de varredura: %d falha(s)." % failures)
	quit(1 if failures else 0)
