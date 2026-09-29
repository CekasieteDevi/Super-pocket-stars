extends SceneTree
func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = PrototipoVista.SEMILLA
	var d := 0
	var local := Team.generar("Atlético Prueba", rng, 0, NivelDivision.potencial(d), "Uruguay", NivelDivision.realizacion(d))
	var visita := Team.generar("Deportivo Banco", rng, 1000, NivelDivision.potencial(d), "Uruguay", NivelDivision.realizacion(d))
	var r := MotorEspacial.simular(local, visita, rng, true)
	var fotos: Array = r["fotogramas"]
	var desde := 745
	var hasta := 800
	for a in OS.get_cmdline_user_args():
		if a.begins_with("desde="): desde = int(a.trim_prefix("desde="))
		if a.begins_with("hasta="): hasta = int(a.trim_prefix("hasta="))
	var ids := {}
	for k in range(desde, hasta):
		for c in fotos[k].get("cambios", []):
			ids[int(c["saliente_clave"])] = "sale"
			ids[int(c["entrante_clave"])] = "entra"
	print("ids ", ids)
	for k in range(desde, hasta):
		var f: Dictionary = fotos[k]
		var txt := ""
		for j in f["jugadores"]:
			if ids.has(int(j["id"])):
				txt += " %s:%s(%.1f,%.1f)" % [ids[int(j["id"])], str(j["id"]), j["x"], j["y"]]
		var ev := []
		for e in f.get("eventos", []): ev.append("%s/%s" % [e.get("tipo", ""), e.get("resultado", "")])
		print("%d det=%s reub=%s foco=%s cambios=%d n=%d%s ev=%s pelota=(%.1f,%.1f)" % [k, str(f.get("detenido", "")), str(f.get("reubicacion", false)), str(f.get("foco", null)), (f.get("cambios", []) as Array).size(), (f["jugadores"] as Array).size(), txt, str(ev), f["pelota"]["x"], f["pelota"]["y"]])
	quit()
