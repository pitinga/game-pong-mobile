extends Node
## Adaptador opcional para o plugin oficial GodotGooglePlayBilling (Android).
## Não permite liberar Pro por botão local nem simula compra na versão publicada.

signal entitlement_checked(owned: bool)
signal availability_changed(available: bool)
signal purchase_message(message: String)

const PRODUCT_ID := "remove_ads"
const RESPONSE_OK := 0
const RESPONSE_CANCELED := 1
const RESPONSE_ALREADY_OWNED := 7
const PRODUCT_INAPP := "inapp"
const PURCHASED := 1
const PENDING := 2

var _native: Object
var _product_available := false
var _connected := false
var _new_purchase_unconfirmed_by_query := false
var _acknowledging: Dictionary = {}


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
	_native.call("startConnection")


func refresh() -> void:
	if _native != null and _connected:
		_native.call("queryPurchases", PRODUCT_INAPP, false)
	else:
		purchase_message.emit("Google Play indisponível. Tente novamente com internet.")


func purchase() -> void:
	if not _connected or not _product_available or _native == null:
		purchase_message.emit("Compra indisponível. Verifique a Play Store e tente novamente.")
		return
	var result: Dictionary = _native.call("purchase", PRODUCT_ID, "", "", false)
	if int(result.get("response_code", -1)) != RESPONSE_OK:
		purchase_message.emit("Não foi possível abrir a compra. Tente novamente.")


func _on_connected() -> void:
	_connected = true
	_native.call("queryProductDetails", PackedStringArray([PRODUCT_ID]), PRODUCT_INAPP)
	refresh()


func _on_disconnected() -> void:
	_connected = false
	_product_available = false
	availability_changed.emit(false)
	purchase_message.emit("Google Play desconectado. Sua compra será verificada ao reconectar.")


func _on_connect_error(_response_code: int, _debug_message: String) -> void:
	_on_disconnected()


func _on_product_details(response: Dictionary) -> void:
	_product_available = false
	if int(response.get("response_code", -1)) == RESPONSE_OK:
		for product in response.get("product_details", []):
			if str(product.get("product_id", product.get("productId", ""))) == PRODUCT_ID:
				_product_available = true
				break
	availability_changed.emit(_product_available)
	if not _product_available:
		purchase_message.emit("Pro ainda não está disponível nesta conta da Play Store.")


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
		purchase_message.emit("Compra pendente de aprovação no Google Play.")
		return
	# Uma consulta iniciada ANTES da compra pode responder depois do callback
	# PURCHASED. Não deixe um resultado antigo apagar o desbloqueio recente.
	if not owned and _new_purchase_unconfirmed_by_query:
		_new_purchase_unconfirmed_by_query = false
		refresh()
		return
	_new_purchase_unconfirmed_by_query = false
	entitlement_checked.emit(owned)
	if owned:
		purchase_message.emit("Pro restaurado: anúncios desativados.")


func _on_purchase_updated(response: Dictionary) -> void:
	var code := int(response.get("response_code", -1))
	if code == RESPONSE_CANCELED:
		purchase_message.emit("Compra cancelada.")
		return
	if code == RESPONSE_ALREADY_OWNED:
		refresh()
		return
	if code != RESPONSE_OK:
		purchase_message.emit("Compra não concluída. Tente novamente.")
		return
	var pending := false
	for purchase_data in response.get("purchases", []):
		var purchase: Dictionary = purchase_data
		if not PRODUCT_ID in purchase.get("product_ids", []):
			continue
		if int(purchase.get("purchase_state", -1)) == PURCHASED:
			_acknowledge_if_needed(purchase)
			_new_purchase_unconfirmed_by_query = true
			entitlement_checked.emit(true)
			purchase_message.emit("Pro desbloqueado! Obrigado pela compra.")
			refresh()
		elif int(purchase.get("purchase_state", -1)) == PENDING:
			pending = true
	if pending:
		purchase_message.emit("Compra pendente de aprovação no Google Play.")


func _acknowledge_if_needed(purchase: Dictionary) -> void:
	var token := str(purchase.get("purchase_token", ""))
	if not bool(purchase.get("is_acknowledged", false)) and not token.is_empty() \
			and not _acknowledging.has(token) and _native != null:
		# Não consumir: "remove_ads" é permanente e precisa reaparecer em consultas.
		_acknowledging[token] = true
		_native.call("acknowledgePurchase", token)


func _on_acknowledged(response: Dictionary) -> void:
	var token := str(response.get("token", ""))
	if token.is_empty():
		_acknowledging.clear()
	else:
		_acknowledging.erase(token)
	if int(response.get("response_code", -1)) != RESPONSE_OK:
		purchase_message.emit("Confirmação da compra pendente; a Play Store tentará novamente.")


func _exit_tree() -> void:
	if _native != null:
		_native.call("endConnection")
