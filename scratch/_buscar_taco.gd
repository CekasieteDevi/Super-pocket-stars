extends SceneTree
## Busca tacos en juego corrido: sin corte ni reubicación ni salto de pelota
## en los 10 ticks previos y los 18 siguientes.
func _initialize() -> void:
	for n in range(0, 30):
		var rng := RandomNumberGenerator.new()
		rng.seed = PrototipoVista.SEMILLA + n
		var local := Team.generar("Atlético Prueba", rng)
		var visita := Team.generar("Deportivo Banco", rng, 1000)
		var fotos: Array = MotorEspacial.simular(local, visita, rng, true)["fotogramas"]
		for i in range(12, fotos.size() - 20):
			var hay := false
			for a in fotos[i].get("acciones", []):
				if str(a["accion"]) == "taco": hay = true
			if not hay: continue
			var limpio := true
			var max_salto := 0.0
			var movimiento := 0.0
			for k in range(i - 10, i + 18):
				var f: Dictionary = fotos[k]
				if bool(f.get("reubicacion", false)) or bool(f.get("corte", false)):
					limpio = false
				var a := Vector2(fotos[k - 1]["pelota"]["x"], fotos[k - 1]["pelota"]["y"])
				var b := Vector2(f["pelota"]["x"], f["pelota"]["y"])
				max_salto = maxf(max_salto, a.distance_to(b))
				if k < i: movimiento += a.distance_to(b)
			if limpio and max_salto < 6.0:
				print("TACO semilla+%d tick %d  salto max %.1f  pelota se movio antes %.1f m" % [n, i, max_salto, movimiento])
	quit()
