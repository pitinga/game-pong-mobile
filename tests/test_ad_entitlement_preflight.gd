extends SceneTree
## Verificação de compra imediatamente antes do anúncio (sem SDK real).

const GameScript = preload("res://scripts/pong.gd")
const BillingBridge = preload("res://scripts/play_billing_bridge.gd")

class FakeBilling:
	extends Node
	signal entitlement_checked(owned: bool)
	signal availability_changed(available: bool)
	signal purchase_message(message: String)
	signal purchase_pending(pending: bool)
	signal checkout_changed(in_progress: bool)
	signal ad_verification_result(request_id: int, confirmed_free: bool)
	var requests: Array[int] = []
	var cancellations: Array[int] = []

	func start() -> void: pass
	func purchase() -> void: pass
	func refresh() -> void: pass
	func verify_free_before_ad(request_id: int) -> void:
		requests.append(request_id)
	func cancel_ad_verification(request_id: int) -> void:
		cancellations.append(request_id)


class FakeAd:
	extends Node
	signal interstitial_opened(request_id: int)
	signal interstitial_impression(request_id: int)
	signal interstitial_closed(request_id: int)
	signal interstitial_failed(request_id: int)
	var allowed := false
	var shows := 0

	func set_ads_allowed(value: bool) -> void: allowed = value
	func is_interstitial_loaded() -> bool: return allowed
	func show_interstitial(_id: int) -> bool:
		shows += 1
		return true
	func cancel_interstitial(_id: int) -> bool: return true
	func recover_interstitial(_id: int) -> bool: return true


class FakeNative:
	extends Node
	var queries := 0
	func queryPurchases(_kind: String, _suspended: bool) -> void:
		queries += 1


var failures := 0
var file_prefix := ""


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	if condition:
		print("OK  - ", description)
	else:
		failures += 1
		push_error("FALHOU - " + description)


func _new_game(suffix: String) -> Control:
	var game: Control = load("res://scenes/main.tscn").instantiate()
	game.pro_entitlement_file = file_prefix + suffix + "_pro.cfg"
	game.ad_policy_file = file_prefix + suffix + "_ads.cfg"
	game.settings_file = file_prefix + suffix + "_settings.cfg"
	game.stats_file = file_prefix + suffix + "_stats.cfg"
	root.add_child(game)
	game._on_entitlement_checked(false)
	game.set_ad_consent_granted(true)
	return game


func _attach_ad(game: Control) -> FakeAd:
	var ad := FakeAd.new()
	game.add_child(ad)
	game.set_interstitial_adapter(ad)
	return ad


func _finish_eligible_match(game: Control) -> void:
	game._ad_policy.matches_since_ad = 3
	game._start_match()
	game._complete_match(true)
	game._try_show_interstitial_after_match(game._match_id)


