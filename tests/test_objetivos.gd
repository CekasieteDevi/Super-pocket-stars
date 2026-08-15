extends SceneTree

## Objetivos de directiva y game over (§10.5/§15 + Fix #6) — 3 categorias
## (tabla/copa/cantera), evaluadas contra un contexto de fin de temporada,
## y 2 incumplidos seguidos terminan la partida.
## Correr con: godot --headless --script tests/test_objetivos.gd

const SEED := 3131


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	_test_ultima_division_pide_no_terminar_ultimo(rng)
	_test_reputacion_alta_pide_pelear_el_titulo(rng)
	_test_reputacion_media_pide_mitad_superior(rng)
	_test_reputacion_baja_pide_evitar_el_descenso(rng)
	_test_ultima_division_nunca_sortea_copa_ni_cantera(rng)
	_test_generar_reparte_las_3_categorias(rng)
	_test_objetivo_de_copa_escala_con_reputacion(rng)
	_test_objetivo_de_cantera(rng)
	_test_evaluar_tabla_cumplido_y_no_cumplido(rng)
	_test_evaluar_copa(rng)
	_test_evaluar_cantera(rng)
	_test_objetivo_vacio_siempre_cumple(rng)
	_test_dos_incumplidos_seguidos_activan_game_over(rng)
	_test_cumplir_resetea_el_contador(rng)
	_test_persiste_en_guardado_y_migra_guardados_viejos(rng)
	_test_en_riesgo_solo_en_las_ultimas_5_fechas(rng)
	_test_en_riesgo_no_aplica_a_copa_ni_cantera(rng)
	_test_promociones_temporada_cuenta_manuales_y_automaticas(rng)

	quit()


func _test_ultima_division_pide_no_terminar_ultimo(rng: RandomNumberGenerator) -> void:
	print("=== En la ultima division, el objetivo es no terminar ultimo (Fix #6) ===")
	var equipo := Team.generar("ClubUltima", rng, 0)
	var objetivo := Objetivos.generar(equipo, true, 20, rng)
	if objetivo["categoria"] == "tabla" and objetivo["tipo"] == "sobrevivir" and objetivo["posicion_maxima"] == 19:
		print("OK: %s (posicion_maxima=%d)" % [objetivo["descripcion"], objetivo["posicion_maxima"]])
	else:
		print("FALLA: %s" % [objetivo])


func _test_reputacion_alta_pide_pelear_el_titulo(rng: RandomNumberGenerator) -> void:
	print("\n=== Reputacion alta (>=70), categoria tabla, pide terminar entre los primeros 3 ===")
	var equipo := Team.generar("ClubGrande", rng, 0)
	equipo.reputacion = 85.0
	var objetivo := Objetivos._generar_tabla(equipo, false, 20)
	if objetivo["tipo"] == "titulo" and objetivo["posicion_maxima"] == 3:
		print("OK: %s" % objetivo["descripcion"])
	else:
		print("FALLA: %s" % [objetivo])


func _test_reputacion_media_pide_mitad_superior(rng: RandomNumberGenerator) -> void:
	print("\n=== Reputacion media (45-70), categoria tabla, pide la mitad superior de la tabla ===")
	var equipo := Team.generar("ClubMedio", rng, 0)
	equipo.reputacion = 55.0
	var objetivo := Objetivos._generar_tabla(equipo, false, 20)
	if objetivo["tipo"] == "mitad_superior" and objetivo["posicion_maxima"] == 10:
		print("OK: %s" % objetivo["descripcion"])
	else:
		print("FALLA: %s" % [objetivo])


func _test_reputacion_baja_pide_evitar_el_descenso(rng: RandomNumberGenerator) -> void:
	print("\n=== Reputacion baja (<45), categoria tabla, fuera de la ultima division, pide evitar el descenso ===")
	var equipo := Team.generar("ClubChico", rng, 0)
	equipo.reputacion = 20.0
	var objetivo := Objetivos._generar_tabla(equipo, false, 20)
	if objetivo["tipo"] == "evitar_descenso" and objetivo["posicion_maxima"] == 18:
		print("OK: %s" % objetivo["descripcion"])
	else:
		print("FALLA: %s" % [objetivo])


