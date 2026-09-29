extends SceneTree
## Centros que caen y se controlan después (3D-09), en el partido del
## prototipo 3D:
##   -- division=1 semilla=5 [viejo]
## Por cada control del motor (control_pie) de una pelota que venía por arriba
## y cayó antes de que la tome: tick de la caída, ticks rodando, distancia del
## receptor a la pelota en cada tick y las claves de la pelota.
func _initialize() -> void:
	var division := -1
	var rng := RandomNumberGenerator.new()
	rng.seed = PrototipoVista.SEMILLA
	for a in OS.get_cmdline_user_args():
		if a.begins_with("division="): division = int(a.trim_prefix("division=")) - 1
		if a.begins_with("semilla="): rng.seed = int(a.trim_prefix("semilla="))
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
	for k in range(1, fs.size()):
		for a in fs[k].get("acciones", []):
			if str(a["accion"]) not in ["control_pie", "pecho"]:
				continue
			var c := int(a["clave"])
			var zmax := 0.0
			for q in range(maxi(0, k - 8), k + 1):
				zmax = maxf(zmax, float(fs[q]["pelota"].get("z", 0.0)))
			if zmax < 1.4:
				continue
			var linea := "%s c%d t%d m%d zmax %.1f |" % [a["accion"], c, k, int(fs[k]["minuto"]), zmax]
			for q in range(maxi(0, k - 7), mini(fs.size(), k + 2)):
				var p: Dictionary = fs[q]["pelota"]
				var j := VistaPartido._jugador_en(fs[q], c)
				var d := -1.0
				var jp := Vector2.ZERO
				if not j.is_empty():
					jp = Vector2(j["x"], j["y"])
					d = jp.distance_to(Vector2(p["x"], p["y"]))
				linea += " t%d(%.1f,%.1f z%.1f pos%d d%.1f r(%.1f,%.1f))" % [q, float(p["x"]), float(p["y"]),
					float(p.get("z", 0.0)), int(p.get("poseedor_id", -1)), d, jp.x, jp.y]
			print(linea)
			var claves: Array = fs[k - 1]["pelota"].keys()
			print("   claves ", claves)
	quit()
