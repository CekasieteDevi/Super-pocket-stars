extends SceneTree
## Velocidad (m/s) del que recibe, tick por tick, alrededor de cada control
## con el pie o de pecho en un partido real (semilla + n): -- 0
func _initialize() -> void:
	var n := int(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 else 0
	var rng := RandomNumberGenerator.new()
	rng.seed = PrototipoVista.SEMILLA + n
	var local := Team.generar("Atlético Prueba", rng)
	var visita := Team.generar("Deportivo Banco", rng, 1000)
	var fotos: Array = MotorEspacial.simular(local, visita, rng, true)["fotogramas"]
	var vistos := 0
	var suma := []
	suma.resize(12)
	suma.fill(0.0)
	for k in range(6, fotos.size() - 8):
		for a in fotos[k].get("acciones", []):
			if str(a["accion"]) not in ["control_pie", "pecho"]:
				continue
			var id := int(a["clave"])
			var fila := []
			var ok := true
			for dk in range(-4, 8):
				var j0 := VistaPartido._jugador_en(fotos[k + dk - 1], id)
				var j1 := VistaPartido._jugador_en(fotos[k + dk], id)
				if j0.is_empty() or j1.is_empty() or bool(fotos[k + dk].get("reubicacion", false)):
					ok = false
					break
				var v := Vector2(j1["x"], j1["y"]).distance_to(Vector2(j0["x"], j0["y"])) / 0.25
				fila.append(v)
			if not ok:
				continue
			for i in fila.size():
				suma[i] += fila[i]
			vistos += 1
			if vistos <= 12:
				print("RECEPCION tick %d %s: %s" % [k, a["accion"], " ".join(fila.map(func(x): return "%.1f" % x))])
	if vistos > 0:
		print("PROMEDIO (%d recepciones, ticks -4..+7): %s" % [vistos, " ".join(suma.map(func(x): return "%.1f" % (x / vistos)))])
	quit()
