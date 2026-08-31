extends SceneTree

## El gradiente por division no se aplana solo. NivelDivision fija la
## condicion INICIAL; lo que la sostiene es que los jugadores que ENTRAN a
## un club salgan del nivel de ese club y no de la tabla global de
## genetica (ver Team.nivel_potencial).

const SEED := 4321
const TEMPORADAS := 4


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_test_nivel_mide_el_plantel_entero(rng)
	_test_la_camada_sale_del_nivel_del_club(rng)
	_test_las_instalaciones_mueven_la_calidad(rng)
	_test_el_gradiente_aguanta_temporadas(rng)
	quit()


## El punto es ESTRUCTURAL, no estadistico: si `nivel_potencial` midiera
## solo a los once —que son a quienes se promueve— cada camada nacería
## por encima del club real y la piramide derivaria hacia arriba sola.
##
## Antes esto se probaba generando UN club y comparando promedios, y eso
## era una moneda al aire: el banco nace con menos MEDIA realizada (ver
## NivelDivision.FACTOR_SUPLENTE) pero con el mismo POTENCIAL objetivo,
## asi que los dos promedios son iguales en esperanza. Pasaba de suerte.
## Ahora se separan los dos grupos a mano y se comprueba que el numero
## mira a los dos.
func _test_nivel_mide_el_plantel_entero(rng: RandomNumberGenerator) -> void:
	print("=== nivel_potencial mide el plantel entero, no los once ===")
	var e := Team.generar("Nivel", rng, 0)
	for j in e.jugadores:
		j["potencial"] = 90
	for j in e.banco:
		j["potencial"] = 50
	for j in e.cantera:
		j["potencial"] = 50

	var nivel := e.nivel_potencial()
	var esperado := int(round(
		(90.0 * e.jugadores.size() + 50.0 * (e.banco.size() + e.cantera.size()))
		/ float(e.todos_los_jugadores().size())))
	if nivel != esperado:
		print("FALLA: nivel %d, esperado %d (promedio del plantel entero)." % [nivel, esperado])
		return
	if nivel >= 90:
		print("FALLA: nivel %d, esta midiendo solo a los once." % nivel)
		return
	print("OK: once en 90 y banco en 50 dan nivel %d, no 90." % nivel)


func _test_la_camada_sale_del_nivel_del_club(rng: RandomNumberGenerator) -> void:
	print("\n=== Un club de decima no produce juveniles de primera ===")
	var pobre := Team.generar("Pobre", rng, 0, NivelDivision.potencial(9), "Uruguay", NivelDivision.realizacion(9))
	var rico := Team.generar("Rico", rng, 1000, NivelDivision.potencial(0), "Uruguay", NivelDivision.realizacion(0))
	var p_pobre := _promedio_potencial(pobre.generar_camada(rng, 12, pobre.nivel_potencial()))
	var p_rico := _promedio_potencial(rico.generar_camada(rng, 12, rico.nivel_potencial()))
	if p_rico - p_pobre > 20.0:
		print("OK: camada de primera %.1f contra %.1f de decima." % [p_rico, p_pobre])
	else:
		print("FALLA: camadas demasiado parecidas (%.1f contra %.1f)." % [p_rico, p_pobre])


func _test_las_instalaciones_mueven_la_calidad(rng: RandomNumberGenerator) -> void:
	print("\n=== Invertir en juveniles mejora la camada, no solo la agranda ===")
	var e := Team.generar("Academia", rng, 0)
	e.instalaciones["juveniles"] = 1
	var malo := Instalaciones.bonus_potencial_juveniles(e)
	e.instalaciones["juveniles"] = Instalaciones.NIVEL_MAXIMO
	var bueno := Instalaciones.bonus_potencial_juveniles(e)
	if bueno > malo:
		print("OK: nivel 1 da %+d de techo y nivel %d da %+d." % [malo, Instalaciones.NIVEL_MAXIMO, bueno])
	else:
		print("FALLA: el nivel de juveniles no cambia el techo (%+d contra %+d)." % [malo, bueno])


func _test_el_gradiente_aguanta_temporadas(rng: RandomNumberGenerator) -> void:
	print("\n=== El gradiente sigue en pie despues de %d temporadas ===" % TEMPORADAS)
	var p := Piramide.generar(rng)
	var brecha_inicial := _brecha(p)
	for t in range(TEMPORADAS):
		for liga in p.divisiones:
			for fecha in range(liga.fixture.size()):
				liga.jugar_fecha(fecha, rng, null)
				liga.avanzar_dias(7)
		p.fin_de_temporada(rng, null, t)
	var brecha_final := _brecha(p)
	# Antes de que los tres puntos de entrada miraran el nivel del club,
	# la brecha de techos caia de 41 a 32 en 4 temporadas y a 15 en 12.
	var conservado: float = brecha_final / brecha_inicial
	if conservado >= 0.85:
		print("OK: brecha de techos %.1f -> %.1f, conserva el %.0f%%." % [
			brecha_inicial, brecha_final, conservado * 100.0])
	else:
		print("FALLA: brecha de techos %.1f -> %.1f, solo el %.0f%%." % [
			brecha_inicial, brecha_final, conservado * 100.0])


func _promedio_potencial(jugadores: Array) -> float:
	var total := 0.0
	for j in jugadores:
		total += float(j["potencial"])
	return total / max(1.0, float(jugadores.size()))


## Techo promedio de primera menos el de la ultima division.
func _brecha(p: Piramide) -> float:
	return _potencial(p.divisiones[0]) - _potencial(p.divisiones[p.divisiones.size() - 1])


func _potencial(liga: Liga) -> float:
	var total := 0.0
	var n := 0.0
	for e in liga.equipos:
		for j in e.jugadores:
			total += float(j["potencial"])
			n += 1.0
	return total / max(1.0, n)
