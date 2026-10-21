extends SceneTree
## Test headless del generatore di mondo. Esce 0 se tutto passa, 1 altrimenti.
##
## Uso:
##   Godot_v4.7.2-stable_win64_console.exe --headless \
##     --path projects/echoes-of-ash --script res://tests/test_world.gd

var _pass: int = 0
var _fail: int = 0
var _lines: Array[String] = []


func _initialize() -> void:
	_main()


func _check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		_pass += 1
		_lines.append("  PASS  %s%s" % [name, ("  [%s]" % detail) if detail != "" else ""])
	else:
		_fail += 1
		_lines.append("  FAIL  %s%s" % [name, ("  [%s]" % detail) if detail != "" else ""])


## Flood fill dai piedi dello spawn: quante celle calpestabili sono raggiungibili.
func _reachable(world: WorldData, from: Vector2i) -> Dictionary:
	var seen: Dictionary = {}
	if not world.is_walkable_cell(from):
		return seen
	var queue: Array[Vector2i] = [from]
	seen[from] = true
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var head: int = 0
	while head < queue.size() and seen.size() < 20000:
		var c: Vector2i = queue[head]
		head += 1
		for d in dirs:
			var n: Vector2i = c + d
			if seen.has(n):
				continue
			if world.is_walkable_cell(n):
				seen[n] = true
				queue.append(n)
	return seen


func _waline(text: String) -> void:
	_lines.append(text)


