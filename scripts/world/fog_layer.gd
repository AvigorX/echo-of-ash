class_name FogLayer
extends Node2D
## Nebbia atmosferica: puff radiali generati a runtime, disegnati in world space
## e riposizionati attorno alla camera (nessun asset, nessuna allocazione per frame).
## z_index alto: la nebbia passa sopra le entità ma resta sotto la UI (CanvasLayer).

var intensity: float = 0.075
var drift_speed: float = 7.0
var time: float = 0.0
var _tex: ImageTexture
## Semi fissi: la nebbia è deterministica, non "salta" fra un frame e l'altro.
var _seeds: Array[Vector3] = []


func _ready() -> void:
	_tex = make_puff(64)
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	for i in 26:
		_seeds.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(28.0, 74.0)))


func _process(delta: float) -> void:
	time += delta
	queue_redraw()


## Texture morbida radiale (alpha quadratica) generata a runtime.
static func make_puff(size: int) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var half: float = float(size) * 0.5
	for y in size:
		for x in size:
			var d: float = Vector2(float(x) - half + 0.5, float(y) - half + 0.5).length() / half
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			a = a * a * a
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)


func _draw() -> void:
	if _tex == null:
		return
	var cam := get_viewport().get_camera_2d()
	var center: Vector2 = cam.get_screen_center_position() if cam != null else Vector2.ZERO
	var span := Vector2(560, 360)
	for s in _seeds:
		var size: float = s.z
		var x: float = fposmod(s.x * span.x + time * drift_speed * (0.6 + s.z / 100.0), span.x)
		var y: float = fposmod(s.y * span.y + time * drift_speed * 0.35, span.y)
		var pos := Vector2(center.x - span.x * 0.5 + x, center.y - span.y * 0.5 + y)
		var wobble: float = sin(time * 0.6 + s.x * 12.0) * 2.0
		draw_texture_rect(
			_tex,
			Rect2(pos + Vector2(wobble, 0) - Vector2(size, size) * 0.5, Vector2(size, size)),
			false,
			Color(0.60, 0.66, 0.72, intensity)
		)
