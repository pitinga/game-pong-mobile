extends SceneTree
## Testa callbacks fora de ordem sem SDK/IDs reais.

const AdPolicy = preload("res://scripts/ad_policy.gd")
const GameScript = preload("res://scripts/pong.gd")

class CountingPolicy:
	extends "res://scripts/ad_policy.gd"
	var completions := 0

	func note_finished_match() -> void:
		completions += 1
		super.note_finished_match()

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

class DelayedInterstitial:
	extends Node
	signal interstitial_opened(request_id: int)
	signal interstitial_impression(request_id: int)
	signal interstitial_closed(request_id: int)
	signal interstitial_failed(request_id: int)
	var requests: Array[int] = []
	var loaded := true
	var cancel_success := true
	var canceled: Array[int] = []
	var cancel_calls: Array[int] = []
	var recovery_calls: Array[int] = []
	var safe_recovery := false
	var ads_allowed := false

	func set_ads_allowed(allowed: bool) -> void:
		ads_allowed = allowed

	func is_interstitial_loaded() -> bool:
		return loaded and ads_allowed

	func show_interstitial(request_id: int = -1) -> bool:
		requests.append(request_id)
		return true

	func cancel_interstitial(request_id: int) -> bool:
		cancel_calls.append(request_id)
		if cancel_success:
			canceled.append(request_id)
		return cancel_success

	# Confirmação nativa: só retorna true se nenhuma publicidade tardia
	# poderá abrir e se nenhuma tela de anúncio continua visível.
	func recover_interstitial(request_id: int) -> bool:
		recovery_calls.append(request_id)
		return safe_recovery

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	if ok:
		print("OK  - " + label)
	else:
		failures += 1
		push_error("FALHOU - " + label)


