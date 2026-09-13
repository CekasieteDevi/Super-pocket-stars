extends "res://tests/_diag_integracion_ocasion.gd"

## Reutiliza la generación pareada; compara el motor previo con el actual.
const SEMILLA_ARCOS := 9500
const PARTIDOS := 30


func _init() -> void:
	var ruta := ""
	var salida := ""
	for arg in OS.get_cmdline_user_args():
		var partes := arg.split("=", true, 1)
		if partes.size() != 2: continue
		if partes[0] == "antes": ruta = partes[1]
		if partes[0] == "salida": salida = partes[1]
	if not FileAccess.file_exists(ruta):
		push_error("Falta antes=ruta/motor_antes.gd")
		quit(1)
		return
	var anterior := GDScript.new()
	anterior.source_code = FileAccess.get_file_as_string(ruta).replace("class_name MotorEspacial", "")
	if anterior.reload() != OK:
		quit(1)
		return
	var filas := []
	for division in [0, 4, 9]:
		var resumen := {"goles_antes": 0, "goles_despues": 0, "remates_antes": 0,
			"remates_despues": 0, "desprotegidos": 0, "pares_identicos": 0}
		for indice in range(PARTIDOS):
			var antes := _partido(anterior, division, SEMILLA_ARCOS + indice, false)
			var despues := _partido(MotorEspacial, division, SEMILLA_ARCOS + indice, false)
			var fila := {"division": division + 1, "semilla": SEMILLA_ARCOS + indice,
				"us_antes": antes["microsegundos"], "us_despues": despues["microsegundos"],
				"goles_antes": antes["goles_local"] + antes["goles_visitante"],
				"goles_despues": despues["goles_local"] + despues["goles_visitante"],
				"remates_antes": antes["stats"]["registro_remates"].size(),
				"remates_despues": despues["stats"]["registro_remates"].size(), "desprotegidos": 0}
			for registro in despues["stats"]["registro_remates"]:
				if registro["ocasion"]["arco_desprotegido"]: fila["desprotegidos"] += 1
				registro["ocasion"].erase("arco_desprotegido")
			antes.erase("microsegundos")
			despues.erase("microsegundos")
			fila["coincide"] = antes == despues
			for campo in ["goles_antes", "goles_despues", "remates_antes", "remates_despues", "desprotegidos"]:
				resumen[campo] += fila[campo]
			if fila["coincide"]: resumen["pares_identicos"] += 1
			filas.append(fila)
		print("DIVISION ", division + 1, " ", resumen)
	if salida != "":
		var archivo := FileAccess.open(salida, FileAccess.WRITE)
		if archivo == null:
			quit(1)
			return
		archivo.store_string(JSON.stringify({"semilla": SEMILLA_ARCOS, "partidos_por_division": PARTIDOS,
			"antes_sha256": FileAccess.get_sha256(ruta),
			"despues_sha256": FileAccess.get_sha256("res://core/motor_espacial.gd"),
			"pesos": MotorEspacial.pesos(), "filas": filas,
			"comparacion": "Resultado completo y RNG final sin tiempo ni nuevo campo arco_desprotegido. Goles totales; remates excluyen penales."}, "\t"))
	quit()
