extends SceneTree
## Offsides y tiros libres directos (con barrera) en más partidos.
func _initialize() -> void:
	var offs := 0
	var directos := 0
	for n in range(0, 40):
		var rng := RandomNumberGenerator.new()
		rng.seed = PrototipoVista.SEMILLA + n
		var local := Team.generar("Atlético Prueba", rng)
		var visita := Team.generar("Deportivo Banco", rng, 1000)
		var fotos: Array = MotorEspacial.simular(local, visita, rng, true)["fotogramas"]
		for k in fotos.size():
			var f: Dictionary = fotos[k]
			for ev in f.get("eventos", []):
				if str(ev.get("tipo", "")) == "offside" and offs < 4:
					offs += 1
					print("OFFSIDE s+%d t%d" % [n, k])
			var det = f.get("detenido", null)
			if det is Dictionary and str(det.get("tipo", "")) == "directo" and directos < 6 \
					and not (fotos[k - 1].get("detenido", null) is Dictionary and str(fotos[k - 1]["detenido"].get("tipo", "")) == "directo"):
				directos += 1
				print("DIRECTO s+%d t%d %s" % [n, k, str(det)])
		if offs >= 4 and directos >= 6:
			break
	if directos == 0:
		# Cómo viene "detenido" en un fotograma cualquiera con juego parado.
		var rng := RandomNumberGenerator.new()
		rng.seed = PrototipoVista.SEMILLA
		var fotos: Array = MotorEspacial.simular(Team.generar("A", rng), Team.generar("B", rng, 1000), rng, true)["fotogramas"]
		for k in fotos.size():
			if fotos[k].get("detenido", false):
				print("EJEMPLO detenido t%d: %s" % [k, str(fotos[k]["detenido"])])
				break
	quit()