func _run() -> void:
	root.size = Vector2i(960, 540)
	var ads_file := "user://pong_async_%d_%d_%d.cfg" % [OS.get_process_id(), int(Time.get_unix_time_from_system() * 1000000.0), randi()]
	var purchase_file := ads_file.replace(".cfg", "_purchase.cfg")
	for path in [ads_file, purchase_file]:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	var game: Control = load("res://scenes/main.tscn").instantiate()
	game.ad_policy_file = ads_file
	game.pro_entitlement_file = purchase_file
	root.add_child(game)
	await process_frame
	var fake_billing := FakeBilling.new()
	game.set_billing_adapter(fake_billing)
	fake_billing.entitlement_checked.emit(false)
	fake_billing.entitlement_query_completed.emit(1, false)
	game.set_ad_consent_granted(true)
	var mock := DelayedInterstitial.new()
	game.add_child(mock)
	game.set_interstitial_adapter(mock)
	game._ad_policy = CountingPolicy.new()
	for _i in range(3):
		game._ad_policy.note_finished_match()
	game._start_match()
	game._complete_match(true)
	game._complete_match(true)
	game._score_point(true)
	await process_frame
	_check(game._ad_policy.completions == 4 and game.player_score == 0, "Encerramento e ponto tardio não creditam partidas duplicadas")
	_check(mock.requests.size() == 1, "Uma solicitação por partida, mesmo com conclusão duplicada")
	var first_id := mock.requests[0] if not mock.requests.is_empty() else -1
	game._start_match()
	_check(game.state == GameScript.GameState.FINISHED, "Nova partida espera resposta de exibição assíncrona")
	game._return_to_menu()
	_check(game.state == GameScript.GameState.FINISHED, "Menu não abre enquanto uma exibição foi aceita")
	mock.interstitial_opened.emit(first_id)
	_check(game.state == GameScript.GameState.FINISHED, "Callback tardio de abertura mantém jogo na tela de fim")
	mock.interstitial_impression.emit(first_id)
	_check(game._ad_policy.matches_since_ad == 0 and game._ad_policy._impressions_msec.size() == 1, "Impressão atrasada é registrada mesmo após interação no fim")
	mock.interstitial_impression.emit(first_id)
	_check(game._ad_policy._impressions_msec.size() == 1, "Callback duplicado de impressão não conta duas vezes")
	mock.interstitial_closed.emit(first_id)
	game._start_match()
	_check(game.state == GameScript.GameState.PLAYING, "Fechamento do anúncio libera nova partida")
	var restored := AdPolicy.new()
	_check(restored.load_state(ads_file) == OK and restored._impressions_msec.size() == 1, "Impressão assíncrona foi salva no perfil de teste")
	# Nova requisição simula a passagem de 10 minutos, sem esperar em tempo real.
	game._ad_policy._last_impression_msec = game._ad_now_msec() - 600000
	game._ad_policy.matches_since_ad = 3
	game._complete_match(false)
	await process_frame
	_check(mock.requests.size() == 2, "Nova partida concluída abre nova solicitação elegível")
	var second_id := mock.requests[1] if mock.requests.size() > 1 else -1
	_check(second_id != first_id and second_id > first_id, "IDs distintos identificam cada tentativa")
	mock.interstitial_impression.emit(first_id)
	_check(game._ad_policy.matches_since_ad == 4, "Callback antigo não consome crédito da solicitação nova")
	mock.interstitial_failed.emit(second_id)
	game._return_to_menu()
	_check(game.state == GameScript.GameState.MENU and game._ad_policy.matches_since_ad == 4, "Falha assíncrona libera navegação sem consumir partidas")
	# Abandono seguro quando a abertura não retorna: cancelamento do adaptador.
	game._start_match()
	game._complete_match(false)
	await process_frame
	var third_id: int = mock.requests.back() if not mock.requests.is_empty() else -1
	game._ad_requested_at_ticks -= 30000
	game._process(0.0)
	_check(mock.canceled.has(third_id), "Timeout pede cancelamento antes de desbloquear")
	game._start_match()
	_check(game.state == GameScript.GameState.PLAYING, "Cancelamento garantido pelo adaptador libera partida")
	mock.interstitial_impression.emit(third_id)
	_check(game._ad_policy.matches_since_ad == 4, "Callback de requisição cancelada não conta impressão")
	# Troca de SDK sem cancelamento garantido não pode soltar uma requisição.
	game._ad_policy = CountingPolicy.new()
	for _i in range(3):
		game._ad_policy.note_finished_match()
	game._complete_match(false)
	await process_frame
	var fourth_id: int = mock.requests.back()
	mock.cancel_success = false
	game.set_interstitial_adapter(null)
	_check(game._interstitial_adapter == mock and game._active_ad_request_id == fourth_id, "Não troca adaptador quando apresentação pendente não pode ser cancelada")
	mock.interstitial_impression.emit(fourth_id)
	_check(game._interstitial_state == GameScript.InterstitialState.SHOWING, "Impressão antes de abertura marca anúncio como exibindo")
	game._ad_requested_at_ticks -= 30000
	game._process(0.0)
	_check(not mock.canceled.has(fourth_id), "Timeout não cancela um anúncio que já registrou impressão")
	mock.interstitial_closed.emit(fourth_id)
	game.set_interstitial_adapter(null)
	_check(game._interstitial_adapter == null, "Troca de adaptador só é liberada após fechamento")
	# Sem callbacks, cancelamento false exige nova tentativa ou recuperação
	# nativa segura; jamais liberar uma nova partida com anúncio tardio.
	game.set_interstitial_adapter(mock)
	game._ad_policy = CountingPolicy.new()
	for _i in range(3):
		game._ad_policy.note_finished_match()
	game._start_match()
	game._complete_match(false)
	await process_frame
	var fifth_id: int = mock.requests.back()
	var initial_calls := mock.cancel_calls.size()
	game._ad_requested_at_ticks -= 120000
	game._process(0.0)
	_check(mock.cancel_calls.size() == initial_calls + 1 and game._active_ad_request_id == fifth_id, "Cancelamento inconclusivo não libera nova partida")
	_check(game._ad_status_label.visible and game._ad_safe_exit_button.visible, "Falha persistente apresenta mensagem e saída segura do app")
	game._start_match()
	_check(game.state == GameScript.GameState.FINISHED, "Anúncio inconclusivo bloqueia nova partida")
	game._ad_next_recovery_attempt_ticks -= 5000
	game._process(0.0)
	_check(mock.cancel_calls.size() >= initial_calls + 2 or mock.recovery_calls.has(fifth_id), "Watchdog tenta recuperar solicitação sem callback, mesmo após cancelamento false")
	mock.safe_recovery = true
	game._ad_next_recovery_attempt_ticks -= 5000
	game._notification(game.NOTIFICATION_APPLICATION_RESUMED)
	_check(game._active_ad_request_id == -1, "Garantia nativa de recuperação encerra solicitação travada")
	game._start_match()
	_check(game.state == GameScript.GameState.PLAYING, "Recuperação confirmada permite nova partida")
	mock.interstitial_opened.emit(fifth_id)
	mock.interstitial_impression.emit(fifth_id)
	_check(game.state == GameScript.GameState.PLAYING and game._ad_policy._impressions_msec.is_empty(), "Callback tardio de solicitação recuperada não invade partida nem conta impressão")
	# Abertura sem fechamento também exige watchdog e confirmação nativa.
	mock.safe_recovery = false
	game._ad_policy = CountingPolicy.new()
	for _i in range(3):
		game._ad_policy.note_finished_match()
	game._complete_match(false)
	await process_frame
	var sixth_id: int = mock.requests.back()
	mock.interstitial_opened.emit(sixth_id)
	game._ad_requested_at_ticks -= 120000
	game._process(0.0)
	_check(mock.recovery_calls.has(sixth_id) and game._active_ad_request_id == sixth_id, "Anúncio aberto sem fechamento permanece bloqueado durante recuperação")
	mock.safe_recovery = true
	game._ad_next_recovery_attempt_ticks -= 5000
	game._notification(game.NOTIFICATION_APPLICATION_RESUMED)
	_check(game._active_ad_request_id == -1, "Recuperação nativa confirmada também solta anúncio aberto sem fechamento")
	game.free()
	if FileAccess.file_exists(ads_file):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ads_file))
	print("Ciclo de anúncio: %d falha(s)." % failures)
	quit(1 if failures else 0)
