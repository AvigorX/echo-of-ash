class_name Game
extends Node2D
## Radice del gioco: compone mondo, giocatore, nemici, oggetti, UI e atmosfera.
## È l'unico punto che conosce tutte le parti; le parti comunicano per segnali.

const DEFAULT_SEED: int = 20261019
const ENEMY_RESPAWN_TIME: float = 28.0
const LOOT_STREAM: int = 9

var seed_value: int = DEFAULT_SEED
var world: WorldData
var player: Player = null
var hud: HUD = null
var effects: Effects
var lights: LightLayer
var fog: FogLayer
var water: WaterOverlay
var day_night: DayNight
var ysort: Node2D
var ground_root: Node2D
var ground: Sprite2D

var enemies: Array[Enemy] = []
var pickups: Array[Pickup] = []
var interactables: Array[Interactable] = []
## Ancore di respawn: {kind, pos, timer, occupied}
var respawn_anchors: Array[Dictionary] = []

var dialogue_npc: Npc = null
var dialogue_index: int = 0
var respawn_point: Vector2 = Vector2.ZERO
var loot_rng: RandomNumberGenerator
var _prompt_timer: float = 0.0
var _shake: float = 0.0
var _phase_timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hud = HUD.new()
	add_child(hud)
	hud.resume_requested.connect(_on_resume_requested)
	hud.new_world_requested.connect(regenerate)
	start_world(seed_from_args(OS.get_cmdline_user_args()))


## Seed iniziale da riga di comando: `godot --path . -- --seed 1234`.
## Senza argomento usa DEFAULT_SEED, così l'avvio è riproducibile.
static func seed_from_args(args: PackedStringArray) -> int:
	for i in range(args.size() - 1):
		if args[i] == "--seed":
			var parsed: String = args[i + 1]
			if parsed.is_valid_int():
				return int(parsed)
	return DEFAULT_SEED


# --- Ciclo di vita del mondo ------------------------------------------------

func start_world(new_seed: int) -> void:
	get_tree().paused = false
	if hud != null:
		hud.reset_overlays()
	_clear_world()
	seed_value = new_seed
	world = WorldGenerator.generate(seed_value)
	loot_rng = WorldGenerator.make_stream(seed_value, LOOT_STREAM)
	_build_layers()
	_build_ground()
	_build_props()
	_spawn_player()
	_spawn_interactables()
	_spawn_enemies()
	_spawn_world_items()
	hud.bind(player)
	hud.set_seed_info(seed_value, day_night.phase_name())
	hud.notify("World %d generated." % seed_value)


func regenerate() -> void:
	start_world(seed_value + 1)


func _clear_world() -> void:
	# Il giocatore sopravvive alla rigenerazione (progressione persistente):
	# lo stacco dal vecchio albero prima di liberare il resto del mondo.
	if player != null and is_instance_valid(player) and player.get_parent() != null:
		player.get_parent().remove_child(player)
	for child in get_children():
		if child == hud:
			continue
		remove_child(child)
		child.queue_free()
	enemies.clear()
	pickups.clear()
	interactables.clear()
	respawn_anchors.clear()
	dialogue_npc = null
	dialogue_index = 0
	_shake = 0.0


func _build_layers() -> void:
	day_night = DayNight.new()
	add_child(day_night)
	ground_root = Node2D.new()
	ground_root.z_index = -20
	add_child(ground_root)
	ysort = Node2D.new()
	ysort.y_sort_enabled = true
	add_child(ysort)
	effects = Effects.new()
	add_child(effects)
	lights = LightLayer.new()
	add_child(lights)
	fog = FogLayer.new()
	add_child(fog)


func _build_ground() -> void:
	ground = Sprite2D.new()
	ground.texture = GroundTexture.build(world, seed_value)
	ground.centered = false
	ground.z_index = -20
	ground_root.add_child(ground)
	water = WaterOverlay.new()
	water.z_index = -19
	ground_root.add_child(water)
	water.setup(world)


