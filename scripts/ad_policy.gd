extends RefCounted
## Limites locais de intersticiais com carimbos Unix (milissegundos), persistidos
## entre aberturas do app. O AdMob também deve impor o próprio limite.

const MATCHES_PER_AD := 4
const MIN_INTERVAL_MSEC := 10 * 60 * 1000
const MAX_ADS_PER_HOUR := 2
const HOUR_MSEC := 60 * 60 * 1000

var matches_since_ad := 0
var _last_impression_msec := -1
var _impressions_msec: Array[int] = []


func note_finished_match() -> void:
	matches_since_ad = mini(matches_since_ad + 1, MATCHES_PER_AD)


func can_show(now_msec: int) -> bool:
	if matches_since_ad < MATCHES_PER_AD:
		return false
	# Se o relógio voltar no tempo, não liberar um anúncio antecipado.
	if _last_impression_msec >= 0 and now_msec - _last_impression_msec < MIN_INTERVAL_MSEC:
		return false
	_prune(now_msec)
	return _impressions_msec.size() < MAX_ADS_PER_HOUR


func record_impression(now_msec: int) -> void:
	_prune(now_msec)
	_impressions_msec.append(now_msec)
	_last_impression_msec = now_msec
	matches_since_ad = 0


func _prune(now_msec: int) -> void:
	while not _impressions_msec.is_empty() and now_msec - _impressions_msec[0] >= HOUR_MSEC:
		_impressions_msec.pop_front()


func save_state(path: String) -> Error:
	var config := ConfigFile.new()
	config.set_value("ads", "matches_since_ad", matches_since_ad)
	config.set_value("ads", "last_impression_unix_msec", _last_impression_msec)
	config.set_value("ads", "impressions_unix_msec", _impressions_msec)
	return config.save(path)


func load_state(path: String) -> Error:
	var config := ConfigFile.new()
	var result := config.load(path)
	if result != OK:
		return result
	matches_since_ad = clampi(int(config.get_value("ads", "matches_since_ad", 0)), 0, MATCHES_PER_AD)
	_last_impression_msec = maxi(-1, int(config.get_value("ads", "last_impression_unix_msec", -1)))
	_impressions_msec.clear()
	var stored: Variant = config.get_value("ads", "impressions_unix_msec", [])
	if stored is Array or stored is PackedInt64Array:
		for timestamp in stored:
			var value := int(timestamp)
			if value >= 0:
				_impressions_msec.append(value)
	_impressions_msec.sort()
	if not _impressions_msec.is_empty():
		_last_impression_msec = maxi(_last_impression_msec, _impressions_msec.back())
	return OK
