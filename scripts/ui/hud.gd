class_name HUD
extends CanvasLayer
## Interfaccia interamente costruita in codice: barre, notifiche, prompt,
## dialogo, inventario, pausa, morte. Nessun asset, nessun font importato.
##
## L'HUD è un *osservatore*: legge lo stato del giocatore e reagisce ai segnali.
## Processa sempre (`PROCESS_MODE_ALWAYS`) così pausa e menu restano usabili.

signal resume_requested
signal new_world_requested

const AMBER: Color = Color(0.949, 0.741, 0.416)
const CYAN: Color = Color(0.451, 0.827, 0.851)
const CRIMSON: Color = Color(0.784, 0.259, 0.271)
const TEXT: Color = Color(0.824, 0.804, 0.761)
const MUTED: Color = Color(0.588, 0.588, 0.565)
const PANEL_BG: Color = Color(0.047, 0.055, 0.063, 0.95)

var player: Player = null
var dialogue_open: bool = false
var inventory_open: bool = false
var paused: bool = false
var dead: bool = false

var ui: Control
var stats: StatsPanel
var hp_label: Label
var level_label: Label
var xp_label: Label
var seed_label: Label
var controls_label: Label
var prompt_label: Label
var notif_box: VBoxContainer
var dialogue_panel: Panel
var dialogue_name: Label
var dialogue_text: Label
var dialogue_hint: Label
var inventory_panel: Panel
var inventory_rows: VBoxContainer
var inventory_footer: Label
var pause_panel: Control
var death_panel: Control
var vignette: Vignette

var _notifications: Array[Dictionary] = []
var _flash: float = 0.0
var _flash_color: Color = CRIMSON


# --- Costruzione ------------------------------------------------------------

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _build() -> void:
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)

	# pannello statistiche
	stats = StatsPanel.new()
	stats.position = Vector2(8, 8)
	stats.size = Vector2(152, 40)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(stats)

	hp_label = _label(ui, Vector2(10, 8), Vector2(140, 10), "", 7, TEXT)
	level_label = _label(ui, Vector2(10, 24), Vector2(60, 12), "LV 1", 8, AMBER)
	xp_label = _label(ui, Vector2(70, 25), Vector2(82, 12), "0 / 30 XP", 7, MUTED)
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	seed_label = _label(ui, Vector2(10, 34), Vector2(150, 10), "", 7, MUTED)

	controls_label = _label(ui, Vector2(8, 226), Vector2(300, 40),
		"WASD move   Mouse aim   LMB attack\nE interact / collect   I inventory   1-4 use item\nESC pause   R regenerate world",
		7, MUTED)

	prompt_label = _label(ui, Vector2(140, 198), Vector2(200, 12), "", 8, AMBER)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.visible = false

	notif_box = VBoxContainer.new()
	notif_box.position = Vector2(296, 8)
	notif_box.size = Vector2(176, 100)
	notif_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	notif_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(notif_box)

	dialogue_panel = _panel(ui, Vector2(40, 184), Vector2(400, 78))
	dialogue_name = _label(dialogue_panel, Vector2(8, 4), Vector2(300, 12), "", 8, AMBER)
	dialogue_text = _label(dialogue_panel, Vector2(8, 18), Vector2(384, 42), "", 8, TEXT)
	dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_hint = _label(dialogue_panel, Vector2(280, 60), Vector2(112, 12), "[E] continue", 7, MUTED)
	dialogue_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dialogue_panel.visible = false

	inventory_panel = _panel(ui, Vector2(108, 34), Vector2(264, 202))
	var inv_title := _label(inventory_panel, Vector2(10, 6), Vector2(200, 12), "INVENTORY", 9, AMBER)
	inv_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var inv_hint := _label(inventory_panel, Vector2(150, 7), Vector2(104, 12), "[I] close", 7, MUTED)
	inv_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	inventory_rows = VBoxContainer.new()
	inventory_rows.position = Vector2(10, 24)
	inventory_rows.size = Vector2(244, 140)
	inventory_rows.add_theme_constant_override("separation", 2)
	inventory_panel.add_child(inventory_rows)
	inventory_footer = _label(inventory_panel, Vector2(10, 168), Vector2(244, 28), "", 7, MUTED)
	inventory_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inventory_panel.visible = false

	pause_panel = _pause_panel()
	death_panel = _death_panel()
	vignette = Vignette.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(vignette)


