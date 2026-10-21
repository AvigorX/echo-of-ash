class_name Effects
extends Node2D
## Effetti visivi procedurali: fendenti, scintille, morte, anelli di livello.
## Nessun asset: tutto disegnato in _draw con vita e dissolvenza per elemento.

var _slashes: Array[Dictionary] = []
var _particles: Array[Dictionary] = []
var _rings: Array[Dictionary] = []


func _ready() -> void:
	z_index = 25


func slash(pos: Vector2, dir: Vector2, color: Color = Color(0.75, 0.92, 0.95)) -> void:
	_slashes.append({"pos": pos, "dir": dir, "t": 0.0, "life": 0.22, "color": color})


func burst(pos: Vector2, color: Color, count: int = 8, speed: float = 60.0, life: float = 0.45, size: float = 1.8) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pos.x * 31.0 + pos.y * 17.0 + count)
	for i in count:
		var a: float = rng.randf() * TAU
		var s: float = speed * rng.randf_range(0.35, 1.0)
		_particles.append({
			"pos": pos,
			"vel": Vector2(cos(a), sin(a)) * s + Vector2(0, -18),
			"t": 0.0,
			"life": life * rng.randf_range(0.7, 1.3),
			"color": color,
			"size": size * rng.randf_range(0.7, 1.3),
		})


func ring(pos: Vector2, color: Color = Color(1.0, 0.78, 0.42)) -> void:
	_rings.append({"pos": pos, "t": 0.0, "life": 0.7, "color": color})


func _process(delta: float) -> void:
	var i: int = _slashes.size() - 1
	while i >= 0:
		_slashes[i]["t"] = float(_slashes[i]["t"]) + delta
		if float(_slashes[i]["t"]) >= float(_slashes[i]["life"]):
			_slashes.remove_at(i)
		i -= 1
	i = _particles.size() - 1
	while i >= 0:
		var p: Dictionary = _particles[i]
		p["t"] = float(p["t"]) + delta
		var vel: Vector2 = p["vel"]
		vel.y += 90.0 * delta
		vel = vel.move_toward(Vector2.ZERO, 40.0 * delta)
		p["vel"] = vel
		p["pos"] = (p["pos"] as Vector2) + vel * delta
		if float(p["t"]) >= float(p["life"]):
			_particles.remove_at(i)
		i -= 1
	i = _rings.size() - 1
	while i >= 0:
		_rings[i]["t"] = float(_rings[i]["t"]) + delta
		if float(_rings[i]["t"]) >= float(_rings[i]["life"]):
			_rings.remove_at(i)
		i -= 1
	queue_redraw()


func _draw() -> void:
	for s in _slashes:
		var k: float = float(s["t"]) / float(s["life"])
		var dir: Vector2 = s["dir"]
		var col: Color = s["color"]
		var alpha: float = (1.0 - k) * 0.85
		var center: Vector2 = s["pos"] + Vector2(0, -6)
		var base_angle: float = dir.angle()
		var sweep: float = deg_to_rad(70.0) * (0.4 + 0.6 * k)
		var radius: float = 20.0 + 8.0 * k
		draw_arc(center, radius, base_angle - sweep, base_angle + sweep, 14,
			Color(col.r, col.g, col.b, alpha), 2.0)
		draw_arc(center, radius * 0.72, base_angle - sweep * 0.8, base_angle + sweep * 0.8, 12,
			Color(col.r, col.g, col.b, alpha * 0.55), 1.0)
	for p in _particles:
		var k2: float = float(p["t"]) / maxf(float(p["life"]), 0.001)
		var col2: Color = p["color"]
		var size: float = float(p["size"]) * (1.0 - k2 * 0.6)
		draw_rect(Rect2((p["pos"] as Vector2) - Vector2(size, size) * 0.5, Vector2(size, size)),
			Color(col2.r, col2.g, col2.b, 1.0 - k2))
	for r in _rings:
		var k3: float = float(r["t"]) / float(r["life"])
		var col3: Color = r["color"]
		var radius2: float = 6.0 + 34.0 * k3
		draw_arc(r["pos"], radius2, 0.0, TAU, 24, Color(col3.r, col3.g, col3.b, (1.0 - k3) * 0.7), 1.5)


func active_count() -> int:
	return _slashes.size() + _particles.size() + _rings.size()
