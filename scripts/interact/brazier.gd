class_name Brazier
extends Interactable
## Braciere: sorgente di luce e cura con cooldown. Interazione ripetibile ma non gratuita.

const HEAL_AMOUNT: float = 35.0
const COOLDOWN: float = 12.0

var cooldown: float = 0.0
var time: float = 0.0


func _ready() -> void:
	prompt_text = "[E] Rest at the brazier"
	interact_radius = 28.0
	queue_redraw()


func can_interact(_player: Player) -> bool:
	return is_inside_tree() and cooldown <= 0.0


func interact(game: Node) -> void:
	var player := game.get("player") as Player
	if player == null:
		return
	if cooldown > 0.0:
		player.notified.emit("The embers are still cold. (%ds)" % int(ceil(cooldown)))
		return
	var healed: float = player.heal(HEAL_AMOUNT)
	if healed <= 0.0:
		player.notified.emit("The warmth does nothing for you now.")
		return
	cooldown = COOLDOWN
	player.notified.emit("The brazier's heat restores %d health." % int(healed))
	var effects := game.get("effects") as Effects
	if effects != null:
		effects.burst(global_position + Vector2(0, -10), Color(1.0, 0.62, 0.28), 14, 40.0, 0.7, 1.6)


func _process(delta: float) -> void:
	time += delta
	cooldown = maxf(0.0, cooldown - delta)
	queue_redraw()


func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, 0), Vector2(-5, -1.5), Vector2(5, -1.5), Vector2(8, 0), Vector2(0, 2),
	]), Color(0.0, 0.0, 0.0, 0.32))
	# piedistallo in pietra
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6, 0), Vector2(-5, -8), Vector2(5, -8), Vector2(6, 0),
	]), Color(0.259, 0.259, 0.271))
	draw_rect(Rect2(-6.5, -9.5, 13, 2.5), Color(0.329, 0.329, 0.341))
	draw_rect(Rect2(-4.5, -8.5, 9, 1.5), Color(0.145, 0.145, 0.157))
	if cooldown <= 0.0:
		# fiamme animate (poligoni sovrapposti, palette ambrata)
		for i in 3:
			var phase: float = time * (5.0 + float(i) * 1.3) + float(i)
			var h: float = 7.0 + 2.0 * sin(phase) - float(i) * 1.2
			var w: float = 3.4 - float(i) * 0.7
			var col: Color = [Color(0.86, 0.36, 0.18), Color(0.95, 0.62, 0.24), Color(1.0, 0.86, 0.52)][i]
			draw_colored_polygon(PackedVector2Array([
				Vector2(-w + sin(phase * 0.7) * 0.8, -9.0),
				Vector2(0, -9.0 - h),
				Vector2(w + cos(phase * 0.6) * 0.8, -9.0),
			]), col)
	else:
		draw_rect(Rect2(-3, -11, 6, 1.4), Color(0.45, 0.32, 0.28))
		draw_circle(Vector2(0, -11.2), 1.0, Color(0.60, 0.22, 0.18))
