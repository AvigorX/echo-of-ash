class_name Interactable
extends Node2D
## Base delle entità interattive (pickup, NPC, braciere).
## Il `game` interroga `can_interact`/`prompt_text` per mostrare il suggerimento
## e chiama `interact(self)` quando il giocatore preme E.

var prompt_text: String = "[E] Interact"
var active: bool = true
## Raggio entro cui l'interazione è possibile (pixel mondo).
var interact_radius: float = 26.0


func can_interact(_player: Player) -> bool:
	return active and is_inside_tree()


func interact(_game: Node) -> void:
	pass
