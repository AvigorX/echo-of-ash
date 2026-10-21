class_name Npc
extends Interactable
## Il Wanderer: dialogo a più battute, ricompensa una tantum, luce della lanterna.
## Il testo vive qui (dati), la UI lo mostra: nessun accoppiamento con l'HUD.

const NPC_NAME: String = "The Wanderer"

var lines: Array[String] = [
	"Ash falls, and the world keeps its shape. You are still walking, then.",
	"These ruins were a village before the ember rain. Now the Wardens keep them.",
	"Take this charm. It was warm when I found it; it has not cooled since.",
	"Follow the old paths. Where the stones still stand, something remembers.",
]
var reward_given: bool = false
var time: float = 0.0


func _ready() -> void:
	prompt_text = "[E] Talk to %s" % NPC_NAME
	interact_radius = 28.0
	queue_redraw()


func can_interact(_player: Player) -> bool:
	return is_inside_tree()


func interact(game: Node) -> void:
	game.call("start_dialogue", self)


## Chiamata dal gioco quando il dialogo finisce: ricompensa una sola volta.
func on_dialogue_finished(game: Node) -> void:
	if reward_given:
		return
	reward_given = true
	var player := game.get("player") as Player
	if player == null:
		return
	player.collect("ember_charm", 1)
	player.gain_xp(20)
	var effects := game.get("effects") as Effects
	if effects != null:
		effects.ring(global_position + Vector2(0, -10), Color(0.95, 0.72, 0.36))


func _process(delta: float) -> void:
	time += delta
	queue_redraw()


func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(-7, 0), Vector2(-5, -1.5), Vector2(5, -1.5), Vector2(7, 0), Vector2(0, 2),
	]), Color(0.0, 0.0, 0.0, 0.30))
	var bob: float = sin(time * 1.4) * 0.7
	# mantello lungo, più scuro del giocatore
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6.0, -18 + bob), Vector2(-7.5, -1.0), Vector2(-2.5, 0.0),
		Vector2(2.5, 0.0), Vector2(7.5, -1.0), Vector2(6.0, -18 + bob),
	]), Color(0.118, 0.145, 0.157))
	draw_line(Vector2(-7.2, -1.6), Vector2(7.2, -1.6), Color(0.62, 0.44, 0.24), 1.0)
	# cappuccio e volto anziano
	draw_circle(Vector2(0, -20 + bob), 4.6, Color(0.157, 0.188, 0.196))
	draw_circle(Vector2(-0.6, -21 + bob), 3.2, Color(0.235, 0.271, 0.271))
	draw_rect(Rect2(-1.8, -20.6 + bob, 3.6, 2.4), Color(0.706, 0.647, 0.545))
	draw_rect(Rect2(-1.2, -19.8 + bob, 0.8, 0.8), Color(0.42, 0.78, 0.80))
	draw_rect(Rect2(0.6, -19.8 + bob, 0.8, 0.8), Color(0.42, 0.78, 0.80))
	# bastone e lanterna ambrata
	draw_line(Vector2(7.0, -16 + bob), Vector2(8.2, 0.0), Color(0.31, 0.24, 0.17), 1.4)
	var flick: float = 0.75 + 0.25 * sin(time * 6.0)
	draw_circle(Vector2(8.2, -17 + bob), 2.0 + flick, Color(0.95, 0.66, 0.30, 0.35))
	draw_circle(Vector2(8.2, -17 + bob), 1.2, Color(1.0, 0.82, 0.52))