func _build_props() -> void:
	for p in world.props:
		ysort.add_child(PropVisual.create(p))


func _spawn_player() -> void:
	var spawn_pos: Vector2 = world.cell_to_world(world.spawn_cell)
	if player == null or not is_instance_valid(player):
		player = Player.new()
		ysort.add_child(player)
		player.attack_swing.connect(_on_attack_swing)
		player.died.connect(_on_player_died)
		player.damaged.connect(_on_player_damaged)
	else:
		ysort.add_child(player)
	player.setup(world, spawn_pos)
	respawn_point = spawn_pos
	lights.follow = player


func _spawn_interactables() -> void:
	var npc := Npc.new()
	npc.position = world.cell_to_world(world.npc_cell)
	ysort.add_child(npc)
	interactables.append(npc)
	for cell in world.brazier_cells:
		var brazier := Brazier.new()
		brazier.position = world.cell_to_world(cell)
		ysort.add_child(brazier)
		interactables.append(brazier)
		lights.add_point(brazier.position + Vector2(0, -12), 62.0, Color(1.0, 0.66, 0.32, 0.32))


func _spawn_enemies() -> void:
	var index: int = 0
	for spawn in world.enemy_spawns:
		var pos: Vector2 = world.cell_to_world(spawn["cell"])
		var enemy := _spawn_enemy(str(spawn["type"]), pos, seed_value + index)
		respawn_anchors.append({
			"kind": str(spawn["type"]),
			"pos": pos,
			"timer": -1.0,
			"enemy": enemy,
		})
		index += 1


func _spawn_enemy(kind: String, pos: Vector2, rng_seed: int) -> Enemy:
	var enemy := Enemy.new()
	enemy.configure(kind, pos, player, rng_seed)
	enemy.world = world
	ysort.add_child(enemy)
	enemy.died.connect(_on_enemy_died)
	enemy.struck.connect(_on_enemy_struck)
	enemies.append(enemy)
	return enemy


func _spawn_world_items() -> void:
	for it in world.item_spawns:
		spawn_pickup(str(it["item"]), world.cell_to_world(it["cell"]), 1)


func spawn_pickup(item_id: String, pos: Vector2, count: int = 1) -> Pickup:
	var pickup := Pickup.new()
	pickup.setup(item_id, count)
	pickup.position = pos
	ysort.add_child(pickup)
	pickups.append(pickup)
	return pickup


## Helper pubblico per test e debug: crea un nemico in una posizione arbitraria.
func spawn_enemy_at(kind: String, pos: Vector2) -> Enemy:
	return _spawn_enemy(kind, pos, seed_value + enemies.size() + 1)


# --- Combattimento ----------------------------------------------------------

func _on_attack_swing(dir: Vector2, damage: float) -> void:
	if player == null:
		return
	effects.slash(player.global_position, dir)
	var hits := Combat.resolve_melee(player.global_position, dir, Player.ATTACK_REACH, Player.ATTACK_ARC_DEG, damage, self)
	for hit in hits:
		var enemy := hit as Enemy
		if enemy == null:
			continue
		effects.burst(enemy.global_position + Vector2(0, -8), Color(0.95, 0.78, 0.48), 7, 70.0, 0.30, 1.6)
	_shake = maxf(_shake, 0.16 if hits.is_empty() else 0.30)


func _on_enemy_struck(pos: Vector2, dir: Vector2) -> void:
	effects.burst(pos + dir * 12.0 + Vector2(0, -6), Color(0.92, 0.36, 0.30), 6, 55.0, 0.3, 1.5)


