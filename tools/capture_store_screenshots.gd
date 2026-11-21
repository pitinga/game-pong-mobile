extends SceneTree
## Captura telas REAIS da UI do jogo para a ficha do Google Play.
## Execute com ambiente gráfico:
## godot --path . --windowed --resolution 960x540 --script res://tools/capture_store_screenshots.gd


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var game: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await _save("res://store/screenshots/01-menu.png")

	game._select_difficulty(1)
	game._start_match()
	game._serve_countdown = 0.0
	game.player_score = 3
	game.cpu_score = 2
	game.player_y = 240.0
	game.cpu_y = 310.0
	game.ball_position = Vector2(610.0, 220.0)
	game.ball_velocity = Vector2(660.0, -410.0)
	game._trail.clear()
	for i in range(1, 9):
		game._trail.append(game.ball_position - game.ball_velocity.normalized() * float(i) * 17.0)
	game.queue_redraw()
	await _save("res://store/screenshots/02-partida.png")

	for _point in range(4):
		game._score_point(true)
	game.queue_redraw()
	await _save("res://store/screenshots/03-vitoria.png")
	game.free()
	quit()


func _save(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var screenshot := root.get_viewport().get_texture().get_image()
	if screenshot.is_empty():
		push_error("Não foi possível capturar a tela: " + path)
		quit(1)
		return
	var result := screenshot.save_png(path)
	if result != OK:
		push_error("Erro ao salvar tela: " + path)
		quit(1)
	else:
		print("CAPTURA: " + path)
