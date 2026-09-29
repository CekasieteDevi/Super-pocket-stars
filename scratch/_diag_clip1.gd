extends SceneTree
func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = PrototipoVista.SEMILLA
	var local := Team.generar("Atlético Prueba", rng)
	var visita := Team.generar("Deportivo Banco", rng, 1000)
	var fotos: Array = MotorEspacial.simular(local, visita, rng, true)["fotogramas"]
	for i in range(int(OS.get_cmdline_user_args()[0]), int(OS.get_cmdline_user_args()[1])):
		var f: Dictionary = fotos[i]
		var p: Dictionary = f["pelota"]
		var acc := []
		for a in f.get("acciones", []):
			acc.append("%s j%s d%s" % [a["accion"], a.get("jugador", a.get("id", "?")), a.get("duracion", "")])
		print(i, " pelota ", snappedf(p["x"],0.1), ",", snappedf(p["y"],0.1), " z=", snappedf(float(p.get("z",0)),0.01), " ", acc, " ", f.get("eventos", []).map(func(e): return e.get("tipo","")))
	quit()