func _on_enemy_died(enemy: Enemy) -> void:
	effects.burst(enemy.global_position + Vector2(0, -8), Color(0.42, 0.40, 0.44), 16, 80.0, 0.6, 2.0)
	effects.burst(enemy.global_position + Vector2(0, -8), Color(0.86, 0.36, 0.24), 8, 45.0, 0.5, 1.4)
	if player != null and not player.dead:
		player.gain_xp(enemy.xp_reward)
		hud.notify("%s slain  +%d XP" % [enemy.display_name, enemy.xp_reward])
	_drop_loot(enemy)
	for anchor in respawn_anchors:
		if anchor["enemy"] == enemy:
			anchor["timer"] = ENEMY_RESPAWN_TIME
			anchor["enemy"] = null
			break


func _drop_loot(enemy: Enemy) -> void:
	var drops: Array[Dictionary] = []
	if enemy.kind == "warden":
		drops.append({"item": "ash_shard", "count": 2})
		if loot_rng.randf() < 0.55:
			drops.append({"item": "warden_plate", "count": 1})
		if loot_rng.randf() < 0.35:
			drops.append({"item": "ember_charm", "count": 1})
		if loot_rng.randf() < 0.45:
			drops.append({"item": "vial_of_sap", "count": 1})
	else:
		if loot_rng.randf() < 0.72:
			drops.append({"item": "ash_shard", "count": 1})
		if loot_rng.randf() < 0.16:
			drops.append({"item": "vial_of_sap", "count": 1})
		if loot_rng.randf() < 0.06:
			drops.append({"item": "ash_blade", "count": 1})
	var spread: int = 0
	for d in drops:
		var offset := Vector2((spread - 1) * 8.0, 0)
		spawn_pickup(str(d["item"]), enemy.global_position + offset, int(d["count"]))
		spread += 1


func _on_player_damaged(_amount: int) -> void:
	_shake = maxf(_shake, 0.45)


func _on_player_died() -> void:
	hud.set_dead(true)
	effects.burst(player.global_position + Vector2(0, -8), Color(0.72, 0.18, 0.22), 24, 90.0, 0.9, 2.0)
	_shake = 0.7


func respawn_player() -> void:
	if player == null:
		return
	player.respawn(respawn_point)
	hud.set_dead(false)
	effects.ring(player.global_position, Color(0.45, 0.80, 0.85))


func set_respawn_point(p: Vector2) -> void:
	respawn_point = p


# --- Dialogo e interazione --------------------------------------------------

func start_dialogue(npc: Npc) -> void:
	dialogue_npc = npc
	dialogue_index = 0
	hud.toggle_inventory_if_open()
	hud.show_dialogue(Npc.NPC_NAME, npc.lines[0], 0, npc.lines.size())


func advance_dialogue() -> void:
	if dialogue_npc == null:
		return
	dialogue_index += 1
	if dialogue_index >= dialogue_npc.lines.size():
		var npc := dialogue_npc
		dialogue_npc = null
		hud.close_dialogue()
		npc.on_dialogue_finished(self)
	else:
		hud.show_dialogue(Npc.NPC_NAME, dialogue_npc.lines[dialogue_index], dialogue_index, dialogue_npc.lines.size())


func nearest_interactable() -> Interactable:
	if player == null:
		return null
	var best: Interactable = null
	var best_d: float = 1e20
	for node in interactables:
		if not is_instance_valid(node) or not node.is_inside_tree():
			continue
		if not node.can_interact(player):
			continue
		var d: float = node.global_position.distance_to(player.global_position)
		if d <= node.interact_radius and d < best_d:
			best = node
			best_d = d
	if best != null:
		return best
	# i pickup sono interattivi ma non stanno nell'array: li cerco nel gruppo
	for node in get_tree().get_nodes_in_group("pickups"):
		var pickup := node as Pickup
		if pickup == null or not pickup.is_inside_tree():
			continue
		var d2: float = pickup.global_position.distance_to(player.global_position)
		if d2 <= pickup.interact_radius and d2 < best_d:
			best = pickup
			best_d = d2
	return best


