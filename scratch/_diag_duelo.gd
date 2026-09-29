extends SceneTree
## Tramo del partido del prototipo 3D, tick a tick:
##   -- division=1 semilla=N desde=MIN hasta=MIN
func _initialize() -> void:
	var division := -1
	var desde := 8
	var hasta := 10
	var rng := RandomNumberGenerator.new()
	rng.seed = PrototipoVista.SEMILLA
	for a in OS.get_cmdline_user_args():
		if a.begins_with("division="): division = int(a.trim_prefix("division=")) - 1
		if a.begins_with("semilla="): rng.seed = int(a.trim_prefix("semilla="))
		if a.begins_with("desde="): desde = int(a.trim_prefix("desde="))
		if a.begins_with("hasta="): hasta = int(a.trim_prefix("hasta="))
		if a == "viejo":
			MotorEspacial.pesos()["fisica"]["un_corte_por_vuelo"] = 0
			MotorEspacial.pesos()["fisica"]["cambio_por_abajo"] = 0
			MotorEspacial.pesos()["fisica"]["arquero_tendido_ticks"] = 0
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
	for i in fs.size():
		var f: Dictionary = fs[i]
		var m := int(f["minuto"])
		if m < desde or m > hasta: continue
		var p: Dictionary = f["pelota"]
		var bp := Vector2(float(p["x"]), float(p["y"]))
		var cerca := []
		for j in f["jugadores"]:
			var d := Vector2(float(j["x"]), float(j["y"])).distance_to(bp)
			if d < 6.0:
				cerca.append("%s%d(%.1f)" % ["L" if j["equipo_local"] else "V", int(j["id"]), d])
		var acc := []
		for a in f.get("acciones", []):
			acc.append("%s:%d" % [a["accion"], int(a["clave"])])
		var ev := []
		for e in f.get("eventos", []):
			ev.append(str(e))
		print("t%d m%d det%d pel(%.1f,%.1f,%.1f) pos=%s pase=%s | %s | acc %s | ev %s" % [i, m, int(f.get("detenido", 0)), bp.x, bp.y, float(p.get("z", 0.0)), str(p["poseedor_id"]), str(p["es_pase"]), " ".join(cerca), " ".join(acc), " ".join(ev)])
	quit()
