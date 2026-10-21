class_name Player
extends CharacterBody2D
## Giocatore: movimento 8 direzioni con inerzia, attacco melee, salute, progressione.
## Non conosce né nemici né UI: emette segnali che il livello (game.gd) collega.

signal health_changed(current: int, maximum: int)
signal damaged(amount: int)
signal died
signal xp_changed(level: int, xp: int, xp_next: int)
signal leveled_up(level: int)
signal attack_swing(dir: Vector2, damage: float)
signal inventory_changed
signal notified(text: String)

const SPEED: float = 76.0
const ACCEL: float = 950.0
const FRICTION: float = 1400.0
const ATTACK_COOLDOWN: float = 0.34
const ATTACK_REACH: float = 26.0
const ATTACK_ARC_DEG: float = 105.0
const KNOCKBACK_FORCE: float = 150.0
## Raggio del corpo fisico del giocatore: usato dai nemici per la distanza di rispetto.
const CONTACT_RADIUS: float = 5.0

var base_max_health: int = 100
var base_damage: float = 7.0
var health: int = 100
var level: int = 1
var xp: int = 0
var xp_next: int = 30
var dead: bool = false
var facing: Vector2 = Vector2.DOWN
var swing_dir: Vector2 = Vector2.RIGHT
var swing_time: float = 0.0
var attack_cooldown: float = 0.0
var invuln: float = 0.0
var hurt_flash: float = 0.0
var walk_phase: float = 0.0
var knockback: Vector2 = Vector2.ZERO
var inventory: Inventory
var bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(1536, 1536))

var camera: Camera2D
var visual: PlayerVisual
var world: WorldData = null
var _collision: CollisionShape2D


func _ready() -> void:
	inventory = Inventory.new()
	inventory.changed.connect(_on_inventory_changed)
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_collision = CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 5.0
	_collision.shape = shape
	_collision.position = Vector2(0, -4)
	add_child(_collision)
	visual = PlayerVisual.new()
	visual.player = self
	add_child(visual)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.position = Vector2(0, -8)
	add_child(camera)
	camera.make_current()
	health = total_max_health()
	health_changed.emit(health, total_max_health())
	xp_changed.emit(level, xp, xp_next)


func setup(world_ref: WorldData, start_pos: Vector2) -> void:
	world = world_ref
	bounds = Rect2(Vector2.ZERO, world_ref.world_size())
	position = start_pos
	camera.limit_left = int(bounds.position.x)
	camera.limit_top = int(bounds.position.y)
	camera.limit_right = int(bounds.position.x + bounds.size.x)
	camera.limit_bottom = int(bounds.position.y + bounds.size.y)
	camera.reset_smoothing()
	dead = false
	attack_cooldown = 0.0
	swing_time = 0.0
	knockback = Vector2.ZERO
	velocity = Vector2.ZERO
	health = total_max_health()
	health_changed.emit(health, total_max_health())


func total_max_health() -> int:
	return base_max_health + int(inventory.bonus_total("max_health")) if inventory != null else base_max_health


func total_damage() -> float:
	return base_damage + inventory.bonus_total("damage") if inventory != null else base_damage


func armor() -> float:
	return inventory.bonus_total("armor") if inventory != null else 0.0


