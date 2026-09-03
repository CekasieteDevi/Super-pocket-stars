extends SceneTree

## Fans (§8.4 #22, core/fans.gd) — lo que mueve la hinchada PARTIDO A
## PARTIDO: gana con victorias, pierde con una racha larga sin ganar, y
## salta al cambiar de división.
##
## Desde la v1.5 la hinchada es una cantidad real y exponencial y todo lo
## que la mueve es MULTIPLICATIVO: un porcentaje, no una cantidad fija.
## Un club de primera gana decenas de miles de hinchas con una victoria y
## uno de décima gana veinte — el mismo 0,4%. Lo que se mueve por
## temporada, la escala entre divisiones y la migración de partidas
## viejas están en tests/test_reputacion_y_fans.gd.
##
## Correr con: godot --headless --script tests/test_fans.gd

const SEED := 6767

## La división en la que se prueba: da números legibles y del orden de
## los de una partida real.
const DIVISION := 5


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	_test_equipo_generado_arranca_con_la_hinchada_de_su_division(rng)
	_test_ganar_suma_fans_y_resetea_la_racha(rng)
	_test_empatar_o_perder_no_resta_de_una_pero_suma_racha(rng)
	_test_racha_larga_sin_ganar_empieza_a_restar(rng)
	_test_volver_a_ganar_corta_la_perdida(rng)
	_test_el_movimiento_es_proporcional(rng)
	_test_clamp(rng)
	_test_ascenso_y_descenso(rng)
	_test_persiste_en_guardado(rng)

	quit()


func _equipo(rng: RandomNumberGenerator, nombre: String) -> Team:
	var t := Team.generar(nombre, rng, 0)
	t.division_actual = DIVISION
	t.fans = Fans.inicial(DIVISION)
	return t


func _test_equipo_generado_arranca_con_la_hinchada_de_su_division(rng: RandomNumberGenerator) -> void:
	print("=== Un club arranca con la hinchada que le corresponde a su division ===")
	# Team.generar no la pone: la pone Liga.inicializar, que es la que
	# sabe en que categoria juega el club.
	var liga := Liga.new()
	liga.inicializar(["ClubA", "ClubB"], rng, 0, DIVISION)
	var equipo: Team = liga.equipos[0]
	var esperado := Fans.inicial(DIVISION)
	if is_equal_approx(equipo.fans, esperado) and equipo.racha_sin_ganar == 0:
		print("OK: %s hinchas (%.0f%% de la referencia de la division), racha en 0." % [
			Fans.texto(equipo.fans), Fans.FRACCION_INICIAL * 100.0])
	else:
		print("FALLA: fans=%s (esperado %s) racha=%d" % [
			Fans.texto(equipo.fans), Fans.texto(esperado), equipo.racha_sin_ganar])


func _test_ganar_suma_fans_y_resetea_la_racha(rng: RandomNumberGenerator) -> void:
	print("\n=== Ganar suma fans y resetea la racha sin ganar ===")
	var equipo := _equipo(rng, "ClubB")
	var antes := equipo.fans
	equipo.racha_sin_ganar = 3
	Fans.actualizar_por_resultado(equipo, 2, 0)
	if is_equal_approx(equipo.fans, antes * (1.0 + Fans.GANANCIA_POR_VICTORIA)) \
			and equipo.racha_sin_ganar == 0:
		print("OK: +%.1f%% (%s -> %s), racha en 0." % [
			Fans.GANANCIA_POR_VICTORIA * 100.0, Fans.texto(antes), Fans.texto(equipo.fans)])
	else:
		print("FALLA: fans=%s racha=%d" % [Fans.texto(equipo.fans), equipo.racha_sin_ganar])


func _test_empatar_o_perder_no_resta_de_una_pero_suma_racha(rng: RandomNumberGenerator) -> void:
	print("\n=== Empatar o perder no resta fans de inmediato, pero suma a la racha ===")
	var empate := _equipo(rng, "ClubC")
	var derrota := _equipo(rng, "ClubD")
	var antes := empate.fans

	Fans.actualizar_por_resultado(empate, 1, 1)
	Fans.actualizar_por_resultado(derrota, 0, 2)

	var ok: bool = is_equal_approx(empate.fans, antes) and empate.racha_sin_ganar == 1
	ok = ok and is_equal_approx(derrota.fans, antes) and derrota.racha_sin_ganar == 1

	if ok:
		print("OK: fans sin cambios, racha_sin_ganar=1 en los dos casos.")
	else:
		print("FALLA: empate fans=%s racha=%d — derrota fans=%s racha=%d" % [
			Fans.texto(empate.fans), empate.racha_sin_ganar,
			Fans.texto(derrota.fans), derrota.racha_sin_ganar])


func _test_racha_larga_sin_ganar_empieza_a_restar(rng: RandomNumberGenerator) -> void:
	print("\n=== Al llegar al umbral de partidos sin ganar, empieza a perder fans cada partido ===")
	var equipo := _equipo(rng, "ClubE")
	var inicial := equipo.fans

	for i in range(Fans.UMBRAL_RACHA_SIN_GANAR - 1):
		Fans.actualizar_por_resultado(equipo, 0, 0)  # empates, no gana nunca
	var justo_antes := equipo.fans

	Fans.actualizar_por_resultado(equipo, 0, 1)  # este ya cae en el umbral

	if is_equal_approx(justo_antes, inicial) \
			and is_equal_approx(equipo.fans, inicial * (1.0 - Fans.PERDIDA_POR_RACHA)):
		print("OK: no perdio nada hasta el partido %d, ahi perdio %.1f%%." % [
			Fans.UMBRAL_RACHA_SIN_GANAR, Fans.PERDIDA_POR_RACHA * 100.0])
	else:
		print("FALLA: antes=%s despues=%s" % [Fans.texto(justo_antes), Fans.texto(equipo.fans)])


