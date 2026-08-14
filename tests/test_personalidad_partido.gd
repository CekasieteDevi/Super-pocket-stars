extends SceneTree

## Rasgos de personalidad conectados al partido (§6/§8.4/§8.7) — bloque D
## atado al minuto, penales, tarjetas, y ánimo post-partido. Correr con:
## godot --headless --script tests/test_personalidad_partido.gd

const SEED := 6363


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	_test_lento_de_arranque_castiga_los_primeros_15(rng)
	_test_se_apaga_castiga_los_ultimos_15(rng)
	_test_clutch_favorece_los_ultimos_15(rng)
	_test_fragil_mental_castiga_los_ultimos_10(rng)
	_test_creador_y_nunca_rendirse_son_pasivos_todo_el_partido(rng)
	_test_sin_rasgos_relevantes_no_hay_modificador(rng)
	_test_bonus_penal(rng)
	_test_factor_amarilla_se_van_multiplicando(rng)
	_test_factor_roja(rng)
	_test_ajustar_delta_animo_positivo_bajon_egolatra(rng)
	_test_integracion_tarjetas_usa_el_factor_de_personalidad(rng)

	quit()


func _jugador_con(rng: RandomNumberGenerator, positiva: String = "", negativa: String = "") -> Dictionary:
	var j := PlayerGenerator.generate(0, rng, "MC")
	j["personalidades"] = {"positiva": positiva, "negativa": negativa}
	return j


func _test_lento_de_arranque_castiga_los_primeros_15(rng: RandomNumberGenerator) -> void:
	print("=== Lento de arranque: malus solo en los primeros 15' ===")
	var j := _jugador_con(rng, "", "Lento de arranque")
	var ok := true
	ok = ok and is_equal_approx(Personalidad.modificador_partido(j, true, "pases", 10), -Personalidad.MALUS_ARRANQUE)
	ok = ok and is_equal_approx(Personalidad.modificador_partido(j, true, "pases", 16), 0.0)
	if ok:
		print("OK: -%.1f en minuto 10, 0 en minuto 16." % Personalidad.MALUS_ARRANQUE)
	else:
		print("FALLA")


func _test_se_apaga_castiga_los_ultimos_15(rng: RandomNumberGenerator) -> void:
	print("\n=== Se apaga: malus solo desde el minuto 75 ===")
	var j := _jugador_con(rng, "", "Se apaga")
	var ok := true
	ok = ok and is_equal_approx(Personalidad.modificador_partido(j, true, "pases", 70), 0.0)
	ok = ok and is_equal_approx(Personalidad.modificador_partido(j, true, "pases", 80), -Personalidad.MALUS_SE_APAGA)
	if ok:
		print("OK: 0 en minuto 70, -%.1f en minuto 80." % Personalidad.MALUS_SE_APAGA)
	else:
		print("FALLA")


func _test_clutch_favorece_los_ultimos_15(rng: RandomNumberGenerator) -> void:
	print("\n=== Clutch: bonus solo desde el minuto 75 ===")
	var j := _jugador_con(rng, "Clutch", "")
	var ok := true
	ok = ok and is_equal_approx(Personalidad.modificador_partido(j, true, "tiro", 60), 0.0)
	ok = ok and is_equal_approx(Personalidad.modificador_partido(j, true, "tiro", 85), Personalidad.BONUS_CLUTCH_PARTIDO)
	if ok:
		print("OK: 0 en minuto 60, +%.1f en minuto 85." % Personalidad.BONUS_CLUTCH_PARTIDO)
	else:
		print("FALLA")


func _test_fragil_mental_castiga_los_ultimos_10(rng: RandomNumberGenerator) -> void:
	print("\n=== Fragil mental: malus solo desde el minuto 80 ===")
	var j := _jugador_con(rng, "", "Fragil mental")
	var ok := true
	ok = ok and is_equal_approx(Personalidad.modificador_partido(j, true, "tiro", 77), 0.0)
	ok = ok and is_equal_approx(Personalidad.modificador_partido(j, true, "tiro", 82), -Personalidad.MALUS_FRAGIL_MENTAL_PARTIDO)
	if ok:
		print("OK: 0 en minuto 77, -%.1f en minuto 82." % Personalidad.MALUS_FRAGIL_MENTAL_PARTIDO)
	else:
		print("FALLA")


