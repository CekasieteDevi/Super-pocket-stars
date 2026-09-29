extends SceneTree
## Lista goles, lesiones y caídas de un partido y el gesto de cada equipo:
##   -- division=1 semilla=5
const SEED := 5

func _initialize() -> void:
	var division := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for a in OS.get_cmdline_user_args():
		if a.begins_with("division="): division = int(a.trim_prefix("division=")) - 1
		if a.begins_with("semilla="): rng.seed = int(a.trim_prefix("semilla="))
	var local := Team.generar("Atlético Prueba", rng, 0, NivelDivision.potencial(division), "Uruguay", NivelDivision.realizacion(division))
	var visita := Team.generar("Deportivo Banco", rng, 1000, NivelDivision.potencial(division), "Uruguay", NivelDivision.realizacion(division))
	var r := MotorEspacial.simular(local, visita, rng, true)
	var fs: Array = r["fotogramas"]
	var datos := GestosCara.preparar(fs, local.nombre)
	print("RESULTADO %d-%d ticks %d" % [r["goles_local"], r["goles_visitante"], fs.size()])
	print("GOLES ", datos["goles"])
	print("LESIONES ", datos["lesiones"])
	for i in fs.size():
		for a in fs[i].get("acciones", []):
			if str(a["accion"]) in ["cae", "lesionado"]:
				print("ACC %s t%d m%d clave %d" % [a["accion"], i, int(fs[i]["minuto"]), int(a["clave"])])
	quit()
