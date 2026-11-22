extends Node
## Adaptador opcional para o plugin oficial GodotGooglePlayBilling (Android).
## Não permite liberar Pro por botão local nem simula compra na versão publicada.

signal entitlement_checked(owned: bool)
signal availability_changed(available: bool)
signal purchase_message(message: String)
signal price_changed(formatted_price: String)
signal purchase_pending(pending: bool)

const PRODUCT_ID := "pro_unlock"
const RESPONSE_OK := 0
const RESPONSE_CANCELED := 1
const RESPONSE_ALREADY_OWNED := 7
const PRODUCT_INAPP := "inapp"
const PURCHASED := 1
const PENDING := 2
const CONNECT_RETRY_LIMIT := 5
const ACK_RETRY_LIMIT := 5
const PURCHASE_SETTLE_MSEC := 300_000

var _native: Object
var _product_available := false
var _connected := false
var _price := ""
var _purchase_option_id := ""
var _recent_purchase_deadline_msec := 0
var _purchase_recheck_attempts := 0
var _connection_retry_attempts := 0
var _connecting := false
var _awaiting_initial_details := false
var _pending_purchase := false
var _acknowledging: Dictionary = {}
var _ack_retry_attempts: Dictionary = {}
var _reconnect_timer := Timer.new()
var _connect_timeout_timer := Timer.new()
var _details_watchdog_timer := Timer.new()
var _purchase_recheck_timer := Timer.new()
var _ack_retry_timer := Timer.new()


func _init() -> void:
	for timer in [_reconnect_timer, _connect_timeout_timer, _details_watchdog_timer, _purchase_recheck_timer, _ack_retry_timer]:
		timer.one_shot = true
		add_child(timer)
	_reconnect_timer.timeout.connect(_retry_connection)
	_connect_timeout_timer.timeout.connect(_on_connect_timeout)
	_details_watchdog_timer.timeout.connect(_restore_after_product_details)
	_purchase_recheck_timer.timeout.connect(refresh)
	_ack_retry_timer.timeout.connect(_retry_acknowledgements)


func start() -> void:
	if OS.get_name() != "Android" or not Engine.has_singleton("GodotGooglePlayBilling"):
		purchase_message.emit("Compras disponíveis após configurar o Google Play Billing.")
		return
	_native = Engine.get_singleton("GodotGooglePlayBilling")
	_native.call("initPlugin")
	for connection in [
		["connected", Callable(self, "_on_connected")],
		["disconnected", Callable(self, "_on_disconnected")],
		["connect_error", Callable(self, "_on_connect_error")],
		["query_product_details_response", Callable(self, "_on_product_details")],
		["query_purchases_response", Callable(self, "_on_purchases")],
		["on_purchase_updated", Callable(self, "_on_purchase_updated")],
		["acknowledge_purchase_response", Callable(self, "_on_acknowledged")],
	]:
		if _native.has_signal(connection[0]) and not _native.is_connected(connection[0], connection[1]):
			_native.connect(connection[0], connection[1])
	_connection_retry_attempts = 0
	_connect()


func _connect() -> void:
	if _native == null or _connected or _connecting:
		return
	_connecting = true
	_native.call("startConnection")
	if is_inside_tree() and _connecting and not _connected:
		_connect_timeout_timer.start(20.0)


func _on_connect_timeout() -> void:
	if _connecting and not _connected:
		_connecting = false
		_schedule_connection_retry()


func refresh() -> void:
	if _native != null and _connected:
		_native.call("queryPurchases", PRODUCT_INAPP, false)
	elif _native != null:
		# Também reabrir ao voltar do segundo plano, mesmo após esgotar os retries.
		if not _connecting:
			_reconnect_timer.stop()
			_connection_retry_attempts = 0
			_connect()
	else:
		purchase_message.emit("Google Play indisponível. Tente novamente com internet.")


func purchase() -> void:
	if not _connected or not _product_available or _native == null:
		purchase_message.emit("Compra indisponível. Verifique a Play Store e tente novamente.")
		return
	_set_purchase_pending(true)
	var result: Dictionary = _native.call("purchase", PRODUCT_ID, _purchase_option_id, "", false)
	if int(result.get("response_code", -1)) != RESPONSE_OK:
		_set_purchase_pending(false)
		purchase_message.emit("Não foi possível abrir a compra. Tente novamente.")


