extends SceneTree
## Velocidad del que recibe, tick a tick desde que la recibe (juego corriendo),
## y de los que dan vuelta (de >4 m/s a sentido contrario).
func _initialize() -> void:
	var suma := []; suma.resize(10); suma.fill(0.0)
	var cuenta := 0
	var vuelta := []; vuelta.resize(8); vuelta.fill(0.0)
	var n_vuelta := 0
	for a in OS.get_cmdline_user_args():
		for clave in ["frenada", "giro_acel", "arranque_extra"]:
			if a.begins_with(clave + "="): MotorEspacial.pesos()["fisica"][clave] = float(a.trim_prefix(clave + "="))
	for m in 3:
		var rng := RandomNumberGenerator.new()
		rng.seed = PrototipoVista.SEMILLA + m
		var local := Team.generar("A", rng, 0, NivelDivision.potencial(0), "Uruguay", NivelDivision.realizacion(0))
		var visita := Team.generar("B", rng, 1000, NivelDivision.potencial(0), "Uruguay", NivelDivision.realizacion(0))
		var fotos: Array = MotorEspacial.simular(local, visita, rng, true)["fotogramas"]
		var pos := func(q: int, id: int) -> Vector2:
			var j := VistaPartido._jugador_en(fotos[q], id)
			return Vector2(j["x"], j["y"]) if not j.is_empty() else Vector2.INF
		for k in range(2, fotos.size() - 11):
			var ok := true
			for q in range(k - 2, k + 11):
				if int(fotos[q].get("detenido", 0)) > 0 or bool(fotos[q].get("reubicacion", false)): ok = false
			if not ok: continue
			var d := int(fotos[k]["pelota"].get("poseedor_id", -1))
			if d != -1 and d != int(fotos[k - 1]["pelota"].get("poseedor_id", -1)):
				var bien := true
				var v := []
				for i in 10:
					var a: Vector2 = pos.call(k + i, d); var b: Vector2 = pos.call(k + i + 1, d)
					if a == Vector2.INF or b == Vector2.INF or int(fotos[k + i + 1]["pelota"].get("poseedor_id", -1)) != d: bien = false; break
					v.append(a.distance_to(b) / 0.25)
				if bien:
					cuenta += 1
					for i in 10: suma[i] += v[i]
			for j in fotos[k]["jugadores"]:
				var id := int(j["id"])
				var a: Vector2 = pos.call(k - 2, id); var b: Vector2 = pos.call(k - 1, id); var p: Vector2 = pos.call(k, id)
				if Vector2.INF in [a, b, p]: continue
				var ida := b - a; var sale := p - b
				if ida.length() / 0.25 > 4.0 and sale.length() > 0.05 and ida.normalized().dot(sale.normalized()) < -0.5:
					n_vuelta += 1
					for i in 8:
						var x: Vector2 = pos.call(k - 2 + i, id); var y: Vector2 = pos.call(k - 1 + i, id)
						if x != Vector2.INF and y != Vector2.INF: vuelta[i] += (y - x).dot(ida.normalized()) / 0.25
	var perfil := []
	for i in 10: perfil.append("%.1f" % (suma[i] / maxf(cuenta, 1)))
	var pv := []
	for i in 8: pv.append("%.1f" % (vuelta[i] / maxf(n_vuelta, 1)))
	print("ARRANQUE (m/s por tick desde que la recibe, n=%d): %s" % [cuenta, ", ".join(perfil)])
	print("VUELTA (m/s a lo largo de la ida, n=%d por partido %.0f): %s" % [n_vuelta, n_vuelta / 3.0, ", ".join(pv)])
	quit()
