class_name WaterOverlay
extends Node2D
## Animazione dell'acqua: increspature disegnate sopra il suolo statico.
## Solo presentazione — la logica di collisione è nella griglia (WorldData).

var time: float = 0.0
var _cells: PackedVector2Array = PackedVector2Array()
var _shore: PackedVector2Array = PackedVector2Array()
var _enabled: bool = true


func setup(world: WorldData) -> void:
	var cells: Array[Vector2] = []
	var shore: Array[Vector2] = []
	for y in world.height:
		for x in world.width:
			var cell := Vector2i(x, y)
			if world.terrain_at(cell) != WorldData.Terrain.WATER:
				continue
			var p := world.cell_to_world(cell)
			cells.append(p)
			var near_land: bool = (
				world.terrain_at(cell + Vector2i(1, 0)) != WorldData.Terrain.WATER
				or world.terrain_at(cell + Vector2i(-1, 0)) != WorldData.Terrain.WATER
				or world.terrain_at(cell + Vector2i(0, 1)) != WorldData.Terrain.WATER
				or world.terrain_at(cell + Vector2i(0, -1)) != WorldData.Terrain.WATER
			)
			if near_land:
				shore.append(p)
	_cells = PackedVector2Array(cells)
	_shore = PackedVector2Array(shore)
	queue_redraw()


func _process(delta: float) -> void:
	if not _enabled:
		return
	time += delta
	queue_redraw()


func _draw() -> void:
	var cam := get_viewport().get_camera_2d()
	var center: Vector2 = cam.get_screen_center_position() if cam != null else Vector2.ZERO
	var half := Vector2(260, 160)
	for p in _cells:
		var d: Vector2 = p - center
		if absf(d.x) > half.x or absf(d.y) > half.y:
			continue
		var phase: float = sin(time * 1.6 + p.x * 0.09 + p.y * 0.13)
		if phase <= 0.15:
			continue
		var a: float = 0.055 * phase
		var length: float = 4.0 + 4.0 * phase
		var yy: float = p.y - 2.0 + sin(time * 1.2 + p.x * 0.05) * 1.2
		draw_line(Vector2(p.x - length, yy), Vector2(p.x + length, yy), Color(0.52, 0.80, 0.86, a), 1.0)
	for p in _shore:
		var d2: Vector2 = p - center
		if absf(d2.x) > half.x or absf(d2.y) > half.y:
			continue
		var foam: float = 0.5 + 0.5 * sin(time * 2.2 + p.x * 0.11)
		draw_line(
			Vector2(p.x - 5.0, p.y + 6.0), Vector2(p.x + 5.0, p.y + 6.0),
			Color(0.78, 0.86, 0.86, 0.05 + 0.06 * foam), 1.0
		)
