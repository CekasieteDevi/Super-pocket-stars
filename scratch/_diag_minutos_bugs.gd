extends SceneTree
## Momentos de los bugs de BUGS_1.1.00.md en el partido del prototipo 3D:
##   -- division=1 semilla=5 [viejo]
## viejo = sin un_corte_por_vuelo (el partido de antes del arreglo 3D-02).
## Lista palos, centros (y el control que les sigue) y saques del arquero
## por el aire, con tick y minuto.
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
			MotorEspacial.pesos()["fisica"]["desvio_lo_toca_el_defensor"] = 0
			MotorEspacial.pesos()["fisica"]["cambio_de_lado"] = 0
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
	print("TICKS ", fs.size(), " GOLES ", fs[-1]["goles"])
	for i in fs.size():
		var f: Dictionary = fs[i]
		var m := int(f["minuto"])
		for e in f.get("eventos", []):
			var t := str(e.get("tipo", ""))
			if t in ["palo", "gol", "centro", "afuera", "atajada", "tiro"]:
				print("EV %s t%d m%d %s" % [t, i, m, str(e)])
		var roles := {}
		for j in f["jugadores"]: roles[int(j["id"])] = str(j["rol"])
		for a in f.get("acciones", []):
			var acc := str(a["accion"])
			var rol := str(roles.get(int(a["clave"]), ""))
			if acc in ["pecho", "control_pie"]:
				var zmax := 0.0
				for k in range(maxi(0, i - 6), i + 1): zmax = maxf(zmax, float(fs[k]["pelota"].get("z", 0.0)))
				if zmax > 1.0: print("REC %s t%d m%d zmax6 %.1f" % [acc, i, m, zmax])
			if rol == "ARQ" and acc in ["patea", "saque_arco"]:
				var zmax := 0.0
				for k in range(i, mini(fs.size(), i + 15)): zmax = maxf(zmax, float(fs[k]["pelota"].get("z", 0.0)))
				if zmax > 3.0: print("ARQ %s t%d m%d zmax %.1f" % [acc, i, m, zmax])
	quit()
