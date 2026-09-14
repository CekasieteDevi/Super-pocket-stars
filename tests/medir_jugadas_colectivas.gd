extends SceneTree

func _init() -> void:
	var cantidad := 48
	var semilla := 20260914
	var salida := "res://docs/mediciones/jugadas_colectivas_calibracion.json"
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with("salida="):
			salida = argumento.trim_prefix("salida=")
		elif argumento.begins_with("partidos="):
			cantidad = maxi(1, int(argumento.trim_prefix("partidos=")))
		elif argumento.begins_with("semilla="):
			semilla = int(argumento.trim_prefix("semilla="))
		elif argumento.begins_with("descarga="):
			MotorEspacial.pesos()["asociacion_colectiva"] = {"descarga_util": float(argumento.trim_prefix("descarga="))}
	var totales := {}
	var filas := []
	for i in range(cantidad):
		var rng := RandomNumberGenerator.new()
		rng.seed = semilla + i
		var division: int = [0, 4, 9][i % 3]
		var a := Team.generar("Local", rng, 0, NivelDivision.potencial(division), "Uruguay", NivelDivision.realizacion(division))
		var b := Team.generar("Visita", rng, 1000, NivelDivision.potencial(division), "Uruguay", NivelDivision.realizacion(division))
		var resultado := MotorEspacial.simular(a, b, rng, false, false, true)
		var conteo: Dictionary = resultado["stats"]["jugadas_colectivas"]
		filas.append({"semilla": semilla + i, "division": division + 1,
			"formaciones": [a.formacion, b.formacion], "conteos": conteo,
			"muestra_pase_atras": resultado["stats"].get("muestra_pase_atras", {}),
			"goles": resultado["goles_local"] + resultado["goles_visitante"],
			"metros_conduccion": resultado["stats"]["metros_conduccion"],
			"pases": resultado["stats"]["pases"],
			"decisiones": resultado["stats"]["decisiones"], "offsides": resultado["stats"]["offsides"]})
		for clave in conteo:
			totales[clave] = int(totales.get(clave, 0)) + int(conteo[clave])
	var informe := JSON.stringify({"partidos": cantidad, "semilla_inicial": semilla,
		"descarga_util": MotorEspacial.pesos().get("asociacion_colectiva", {}).get("descarga_util", 0.35),
		"conteos": totales, "filas": filas}, "\t")
	print(JSON.stringify({"partidos": cantidad, "conteos": totales}, "\t"))
	var archivo := FileAccess.open(salida, FileAccess.WRITE)
	archivo.store_string(informe)
	quit()
