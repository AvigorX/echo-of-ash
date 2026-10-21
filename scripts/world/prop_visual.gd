class_name PropVisual
extends Node2D
## Props procedurali (alberi, rocce, muri, arbusti, funghi).
## Il nodo radice sta ai piedi del prop: così y_sort funziona con il player.
## I props solidi creano un StaticBody2D con una forma di collisione.

const SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.28)

var prop_type: String = "tree"
var variant: int = 0
var solid: bool = false
var radius: float = 6.0
var _body: StaticBody2D = null


static func create(prop: Dictionary, tile: int = WorldData.TILE) -> PropVisual:
	var node := PropVisual.new()
	node.prop_type = prop["type"]
	node.variant = int(prop["variant"])
	node.solid = bool(prop["solid"])
	node.radius = float(prop["radius"])
	var cell: Vector2i = prop["cell"]
	node.position = Vector2(cell.x * tile + tile * 0.5, cell.y * tile + tile * 0.5)
	node.z_index = 0
	node._build_body()
	return node


func _build_body() -> void:
	if not solid:
		return
	_body = StaticBody2D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	shape.position = Vector2(0, -radius * 0.35)
	_body.add_child(shape)
	add_child(_body)


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = variant * 7919 + prop_type.hash()
	match prop_type:
		"tree":
			_draw_tree(r)
		"rock":
			_draw_rock(r)
		"wall":
			_draw_wall(r)
		"shrub":
			_draw_shrub(r)
		"mushroom":
			_draw_mushroom(r)
		"pebbles":
			_draw_pebbles(r)
		_:
			_draw_pebbles(r)


func _ellipse(cx: float, cy: float, rx: float, ry: float, seg: int = 12) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in seg:
		var a: float = TAU * float(i) / float(seg)
		pts.append(Vector2(cx + cos(a) * rx, cy + sin(a) * ry))
	return pts


func _draw_tree(r: RandomNumberGenerator) -> void:
	var h: float = 22.0 + r.randf_range(-3.0, 5.0)
	var canopy_w: float = 10.0 + r.randf_range(-1.5, 2.5)
	draw_colored_polygon(_ellipse(0, 1, 7.0, 2.6), SHADOW_COLOR)
	# tronco
	draw_rect(Rect2(-1.5, -h * 0.45, 3.0, h * 0.45), Color(0.18, 0.14, 0.11))
	draw_rect(Rect2(-1.5, -h * 0.45, 1.0, h * 0.45), Color(0.23, 0.18, 0.14))
	# chioma a strati: silhouette scura + bordo più chiaro in alto a sinistra
	var base := Color(0.117, 0.176, 0.145).lerp(Color(0.145, 0.196, 0.156), r.randf())
	var dark := Color(0.086, 0.129, 0.109)
	draw_colored_polygon(_ellipse(0, -h * 0.55, canopy_w, canopy_w * 0.92), dark)
	draw_colored_polygon(_ellipse(-1.0, -h * 0.62, canopy_w * 0.80, canopy_w * 0.72), base)
	draw_colored_polygon(_ellipse(-2.0, -h * 0.72, canopy_w * 0.42, canopy_w * 0.34), Color(0.18, 0.24, 0.18, 0.75))
	# fronda secca/ramo
	if r.randf() < 0.5:
		draw_line(Vector2(1, -h * 0.55), Vector2(5, -h * 0.78), Color(0.16, 0.13, 0.10), 1.0)


