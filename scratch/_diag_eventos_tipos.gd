extends SceneTree
func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = PrototipoVista.SEMILLA
	var d := 0
	var local := Team.generar("Atlético Prueba", rng, 0, NivelDivision.potencial(d), "Uruguay", NivelDivision.realizacion(d))
	var visita := Team.generar("Deportivo Banco", rng, 1000, NivelDivision.potencial(d), "Uruguay", NivelDivision.realizacion(d))
	var fotos: Array = MotorEspacial.simular(local, visita, rng, true)["fotogramas"]
	var tipos := {}
	for k in fotos.size():
		for e in fotos[k].get("eventos", []):
			var ac := (fotos[k].get("acciones", []) as Array).map(func(x): return str(x["accion"]))
			var c := "%s/%s acc=%s" % [e.get("tipo", ""), e.get("resultado", ""), str(ac)]
			tipos[c] = int(tipos.get(c, 0)) + 1
	var lista := tipos.keys()
	lista.sort_custom(func(x, y): return tipos[x] > tipos[y])
	for kk in lista.slice(0, 30): print("  ", tipos[kk], " ", kk)
	quit()
