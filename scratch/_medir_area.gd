extends SceneTree
## Qué pasa cuando un jugador tiene la pelota en el área rival: remata, pasa,
## la pierde, se le escapa (rebota sin acción) o se la queda sin hacer nada.
func _initialize() -> void:
	var n := 12
	for a in OS.get_cmdline_user_args():
		for clave in ["frenada", "giro_acel", "arranque_extra"]:
			if a.begins_with(clave + "="): MotorEspacial.pesos()["fisica"][clave] = float(a.trim_prefix(clave + "="))
		if a.begins_with("n="): n = int(a.trim_prefix("n="))
	var c := {"remata": 0, "pasa": 0, "la_pierde": 0, "suelta_sin_accion": 0, "ticks_en_area": 0, "posesiones": 0}
	for m in n:
		var rng := RandomNumberGenerator.new()
		rng.seed = 424200 + m
		if n == 1:
			rng.seed = PrototipoVista.SEMILLA
		var local := Team.generar("A", rng, 0, NivelDivision.potencial(0), "Uruguay", NivelDivision.realizacion(0))
		var visita := Team.generar("B", rng, 1000, NivelDivision.potencial(0), "Uruguay", NivelDivision.realizacion(0))
		var fotos: Array = MotorEspacial.simular(local, visita, rng, true)["fotogramas"]
		var k := 1
		while k < fotos.size() - 1:
			var d := int(fotos[k]["pelota"].get("poseedor_id", -1))
			var j := VistaPartido._jugador_en(fotos[k], d) if d != -1 else {}
			if j.is_empty() or int(fotos[k].get("detenido", 0)) > 0:
				k += 1; continue
			var ataca := MotorEspacial.arco_rival(bool(j["equipo_local"]))
			var p := Vector2(j["x"], j["y"])
			if absf(p.x - ataca.x) > 16.5 or absf(p.y) > 20.0:
				k += 1; continue
			c["posesiones"] += 1
			var q := k
			while q < fotos.size() - 1 and int(fotos[q]["pelota"].get("poseedor_id", -1)) == d:
				q += 1
			c["ticks_en_area"] += q - k
			var acc := []
			for z in range(k, mini(q + 1, fotos.size())):
				for a in fotos[z].get("acciones", []):
					if int(a["clave"]) == d: acc.append(str(a["accion"]))
			var nuevo := int(fotos[q]["pelota"].get("poseedor_id", -1))
			var es_remate := bool(fotos[q]["pelota"].get("es_remate", false)) or acc.has("patea") and bool(fotos[mini(q + 1, fotos.size() - 1)]["pelota"].get("es_remate", false))
			var tipo := "remata" if es_remate else ("pasa" if bool(fotos[q]["pelota"].get("es_pase", false)) else ("suelta_sin_accion" if acc.is_empty() else "la_pierde"))
			if n == 1: print("  tick %d-%d min %d id %d %s acc=%s nuevo=%d" % [k, q, int(fotos[k].get("minuto", 0)), d, tipo, str(acc), nuevo])
			if es_remate: c["remata"] += 1
			elif bool(fotos[q]["pelota"].get("es_pase", false)): c["pasa"] += 1
			elif acc.is_empty(): c["suelta_sin_accion"] += 1
			else: c["la_pierde"] += 1
			k = q + 1
	print("AREA ", c, " ticks por posesion %.1f" % [float(c["ticks_en_area"]) / maxf(c["posesiones"], 1)])
	quit()