func interact() -> void:
	if player == null:
		return
	if player.dead:
		respawn_player()
		return
	if hud.dialogue_open:
		advance_dialogue()
		return
	if hud.inventory_open:
		hud.toggle_inventory()
		return
	var target := nearest_interactable()
	if target != null:
		target.interact(self)


# --- Input e pausa ----------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if player == null:
		return
	if event.is_action_pressed("pause"):
		if not player.dead:
			set_paused(not hud.paused)
		get_viewport().set_input_as_handled()
		return
	if hud.paused:
		if event.is_action_pressed("regenerate"):
			regenerate()
		return
	if event.is_action_pressed("regenerate"):
		regenerate()
		get_viewport().set_input_as_handled()
		return
	if player.dead:
		if event.is_action_pressed("interact"):
			respawn_player()
		return
	if event.is_action_pressed("interact") and not hud.dialogue_open:
		interact()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and hud.dialogue_open:
		interact()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory"):
		if not hud.dialogue_open:
			hud.toggle_inventory()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("use_slot_1"):
		player.use_slot(0)
	elif event.is_action_pressed("use_slot_2"):
		player.use_slot(1)
	elif event.is_action_pressed("use_slot_3"):
		player.use_slot(2)
	elif event.is_action_pressed("use_slot_4"):
		player.use_slot(3)


func set_paused(value: bool) -> void:
	hud.set_paused(value)
	get_tree().paused = value


func _on_resume_requested() -> void:
	set_paused(false)


# --- Processo ----------------------------------------------------------------

func _process(delta: float) -> void:
	if player == null:
		return
	_shake = maxf(0.0, _shake - delta * 2.4)
	if player.camera != null:
		player.camera.offset = Vector2(sin(_shake * 70.0) * _shake * 5.0, cos(_shake * 53.0) * _shake * 3.5) if _shake > 0.0 else Vector2.ZERO
	_prompt_timer -= delta
	if _prompt_timer <= 0.0:
		_prompt_timer = 0.08
		_update_prompt()
	_phase_timer -= delta
	if _phase_timer <= 0.0:
		_phase_timer = 1.0
		hud.set_seed_info(seed_value, day_night.phase_name())
	_tick_respawns(delta)


func _update_prompt() -> void:
	if hud.paused or player.dead or hud.dialogue_open or hud.inventory_open:
		hud.set_prompt("")
		return
	var target := nearest_interactable()
	hud.set_prompt(target.prompt_text if target != null else "")


func _tick_respawns(delta: float) -> void:
	if player == null or player.dead:
		return
	for anchor in respawn_anchors:
		if anchor["enemy"] != null:
			continue
		var timer: float = float(anchor["timer"])
		if timer < 0.0:
			continue
		timer -= delta
		anchor["timer"] = timer
		if timer <= 0.0:
			if player.global_position.distance_to(anchor["pos"]) > 260.0:
				var enemy := _spawn_enemy(str(anchor["kind"]), anchor["pos"], seed_value + int(Time.get_ticks_msec()))
				anchor["enemy"] = enemy
				anchor["timer"] = -1.0
			else:
				anchor["timer"] = 4.0


# --- Stato per test e diagnostica ------------------------------------------

func alive_enemy_count() -> int:
	var n: int = 0
	for e in enemies:
		if is_instance_valid(e) and not e.dead:
			n += 1
	return n


func state() -> Dictionary:
	return {
		"seed": seed_value,
		"hash": world.layout_hash() if world != null else 0,
		"player_pos": player.global_position if player != null else Vector2.ZERO,
		"player_health": player.health if player != null else 0,
		"player_level": player.level if player != null else 0,
		"player_xp": player.xp if player != null else 0,
		"enemies_alive": alive_enemy_count(),
		"props": world.props.size() if world != null else 0,
		"pickups": get_tree().get_nodes_in_group("pickups").size(),
		"paused": hud.paused if hud != null else false,
		"dialogue": hud.dialogue_open if hud != null else false,
		"dead": player.dead if player != null else false,
	}