func _main() -> void:
	_lines.append("=== Echoes of Ash — test del generatore di mondo ===")
	var t0: int = Time.get_ticks_msec()
	var a: WorldData = WorldGenerator.generate(20261019)
	var gen_ms: int = Time.get_ticks_msec() - t0
	var b: WorldData = WorldGenerator.generate(20261019)
	var c: WorldData = WorldGenerator.generate(777001)

	var sa: Dictionary = a.summary()
	_waline("  mondo: %s" % str(sa))
	_waline("  generazione: %d ms (2 mondi)" % gen_ms)

	# --- determinismo -------------------------------------------------------
	_check("stesso seed -> stesso hash di layout", a.layout_hash() == b.layout_hash(),
		"%d vs %d" % [a.layout_hash(), b.layout_hash()])
	_check("stesso seed -> stesse celle di terreno", a.cells == b.cells)
	_check("stesso seed -> stessi nemici", _cells(a.enemy_spawns) == _cells(b.enemy_spawns))
	_check("stesso seed -> stessi oggetti", _cells(a.item_spawns) == _cells(b.item_spawns))
	_check("stesso seed -> stessi props", a.props.size() == b.props.size() and a.props == b.props)
	_check("seed diverso -> hash diverso", a.layout_hash() != c.layout_hash(),
		"%d vs %d" % [a.layout_hash(), c.layout_hash()])

	# --- composizione del terreno ------------------------------------------
	var counts: Dictionary = a.terrain_counts()
	var total: int = a.width * a.height
	var water_ratio: float = float(counts["water"]) / float(total)
	var green_ratio: float = float(int(counts["grass"]) + int(counts["moss"])) / float(total)
	var stone_ratio: float = float(counts["stone"]) / float(total)
	_check("acqua presente (>=3%)", water_ratio >= 0.03, "%.1f%%" % (water_ratio * 100.0))
	_check("prateria/muschio presenti (>=20%)", green_ratio >= 0.20, "%.1f%%" % (green_ratio * 100.0))
	_check("pietra presente (>=2%)", stone_ratio >= 0.02, "%.1f%%" % (stone_ratio * 100.0))
	_check("sentieri tracciati (>=200 celle)", a.path_cells.size() >= 200, "%d celle" % a.path_cells.size())
	_check("rovine presenti (props 'wall' >= 30)", _count_type(a, "wall") >= 30, "%d muri" % _count_type(a, "wall"))

	# --- spawn sicuro -------------------------------------------------------
	_check("spawn calpestabile", a.is_walkable_cell(a.spawn_cell), str(a.spawn_cell))
	var safe: bool = true
	for p in a.props:
		if p["solid"] and (p["cell"] as Vector2i).distance_to(Vector2(a.spawn_cell)) < 4.5:
			safe = false
	_check("area di spawn libera da props solidi (r=4)", safe)
	var spawn_terrain: int = a.terrain_at(a.spawn_cell)
	_check("spawn su terreno asciutto", spawn_terrain != WorldData.Terrain.WATER,
		WorldData.TERRAIN_NAME[spawn_terrain])

	# --- props coerenti -----------------------------------------------------
	var on_water: int = 0
	var unwalkable: int = 0
	for p in a.props:
		var cell: Vector2i = p["cell"]
		if a.terrain_at(cell) == WorldData.Terrain.WATER:
			on_water += 1
		if p["solid"] and a.is_walkable_cell(cell):
			unwalkable += 1
	_check("nessun prop sull'acqua", on_water == 0, "%d" % on_water)
	_check("ogni prop solido blocca la propria cella", unwalkable == 0, "%d non bloccanti" % unwalkable)

	# --- entità -------------------------------------------------------------
	var crawlers: int = 0
	var wardens: int = 0
	var too_close: int = 0
	for e in a.enemy_spawns:
		if e["type"] == "crawler":
			crawlers += 1
		else:
			wardens += 1
		if (e["cell"] as Vector2i).distance_to(Vector2(a.spawn_cell)) < 10.0:
			too_close += 1
	_check("17 crawler generati", crawlers == 17, "%d" % crawlers)
	_check("7 warden generati", wardens == 7, "%d" % wardens)
	_check("nemici lontani dallo spawn (>=10 celle)", too_close == 0, "%d vicini" % too_close)
	_check("18 oggetti sparsi generati", a.item_spawns.size() == 18, "%d" % a.item_spawns.size())

	# --- connettività -------------------------------------------------------
	var reach: Dictionary = _reachable(a, a.spawn_cell)
	var walkable_total: int = 0
	for y in a.height:
		for x in a.width:
			if a.is_walkable_cell(Vector2i(x, y)):
				walkable_total += 1
	var reach_ratio: float = float(reach.size()) / float(maxi(walkable_total, 1))
	_check("area calpestabile connessa dallo spawn (>=70%)", reach_ratio >= 0.70,
		"%.1f%% (%d/%d)" % [reach_ratio * 100.0, reach.size(), walkable_total])
	var unreachable_enemies: int = 0
	for e in a.enemy_spawns:
		if not reach.has(e["cell"]):
			unreachable_enemies += 1
	_check("tutti gli spawn nemici raggiungibili a piedi", unreachable_enemies == 0, "%d isolati" % unreachable_enemies)
	var unreachable_items: int = 0
	for it in a.item_spawns:
		if not reach.has(it["cell"]):
			unreachable_items += 1
	_check("tutti gli oggetti raggiungibili a piedi", unreachable_items == 0, "%d isolati" % unreachable_items)
	_check("NPC raggiungibile", reach.has(a.npc_cell), str(a.npc_cell))
	var braziers_ok: bool = true
	for bc in a.brazier_cells:
		if not reach.has(bc):
			braziers_ok = false
	_check("bracieri raggiungibili", braziers_ok and a.brazier_cells.size() == 2, str(a.brazier_cells))

	# --- robustezza su più seed --------------------------------------------
	var bad: Array[String] = []
	for s in [1, 42, 999, 123456, 987654321]:
		var w: WorldData = WorldGenerator.generate(s)
		var r: Dictionary = _reachable(w, w.spawn_cell)
		var ok: bool = w.is_walkable_cell(w.spawn_cell) and w.enemy_spawns.size() == 24 and r.size() > 500
		if not ok:
			bad.append("seed %d (spawn=%s nemici=%d raggiungibili=%d)" % [s, str(w.spawn_cell), w.enemy_spawns.size(), r.size()])
	_check("5 seed diversi generano mondi validi", bad.is_empty(), ", ".join(bad))

	# --- stream RNG indipendenti -------------------------------------------
	var st1: RandomNumberGenerator = WorldGenerator.make_stream(4242, WorldGenerator.STREAM_TERRAIN)
	var st2: RandomNumberGenerator = WorldGenerator.make_stream(4242, WorldGenerator.STREAM_DECOR)
	var seq1: Array[float] = [st1.randf(), st1.randf(), st1.randf()]
	var seq2: Array[float] = [st2.randf(), st2.randf(), st2.randf()]
	_check("stream di terreno e decorazione sono indipendenti", seq1 != seq2)
	var st3: RandomNumberGenerator = WorldGenerator.make_stream(4242, WorldGenerator.STREAM_TERRAIN)
	var seq3: Array[float] = [st3.randf(), st3.randf(), st3.randf()]
	_check("lo stesso stream è riproducibile", seq1 == seq3)
	var st4: RandomNumberGenerator = WorldGenerator.make_stream(4243, WorldGenerator.STREAM_TERRAIN)
	_check("seed diverso -> stream diverso", st4.randf() != seq1[0])

	_finish()


func _cells(arr: Array[Dictionary]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for e in arr:
		out.append(e["cell"])
	return out


func _count_type(world: WorldData, type: String) -> int:
	var n: int = 0
	for p in world.props:
		if p["type"] == type:
			n += 1
	return n


func _finish() -> void:
	_lines.append("--- %d passati, %d falliti ---" % [_pass, _fail])
	for l in _lines:
		print(l)
	quit(0 if _fail == 0 else 1)