func _run() -> void:
	root.size = Vector2i(960, 540)
	file_prefix = "user://pong_preflight_%s_%s_" % [OS.get_process_id(), Time.get_ticks_usec()]
	var game := _new_game("paid")
	await process_frame
	var billing := FakeBilling.new()
	game.set_billing_adapter(billing)
	var ad := _attach_ad(game)
	_finish_eligible_match(game)
	_check(billing.requests.size() == 1 and ad.shows == 0, "Fim de partida solicita revalidação antes de exibir anúncio")
	var first_id: int = billing.requests.back() if not billing.requests.is_empty() else -1
	billing.entitlement_checked.emit(true)
	billing.ad_verification_result.emit(first_id, false)
	_check(game.is_pro and ad.shows == 0, "Compra encontrada na revalidação impede anúncio para titular Pro")
	game.free()

	var timeout_game := _new_game("timeout")
	await process_frame
	var timeout_billing := FakeBilling.new()
	timeout_game.set_billing_adapter(timeout_billing)
	var timeout_ad := _attach_ad(timeout_game)
	_finish_eligible_match(timeout_game)
	_check(timeout_ad.shows == 0 and timeout_billing.requests.size() == 1, "Sem resposta da Play não exibe anúncio")
	var old_id: int = timeout_billing.requests.back() if not timeout_billing.requests.is_empty() else -1
	if timeout_game.has_method("_on_ad_verification_timeout"):
		timeout_game._ad_verification_start_ticks -= timeout_game.AD_VERIFY_TIMEOUT_MSEC + 1
		timeout_game._process(0.0)
	_check(old_id in timeout_billing.cancellations, "Timeout cancela consulta pré-anúncio sem liberar exibição")
	timeout_billing.ad_verification_result.emit(old_id, true)
	_check(timeout_ad.shows == 0, "Resposta positiva tardia não reabre anúncio após timeout")
	timeout_game._return_to_menu()
	_finish_eligible_match(timeout_game)
	var second_id: int = timeout_billing.requests.back() if not timeout_billing.requests.is_empty() else -1
	_check(second_id > old_id and timeout_ad.shows == 0, "Nova partida possui identificador de verificação próprio")
	timeout_game._return_to_menu()
	timeout_billing.ad_verification_result.emit(second_id, true)
	_check(timeout_ad.shows == 0, "Voltar ao menu impede anúncio de confirmação atrasada")
	_finish_eligible_match(timeout_game)
	var valid_id: int = timeout_billing.requests.back() if not timeout_billing.requests.is_empty() else -1
	timeout_billing.ad_verification_result.emit(valid_id, true)
	_check(timeout_ad.shows == 1 and timeout_game.state == GameScript.GameState.FINISHED, "Negativa fresca e válida permite apenas anúncio no fim de partida")
	timeout_game._on_interstitial_closed(timeout_game._active_ad_request_id)
	timeout_game.free()

	var missing := _new_game("missing")
	await process_frame
	var missing_ad := _attach_ad(missing)
	_finish_eligible_match(missing)
	_check(missing_ad.shows == 0, "Sem ponte de cobrança compatível, anúncio falha fechado")
	missing.free()

	var bridge := BillingBridge.new()
	var native := FakeNative.new()
	bridge._native = native
	bridge._connected = true
	var results: Array[String] = []
	bridge.ad_verification_result.connect(func(id: int, free: bool): results.append("%d:%s" % [id, str(free)]))
	bridge.refresh()
	bridge.verify_free_before_ad(42)
	_check(native.queries == 1, "Consulta de anúncio aguarda consulta anterior sem misturar callbacks")
	bridge._on_purchases({"response_code": 0, "purchases": []})
	_check(native.queries == 2 and results.is_empty(), "Resposta antiga negativa não confirma verificação de anúncio")
	bridge._on_purchases({"response_code": 0, "purchases": [{
		"product_ids": ["pro_unlock"], "purchase_state": 1, "is_acknowledged": true
	}]})
	_check(results == ["42:false"], "Resposta correlacionada identifica compra Pro e recusa anúncio")
	bridge.verify_free_before_ad(43)
	bridge._on_purchases({"response_code": -1})
	_check(results.back() == "43:false", "Erro nativo de verificação recusa anúncio")
	bridge.refresh()
	bridge.verify_free_before_ad(44)
	bridge.cancel_ad_verification(44)
	bridge._on_purchases({"response_code": 0, "purchases": []})
	_check(native.queries == 4 and results.size() == 2, "Cancelar uma verificação ainda enfileirada evita nova consulta e callback")
	bridge.verify_free_before_ad(45)
	bridge.cancel_ad_verification(45)
	bridge._on_purchases({"response_code": 0, "purchases": []})
	_check(results.size() == 2, "Consulta já iniciada e cancelada descarta confirmação tardia")
	bridge.free()

	var checkout := BillingBridge.new()
	var checkout_native := FakeNative.new()
	checkout._native = checkout_native
	checkout._connected = true
	var checkout_entitlements: Array[bool] = []
	var checkout_statuses: Array[bool] = []
	checkout.entitlement_checked.connect(func(owned: bool): checkout_entitlements.append(owned))
	checkout.checkout_changed.connect(func(in_progress: bool): checkout_statuses.append(in_progress))
	checkout._set_checkout_in_progress(true)
	checkout._on_purchases({"response_code": 0, "purchases": []})
	_check(checkout_entitlements.is_empty() and checkout._checkout_in_progress, "Consulta antiga vazia não encerra checkout nem habilita anúncios")
	checkout._on_checkout_timeout()
	_check(not checkout._checkout_in_progress and checkout_statuses == [true, false] \
			and checkout_native.queries == 1, "Watchdog recupera checkout sem callback e solicita restauração")
	checkout._on_purchases({"response_code": 0, "purchases": [{
		"product_ids": ["pro_unlock"], "purchase_state": 2
	}]})
	_check(checkout._pending_purchase and checkout_entitlements.is_empty(), "Somente resposta nativa PENDING marca pagamento em análise")
	checkout.free()

	var directory := DirAccess.open("user://")
	if directory != null:
		directory.list_dir_begin()
		var filename := directory.get_next()
		while not filename.is_empty():
			if filename.begins_with(file_prefix.trim_prefix("user://")):
				directory.remove(filename)
			filename = directory.get_next()
		directory.list_dir_end()
	print("Revalidação pré-anúncio: %d falha(s)." % failures)
	quit(1 if failures else 0)
