extends RefCounted
## Limites locais de intersticiais. A rede de anúncios ainda pode impor limites adicionais.

const MATCHES_PER_AD := 4
const MIN_INTERVAL_MSEC := 10 * 60 * 1000
const MAX_ADS_PER_HOUR := 2
const HOUR_MSEC := 60 * 60 * 1000

var matches_since_ad := 0
var _last_impression_msec := -1
var _impressions_msec: Array[int] = []


func note_finished_match() -> void:
	matches_since_ad += 1


func can_show(now_msec: int) -> bool:
	if matches_since_ad < MATCHES_PER_AD:
		return false
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
