extends SceneTree
## Verifica VISIVA falsificabile: rendering reale (eseguibile GUI, non headless).
##
## Metodo: si cattura il viewport due volte, nascondendo un solo elemento, e si
## contano i pixel che cambiano. Se un elemento non viene disegnato il diff è 0.
## Copre: giocatore, due tipi di nemico, HUD, nebbia, fendente, ciclo giorno/notte.
## Esce 0 se tutti i controlli passano, 1 altrimenti.

var _pass: int = 0
var _fail: int = 0
var _lines: Array[String] = []
var game: Game = null
var _center: Vector2i = Vector2i.ZERO


func _initialize() -> void:
	_main()


func _check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		_pass += 1
		_lines.append("  PASS  %s%s" % [name, ("  [%s]" % detail) if detail != "" else ""])
	else:
		_fail += 1
		_lines.append("  FAIL  %s%s" % [name, ("  [%s]" % detail) if detail != "" else ""])


func _main() -> void:
	_lines.append("=== Echoes of Ash — verifica visiva (rendering reale) ===")
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		_check("scena caricata", false)
		_finish()
		return
	game = packed.instantiate() as Game
	root.add_child(game)
	await process_frame
	await physics_frame
	# condizioni stabili: tinta fissa, niente drift di nebbia/acqua nei confronti A/B
	game.day_night.frozen = true
	game.day_night.time_of_day = 0.45
	game.day_night.color = game.day_night.sample(0.45)
	game.fog.visible = false
	game.water.visible = false
	for e in game.enemies:
		if is_instance_valid(e):
			e.process_mode = Node.PROCESS_MODE_DISABLED
	game.player.global_position = game.world.cell_to_world(game.world.spawn_cell)
	game.player.velocity = Vector2.ZERO
	game.player.camera.reset_smoothing()
	game.player.invuln = 0.0
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw

	var screen_pos: Vector2 = game.player.get_global_transform_with_canvas().origin
	var base: Image = await _grab()
	var tex_w: int = base.get_width()
	var tex_h: int = base.get_height()
	var scale: float = float(tex_w) / 480.0
	_center = Vector2i(int(screen_pos.x * scale), int(screen_pos.y * scale))
	if _center.x < 0 or _center.y < 0 or _center.x >= tex_w or _center.y >= tex_h:
		_center = Vector2i(tex_w / 2, tex_h / 2)
	_lines.append("  posizione schermo giocatore: %s -> centro %s (immagine %dx%d)" % [str(screen_pos), str(_center), tex_w, tex_h])
	var region := Rect2i(_center - Vector2i(70, 70), Vector2i(140, 140))

	_check("il viewport produce un'immagine", base != null and base.get_width() == 480,
		"%dx%d" % [base.get_width() if base else 0, base.get_height() if base else 0])

	# 1. giocatore disegnato: pixel ciano-firma (trim/occhi) presenti solo se visibile.
	#    Spengo la luce additiva per non falsare i colori della silhouette.
	game.lights.visible = false
	await _frames(2)
	var base_clean: Image = await _grab()
	game.player.visible = false
	await _frames(3)
	var no_player: Image = await _grab()
	game.player.visible = true
	game.lights.visible = true
	await _frames(3)
	var cyan_visible: int = _count_cyan(base_clean, region)
	var cyan_hidden: int = _count_cyan(no_player, region)
	_check("il giocatore è effettivamente disegnato",
		cyan_visible >= 10 and cyan_hidden == 0,
		"pixel ciano visibile=%d nascosto=%d" % [cyan_visible, cyan_hidden])

	# 2. nemici disegnati (uno per tipo, accanto al giocatore)
	var crawler: Enemy = game.spawn_enemy_at("crawler", game.player.global_position + Vector2(22, 0))
	var warden: Enemy = game.spawn_enemy_at("warden", game.player.global_position + Vector2(-30, 0))
	await _frames(4)
	var with_enemies: Image = await _grab()
	crawler.visible = false
	warden.visible = false
	await _frames(3)
	var no_enemies: Image = await _grab()
	crawler.visible = true
	warden.visible = true
	await _frames(3)
	var d_enemies: int = _diff(with_enemies, no_enemies, region)
	_check("i due tipi di nemico sono disegnati", d_enemies > 100, "%d pixel diversi" % d_enemies)

	# 3. HUD disegnata
	var with_hud: Image = await _grab()
	game.hud.ui.visible = false
	await _frames(3)
	var no_hud: Image = await _grab()
	game.hud.ui.visible = true
	await _frames(3)
	var d_hud: int = _diff(with_hud, no_hud, Rect2i(0, 0, 180, 60))
	_check("la HUD è disegnata (barre e testi)", d_hud > 80, "%d pixel diversi" % d_hud)

	# 4. nebbia
	var fog_off: Image = await _grab()
	game.fog.visible = true
	await _frames(3)
	var fog_on: Image = await _grab()
	var d_fog: int = _diff(fog_off, fog_on, Rect2i(0, 0, fog_on.get_width(), fog_on.get_height()))
	_check("la nebbia aggiunge pixel di atmosfera", d_fog > 500, "%d pixel diversi" % d_fog)
	game.fog.visible = false

	# 5. fendente dell'attacco
	await _frames(2)
	var before_slash: Image = await _grab()
	game.player.attack_cooldown = 0.0
	game.player.try_attack(Vector2.RIGHT)
	await _frames(2)
	var during_slash: Image = await _grab()
	await _frames(2)
	var d_slash: int = _diff(before_slash, during_slash, region)
	_check("il fendente dell'attacco è visibile", d_slash > 40, "%d pixel diversi" % d_slash)

	# 6. giorno/notte: la notte è più scura
	game.day_night.time_of_day = 0.92
	game.day_night.color = game.day_night.sample(0.92)
	await _frames(4)
	var night: Image = await _grab()
	var day_lum: float = _luminance(base, region)
	var night_lum: float = _luminance(night, region)
	_check("il ciclo giorno/notte scurisce la scena", night_lum < day_lum * 0.92,
		"giorno=%.3f notte=%.3f" % [day_lum, night_lum])
	game.day_night.time_of_day = 0.45
	game.day_night.color = game.day_night.sample(0.45)

	# 7. acqua animata: due frame consecutivi su una zona costiera
	var shore: Vector2i = _find_shore_cell()
	if shore.x >= 0:
		game.player.global_position = game.world.cell_to_world(shore)
		game.player.camera.reset_smoothing()
		game.water.visible = true
		await _frames(6)
		var w1: Image = await _grab()
		await create_timer(0.45).timeout
		var w2: Image = await _grab()
		var d_water: int = _diff(w1, w2, Rect2i(0, 0, w1.get_width(), w1.get_height()))
		_check("l'acqua è animata (frame diversi nel tempo)", d_water > 100, "%d pixel diversi" % d_water)
	else:
		_check("l'acqua è animata (frame diversi nel tempo)", false, "nessuna costa trovata")
	game.water.visible = false

	var img_path: String = "res://out/shot_visual_check.png"
	var full: Image = await _grab_full()
	if full != null:
		full.save_png(img_path)
	_lines.append("  screenshot: " + img_path)
	_finish()


