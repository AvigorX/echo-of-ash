class_name WorldData
extends RefCounted
## Stato *puro* del mondo: griglia di terreno, props, ancore di spawn.
## Non contiene nodi né codice di disegno, quindi è interamente testabile in headless.

enum Terrain { WATER, SAND, DIRT, GRASS, MOSS, STONE, RUBBLE }

const TILE: int = 16

## Nomi leggibili (usati da UI, test e report).
const TERRAIN_NAME: Dictionary = {
	Terrain.WATER: "water",
	Terrain.SAND: "sand",
	Terrain.DIRT: "dirt",
	Terrain.GRASS: "grass",
	Terrain.MOSS: "moss",
	Terrain.STONE: "stone",
	Terrain.RUBBLE: "rubble",
}

var seed: int = 0
var width: int = 96
var height: int = 96
## Un byte per cella: valore di Terrain.
var cells: PackedByteArray = PackedByteArray()
## 1 se un prop solido occupa la cella (blocca il movimento).
var blockers: PackedByteArray = PackedByteArray()
## Props decorativi: {type, cell, solid, variant, radius}
var props: Array[Dictionary] = []
var spawn_cell: Vector2i = Vector2i(48, 48)
## {type, cell}
var enemy_spawns: Array[Dictionary] = []
## {item, cell}
var item_spawns: Array[Dictionary] = []
var poi: Array[Vector2i] = []
var npc_cell: Vector2i = Vector2i(-1, -1)
var brazier_cells: Array[Vector2i] = []
## Celle di sentiero, usate dalla vista per dettagli coerenti.
var path_cells: Array[Vector2i] = []


func _init(p_width: int = 96, p_height: int = 96, p_seed: int = 0) -> void:
	width = p_width
	height = p_height
	seed = p_seed
	cells.resize(width * height)
	blockers.resize(width * height)
	cells.fill(Terrain.GRASS)
	blockers.fill(0)


func idx(cell: Vector2i) -> int:
	return cell.y * width + cell.x


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func terrain_at(cell: Vector2i) -> int:
	if not in_bounds(cell):
		return Terrain.WATER
	return cells[idx(cell)]


func set_terrain(cell: Vector2i, value: int) -> void:
	if in_bounds(cell):
		cells[idx(cell)] = value


func is_water(cell: Vector2i) -> bool:
	return terrain_at(cell) == Terrain.WATER


func is_water_at_pos(pos: Vector2) -> bool:
	return is_water(world_to_cell(pos))


## Impedisce di camminare sull'acqua senza costosi corpi fisici per cella:
## se il punto desiderato è acqua, prova a scivolare lungo un solo asse.
static func resolve_land_position(world: WorldData, prev: Vector2, desired: Vector2, feet_offset: float = -3.0) -> Vector2:
	if not world.is_water_at_pos(desired + Vector2(0, feet_offset)):
		return desired
	var try_x := Vector2(desired.x, prev.y)
	if not world.is_water_at_pos(try_x + Vector2(0, feet_offset)):
		return try_x
	var try_y := Vector2(prev.x, desired.y)
	if not world.is_water_at_pos(try_y + Vector2(0, feet_offset)):
		return try_y
	return prev


## Una cella è calpestabile se è dentro la mappa, non è acqua e nessun prop solido la occupa.
func is_walkable_cell(cell: Vector2i) -> bool:
	return in_bounds(cell) and cells[idx(cell)] != Terrain.WATER and blockers[idx(cell)] == 0


func is_walkable_pos(pos: Vector2) -> bool:
	return is_walkable_cell(world_to_cell(pos))


func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE + TILE * 0.5, cell.y * TILE + TILE * 0.5)


func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos.x / float(TILE))), int(floor(pos.y / float(TILE))))


func world_size() -> Vector2:
	return Vector2(width * TILE, height * TILE)


func mark_blocked(cell: Vector2i) -> void:
	if in_bounds(cell):
		blockers[idx(cell)] = 1


func is_blocked(cell: Vector2i) -> bool:
	return in_bounds(cell) and blockers[idx(cell)] == 1


## Cella calpestabile più vicina a `from` (ricerca a spirale, deterministica).
func nearest_walkable(from: Vector2i, max_radius: int = 12) -> Vector2i:
	if is_walkable_cell(from):
		return from
	for radius in range(1, max_radius + 1):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if absi(dx) != radius and absi(dy) != radius:
					continue
				var c := from + Vector2i(dx, dy)
				if is_walkable_cell(c):
					return c
	return from


## Impronta deterministica del layout (terreno + props + ancore).
## Due mondi con lo stesso seed devono avere lo stesso hash.
func layout_hash() -> int:
	var h: int = 2166136261
	for i in cells.size():
		h = ((h ^ int(cells[i])) * 16777619) & 0xFFFFFFFF
	for i in blockers.size():
		h = ((h ^ (int(blockers[i]) + 7)) * 16777619) & 0xFFFFFFFF
	for p in props:
		var c: Vector2i = p["cell"]
		h = ((h ^ (c.x * 31 + c.y * 17 + 1)) * 16777619) & 0xFFFFFFFF
		h = ((h ^ (int(p["variant"]) + 3)) * 16777619) & 0xFFFFFFFF
		var t: String = p["type"]
		for ch in t.to_utf8_buffer():
			h = ((h ^ int(ch)) * 16777619) & 0xFFFFFFFF
	h = ((h ^ (spawn_cell.x * 131 + spawn_cell.y)) * 16777619) & 0xFFFFFFFF
	for e in enemy_spawns:
		var c: Vector2i = e["cell"]
		h = ((h ^ (c.x * 977 + c.y * 131 + 11)) * 16777619) & 0xFFFFFFFF
	for it in item_spawns:
		var c: Vector2i = it["cell"]
		h = ((h ^ (c.x * 613 + c.y * 71 + 29)) * 16777619) & 0xFFFFFFFF
	return h & 0x7FFFFFFF


## Conteggio dei prop solidi (diagnostica e test).
func solid_prop_count() -> int:
	var n: int = 0
	for p in props:
		if p["solid"]:
			n += 1
	return n


func terrain_counts() -> Dictionary:
	var out: Dictionary = {}
	for t in TERRAIN_NAME.keys():
		out[TERRAIN_NAME[t]] = 0
	for v in cells:
		var name: String = TERRAIN_NAME[int(v)]
		out[name] = int(out[name]) + 1
	return out


## Riassunto leggibile (log di avvio, report, test).
func summary() -> Dictionary:
	var walkable: int = 0
	for y in height:
		for x in width:
			if is_walkable_cell(Vector2i(x, y)):
				walkable += 1
	return {
		"seed": seed,
		"size": "%dx%d" % [width, height],
		"hash": layout_hash(),
		"spawn": spawn_cell,
		"props_total": props.size(),
		"props_solid": solid_prop_count(),
		"enemies": enemy_spawns.size(),
		"items": item_spawns.size(),
		"walkable_cells": walkable,
		"terrain": terrain_counts(),
	}
