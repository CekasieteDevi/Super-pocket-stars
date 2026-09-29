extends SceneTree
## Pelota suelta en el área: rebota en alguien sin acción (cambia de rumbo al
## lado de un jugador) o pasa al lado de un delantero sin que la toque.
func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = PrototipoVista.SEMILLA
	var local := Team.generar("A", rng, 0, NivelDivision.potencial(0), "Uruguay", NivelDivision.realizacion(0))
	var visita := Team.generar("B", rng, 1000, NivelDivision.potencial(0), "Uruguay", NivelDivision.realizacion(0))
	var fotos: Array = MotorEspacial.simular(local, visita, rng, true)["fotogramas"]
	for k in range(1, fotos.size() - 1):
		var f: Dictionary = fotos[k]
		if int(f.get("detenido", 0)) > 0 or int(f["pelota"].get("poseedor_id", -1)) != -1: continue
		var b := Vector2(f["pelota"]["x"], f["pelota"]["y"])
		if absf(b.x) < 36.0 or absf(b.y) > 20.0: continue
		var a := Vector2(fotos[k - 1]["pelota"]["x"], fotos[k - 1]["pelota"]["y"])
		var c := Vector2(fotos[k + 1]["pelota"]["x"], fotos[k + 1]["pelota"]["y"])
		var cerca := []
		for j in f["jugadores"]:
			var d := Vector2(j["x"], j["y"]).distance_to(b)
			if d < 1.5: cerca.append("%d%s(%.1f)" % [int(j["id"]), "L" if bool(j["equipo_local"]) else "V", d])
		var giro := 0.0
		if (b - a).length() > 0.2 and (c - b).length() > 0.2:
			giro = rad_to_deg(absf((b - a).angle_to(c - b)))
		var ev := []
		for e in f.get("eventos", []): ev.append("%s/%s" % [e.get("tipo", ""), e.get("resultado", "")])
		var acc := (f.get("acciones", []) as Array).map(func(x): return "%s:%s" % [x["clave"], x["accion"]])
		print("k %d min %d pelota=(%.1f,%.1f) z=%.2f vel=%.1f giro=%.0f cerca=%s ev=%s acc=%s" % [k, int(f.get("minuto", 0)), b.x, b.y, float(f["pelota"].get("z", 0)), (b - a).length() / 0.25, giro, str(cerca), str(ev), str(acc)])
	quit()
