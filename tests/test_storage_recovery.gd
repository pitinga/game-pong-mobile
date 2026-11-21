extends SceneTree
## Recuperação de preferências e estatísticas Pro após arquivo corrompido.

const GameScript = preload("res://scripts/pong.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if ok:
		print("OK  - " + message)
	else:
		failures += 1
		push_error("FALHOU - " + message)


func _corrupt(path: String) -> void:
	var handle := FileAccess.open(path, FileAccess.WRITE)
	if handle == null:
		push_error("Não foi possível preparar corrupção em arquivo de teste: " + path)
		failures += 1
		return
	handle.store_string("[arquivo_incompleto\nchave =")
	handle.close()


func _run() -> void:
	root.size = Vector2i(960, 540)
	var token := "%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var settings_path := "user://pong_storage_%s_settings.cfg" % token
	var stats_path := "user://pong_storage_%s_stats.cfg" % token
	var game: Control = load("res://scenes/main.tscn").instantiate()
	game.is_pro = true
	game.settings_file = settings_path
	game.stats_file = stats_path
	root.add_child(game)
	await process_frame
	game._set_ball_size(130.0)
	game._set_ball_size(140.0)
	_check(FileAccess.file_exists(settings_path + ".bak"), "Preferências possuem backup anterior válido")
	game._start_match()
	game._complete_match(true)
	game._start_match()
	game._complete_match(true)
	_check(FileAccess.file_exists(stats_path + ".bak"), "Estatísticas possuem backup após salvar partidas")
	_check(not FileAccess.file_exists(settings_path + ".tmp") and not FileAccess.file_exists(stats_path + ".tmp"), "Gravação bem-sucedida não deixa arquivos temporários")
	game.free()

	_corrupt(settings_path)
	_corrupt(stats_path)
	var reopened: Control = load("res://scenes/main.tscn").instantiate()
	reopened.is_pro = true
	reopened.settings_file = settings_path
	reopened.stats_file = stats_path
	root.add_child(reopened)
	await process_frame
	_check(is_equal_approx(reopened.ball_scale, 1.3), "Preferência é restaurada do último backup válido")
	_check(int(reopened._stats["custom_wins"]) >= 1 and int(reopened._stats["best_streak"]) >= 1, "Histórico de vitórias personalizadas sobrevive à corrupção do arquivo principal")
	_check(int(reopened._stats["streak"]) == 0 and int(reopened._stats["custom_losses"]) == 0, "Backup de partida interrompida quebra sequência sem derrota falsa")
	var backup := ConfigFile.new()
	_check(backup.load(stats_path + ".bak") == OK and int(backup.get_value("stats", "custom_wins", 0)) >= 1, "Recuperação não substitui backup válido por arquivo corrompido")
	reopened.free()

	for path in [settings_path, stats_path]:
		for suffix in ["", ".bak", ".tmp"]:
			var candidate: String = path + suffix
			if FileAccess.file_exists(candidate):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
	print("Persistência recuperável: %d falha(s)." % failures)
	quit(1 if failures else 0)
