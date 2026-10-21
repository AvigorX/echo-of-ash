class_name PlayerVisual
extends Node2D
## Disegno procedurale del giocatore: pixel-art stilizzata, silhouette leggibile.
## Legge lo stato di `player` e non scrive nulla: presentazione separata dalla logica.

const CLOAK: Color = Color(0.176, 0.231, 0.251)
const CLOAK_LIGHT: Color = Color(0.243, 0.310, 0.333)
const HOOD: Color = Color(0.220, 0.282, 0.302)
const TRIM: Color = Color(0.310, 0.639, 0.682)
const SCARF: Color = Color(0.706, 0.427, 0.220)
const FACE: Color = Color(0.780, 0.706, 0.588)
const EYE: Color = Color(0.451, 0.855, 0.882)
const BLADE: Color = Color(0.741, 0.784, 0.820)
const SHADOW: Color = Color(0.0, 0.0, 0.0, 0.30)

var player: Player
var _time: float = 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _ellipse(cx: float, cy: float, rx: float, ry: float, seg: int = 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in seg:
		var a: float = TAU * float(i) / float(seg)
		pts.append(Vector2(cx + cos(a) * rx, cy + sin(a) * ry))
	return pts


func _draw() -> void:
	if player == null:
		return
	if player.invuln > 0.0 and not player.dead and int(player.invuln * 14.0) % 2 == 0:
		return
	draw_colored_polygon(_ellipse(0, 1, 6.0, 2.2), SHADOW)
	if player.dead:
		_draw_dead()
		return
	var moving: bool = player.velocity.length() > 6.0
	var bob: float = (sin(player.walk_phase) * 1.1) if moving else (sin(_time * 2.2) * 0.45)
	var stride: float = sin(player.walk_phase) * 2.2 if moving else 0.0
	var fx: float = player.facing.x
	var fy: float = player.facing.y

	# gambe
	draw_rect(Rect2(-2.6, -4.0 + maxf(stride, 0.0) * 0.5, 2.2, 4.2), Color(0.114, 0.137, 0.145))
	draw_rect(Rect2(0.6, -4.0 + maxf(-stride, 0.0) * 0.5, 2.2, 4.2), Color(0.114, 0.137, 0.145))

	# mantello
	var cloak := PackedVector2Array([
		Vector2(-5.4, -14.0 + bob), Vector2(-6.4, -2.2), Vector2(-3.0, -1.2),
		Vector2(0.0, -2.0), Vector2(3.2, -1.2), Vector2(6.4, -2.2), Vector2(5.4, -14.0 + bob),
	])
	draw_colored_polygon(cloak, CLOAK)
	# piega luminosa sul lato della direzione
	var fold_x: float = clampf(fx, -1.0, 1.0) * 1.6
	draw_line(Vector2(fold_x - 1.0, -13.0 + bob), Vector2(fold_x - 1.4, -3.0), CLOAK_LIGHT, 1.4)
	# orlo cyan
	draw_line(Vector2(-6.2, -2.4), Vector2(6.2, -2.4), TRIM, 1.0)
	# sciarpa
	draw_rect(Rect2(-4.0, -13.6 + bob, 8.0, 1.6), SCARF)
	draw_rect(Rect2(3.4, -13.0 + bob, 1.4, 4.0), SCARF)

	# cappuccio
	draw_circle(Vector2(fx * 0.7, -16.4 + bob), 4.4, HOOD)
	draw_circle(Vector2(fx * 0.7 - 1.0, -17.2 + bob), 3.0, CLOAK_LIGHT)
	# volto (non visibile quando guarda in alto)
	if fy > -0.55:
		var face_off := Vector2(fx * 1.3, maxf(fy, 0.0) * 1.1)
		draw_rect(Rect2(face_off.x - 1.6, -16.2 + bob + face_off.y, 3.4, 2.6), FACE)
		var eye_y: float = -15.2 + bob + face_off.y * 0.8
		if absf(fx) < 0.45:
			draw_rect(Rect2(-1.5, eye_y, 1.0, 1.0), EYE)
			draw_rect(Rect2(1.1, eye_y, 1.0, 1.0), EYE)
		else:
			draw_rect(Rect2(fx * 1.5 - 0.5, eye_y, 1.0, 1.0), EYE)

	# lama tenuta al fianco; durante lo swing segue la direzione d'attacco
	var blade_base := Vector2(fx * 2.0 + 3.6, -9.0 + bob)
	var blade_tip := blade_base + Vector2(0.6, -7.0)
	if player.swing_time > 0.0:
		blade_base = Vector2(0, -9.0 + bob) + player.swing_dir * 3.0
		blade_tip = blade_base + player.swing_dir * 11.0
	draw_line(blade_base, blade_tip, BLADE, 1.6)
	draw_line(blade_base, blade_base + (blade_tip - blade_base) * 0.25, Color(0.42, 0.36, 0.28), 2.0)

	# indicatore di direzione a terra (leggibilità dell'orientamento)
	if player.swing_time > 0.0:
		var tip: Vector2 = player.swing_dir * 13.0
		draw_line(Vector2(0, 0.5), tip, Color(TRIM.r, TRIM.g, TRIM.b, 0.45), 1.0)


func _draw_dead() -> void:
	draw_set_transform(Vector2(0, -1.0), 1.35, Vector2(1.0, 0.55))
	draw_colored_polygon(_ellipse(0, -8, 5.6, 8.5), CLOAK)
	draw_circle(Vector2(0, -17), 4.0, HOOD)
	draw_line(Vector2(-5, -2), Vector2(5, -2), TRIM, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_line(Vector2(5, -3), Vector2(9, -1), BLADE, 1.5)
