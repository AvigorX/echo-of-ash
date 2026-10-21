class_name Pickup
extends Interactable
## Oggetto raccoglibile a terra, disegnato proceduralmente per tipo.

var item_id: String = "ash_shard"
var count: int = 1
var time: float = 0.0


func setup(id: String, amount: int = 1) -> void:
	item_id = id
	count = amount
	prompt_text = "[E] Pick up %s%s" % [ItemDB.name_of(id), (" x%d" % count) if count > 1 else ""]
	interact_radius = 24.0


func _ready() -> void:
	add_to_group("pickups")
	queue_redraw()


func _process(delta: float) -> void:
	time += delta
	queue_redraw()


func interact(game: Node) -> void:
	var player := game.get("player") as Player
	if player == null:
		return
	if player.collect(item_id, count):
		var effects := game.get("effects") as Effects
		if effects != null:
			var col: Color = ItemDB.get_def(item_id).get("color", Color(0.8, 0.8, 0.8))
			effects.burst(global_position + Vector2(0, -6), col, 10, 45.0, 0.4, 1.4)
		queue_free()


func _draw() -> void:
	var bob: float = sin(time * 2.6) * 1.2
	var y: float = -6.0 + bob
	draw_colored_polygon(PackedVector2Array([
		Vector2(-4, 0), Vector2(-2.6, -0.6), Vector2(2.6, -0.6), Vector2(4, 0), Vector2(0, 1.2),
	]), Color(0.0, 0.0, 0.0, 0.26))
	var def: Dictionary = ItemDB.get_def(item_id)
	var col: Color = def.get("color", Color(0.8, 0.8, 0.8))
	match str(def.get("kind", "resource")):
		"consumable":
			draw_rect(Rect2(-2, y - 4, 4, 5), Color(0.42, 0.36, 0.28))
			draw_rect(Rect2(-1.4, y - 6, 2.8, 2.6), col)
			draw_rect(Rect2(-0.8, y - 8, 1.6, 1.6), Color(0.72, 0.66, 0.54))
		"weapon":
			draw_line(Vector2(-4, y + 2), Vector2(4, y - 6), col, 1.6)
			draw_line(Vector2(-2, y + 1), Vector2(0, y + 3), Color(0.45, 0.36, 0.26), 1.4)
		"armor":
			draw_rect(Rect2(-4, y - 5, 8, 7), col)
			draw_rect(Rect2(-4, y - 5, 8, 1.4), col.lightened(0.25))
			draw_line(Vector2(0, y - 4), Vector2(0, y + 2), Color(0.16, 0.18, 0.18), 1.0)
		"trinket":
			draw_circle(Vector2(0, y - 3), 3.2, col)
			draw_circle(Vector2(0, y - 3), 1.4, Color(1.0, 0.88, 0.66))
			draw_line(Vector2(0, y - 6), Vector2(0, y - 8), Color(0.7, 0.7, 0.7), 1.0)
		_:
			draw_colored_polygon(PackedVector2Array([
				Vector2(0, y - 7), Vector2(3.2, y - 3), Vector2(0, y + 2), Vector2(-3.2, y - 3),
			]), col)
			draw_colored_polygon(PackedVector2Array([
				Vector2(0, y - 7), Vector2(1.2, y - 3), Vector2(0, y + 2),
			]), col.lightened(0.35))
	if count > 1:
		draw_rect(Rect2(3, y - 9, 5, 1), Color(0.9, 0.9, 0.85, 0.6))
