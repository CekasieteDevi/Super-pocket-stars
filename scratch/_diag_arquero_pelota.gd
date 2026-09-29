extends SceneTree
## Qué hace el arquero con la pelota en las manos: -- division=N [semilla=N]
func _initialize() -> void:
	var division := 0
	var semilla := PrototipoVista.SEMILLA
	for a in OS.get_cmdline_user_args():
		if a.begins_with("division="): division = int(a.trim_prefix("division=")) - 1
		if a.begins_with("semilla="): semilla = int(a.trim_prefix("semilla="))
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var local := Team.generar("Atlético Prueba", rng, 0, NivelDivision.potencial(division), "Uruguay", NivelDivision.realizacion(division))
	var visita := Team.generar("Deportivo Banco", rng, 1000, NivelDivision.potencial(division), "Uruguay", NivelDivision.realizacion(division))
	var r := MotorEspacial.simular(local, visita, rng, true)
	var fs: Array = r["fotogramas"]
	var arqs := {}
	for j in fs[0]["jugadores"]:
		if str(j.get("rol", "")) == "ARQ": arqs[int(j["id"])] = true
	print("ARQS ", arqs.keys())
	var desde := -1
	var dueno := -1
	for k in fs.size():
		var f: Dictionary = fs[k]
		var p := int(f["pelota"].get("poseedor_id", -1))
		for a in f.get("acciones", []):
			if arqs.has(int(a["clave"])):
				var b1: Dictionary = fs[mini(k + 4, fs.size() - 1)]["pelota"]
				var viaje := Vector2(b1["x"], b1["y"]).distance_to(Vector2(f["pelota"]["x"], f["pelota"]["y"]))
				var zmax := 0.0
				for kk in range(k, mini(k + 12, fs.size())): zmax = maxf(zmax, float(fs[kk]["pelota"].get("z", 0.0)))
				print("  tick %d ACC %s arq %d | z %.2f det %s pase %s | 4 ticks: %.1f m, zmax %.1f, dueno_antes %d" % [k, a["accion"], int(a["clave"]), float(f["pelota"].get("z", 0.0)), str(f.get("detenido", 0)), str(f["pelota"].get("es_pase", false)), viaje, zmax, int(fs[k-1]["pelota"].get("poseedor_id", -1))])
		if p != dueno:
			if arqs.has(dueno):
				print("ARQ %d tuvo la pelota %d ticks (%d-%d) det_inicio %s" % [dueno, k - desde, desde, k, str(fs[desde].get("detenido", 0))])
			dueno = p
			desde = k
	quit()