func _test_ultima_division_nunca_sortea_copa_ni_cantera(rng: RandomNumberGenerator) -> void:
	print("\n=== La ultima division SIEMPRE da un objetivo de tabla, nunca copa/cantera ===")
	var equipo := Team.generar("ClubUltimaSiempre", rng, 0)
	var ok := true
	for i in range(50):
		var objetivo := Objetivos.generar(equipo, true, 20, rng)
		if objetivo["categoria"] != "tabla":
			ok = false
			break
	if ok:
		print("OK: 50 tiradas, siempre categoria tabla en la ultima division.")
	else:
		print("FALLA")


func _test_generar_reparte_las_3_categorias(rng: RandomNumberGenerator) -> void:
	print("\n=== Fuera de la ultima division, generar() reparte entre tabla/copa/cantera ===")
	var equipo := Team.generar("ClubCategorias", rng, 0)
	var conteo := {"tabla": 0, "copa": 0, "cantera": 0}
	for i in range(2000):
		var objetivo := Objetivos.generar(equipo, false, 20, rng)
		conteo[objetivo["categoria"]] += 1
	if conteo["tabla"] > 0 and conteo["copa"] > 0 and conteo["cantera"] > 0:
		print("OK: tabla=%d copa=%d cantera=%d (de 2000)." % [conteo["tabla"], conteo["copa"], conteo["cantera"]])
	else:
		print("FALLA: %s" % [conteo])


func _test_objetivo_de_copa_escala_con_reputacion(rng: RandomNumberGenerator) -> void:
	print("\n=== Objetivo de copa: mas reputacion pide llegar mas lejos ===")
	var chico := Team.generar("ClubCopaChico", rng, 0)
	chico.reputacion = 20.0
	var grande := Team.generar("ClubCopaGrande", rng, 100)
	grande.reputacion = 85.0

	var obj_chico := Objetivos._generar_copa(chico)
	var obj_grande := Objetivos._generar_copa(grande)

	if obj_chico["categoria"] == "copa" and obj_grande["rondas_minimas"] > obj_chico["rondas_minimas"]:
		print("OK: chico pide %d ronda(s), grande pide %d." % [obj_chico["rondas_minimas"], obj_grande["rondas_minimas"]])
	else:
		print("FALLA: chico=%s grande=%s" % [obj_chico, obj_grande])


func _test_objetivo_de_cantera(rng: RandomNumberGenerator) -> void:
	print("\n=== Objetivo de cantera pide al menos 1 promocion ===")
	var objetivo := Objetivos._generar_cantera()
	if objetivo["categoria"] == "cantera" and objetivo["promociones_minimas"] == Objetivos.PROMOCIONES_MINIMAS_CANTERA:
		print("OK: %s" % objetivo["descripcion"])
	else:
		print("FALLA: %s" % [objetivo])


func _test_evaluar_tabla_cumplido_y_no_cumplido(rng: RandomNumberGenerator) -> void:
	print("\n=== evaluar() tabla: posicion_final <= posicion_maxima es cumplido, mas alla no ===")
	var objetivo := {"categoria": "tabla", "tipo": "mitad_superior", "descripcion": "x", "posicion_maxima": 10}
	var ok := true
	ok = ok and Objetivos.evaluar(objetivo, {"posicion_final": 10}) == true
	ok = ok and Objetivos.evaluar(objetivo, {"posicion_final": 1}) == true
	ok = ok and Objetivos.evaluar(objetivo, {"posicion_final": 11}) == false
	if ok:
		print("OK: 10 y 1 cumplen, 11 no.")
	else:
		print("FALLA")


func _test_evaluar_copa(rng: RandomNumberGenerator) -> void:
	print("\n=== evaluar() copa: rondas_copa >= rondas_minimas es cumplido ===")
	var objetivo := {"categoria": "copa", "descripcion": "x", "rondas_minimas": 3}
	var ok := true
	ok = ok and Objetivos.evaluar(objetivo, {"rondas_copa": 3}) == true
	ok = ok and Objetivos.evaluar(objetivo, {"rondas_copa": 5}) == true
	ok = ok and Objetivos.evaluar(objetivo, {"rondas_copa": 2}) == false
	if ok:
		print("OK: 3 y 5 rondas cumplen (pide 3), 2 no.")
	else:
		print("FALLA")


func _test_evaluar_cantera(rng: RandomNumberGenerator) -> void:
	print("\n=== evaluar() cantera: promociones_cantera >= promociones_minimas es cumplido ===")
	var objetivo := {"categoria": "cantera", "descripcion": "x", "promociones_minimas": 1}
	var ok := true
	ok = ok and Objetivos.evaluar(objetivo, {"promociones_cantera": 1}) == true
	ok = ok and Objetivos.evaluar(objetivo, {"promociones_cantera": 0}) == false
	if ok:
		print("OK: 1 promocion cumple, 0 no.")
	else:
		print("FALLA")


