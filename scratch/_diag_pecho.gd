extends SceneTree
## Recepciones de pecho/control en el partido del prototipo 3D:
##   -- division=1 [semilla=N]
## Para cada una, la altura de la pelota (z del motor) en los 4 ticks previos.
## PECHO_RASO = pecho con la pelota abajo de 0.5 m en esos ticks.
func _initialize() -> void:
	var division := -1
	var rng := RandomNumberGenerator.new()
	rng.seed = PrototipoVista.SEMILLA
	for a in OS.get_cmdline_user_args():
		if a.begins_with("division="): division = int(a.trim_prefix("division=")) - 1
		if a.begins_with("semilla="): rng.seed = int(a.trim_prefix("semilla="))
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
	var cuenta := {}
	for i in fs.size():
		for a in fs[i].get("acciones", []):
			var acc := str(a["accion"])
			if acc not in ["pecho", "control_pie"]: continue
			var zs := []
			var zmax := 0.0
			for k in range(maxi(0, i - 4), i + 1):
				var z := float(fs[k]["pelota"].get("z", 0.0))
				zs.append("%.2f" % z)
				zmax = maxf(zmax, z)
			var tipo := acc + ("_RASO" if zmax < 0.5 else "_ALTO")
			cuenta[tipo] = int(cuenta.get(tipo, 0)) + 1
			print("%s tick %d min %d clave %d z %s" % [tipo, i, int(fs[i]["minuto"]), int(a["clave"]), " ".join(zs)])
	print("RESUMEN ", cuenta)
	quit()
