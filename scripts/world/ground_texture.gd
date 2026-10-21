class_name GroundTexture
extends RefCounted
## Costruisce l'immagine del suolo (ImageTexture generata a runtime) a partire
## dalla griglia logica. Zero texture importate: solo fill_rect su un'Image.
##
## Il dettaglio cosmetico usa uno stream RNG dedicato (id 7) derivato dal seed:
## non tocca né il layout né le entità.

const PALETTE: Dictionary = {
	WorldData.Terrain.WATER: Color(0.086, 0.137, 0.176),
	WorldData.Terrain.SAND: Color(0.376, 0.345, 0.278),
	WorldData.Terrain.DIRT: Color(0.259, 0.212, 0.165),
	WorldData.Terrain.GRASS: Color(0.204, 0.259, 0.180),
	WorldData.Terrain.MOSS: Color(0.149, 0.220, 0.173),
	WorldData.Terrain.STONE: Color(0.290, 0.290, 0.306),
	WorldData.Terrain.RUBBLE: Color(0.235, 0.227, 0.235),
}

const WATER_SHALLOW: Color = Color(0.129, 0.196, 0.235)
const GRASS_TUFT: Color = Color(0.271, 0.337, 0.216)
const MOSS_SPECK: Color = Color(0.106, 0.169, 0.137)
const DIRT_PEBBLE: Color = Color(0.322, 0.271, 0.208)
const STONE_CRACK: Color = Color(0.216, 0.216, 0.239)
const FLOWER_AMBER: Color = Color(0.855, 0.647, 0.290)
const FLOWER_CYAN: Color = Color(0.373, 0.741, 0.776)
const TILE: int = WorldData.TILE


static func build(world: WorldData, world_seed: int, stream_id: int = 7) -> ImageTexture:
	var rng := WorldGenerator.make_stream(world_seed, stream_id)
	var px_w: int = world.width * TILE
	var px_h: int = world.height * TILE
	var img := Image.create_empty(px_w, px_h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.043, 0.047, 0.055))
	for y in world.height:
		for x in world.width:
			var cell := Vector2i(x, y)
			var t: int = world.terrain_at(cell)
			var base: Color = PALETTE[t]
			var shade: float = rng.randf_range(-0.022, 0.022)
			var col := Color(clampf(base.r + shade, 0.0, 1.0), clampf(base.g + shade, 0.0, 1.0), clampf(base.b + shade, 0.0, 1.0))
			if t == WorldData.Terrain.WATER and _touches_land(world, cell):
				col = WATER_SHALLOW.lerp(col, rng.randf_range(0.0, 0.35))
			var ox: int = x * TILE
			var oy: int = y * TILE
			img.fill_rect(Rect2i(ox, oy, TILE, TILE), col)
			_detail(img, rng, cell, t, ox, oy)
	# Bordi: una linea più scura dove il terreno cambia (lettura delle forme).
	for y in world.height:
		for x in world.width:
			var cell := Vector2i(x, y)
			var t: int = world.terrain_at(cell)
			if t == WorldData.Terrain.WATER:
				continue
			var edge_col := Color(0.0, 0.0, 0.0, 0.16)
			if world.terrain_at(cell + Vector2i(0, 1)) != t and world.terrain_at(cell + Vector2i(0, 1)) != WorldData.Terrain.WATER:
				img.fill_rect(Rect2i(x * TILE, y * TILE + TILE - 1, TILE, 1), edge_col)
			if world.terrain_at(cell + Vector2i(1, 0)) != t and world.terrain_at(cell + Vector2i(1, 0)) != WorldData.Terrain.WATER:
				img.fill_rect(Rect2i(x * TILE + TILE - 1, y * TILE, 1, TILE), edge_col)
			if world.terrain_at(cell + Vector2i(0, -1)) == WorldData.Terrain.WATER:
				img.fill_rect(Rect2i(x * TILE, y * TILE, TILE, 2), Color(0.72, 0.80, 0.80, 0.10))
	var tex := ImageTexture.create_from_image(img)
	return tex


static func _touches_land(world: WorldData, cell: Vector2i) -> bool:
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for d in dirs:
		if world.terrain_at(cell + d) != WorldData.Terrain.WATER:
			return true
	return false


static func _detail(img: Image, rng: RandomNumberGenerator, cell: Vector2i, t: int, ox: int, oy: int) -> void:
	match t:
		WorldData.Terrain.GRASS:
			var tufts: int = rng.randi_range(1, 3)
			for i in tufts:
				var tx: int = ox + rng.randi_range(2, TILE - 3)
				var ty: int = oy + rng.randi_range(3, TILE - 3)
				img.fill_rect(Rect2i(tx, ty, 1, 2), GRASS_TUFT)
			if rng.randf() < 0.03:
				var fx: int = ox + rng.randi_range(4, TILE - 5)
				var fy: int = oy + rng.randi_range(4, TILE - 5)
				img.fill_rect(Rect2i(fx, fy, 2, 2), FLOWER_AMBER if rng.randf() < 0.5 else FLOWER_CYAN)
		WorldData.Terrain.MOSS:
			var specks: int = rng.randi_range(2, 4)
			for i in specks:
				img.fill_rect(Rect2i(ox + rng.randi_range(1, TILE - 2), oy + rng.randi_range(1, TILE - 2), 1, 1), MOSS_SPECK)
			if rng.randf() < 0.05:
				img.fill_rect(Rect2i(ox + rng.randi_range(3, TILE - 4), oy + rng.randi_range(3, TILE - 4), 2, 1), GRASS_TUFT)
		WorldData.Terrain.DIRT:
			var pebbles: int = rng.randi_range(1, 3)
			for i in pebbles:
				img.fill_rect(Rect2i(ox + rng.randi_range(2, TILE - 3), oy + rng.randi_range(2, TILE - 3), 2, 1), DIRT_PEBBLE)
		WorldData.Terrain.STONE:
			if rng.randf() < 0.55:
				var sx: int = ox + rng.randi_range(2, TILE - 3)
				var sy: int = oy + rng.randi_range(2, TILE - 4)
				img.fill_rect(Rect2i(sx, sy, 1, 3), STONE_CRACK)
			if rng.randf() < 0.25:
				img.fill_rect(Rect2i(ox + rng.randi_range(2, TILE - 4), oy + rng.randi_range(2, TILE - 4), 2, 2), Color(0.36, 0.36, 0.38))
		WorldData.Terrain.SAND:
			if rng.randf() < 0.5:
				img.fill_rect(Rect2i(ox + rng.randi_range(2, TILE - 3), oy + rng.randi_range(2, TILE - 3), 2, 1), Color(0.42, 0.39, 0.31))
		WorldData.Terrain.RUBBLE:
			var debris: int = rng.randi_range(1, 3)
			for i in debris:
				img.fill_rect(Rect2i(ox + rng.randi_range(1, TILE - 3), oy + rng.randi_range(1, TILE - 3), 2, 2), Color(0.31, 0.30, 0.32))
		_:
			pass
