extends SceneTree

## Aprender una habilidad (§5, core/aprendizaje.gd) — segunda via ademas de
## nacer con una: requisitos (2 temporadas de foco + atributo 65+ + a
## partir de temporada 3), siempre bronce, maximo 1 en la carrera, y los
## bonus de chance (mentor/genetica/personalidad/edad/instalaciones).
## Correr con: godot --headless --script tests/test_aprendizaje.gd

const SEED := 8585


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	_test_no_aprende_si_ya_tiene_una_habilidad(rng)
	_test_no_aprende_antes_de_temporada_3(rng)
	_test_no_aprende_sin_2_temporadas_de_foco_seguidas(rng)
	_test_no_aprende_con_el_atributo_bajo_65(rng)
	_test_no_aprende_si_el_atributo_no_tiene_pool_de_habilidades(rng)
	_test_chance_suma_los_bonus_y_topea_en_15(rng)
	_test_mentor_con_esa_habilidad_suma_bonus(rng)
	_test_habilidad_aprendida_siempre_es_bronce_y_del_atributo_correcto(rng)
	_test_integracion_con_chance_forzada_al_maximo(rng)

	quit()


func _jugador_listo_para_aprender(rng: RandomNumberGenerator, atributo: String = "tiro") -> Dictionary:
	var j := PlayerGenerator.generate(0, rng, "DC")
	j["habilidad"] = {}
	j["atributos"][atributo] = 70
	j["foco_atributo"] = atributo
	j["foco_temporadas_consecutivas"] = 2
	j["edad"] = 30
	j["genetica_tier"] = "Del monton"
	j["personalidades"] = {}
	return j


func _test_no_aprende_si_ya_tiene_una_habilidad(rng: RandomNumberGenerator) -> void:
	print("=== No aprende si ya tiene una habilidad (nacida o aprendida antes) ===")
	var equipo := Team.generar("ClubA", rng, 0)
	var j := _jugador_listo_para_aprender(rng)
	j["habilidad"] = {"nombre": "Cañón", "nivel": 2}
	var resultado := Aprendizaje.procesar_jugador(j, equipo, 5, rng)
	if resultado.is_empty():
		print("OK: no aprende una segunda.")
	else:
		print("FALLA: %s" % [resultado])


func _test_no_aprende_antes_de_temporada_3(rng: RandomNumberGenerator) -> void:
	print("\n=== No aprende antes de la temporada 3 ===")
	var equipo := Team.generar("ClubB", rng, 0)
	var j := _jugador_listo_para_aprender(rng)
	var resultado := Aprendizaje.procesar_jugador(j, equipo, 2, rng)
	if resultado.is_empty():
		print("OK: temporada 2 no alcanza.")
	else:
		print("FALLA: %s" % [resultado])


func _test_no_aprende_sin_2_temporadas_de_foco_seguidas(rng: RandomNumberGenerator) -> void:
	print("\n=== No aprende con solo 1 temporada de foco (o sin foco) ===")
	var equipo := Team.generar("ClubC", rng, 0)
	var j1 := _jugador_listo_para_aprender(rng)
	j1["foco_temporadas_consecutivas"] = 1
	var j2 := _jugador_listo_para_aprender(rng)
	j2["foco_atributo"] = ""
	j2["foco_temporadas_consecutivas"] = 0

	var ok := true
	ok = ok and Aprendizaje.procesar_jugador(j1, equipo, 5, rng).is_empty()
	ok = ok and Aprendizaje.procesar_jugador(j2, equipo, 5, rng).is_empty()
	if ok:
		print("OK: ni con 1 temporada ni sin foco.")
	else:
		print("FALLA")


func _test_no_aprende_con_el_atributo_bajo_65(rng: RandomNumberGenerator) -> void:
	print("\n=== No aprende si el atributo de foco esta por debajo de 65 ===")
	var equipo := Team.generar("ClubD", rng, 0)
	var j := _jugador_listo_para_aprender(rng)
	j["atributos"]["tiro"] = 50
	var resultado := Aprendizaje.procesar_jugador(j, equipo, 5, rng)
	if resultado.is_empty():
		print("OK: 50 no alcanza los 65 requeridos.")
	else:
		print("FALLA: %s" % [resultado])


func _test_no_aprende_si_el_atributo_no_tiene_pool_de_habilidades(rng: RandomNumberGenerator) -> void:
	print("\n=== Un atributo sin pool de habilidades (ej. 'velocidad') nunca hace aprender nada, sin romper ===")
	var equipo := Team.generar("ClubE", rng, 0)
	var j := _jugador_listo_para_aprender(rng, "velocidad")
	var resultado := Aprendizaje.procesar_jugador(j, equipo, 10, rng)
	if resultado.is_empty():
		print("OK: no rompe y no aprende nada (velocidad no tiene pool en habilidades.json).")
	else:
		print("FALLA: %s" % [resultado])


