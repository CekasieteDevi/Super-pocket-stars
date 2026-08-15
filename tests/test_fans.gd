extends SceneTree

## Fans (§8.4 #22, core/fans.gd) — arranca en 0 para todos, gana con
## victorias, pierde con una racha larga sin ganar, y pesa fuerte en
## ascensos/descensos. Correr con: godot --headless --script tests/test_fans.gd

const SEED := 6767


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	_test_equipo_generado_arranca_sin_fans(rng)
	_test_ganar_suma_fans_y_resetea_la_racha(rng)
	_test_empatar_o_perder_no_resta_de_una_pero_suma_racha(rng)
	_test_racha_larga_sin_ganar_empieza_a_restar(rng)
	_test_volver_a_ganar_corta_la_perdida(rng)
	_test_clamp_0_100(rng)
	_test_ascenso_y_descenso(rng)
	_test_persiste_en_guardado(rng)

	quit()


func _test_equipo_generado_arranca_sin_fans(rng: RandomNumberGenerator) -> void:
	print("=== Un equipo recien generado arranca en 0 fans, no como estilo/cancha/DT ===")
	var equipo := Team.generar("ClubA", rng, 0)
	if is_equal_approx(equipo.fans, 0.0) and equipo.racha_sin_ganar == 0:
		print("OK: fans=0.0, racha_sin_ganar=0.")
	else:
		print("FALLA: fans=%.2f racha=%d" % [equipo.fans, equipo.racha_sin_ganar])


func _test_ganar_suma_fans_y_resetea_la_racha(rng: RandomNumberGenerator) -> void:
	print("\n=== Ganar suma fans y resetea la racha sin ganar ===")
	var equipo := Team.generar("ClubB", rng, 0)
	equipo.racha_sin_ganar = 3
	Fans.actualizar_por_resultado(equipo, 2, 0)
	if is_equal_approx(equipo.fans, Fans.GANANCIA_POR_VICTORIA) and equipo.racha_sin_ganar == 0:
		print("OK: +%.1f fans, racha en 0." % Fans.GANANCIA_POR_VICTORIA)
	else:
		print("FALLA: fans=%.2f racha=%d" % [equipo.fans, equipo.racha_sin_ganar])


func _test_empatar_o_perder_no_resta_de_una_pero_suma_racha(rng: RandomNumberGenerator) -> void:
	print("\n=== Empatar o perder no resta fans de inmediato, pero suma a la racha ===")
	var empate := Team.generar("ClubC", rng, 0)
	var derrota := Team.generar("ClubD", rng, 100)

	Fans.actualizar_por_resultado(empate, 1, 1)
	Fans.actualizar_por_resultado(derrota, 0, 2)

	var ok: bool = is_equal_approx(empate.fans, 0.0) and empate.racha_sin_ganar == 1
	ok = ok and is_equal_approx(derrota.fans, 0.0) and derrota.racha_sin_ganar == 1

	if ok:
		print("OK: fans sin cambios, racha_sin_ganar=1 en los dos casos.")
	else:
		print("FALLA: empate fans=%.2f racha=%d — derrota fans=%.2f racha=%d" % [empate.fans, empate.racha_sin_ganar, derrota.fans, derrota.racha_sin_ganar])


func _test_racha_larga_sin_ganar_empieza_a_restar(rng: RandomNumberGenerator) -> void:
	print("\n=== Al llegar al umbral de partidos sin ganar, empieza a perder fans cada partido ===")
	var equipo := Team.generar("ClubE", rng, 0)
	equipo.fans = 50.0

	for i in range(Fans.UMBRAL_RACHA_SIN_GANAR - 1):
		Fans.actualizar_por_resultado(equipo, 0, 0)  # empates, no gana nunca
	var fans_justo_antes_del_umbral := equipo.fans

	Fans.actualizar_por_resultado(equipo, 0, 1)  # este ya cae en el umbral

	if is_equal_approx(fans_justo_antes_del_umbral, 50.0) and is_equal_approx(equipo.fans, 50.0 - Fans.PERDIDA_POR_RACHA):
		print("OK: no perdio nada hasta el partido %d, ahi perdio %.1f." % [Fans.UMBRAL_RACHA_SIN_GANAR, Fans.PERDIDA_POR_RACHA])
	else:
		print("FALLA: antes=%.2f despues=%.2f" % [fans_justo_antes_del_umbral, equipo.fans])


