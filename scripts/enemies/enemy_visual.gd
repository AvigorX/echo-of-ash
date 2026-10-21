class_name EnemyVisual
extends Node2D
## Disegno procedurale dei due tipi di nemico. Silhouette diverse:
## il Crawler è basso e rapido (rosso cinabro), il Warden è alto e massiccio (pietra).
## Legge lo stato di `enemy`; non modifica nulla.

const CRAWLER_BODY: Color = Color(0.235, 0.129, 0.141)
const CRAWLER_LIGHT: Color = Color(0.345, 0.180, 0.184)
const CRAWLER_LEG: Color = Color(0.137, 0.078, 0.086)
const CRAWLER_EYE: Color = Color(0.941, 0.663, 0.235)
const WARDEN_BODY: Color = Color(0.196, 0.239, 0.231)
const WARDEN_LIGHT: Color = Color(0.267, 0.318, 0.302)
const WARDEN_DARK: Color = Color(0.129, 0.161, 0.157)
const WARDEN_CORE: Color = Color(0.933, 0.573, 0.220)
const WARDEN_EYE: Color = Color(0.404, 0.788, 0.812)
const SHADOW: Color = Color(0.0, 0.0, 0.0, 0.30)

var enemy: Enemy


func _ellipse(cx: float, cy: float, rx: float, ry: float, seg: int = 12) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in seg:
		var a: float = TAU * float(i) / float(seg)
		pts.append(Vector2(cx + cos(a) * rx, cy + sin(a) * ry))
	return pts


func _tint(c: Color) -> Color:
	if enemy == null:
		return c
	if enemy.hurt_flash > 0.0:
		return c.lerp(Color(1.0, 0.96, 0.92), clampf(enemy.hurt_flash * 5.0, 0.0, 0.85))
	return c


func _draw() -> void:
	if enemy == null:
		return
	var dying: bool = enemy.dead
	var fade: float = 1.0
	if dying:
		fade = clampf(1.0 - enemy.death_time / 0.45, 0.0, 1.0)
	var flip: float = -1.0 if enemy.facing.x < -0.15 else 1.0
	var bob: float = sin(enemy.walk_phase) * 1.0 if not dying else 0.0
	draw_set_transform(Vector2(0, 1), 0.0, Vector2(flip, 1.0 * (0.5 + 0.5 * fade) if dying else 1.0))
	if enemy.kind == "warden":
		_draw_warden(bob, fade)
	else:
		_draw_crawler(bob, fade)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_telegraph()
	if not dying and enemy.health < enemy.max_health:
		_draw_health_bar()


func _draw_crawler(bob: float, fade: float) -> void:
	draw_colored_polygon(_ellipse(0, 1, 8.0, 2.4), Color(SHADOW.r, SHADOW.g, SHADOW.b, SHADOW.a * fade))
	var body := _tint(CRAWLER_BODY)
	var leg := _tint(CRAWLER_LEG)
	# zampe: 4 segmenti, oscillano con il passo
	for i in 4:
		var lx: float = -4.5 + float(i) * 3.0
		var swing: float = sin(enemy.walk_phase * 2.0 + float(i) * 1.6) * 1.8
		draw_line(Vector2(lx, -3.0), Vector2(lx + swing, 0.5), leg, 1.4)
	# addome + torace
	draw_colored_polygon(_ellipse(-2.0, -5.0 + bob, 6.2, 3.4), body)
	draw_colored_polygon(_ellipse(3.6, -4.6 + bob, 3.8, 2.8), _tint(CRAWLER_LIGHT))
	# spine sul dorso
	for i in 3:
		var sx: float = -5.0 + float(i) * 2.6
		draw_line(Vector2(sx, -7.4 + bob), Vector2(sx + 0.8, -10.0 + bob), _tint(CRAWLER_LIGHT), 1.2)
	# occhi
	draw_rect(Rect2(5.0, -5.4 + bob, 1.4, 1.4), CRAWLER_EYE)
	draw_rect(Rect2(4.0, -3.6 + bob, 1.0, 1.0), Color(0.75, 0.35, 0.28))
	# mandibole
	draw_line(Vector2(6.6, -4.2 + bob), Vector2(8.4, -3.0 + bob), leg, 1.2)
	draw_line(Vector2(6.4, -3.2 + bob), Vector2(8.2, -2.2 + bob), leg, 1.0)


