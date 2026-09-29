extends SceneTree
## ¿De dónde salen las frenadas en seco? Recibe la pelota / la pierde / queda
## en su marca (sigue quieto 2 ticks) / da vuelta (sale para otro lado).
func _initialize() -> void:
	var c := {"recibe": 0, "da_pase_o_patea": 0, "accion": 0, "queda_quieto": 0, "da_vuelta": 0, "sigue_despacio": 0}
	for a in OS.get_cmdline_user_args():
		for clave in ["frenada", "giro_acel", "arranque_extra"]:
			if a.begins_with(clave + "="): MotorEspacial.pesos()["fisica"][clave] = float(a.trim_prefix(clave + "="))
	for n in 3:
		var rng := RandomNumberGenerator.new()
		rng.seed = PrototipoVista.SEMILLA + n
		var d := 0
		var local := Team.generar("Atlético Prueba", rng, 0, NivelDivision.potencial(d), "Uruguay", NivelDivision.realizacion(d))
		var visita := Team.generar("Deportivo Banco", rng, 1000, NivelDivision.potencial(d), "Uruguay", NivelDivision.realizacion(d))
		var fotos: Array = MotorEspacial.simular(local, visita, rng, true)["fotogramas"]
		for k in range(2, fotos.size() - 3):
			var ok := true
			for q in range(k - 2, k + 3):
				if int(fotos[q].get("detenido", 0)) > 0 or bool(fotos[q].get("reubicacion", false)): ok = false
			if not ok: continue
			var pos := func(q: int, id) -> Vector2:
				var j := VistaPartido._jugador_en(fotos[q], int(id))
				return Vector2(j["x"], j["y"]) if not j.is_empty() else Vector2.INF
			for j in fotos[k]["jugadores"]:
				var id = j["id"]
				var a: Vector2 = pos.call(k - 2, id); var b: Vector2 = pos.call(k - 1, id); var p: Vector2 = pos.call(k, id)
				var s1: Vector2 = pos.call(k + 1, id); var s2: Vector2 = pos.call(k + 2, id)
				if Vector2.INF in [a, b, s1, s2]: continue
				var v1 := b.distance_to(a) / 0.25; var v2 := p.distance_to(b) / 0.25
				if not (v1 > 4.0 and v2 < 0.8): continue
				var acciones := (fotos[k].get("acciones", []) as Array) + (fotos[k - 1].get("acciones", []) as Array)
				var dueno_ahora := int(fotos[k]["pelota"].get("poseedor_id", -1))
				var dueno_antes := int(fotos[k - 1]["pelota"].get("poseedor_id", -1))
				if dueno_ahora == int(id) and dueno_antes != int(id): c["recibe"] += 1
				elif dueno_antes == int(id) and dueno_ahora != int(id): c["da_pase_o_patea"] += 1
				elif acciones.any(func(x): return int(x["clave"]) == int(id)): c["accion"] += 1
				else:
					var v3 := s1.distance_to(p) / 0.25; var v4 := s2.distance_to(s1) / 0.25
					var ida := (b - a).normalized(); var vuelta := (s2 - p).normalized()
					if v3 < 0.8 and v4 < 0.8: c["queda_quieto"] += 1
					elif v4 > 2.0 and ida.dot(vuelta) < 0.0: c["da_vuelta"] += 1
					else: c["sigue_despacio"] += 1
	print("FRENADAS 3 partidos: ", c)
	quit()