func _frames(n: int) -> void:
	for i in n:
		await process_frame
	await RenderingServer.frame_post_draw


func _grab() -> Image:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img == null:
		return null
	# riporto alla risoluzione interna: i confronti sono in pixel di gioco
	img.resize(480, 270, Image.INTERPOLATE_NEAREST)
	return img


func _grab_full() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _diff(a: Image, b: Image, rect: Rect2i, eps: float = 0.05) -> int:
	if a == null or b == null:
		return 0
	var count: int = 0
	var x0: int = clampi(rect.position.x, 0, a.get_width() - 1)
	var y0: int = clampi(rect.position.y, 0, a.get_height() - 1)
	var x1: int = clampi(rect.position.x + rect.size.x, 0, a.get_width())
	var y1: int = clampi(rect.position.y + rect.size.y, 0, a.get_height())
	for y in range(y0, y1, 2):
		for x in range(x0, x1, 2):
			var ca: Color = a.get_pixel(x, y)
			var cb: Color = b.get_pixel(x, y)
			if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > eps:
				count += 1
	return count


## Pixel "ciano-firma": il trim e gli occhi del giocatore. L'acqua profonda è
## troppo scura per superare la soglia di luminanza.
func _count_cyan(img: Image, rect: Rect2i) -> int:
	var count: int = 0
	for y in range(maxi(rect.position.y, 0), mini(rect.position.y + rect.size.y, img.get_height())):
		for x in range(maxi(rect.position.x, 0), mini(rect.position.x + rect.size.x, img.get_width())):
			var c: Color = img.get_pixel(x, y)
			if c.b > c.r + 0.12 and c.g > c.r + 0.10 and c.b > 0.28 and c.g > 0.30:
				count += 1
	return count


func _luminance(img: Image, rect: Rect2i) -> float:
	var sum: float = 0.0
	var n: int = 0
	for y in range(maxi(rect.position.y, 0), mini(rect.position.y + rect.size.y, img.get_height()), 3):
		for x in range(maxi(rect.position.x, 0), mini(rect.position.x + rect.size.x, img.get_width()), 3):
			sum += img.get_pixel(x, y).get_luminance()
			n += 1
	return sum / float(maxi(n, 1))


func _find_shore_cell() -> Vector2i:
	for y in range(2, game.world.height - 2):
		for x in range(2, game.world.width - 2):
			var c := Vector2i(x, y)
			if game.world.terrain_at(c) != WorldData.Terrain.WATER:
				continue
			if game.world.terrain_at(c + Vector2i(1, 0)) != WorldData.Terrain.WATER and game.world.is_walkable_cell(c + Vector2i(2, 0)):
				return c + Vector2i(2, 0)
	return Vector2i(-1, -1)


func _finish() -> void:
	_lines.append("--- %d passati, %d falliti ---" % [_pass, _fail])
	for l in _lines:
		print(l)
	quit(0 if _fail == 0 else 1)