func _set_purchase_pending(pending: bool) -> void:
	if _pending_purchase == pending:
		return
	_pending_purchase = pending
	purchase_pending.emit(pending)


func _on_connected() -> void:
	_connected = true
	_connecting = false
	_connect_timeout_timer.stop()
	_connection_retry_attempts = 0
	_reconnect_timer.stop()
	_awaiting_initial_details = true
	_native.call("queryProductDetails", PackedStringArray([PRODUCT_ID]), PRODUCT_INAPP)
	# Consultar preço e opções primeiro. Falha/ausência de resposta não pode
	# impedir restauração: o watchdog consulta compras após 5 s.
	if is_inside_tree() and _awaiting_initial_details:
		_details_watchdog_timer.start(5.0)


func _on_disconnected() -> void:
	_connected = false
	_connecting = false
	_connect_timeout_timer.stop()
	_awaiting_initial_details = false
	_details_watchdog_timer.stop()
	_product_available = false
	_price = ""
	availability_changed.emit(false)
	price_changed.emit("")
	purchase_message.emit("Google Play desconectado. Sua compra será verificada ao reconectar.")
	_schedule_connection_retry()


func _on_connect_error(_response_code: int, _debug_message: String) -> void:
	_on_disconnected()


func _schedule_connection_retry() -> void:
	if _native == null or _connection_retry_attempts >= CONNECT_RETRY_LIMIT:
		purchase_message.emit("Google Play indisponível. Use Restaurar para tentar novamente.")
		return
	if not _reconnect_timer.is_stopped():
		return
	var delay := minf(pow(2.0, _connection_retry_attempts), 30.0)
	_connection_retry_attempts += 1
	if is_inside_tree():
		_reconnect_timer.start(delay)


func _retry_connection() -> void:
	_connect()


func _restore_after_product_details() -> void:
	if _awaiting_initial_details:
		_awaiting_initial_details = false
		refresh()


func _on_product_details(response: Dictionary) -> void:
	_details_watchdog_timer.stop()
	var should_restore := _awaiting_initial_details
	_awaiting_initial_details = false
	_product_available = false
	_price = ""
	_purchase_option_id = ""
	if int(response.get("response_code", -1)) == RESPONSE_OK:
		for product in response.get("product_details", []):
			if str(product.get("product_id", product.get("productId", ""))) == PRODUCT_ID:
				# O Billing 9 retorna preços por opção de compra avulsa.
				# Evitar inventar preço se nenhum detalhe de oferta veio da Play.
				var offers: Array = product.get("one_time_purchase_offer_details_list", [])
				for offer in offers:
					var offer_id: Variant = offer.get("offer_id", "")
					if offer_id == null or str(offer_id).is_empty():
						_price = str(offer.get("formatted_price", ""))
						_purchase_option_id = str(offer.get("purchase_option_id", ""))
						break
				_product_available = not _price.is_empty()
				break
	availability_changed.emit(_product_available)
	price_changed.emit(_price)
	if not _product_available:
		purchase_message.emit("Preço do Pro indisponível nesta conta da Play Store.")
	# A restauração é independente do cadastro/preço do produto e também
	# deve funcionar quando queryProductDetails retorna um erro.
	if should_restore:
		refresh()


func _on_purchases(response: Dictionary) -> void:
	if int(response.get("response_code", -1)) != RESPONSE_OK:
		purchase_message.emit("Não foi possível restaurar compras agora. Tente novamente.")
		return
	var owned := false
	var pending := false
	for purchase_data in response.get("purchases", []):
		var purchase: Dictionary = purchase_data
		if not PRODUCT_ID in purchase.get("product_ids", []):
			continue
		if int(purchase.get("purchase_state", -1)) == PURCHASED:
			owned = true
			_acknowledge_if_needed(purchase)
		elif int(purchase.get("purchase_state", -1)) == PENDING:
			pending = true
	if pending and not owned:
		_set_purchase_pending(true)
		purchase_message.emit("Compra pendente de aprovação no Google Play.")
		return
	_set_purchase_pending(false)
	# Consultas iniciadas antes da compra e atrasos de propagação da Play
	# podem retornar vazias após PURCHASED. Manter o direito por até 5 min
	# enquanto rechecamos; depois disso uma consulta OK sem compra revoga.
	if not owned and _recent_purchase_deadline_msec > Time.get_ticks_msec():
		_schedule_purchase_recheck()
		return
	_recent_purchase_deadline_msec = 0
	_purchase_recheck_timer.stop()
	_purchase_recheck_attempts = 0
	entitlement_checked.emit(owned)
	if owned:
		purchase_message.emit("Pro restaurado: anúncios desativados.")
	else:
		purchase_message.emit("Pro não encontrado nesta conta Google da Play Store. Se já comprou, selecione a conta usada na compra e toque em RESTAURAR; procure o suporte se persistir.")


