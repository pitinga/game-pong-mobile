extends SceneTree
## Compra permanente, restauração e migração Free/Pro (sem dinheiro nem SDK real).

const GameScript = preload("res://scripts/pong.gd")
const BillingBridge = preload("res://scripts/play_billing_bridge.gd")

class FakeBilling:
	extends Node
	signal entitlement_checked(owned: bool)
	signal availability_changed(available: bool)
	signal purchase_message(message: String)
	var starts := 0
	var purchases := 0
	var queries := 0

	func start() -> void:
		starts += 1

	func purchase() -> void:
		purchases += 1

	func refresh() -> void:
		queries += 1


class FakeNative:
	extends Node
	var acknowledges: Array[String] = []
	var launches := 0
	var queries := 0

	func acknowledgePurchase(token: String) -> void:
		acknowledges.append(token)

	func purchase(_product_id: String, _option: String, _offer: String, _personalized: bool) -> Dictionary:
		launches += 1
		return {"response_code": 0}

	func queryPurchases(_product_type: String, _include_suspended: bool) -> void:
		queries += 1


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
	var token := "%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var purchase_file := "user://pong_billing_test_%s.cfg" % token
	var settings_file := "user://pong_billing_settings_%s.cfg" % token
	var stats_file := "user://pong_billing_stats_%s.cfg" % token
	var game: Control = load("res://scenes/main.tscn").instantiate()
	game.pro_entitlement_file = purchase_file
	game.settings_file = settings_file
	game.stats_file = stats_file
	root.add_child(game)
	await process_frame
	_check(not game.is_pro and game._pro_button.visible and game._pro_button.disabled, "App único começa Free sem plugin nem compra fictícia")
	_check(game._other_games_button.disabled, "Menu não oferece link de instalação inexistente")
	var fake := FakeBilling.new()
	game.set_billing_adapter(fake)
	_check(fake.starts == 1 and game._restore_purchase_button.disabled == false, "Adaptador conectado habilita consulta de restauração")
	game._buy_pro()
	_check(fake.purchases == 0 and not game.is_pro, "Compra indisponível não é simulada como concluída")
	fake.availability_changed.emit(true)
	game._buy_pro()
	_check(fake.purchases == 1 and not game.is_pro, "Tocar em comprar apenas abre fluxo externo: não libera Pro")
	fake.purchase_message.emit("Compra pendente")
	_check(not game.is_pro and game._pro_status_label.text == "Compra pendente", "Compra pendente mantém recursos bloqueados")
	game._restore_purchase()
	_check(fake.queries == 1, "Restaurar consulta compras no adaptador")
	fake.entitlement_checked.emit(true)
	_check(game.is_pro and game._pro_row.visible and not game._pro_button.visible, "Confirmação da Play libera os modos Pro sem outro app")
	_check(game._restore_purchase_button.visible == false, "Compra já confirmada não é oferecida novamente")
	var saved := ConfigFile.new()
	_check(saved.load(purchase_file) == OK and saved.get_value("purchase", "pro_owned", false), "Titularidade confirmada persiste para atualização/offline")
	game._open_settings()
	game._set_ball_size(130.0)
	game._set_mode(1)
	game._return_to_menu()
	game.free()

	var reopened: Control = load("res://scenes/main.tscn").instantiate()
	reopened.pro_entitlement_file = purchase_file
	reopened.settings_file = settings_file
	reopened.stats_file = stats_file
	# No Android, este load é executado automaticamente em _ready().
	reopened._load_cached_pro_entitlement()
	root.add_child(reopened)
	await process_frame
	_check(reopened.is_pro and is_equal_approx(reopened.ball_scale, 1.3) and reopened.match_mode == GameScript.MatchMode.SURVIVAL, "Reabertura preserva compra e configurações Pro")
	var offline_fake := FakeBilling.new()
	reopened.set_billing_adapter(offline_fake)
	offline_fake.purchase_message.emit("Sem conexão")
	_check(reopened.is_pro, "Falha de rede não remove compra confirmada nem faz anúncios voltarem")
	offline_fake.entitlement_checked.emit(false)
	_check(not reopened.is_pro and reopened.match_mode == GameScript.MatchMode.CLASSIC and is_equal_approx(reopened.ball_scale, 1.0), "Consulta Play válida sem titularidade revoga recursos e volta a regras Free")
	saved = ConfigFile.new()
	_check(saved.load(purchase_file) == OK and not saved.get_value("purchase", "pro_owned", true), "Revogação confirmada também atualiza cache")
	# A mesma conta pode recuperar depois da reinstalação sem nova compra.
	offline_fake.entitlement_checked.emit(true)
	_check(reopened.is_pro and offline_fake.purchases == 0, "Restaurar na Play desbloqueia Pro sem gerar cobrança")
	# Uma confirmação pode chegar depois que um jogo Free já começou.
	# Aplicar o direito de não ver anúncios imediatamente é seguro; mudar
	# geometria e modo no meio do rally não é.
	offline_fake.entitlement_checked.emit(false)
	reopened._start_match()
	offline_fake.entitlement_checked.emit(true)
	_check(reopened.is_pro and is_equal_approx(reopened.ball_scale, 1.0) and reopened._pending_pro_preferences, "Compra restaurada no meio do jogo não teletransporta raquetes")
	reopened._return_to_menu()
	_check(is_equal_approx(reopened.ball_scale, 1.3) and reopened.match_mode == GameScript.MatchMode.SURVIVAL and not reopened._pending_pro_preferences, "Preferências Pro entram em vigor ao voltar ao menu")
	var ads_before: int = reopened._ad_policy.matches_since_ad
	reopened._start_match()
	reopened._complete_match(true)
	_check(reopened._ad_policy.matches_since_ad == ads_before, "Partida Pro não concede crédito para anúncios gratuitos")
	reopened._return_to_menu()
	reopened.set_published_games([
		{"name": "Pong", "play_url": "https://play.google.com/store/apps/details?id=com.pitinga.pongmobile"},
		{"name": "Site não autorizado", "play_url": "https://example.com/game"},
		{"name": "2048", "play_url": "https://play.google.com/store/apps/details?id=com.pitinga.game2048"},
	])
	_check(reopened.published_games.size() == 1 and not reopened._other_games_button.disabled, "Catálogo mostra apenas outros jogos com URL oficial publicada")
	reopened._open_other_games()
	_check(reopened.state == GameScript.GameState.OTHER_GAMES and reopened._other_games_content.get_child_count() == 1, "Menu abre lista de instalação dos demais jogos")
	reopened._return_to_menu()
	_check(reopened.state == GameScript.GameState.MENU, "Lista de jogos volta ao menu")
	reopened.free()

	var bridge := BillingBridge.new()
	var native := FakeNative.new()
	bridge._native = native
	bridge._connected = true
	bridge.purchase()
	_check(native.launches == 0, "Sem detalhes válidos do produto a Play não recebe tentativa de pagamento")
	bridge._on_product_details({"response_code": 0, "product_details": [{"product_id": "outro_item"}]})
	_check(not bridge._product_available, "Outro produto da loja não habilita compra Pro")
	bridge._on_product_details({"response_code": 0, "product_details": [{"product_id": "remove_ads"}]})
	bridge.purchase()
	_check(native.launches == 1, "Adaptador nativo só solicita compra; não inventa titularidade")
	var bought := {"product_ids": PackedStringArray(["remove_ads"]), "purchase_state": 1,
		"purchase_token": "token-fake", "is_acknowledged": false}
	var delivered: Array[bool] = []
	bridge.entitlement_checked.connect(func(owned: bool): delivered.append(owned))
	bridge._on_purchase_updated({"response_code": 1})
	_check(delivered.is_empty(), "Cancelamento da compra não libera Pro")
	bridge._on_purchases({"response_code": 0, "purchases": [{"product_ids": ["remove_ads"], "purchase_state": 2}]})
	_check(delivered.is_empty(), "Compra pendente não concede nem remove Pro")
	bridge._on_purchase_updated({"response_code": 0, "purchases": [bought]})
	_check(delivered.size() == 1 and delivered[0] and native.acknowledges == ["token-fake"] and native.queries == 1, "Compra concluída desbloqueia, reconhece sem consumo e consulta a Play")
	bridge._on_purchase_updated({"response_code": 0, "purchases": [bought]})
	_check(native.acknowledges.size() == 1, "Callback duplicado não reconhece o mesmo token duas vezes")
	bridge._on_purchases({"response_code": -1})
	_check(delivered.size() == 2 and delivered.back(), "Erro da Play não revoga compra em cache")
	bridge._on_purchases({"response_code": 0, "purchases": []})
	_check(delivered.size() == 2 and native.queries >= 3, "Consulta antiga sem compra não desfaz desbloqueio recém-confirmado")
	bridge._on_purchases({"response_code": 0, "purchases": []})
	_check(delivered.size() == 3 and not delivered.back(), "Consulta nova e válida sem produto permite revogação após reembolso")
	bridge._native = null
	bridge.free()
	native.free()
	for path in [purchase_file, settings_file, stats_file]:
		for suffix in ["", ".bak", ".tmp"]:
			var candidate: String = path + suffix
			if FileAccess.file_exists(candidate):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
	print("Pro / Billing unificados: %d falha(s)." % failures)
	quit(1 if failures else 0)
