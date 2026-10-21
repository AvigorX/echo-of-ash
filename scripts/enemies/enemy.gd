class_name Enemy
extends CharacterBody2D
## Nemici con macchina a stati: IDLE → PATROL → CHASE → WINDUP → RECOVER, più HURT/DEAD.
## Movimento con raycast di aggiramento + rilevamento di stallo: non restano incastrati.

signal died(enemy: Enemy)
signal health_changed(current: int, maximum: int)
signal struck(pos: Vector2, dir: Vector2)

enum State { IDLE, PATROL, CHASE, WINDUP, RECOVER, HURT, DEAD }

const TYPES: Dictionary = {
	"crawler": {
		"name": "Cinder Crawler",
		"max_health": 26,
		"speed": 62.0,
		"damage": 9.0,
		"detect": 118.0,
		"attack_range": 20.0,
		"cooldown": 1.05,
		"windup": 0.30,
		"xp": 12,
		"radius": 6.5,
		"knock_resist": 0.95,
	},
	"warden": {
		"name": "Ash Warden",
		"max_health": 72,
		"speed": 44.0,
		"damage": 18.0,
		"detect": 152.0,
		"attack_range": 26.0,
		"cooldown": 1.65,
		"windup": 0.55,
		"xp": 34,
		"radius": 9.0,
		"knock_resist": 0.55,
	},
}

var kind: String = "crawler"
var display_name: String = "Cinder Crawler"
var max_health: int = 26
var health: int = 26
var speed: float = 62.0
var damage: float = 9.0
var detect_radius: float = 118.0
var attack_range: float = 20.0
var cooldown_time: float = 1.05
var windup_time: float = 0.30
var xp_reward: int = 12
var radius: float = 6.5
var knock_resist: float = 0.95

var state: int = State.IDLE
var target: Player = null
var world: WorldData = null
var spawn_point: Vector2 = Vector2.ZERO
var facing: Vector2 = Vector2.DOWN
var dead: bool = false
var hurt_flash: float = 0.0
var state_time: float = 0.0
var cooldown: float = 0.0
var knockback: Vector2 = Vector2.ZERO
var walk_phase: float = 0.0
var death_time: float = 0.0
var wander_dir: Vector2 = Vector2.ZERO
var wander_time: float = 0.0
var sidestep_time: float = 0.0
var sidestep_dir: Vector2 = Vector2.ZERO

var _visual: EnemyVisual
var _collision: CollisionShape2D
var _rng := RandomNumberGenerator.new()
var _stuck_ref: Vector2 = Vector2.ZERO
var _stuck_acc: float = 0.0


func configure(kind_id: String, spawn: Vector2, player: Player, rng_seed: int = 1) -> void:
	kind = kind_id if TYPES.has(kind_id) else "crawler"
	var def: Dictionary = TYPES[kind]
	display_name = str(def["name"])
	max_health = int(def["max_health"])
	health = max_health
	speed = float(def["speed"])
	damage = float(def["damage"])
	detect_radius = float(def["detect"])
	attack_range = float(def["attack_range"])
	cooldown_time = float(def["cooldown"])
	windup_time = float(def["windup"])
	xp_reward = int(def["xp"])
	radius = float(def["radius"])
	knock_resist = float(def["knock_resist"])
	target = player
	spawn_point = spawn
	position = spawn
	_rng.seed = rng_seed * 7919 + kind.hash()


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_collision = CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	_collision.shape = shape
	_collision.position = Vector2(0, -radius * 0.4)
	add_child(_collision)
	_visual = EnemyVisual.new()
	_visual.enemy = self
	add_child(_visual)
	_stuck_ref = global_position
	_set_state(State.IDLE)


func _physics_process(delta: float) -> void:
	if dead:
		death_time += delta
		queue_redraw_visual()
		if death_time > 0.45:
			queue_free()
		return
	cooldown = maxf(0.0, cooldown - delta)
	hurt_flash = maxf(0.0, hurt_flash - delta)
	state_time += delta
	if target == null or not is_instance_valid(target) or target.dead:
		if state != State.IDLE and state != State.PATROL:
			_set_state(State.IDLE)
	match state:
		State.IDLE:
			velocity = velocity.move_toward(Vector2.ZERO, 400.0 * delta)
			_slide()
			if _player_visible() and _distance_to_player() < detect_radius:
				_set_state(State.CHASE)
			elif state_time > wander_time:
				_start_patrol()
		State.PATROL:
			_move(wander_dir, 0.42, delta)
			if _player_visible() and _distance_to_player() < detect_radius:
				_set_state(State.CHASE)
			elif state_time > 1.6:
				_set_state(State.IDLE)
		State.CHASE:
			if _distance_to_player() <= attack_range and cooldown <= 0.0 and _player_visible():
				_set_state(State.WINDUP)
				velocity = Vector2.ZERO
			else:
				var to_target: Vector2 = (target.global_position - global_position) if target != null else Vector2.ZERO
				# Distanza di rispetto: il nemico non entra dentro il giocatore
				# (non c'è collisione fisica fra i due, solo fra entrambi e il mondo).
				var standoff: float = radius + Player.CONTACT_RADIUS + 1.0
				if to_target.length() > standoff:
					_move(to_target.normalized(), 1.0, delta)
				else:
					velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
					_slide()
		State.WINDUP:
			velocity = velocity.move_toward(Vector2.ZERO, 700.0 * delta)
			_slide()
			if target != null:
				facing = (target.global_position - global_position).normalized()
			if state_time >= windup_time:
				_strike()
		State.RECOVER:
			velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
			_slide()
			if state_time >= 0.42:
				_set_state(State.CHASE if _distance_to_player() < detect_radius * 1.3 else State.IDLE)
		State.HURT:
			velocity = knockback
			knockback = knockback.move_toward(Vector2.ZERO, 520.0 * delta)
			_slide()
			if state_time >= 0.22:
				var chase: bool = target != null and is_instance_valid(target) and not target.dead
				_set_state(State.CHASE if chase else State.IDLE)
		State.DEAD:
			pass
	queue_redraw_visual()


