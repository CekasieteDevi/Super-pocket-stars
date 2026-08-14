extends SceneTree

## Objetivos de directiva y game over (§10.5/§15 + Fix #6) — el objetivo se
## arma por reputación/división, se evalúa contra la posición final de
## temporada, y 2 incumplidos seguidos terminan la partida.
## Correr con: godot --headless --script tests/test_objetivos.gd

const SEED := 3131


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	_test_ultima_division_pide_no_terminar_ultimo(rng)
	_test_reputacion_alta_pide_pelear_el_titulo(rng)
	_test_reputacion_media_pide_mitad_superior(rng)
	_test_reputacion_baja_pide_evitar_el_descenso(rng)
	_test_evaluar_cumplido_y_no_cumplido(rng)
	_test_objetivo_vacio_siempre_cumple(rng)
	_test_dos_incumplidos_seguidos_activan_game_over(rng)
	_test_cumplir_resetea_el_contador(rng)
	_test_persiste_en_guardado_y_migra_guardados_viejos(rng)

	quit()


func _test_ultima_division_pide_no_terminar_ultimo(rng: RandomNumberGenerator) -> void:
	print("=== En la ultima division, el objetivo es no terminar ultimo (Fix #6) ===")
	var equipo := Team.generar("ClubUltima", rng, 0)
	var objetivo := Objetivos.generar(equipo, true, 20)
	if objetivo["tipo"] == "sobrevivir" and objetivo["posicion_maxima"] == 19:
		print("OK: %s (posicion_maxima=%d)" % [objetivo["descripcion"], objetivo["posicion_maxima"]])
	else:
		print("FALLA: %s" % [objetivo])


func _test_reputacion_alta_pide_pelear_el_titulo(rng: RandomNumberGenerator) -> void:
	print("\n=== Reputacion alta (>=70) pide terminar entre los primeros 3 ===")
	var equipo := Team.generar("ClubGrande", rng, 0)
	equipo.reputacion = 85.0
	var objetivo := Objetivos.generar(equipo, false, 20)
	if objetivo["tipo"] == "titulo" and objetivo["posicion_maxima"] == 3:
		print("OK: %s" % objetivo["descripcion"])
	else:
		print("FALLA: %s" % [objetivo])


func _test_reputacion_media_pide_mitad_superior(rng: RandomNumberGenerator) -> void:
	print("\n=== Reputacion media (45-70) pide la mitad superior de la tabla ===")
	var equipo := Team.generar("ClubMedio", rng, 0)
	equipo.reputacion = 55.0
	var objetivo := Objetivos.generar(equipo, false, 20)
	if objetivo["tipo"] == "mitad_superior" and objetivo["posicion_maxima"] == 10:
		print("OK: %s" % objetivo["descripcion"])
	else:
		print("FALLA: %s" % [objetivo])


func _test_reputacion_baja_pide_evitar_el_descenso(rng: RandomNumberGenerator) -> void:
	print("\n=== Reputacion baja (<45), fuera de la ultima division, pide evitar el descenso ===")
	var equipo := Team.generar("ClubChico", rng, 0)
	equipo.reputacion = 20.0
	var objetivo := Objetivos.generar(equipo, false, 20)
	if objetivo["tipo"] == "evitar_descenso" and objetivo["posicion_maxima"] == 18:
		print("OK: %s" % objetivo["descripcion"])
	else:
		print("FALLA: %s" % [objetivo])


func _test_evaluar_cumplido_y_no_cumplido(rng: RandomNumberGenerator) -> void:
	print("\n=== evaluar(): posicion_final <= posicion_maxima es cumplido, mas alla no ===")
	var objetivo := {"tipo": "mitad_superior", "descripcion": "x", "posicion_maxima": 10}
	var ok := true
	ok = ok and Objetivos.evaluar(objetivo, 10) == true
	ok = ok and Objetivos.evaluar(objetivo, 1) == true
	ok = ok and Objetivos.evaluar(objetivo, 11) == false
	if ok:
		print("OK: 10 y 1 cumplen, 11 no.")
	else:
		print("FALLA")


func _test_objetivo_vacio_siempre_cumple(rng: RandomNumberGenerator) -> void:
	print("\n=== Un objetivo vacio (club de la IA, o guardado migrado) siempre se considera cumplido ===")
	if Objetivos.evaluar({}, 20):
		print("OK: sin objetivo no penaliza.")
	else:
		print("FALLA")


func _test_dos_incumplidos_seguidos_activan_game_over(rng: RandomNumberGenerator) -> void:
	print("\n=== Reproduce la logica de GameState._cerrar_temporada(): 2 incumplidos seguidos = game over ===")
	# No se puede instanciar el autoload GameState en modo --script, asi que
	# se reproduce el mismo fragmento de logica que game_state.gd usa en
	# _cerrar_temporada() contra un Team de prueba, con una posicion_final
	# forzada en vez de jugar una piramide entera dos veces (carísimo y
	# lento para lo que hace falta probar acá: el contador y el corte).
	var equipo := Team.generar("ClubGameOver", rng, 0)
	equipo.objetivo_temporada = Objetivos.generar(equipo, true, 20)  # "no terminar ultimo"
	var juego_terminado := false

	for temporada in range(2):
		var posicion_final := 20  # termina ultimo las dos veces
		var cumplido := Objetivos.evaluar(equipo.objetivo_temporada, posicion_final)
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
	equipo.objetivo_temporada = Objetivos.generar(equipo, true, 20)
	var juego_terminado := false

	var posiciones := [20, 5]  # ultimo, despues se salva terminando 5to
	for posicion_final in posiciones:
		var cumplido := Objetivos.evaluar(equipo.objetivo_temporada, posicion_final)
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
	equipo.objetivo_temporada = Objetivos.generar(equipo, false, 20)
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
