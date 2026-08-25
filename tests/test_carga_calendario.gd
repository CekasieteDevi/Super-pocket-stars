extends SceneTree

## §7.4.1 + §7.4.7: la carga de entrenamiento y el calendario apretado.
## Lo que se prueba es que la decision EXISTA: que las tres consecuencias
## (recuperacion, crecimiento, lesiones) tiren en direcciones opuestas, y
## que una semana con partido entre semana deje al plantel mas fundido
## que una semana normal.
## Correr con: godot --headless --script tests/test_carga_calendario.gd

const SEED := 3131


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_test_los_efectos_van_en_direcciones_opuestas()
	_test_la_carga_cambia_la_recuperacion(rng)
	_test_semana_apretada_deja_mas_fundido(rng)
	_test_el_promedio_de_temporada_pesa_en_el_crecimiento(rng)
	_test_sobrevive_guardado(rng)
	quit()


func _test_los_efectos_van_en_direcciones_opuestas() -> void:
	print("=== Mas carga = mas crecimiento pero menos recuperacion y mas lesiones ===")
	var ok := true
	for i in range(CargaEntrenamiento.NIVELES.size() - 1):
		var a: String = CargaEntrenamiento.NIVELES[i]
		var b: String = CargaEntrenamiento.NIVELES[i + 1]
		ok = ok and CargaEntrenamiento.factor_crecimiento(b) > CargaEntrenamiento.factor_crecimiento(a)
		ok = ok and CargaEntrenamiento.factor_recuperacion(b) < CargaEntrenamiento.factor_recuperacion(a)
		ok = ok and CargaEntrenamiento.factor_lesion(b) > CargaEntrenamiento.factor_lesion(a)
	if ok:
		print("OK: los 5 escalones son monotonos y con signos opuestos.")
	else:
		print("FALLA: algun escalon no respeta el intercambio.")


func _test_la_carga_cambia_la_recuperacion(rng: RandomNumberGenerator) -> void:
	print("\n=== Entrenar suave recupera mas ===")
	var suave := Team.generar("Suave", rng)
	var duro := Team.generar("Duro", rng, 100)
	suave.carga_entrenamiento = "recuperacion"
	duro.carga_entrenamiento = "brutal"
	for e in [suave, duro]:
		for j in e.todos_los_jugadores():
			e.fatiga_acumulada[j["id"]] = 0.3
	suave.avanzar_dias(7)
	duro.avanzar_dias(7)
	var f_suave: float = suave.fatiga_acumulada[suave.jugadores[0]["id"]]
	var f_duro: float = duro.fatiga_acumulada[duro.jugadores[0]["id"]]
	if f_suave > f_duro:
		print("OK: tras una semana, suave %.2f contra duro %.2f de energia." % [f_suave, f_duro])
	else:
		print("FALLA: suave %.2f duro %.2f" % [f_suave, f_duro])


func _test_semana_apretada_deja_mas_fundido(rng: RandomNumberGenerator) -> void:
	print("
=== Con partido entre semana se llega mas fundido al siguiente ===")
	# Los dos terminan un partido igual de cansados. Uno descansa siete
	# dias; el otro juega el miercoles y descansa 3 + 4.
	var normal := Team.generar("Normal", rng)
	var apretada := Team.generar("Apretada", rng, 100)
	var tras_partido := 0.62
	for e in [normal, apretada]:
		for j in e.todos_los_jugadores():
			e.fatiga_acumulada[j["id"]] = tras_partido
	normal.avanzar_dias(7)
	apretada.avanzar_dias(3)
	# El partido de copa la vuelve a dejar igual de cansada.
	for j in apretada.todos_los_jugadores():
		apretada.fatiga_acumulada[j["id"]] = minf(apretada.fatiga_acumulada[j["id"]], tras_partido)
	apretada.avanzar_dias(4)
	var f_normal: float = normal.fatiga_acumulada[normal.jugadores[0]["id"]]
	var f_apretada: float = apretada.fatiga_acumulada[apretada.jugadores[0]["id"]]
	if f_normal - f_apretada > 0.08:
		print("OK: llega al proximo partido con %.2f contra %.2f del que jugo entre semana." % [
			f_normal, f_apretada])
	else:
		print("FALLA: normal %.2f apretada %.2f (la diferencia no se siente)" % [f_normal, f_apretada])


func _test_el_promedio_de_temporada_pesa_en_el_crecimiento(rng: RandomNumberGenerator) -> void:
	print("\n=== El crecimiento usa el PROMEDIO de la temporada, no la carga de hoy ===")
	var e := Team.generar("Promedio", rng)
	e.carga_entrenamiento = "brutal"
	e.avanzar_dias(7)
	e.carga_entrenamiento = "recuperacion"
	e.avanzar_dias(7)
	var promedio := e.factor_carga_temporada()
	var esperado := (CargaEntrenamiento.factor_crecimiento("brutal") + CargaEntrenamiento.factor_crecimiento("recuperacion")) / 2.0
	if is_equal_approx(promedio, esperado):
		print("OK: una semana brutal y una de recuperacion promedian x%.3f." % promedio)
	else:
		print("FALLA: promedio %.3f, esperado %.3f" % [promedio, esperado])


func _test_sobrevive_guardado(rng: RandomNumberGenerator) -> void:
	print("\n=== La carga sobrevive un guardar/cargar ===")
	var e := Team.generar("Guardado", rng)
	e.carga_entrenamiento = "intenso"
	e.avanzar_dias(7)
	var cargado := Team.cargar(JSON.parse_string(JSON.stringify(e.guardar())))
	var viejo_datos := Team.generar("Viejo", rng).guardar()
	viejo_datos.erase("carga_entrenamiento")
	var viejo := Team.cargar(JSON.parse_string(JSON.stringify(viejo_datos)))
	if cargado.carga_entrenamiento == "intenso" and is_equal_approx(cargado.factor_carga_temporada(), e.factor_carga_temporada()) \
			and viejo.carga_entrenamiento == CargaEntrenamiento.POR_DEFECTO:
		print("OK: round-trip conserva nivel y promedio; un guardado viejo cae a %s." % CargaEntrenamiento.POR_DEFECTO)
	else:
		print("FALLA: cargado=%s promedio=%.3f viejo=%s" % [
			cargado.carga_entrenamiento, cargado.factor_carga_temporada(), viejo.carga_entrenamiento])