func _test_chance_suma_los_bonus_y_topea_en_15(rng: RandomNumberGenerator) -> void:
	print("\n=== La chance suma cada bonus disponible y topea en 15%% ===")
	var equipo := Team.generar("ClubF", rng, 0)
	var j := _jugador_listo_para_aprender(rng)

	var chance_base: float = Aprendizaje._chance(j, equipo, "tiro")
	if not is_equal_approx(chance_base, Aprendizaje.CHANCE_BASE):
		print("FALLA: chance base = %.3f, esperado %.3f" % [chance_base, Aprendizaje.CHANCE_BASE])
		return

	j["genetica_tier"] = "Prodigio"
	j["personalidades"] = {"positiva": "Trabajador", "negativa": ""}
	j["edad"] = 20
	equipo.instalaciones["entrenamiento"] = Instalaciones.NIVEL_MAXIMO
	var chance_con_todo: float = Aprendizaje._chance(j, equipo, "tiro")
	var esperado_sin_tope: float = Aprendizaje.CHANCE_BASE + Aprendizaje.BONUS_GENETICA + Aprendizaje.BONUS_TRABAJADOR + Aprendizaje.BONUS_JOVEN + Aprendizaje.BONUS_INSTALACIONES_MAX

	var ok: bool = chance_con_todo > chance_base
	ok = ok and chance_con_todo <= Aprendizaje.CHANCE_MAXIMA
	ok = ok and is_equal_approx(chance_con_todo, min(esperado_sin_tope, Aprendizaje.CHANCE_MAXIMA))

	if ok:
		print("OK: base=%.3f con_bonus=%.3f (topeado en %.2f)." % [chance_base, chance_con_todo, Aprendizaje.CHANCE_MAXIMA])
	else:
		print("FALLA: base=%.3f con_bonus=%.3f esperado_sin_tope=%.3f" % [chance_base, chance_con_todo, esperado_sin_tope])


func _test_mentor_con_esa_habilidad_suma_bonus(rng: RandomNumberGenerator) -> void:
	print("\n=== Un mentor (28+, Lider nato) con una habilidad de 'tiro' en el plantel suma el bonus de mentor ===")
	var equipo := Team.generar("ClubMentor", rng, 0)
	var j := _jugador_listo_para_aprender(rng, "tiro")
	var sin_mentor: float = Aprendizaje._chance(j, equipo, "tiro")

	var mentor := PlayerGenerator.generate(9000, rng, "MC")
	mentor["edad"] = 32
	mentor["personalidades"] = {"positiva": "Lider nato", "negativa": ""}
	mentor["habilidad"] = {"nombre": "Cañón", "nivel": 2}  # Cañón es del pool de "tiro"
	equipo.banco.append(mentor)

	var con_mentor: float = Aprendizaje._chance(j, equipo, "tiro")

	if is_equal_approx(con_mentor - sin_mentor, Aprendizaje.BONUS_MENTOR):
		print("OK: +%.2f de chance con el mentor en el plantel." % Aprendizaje.BONUS_MENTOR)
	else:
		print("FALLA: sin_mentor=%.3f con_mentor=%.3f" % [sin_mentor, con_mentor])


func _test_habilidad_aprendida_siempre_es_bronce_y_del_atributo_correcto(rng: RandomNumberGenerator) -> void:
	print("\n=== La habilidad elegida siempre es nivel 1 (bronce) y del pool correcto para el atributo ===")
	var jugador := PlayerGenerator.generate(0, rng, "DC")
	var pool_tiro: Array = Habilidades._datos()["campo"]["tiro"]

	var ok := true
	for i in range(100):
		var h := Aprendizaje._elegir_habilidad(jugador, "tiro", rng)
		ok = ok and h["nivel"] == 1 and pool_tiro.has(h["nombre"])
		if not ok:
			break

	if ok:
		print("OK: 100 tiradas, siempre nivel 1 y del pool de 'tiro'.")
	else:
		print("FALLA")


func _test_integracion_con_chance_forzada_al_maximo(rng: RandomNumberGenerator) -> void:
	print("\n=== Con la chance en el maximo (15%%), aprender algo en 300 intentos es practicamente seguro ===")
	var equipo := Team.generar("ClubG", rng, 0)
	equipo.instalaciones["entrenamiento"] = Instalaciones.NIVEL_MAXIMO

	var rng_intentos := RandomNumberGenerator.new()
	rng_intentos.seed = 999
	var aprendieron := 0
	for i in range(300):
		var j := _jugador_listo_para_aprender(rng, "tiro")
		j["genetica_tier"] = "Prodigio"
		j["personalidades"] = {"positiva": "Trabajador", "negativa": ""}
		j["edad"] = 20
		var resultado := Aprendizaje.procesar_jugador(j, equipo, 10, rng_intentos)
		if not resultado.is_empty():
			aprendieron += 1

	if aprendieron > 0:
		print("OK: %d/300 aprendieron algo con la chance en el maximo." % aprendieron)
	else:
		print("FALLA: nadie aprendio nada en 300 intentos con 15%% de chance.")