func _on_purchase_updated(response: Dictionary) -> void:
	var code := int(response.get("response_code", -1))
	if code == RESPONSE_CANCELED:
		_set_purchase_pending(false)
		purchase_message.emit("Compra cancelada.")
		refresh()
		return
	if code == RESPONSE_ALREADY_OWNED:
		refresh()
		return
	if code != RESPONSE_OK:
		_set_purchase_pending(false)
		purchase_message.emit("Compra não concluída. Tente novamente.")
		refresh()
		return
	var pending := false
	for purchase_data in response.get("purchases", []):
		var purchase: Dictionary = purchase_data
		if not PRODUCT_ID in purchase.get("product_ids", []):
			continue
		if int(purchase.get("purchase_state", -1)) == PURCHASED:
			_set_purchase_pending(false)
			_acknowledge_if_needed(purchase)
			_recent_purchase_deadline_msec = Time.get_ticks_msec() + PURCHASE_SETTLE_MSEC
			_purchase_recheck_attempts = 0
			entitlement_checked.emit(true)
			purchase_message.emit("Pro desbloqueado! Obrigado pela compra.")
			refresh()
		elif int(purchase.get("purchase_state", -1)) == PENDING:
			pending = true
	if pending:
		_set_purchase_pending(true)
		purchase_message.emit("Compra pendente de aprovação no Google Play.")


func _schedule_purchase_recheck() -> void:
	if not _connected or not _purchase_recheck_timer.is_stopped():
		return
	var delay := minf(5.0 * pow(2.0, mini(_purchase_recheck_attempts, 4)), 60.0)
	_purchase_recheck_attempts += 1
	if is_inside_tree():
		_purchase_recheck_timer.start(delay)


func _acknowledge_if_needed(purchase: Dictionary) -> void:
	var token := str(purchase.get("purchase_token", ""))
	if not bool(purchase.get("is_acknowledged", false)) and not token.is_empty() \
			and not _acknowledging.has(token) and _native != null:
		# Não consumir: "pro_unlock" é permanente e reaparece em consultas.
		_acknowledging[token] = true
		_ack_retry_attempts.erase(token)
		_native.call("acknowledgePurchase", token)


func _on_acknowledged(response: Dictionary) -> void:
	var token := str(response.get("token", ""))
	if token.is_empty():
		_acknowledging.clear()
	else:
		_acknowledging.erase(token)
	if int(response.get("response_code", -1)) != RESPONSE_OK:
		purchase_message.emit("Confirmação do pagamento pendente; tentando novamente.")
		if not token.is_empty():
			_ack_retry_attempts[token] = int(_ack_retry_attempts.get(token, 0)) + 1
			_schedule_ack_retry()
	else:
		_ack_retry_attempts.erase(token)


func _schedule_ack_retry() -> void:
	if _ack_retry_timer.is_stopped() and is_inside_tree():
		_ack_retry_timer.start(10.0)


func _retry_acknowledgements() -> void:
	if not _connected or _native == null:
		return
	for token in _ack_retry_attempts.keys():
		if int(_ack_retry_attempts[token]) > ACK_RETRY_LIMIT:
			_ack_retry_attempts.erase(token)
			continue
		if not _acknowledging.has(token):
			_acknowledging[token] = true
			_native.call("acknowledgePurchase", token)


func _exit_tree() -> void:
	_reconnect_timer.stop()
	_connect_timeout_timer.stop()
	_details_watchdog_timer.stop()
	_purchase_recheck_timer.stop()
	_ack_retry_timer.stop()
	if _native != null:
		_native.call("endConnection")
