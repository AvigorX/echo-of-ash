class_name Combat
extends RefCounted
## Regole di combattimento melee, pure e deterministiche.
##
## Scelta progettuale: il colpo è un *arco interrogato* (distanza + angolo) invece
## di un'Area2D che deve sovrapporsi per qualche frame fisico. In headless la
## sovrapposizione di Area2D compare solo dal 3° frame fisico dopo un teletrasporto
## (misurato in questo ambiente): l'arco interrogato dà lo stesso risultato al
## primo frame e rende il combattimento testabile senza attese arbitrarie.


## Colpisce i nemici nell'arco `arc_deg` attorno a `dir` entro `reach`.
## Ritorna i nemici effettivamente colpiti (per effetti e statistica dei test).
static func resolve_melee(origin: Vector2, dir: Vector2, reach: float, arc_deg: float,
		damage: float, source: Node) -> Array[Node]:
	var hits: Array[Node] = []
	if source == null or not source.is_inside_tree():
		return hits
	var aim: Vector2 = dir.normalized()
	if aim == Vector2.ZERO:
		return hits
	var half_arc: float = deg_to_rad(arc_deg * 0.5)
	for node in source.get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.dead:
			continue
		var to_enemy: Vector2 = enemy.global_position - origin
		var dist: float = to_enemy.length()
		if dist > reach + enemy.radius:
			continue
		if dist > 0.1:
			var angle: float = absf(aim.angle_to(to_enemy.normalized()))
			if angle > half_arc:
				continue
		if enemy.take_damage(damage, origin):
			hits.append(enemy)
	return hits
