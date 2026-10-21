class_name WorldGenerator
extends RefCounted
## Generatore procedurale deterministico di Echoes of Ash.
##
## Algoritmo coerente (non rumore sparso):
##   1. campo di elevazione e umidità (value noise multilivello, seme esplicito)
##   2. classificazione del terreno con caduta ai bordi (isola costiera)
##   3. punti d'interesse + sentieri con BFS su terraferma
##   4. rovine costruite a mano su griglia attorno ai POI
##   5. props decorativi con spaziatura minima e rispetto dei sentieri
##   6. ancore di nemici / oggetti su celle calpestabili e lontane dallo spawn
##
## Ogni fase ha il proprio RandomNumberGenerator derivato dal seed: cambiare la
## decorazione (stream 2) non può alterare il layout dei sentieri (stream 1) né
## le posizioni dei nemici (stream 3).

const STREAM_TERRAIN: int = 1
const STREAM_DECOR: int = 2
const STREAM_ENTITY: int = 3
const STREAM_LOOT: int = 4


## Stream indipendente e riproducibile da (seed, id).
static func make_stream(world_seed: int, stream_id: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	var v: int = (world_seed * 6364136223846793005 + stream_id * 1442695040888963407) & 0x7FFFFFFFFFFFFFFF
	rng.seed = v
	return rng


static func generate(world_seed: int, w: int = 96, h: int = 96) -> WorldData:
	var gen := WorldGenerator.new(world_seed, w, h)
	return gen.build()


var data: WorldData
var rng_t: RandomNumberGenerator
var rng_d: RandomNumberGenerator
var rng_e: RandomNumberGenerator
var rng_l: RandomNumberGenerator
## Celle già occupate da qualsiasi prop (anche non solido).
var occupied: Dictionary = {}
## Celle troppo vicine a un prop solido (spaziatura minima).
var crowded: Dictionary = {}


func _init(world_seed: int, w: int = 96, h: int = 96) -> void:
	data = WorldData.new(w, h, world_seed)
	rng_t = make_stream(world_seed, STREAM_TERRAIN)
	rng_d = make_stream(world_seed, STREAM_DECOR)
	rng_e = make_stream(world_seed, STREAM_ENTITY)
	rng_l = make_stream(world_seed, STREAM_LOOT)


func build() -> WorldData:
	_build_terrain()
	_find_spawn()
	_place_pois()
	_carve_paths()
	_build_ruins()
	_place_interactable_anchors()
	_place_props()
	_place_entities()
	return data


# --- 1. terreno -------------------------------------------------------------

func _build_terrain() -> void:
	var w: int = data.width
	var h: int = data.height
	var e1 := _noise(rng_t, w, h, 18)
	var e2 := _noise(rng_t, w, h, 9)
	var e3 := _noise(rng_t, w, h, 4)
	var m1 := _noise(rng_t, w, h, 14)
	var m2 := _noise(rng_t, w, h, 7)
	var half: float = float(mini(w, h)) * 0.5

	var elevation := PackedFloat32Array()
	elevation.resize(w * h)
	var moisture := PackedFloat32Array()
	moisture.resize(w * h)
	for y in h:
		for x in w:
			var i: int = y * w + x
			var e: float = e1[i] * 0.55 + e2[i] * 0.30 + e3[i] * 0.15
			# Caduta ai bordi: il mondo è un'isola, l'acqua fa da confine naturale.
			var edge: float = minf(minf(float(x), float(w - 1 - x)), minf(float(y), float(h - 1 - y)))
			var falloff: float = clampf(edge / (half * 0.85), 0.0, 1.0)
			elevation[i] = e * (0.35 + 0.65 * falloff)
			moisture[i] = m1[i] * 0.65 + m2[i] * 0.35

	# Soglie a percentile: la composizione del mondo resta stabile su ogni seed.
	var water_thr: float = _percentile(elevation, 0.22)
	var stone_thr: float = _percentile(elevation, 0.925)
	var moss_thr: float = _percentile(moisture, 0.640)
	for i in w * h:
		var elevation_i: float = elevation[i]
		var t: int = WorldData.Terrain.GRASS
		if elevation_i < water_thr:
			t = WorldData.Terrain.WATER
		elif elevation_i < water_thr + (stone_thr - water_thr) * 0.055:
			t = WorldData.Terrain.SAND
		elif elevation_i > stone_thr:
			t = WorldData.Terrain.STONE
		elif moisture[i] > moss_thr:
			t = WorldData.Terrain.MOSS
		data.cells[i] = t


## Valore al quantile `q` (0..1) di una copia ordinata dell'array.
static func _percentile(values: PackedFloat32Array, q: float) -> float:
	if values.is_empty():
		return 0.0
	var copy := values.duplicate()
	copy.sort()
	var i: int = clampi(int(copy.size() * q), 0, copy.size() - 1)
	return copy[i]


## Value noise bilineare su reticolo casuale, con smoothing cubico.
func _noise(rng: RandomNumberGenerator, w: int, h: int, cell: int) -> PackedFloat32Array:
	var gw: int = int(ceil(float(w) / float(cell))) + 2
	var gh: int = int(ceil(float(h) / float(cell))) + 2
	var lat := PackedFloat32Array()
	lat.resize(gw * gh)
	for i in lat.size():
		lat[i] = rng.randf()
	var out := PackedFloat32Array()
	out.resize(w * h)
	for y in h:
		var fy: float = float(y) / float(cell)
		var y0: int = int(fy)
		var y1: int = mini(y0 + 1, gh - 1)
		var ty: float = fy - float(y0)
		ty = ty * ty * (3.0 - 2.0 * ty)
		for x in w:
			var fx: float = float(x) / float(cell)
			var x0: int = int(fx)
			var x1: int = mini(x0 + 1, gw - 1)
			var tx: float = fx - float(x0)
			tx = tx * tx * (3.0 - 2.0 * tx)
			var a: float = lerpf(lat[y0 * gw + x0], lat[y0 * gw + x1], tx)
			var b: float = lerpf(lat[y1 * gw + x0], lat[y1 * gw + x1], tx)
			out[y * w + x] = lerpf(a, b, ty)
	return out


# --- 2. spawn e POI ---------------------------------------------------------

func _find_spawn() -> void:
	var center := Vector2i(data.width / 2, data.height / 2)
	var found := _find_land_near(center, 4, 26)
	if found.x < 0:
		found = _force_land(center, 5)
	data.spawn_cell = found
	# Raddoppia la sicurezza: nessun prop nel raggio di 5 celle dallo spawn.
	for dy in range(-5, 6):
		for dx in range(-5, 6):
			var c: Vector2i = found + Vector2i(dx, dy)
			if not data.in_bounds(c):
				continue
			if data.terrain_at(c) == WorldData.Terrain.WATER:
				data.set_terrain(c, WorldData.Terrain.SAND)
			if data.terrain_at(c) == WorldData.Terrain.STONE:
				data.set_terrain(c, WorldData.Terrain.GRASS)
			occupied[c] = true


func _place_pois() -> void:
	var anchors: Array[Vector2i] = [
		Vector2i(int(data.width * 0.26), int(data.height * 0.28)),
		Vector2i(int(data.width * 0.74), int(data.height * 0.24)),
		Vector2i(int(data.width * 0.28), int(data.height * 0.74)),
		Vector2i(int(data.width * 0.70), int(data.height * 0.68)),
	]
	for a in anchors:
		var c := _find_land_near(a, 3, 22)
		if c.x < 0:
			c = _force_land(a, 4)
		if data.poi.size() > 0 and c == data.poi[data.poi.size() - 1]:
			c = data.nearest_walkable(c + Vector2i(2, 2), 8)
		data.poi.append(c)


func _find_land_near(target: Vector2i, clearance: int, max_radius: int) -> Vector2i:
	for radius in range(0, max_radius + 1):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if radius > 0 and absi(dx) != radius and absi(dy) != radius:
					continue
				var c: Vector2i = target + Vector2i(dx, dy)
				if _area_is_land(c, clearance):
					return c
	return Vector2i(-1, -1)


func _area_is_land(c: Vector2i, clearance: int) -> bool:
	for dy in range(-clearance, clearance + 1):
		for dx in range(-clearance, clearance + 1):
			var n: Vector2i = c + Vector2i(dx, dy)
			if not data.in_bounds(n):
				return false
			if data.terrain_at(n) == WorldData.Terrain.WATER:
				return false
	return true


func _force_land(center: Vector2i, radius: int) -> Vector2i:
	center = Vector2i(clampi(center.x, radius + 1, data.width - radius - 2), clampi(center.y, radius + 1, data.height - radius - 2))
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var c: Vector2i = center + Vector2i(dx, dy)
			if not data.in_bounds(c):
				continue
			if data.terrain_at(c) == WorldData.Terrain.WATER:
				data.set_terrain(c, WorldData.Terrain.GRASS)
			data.blockers[data.idx(c)] = 0
	return center


# --- 3. sentieri ------------------------------------------------------------

func _carve_paths() -> void:
	var chain: Array[Vector2i] = [data.spawn_cell]
	for p in data.poi:
		chain.append(p)
	for i in range(1, chain.size()):
		var path := _bfs_path(chain[i - 1], chain[i])
		if path.is_empty():
			path = _straight_path(chain[i - 1], chain[i])
		for c in path:
			if not data.in_bounds(c):
				continue
			var t: int = data.terrain_at(c)
			if t != WorldData.Terrain.WATER:
				data.set_terrain(c, WorldData.Terrain.DIRT)
				data.path_cells.append(c)
				if rng_t.randf() < 0.28:
					var side := Vector2i(1, 0) if rng_t.randf() < 0.5 else Vector2i(0, 1)
					var wc: Vector2i = c + side
					if data.in_bounds(wc) and data.terrain_at(wc) != WorldData.Terrain.WATER:
						data.set_terrain(wc, WorldData.Terrain.DIRT)
						data.path_cells.append(wc)


## Percorso minimo su terraferma (celle d'acqua bloccate).
func _bfs_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not data.in_bounds(start) or not data.in_bounds(goal):
		return out
	var total: int = data.width * data.height
	var prev := PackedInt32Array()
	prev.resize(total)
	prev.fill(-1)
	var seen := PackedByteArray()
	seen.resize(total)
	seen.fill(0)
	var queue := PackedInt32Array()
	queue.append(data.idx(start))
	seen[data.idx(start)] = 1
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var head: int = 0
	var goal_idx: int = data.idx(goal)
	while head < queue.size():
		var cur: int = queue[head]
		head += 1
		if cur == goal_idx:
			break
		var cx: int = cur % data.width
		var cy: int = cur / data.width
		for d in dirs:
			var nx: int = cx + d.x
			var ny: int = cy + d.y
			if nx < 0 or ny < 0 or nx >= data.width or ny >= data.height:
				continue
			var ni: int = ny * data.width + nx
			if seen[ni] == 1:
				continue
			if data.cells[ni] == WorldData.Terrain.WATER:
				continue
			seen[ni] = 1
			prev[ni] = cur
			queue.append(ni)
	if seen[goal_idx] == 0:
		return out
	var walk: int = goal_idx
	while walk != -1:
		out.append(Vector2i(walk % data.width, walk / data.width))
		if walk == data.idx(start):
			break
		walk = prev[walk]
	out.reverse()
	return out


## Fallback: attraversamento rettilineo che trasforma l'acqua in un guado sabbioso.
func _straight_path(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var steps: int = maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in range(steps + 1):
		var t: float = float(i) / float(maxi(steps, 1))
		var c := Vector2i(roundi(lerpf(float(a.x), float(b.x), t)), roundi(lerpf(float(a.y), float(b.y), t)))
		if data.in_bounds(c) and data.terrain_at(c) == WorldData.Terrain.WATER:
			data.set_terrain(c, WorldData.Terrain.SAND)
		out.append(c)
	return out


# --- 4. rovine --------------------------------------------------------------

func _build_ruins() -> void:
	var ruin_pois: Array[Vector2i] = []
	if data.poi.size() > 0:
		ruin_pois.append(data.poi[0])
	if data.poi.size() > 2:
		ruin_pois.append(data.poi[2])
	for center in ruin_pois:
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				var c: Vector2i = center + Vector2i(dx, dy)
				if not data.in_bounds(c):
					continue
				var perimeter: bool = absi(dx) == 3 or absi(dy) == 3
				if perimeter:
					if data.terrain_at(c) == WorldData.Terrain.DIRT or data.terrain_at(c) == WorldData.Terrain.WATER:
						continue
					if rng_t.randf() < 0.80:
						data.set_terrain(c, WorldData.Terrain.RUBBLE)
						_place_solid(c, "wall", 9.0)
				else:
					data.set_terrain(c, WorldData.Terrain.RUBBLE)
		# Il centro resta libero: è il punto d'incontro delle rovine.
		if data.in_bounds(center):
			occupied.erase(center)


# --- 5. ancore delle interazioni -------------------------------------------

func _place_interactable_anchors() -> void:
	# L'NPC vive nel secondo punto d'interesse, i bracieri allo spawn e al quarto.
	if data.poi.size() > 1:
		data.npc_cell = data.nearest_walkable(data.poi[1], 6)
	else:
		data.npc_cell = data.nearest_walkable(data.spawn_cell + Vector2i(3, 0), 6)
	var spawn_brazier := data.nearest_walkable(data.spawn_cell + Vector2i(3, 2), 6)
	if spawn_brazier == data.spawn_cell:
		spawn_brazier = data.nearest_walkable(data.spawn_cell + Vector2i(-3, 2), 6)
	data.brazier_cells.append(spawn_brazier)
	if data.poi.size() > 3:
		data.brazier_cells.append(data.nearest_walkable(data.poi[3], 6))
	for c in [data.npc_cell] + data.brazier_cells:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				occupied[c + Vector2i(dx, dy)] = true


# --- 6. props ---------------------------------------------------------------

func _place_props() -> void:
	for y in data.height:
		for x in data.width:
			var c := Vector2i(x, y)
			var t: int = data.terrain_at(c)
			if t == WorldData.Terrain.WATER:
				continue
			if occupied.has(c) or crowded.has(c):
				continue
			var r: float = rng_d.randf()
			match t:
				WorldData.Terrain.MOSS:
					if r < 0.150:
						_place_solid(c, "tree", 6.5)
					elif r < 0.230:
						_place_prop(c, "shrub", false, 0.0)
					elif r < 0.260:
						_place_prop(c, "mushroom", false, 0.0)
				WorldData.Terrain.GRASS:
					if r < 0.045:
						_place_solid(c, "tree", 6.5)
					elif r < 0.060:
						_place_solid(c, "rock", 6.0)
					elif r < 0.115:
						_place_prop(c, "shrub", false, 0.0)
				WorldData.Terrain.STONE:
					if r < 0.150:
						_place_solid(c, "rock", 7.0)
					elif r < 0.220:
						_place_prop(c, "pebbles", false, 0.0)
				WorldData.Terrain.RUBBLE:
					if r < 0.050:
						_place_prop(c, "pebbles", false, 0.0)
				WorldData.Terrain.SAND:
					if r < 0.020:
						_place_prop(c, "pebbles", false, 0.0)
				_:
					pass


func _place_solid(c: Vector2i, type: String, radius: float) -> void:
	if not _place_prop(c, type, true, radius):
		return
	data.mark_blocked(c)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			crowded[c + Vector2i(dx, dy)] = true


func _place_prop(c: Vector2i, type: String, solid: bool, radius: float) -> bool:
	if not data.in_bounds(c) or occupied.has(c):
		return false
	if data.terrain_at(c) == WorldData.Terrain.WATER:
		return false
	occupied[c] = true
	data.props.append({
		"type": type,
		"cell": c,
		"solid": solid,
		"radius": radius,
		"variant": rng_d.randi_range(0, 9999),
	})
	return true


# --- 7. entità --------------------------------------------------------------

func _place_entities() -> void:
	_place_enemies("crawler", 17, 11)
	_place_enemies("warden", 7, 15)
	_place_items(18, 3)


func _place_enemies(type: String, count: int, min_dist: int) -> void:
	var placed: int = 0
	var attempts: int = 0
	while placed < count and attempts < 6000:
		attempts += 1
		var c := Vector2i(rng_e.randi_range(2, data.width - 3), rng_e.randi_range(2, data.height - 3))
		if not data.is_walkable_cell(c):
			continue
		if occupied.has(c):
			continue
		if _chebyshev(c, data.spawn_cell) < min_dist:
			continue
		var dup: bool = false
		for e in data.enemy_spawns:
			if e["cell"] == c:
				dup = true
				break
		if dup:
			continue
		data.enemy_spawns.append({"type": type, "cell": c})
		placed += 1


func _place_items(count: int, min_dist: int) -> void:
	var placed: int = 0
	var attempts: int = 0
	while placed < count and attempts < 6000:
		attempts += 1
		var c := Vector2i(rng_l.randi_range(2, data.width - 3), rng_l.randi_range(2, data.height - 3))
		if not data.is_walkable_cell(c):
			continue
		if occupied.has(c):
			continue
		if _chebyshev(c, data.spawn_cell) < min_dist:
			continue
		var roll: float = rng_l.randf()
		var item: String = "ash_shard"
		if roll > 0.86:
			item = "ember_charm"
		elif roll > 0.58:
			item = "vial_of_sap"
		data.item_spawns.append({"item": item, "cell": c})
		occupied[c] = true
		placed += 1


func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))
