extends SceneTree
## Cuántas veces aparece cada acción en el partido del prototipo: -- division=N
func _initialize() -> void:
	for division in [-1, 0]:
		var rng := RandomNumberGenerator.new()
		rng.seed = PrototipoVista.SEMILLA
		var local: Team
		var visita: Team
		if division >= 0:
			local = Team.generar("Atlético Prueba", rng, 0, NivelDivision.potencial(division), "Uruguay", NivelDivision.realizacion(division))
			visita = Team.generar("Deportivo Banco", rng, 1000, NivelDivision.potencial(division), "Uruguay", NivelDivision.realizacion(division))
		else:
			local = Team.generar("Atlético Prueba", rng)
			visita = Team.generar("Deportivo Banco", rng, 1000)
		var r := MotorEspacial.simular(local, visita, rng, true)
		var cuenta := {}
		var efecto := 0
		for f in r["fotogramas"]:
			for a in f.get("acciones", []):
				cuenta[str(a["accion"])] = int(cuenta.get(str(a["accion"]), 0)) + 1
			for e in f.get("eventos", []):
				if bool(e.get("con_efecto", false)): efecto += 1
		print("DIVISION %s: %s | tiros con efecto %d" % ["azar" if division < 0 else str(division + 1), str(cuenta), efecto])
	quit()
