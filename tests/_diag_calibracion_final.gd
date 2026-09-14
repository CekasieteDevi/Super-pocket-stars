extends SceneTree

const SEMILLA := 97000
const ESCENARIOS := [[0, 0], [0, 3], [4, 4], [4, 7], [9, 9], [9, 6]]
const ESTILOS := [["Tiki taka", "Juego directo"], ["Presion alta", "Contragolpe"]]
var parejas := 50
var ruta := ""
var celda := -1
var instantanea := ""


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		var partes := arg.split("=", true, 1)
		if partes.size() != 2: continue
		if partes[0] == "salida": ruta = partes[1]
		if partes[0] == "parejas": parejas = maxi(1, int(partes[1]))
		if partes[0] == "celda": celda = int(partes[1])
		if partes[0] == "instantanea": instantanea = partes[1]
	if ruta == "":
		push_error("Falta salida=carpeta_existente")
		quit(1)
		return
	var referencia: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/mediciones/ocasion_etapa96/ocasiones.json"))
	var fuente_base := FileAccess.get_file_as_string("res://docs/mediciones/ocasion_etapa96/ocasiones.json.motor.gd")
	var actual: GDScript = MotorEspacial
	if instantanea != "":
		actual = GDScript.new()
		actual.source_code = FileAccess.get_file_as_string(instantanea.path_join("motor.gd")).replace("class_name MotorEspacial", "")
		if actual.reload() != OK:
			quit(1)
			return
		actual._pesos_cache = JSON.parse_string(FileAccess.get_file_as_string(instantanea.path_join("pesos.json")))
	var base := GDScript.new()
	base.source_code = fuente_base.replace("class_name MotorEspacial", "")
	if base.reload() != OK:
		quit(1)
		return
	base._pesos_cache = referencia["pesos"].duplicate(true)
	_guardar("motor_actual.gd", actual.source_code)
	_guardar("motor_base.gd", fuente_base)
	_guardar("pesos_actual.json", JSON.stringify(actual.pesos(), "\t"))
	_guardar("pesos_base.json", JSON.stringify(referencia["pesos"], "\t"))
	var filas := []
	var diferencias := 0
	for escenario in ESCENARIOS:
		if celda >= 0 and ESCENARIOS.find(escenario) != celda: continue
		for indice in range(parejas):
			var estilos: Array = ESTILOS[indice % ESTILOS.size()]
			for vuelta in [false, true]:
				var semilla := SEMILLA + indice
				var resultado := _correr(actual, escenario, estilos, semilla, vuelta, false)
				var visual := _correr(actual, escenario, estilos, semilla, vuelta, true)
				var anterior := _correr(base, escenario, estilos, semilla, vuelta, false)
				var abstracto := _correr(MatchEngine, escenario, estilos, semilla, vuelta, false, true)
				var coincide: bool = resultado["resultado"] == visual["resultado"]
				if not coincide: diferencias += 1
				filas.append({"division_a": escenario[0] + 1, "division_b": escenario[1] + 1,
					"estilos": estilos, "semilla": semilla, "vuelta": vuelta, "coincide": coincide,
					"actual": _metricas(resultado), "base": _metricas(anterior),
					"abstracto": _metricas(abstracto), "ms_con_fotogramas": visual["ms"]})
			if (indice + 1) % 10 == 0: print("PROGRESO D%d/D%d: %d/%d parejas" % [escenario[0] + 1, escenario[1] + 1, indice + 1, parejas])
		print("CELDA D%d/D%d: %d partidos; diferencias de fotogramas=%d" % [escenario[0] + 1, escenario[1] + 1, parejas * 2, diferencias])
		_guardar("resultados.json", JSON.stringify({"semilla": SEMILLA, "parejas_por_celda": parejas,
			"base": "Última medición de 9.6, con sus pesos históricos; resto de dependencias compartidas.",
			"actual_sha256": actual.source_code.sha256_text(), "base_sha256": fuente_base.sha256_text(),
			"abstracto_sha256": FileAccess.get_sha256("res://core/match_engine.gd"),
			"filas": filas, "diferencias_fotogramas": diferencias}, "\t"))
	print("FALLOS=%d" % diferencias)
	quit(1 if diferencias else 0)


func _guardar(nombre: String, texto: String) -> void:
	var archivo := FileAccess.open(ruta.path_join(nombre), FileAccess.WRITE)
	if archivo == null:
		push_error("No se pudo guardar " + nombre)
		quit(1)
		return
	archivo.store_string(texto)


func _correr(motor: GDScript, escenario: Array, estilos: Array, semilla: int,
		vuelta: bool, visual: bool, es_abstracto: bool = false) -> Dictionary:
	var generador := RandomNumberGenerator.new()
	generador.seed = semilla
	var a := Team.generar("A", generador, 0, NivelDivision.potencial(escenario[0]), "Uruguay", NivelDivision.realizacion(escenario[0]))
	var b := Team.generar("B", generador, 400, NivelDivision.potencial(escenario[1]), "Uruguay", NivelDivision.realizacion(escenario[1]))
	a.estilo = estilos[0]
	b.estilo = estilos[1]
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var inicio := Time.get_ticks_usec()
	var resultado: Dictionary = motor.simular(b if vuelta else a, a if vuelta else b, rng) if es_abstracto else motor.simular(b if vuelta else a, a if vuelta else b, rng, visual, false, true)
	var ms := float(Time.get_ticks_usec() - inicio) / 1000.0
	resultado.erase("fotogramas")
	resultado["azar_final"] = rng.state
	return {"resultado": resultado, "ms": ms}


func _metricas(corrida: Dictionary) -> Dictionary:
	var res: Dictionary = corrida["resultado"]
	var tiros: Variant = null
	if res.has("stats"):
		tiros = res["stats"]["dist_tiros"].size()
	return {"goles": res["goles_local"] + res["goles_visitante"],
		"local": res["goles_local"], "visitante": res["goles_visitante"],
		"tiros": tiros, "ms": corrida["ms"]}
