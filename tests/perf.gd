extends SceneTree
## Sonda di prestazioni: misura i tempi reali riportati dal motore (Performance),
## il numero di nodi e il costo di generazione del mondo. Non è un test pass/fail:
## produce numeri da citare nel README.
##
## Uso: ... --headless --script res://tests/perf.gd


func _initialize() -> void:
	_main()


func _main() -> void:
	var gen_t0: int = Time.get_ticks_usec()
	var world: WorldData = WorldGenerator.generate(20261019)
	var gen_us: int = Time.get_ticks_usec() - gen_t0
	var img_t0: int = Time.get_ticks_usec()
	var tex: ImageTexture = GroundTexture.build(world, 20261019)
	var img_us: int = Time.get_ticks_usec() - img_t0

	var packed: PackedScene = load("res://scenes/main.tscn")
	var game: Game = packed.instantiate() as Game
	root.add_child(game)
	await process_frame
	await physics_frame

	# 120 frame per stabilizzare le medie
	for i in 120:
		await physics_frame
	var process_sum: float = 0.0
	var physics_sum: float = 0.0
	var wall_t0: int = Time.get_ticks_usec()
	for i in 120:
		await physics_frame
		process_sum += float(Performance.get_monitor(Performance.TIME_PROCESS))
		physics_sum += float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))
	var wall_ms: float = float(Time.get_ticks_usec() - wall_t0) / 120.0 / 1000.0
	print("=== Echoes of Ash — prestazioni (headless, CPU) ===")
	print("generazione mondo: %.1f ms" % (float(gen_us) / 1000.0))
	print("texture suolo %dx%d: %.1f ms" % [world.width * 16, world.height * 16, float(img_us) / 1000.0])
	print("nodi in scena: %d" % int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	print("oggetti (Object): %d" % int(Performance.get_monitor(Performance.OBJECT_COUNT)))
	print("memoria statica: %.1f MB" % (float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0))
	print("tempo _process medio: %.3f ms/frame" % (process_sum / 120.0 * 1000.0))
	print("tempo fisica medio:   %.3f ms/frame" % (physics_sum / 120.0 * 1000.0))
	print("frame reale (wall clock): %.2f ms -> %.1f fps" % [wall_ms, 1000.0 / maxf(wall_ms, 0.001)])
	print("nemici vivi: %d, pickup: %d" % [game.alive_enemy_count(), get_nodes_in_group("pickups").size()])
	print("draw call (headless, non significative): %d" % int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))

	# stress: 14 nemici in agguato attorno al giocatore (carico AI massimo locale)
	for i in 14:
		var ang: float = TAU * float(i) / 14.0
		var kind: String = "crawler" if i % 2 == 0 else "warden"
		game.spawn_enemy_at(kind, game.player.global_position + Vector2(cos(ang), sin(ang)) * 70.0)
	for i in 30:
		await physics_frame
	var stress_t0: int = Time.get_ticks_usec()
	for i in 120:
		await physics_frame
	var stress_ms: float = float(Time.get_ticks_usec() - stress_t0) / 120.0 / 1000.0
	print("stress %d nemici vicini: %.2f ms/frame (%.1f fps)" % [game.alive_enemy_count(), stress_ms, 1000.0 / maxf(stress_ms, 0.001)])
	quit(0)