func _test_objetivo_vacio_siempre_cumple(rng: RandomNumberGenerator) -> void:
	print("\n=== Un objetivo vacio (club de la IA, o guardado migrado) siempre se considera cumplido ===")
	if Objetivos.evaluar({}, {"posicion_final": 20}):
		print("OK: sin objetivo no penaliza.")
	else:
		print("FALLA")


func _test_dos_incumplidos_seguidos_activan_game_over(rng: RandomNumberGenerator) -> void:
	print("\n=== Reproduce la logica de GameState._cerrar_temporada(): 2 incumplidos seguidos = game over ===")
	# No se puede instanciar el autoload GameState en modo --script, asi que
	# se reproduce el mismo fragmento de logica que game_state.gd usa en
	# _cerrar_temporada() contra un Team de prueba, con un contexto forzado
	# en vez de jugar una piramide entera dos veces (carísimo y lento para
	# lo que hace falta probar acá: el contador y el corte).
	var equipo := Team.generar("ClubGameOver", rng, 0)
	equipo.objetivo_temporada = Objetivos.generar(equipo, true, 20, rng)  # "no terminar ultimo"
	var juego_terminado := false

	for temporada in range(2):
		var contexto := {"posicion_final": 20}  # termina ultimo las dos veces
		var cumplido := Objetivos.evaluar(equipo.objetivo_temporada, contexto)
		if cumplido:
			equipo.objetivos_incumplidos_seguidos = 0
		else:
			equipo.objetivos_incumplidos_seguidos += 1
			if equipo.objetivos_incumplidos_seguidos >= Objetivos.MAX_INCUMPLIDOS_SEGUIDOS:
				juego_terminado = true

	if juego_terminado and equipo.objetivos_incumplidos_seguidos == 2:
		print("OK: terminar ultimo 2 temporadas seguidas activa el game over.")
	else:
		print("FALLA: juego_terminado=%s incumplidos=%d" % [juego_terminado, equipo.objetivos_incumplidos_seguidos])


func _test_cumplir_resetea_el_contador(rng: RandomNumberGenerator) -> void:
	print("\n=== Cumplir el objetivo despues de un incumplido resetea el contador (no hay game over) ===")
	var equipo := Team.generar("ClubSeSalva", rng, 0)
	equipo.objetivo_temporada = Objetivos.generar(equipo, true, 20, rng)
	var juego_terminado := false

	var posiciones := [20, 5]  # ultimo, despues se salva terminando 5to
	for posicion_final in posiciones:
		var cumplido := Objetivos.evaluar(equipo.objetivo_temporada, {"posicion_final": posicion_final})
		if cumplido:
			equipo.objetivos_incumplidos_seguidos = 0
		else:
			equipo.objetivos_incumplidos_seguidos += 1
			if equipo.objetivos_incumplidos_seguidos >= Objetivos.MAX_INCUMPLIDOS_SEGUIDOS:
				juego_terminado = true

	if not juego_terminado and equipo.objetivos_incumplidos_seguidos == 0:
		print("OK: un incumplido seguido de un cumplido no gatilla game over, el contador vuelve a 0.")
	else:
		print("FALLA: juego_terminado=%s incumplidos=%d" % [juego_terminado, equipo.objetivos_incumplidos_seguidos])


