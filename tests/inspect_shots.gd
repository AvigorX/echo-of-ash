extends SceneTree
## Ispezione testuale degli screenshot: mappa ASCII di luminanza + mappa di
## classificazione colore. Serve a verificare la composizione (terreno, acqua,
## HUD, personaggi) senza dipendere dalla vista.
##
## Uso: ... --headless --script res://tests/inspect_shots.gd

const RAMP: String = " .:-=+*#%@"


func _initialize() -> void:
	for name in ["shot_01_spawn", "shot_02_combat", "shot_03_dialogue", "shot_06_closeup"]:
		var path: String = "res://out/%s.png" % name
		if not FileAccess.file_exists(path):
			print("MANCA ", path)
			continue
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img == null:
			print("ERRORE caricamento ", path)
			continue
		print("\n===== ", name, " ", img.get_width(), "x", img.get_height(), " =====")
		if name == "shot_06_closeup":
			# ingrandimento 3x della zona attorno al centro (giocatore + nemici)
			var crop := img.get_region(Rect2i(img.get_width() / 2 - 130, img.get_height() / 2 - 90, 260, 180))
			crop.resize(260, 180, Image.INTERPOLATE_NEAREST)
			_ascii(crop, 86, 42)
		else:
			_ascii(img, 96, 40)
		_classes(img)
	quit(0)


func _ascii(img: Image, cols: int, rows: int) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var bw: int = maxi(w / cols, 1)
	var bh: int = maxi(h / rows, 1)
	var out: Array[String] = []
	for ry in rows:
		var line: String = ""
		for rx in cols:
			var sum: float = 0.0
			var n: int = 0
			for y in range(ry * bh, mini((ry + 1) * bh, h), 3):
				for x in range(rx * bw, mini((rx + 1) * bw, w), 3):
					var c: Color = img.get_pixel(x, y)
					sum += c.get_luminance()
					n += 1
			var lum: float = sum / float(maxi(n, 1))
			var idx: int = clampi(int(lum * float(RAMP.length() - 1) * 2.2), 0, RAMP.length() - 1)
			line += RAMP[idx]
		out.append(line)
	for l in out:
		print("|", l, "|")


func _classes(img: Image) -> void:
	var counts: Dictionary = {
		"acqua": 0, "verde": 0, "terra": 0, "pietra": 0, "ciano": 0, "ambra": 0, "cremisi": 0, "scuro": 0,
	}
	var w: int = img.get_width()
	var h: int = img.get_height()
	var total: int = 0
	for y in range(0, h, 4):
		for x in range(0, w, 4):
			var c: Color = img.get_pixel(x, y)
			total += 1
			var mx: float = maxf(c.r, maxf(c.g, c.b))
			var mn: float = minf(c.r, minf(c.g, c.b))
			if mx < 0.16:
				counts["scuro"] += 1
			elif c.b > c.r * 1.25 and c.b > c.g * 1.05 and mx < 0.45:
				counts["acqua"] += 1
			elif c.g > c.r * 1.08 and c.g > c.b * 1.02:
				counts["verde"] += 1
			elif c.r > 0.55 and c.g > 0.38 and c.b < c.g * 0.75:
				counts["ambra"] += 1
			elif c.r > 0.38 and c.r > c.g * 1.35 and c.r > c.b * 1.3:
				counts["cremisi"] += 1
			elif c.b > 0.45 and c.g > 0.5 and c.r < 0.55:
				counts["ciano"] += 1
			elif mx - mn < 0.07:
				counts["pietra"] += 1
			else:
				counts["terra"] += 1
	var parts: Array[String] = []
	for k in counts.keys():
		parts.append("%s=%.1f%%" % [k, 100.0 * float(counts[k]) / float(maxi(total, 1))])
	print("classi: ", ", ".join(parts))
