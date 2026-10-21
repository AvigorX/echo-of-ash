extends SceneTree
## Test headless del gioco completo: carica la scena reale e verifica stato,
## input, collisioni, combattimento, loot, inventario, progressione, dialogo,
## pausa, morte/respawn e rigenerazione del mondo.
##
## Uso:
##   Godot_v4.7.2-stable_win64_console.exe --headless \
##     --path projects/echoes-of-ash --script res://tests/test_gameplay.gd
##
## Esce 0 se tutti i controlli passano, 1 altrimenti.

var _pass: int = 0
var _fail: int = 0
var _lines: Array[String] = []
var game: Game = null


func _initialize() -> void:
	_main()


func _check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		_pass += 1
		_lines.append("  PASS  %s%s" % [name, ("  [%s]" % detail) if detail != "" else ""])
	else:
		_fail += 1
		_lines.append("  FAIL  %s%s" % [name, ("  [%s]" % detail) if detail != "" else ""])


func _phys(n: int) -> void:
	for i in n:
		await physics_frame


func _press_key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventKey.new()
	up.keycode = code
	up.physical_keycode = code
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame
	await process_frame


## Area di celle libere e asciutte, lontana dagli altri nemici.
func _find_open_area(clearance: int = 2) -> Vector2:
	var best := game.world.cell_to_world(game.world.spawn_cell)
	for y in range(4 + clearance, game.world.height - 4 - clearance):
		for x in range(4 + clearance, game.world.width - 4 - clearance):
			var ok := true
			for dy in range(-clearance, clearance + 1):
				for dx in range(-clearance, clearance + 1):
					if not game.world.is_walkable_cell(Vector2i(x + dx, y + dy)):
						ok = false
						break
				if not ok:
					break
			if ok:
				return game.world.cell_to_world(Vector2i(x, y))
	return best