func _test_persiste_en_guardado_y_migra_guardados_viejos(rng: RandomNumberGenerator) -> void:
	print("\n=== objetivo_temporada/objetivos_incumplidos_seguidos sobreviven el guardado, y migran guardados viejos ===")
	var equipo := Team.generar("ClubGuardadoObjetivo", rng, 0)
	equipo.objetivo_temporada = Objetivos._generar_tabla(equipo, false, 20)
	equipo.objetivos_incumplidos_seguidos = 1

	var datos := equipo.guardar()
	var cargado := Team.cargar(JSON.parse_string(JSON.stringify(datos)))

	var ok := true
	ok = ok and cargado.objetivo_temporada["tipo"] == equipo.objetivo_temporada["tipo"]
	ok = ok and cargado.objetivo_temporada["posicion_maxima"] == equipo.objetivo_temporada["posicion_maxima"]
	ok = ok and typeof(cargado.objetivo_temporada["posicion_maxima"]) == TYPE_INT  # no se queda en float tras el JSON
	ok = ok and cargado.objetivos_incumplidos_seguidos == 1

	var datos_viejos := equipo.guardar()
	datos_viejos.erase("objetivo_temporada")
	datos_viejos.erase("objetivos_incumplidos_seguidos")
	var cargado_viejo := Team.cargar(JSON.parse_string(JSON.stringify(datos_viejos)))
	ok = ok and cargado_viejo.objetivo_temporada.is_empty() and cargado_viejo.objetivos_incumplidos_seguidos == 0

	if ok:
		print("OK: round-trip preserva el objetivo (con posicion_maxima como int) y el contador; guardado viejo migra a vacio/0.")
	else:
		print("FALLA: cargado=%s incumplidos=%d viejo=%s" % [cargado.objetivo_temporada, cargado.objetivos_incumplidos_seguidos, cargado_viejo.objetivo_temporada])


func _test_en_riesgo_solo_en_las_ultimas_5_fechas(rng: RandomNumberGenerator) -> void:
	print("\n=== esta_en_riesgo(): §8.4 #30, solo pesa en las ultimas 5 fechas y si todavia no se cumple ===")
	var objetivo := {"categoria": "tabla", "tipo": "mitad_superior", "descripcion": "x", "posicion_maxima": 10}
	var total_fechas := 38

	var ok := true
	# Lejos del final, aunque vaya mal, no hay tension todavia.
	ok = ok and Objetivos.esta_en_riesgo(objetivo, 15, 10, total_fechas) == false
	# En las ultimas 5 (fecha 34 de 38, total-5=33 -> 34>=33), si no cumple: en riesgo.
	ok = ok and Objetivos.esta_en_riesgo(objetivo, 15, 34, total_fechas) == true
	# En las ultimas 5, pero ya cumple (posicion 8 <= 10): no hay riesgo.
	ok = ok and Objetivos.esta_en_riesgo(objetivo, 8, 34, total_fechas) == false
	# Sin objetivo (club de la IA, o migracion): nunca hay riesgo.
	ok = ok and Objetivos.esta_en_riesgo({}, 15, 37, total_fechas) == false

	if ok:
		print("OK: solo pesa en las ultimas 5 fechas, y solo si la posicion actual no cumple el objetivo.")
	else:
		print("FALLA")


func _test_en_riesgo_no_aplica_a_copa_ni_cantera(rng: RandomNumberGenerator) -> void:
	print("\n=== esta_en_riesgo(): categoria copa/cantera nunca dan tension de tabla, aunque se les pase una posicion mala ===")
	var obj_copa := {"categoria": "copa", "descripcion": "x", "rondas_minimas": 3}
	var obj_cantera := {"categoria": "cantera", "descripcion": "x", "promociones_minimas": 1}
	var ok := true
	ok = ok and Objetivos.esta_en_riesgo(obj_copa, 20, 37, 38) == false
	ok = ok and Objetivos.esta_en_riesgo(obj_cantera, 20, 37, 38) == false
	if ok:
		print("OK: ninguna de las dos categorias activa el malus de tension.")
	else:
		print("FALLA")


func _test_promociones_temporada_cuenta_manuales_y_automaticas(rng: RandomNumberGenerator) -> void:
	print("\n=== Team.promociones_temporada cuenta tanto promover_juvenil() como promover_a_titular() ===")
	var equipo := Team.generar("ClubPromociones", rng, 0)
	var antes := equipo.promociones_temporada

	var juvenil_id: int = equipo.cantera[0]["id"] if not equipo.cantera.is_empty() else -1
	if juvenil_id == -1:
		# generar_camada normal deberia darle cantera, pero por las dudas
		# se genera una camada fresca si el club no tiene ninguna todavia.
		equipo.generar_camada(rng, 1)
		juvenil_id = equipo.cantera[0]["id"]
	equipo.promover_juvenil(juvenil_id)

	var suplente_id: int = equipo.banco[0]["id"]
	equipo.promover_a_titular(suplente_id)

	if equipo.promociones_temporada == antes + 2:
		print("OK: %d -> %d tras 1 promover_juvenil + 1 promover_a_titular." % [antes, equipo.promociones_temporada])
	else:
		print("FALLA: antes=%d despues=%d" % [antes, equipo.promociones_temporada])
