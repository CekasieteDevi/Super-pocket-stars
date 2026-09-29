extends SceneTree
func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = PrototipoVista.SEMILLA
	var d := 0
	var local := Team.generar("Atlético Prueba", rng, 0, NivelDivision.potencial(d), "Uruguay", NivelDivision.realizacion(d))
	var visita := Team.generar("Deportivo Banco", rng, 1000, NivelDivision.potencial(d), "Uruguay", NivelDivision.realizacion(d))
	var r := MotorEspacial.simular(local, visita, rng, true)
	var fotos: Array = r["fotogramas"]
	for k in range(640, 660):
		var f: Dictionary = fotos[k]
		var b := Vector2(f["pelota"]["x"], f["pelota"]["y"])
		var cerca := []
		for j in f["jugadores"]:
			var p := Vector2(j["x"], j["y"])
			if p.distance_to(b) < 12.0:
				cerca.append("%s%s(%.1f,%.1f)" % [str(j["id"]), "L" if bool(j["equipo_local"]) else "V", p.x, p.y])
		var ev := []
		for e in f.get("eventos", []): ev.append("%s/%s" % [e.get("tipo", ""), e.get("resultado", "")])
		print("%d det=%s pelota=(%.2f,%.2f,z=%.2f) pos=%s ev=%s acc=%s cerca=%s" % [k, str(f.get("detenido", "")), b.x, b.y, float(f["pelota"].get("z", 0)), str(f["pelota"].get("poseedor_id", "")), str(ev),
			str((f.get("acciones", []) as Array).map(func(a): return "%s:%s" % [a["clave"], a["accion"]])), " ".join(cerca)])
	quit()