func _draw_warden(bob: float, fade: float) -> void:
	draw_colored_polygon(_ellipse(0, 1, 11.0, 3.2), Color(SHADOW.r, SHADOW.g, SHADOW.b, SHADOW.a * fade))
	var body := _tint(WARDEN_BODY)
	var light := _tint(WARDEN_LIGHT)
	var dark := _tint(WARDEN_DARK)
	# gambe massicce
	draw_rect(Rect2(-5.0, -8.0, 3.6, 8.0), dark)
	draw_rect(Rect2(1.6, -8.0, 3.6, 8.0), dark)
	# torso trapezoidale
	var torso := PackedVector2Array([
		Vector2(-7.0, -26.0 + bob), Vector2(7.0, -26.0 + bob),
		Vector2(5.2, -8.0), Vector2(-5.2, -8.0),
	])
	draw_colored_polygon(torso, body)
	draw_line(Vector2(-7.0, -26.0 + bob), Vector2(-5.2, -8.0), light, 1.4)
	draw_line(Vector2(-3.0, -24.0 + bob), Vector2(-2.0, -10.0), dark, 1.0)
	# spallacci
	draw_rect(Rect2(-10.0, -27.0 + bob, 5.0, 4.0), light)
	draw_rect(Rect2(5.0, -27.0 + bob, 5.0, 4.0), light)
	draw_rect(Rect2(-10.0, -23.5 + bob, 5.0, 1.2), dark)
	draw_rect(Rect2(5.0, -23.5 + bob, 5.0, 1.2), dark)
	# braccia
	var arm_swing: float = sin(enemy.walk_phase) * 1.2
	draw_rect(Rect2(-11.5, -22.0 + bob + arm_swing, 3.0, 9.0), dark)
	draw_rect(Rect2(8.5, -22.0 + bob - arm_swing, 3.0, 9.0), dark)
	# nucleo ambrato nel petto
	var pulse: float = 1.0 + 0.18 * sin(enemy.walk_phase * 2.0 + float(enemy.state))
	var core_r: float = (2.6 if enemy.state != Enemy.State.WINDUP else 3.8) * pulse
	draw_circle(Vector2(0, -18.0 + bob), core_r, WARDEN_CORE)
	draw_circle(Vector2(0, -18.0 + bob), core_r * 0.5, Color(1.0, 0.87, 0.62))
	# testa/maschera
	draw_rect(Rect2(-3.4, -32.0 + bob, 6.8, 5.0), light)
	draw_rect(Rect2(-2.4, -30.6 + bob, 4.8, 1.2), Color(0.09, 0.12, 0.12))
	draw_rect(Rect2(-1.6, -30.4 + bob, 1.2, 1.0), WARDEN_EYE)
	draw_rect(Rect2(0.6, -30.4 + bob, 1.2, 1.0), WARDEN_EYE)
	# crepe
	draw_line(Vector2(-4.4, -14.0), Vector2(-3.0, -10.0), dark, 1.0)
	draw_line(Vector2(4.2, -12.5), Vector2(3.2, -9.0), dark, 1.0)


func _draw_telegraph() -> void:
	if enemy.dead or enemy.state != Enemy.State.WINDUP:
		return
	var k: float = clampf(enemy.state_time / maxf(enemy.windup_time, 0.01), 0.0, 1.0)
	var dir: Vector2 = enemy.facing.normalized()
	var center: Vector2 = Vector2(0, -6)
	var base: float = dir.angle()
	var sweep: float = deg_to_rad(45.0)
	draw_arc(center, enemy.attack_range + 4.0, base - sweep, base + sweep, 10,
		Color(0.90, 0.36, 0.26, 0.10 + 0.45 * k), 1.5)


func _draw_health_bar() -> void:
	var width: float = 16.0 if enemy.kind == "crawler" else 20.0
	var top: float = -18.0 if enemy.kind == "crawler" else -38.0
	draw_rect(Rect2(-width * 0.5 - 1.0, top - 1.0, width + 2.0, 4.0), Color(0.06, 0.06, 0.07, 0.85))
	draw_rect(Rect2(-width * 0.5, top, width * enemy.health_ratio(), 2.0),
		Color(0.72, 0.22, 0.22) if enemy.kind == "crawler" else Color(0.80, 0.62, 0.26))
