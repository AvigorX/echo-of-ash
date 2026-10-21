class_name LightLayer
extends Node2D
## Luci procedurali additive: torcia del giocatore + bracieri.
## La texture di glow è generata a runtime (nessun asset).

var follow: Node2D = null
## [{pos: Vector2, radius: float, color: Color}]
var points: Array[Dictionary] = []
var time: float = 0.0
var _tex: ImageTexture


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	_tex = make_glow(128)
	z_index = 30


func _process(delta: float) -> void:
	time += delta
	queue_redraw()


static func make_glow(size: int) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var half: float = float(size) * 0.5
	for y in size:
		for x in size:
			var d: float = Vector2(float(x) - half + 0.5, float(y) - half + 0.5).length() / half
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			a = a * a
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)


func add_point(pos: Vector2, radius: float, color: Color) -> void:
	points.append({"pos": pos, "radius": radius, "color": color})


func _draw() -> void:
	if _tex == null:
		return
	for p in points:
		var pos: Vector2 = p["pos"]
		var radius: float = p["radius"]
		var col: Color = p["color"]
		var flicker: float = 0.86 + 0.14 * sin(time * 7.0 + pos.x * 0.3)
		draw_texture_rect(_tex, Rect2(pos - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false,
			Color(col.r, col.g, col.b, col.a * flicker))
	if follow != null and is_instance_valid(follow):
		var flicker2: float = 0.88 + 0.12 * sin(time * 5.3)
		draw_texture_rect(_tex, Rect2(follow.global_position - Vector2(74, 74), Vector2(148, 148)), false,
			Color(1.0, 0.74, 0.44, 0.15 * flicker2))
		draw_texture_rect(_tex, Rect2(follow.global_position - Vector2(34, 34), Vector2(68, 68)), false,
			Color(1.0, 0.82, 0.58, 0.12 * flicker2))