func _test_creador_y_nunca_rendirse_son_pasivos_todo_el_partido(rng: RandomNumberGenerator) -> void:
	print("\n=== Creador (+pases) y Nunca rendirse (+quite) valen todo el partido, sin importar el minuto ===")
	var creador := _jugador_con(rng, "Creador", "")
	var nunca_rendirse := _jugador_con(rng, "Nunca rendirse", "")
	var ok := true
	ok = ok and is_equal_approx(Personalidad.modificador_partido(creador, true, "pases", 1), Personalidad.BONUS_CREADOR)
	ok = ok and is_equal_approx(Personalidad.modificador_partido(creador, true, "pases", 89), Personalidad.BONUS_CREADOR)
	ok = ok and is_equal_approx(Personalidad.modificador_partido(creador, true, "tiro", 45), 0.0)  # solo en pases
	ok = ok and is_equal_approx(Personalidad.modificador_partido(nunca_rendirse, true, "quite", 45), Personalidad.BONUS_NUNCA_RENDIRSE)
	if ok:
		print("OK: Creador +%.1f en pases (cualquier minuto), Nunca rendirse +%.1f en quite." % [Personalidad.BONUS_CREADOR, Personalidad.BONUS_NUNCA_RENDIRSE])
	else:
		print("FALLA")


func _test_sin_rasgos_relevantes_no_hay_modificador(rng: RandomNumberGenerator) -> void:
	print("\n=== Un jugador sin personalidad (o sin rasgos de partido) no suma nada ===")
	var j := PlayerGenerator.generate(0, rng, "MC")
	j["personalidades"] = {}
	if is_equal_approx(Personalidad.modificador_partido(j, true, "pases", 44), 0.0):
		print("OK: 0.0")
	else:
		print("FALLA")


func _test_bonus_penal(rng: RandomNumberGenerator) -> void:
	print("\n=== bonus_penal: Picaro y Clutch suman, Fragil mental resta ===")
	var picaro := _jugador_con(rng, "Picaro", "")
	var clutch := _jugador_con(rng, "Clutch", "")
	var fragil := _jugador_con(rng, "", "Fragil mental")
	var neutro := _jugador_con(rng, "", "")
	var ok := true
	ok = ok and is_equal_approx(Personalidad.bonus_penal(picaro), Personalidad.BONUS_PICARO_PENAL)
	ok = ok and is_equal_approx(Personalidad.bonus_penal(clutch), Personalidad.BONUS_CLUTCH_PENAL)
	ok = ok and is_equal_approx(Personalidad.bonus_penal(fragil), -Personalidad.MALUS_FRAGIL_MENTAL_PENAL)
	ok = ok and is_equal_approx(Personalidad.bonus_penal(neutro), 0.0)
	if ok:
		print("OK: Picaro=+%.2f Clutch=+%.2f Fragil mental=-%.2f neutro=0." % [Personalidad.BONUS_PICARO_PENAL, Personalidad.BONUS_CLUTCH_PENAL, Personalidad.MALUS_FRAGIL_MENTAL_PENAL])
	else:
		print("FALLA")


func _test_factor_amarilla_se_van_multiplicando(rng: RandomNumberGenerator) -> void:
	print("\n=== factor_amarilla: Calenton (negativa) y Canchero (positiva) pueden coexistir y se multiplican ===")
	var j := _jugador_con(rng, "Canchero", "Calenton")
	var esperado: float = Personalidad.FACTOR_CALENTON_AMARILLA * Personalidad.FACTOR_CANCHERO
	if is_equal_approx(Personalidad.factor_amarilla(j), esperado):
		print("OK: factor=%.3f (Calenton x Canchero)." % Personalidad.factor_amarilla(j))
	else:
		print("FALLA: factor=%.3f esperado=%.3f" % [Personalidad.factor_amarilla(j), esperado])