func _set_state(next: int) -> void:
	state = next
	state_time = 0.0


func _start_patrol() -> void:
	var angle: float = _rng.randf() * TAU
	wander_dir = Vector2(cos(angle), sin(angle))
	wander_time = _rng.randf_range(0.6, 1.6)
	_set_state(State.PATROL)


func _distance_to_player() -> float:
	if target == null or not is_instance_valid(target):
		return 9999.0
	return global_position.distance_to(target.global_position)


## Linea di vista: un muro/albero fra nemico e giocatore nasconde il bersaglio.
func _player_visible() -> bool:
	if target == null or not is_instance_valid(target) or not is_inside_tree():
		return false
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var from: Vector2 = global_position + Vector2(0, -6)
	var to: Vector2 = target.global_position + Vector2(0, -6)
	var query := PhysicsRayQueryParameters2D.create(from, to, 1)
	query.exclude = [get_rid()]
	var hit: Dictionary = space.intersect_ray(query)
	return hit.is_empty() or float((hit.get("position", to) as Vector2).distance_to(to)) < 4.0


## Muove verso `desired` aggirando gli ostacoli con 5 raggi; dopo 0.6 s di stallo
## passa a un movimento laterale per uscire dagli angoli.
func _move(desired: Vector2, speed_scale: float, delta: float) -> void:
	if desired == Vector2.ZERO:
		velocity = velocity.move_toward(Vector2.ZERO, 500.0 * delta)
		_slide()
		return
	var dir: Vector2 = _avoid(desired.normalized())
	if sidestep_time > 0.0:
		sidestep_time -= delta
		dir = _avoid(sidestep_dir)
	var separation := _separation()
	var final_dir: Vector2 = (dir + separation * 0.7).normalized()
	velocity = final_dir * speed * speed_scale + knockback
	knockback = knockback.move_toward(Vector2.ZERO, 480.0 * delta)
	_slide()
	if velocity.length() > 4.0:
		facing = velocity.normalized()
	walk_phase += delta * (4.0 + 3.0 * speed_scale)
	# rilevamento di stallo su finestra di 0.6 s
	if global_position.distance_to(_stuck_ref) < 1.2:
		_stuck_acc += delta
		if _stuck_acc > 0.6:
			sidestep_time = 0.85
			sidestep_dir = desired.normalized().rotated(PI * 0.5 * (1.0 if _rng.randf() < 0.5 else -1.0))
			_stuck_acc = 0.0
			_stuck_ref = global_position
	else:
		_stuck_acc = 0.0
		_stuck_ref = global_position


func _slide() -> void:
	var previous: Vector2 = global_position
	move_and_slide()
	if world != null:
		global_position = WorldData.resolve_land_position(world, previous, global_position)


func _separation() -> Vector2:
	var push := Vector2.ZERO
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == self or not (node is Enemy):
			continue
		var other := node as Enemy
		if other.dead:
			continue
		var d: Vector2 = global_position - other.global_position
		var minimum: float = radius + other.radius + 2.0
		if d.length() < minimum and d.length() > 0.01:
			push += d.normalized() * (1.0 - d.length() / minimum)
	return push


func _avoid(desired: Vector2) -> Vector2:
	if not is_inside_tree():
		return desired
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var origin: Vector2 = global_position + Vector2(0, -6)
	for angle in [0.0, 28.0, -28.0, 58.0, -58.0, 90.0, -90.0]:
		var d: Vector2 = desired.rotated(deg_to_rad(angle))
		var query := PhysicsRayQueryParameters2D.create(origin, origin + d * (radius + 12.0), 1)
		query.exclude = [get_rid()]
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			return d
	return -desired


func _strike() -> void:
	struck.emit(global_position, facing)
	cooldown = cooldown_time
	if target != null and is_instance_valid(target) and not target.dead:
		var to_target: Vector2 = target.global_position - global_position
		if to_target.length() <= attack_range + 7.0:
			target.take_damage(damage, global_position)
	_set_state(State.RECOVER)


func take_damage(amount: float, from_pos: Vector2) -> bool:
	if dead:
		return false
	var applied: int = maxi(1, int(round(amount)))
	health = maxi(0, health - applied)
	hurt_flash = 0.20
	var away: Vector2 = global_position - from_pos
	if away.length() < 0.01:
		away = Vector2.DOWN
	knockback = away.normalized() * 120.0 * knock_resist
	health_changed.emit(health, max_health)
	if health <= 0:
		_die()
	else:
		_set_state(State.HURT)
	return true


func _die() -> void:
	if dead:
		return
	dead = true
	health = 0
	state = State.DEAD
	velocity = Vector2.ZERO
	knockback = Vector2.ZERO
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0
	if _collision != null:
		_collision.set_deferred("disabled", true)
	death_time = 0.0
	died.emit(self)


func health_ratio() -> float:
	return float(health) / float(maxi(max_health, 1))


func queue_redraw_visual() -> void:
	if _visual != null and is_instance_valid(_visual):
		_visual.queue_redraw()
