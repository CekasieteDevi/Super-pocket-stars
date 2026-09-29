extends SceneTree
## Semillas del tiro_efecto: dónde entra y qué hace el arquero.
func _initialize() -> void:
	for semilla in range(1, 61):
		var rng := RandomNumberGenerator.new()
		rng.seed = semilla
		var casa := Team.generar("Atlético Prueba", rng)
		var visita := Team.generar("Deportivo Banco", rng, 1000)
		var r := Laboratorio.generar("tiro_efecto", casa, visita, rng)
		var fotos: Array = r["fotogramas"]
		if fotos.size() < 3: continue
		var tr = fotos[1]["pelota"].get("trayectoria", {})
		if not (tr is Dictionary) or tr.is_empty(): continue
		var d := Vector2(tr["destino"]["x"], tr["destino"]["y"])
		var c := Vector2(tr["control"]["x"], tr["control"]["y"])
		var gol := false
		var vuela := -1
		var arq0 := Vector2.INF
		var arq1 := Vector2.INF
		for i in fotos.size():
			for e in fotos[i].get("eventos", []):
				if str(e.get("resultado", "")) == "gol": gol = true
			for a in fotos[i].get("acciones", []):
				if str(a["accion"]) == "vuela" and vuela < 0: vuela = i
		if vuela >= 0:
			for j in fotos[vuela]["jugadores"]:
				if str(j.get("rol", "")) == "POR" and float(j["x"]) > 30:
					arq0 = Vector2(j["x"], j["y"])
			for j in fotos[mini(vuela + 2, fotos.size() - 1)]["jugadores"]:
				if str(j.get("rol", "")) == "POR" and float(j["x"]) > 30:
					arq1 = Vector2(j["x"], j["y"])
		print("semilla %d gol=%s destino=(%.1f,%.2f) control=(%.1f,%.1f) curva=%.1f vuela=%d arq %s -> %s" % [semilla, gol, d.x, d.y, c.x, c.y, float(tr["curva_m"]), vuela, str(arq0), str(arq1)])
	quit()