func _label(parent: Node, pos: Vector2, size: Vector2, text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = size
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _panel(parent: Node, pos: Vector2, size: Vector2) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = size
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = Color(0.32, 0.28, 0.24)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 2
	sb.corner_radius_top_right = 2
	sb.corner_radius_bottom_left = 2
	sb.corner_radius_bottom_right = 2
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p


func _pause_panel() -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	ui.add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.025, 0.03, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var title := _label(root, Vector2(0, 44), Vector2(480, 30), "PAUSED", 22, AMBER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var box := VBoxContainer.new()
	box.position = Vector2(180, 96)
	box.size = Vector2(120, 90)
	box.add_theme_constant_override("separation", 6)
	root.add_child(box)
	var resume := _button(box, "Resume  [ESC]")
	resume.pressed.connect(func() -> void: resume_requested.emit())
	var new_world := _button(box, "New world  [R]")
	new_world.pressed.connect(func() -> void: new_world_requested.emit())
	var hint := _label(root, Vector2(60, 200), Vector2(360, 40),
		"Seed changes every regeneration. The world, enemies and loot are rebuilt.\nProgress is kept for this session.",
		7, MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return root


func _death_panel() -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	ui.add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.14, 0.02, 0.03, 0.60)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var title := _label(root, Vector2(0, 96), Vector2(480, 34), "YOU DIED", 26, CRIMSON)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hint := _label(root, Vector2(0, 140), Vector2(480, 30),
		"[E] rise again at the last brazier     [R] new world", 8, TEXT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return root


func _button(parent: Node, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(120, 18)
	b.add_theme_font_size_override("font_size", 8)
	b.focus_mode = Control.FOCUS_ALL
	parent.add_child(b)
	return b


# --- Collegamento al giocatore ---------------------------------------------

var _bound_player: Player = null


func bind(p: Player) -> void:
	if p == _bound_player:
		refresh_stats()
		refresh_inventory()
		return
	_bound_player = p
	player = p
	player.health_changed.connect(_on_health_changed)
	player.xp_changed.connect(_on_xp_changed)
	player.inventory_changed.connect(refresh_inventory)
	player.notified.connect(notify)
	player.damaged.connect(_on_damaged)
	player.leveled_up.connect(_on_leveled_up)
	refresh_stats()
	refresh_inventory()


func refresh_stats() -> void:
	if player == null:
		return
	var maximum: int = player.total_max_health()
	stats.health_ratio = clampf(float(player.health) / float(maxi(maximum, 1)), 0.0, 1.0)
	stats.xp_ratio = clampf(float(player.xp) / float(maxi(player.xp_next, 1)), 0.0, 1.0)
	hp_label.text = "%d / %d" % [player.health, maximum]
	level_label.text = "LV %d" % player.level
	xp_label.text = "%d / %d XP" % [player.xp, player.xp_next]
	stats.queue_redraw()


func _on_health_changed(_current: int, _maximum: int) -> void:
	refresh_stats()


func _on_xp_changed(_level: int, _xp: int, _xp_next: int) -> void:
	refresh_stats()


func _on_damaged(_amount: int) -> void:
	vignette.pulse(0.55, CRIMSON)


func _on_leveled_up(level: int) -> void:
	notify("Level %d — stronger." % level)
	vignette.pulse(0.5, AMBER)


# --- Notifiche, prompt, dialogo --------------------------------------------

func notify(text: String) -> void:
	if text == "":
		return
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 7)
	l.add_theme_color_override("font_color", TEXT)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.custom_minimum_size = Vector2(176, 10)
	l.size = Vector2(176, 10)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notif_box.add_child(l)
	_notifications.append({"node": l, "t": 0.0})
	while _notifications.size() > 5:
		var oldest: Dictionary = _notifications.pop_front()
		if is_instance_valid(oldest["node"]):
			(oldest["node"] as Label).queue_free()


func set_prompt(text: String) -> void:
	prompt_label.visible = text != ""
	prompt_label.text = text


func show_dialogue(speaker: String, text: String, index: int, total: int) -> void:
	dialogue_open = true
	dialogue_panel.visible = true
	dialogue_name.text = speaker
	dialogue_text.text = text
	dialogue_hint.text = "[E] continue (%d/%d)" % [index + 1, total]


func close_dialogue() -> void:
	dialogue_open = false
	dialogue_panel.visible = false


func set_seed_info(world_seed: int, phase: String) -> void:
	seed_label.text = "seed %d · %s" % [world_seed, phase]


# --- Inventario -------------------------------------------------------------

func refresh_inventory() -> void:
	for child in inventory_rows.get_children():
		child.queue_free()
	if player == null:
		return
	var entries: Array[Dictionary] = player.inventory.entries()
	if entries.is_empty():
		var empty := Label.new()
		empty.text = "Empty. Ash shards and relics drop from enemies."
		empty.add_theme_font_size_override("font_size", 7)
		empty.add_theme_color_override("font_color", MUTED)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.custom_minimum_size = Vector2(244, 24)
		inventory_rows.add_child(empty)
	else:
		for i in mini(entries.size(), 8):
			var e: Dictionary = entries[i]
			var row := Label.new()
			var equipped: bool = bool(e["equipped"])
			row.text = "%d  %-16s x%d%s" % [i + 1, str(e["name"]), int(e["count"]), "  [equipped]" if equipped else ""]
			row.add_theme_font_size_override("font_size", 7)
			row.add_theme_color_override("font_color", AMBER if equipped else TEXT)
			row.custom_minimum_size = Vector2(244, 10)
			inventory_rows.add_child(row)
			var desc := Label.new()
			desc.text = "    " + str(e["desc"])
			desc.add_theme_font_size_override("font_size", 6)
			desc.add_theme_color_override("font_color", MUTED)
			desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc.custom_minimum_size = Vector2(244, 10)
			inventory_rows.add_child(desc)
	inventory_footer.text = "Equipped: %s\n1-4 use / equip   ·   I close" % player.inventory.equipped_names()


func toggle_inventory() -> void:
	inventory_open = not inventory_open
	inventory_panel.visible = inventory_open
	if inventory_open:
		refresh_inventory()


## Chiude l'inventario se aperto (usato quando parte un dialogo).
func toggle_inventory_if_open() -> void:
	if inventory_open:
		toggle_inventory()


# --- Pausa e morte ----------------------------------------------------------

func set_paused(value: bool) -> void:
	paused = value
	pause_panel.visible = value
	if value:
		var first: Button = null
		for child in pause_panel.find_children("*", "Button", true, false):
			first = child as Button
			break
		if first != null:
			first.grab_focus()


func set_dead(value: bool) -> void:
	dead = value
	death_panel.visible = value
	if value:
		close_dialogue()
		inventory_open = false
		inventory_panel.visible = false


## Riporta la UI allo stato di gioco (usato quando il mondo viene ricostruito,
## anche dal menu di pausa): nessun overlay aperto, albero non in pausa.
func reset_overlays() -> void:
	dialogue_open = false
	dialogue_panel.visible = false
	inventory_open = false
	inventory_panel.visible = false
	paused = false
	pause_panel.visible = false
	dead = false
	death_panel.visible = false
	set_prompt("")


func _process(delta: float) -> void:
	vignette.tick(delta)
	for i in range(_notifications.size() - 1, -1, -1):
		var item: Dictionary = _notifications[i]
		item["t"] = float(item["t"]) + delta
		var t: float = float(item["t"])
		var node: Label = item["node"]
		if not is_instance_valid(node):
			_notifications.remove_at(i)
			continue
		if t > 1.6:
			node.modulate.a = clampf(1.0 - (t - 1.6) / 0.8, 0.0, 1.0)
		if t > 2.4:
			node.queue_free()
			_notifications.remove_at(i)


# --- Sottocontrolli disegnati ----------------------------------------------

class StatsPanel extends Control:
	var health_ratio: float = 1.0
	var xp_ratio: float = 0.0

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 152, 9), Color(0.05, 0.05, 0.06, 0.92))
		draw_rect(Rect2(0, 0, 152 * health_ratio, 9), Color(0.62, 0.16, 0.18))
		draw_rect(Rect2(0, 0, 152 * health_ratio, 3), Color(0.78, 0.27, 0.27, 0.85))
		draw_rect(Rect2(0, 0, 152, 9), Color(0.34, 0.28, 0.27), false, 1.0)
		draw_rect(Rect2(0, 12, 152, 4), Color(0.05, 0.05, 0.06, 0.92))
		draw_rect(Rect2(0, 12, 152 * xp_ratio, 4), Color(0.28, 0.60, 0.64))
		draw_rect(Rect2(0, 12, 152, 4), Color(0.24, 0.30, 0.31), false, 1.0)


class Vignette extends Control:
	var amount: float = 0.0
	var color: Color = Color(0.7, 0.1, 0.12)

	func pulse(strength: float, c: Color) -> void:
		amount = maxf(amount, strength)
		color = c
		queue_redraw()

	func tick(delta: float) -> void:
		if amount > 0.0:
			amount = maxf(0.0, amount - delta * 0.9)
			queue_redraw()

	func _draw() -> void:
		if amount <= 0.01:
			return
		var band: float = 26.0
		var layers: int = 6
		for i in layers:
			var a: float = amount * 0.10 * (1.0 - float(i) / float(layers))
			var inset: float = float(i) * (band / float(layers))
			var thickness: float = band / float(layers)
			draw_rect(Rect2(inset, inset, size.x - inset * 2.0, thickness), Color(color.r, color.g, color.b, a))
			draw_rect(Rect2(inset, size.y - inset - thickness, size.x - inset * 2.0, thickness), Color(color.r, color.g, color.b, a))
			draw_rect(Rect2(inset, inset, thickness, size.y - inset * 2.0), Color(color.r, color.g, color.b, a))
			draw_rect(Rect2(size.x - inset - thickness, inset, thickness, size.y - inset * 2.0), Color(color.r, color.g, color.b, a))
