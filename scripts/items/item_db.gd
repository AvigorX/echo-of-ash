class_name ItemDB
extends RefCounted
## Catalogo oggetti: dati puri, nessun nodo. Le definizioni vivono in un solo posto
## e sono lette da inventario, UI, drop e pickup.

const ITEMS: Dictionary = {
	"ash_shard": {
		"name": "Ash Shard",
		"kind": "resource",
		"desc": "A warm sliver of the old world. Currency of the survivors.",
		"color": Color(0.55, 0.78, 0.82),
	},
	"vial_of_sap": {
		"name": "Vial of Sap",
		"kind": "consumable",
		"heal": 35.0,
		"desc": "Bitter resin. Restores 35 health.",
		"color": Color(0.86, 0.63, 0.28),
	},
	"ash_blade": {
		"name": "Ashen Blade",
		"kind": "weapon",
		"damage": 4.0,
		"desc": "+4 attack. A re-forged blade from the ruins.",
		"color": Color(0.80, 0.84, 0.88),
	},
	"warden_plate": {
		"name": "Warden Plate",
		"kind": "armor",
		"armor": 2.0,
		"desc": "Reduces incoming damage by 2.",
		"color": Color(0.45, 0.55, 0.55),
	},
	"ember_charm": {
		"name": "Ember Charm",
		"kind": "trinket",
		"max_health": 20,
		"desc": "+20 maximum health. Still warm.",
		"color": Color(0.90, 0.42, 0.30),
	},
}

const SLOT_FOR_KIND: Dictionary = {
	"weapon": "weapon",
	"armor": "armor",
	"trinket": "trinket",
}


static func get_def(id: String) -> Dictionary:
	return ITEMS.get(id, {})


static func has(id: String) -> bool:
	return ITEMS.has(id)


static func name_of(id: String) -> String:
	var d: Dictionary = get_def(id)
	return str(d.get("name", id))


static func id_list() -> Array[String]:
	var out: Array[String] = []
	for k in ITEMS.keys():
		out.append(str(k))
	return out