func _test_volver_a_ganar_corta_la_perdida(rng: RandomNumberGenerator) -> void:
	print("\n=== Ganar despues de una racha larga corta la sangria y resetea la racha ===")
	var equipo := Team.generar("ClubF", rng, 0)
	equipo.fans = 50.0
	for i in range(Fans.UMBRAL_RACHA_SIN_GANAR + 3):
		Fans.actualizar_por_resultado(equipo, 0, 1)
	var fans_tras_la_racha := equipo.fans

	Fans.actualizar_por_resultado(equipo, 1, 0)  # gana

	if equipo.fans > fans_tras_la_racha and equipo.racha_sin_ganar == 0:
		print("OK: ganar corta la racha (fans %.2f -> %.2f)." % [fans_tras_la_racha, equipo.fans])
	else:
		print("FALLA: antes=%.2f despues=%.2f racha=%d" % [fans_tras_la_racha, equipo.fans, equipo.racha_sin_ganar])


func _test_clamp_0_100(rng: RandomNumberGenerator) -> void:
	print("\n=== fans nunca sale de [0, 100] ===")
	var equipo := Team.generar("ClubG", rng, 0)
	equipo.fans = 99.9
	for i in range(20):
		Fans.actualizar_por_resultado(equipo, 1, 0)
	var arriba_ok: bool = equipo.fans <= 100.0

	equipo.fans = 0.2
	for i in range(50):
		Fans.actualizar_por_resultado(equipo, 0, 1)
	var abajo_ok: bool = equipo.fans >= 0.0

	if arriba_ok and abajo_ok:
		print("OK: nunca pasa de 100 ni baja de 0 (quedo en %.2f)." % equipo.fans)
	else:
		print("FALLA")


func _test_ascenso_y_descenso(rng: RandomNumberGenerator) -> void:
	print("\n=== Ascender suma un bonus grande, descender resta uno grande ===")
	var asciende := Team.generar("ClubAsciende", rng, 0)
	var desciende := Team.generar("ClubDesciende", rng, 100)
	asciende.fans = 20.0
	desciende.fans = 20.0

	Fans.actualizar_por_movimiento_de_division(asciende, true)
	Fans.actualizar_por_movimiento_de_division(desciende, false)

	var ok: bool = is_equal_approx(asciende.fans, 20.0 + Fans.BONUS_ASCENSO)
	ok = ok and is_equal_approx(desciende.fans, 20.0 - Fans.PERDIDA_DESCENSO)

	if ok:
		print("OK: ascenso +%.1f, descenso -%.1f." % [Fans.BONUS_ASCENSO, Fans.PERDIDA_DESCENSO])
	else:
		print("FALLA: asciende=%.2f desciende=%.2f" % [asciende.fans, desciende.fans])


func _test_persiste_en_guardado(rng: RandomNumberGenerator) -> void:
	print("\n=== fans/racha_sin_ganar/rival_directo sobreviven un guardar/cargar ===")
	var equipo := Team.generar("ClubGuardadoFans", rng, 0)
	equipo.fans = 42.5
	equipo.racha_sin_ganar = 3
	equipo.rival_directo = "Algun Rival FC"

	var datos := equipo.guardar()
	var cargado := Team.cargar(JSON.parse_string(JSON.stringify(datos)))

	var ok: bool = is_equal_approx(cargado.fans, 42.5)
	ok = ok and cargado.racha_sin_ganar == 3 and typeof(cargado.racha_sin_ganar) == TYPE_INT
	ok = ok and cargado.rival_directo == "Algun Rival FC"

	if ok:
		print("OK: round-trip preserva fans, racha_sin_ganar (como int) y rival_directo.")
	else:
		print("FALLA: fans=%.2f racha=%d rival=%s" % [cargado.fans, cargado.racha_sin_ganar, cargado.rival_directo])
