extends SceneTree

## Una linea por division: cuantos goles, cuantos remates y desde donde.
## Es el diagnostico corto para barrer pesos de tiro_resolucion.

const SEED := 4400
const PARTIDOS := 30
const ResumenOcasiones := preload("res://tests/resumen_ocasiones.gd")
var cantidad := PARTIDOS
var ruta_salida := ""
var filas: Array = []


func _init() -> void:
	var script_motor: GDScript = MotorEspacial
	var fuente_motor: String = script_motor.source_code
	var motor_sha := fuente_motor.sha256_text()
	for arg in OS.get_cmdline_user_args():
		var partes := arg.split("=", true, 1)
		if partes.size() == 2:
			if partes[0] == "partidos": cantidad = maxi(1, int(partes[1]))
			if partes[0] == "salida": ruta_salida = partes[1]
	if ruta_salida != "":
		var copia := FileAccess.open(ruta_salida + ".motor.gd", FileAccess.WRITE)
		if copia == null:
			push_error("No se pudo guardar el motor medido")
			quit(1)
			return
		copia.store_string(fuente_motor)
		copia.close()
	print("div | goles | remates | >20m | >25m | al arco | conversion | dist p50/p90")
	for division in [9, 4, 0]:
		_medir(division)
	print("distancia | tiro | remates | goles | conversion")
	for distancia in ["0-11", "11-18", "18-25", "25+"]:
		for atributo in ["1-39", "40-69", "70-99"]:
			var n := 0
			var goles := 0
			for fila in filas:
				for tiro in fila["remates"]:
					if tiro["atributo"] != "tiro": continue
					if _tramo_distancia(tiro["distancia"]) != distancia: continue
					if _tramo_atributo(tiro["tiro"]) != atributo: continue
					n += 1
					if tiro.get("resultado_observado", "") == "gol": goles += 1
			print("%9s | %5s | %7d | %5d | %.1f%%" % [distancia, atributo, n, goles, 100.0 * goles / maxi(1, n)])
	var calidad := ResumenOcasiones.resumir(filas)
	print("Calidad geométrica (no xG) | tipo | intentos | goles | bloqueos | conversión")
	for grupo in calidad["filas"]:
		print("[%.1f,%.1f%s | %s | %d | %d | %d | %.1f%%" % [grupo["desde"], grupo["hasta"],
			"]" if grupo["incluye_hasta"] else ")", grupo["tipo"], grupo["intentos"],
			grupo["goles"], grupo["bloqueados"], 100.0 * grupo["conversion"]])
	if ruta_salida != "":
		var archivo := FileAccess.open(ruta_salida, FileAccess.WRITE)
		if archivo == null:
			push_error("No se pudo escribir " + ruta_salida)
			quit(1)
			return
		archivo.store_string(JSON.stringify({"semilla": SEED, "partidos_por_division": cantidad,
			"motor_sha256": motor_sha,
			"copia_motor": ruta_salida.get_file() + ".motor.gd",
			"codigo_motor_estable": motor_sha == FileAccess.get_sha256("res://core/motor_espacial.gd"),
			"diagnostico_sha256": FileAccess.get_sha256("res://tests/_diag_remates.gd"),
			"resumen_sha256": FileAccess.get_sha256("res://tests/resumen_ocasiones.gd"),
			"pesos": MotorEspacial.pesos(), "partidos": filas, "calidad_ocasiones": calidad,
			"definicion": "Intervalos [0,11), [11,18), [18,25), [25,infinito). Tiro: 1-39, 40-69, 70-99. Conversion: goles / todos los intentos, incluidos bloqueados. Tabla solo de atributo tiro; cabezazos y libres separados en las filas. Penales fuera del registro."}, "\t"))
	quit()


func _tramo_distancia(distancia: float) -> String:
	if distancia < 11.0: return "0-11"
	if distancia < 18.0: return "11-18"
	if distancia < 25.0: return "18-25"
	return "25+"


func _tramo_atributo(atributo: float) -> String:
	if atributo < 40.0: return "1-39"
	if atributo < 70.0: return "40-69"
	return "70-99"


func _medir(division: int) -> void:
	var tiros := []
	var goles := 0
	var goles_remates := 0
	var al_arco := 0
	for i in range(cantidad):
		var r1 := RandomNumberGenerator.new()
		r1.seed = SEED + i
		var a := Team.generar("A", r1, 0, NivelDivision.potencial(division),
			"Uruguay", NivelDivision.realizacion(division))
		var b := Team.generar("B", r1, 400, NivelDivision.potencial(division),
			"Uruguay", NivelDivision.realizacion(division))
		var r2 := RandomNumberGenerator.new()
		r2.seed = SEED + i
		var res := MotorEspacial.simular(a, b, r2, false, false, true)
		var resultados := {}
		for evento in res["eventos"]:
			if evento.get("tipo", "") in ["tiro", "tiro_puerta"] and evento.has("remate_id"):
				resultados[evento["remate_id"]] = evento.get("resultado", "")
		for remate in res["stats"]["registro_remates"]:
			remate["resultado_observado"] = resultados.get(remate.get("remate_id", -1), null)
			if remate["resultado_observado"] == "gol": goles_remates += 1
		filas.append({"division": division + 1, "semilla": SEED + i,
			"goles": int(res["goles_local"]) + int(res["goles_visitante"]),
			"remates": res["stats"]["registro_remates"]})
		goles += int(res["goles_local"]) + int(res["goles_visitante"])
		for ev in res["eventos"]:
			if str(ev.get("tipo", "")) == "tiro_puerta":
				al_arco += 1
		tiros.append_array(res["stats"]["dist_tiros"])

	var n: int = maxi(tiros.size(), 1)
	var largos := 0
	var muy_largos := 0
	for d in tiros:
		if float(d) > 20.0:
			largos += 1
		if float(d) > 25.0:
			muy_largos += 1
	var orden := tiros.duplicate()
	orden.sort()
	print("%3d | %5.2f | %7.1f | %3.0f%% | %3.0f%% | %6.0f%% | %9.1f%% | %.0f/%.0f" % [
		division + 1, float(goles) / cantidad, float(tiros.size()) / cantidad,
		100.0 * largos / n, 100.0 * muy_largos / n,
		100.0 * al_arco / n, 100.0 * goles_remates / n,
		float(orden[int(n * 0.5)]) if not orden.is_empty() else 0.0,
		float(orden[int(n * 0.9)]) if not orden.is_empty() else 0.0])

