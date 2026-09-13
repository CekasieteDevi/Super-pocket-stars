extends SceneTree

## Aísla el arreglo de la entrega que anulaba remates tras centros.
## La variante anterior solo omite limpiar esa entrega al lanzar el remate.
const SEED := 9400
const PARTIDOS := 30


func _init() -> void:
	var salida := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("salida="): salida = arg.trim_prefix("salida=")
	var fuente := FileAccess.get_file_as_string("res://core/motor_espacial.gd")
	if fuente.count("\t_limpiar_dirigida(estado[\"pelota\"])\n") != 1:
		push_error("La variante debe modificar exactamente una llamada")
		quit(1)
		return
	var anterior := GDScript.new()
	anterior.source_code = fuente.replace("class_name MotorEspacial", "").replace("\t_limpiar_dirigida(estado[\"pelota\"])\n", "")
	if anterior.source_code == fuente.replace("class_name MotorEspacial", "") or anterior.reload() != OK:
		push_error("No se pudo construir la variante anterior")
		quit(1)
		return
	var filas := []
	for division in [0, 4, 9]:
		var resumen := {"goles_antes": 0, "goles_despues": 0, "remates_antes": 0, "remates_despues": 0,
			"sin_evento_antes": 0, "sin_evento_despues": 0}
		for indice in range(PARTIDOS):
			var antes := _partido(anterior, division, SEED + indice)
			var despues := _partido(MotorEspacial, division, SEED + indice)
			for campo in ["goles", "remates", "sin_evento"]:
				resumen[campo + "_antes"] += antes[campo]
				resumen[campo + "_despues"] += despues[campo]
			filas.append({"division": division + 1, "semilla": SEED + indice, "antes": antes, "despues": despues})
		print("DIVISION ", division + 1, " ", resumen)
	if salida != "":
		var archivo := FileAccess.open(salida, FileAccess.WRITE)
		if archivo == null:
			quit(1)
			return
		archivo.store_string(JSON.stringify({"semilla": SEED, "partidos_por_division": PARTIDOS,
			"motor_sha256": fuente.sha256_text(),
			"pesos": MotorEspacial.pesos(), "filas": filas,
			"variante_antes": "Motor actual sin limpiar dirigida_a al lanzar el remate. Resto del código idéntico.",
			"definicion": "Goles totales; remates excluye penales; sin_evento cuenta registros cuyo remate_id no aparece en eventos de tiro/tiro_puerta."}, "\t"))
	quit()


func _partido(motor: GDScript, division: int, semilla: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var a := Team.generar("A", rng, 0, NivelDivision.potencial(division), "Uruguay", NivelDivision.realizacion(division))
	var b := Team.generar("B", rng, 400, NivelDivision.potencial(division), "Uruguay", NivelDivision.realizacion(division))
	rng.seed = semilla
	var resultado: Dictionary = motor.simular(a, b, rng, false, false, true)
	var eventos := {}
	for evento in resultado["eventos"]:
		if evento["tipo"] in ["tiro", "tiro_puerta"]: eventos[evento["remate_id"]] = true
	var faltantes := 0
	for registro in resultado["stats"]["registro_remates"]:
		if not eventos.has(registro["remate_id"]): faltantes += 1
	return {"goles": resultado["goles_local"] + resultado["goles_visitante"],
		"remates": resultado["stats"]["registro_remates"].size(), "sin_evento": faltantes}
