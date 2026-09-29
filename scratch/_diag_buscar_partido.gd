extends SceneTree
## Minutos de palos/travesaños y pechos, para identificar qué partido se vio:
##   [-- division=N] [semilla=N]
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
	var palos := []
	var pechos := []
	for f in r["fotogramas"]:
		for e in f.get("eventos", []):
			var s := str(e)
			if s.contains("travesano") or s.contains("\"palo\""):
				palos.append(int(f["minuto"]))
		for a in f.get("acciones", []):
			if str(a["accion"]) == "pecho": pechos.append(int(f["minuto"]))
	print("PARTIDO %d-%d palos %s pechos %s" % [r["goles_local"], r["goles_visitante"], str(palos), str(pechos)])
	quit()