func _physics_process(delta: float) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	swing_time = maxf(0.0, swing_time - delta)
	invuln = maxf(0.0, invuln - delta)
	hurt_flash = maxf(0.0, hurt_flash - delta)
	if dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var desired: Vector2 = input * SPEED
	if input.length_squared() > 0.01:
		facing = input.normalized()
		walk_phase += delta * (6.0 + 4.0 * input.length())
		velocity = velocity.move_toward(desired, ACCEL * delta)
	else:
		walk_phase = lerpf(walk_phase, roundf(walk_phase / PI) * PI, clampf(delta * 8.0, 0.0, 1.0))
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	knockback = knockback.move_toward(Vector2.ZERO, 620.0 * delta)
	velocity += knockback
	var previous: Vector2 = global_position
	move_and_slide()
	if world != null:
		global_position = WorldData.resolve_land_position(world, previous, global_position)
	position.x = clampf(position.x, bounds.position.x + 6.0, bounds.position.x + bounds.size.x - 6.0)
	position.y = clampf(position.y, bounds.position.y + 8.0, bounds.position.y + bounds.size.y - 4.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack") and not dead:
		try_attack(aim_direction())


## Direzione di mira: verso il mouse, altrimenti verso l'ultima direzione di movimento.
func aim_direction() -> Vector2:
	var to_mouse: Vector2 = get_global_mouse_position() - global_position
	if to_mouse.length() > 6.0:
		return to_mouse.normalized()
	if facing.length_squared() > 0.01:
		return facing.normalized()
	return Vector2.DOWN


## Esegue un attacco se il cooldown lo consente. Ritorna true se l'attacco parte.
## Pubblica: i test la chiamano direttamente, senza simulare il mouse.
func try_attack(dir: Vector2 = Vector2.ZERO) -> bool:
	if dead or attack_cooldown > 0.0:
		return false
	if dir == Vector2.ZERO:
		dir = facing
	swing_dir = dir.normalized()
	swing_time = 0.22
	attack_cooldown = ATTACK_COOLDOWN
	facing = swing_dir
	attack_swing.emit(swing_dir, total_damage())
	return true


func take_damage(amount: float, from_pos: Vector2) -> bool:
	if dead or invuln > 0.0:
		return false
	var reduced: float = maxf(1.0, amount - armor())
	var applied: int = int(round(reduced))
	health = maxi(0, health - applied)
	invuln = 0.55
	hurt_flash = 0.30
	var away: Vector2 = global_position - from_pos
	if away.length() < 0.01:
		away = Vector2.DOWN
	knockback = away.normalized() * KNOCKBACK_FORCE
	damaged.emit(applied)
	health_changed.emit(health, total_max_health())
	if health <= 0:
		_die()
	return true


## Cura il giocatore e ritorna la quantità effettivamente recuperata.
func heal(amount: float) -> float:
	if dead or amount <= 0.0:
		return 0.0
	var maximum: int = total_max_health()
	var before: int = health
	health = mini(maximum, health + int(round(amount)))
	var healed: int = health - before
	if healed > 0:
		health_changed.emit(health, maximum)
	return float(healed)


func _die() -> void:
	if dead:
		return
	dead = true
	velocity = Vector2.ZERO
	knockback = Vector2.ZERO
	died.emit()


func respawn(at: Vector2) -> void:
	dead = false
	health = total_max_health()
	invuln = 1.2
	hurt_flash = 0.0
	position = at
	knockback = Vector2.ZERO
	velocity = Vector2.ZERO
	health_changed.emit(health, total_max_health())


func gain_xp(amount: int) -> void:
	if amount <= 0 or dead:
		return
	xp += amount
	while xp >= xp_next:
		xp -= xp_next
		level += 1
		base_max_health += 12
		base_damage += 1.5
		xp_next = int(round(float(xp_next) * 1.35 + 8.0))
		health = total_max_health()
		leveled_up.emit(level)
		health_changed.emit(health, total_max_health())
	xp_changed.emit(level, xp, xp_next)


## Raccoglie un oggetto nell'inventario e notifica la UI.
func collect(id: String, count: int = 1) -> bool:
	if not inventory.add(id, count):
		notified.emit("Inventory full.")
		return false
	notified.emit("+%d %s" % [count, ItemDB.name_of(id)])
	if id == "ash_shard":
		gain_xp(2)
	return true


func use_slot(index: int) -> void:
	var entries: Array[Dictionary] = inventory.entries()
	if index < 0 or index >= entries.size():
		notified.emit("No item in slot %d." % (index + 1))
		return
	var id: String = str(entries[index]["id"])
	var message: String = inventory.use(id, self)
	if message != "":
		notified.emit(message)


func _on_inventory_changed() -> void:
	var maximum: int = total_max_health()
	if health > maximum:
		health = maximum
	health_changed.emit(health, maximum)
	inventory_changed.emit()
