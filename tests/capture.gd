extends SceneTree
## Cattura screenshot dal rendering reale (NON headless: il driver dummy non
## produce pixel). Salva i PNG in res://out/ e stampa statistiche sull'immagine,
## così anche un agente senza vista può verificare che il frame non sia vuoto.
##
## Uso (con l'eseguibile GUI, non _console se non serve l'output):
##   Godot_v4.7.2-stable_win64.exe --path projects/echoes-of-ash \
##     --script res://tests/capture.gd

var game: Game = null


func _initialize() -> void:
	_main()


func _main() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://out"))
	var packed: PackedScene = load("res://scenes/main.tscn")
	game = packed.instantiate() as Game
	root.add_child(game)
	for i in 20:
		await process_frame
	var arena: Vector2 = _find_open_area()

	# 1. vista iniziale allo spawn, con HUD completa
	await RenderingServer.frame_post_draw
	await _shot("res://out/shot_01_spawn.png")

	# 2. combattimento: due nemici vicini, attacco in corso, effetti
	game.player.global_position = arena
	game.player.velocity = Vector2.ZERO
	var crawler: Enemy = game.spawn_enemy_at("crawler", arena + Vector2(24, -4))
	var warden: Enemy = game.spawn_enemy_at("warden", arena + Vector2(-34, 6))
	for i in 4:
		await physics_frame
	game.player.attack_cooldown = 0.0
	game.player.try_attack(Vector2.RIGHT)
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	await _shot("res://out/shot_02_combat.png")

	# 3. dialogo con l'NPC
	game.player.global_position = game.world.cell_to_world(game.world.npc_cell) + Vector2(0, 16)
	for i in 8:
		await physics_frame
	game.start_dialogue(_find_npc())
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	await _shot("res://out/shot_03_dialogue.png")

	# 4. inventario aperto
	game.hud.close_dialogue()
	game.player.collect("ash_shard", 12)
	game.player.collect("vial_of_sap", 2)
	game.player.collect("ash_blade", 1)
	game.player.collect("ember_charm", 1)
	game.player.inventory.equip("ash_blade")
	game.player.inventory.equip("ember_charm")
	game.hud.toggle_inventory()
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	await _shot("res://out/shot_04_inventory.png")

	# 5. pausa
	game.hud.toggle_inventory()
	game.set_paused(true)
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	await _shot("res://out/shot_05_pause.png")
	game.set_paused(false)

	# 6. primo piano: giocatore e i due tipi di nemico, con camera centrata
	game.player.global_position = game.world.cell_to_world(game.world.spawn_cell)
	game.player.velocity = Vector2.ZERO
	game.player.facing = Vector2.DOWN
	game.player.camera.reset_smoothing()
	game.spawn_enemy_at("crawler", game.player.global_position + Vector2(26, 2))
	game.spawn_enemy_at("warden", game.player.global_position + Vector2(-34, -2))
	for i in 10:
		await physics_frame
	await RenderingServer.frame_post_draw
	print("PLAYER_SCREEN ", game.player.get_global_transform_with_canvas().origin)
	await _shot("res://out/shot_06_closeup.png")

	# 7. notte: tinta del CanvasModulate + luce della torcia
	game.day_night.time_of_day = 0.92
	game.day_night.color = game.day_night.sample(0.92)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	await _shot("res://out/shot_07_night.png")

	print("CAPTURE_OK")
	quit(0)


func _find_npc() -> Npc:
	for node in game.interactables:
		if node is Npc:
			return node as Npc
	return null


func _find_open_area() -> Vector2:
	for y in range(4, game.world.height - 4):
		for x in range(4, game.world.width - 4):
			var ok := true
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					if not game.world.is_walkable_cell(Vector2i(x + dx, y + dy)):
						ok = false
						break
				if not ok:
					break
			if ok:
				return game.world.cell_to_world(Vector2i(x, y))
	return game.world.cell_to_world(game.world.spawn_cell)


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img == null:
		print("SHOT_FAIL ", path, " (nessuna immagine dal viewport)")
		return
	var err: int = img.save_png(path)
	print("SHOT ", path, " ", img.get_width(), "x", img.get_height(), " err=", err,
		" ", _stats(img))


## Statistiche oggettive: un frame vuoto ha 1 solo colore e media ~0.
func _stats(img: Image) -> String:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var colours: Dictionary = {}
	var sum: float = 0.0
	var samples: int = 0
	for y in range(0, h, 3):
		for x in range(0, w, 3):
			var c: Color = img.get_pixel(x, y)
			colours[c.to_rgba32()] = true
			sum += (c.r + c.g + c.b) / 3.0
			samples += 1
	var mean: float = sum / float(maxi(samples, 1))
	return "colori=%d luminanza_media=%.3f" % [colours.size(), mean]
