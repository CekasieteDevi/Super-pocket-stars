extends SceneTree
## Tiros libres del Laboratorio con distintas semillas: cómo termina cada uno
## (gol, barrera, otro).
func _initialize() -> void:
	var gol := 0
	var barrera := 0
	for s in range(0, 120):
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var casa := Team.generar("Atlético Prueba", rng)
		var visita := Team.generar("Deportivo Banco", rng, 1000)
		var r := Laboratorio.generar("tiro_libre", casa, visita, rng)
		var fotos: Array = r["fotogramas"]
		var saque := -1
		var pateador := -1
		for k in fotos.size():
			for a in fotos[k].get("acciones", []):
				if str(a["accion"]) == MotorEspacial.ACCION_PATEA and saque == -1 and k > 0 and int(fotos[k - 1].get("detenido", 0)) > 0:
					saque = k
					pateador = int(a["clave"])
		if saque == -1:
			continue
		var f: Dictionary = fotos[saque - 1]
		var bola := Vector2(f["pelota"]["x"], f["pelota"]["y"])
		var je := VistaPartido._jugador_en(f, pateador)
		if je.is_empty():
			continue
		var arco := MotorEspacial.arco_rival(bool(je["equipo_local"]))
		var linea := (arco - bola).normalized()
		var muro := []
		for j in f["jugadores"]:
			if bool(j["equipo_local"]) == bool(je["equipo_local"]): continue
			var d := Vector2(j["x"], j["y"]) - bola
			if d.length() > 8.0 and d.length() < 10.5 and d.dot(linea) > 0.0 and absf(d.cross(linea)) < 3.0:
				muro.append(Vector2(j["x"], j["y"]))
		var resultado := "otro"
		for k in range(saque, mini(fotos.size(), saque + 12)):
			for ev in fotos[k].get("eventos", []):
				if str(ev.get("resultado", "")) == "gol" or str(ev.get("tipo", "")) == "gol":
					resultado = "GOL"
		if resultado == "otro":
			# pega en la barrera: la pelota pasa a <1.3 m de uno del muro y se desvía
			for k in range(saque, mini(fotos.size() - 1, saque + 4)):
				var p0 := Vector2(fotos[k]["pelota"]["x"], fotos[k]["pelota"]["y"])
				var p1 := Vector2(fotos[k + 1]["pelota"]["x"], fotos[k + 1]["pelota"]["y"])
				for m in muro:
					var cerca := Geometry2D.get_closest_point_to_segment(m, p0, p1).distance_to(m) < 1.3
					if cerca and (p1 - p0).normalized().dot(linea) < 0.6:
						resultado = "BARRERA"
		if resultado == "GOL": gol += 1
		if resultado == "BARRERA": barrera += 1
		if resultado != "otro" or s < 5:
			print("TL semilla %d saque %d barrera=%d %s z=%s" % [s, saque, muro.size(), resultado,
				str(fotos[mini(saque + 1, fotos.size() - 1)]["pelota"].get("z", 0))])
		if gol >= 3 and barrera >= 3: break
	quit()
