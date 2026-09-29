extends SceneTree
## Eventos y "detenido" de los primeros cuadros de un tiro libre del Laboratorio.
func _initialize() -> void:
	var s := int(OS.get_cmdline_user_args()[0])
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	var casa := Team.generar("Atlético Prueba", rng)
	var visita := Team.generar("Deportivo Banco", rng, 1000)
	var fotos: Array = Laboratorio.generar("tiro_libre", casa, visita, rng)["fotogramas"]
	for k in range(0, 24):
		var f: Dictionary = fotos[k]
		print("%d det=%s reub=%s ev=%s acc=%s" % [k, str(f.get("detenido")), str(f.get("reubicacion")),
			f.get("eventos", []).map(func(e): return str(e.get("tipo", ""))),
			f.get("acciones", []).map(func(a): return str(a["accion"]) + "@" + str(a["clave"]))])
	quit()
