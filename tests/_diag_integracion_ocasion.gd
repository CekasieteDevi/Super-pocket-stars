extends SceneTree

## Compara la integración con una copia del motor anterior en el mismo proceso.
## Uso: -- antes=ruta/motor_antes.gd salida=ruta/informe.json
const SEED := 9300
var fallos := 0


func _init() -> void:
	var ruta := ""
	var salida := ""
	for arg in OS.get_cmdline_user_args():
		var partes := arg.split("=", true, 1)
		if partes.size() != 2: continue
		if partes[0] == "antes": ruta = partes[1]
		if partes[0] == "salida": salida = partes[1]
	if not FileAccess.file_exists(ruta):
		push_error("Falta copia del motor anterior: antes=ruta")
		quit(1)
		return
	var anterior := GDScript.new()
	anterior.source_code = FileAccess.get_file_as_string(ruta).replace("class_name MotorEspacial", "")
	if anterior.reload() != OK:
		quit(1)
		return
	var filas := []
	for division in [0, 4, 9]:
		for indice in range(10):
			for visual in [false, true]:
				var antes := _partido(anterior, division, SEED + indice, visual)
				var despues := _partido(MotorEspacial, division, SEED + indice, visual)
				var tiempo_antes: int = antes["microsegundos"]
				var tiempo_despues: int = despues["microsegundos"]
				antes.erase("microsegundos")
				despues.erase("microsegundos")
				for remate in despues["stats"]["registro_remates"]:
					remate["ejecucion"].erase("factor_fuerza")
				var igual := antes == despues
				if not igual: fallos += 1
				filas.append({"division": division + 1, "semilla": SEED + indice,
					"fotogramas": visual, "coincide": igual,
					"goles": antes["goles_local"] + antes["goles_visitante"],
					"remates": antes["stats"]["registro_remates"].size(),
					"us_antes": tiempo_antes, "us_despues": tiempo_despues})
		print("División %d terminada; diferencias=%d" % [division + 1, fallos])
	if salida != "":
		var archivo := FileAccess.open(salida, FileAccess.WRITE)
		if archivo == null:
			quit(1)
			return
		archivo.store_string(JSON.stringify({"semilla": SEED, "pares": filas.size(),
			"antes_sha256": FileAccess.get_sha256(ruta),
			"despues_sha256": FileAccess.get_sha256("res://core/motor_espacial.gd"),
			"pesos": MotorEspacial.pesos(), "filas": filas,
			"comparacion": "Resultado completo, fotogramas, eventos, estadísticas, XP y RNG final. Se excluyen tiempo y el nuevo campo factor_fuerza del registro."}, "\t"))
	print("FALLOS=%d" % fallos)
	quit(1 if fallos else 0)


func _partido(motor: GDScript, division: int, semilla: int, visual: bool) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var a := Team.generar("A", rng, 0, NivelDivision.potencial(division), "Uruguay", NivelDivision.realizacion(division))
	var b := Team.generar("B", rng, 400, NivelDivision.potencial(division), "Uruguay", NivelDivision.realizacion(division))
	rng.seed = semilla
	var inicio := Time.get_ticks_usec()
	var resultado: Dictionary = motor.simular(a, b, rng, visual, false, true)
	resultado["microsegundos"] = Time.get_ticks_usec() - inicio
	resultado["azar_final"] = rng.state
	return resultado