func _test_volver_a_ganar_corta_la_perdida(rng: RandomNumberGenerator) -> void:
	print("\n=== Ganar despues de una racha larga corta la sangria y resetea la racha ===")
	var equipo := _equipo(rng, "ClubF")
	for i in range(Fans.UMBRAL_RACHA_SIN_GANAR + 3):
		Fans.actualizar_por_resultado(equipo, 0, 1)
	var tras_la_racha := equipo.fans

	Fans.actualizar_por_resultado(equipo, 1, 0)  # gana

	if equipo.fans > tras_la_racha and equipo.racha_sin_ganar == 0:
		print("OK: ganar corta la racha (%s -> %s)." % [
			Fans.texto(tras_la_racha), Fans.texto(equipo.fans)])
	else:
		print("FALLA: antes=%s despues=%s racha=%d" % [
			Fans.texto(tras_la_racha), Fans.texto(equipo.fans), equipo.racha_sin_ganar])


func _test_el_movimiento_es_proporcional(rng: RandomNumberGenerator) -> void:
	print("\n=== Lo que gana una victoria es PROPORCIONAL, no una cantidad fija ===")
	# Es la diferencia con el modelo viejo, donde una victoria valia lo
	# mismo (+0.5 de un puntaje de 100) para un club de barrio que para
	# uno de primera. Un grande gana miles de hinchas con una victoria;
	# uno de decima gana veinte. El PORCENTAJE es el mismo.
	var chico := Team.generar("ClubChico", rng, 0)
	chico.fans = Fans.inicial(9)
	var grande := Team.generar("ClubGrande", rng, 0)
	grande.fans = Fans.inicial(0)

	var antes_chico := chico.fans
	var antes_grande := grande.fans
	Fans.actualizar_por_resultado(chico, 1, 0)
	Fans.actualizar_por_resultado(grande, 1, 0)

	var gana_chico := chico.fans - antes_chico
	var gana_grande := grande.fans - antes_grande
	var mismo_porcentaje: bool = is_equal_approx(
		gana_chico / antes_chico, gana_grande / antes_grande)

	if mismo_porcentaje and gana_grande > gana_chico * 100.0:
		print("OK: el de decima gana %s hinchas y el de primera %s — el mismo %.1f%%." % [
			Fans.texto(gana_chico), Fans.texto(gana_grande),
			Fans.GANANCIA_POR_VICTORIA * 100.0])
	else:
		print("FALLA: chico +%.1f sobre %.1f, grande +%.1f sobre %.1f" % [
			gana_chico, antes_chico, gana_grande, antes_grande])


func _test_clamp(rng: RandomNumberGenerator) -> void:
	print("\n=== fans nunca sale de [%s, %s] ===" % [
		Fans.texto(Fans.FANS_MIN), Fans.texto(Fans.FANS_MAX)])
	var equipo := _equipo(rng, "ClubG")
	equipo.fans = Fans.FANS_MAX
	for i in range(20):
		Fans.actualizar_por_resultado(equipo, 1, 0)
	var arriba_ok: bool = equipo.fans <= Fans.FANS_MAX

	equipo.fans = Fans.FANS_MIN
	for i in range(50):
		Fans.actualizar_por_resultado(equipo, 0, 1)
	var abajo_ok: bool = equipo.fans >= Fans.FANS_MIN

	if arriba_ok and abajo_ok:
		print("OK: ni pasa el techo ni baja del piso (quedo en %s)." % Fans.texto(equipo.fans))
	else:
		print("FALLA: arriba_ok=%s abajo_ok=%s (%s)" % [
			arriba_ok, abajo_ok, Fans.texto(equipo.fans)])


func _test_ascenso_y_descenso(rng: RandomNumberGenerator) -> void:
	print("\n=== Ascender multiplica la hinchada, descender la achica ===")
	var asciende := _equipo(rng, "ClubAsciende")
	var desciende := _equipo(rng, "ClubDesciende")
	var antes := asciende.fans

	Fans.actualizar_por_movimiento_de_division(asciende, true)
	Fans.actualizar_por_movimiento_de_division(desciende, false)

	if asciende.fans > antes and desciende.fans < antes:
		print("OK: %s -> %s ascendiendo, %s -> %s descendiendo." % [
			Fans.texto(antes), Fans.texto(asciende.fans),
			Fans.texto(antes), Fans.texto(desciende.fans)])
	else:
		print("FALLA: asciende=%s desciende=%s (antes %s)" % [
			Fans.texto(asciende.fans), Fans.texto(desciende.fans), Fans.texto(antes)])


func _test_persiste_en_guardado(rng: RandomNumberGenerator) -> void:
	print("\n=== fans/racha_sin_ganar/rival_directo sobreviven un guardar/cargar ===")
	var equipo := _equipo(rng, "ClubGuardadoFans")
	equipo.fans = 425000.0
	equipo.racha_sin_ganar = 3
	equipo.rival_directo = "Algun Rival FC"

	var datos := equipo.guardar()
	var cargado := Team.cargar(JSON.parse_string(JSON.stringify(datos)))

	var ok: bool = is_equal_approx(cargado.fans, 425000.0)
	ok = ok and cargado.racha_sin_ganar == 3 and typeof(cargado.racha_sin_ganar) == TYPE_INT
	ok = ok and cargado.rival_directo == "Algun Rival FC"

	if ok:
		print("OK: round-trip preserva fans, racha_sin_ganar (como int) y rival_directo.")
	else:
		print("FALLA: fans=%s racha=%d rival=%s" % [
			Fans.texto(cargado.fans), cargado.racha_sin_ganar, cargado.rival_directo])
