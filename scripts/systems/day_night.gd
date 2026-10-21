class_name DayNight
extends CanvasModulate
## Ciclo giorno/notte: tinta globale del canvas (CanvasModulate nativo).
## Ampiezza volutamente contenuta: la notte scurisce ma non nasconde il gameplay.

const CYCLE_SECONDS: float = 210.0

var time_of_day: float = 0.30
var frozen: bool = false

var _stops: Array[Dictionary] = [
	{"t": 0.00, "c": Color(0.62, 0.58, 0.68)},  # alba
	{"t": 0.12, "c": Color(0.94, 0.92, 0.88)},  # mattina
	{"t": 0.45, "c": Color(1.00, 0.98, 0.94)},  # giorno
	{"t": 0.68, "c": Color(0.92, 0.78, 0.70)},  # tramonto
	{"t": 0.80, "c": Color(0.66, 0.62, 0.74)},  # crepuscolo
	{"t": 0.92, "c": Color(0.54, 0.58, 0.72)},  # notte
	{"t": 1.00, "c": Color(0.62, 0.58, 0.68)},
]


func _ready() -> void:
	color = sample(time_of_day)


func _process(delta: float) -> void:
	if frozen:
		return
	time_of_day = fposmod(time_of_day + delta / CYCLE_SECONDS, 1.0)
	color = sample(time_of_day)


func sample(t: float) -> Color:
	var clamped: float = fposmod(t, 1.0)
	for i in range(1, _stops.size()):
		var a: Dictionary = _stops[i - 1]
		var b: Dictionary = _stops[i]
		if clamped <= float(b["t"]):
			var span: float = maxf(float(b["t"]) - float(a["t"]), 0.0001)
			var k: float = (clamped - float(a["t"])) / span
			return (a["c"] as Color).lerp(b["c"] as Color, k)
	return _stops[_stops.size() - 1]["c"]


func phase_name() -> String:
	if time_of_day < 0.10 or time_of_day > 0.95:
		return "dawn"
	if time_of_day < 0.62:
		return "day"
	if time_of_day < 0.78:
		return "dusk"
	return "night"
