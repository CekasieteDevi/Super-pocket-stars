extends SceneTree
## Estiradas que terminan en agarre (3D-08): tick de la estirada, del agarre,
## hasta cuándo la tiene en las manos y con qué la juega.
##   -- division=1 semilla=5
func _initialize() -> void:
	var division := 0
	var semilla := PrototipoVista.SEMILLA
	for a in OS.get_cmdline_user_args():
		if a.begins_with("division="): division = int(a.trim_prefix("division=")) - 1
		if a.begins_with("semilla="): semilla = int(a.trim_prefix("semilla="))
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var local := Team.generar("Atlético Prueba", rng, 0, NivelDivision.potencial(division), "Uruguay", NivelDivision.realizacion(division))
	var visita := Team.generar("Deportivo Banco", rng, 1000, NivelDivision.potencial(division), "Uruguay", NivelDivision.realizacion(division))
	var fs: Array = MotorEspacial.simular(local, visita, rng, true)["fotogramas"]
	var ultima_vuela := {}
	var n := 0
	for k in fs.size():
		for a in fs[k].get("acciones", []):
			var c := int(a["clave"])
			if str(a["accion"]) == MotorEspacial.ACCION_VUELA:
				if not ultima_vuela.has(c) or k - int(ultima_vuela[c][1]) > 1:
					ultima_vuela[c] = [k, k]
				else:
					ultima_vuela[c][1] = k
			elif str(a["accion"]) == MotorEspacial.ACCION_AGARRA:
				var fin := k
				while fin + 1 < fs.size() and int(fs[fin + 1]["pelota"].get("poseedor_id", -1)) == c:
					fin += 1
				var sale := []
				for s in range(fin, mini(fin + 2, fs.size())):
					for b in fs[s].get("acciones", []):
						if int(b["clave"]) == c: sale.append("%s@%d" % [b["accion"], s])
				var v: Array = ultima_vuela.get(c, [-99, -99])
				var tag := "CON_ESTIRADA" if k - int(v[0]) <= 6 else "sin"
				if tag == "CON_ESTIRADA": n += 1
				print("AGARRE %s arq %d tick %d (min %d) vuela %d..%d | tiene hasta %d (%d ticks) | sale %s | detenido %d" % [tag, c, k, int(fs[k].get("minuto", 0)), v[0], v[1], fin, fin - k, str(sale), int(fs[fin].get("detenido", 0))])
	print("TOTAL con estirada: %d" % n)
	quit()
