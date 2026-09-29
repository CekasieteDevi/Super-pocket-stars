extends SceneTree
func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = PrototipoVista.SEMILLA
	var d := 0
	var local := Team.generar("Atlético Prueba", rng, 0, NivelDivision.potencial(d), "Uruguay", NivelDivision.realizacion(d))
	var visita := Team.generar("Deportivo Banco", rng, 1000, NivelDivision.potencial(d), "Uruguay", NivelDivision.realizacion(d))
	var fotos: Array = MotorEspacial.simular(local, visita, rng, true)["fotogramas"]
	var tipos := {}
	var n := 0
	for k in range(2, fotos.size()):
		var a := int(fotos[k - 1]["pelota"].get("poseedor_id", -1))
		var b := int(fotos[k]["pelota"].get("poseedor_id", -1))
		# también con un tick suelta en el medio
		if b == -1: continue
		var previo := a
		if a == -1: previo = int(fotos[k - 2]["pelota"].get("poseedor_id", -1))
		if previo == -1 or previo == b: continue
		var ja := VistaPartido._jugador_en(fotos[k - 1], previo)
		var jb := VistaPartido._jugador_en(fotos[k], b)
		if ja.is_empty() or jb.is_empty() or bool(ja["equipo_local"]) == bool(jb["equipo_local"]): continue
		var dist := Vector2(ja["x"], ja["y"]).distance_to(Vector2(jb["x"], jb["y"]))
		var ev := []
		for e in (fotos[k].get("eventos", []) as Array) + (fotos[k - 1].get("eventos", []) as Array): ev.append("%s/%s" % [e.get("tipo", ""), e.get("resultado", "")])
		var ac := ((fotos[k].get("acciones", []) as Array) + (fotos[k - 1].get("acciones", []) as Array)).map(func(x): return str(x["accion"]))
		var clave := "%s d<2=%s suelta=%s ev=%s acc=%s" % ["", dist < 2.0, a == -1, str(ev), str(ac)]
		tipos[clave] = int(tipos.get(clave, 0)) + 1
		n += 1
	var lista := tipos.keys()
	lista.sort_custom(func(x, y): return tipos[x] > tipos[y])
	print("CAMBIOS DE EQUIPO ", n)
	for kk in lista.slice(0, 14): print("  ", tipos[kk], " ", kk)
	quit()
