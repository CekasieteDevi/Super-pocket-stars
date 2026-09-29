extends SceneTree
## Faltas cerca del área: cuántos defensores quedan a 8-10.5 m de la pelota
## del lado del arco justo antes del saque (la barrera).
func _initialize() -> void:
	var hallados := 0
	for n in range(0, 40):
		var rng := RandomNumberGenerator.new()
		rng.seed = PrototipoVista.SEMILLA + n
		var local := Team.generar("Atlético Prueba", rng)
		var visita := Team.generar("Deportivo Banco", rng, 1000)
		var fotos: Array = MotorEspacial.simular(local, visita, rng, true)["fotogramas"]
		for k in fotos.size():
			if not fotos[k].get("eventos", []).any(func(e): return str(e.get("tipo", "")) == "falta"):
				continue
			# el saque: primer tick después con detenido == 0
			var s := k + 1
			while s < fotos.size() and int(fotos[s].get("detenido", 0)) > 0:
				s += 1
			if s >= fotos.size(): continue
			var f: Dictionary = fotos[s - 1]
			var bola := Vector2(f["pelota"]["x"], f["pelota"]["y"])
			if absf(bola.x) < 22.0 or absf(bola.y) > 22.0: continue
			var arco := Vector2(signf(bola.x) * 52.5, 0.0)
			var en_barrera := []
			for j in f["jugadores"]:
				var pj := Vector2(j["x"], j["y"])
				var d := pj.distance_to(bola)
				if d > 8.0 and d < 10.5 and (pj - bola).dot(arco - bola) > 0.0:
					en_barrera.append(str(j["id"]))
			print("FALTA s+%d t%d saque t%d bola(%.1f,%.1f) barrera=%s acc=%s" % [n, k, s, bola.x, bola.y, en_barrera,
				fotos[s].get("acciones", []).map(func(a): return str(a["accion"]))])
			hallados += 1
		if hallados >= 8: break
	quit()
