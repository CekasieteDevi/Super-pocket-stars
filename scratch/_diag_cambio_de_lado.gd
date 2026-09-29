extends SceneTree
## 3D-12: en el segundo tiempo el fotograma sale girado. Imprime, por
## periodo, el giro y dónde está el arquero local (x promedio).
##   -- division=1 semilla=5
func _initialize() -> void:
	var division := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = PrototipoVista.SEMILLA
	for a in OS.get_cmdline_user_args():
		if a.begins_with("division="): division = int(a.trim_prefix("division=")) - 1
		if a.begins_with("semilla="): rng.seed = int(a.trim_prefix("semilla="))
	var local := Team.generar("A", rng, 0, NivelDivision.potencial(division), "Uruguay", NivelDivision.realizacion(division))
	var visita := Team.generar("B", rng, 1000, NivelDivision.potencial(division), "Uruguay", NivelDivision.realizacion(division))
	var r := MotorEspacial.simular(local, visita, rng, true)
	var por_periodo := {}
	for f in r["fotogramas"]:
		var p := int(f.get("periodo", 1))
		if not por_periodo.has(p): por_periodo[p] = {"giro": {}, "x": 0.0, "n": 0, "cambios_y": []}
		var d: Dictionary = por_periodo[p]
		d["giro"][float(f.get("giro", 1.0))] = true
		for j in f["jugadores"]:
			if bool(j["equipo_local"]) and str(j["rol"]) == "ARQ":
				d["x"] = float(d["x"]) + float(j["x"])
				d["n"] = int(d["n"]) + 1
		if f["foco"] != null:
			d["cambios_y"].append(signf(float(f["foco"]["y"])))
	for p in por_periodo:
		var d: Dictionary = por_periodo[p]
		var ys := {}
		for y in d["cambios_y"]: ys[y] = int(ys.get(y, 0)) + 1
		print("PERIODO %d giro %s arquero local x %.1f | foco de cambios por y %s" % [p, str(d["giro"].keys()), float(d["x"]) / maxi(1, int(d["n"])), str(ys)])
	quit()
