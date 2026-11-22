extends SceneTree
## Proteção contra publicidade indevida depois da compra Pro.
## Fakes apenas: não valida o SDK da Play nem o consentimento real.

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
	var restores := 0

	func start() -> void:
		pass

	func purchase() -> void:
		pass

	func refresh() -> void:
		restores += 1

	func verify_free_before_ad(request_id: int) -> void:
		ad_verification_result.emit(request_id, true)


class FakeNative:
	extends Node
	var queries := 0
	func queryPurchases(_kind: String, _suspended: bool) -> void:
		queries += 1


class FakeInterstitial:
	extends Node
	signal interstitial_opened(request_id: int)
	signal interstitial_impression(request_id: int)
	signal interstitial_closed(request_id: int)
	signal interstitial_failed(request_id: int)
	var ads_allowed := false
	var preload_count := 0
	var show_count := 0
	var denied_shows := 0

	func set_ads_allowed(allowed: bool) -> void:
		ads_allowed = allowed
		if allowed:
			preload_count += 1

	func is_interstitial_loaded() -> bool:
		return ads_allowed

	func show_interstitial(_request_id: int) -> bool:
		if not ads_allowed:
			denied_shows += 1
			return false
		show_count += 1
		return true

	func cancel_interstitial(_request_id: int) -> bool:
		return true

	func recover_interstitial(_request_id: int) -> bool:
		return true


var failures := 0
var files: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	if condition:
		print("OK  - " + label)
	else:
		failures += 1
		push_error("FALHOU - " + label)


func _new_game() -> Control:
	var game: Control = load("res://scenes/main.tscn").instantiate()
	game.pro_entitlement_file = files["entitlement"]
	game.settings_file = files["settings"]
	game.stats_file = files["stats"]
	game.ad_policy_file = files["ads"]
	# Em desktop, _ready() não lê automaticamente o cache Android.
	game._load_cached_pro_entitlement()
	root.add_child(game)
	return game


func _attach_ads(game: Control) -> FakeInterstitial:
	var fake := FakeInterstitial.new()
	game.add_child(fake)
	game.set_interstitial_adapter(fake)
	return fake


func _check_no_ad(game: Control, fake: FakeInterstitial, label: String) -> void:
	game._start_match()
	game._complete_match(true)
	game._try_show_interstitial_after_match(game._match_id)
	_check(not fake.ads_allowed and fake.preload_count == 0 and fake.show_count == 0 \
			and fake.denied_shows == 0, label)
	game._return_to_menu()


