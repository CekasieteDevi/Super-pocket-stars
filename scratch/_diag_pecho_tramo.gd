extends SceneTree
## Tramo de fotogramas del partido del prototipo: -- division=1 desde=T hasta=T
func _initialize() -> void:
	var division := -1
	var desde := 0
	var hasta := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = PrototipoVista.SEMILLA
	for a in OS.get_cmdline_user_args():
		if a.begins_with("division="): division = int(a.trim_prefix("division=")) - 1
		if a.begins_with("semilla="): rng.seed = int(a.trim_prefix("semilla="))
		if a.begins_with("desde="): desde = int(a.trim_prefix("desde="))
		if a.begins_with("hasta="): hasta = int(a.trim_prefix("hasta="))
	var local: Team
	var visita: Team
	if division >= 0:
		local = Team.generar("Atlético Prueba", rng, 0, NivelDivision.potencial(division), "Uruguay", NivelDivision.realizacion(division))
		visita = Team.generar("Deportivo Banco", rng, 1000, NivelDivision.potencial(division), "Uruguay", NivelDivision.realizacion(division))
	else:
		local = Team.generar("Atlético Prueba", rng)
		visita = Team.generar("Deportivo Banco", rng, 1000)
	var r := MotorEspacial.simular(local, visita, rng, true)
	var fs: Array = r["fotogramas"]
	for i in range(desde, mini(hasta + 1, fs.size())):
		var f: Dictionary = fs[i]
		var p: Dictionary = f["pelota"]
		var ev := []
		for e in f.get("eventos", []): ev.append(str(e.get("tipo", "?")))
		print("t%d m%d det%d | pelota (%.1f,%.1f) z%.2f dueño %d pase %s | acc %s | ev %s | dec %s" % [i, int(f["minuto"]), int(f.get("detenido", 0)),
			float(p["x"]), float(p["y"]), float(p["z"]), int(p["poseedor_id"]), str(p["es_pase"]),
			str(f.get("acciones", [])), str(ev), str(f.get("decision", null)).substr(0, 120)])
	quit()