func _main() -> void:
	_lines.append("=== Echoes of Ash — test di gameplay ===")
	var packed: PackedScene = load("res://scenes/main.tscn")
	_check("scena principale caricata", packed != null)
	if packed == null:
		_finish()
		return
	game = packed.instantiate() as Game
	_check("la radice è uno script Game", game != null)
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	await physics_frame

	_check("mondo generato", game.world != null, "seed %d" % game.seed_value)
	_check("giocatore creato", game.player != null)
	_check("HUD creata", game.hud != null)
	_check("24 nemici vivi all'avvio", game.alive_enemy_count() == 24, "%d" % game.alive_enemy_count())
	_check("props nel mondo (>150)", game.world.props.size() > 150, "%d" % game.world.props.size())
	_check("18 pickups sparsi", get_nodes_in_group("pickups").size() == 18, "%d" % get_nodes_in_group("pickups").size())
	_check("camera attiva sul giocatore", game.player.camera != null and game.player.camera.enabled)

	# --- InputMap -----------------------------------------------------------
	var actions: Array[String] = ["move_left", "move_right", "move_up", "move_down", "attack",
		"interact", "inventory", "pause", "regenerate", "use_slot_1", "use_slot_2", "use_slot_3", "use_slot_4"]
	var missing: Array[String] = []
	for a in actions:
		if not InputMap.has_action(a):
			missing.append(a)
	_check("tutte le 13 azioni sono nella InputMap", missing.is_empty(), ", ".join(missing))
	var attack_events := InputMap.action_get_events("attack")
	_check("attacco legato al tasto sinistro del mouse",
		attack_events.size() > 0 and attack_events[0] is InputEventMouseButton and (attack_events[0] as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	var pause_events := InputMap.action_get_events("pause")
	_check("pausa legata a ESC", pause_events.size() > 0 and (pause_events[0] as InputEventKey).physical_keycode == KEY_ESCAPE)
	_check("seed da riga di comando (--seed N)",
		Game.seed_from_args(PackedStringArray(["--seed", "4321"])) == 4321
		and Game.seed_from_args(PackedStringArray([])) == Game.DEFAULT_SEED,
		"default=%d" % Game.DEFAULT_SEED)

	# --- movimento ----------------------------------------------------------
	var start_pos: Vector2 = game.player.global_position
	Input.action_press("move_right")
	await _phys(24)
	Input.action_release("move_right")
	await _phys(2)
	var moved: float = game.player.global_position.x - start_pos.x
	_check("il giocatore si muove a destra", moved > 8.0, "dx=%.1f" % moved)
	Input.action_press("move_down")
	await _phys(20)
	Input.action_release("move_down")
	await _phys(2)
	_check("il giocatore si muove in basso (8 direzioni)",
		game.player.global_position.y > start_pos.y + 4.0, "y=%.1f" % game.player.global_position.y)

	# disattivo i nemici preesistenti per isolare i test di combattimento
	for e in game.enemies:
		if is_instance_valid(e):
			e.process_mode = Node.PROCESS_MODE_DISABLED

	# --- collisione con un ostacolo solido ----------------------------------
	var solid_cell := _find_solid_prop_cell()
	if solid_cell.x >= 0:
		var prop := _prop_at(solid_cell)
		var radius: float = float(prop["radius"])
		var approach := solid_cell + Vector2i(-1, 0)
		if not game.world.is_walkable_cell(approach):
			approach = solid_cell + Vector2i(0, -1)
		game.player.global_position = game.world.cell_to_world(approach)
		game.player.velocity = Vector2.ZERO
		await _phys(3)
		Input.action_press("move_right")
		await _phys(30)
		Input.action_release("move_right")
		await _phys(2)
		var centre: Vector2 = game.world.cell_to_world(solid_cell)
		var dist: float = game.player.global_position.distance_to(centre)
		_check("il giocatore è bloccato dal prop solido", dist >= radius - 1.0, "d=%.1f r=%.1f" % [dist, radius])
	else:
		_check("il giocatore è bloccato dal prop solido", false, "nessun prop solido trovato")

	# --- l'acqua blocca il movimento ---------------------------------------
	var shore: Dictionary = _find_shore()
	if not shore.is_empty():
		game.player.respawn(game.world.cell_to_world(shore["cell"]))
		game.player.invuln = 99.0
		await _phys(3)
		var water_action: String = str(shore["action"])
		var shore_start: Vector2 = game.player.global_position
		Input.action_press(water_action)
		await _phys(45)
		Input.action_release(water_action)
		await _phys(2)
		var feet: Vector2 = game.player.global_position + Vector2(0, -3)
		var shore_moved: float = game.player.global_position.distance_to(shore_start)
		_check("non si può camminare sull'acqua",
			not game.world.is_water_at_pos(feet) and shore_moved > 1.0,
			"pos=%s cella=%s spostato=%.1f" % [str(game.player.global_position), str(game.world.world_to_cell(feet)), shore_moved])
	else:
		_check("non si può camminare sull'acqua", false, "nessuna costa trovata")
	game.player.invuln = 0.0

	# --- combattimento ------------------------------------------------------
	var arena := _find_open_area()
	game.player.global_position = arena
	game.player.velocity = Vector2.ZERO
	await _phys(3)
	var crawler: Enemy = game.spawn_enemy_at("crawler", arena + Vector2(18, 0))
	await _phys(3)
	var hp_before: int = crawler.health
	var swing_seen: Array = []
	game.player.attack_swing.connect(func(_d, _dmg): swing_seen.append(1))
	var attacked: bool = game.player.try_attack(Vector2.RIGHT)
	await _phys(2)
	_check("l'attacco parte quando il cooldown è pronto", attacked)
	_check("il segnale attack_swing è emesso", swing_seen.size() == 1, "%d" % swing_seen.size())
	_check("il nemico subisce danno", crawler.health < hp_before, "%d -> %d" % [hp_before, crawler.health])
	_check("il nemico riceve knockback", crawler.knockback.length() > 1.0, "%.1f" % crawler.knockback.length())
	_check("cooldown attivo dopo il colpo", game.player.attack_cooldown > 0.0, "%.2f" % game.player.attack_cooldown)
	_check("secondo attacco immediato rifiutato dal cooldown", not game.player.try_attack(Vector2.RIGHT))

	# uccisione + ricompensa XP
	var xp_before: int = game.player.xp
	var level_before: int = game.player.level
	var guard: int = 0
	while not crawler.dead and guard < 40:
		guard += 1
		game.player.attack_cooldown = 0.0
		game.player.try_attack(Vector2.RIGHT)
		await physics_frame
	var dead_now: bool = crawler.dead
	var left_group: bool = not crawler.is_in_group("enemies")
	_check("il nemico muore dopo i colpi", dead_now, "colpi=%d" % guard)
	_check("uccisione -> XP", game.player.xp != xp_before or game.player.level > level_before,
		"xp %d -> %d, lv %d" % [xp_before, game.player.xp, game.player.level])
	_check("il nemico esce dal gruppo enemies", left_group)

	# loot garantito dal Warden (2 ash shard)
	var pickups_before: int = get_nodes_in_group("pickups").size()
	var warden: Enemy = game.spawn_enemy_at("warden", arena + Vector2(22, 0))
	await _phys(3)
	guard = 0
	while not warden.dead and guard < 120:
		guard += 1
		game.player.attack_cooldown = 0.0
		game.player.try_attack(Vector2.RIGHT)
		await physics_frame
	_check("il Warden muore", warden.dead, "colpi=%d" % guard)
	await _phys(2)
	_check("loot del Warden a terra (>=2 pickup)", get_nodes_in_group("pickups").size() >= pickups_before + 2,
		"%d -> %d" % [pickups_before, get_nodes_in_group("pickups").size()])

	# --- IA: inseguimento e rispetto degli ostacoli -------------------------
	var chase_arena: Vector2 = _find_open_area(5)
	game.player.respawn(chase_arena)
	game.player.invuln = 999.0
	await _phys(2)
	var hunter: Enemy = game.spawn_enemy_at("crawler", chase_arena + Vector2(70, 0))
	await _phys(2)
	var hunter_start: float = hunter.global_position.distance_to(game.player.global_position)
	var hunter_min: float = hunter_start
	var worst_overlap: float = 0.0
	for i in 180:
		await physics_frame
		hunter_min = minf(hunter_min, hunter.global_position.distance_to(game.player.global_position))
		if i % 10 == 0:
			worst_overlap = maxf(worst_overlap, _deepest_penetration(hunter))
	hunter.process_mode = Node.PROCESS_MODE_DISABLED
	_check("un nemico che insegue si avvicina davvero al giocatore",
		hunter_min < hunter_start - 40.0, "%.0f -> %.0f px" % [hunter_start, hunter_min])
	_check("il nemico mantiene la distanza di rispetto (non entra nel giocatore)",
		hunter_min >= 8.0, "distanza minima %.1f px" % hunter_min)
	_check("il nemico non compenetra i props solidi", worst_overlap < 1.0, "max=%.2f px" % worst_overlap)
	game.player.invuln = 0.0

	# --- pickup e inventario -------------------------------------------------
	game.player.global_position = arena
	game.player.velocity = Vector2.ZERO
	await _phys(3)
	var test_pickup: Pickup = game.spawn_pickup("ash_shard", game.player.global_position + Vector2(4, 0), 3)
	await _phys(2)
	game._update_prompt()
	_check("prompt di interazione visibile vicino a un oggetto",
		game.hud.prompt_label.visible and game.hud.prompt_label.text.contains("[E]"),
		game.hud.prompt_label.text)
	var shards_before: int = game.player.inventory.count_of("ash_shard")
	game.interact()
	await _phys(2)
	_check("E raccoglie l'oggetto nell'inventario",
		game.player.inventory.count_of("ash_shard") == shards_before + 3,
		"%d -> %d" % [shards_before, game.player.inventory.count_of("ash_shard")])
	_check("il pickup raccolto è rimosso", not is_instance_valid(test_pickup) or test_pickup.is_queued_for_deletion())

	# pozione: cura
	game.player.collect("vial_of_sap", 1)
	game.player.invuln = 0.0
	game.player.take_damage(40.0, game.player.global_position + Vector2(10, 0))
	await _phys(2)
	var hurt: int = game.player.health
	var healed_msg: String = game.player.inventory.use("vial_of_sap", game.player)
	await _phys(2)
	_check("la pozione cura e si consuma", game.player.health > hurt and healed_msg.contains("Restored"),
		"%d -> %d [%s]" % [hurt, game.player.health, healed_msg])
	_check("la pozione è stata rimossa", game.player.inventory.count_of("vial_of_sap") == 0)

	# equipaggiamento: arma e amuleto
	var damage_before: float = game.player.total_damage()
	game.player.collect("ash_blade", 1)
	game.player.inventory.equip("ash_blade")
	await _phys(2)
	_check("l'arma equipaggiata aumenta il danno", game.player.total_damage() > damage_before,
		"%.1f -> %.1f" % [damage_before, game.player.total_damage()])
	var maxhp_before: int = game.player.total_max_health()
	game.player.collect("ember_charm", 1)
	game.player.inventory.equip("ember_charm")
	await _phys(2)
	_check("l'amuleto aumenta la salute massima", game.player.total_max_health() > maxhp_before,
		"%d -> %d" % [maxhp_before, game.player.total_max_health()])
	var armor_before: float = game.player.armor()
	game.player.collect("warden_plate", 1)
	game.player.inventory.equip("warden_plate")
	await _phys(2)
	_check("l'armatura riduce il danno subito", game.player.armor() > armor_before,
		"%.1f -> %.1f" % [armor_before, game.player.armor()])

	# inventario UI
	var inv_before: bool = game.hud.inventory_open
	await _press_key(KEY_I)
	_check("I apre/chiude il pannello inventario", game.hud.inventory_open != inv_before,
		"aperto=%s" % game.hud.inventory_open)
	await _press_key(KEY_I)
	_check("I richiude l'inventario", game.hud.inventory_open == false)

	# --- progressione -------------------------------------------------------
	var lv_before: int = game.player.level
	var hp_max_before: int = game.player.total_max_health()
	game.player.gain_xp(game.player.xp_next)
	await _phys(2)
	_check("l'esperienza fa salire di livello", game.player.level == lv_before + 1,
		"lv %d -> %d" % [lv_before, game.player.level])
	_check("il livello aumenta la salute massima", game.player.total_max_health() > hp_max_before,
		"%d -> %d" % [hp_max_before, game.player.total_max_health()])
	_check("la barra XP della HUD si aggiorna", game.hud.xp_label.text.contains("XP"), game.hud.xp_label.text)
	_check("la barra salute della HUD riflette lo stato", game.hud.hp_label.text.contains("/"), game.hud.hp_label.text)

	# --- danno da nemico ----------------------------------------------------
	game.hud.set_dead(false)
	game.player.respawn(arena)
	game.player.invuln = 0.0
	await _phys(3)
	var health_before_hit: int = game.player.health
	var attacker: Enemy = game.spawn_enemy_at("crawler", arena + Vector2(16, 0))
	var hit_after: float = -1.0
	for i in 90:
		await physics_frame
		if game.player.health < health_before_hit:
			hit_after = float(i) / 60.0
			break
	_check("un nemico in mischia ferisce il giocatore", hit_after >= 0.0,
		"%d -> %d dopo %.2fs" % [health_before_hit, game.player.health, hit_after])
	_check("il danno attiva il feedback (vignetta)", game.hud.vignette.amount > 0.0,
		"vignetta=%.2f" % game.hud.vignette.amount)
	attacker.process_mode = Node.PROCESS_MODE_DISABLED

	# --- NPC e dialogo ------------------------------------------------------
	game.player.respawn(game.world.cell_to_world(game.world.npc_cell) + Vector2(0, 14))
	game.player.invuln = 99.0
	await _phys(4)
	var charms_before: int = game.player.inventory.count_of("ember_charm")
	game.interact()
	await _phys(2)
	_check("E avvia il dialogo con l'NPC", game.hud.dialogue_open and game.hud.dialogue_panel.visible)
	_check("il dialogo mostra il nome del personaggio", game.hud.dialogue_name.text == Npc.NPC_NAME,
		game.hud.dialogue_name.text)
	guard = 0
	while game.hud.dialogue_open and guard < 12:
		guard += 1
		game.interact()
		await _phys(2)
	_check("il dialogo termina dopo tutte le battute", not game.hud.dialogue_open, "passi=%d" % guard)
	_check("l'NPC ricompensa una volta sola", game.player.inventory.count_of("ember_charm") == charms_before + 1,
		"%d -> %d" % [charms_before, game.player.inventory.count_of("ember_charm")])
	var charms_after: int = game.player.inventory.count_of("ember_charm")
	game.interact()
	await _phys(2)
	while game.hud.dialogue_open and guard < 30:
		guard += 1
		game.interact()
		await _phys(2)
	_check("una seconda conversazione non duplica la ricompensa",
		game.player.inventory.count_of("ember_charm") == charms_after)

	# --- braciere: cura -----------------------------------------------------
	game.player.invuln = 0.0
	game.player.take_damage(30.0, game.player.global_position + Vector2(5, 0))
	await _phys(2)
	var health_before_rest: int = game.player.health
	var brazier: Brazier = null
	for node in game.interactables:
		if node is Brazier:
			brazier = node as Brazier
			break
	_check("braciere presente nel mondo", brazier != null)
	if brazier != null:
		game.player.global_position = brazier.global_position + Vector2(0, 12)
		await _phys(3)
		game.interact()
		await _phys(2)
		_check("il braciere cura il giocatore", game.player.health > health_before_rest,
			"%d -> %d" % [health_before_rest, game.player.health])
		_check("il braciere entra in cooldown", brazier.cooldown > 0.0, "%.1f" % brazier.cooldown)

	# --- pausa --------------------------------------------------------------
	await _press_key(KEY_ESCAPE)
	_check("ESC mette in pausa", paused and game.hud.paused)
	_check("il menu di pausa è visibile", game.hud.pause_panel.visible)
	await _press_key(KEY_ESCAPE)
	_check("ESC toglie la pausa", not paused and not game.hud.paused)

	# pulsanti del menu (stessi segnali emessi dai Button della HUD)
	game.set_paused(true)
	game.hud.resume_requested.emit()
	await _phys(2)
	_check("il pulsante Resume riprende il gioco", not paused and not game.hud.paused)
	var seed_before_menu: int = game.seed_value
	game.set_paused(true)
	game.hud.new_world_requested.emit()
	await _phys(3)
	_check("il pulsante New world rigenera e toglie la pausa",
		game.seed_value == seed_before_menu + 1 and not paused and not game.hud.paused,
		"seed %d -> %d" % [seed_before_menu, game.seed_value])

	# --- morte e respawn ----------------------------------------------------
	game.player.invuln = 0.0
	game.player.take_damage(9999.0, game.player.global_position + Vector2(1, 0))
	await _phys(3)
	_check("il giocatore muore a salute zero", game.player.dead)
	_check("la schermata di morte è visibile", game.hud.death_panel.visible)
	await _press_key(KEY_E)
	await _phys(3)
	_check("E fa rinascere il giocatore", not game.player.dead)
	_check("il respawn ripristina la salute", game.player.health == game.player.total_max_health(),
		"%d/%d" % [game.player.health, game.player.total_max_health()])
	_check("la schermata di morte scompare", not game.hud.death_panel.visible)

	# --- respawn dei nemici (alternativa documentata alla permadeath) -------
	var anchor: Dictionary = {}
	for a in game.respawn_anchors:
		if a["enemy"] != null and is_instance_valid(a["enemy"]):
			anchor = a
			break
	if not anchor.is_empty():
		var victim: Enemy = anchor["enemy"]
		victim.take_damage(9999.0, victim.global_position + Vector2(6, 0))
		await _phys(2)
		var alive_before_respawn: int = game.alive_enemy_count()
		var far := Vector2(40, 40)
		if (anchor["pos"] as Vector2).distance_to(far) < 320.0:
			far = Vector2(game.world.world_size().x - 40.0, game.world.world_size().y - 40.0)
		game.player.respawn(far)
		game.player.invuln = 99.0
		anchor["timer"] = 0.01
		await _phys(12)
		_check("il nemico ricompare dopo il timer, lontano dal giocatore",
			game.alive_enemy_count() > alive_before_respawn,
			"%d -> %d (distanza %.0f)" % [alive_before_respawn, game.alive_enemy_count(),
				game.player.global_position.distance_to(anchor["pos"])])
	else:
		_check("il nemico ricompare dopo il timer, lontano dal giocatore", false, "nessuna ancora attiva")
	game.player.invuln = 0.0

	# --- rigenerazione del mondo -------------------------------------------
	var old_hash: int = game.world.layout_hash()
	var old_seed: int = game.seed_value
	var lv_before_regen: int = game.player.level
	var shards_before_regen: int = game.player.inventory.count_of("ash_shard")
	var player_id: int = game.player.get_instance_id()
	game.regenerate()
	await _phys(3)
	_check("R rigenera un mondo diverso", game.world.layout_hash() != old_hash and game.seed_value == old_seed + 1,
		"seed %d -> %d" % [old_seed, game.seed_value])
	_check("il nuovo mondo ha un giocatore valido", game.player != null and not game.player.dead)
	_check("la progressione sopravvive alla rigenerazione",
		game.player.level == lv_before_regen and game.player.inventory.count_of("ash_shard") == shards_before_regen,
		"lv %d, shard %d" % [game.player.level, game.player.inventory.count_of("ash_shard")])
	_check("il nodo giocatore è riusato (nessuna perdita di stato)", game.player.get_instance_id() == player_id)
	_check("il nuovo mondo ripopola i nemici", game.alive_enemy_count() == 24, "%d" % game.alive_enemy_count())
	_check("il giocatore rinasce allo spawn del nuovo mondo",
		game.player.global_position.distance_to(game.world.cell_to_world(game.world.spawn_cell)) < 2.0)
	_check("la HUD è ricollegata al nuovo giocatore", game.hud.player == game.player)

	# determinismo runtime: stesso seed -> stesso mondo
	game.start_world(424242)
	await _phys(2)
	var h1: int = game.world.layout_hash()
	game.start_world(424242)
	await _phys(2)
	var h2: int = game.world.layout_hash()
	_check("stesso seed rigenerato a runtime -> stesso mondo", h1 == h2, "%d vs %d" % [h1, h2])
	_check("dopo la rigenerazione il gioco non è in pausa", not paused and not game.hud.paused)

	# --- nessun errore di script residuo -----------------------------------
	_check("il giocatore è dentro l'albero", game.player.is_inside_tree())
	_check("il conteggio nemici resta coerente", game.alive_enemy_count() > 0, "%d" % game.alive_enemy_count())

	_finish()


## Quanto un nemico è dentro il cerchio di collisione di un prop solido (px).
func _deepest_penetration(enemy: Enemy) -> float:
	var worst: float = 0.0
	var enemy_centre: Vector2 = enemy.global_position + Vector2(0, -enemy.radius * 0.4)
	for p in game.world.props:
		if not bool(p["solid"]):
			continue
		var cell: Vector2i = p["cell"]
		var radius: float = float(p["radius"])
		var prop_centre := Vector2(cell.x * 16 + 8, cell.y * 16 + 8 - radius * 0.35)
		worst = maxf(worst, radius + enemy.radius - enemy_centre.distance_to(prop_centre))
	return worst


## Costa calpestabile con acqua adiacente + azione che spinge verso l'acqua.
func _find_shore() -> Dictionary:
	var moves: Array[Dictionary] = [
		{"d": Vector2i(1, 0), "a": "move_right"},
		{"d": Vector2i(-1, 0), "a": "move_left"},
		{"d": Vector2i(0, 1), "a": "move_down"},
		{"d": Vector2i(0, -1), "a": "move_up"},
	]
	for y in range(5, game.world.height - 5):
		for x in range(5, game.world.width - 5):
			var c := Vector2i(x, y)
			if not game.world.is_walkable_cell(c):
				continue
			for m in moves:
				if game.world.terrain_at(c + (m["d"] as Vector2i)) == WorldData.Terrain.WATER:
					return {"cell": c, "action": str(m["a"])}
	return {}


func _find_solid_prop_cell() -> Vector2i:
	for p in game.world.props:
		if not bool(p["solid"]):
			continue
		var cell: Vector2i = p["cell"]
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if game.world.is_walkable_cell(cell + d):
				return cell
	return Vector2i(-1, -1)


func _prop_at(cell: Vector2i) -> Dictionary:
	for p in game.world.props:
		if p["cell"] == cell and bool(p["solid"]):
			return p
	return {"radius": 6.0}


func _finish() -> void:
	_lines.append("--- %d passati, %d falliti ---" % [_pass, _fail])
	for l in _lines:
		print(l)
	quit(0 if _fail == 0 else 1)