func _test_factor_roja(rng: RandomNumberGenerator) -> void:
	print("\n=== factor_roja: Calenton sube mucho mas la roja que la amarilla ===")
	var j := _jugador_con(rng, "", "Calenton")
	if Personalidad.factor_roja(j) > Personalidad.factor_amarilla(j):
		print("OK: roja=%.2fx > amarilla=%.2fx." % [Personalidad.factor_roja(j), Personalidad.factor_amarilla(j)])
	else:
		print("FALLA")


func _test_ajustar_delta_animo_positivo_bajon_egolatra(rng: RandomNumberGenerator) -> void:
	print("\n=== ajustar_delta_animo: Positivo anula la caida por perder, Bajon la duplica, Egolatra castiga si no es capitan ===")
	var positivo := _jugador_con(rng, "Positivo", "")
	var bajon := _jugador_con(rng, "", "Bajon")
	var egolatra := _jugador_con(rng, "", "Egolatra")
	var neutro := _jugador_con(rng, "", "")

	var ok := true
	ok = ok and is_equal_approx(Personalidad.ajustar_delta_animo(positivo, -3.0, false), 0.0)
	ok = ok and is_equal_approx(Personalidad.ajustar_delta_animo(bajon, -3.0, false), -6.0)
	ok = ok and is_equal_approx(Personalidad.ajustar_delta_animo(egolatra, 3.0, false), 3.0 - Personalidad.MALUS_EGOLATRA)
	ok = ok and is_equal_approx(Personalidad.ajustar_delta_animo(egolatra, 3.0, true), 3.0)  # es capitan, no se le aplica
	ok = ok and is_equal_approx(Personalidad.ajustar_delta_animo(neutro, -3.0, false), -3.0)  # sin cambios
	ok = ok and is_equal_approx(Personalidad.ajustar_delta_animo(positivo, 3.0, false), 3.0)  # ganando, Positivo no toca nada

	if ok:
		print("OK: Positivo anula perder, Bajon duplica, Egolatra castiga solo si no es capitan.")
	else:
		print("FALLA")


func _test_integracion_tarjetas_usa_el_factor_de_personalidad(rng: RandomNumberGenerator) -> void:
	print("\n=== Integracion: un defensor Calenton junta mas tarjetas en el motor real que uno Canchero ===")
	var home := Team.generar("HomeTarjetas", rng, 0)
	var away := Team.generar("AwayTarjetas", rng, 100)

	# Fuerzo la personalidad de TODOS los defensores de home para que el
	# efecto se note claro en el agregado (con personalidades al azar el
	# ruido tapa la señal, como paso con el test de posesion de estilos).
	for j in home.jugadores:
		if j["posicion"] in ["DFC", "LAT", "MC"]:
			j["personalidades"] = {"positiva": "", "negativa": "Calenton"}

	var muestras := 80
	var tarjetas_calenton := 0
	for i in range(muestras):
		var r := RandomNumberGenerator.new()
		r.seed = 7000 + i
		var res := MatchEngine.simular(home, away, r, false)
		for ev in res["eventos"]:
			if ev["tipo"] == "tarjeta" and ev["equipo"] == home.nombre:
				tarjetas_calenton += 1

	for j in home.jugadores:
		if j["posicion"] in ["DFC", "LAT", "MC"]:
			j["personalidades"] = {"positiva": "Canchero", "negativa": ""}

	var tarjetas_canchero := 0
	for i in range(muestras):
		var r := RandomNumberGenerator.new()
		r.seed = 7000 + i
		var res := MatchEngine.simular(home, away, r, false)
		for ev in res["eventos"]:
			if ev["tipo"] == "tarjeta" and ev["equipo"] == home.nombre:
				tarjetas_canchero += 1

	if tarjetas_calenton > tarjetas_canchero:
		print("OK: Calenton=%d tarjetas en %d partidos, Canchero=%d." % [tarjetas_calenton, muestras, tarjetas_canchero])
	else:
		print("FALLA: calenton=%d canchero=%d" % [tarjetas_calenton, tarjetas_canchero])
