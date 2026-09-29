extends SceneTree
## Acciones, eventos y pelota del motor en unos ticks: -- division=1 [semilla=N] ticks=a,b,c [radio=2]
func _initialize() -> void:
	var division := 0
	var semilla := PrototipoVista.SEMILLA
	var ticks: Array = []
	var radio := 2
	for a in OS.get_cmdline_user_args():
		if a.begins_with("division="): division = int(a.trim_prefix("division=")) - 1
		if a.begins_with("semilla="): semilla = int(a.trim_prefix("semilla="))
		if a.begins_with("radio="): radio = int(a.trim_prefix("radio="))
		if a.begins_with("ticks="):
			for s in a.trim_prefix("ticks=").split(","): ticks.append(int(s))
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var local := Team.generar("Atlético Prueba", rng, 0, NivelDivision.potencial(division), "Uruguay", NivelDivision.realizacion(division))
	var visita := Team.generar("Deportivo Banco", rng, 1000, NivelDivision.potencial(division), "Uruguay", NivelDivision.realizacion(division))
	var fs: Array = MotorEspacial.simular(local, visita, rng, true)["fotogramas"]
	for t in ticks:
		for k in range(maxi(0, t - radio), mini(fs.size(), t + radio + 1)):
			var f: Dictionary = fs[k]
			var ev := []
			for e in f.get("eventos", []): ev.append(str(e.get("tipo", "")))
			print("T %d det %d pelota(%.1f,%.1f) z %.1f pos %d acc %s ev %s" % [k, int(f.get("detenido", 0)), f["pelota"]["x"], f["pelota"]["y"], float(f["pelota"].get("z", 0.0)), int(f["pelota"].get("poseedor_id", -1)), str(f.get("acciones", [])), str(ev)])
	quit()
