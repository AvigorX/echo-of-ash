class_name Inventory
extends RefCounted
## Inventario: dati + regole, nessuna UI. La UI si limita a leggere `entries()`.
## Equipaggiamento per slot (arma / armatura / amuleto); i bonus sono interrogati
## dal giocatore tramite `bonus_total()`.

signal changed

const MAX_SLOTS: int = 12

var items: Dictionary = {}
var equipped: Dictionary = {"weapon": "", "armor": "", "trinket": ""}


func add(id: String, count: int = 1) -> bool:
	if count <= 0 or not ItemDB.has(id):
		return false
	if not items.has(id) and items.size() >= MAX_SLOTS:
		return false
	items[id] = int(items.get(id, 0)) + count
	changed.emit()
	return true


func remove(id: String, count: int = 1) -> bool:
	if count <= 0:
		return false
	var have: int = int(items.get(id, 0))
	if have < count:
		return false
	if have == count:
		items.erase(id)
		for slot in equipped.keys():
			if equipped[slot] == id:
				equipped[slot] = ""
	else:
		items[id] = have - count
	changed.emit()
	return true


func count_of(id: String) -> int:
	return int(items.get(id, 0))


func is_empty() -> bool:
	return items.is_empty()


## Voci ordinate per la UI: [{id, count, name, kind, desc, color, equipped}]
func entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ids: Array = items.keys()
	ids.sort()
	for id in ids:
		var d: Dictionary = ItemDB.get_def(str(id))
		if d.is_empty():
			continue
		out.append({
			"id": str(id),
			"count": int(items[id]),
			"name": str(d["name"]),
			"kind": str(d["kind"]),
			"desc": str(d.get("desc", "")),
			"color": d.get("color", Color(0.8, 0.8, 0.8)),
			"equipped": is_equipped(str(id)),
		})
	return out


func is_equipped(id: String) -> bool:
	for slot in equipped.keys():
		if equipped[slot] == id:
			return true
	return false


func equip(id: String) -> bool:
	var d: Dictionary = ItemDB.get_def(id)
	if d.is_empty():
		return false
	var slot: String = str(ItemDB.SLOT_FOR_KIND.get(str(d["kind"]), ""))
	if slot == "" or count_of(id) <= 0:
		return false
	equipped[slot] = id
	changed.emit()
	return true


## Usa un oggetto. Restituisce il messaggio da mostrare ("" se non usabile).
## `user` è duck-typed: deve esporre heal(float) -> float.
func use(id: String, user: Node) -> String:
	var d: Dictionary = ItemDB.get_def(id)
	if d.is_empty() or count_of(id) <= 0:
		return ""
	match str(d["kind"]):
		"consumable":
			var healed: float = float(user.call("heal", float(d.get("heal", 0.0))))
			if healed <= 0.0:
				return "Already at full health."
			remove(id, 1)
			return "Restored %d health." % int(healed)
		"weapon", "armor", "trinket":
			if is_equipped(id):
				return "%s is already equipped." % str(d["name"])
			equip(id)
			return "Equipped %s." % str(d["name"])
		_:
			return ""


func bonus_total(key: String) -> float:
	var total: float = 0.0
	for slot in equipped.keys():
		var id: String = str(equipped[slot])
		if id == "":
			continue
		var d: Dictionary = ItemDB.get_def(id)
		total += float(d.get(key, 0.0))
	return total


func equipped_names() -> String:
	var parts: Array[String] = []
	for slot in ["weapon", "armor", "trinket"]:
		var id: String = str(equipped[slot])
		if id != "":
			parts.append(ItemDB.name_of(id))
	if parts.is_empty():
		return "none"
	return ", ".join(parts)