func _draw_rock(r: RandomNumberGenerator) -> void:
	var w: float = 6.0 + r.randf_range(-1.0, 2.0)
	draw_colored_polygon(_ellipse(0, 1, w + 1.5, 2.6), SHADOW_COLOR)
	var pts := PackedVector2Array([
		Vector2(-w, 0), Vector2(-w * 0.7, -w * 0.9), Vector2(-w * 0.1, -w * 1.25),
		Vector2(w * 0.75, -w * 0.85), Vector2(w, 0),
	])
	draw_colored_polygon(pts, Color(0.253, 0.259, 0.271))
	var top := PackedVector2Array([
		Vector2(-w * 0.7, -w * 0.9), Vector2(-w * 0.1, -w * 1.25), Vector2(w * 0.4, -w * 0.95),
		Vector2(-w * 0.25, -w * 0.62),
	])
	draw_colored_polygon(top, Color(0.322, 0.329, 0.341))
	draw_line(Vector2(-w * 0.1, -w * 1.25), Vector2(w * 0.1, -w * 0.3), Color(0.19, 0.19, 0.21), 1.0)
	if r.randf() < 0.4:
		draw_rect(Rect2(-w * 0.5, -w * 0.5, 2, 1), Color(0.30, 0.36, 0.29))


func _draw_wall(r: RandomNumberGenerator) -> void:
	draw_colored_polygon(_ellipse(0, 1, 8.0, 2.8), SHADOW_COLOR)
	var h: float = 14.0 + r.randf_range(-2.0, 4.0)
	draw_rect(Rect2(-7, -h, 14, h), Color(0.271, 0.263, 0.271))
	draw_rect(Rect2(-7, -h, 14, 2), Color(0.337, 0.329, 0.337))
	draw_rect(Rect2(-7, -h, 2, h), Color(0.310, 0.302, 0.310))
	draw_rect(Rect2(5, -h, 2, h), Color(0.204, 0.200, 0.208))
	# blocchi e brecce
	var blocks: int = r.randi_range(2, 3)
	for i in blocks:
		var by: float = -h + 3.0 + float(i) * 4.0
		draw_line(Vector2(-7, by), Vector2(7, by), Color(0.196, 0.192, 0.200), 1.0)
	if r.randf() < 0.5:
		draw_rect(Rect2(-7 + r.randf_range(1, 9), -h - 2, 3, 3), Color(0.271, 0.263, 0.271))
	# muschio sulla sommità
	if r.randf() < 0.6:
		draw_rect(Rect2(-6, -h - 1, 5, 1), Color(0.180, 0.259, 0.196))


func _draw_shrub(r: RandomNumberGenerator) -> void:
	draw_colored_polygon(_ellipse(0, 0.5, 5.0, 1.8), SHADOW_COLOR)
	var c := Color(0.157, 0.216, 0.169)
	draw_circle(Vector2(-2, -3), 3.0, c)
	draw_circle(Vector2(2, -3), 3.2, c)
	draw_circle(Vector2(0, -5), 3.4, Color(0.180, 0.247, 0.188))
	if r.randf() < 0.3:
		draw_rect(Rect2(1, -6, 1, 1), Color(0.855, 0.647, 0.290))


func _draw_mushroom(r: RandomNumberGenerator) -> void:
	draw_colored_polygon(_ellipse(0, 0, 3.0, 1.0), SHADOW_COLOR)
	draw_rect(Rect2(-0.5, -3, 1, 3), Color(0.60, 0.56, 0.48))
	var cap := Color(0.62, 0.29, 0.24) if r.randf() < 0.6 else Color(0.42, 0.55, 0.55)
	draw_colored_polygon(_ellipse(0, -3.5, 3.0, 2.0), cap)
	draw_rect(Rect2(-1, -4, 1, 1), Color(0.85, 0.80, 0.70))


func _draw_pebbles(r: RandomNumberGenerator) -> void:
	draw_colored_polygon(_ellipse(0, 0, 5.0, 1.6), SHADOW_COLOR)
	var n: int = r.randi_range(2, 4)
	for i in n:
		var px: float = r.randf_range(-4.0, 4.0)
		var py: float = r.randf_range(-2.0, 0.0)
		var s: float = r.randf_range(1.0, 2.2)
		draw_rect(Rect2(px, py, s, s * 0.8), Color(0.322, 0.322, 0.337))