func _run() -> void:
	root.size = Vector2i(960, 540)
	var token := "%s_%s" % [OS.get_process_id(), Time.get_ticks_usec()]
	for name in ["entitlement", "settings", "stats", "ads"]:
		files[name] = "user://pong_ad_safety_%s_%s.cfg" % [token, name]

	var game := _new_game()
	await process_frame
	var fake := _attach_ads(game)
	game.set_ad_consent_granted(true)
	_check(game.entitlement_status == GameScript.EntitlementStatus.UNKNOWN \
			and not game._ads_allowed_now(), "Instalação sem cache começa com titularidade desconhecida")
	for i in range(4):
		_check_no_ad(game, fake, "Sem consulta da Play, partida %d não permite anúncio nem pré-carga" % (i + 1))
	_check(game._ad_policy.matches_since_ad == 0, "Partidas com titularidade desconhecida não acumulam crédito")
	var billing := FakeBilling.new()
	game.set_billing_adapter(billing)
	billing.purchase_pending.emit(true)
	_check(game.entitlement_status == GameScript.EntitlementStatus.PENDING \
			and "ANÁLISE" in game._pro_status_label.text, "Compra pendente tem estado e mensagem próprios")
	_check_no_ad(game, fake, "Pagamento pendente impede pré-carga e exibição")
	billing.purchase_pending.emit(false)
	_check(game.entitlement_status == GameScript.EntitlementStatus.UNKNOWN, "Após pendência, aguarda nova consulta antes de liberar anúncios")
	billing.entitlement_checked.emit(false)
	_check(game.entitlement_status == GameScript.EntitlementStatus.FREE_CONFIRMED \
			and fake.ads_allowed and fake.preload_count == 1, "Somente confirmação Free da sessão libera o adaptador com consentimento")
	for i in range(4):
		game._start_match()
		game._complete_match(true)
		game._try_show_interstitial_after_match(game._match_id)
		_check(fake.show_count == (1 if i == 3 else 0), "Confirmado Free: anúncio somente após %dª partida" % (i + 1))
		if i == 3:
			game._on_interstitial_impression(game._active_ad_request_id)
			game._on_interstitial_closed(game._active_ad_request_id)
		game._return_to_menu()
	billing.purchase_pending.emit(true)
	_check(not fake.ads_allowed and game.entitlement_status == GameScript.EntitlementStatus.PENDING, "Pendência iniciada após Free confirmado suspende pré-carregamento")
	billing.purchase_pending.emit(false)
	_check(not fake.ads_allowed and game.entitlement_status == GameScript.EntitlementStatus.UNKNOWN, "Cancelar pendência exige nova confirmação Free")
	billing.entitlement_checked.emit(false)
	_check(fake.ads_allowed and game.entitlement_status == GameScript.EntitlementStatus.FREE_CONFIRMED, "Nova consulta da Play reabilita Free com consentimento")
	game.set_ad_consent_granted(false)
	_check(not fake.ads_allowed, "Retirada de consentimento bloqueia o adaptador imediatamente")
	var preloads_before := fake.preload_count
	game._start_match()
	game._complete_match(true)
	game._try_show_interstitial_after_match(game._match_id)
	_check(fake.preload_count == preloads_before and fake.show_count == 1, "Sem consentimento não há nova pré-carga nem anúncio")
	game._return_to_menu()
	billing.entitlement_checked.emit(true)
	_check(game.is_pro and not fake.ads_allowed \
			and game._negative_count == 0, "Compra positiva revoga permissão de anúncios e zera negativas")
	var saved := ConfigFile.new()
	_check(saved.load(files["entitlement"]) == OK \
			and saved.get_value("purchase", "pro_owned", false), "Compra Pro salva em cache imediatamente")
	game.free()

	var reopened := _new_game()
	await process_frame
	var reopened_ads := _attach_ads(reopened)
	reopened.set_ad_consent_granted(true)
	_check(reopened.is_pro and reopened.entitlement_status == GameScript.EntitlementStatus.PRO, "Reabertura sem internet conserva Pro antes de consultar a Play")
	_check_no_ad(reopened, reopened_ads, "Pro restaurado do cache nunca autoriza pré-carga")
	var restored_billing := FakeBilling.new()
	reopened.set_billing_adapter(restored_billing)
	restored_billing.purchase_message.emit("Play indisponível")
	_check(reopened.is_pro and not reopened_ads.ads_allowed, "Erro de conexão não revoga Pro")
	restored_billing.entitlement_checked.emit(false)
	restored_billing.entitlement_checked.emit(false)
	_check(reopened.is_pro and reopened._negative_count == 1 \
			and not reopened_ads.ads_allowed, "Duas respostas vazias no mesmo dia mantêm Pro")
	_check("RESTAURAR" in reopened._pro_status_label.text \
			and reopened._restore_purchase_button.visible, "Negativa informa restauração também a quem já tem Pro")
	_check((reopened._menu.get_child(0) as PanelContainer).get_combined_minimum_size().y <= 530.0, "Menu com aviso Pro mantido cabe na altura de referência")
	saved = ConfigFile.new()
	_check(saved.load(files["entitlement"]) == OK \
			and saved.get_value("purchase", "pro_owned", false) \
			and saved.get_value("purchase", "negative_count", 0) == 1, "Negativa persistida não remove titularidade")
	reopened.free()

	var later := _new_game()
	await process_frame
	var later_ads := _attach_ads(later)
	later.set_ad_consent_granted(true)
	_check(later.is_pro and later._negative_count == 1 and not later_ads.ads_allowed, "Histórico negativo sobrevive a reinício de processo")
	var later_billing := FakeBilling.new()
	later.set_billing_adapter(later_billing)
	var now := int(Time.get_unix_time_from_system())
	later._negative_first_unix = now - later.PRO_REVOKE_GRACE_SEC + 3600
	later._negative_last_unix = now - later.PRO_NEGATIVE_INTERVAL_SEC - 10
	later_billing.entitlement_checked.emit(false)
	_check(later.is_pro and later._negative_count == 2 and not later_ads.ads_allowed, "Segunda negativa em outro dia, mas antes das 48h, mantém Pro")
	later_billing.entitlement_checked.emit(true)
	_check(later._negative_count == 0 and later._negative_first_unix == 0 and later._negative_last_unix == 0 \
			and later.is_pro, "Nova confirmação positiva limpa toda a suspeita de revogação")
	later_billing.entitlement_checked.emit(false)
	_check(later.is_pro and later._negative_count == 1, "Depois de uma confirmação, primeira negativa inicia nova carência")
	later._negative_first_unix = now - later.PRO_REVOKE_GRACE_SEC - 3600
	later._negative_last_unix = now - later.PRO_NEGATIVE_INTERVAL_SEC - 3600
	later_billing.entitlement_checked.emit(false)
	_check(not later.is_pro and later.entitlement_status == GameScript.EntitlementStatus.FREE_CONFIRMED \
			and later_ads.ads_allowed, "Reembolso só revoga depois das duas negativas e 48h; volta a Free com consentimento")
	later._restore_purchase()
	_check(later_billing.restores == 1, "Ação Restaurar continua disponível depois da revogação")
	later.free()

	var clean := _new_game()
	await process_frame
	var no_consent_ads := _attach_ads(clean)
	_check(clean.entitlement_status == GameScript.EntitlementStatus.UNKNOWN \
			and not no_consent_ads.ads_allowed, "Cache Free da sessão anterior não confirma Free nesta sessão")
	var clean_billing := FakeBilling.new()
	clean.set_billing_adapter(clean_billing)
	clean_billing.entitlement_checked.emit(false)
	_check(clean.entitlement_status == GameScript.EntitlementStatus.FREE_CONFIRMED \
			and not no_consent_ads.ads_allowed and no_consent_ads.preload_count == 0, "Confirmação Free sem consentimento não inicializa publicidade")
	clean_billing.purchase_message.emit("Pro não encontrado nesta conta Google da Play Store. Se já comprou, selecione a conta usada na compra e toque em RESTAURAR; procure o suporte se persistir.")
	_check((clean._menu.get_child(0) as PanelContainer).get_combined_minimum_size().y <= 530.0, "Orientação de conta Google também cabe no menu Free")
	clean.free()

	var bridge := BillingBridge.new()
	var native := FakeNative.new()
	bridge._native = native
	bridge._connected = true
	var messages: Array[String] = []
	var entitlements: Array[bool] = []
	bridge.purchase_message.connect(func(message: String): messages.append(message))
	bridge.entitlement_checked.connect(func(owned: bool): entitlements.append(owned))
	bridge._on_purchases({"response_code": 0, "purchases": [{
		"product_ids": PackedStringArray(["pro_unlock"]), "purchase_state": 2,
	}]})
	_check(bridge._pending_purchase and entitlements.is_empty(), "Compra nativa pendente não emite revogação")
	var message_count_before := messages.size()
	bridge._on_purchases({"response_code": 0, "purchases": []})
	_check(not bridge._pending_purchase and entitlements == [false] and messages.size() == message_count_before, "Consulta automática Free não sugere erro de compra inexistente")
	bridge.restore()
	bridge._on_purchases({"response_code": 0, "purchases": []})
	_check("conta Google" in messages.back() and "RESTAURAR" in messages.back() \
			and "suporte" in messages.back(), "Restaurar sem compra orienta conta correta e suporte")
	bridge._native = null
	bridge.free()

	for path in files.values():
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	print("Segurança de Pro/anúncios: %d falha(s)." % failures)
	quit(1 if failures else 0)
