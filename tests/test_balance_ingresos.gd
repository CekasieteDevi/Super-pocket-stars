extends SceneTree

## Balance de ingresos vs valor de jugador (feedback de playtesting: "gané
## $797,000 en división 10 cuando un jugador de media 75 cuesta $170,000")
## y el efecto colateral que ese ajuste no debía causar: quiebra masiva
## por multas/sueldos ahora desproporcionados al ingreso más chico. Correr
## con: godot --headless --script tests/test_balance_ingresos.gd

const SEED := 2020


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	_test_ingreso_division_baja_no_es_desproporcionado(rng)
	_test_quiebra_no_es_masiva_en_la_primera_temporada(rng)

	quit()


func _test_ingreso_division_baja_no_es_desproporcionado(rng: RandomNumberGenerator) -> void:
	print("=== Ingreso de un club de division baja, comparado con el valor de un jugador propio ===")
	var equipo := Team.generar("ClubDivisionBaja", rng, 0)
	var informe := Economia.procesar_temporada(equipo, 10, 20)

	var medias := []
	for j in equipo.jugadores:
		medias.append(j["media"])
	medias.sort()
	var jugador_mediano: Dictionary = {}
	for j in equipo.jugadores:
		if is_equal_approx(j["media"], medias[medias.size() / 2]):
			jugador_mediano = j
			break
	var valor_mediano := ValorJugador.calcular(jugador_mediano, equipo.animo.get(jugador_mediano["id"], 50.0), equipo.contratos.get(jugador_mediano["id"], 1))

	var ratio: float = informe["ingresos"] / valor_mediano

	# Antes del ajuste (PRECIO_ENTRADA=80) esta relacion rondaba 40-45x --
	# un club de division baja se compraba la division entera con un solo
	# cierre de temporada. Ahora tiene que ser bastante mas chica.
	if ratio < 15.0:
		print("OK: ingresos (%s) son %.1fx el valor de un jugador mediano propio (%s) -- antes era ~40-45x." % [
			Economia.formato_dinero(informe["ingresos"]), ratio, Economia.formato_dinero(valor_mediano)
		])
	else:
		print("FALLA: la relacion sigue siendo %.1fx (deberia ser < 15x)." % ratio)


func _test_quiebra_no_es_masiva_en_la_primera_temporada(rng: RandomNumberGenerator) -> void:
	print("\n=== La primera temporada de la piramide no manda a la mayoria de los clubes a quiebra ===")
	var piramide := Piramide.generar(rng)
	piramide.jugar_temporada(rng)
	piramide.fin_de_temporada(rng, null, 1)

	var quebrados := 0
	var total := 0
	for liga in piramide.divisiones:
		for e in liga.equipos:
			total += 1
			if e.quebrado:
				quebrados += 1

	# Con el ajuste de ingresos sin acompañarlo de bajar la multa de
	# forfeit y contar el banco en el valor de plantel, la primera
	# temporada por si sola ya mandaba a ~120/200 clubes a quiebra
	# (informe de playtesting). Con los tres ajustes juntos, tiene que
	# ser una fraccion chica.
	var proporcion: float = float(quebrados) / float(total)
	if proporcion < 0.15:
		print("OK: %d/%d clubes (%.0f%%) en quiebra tras la primera temporada -- antes eran ~120/200 (61%%)." % [quebrados, total, proporcion * 100.0])
	else:
		print("FALLA: %d/%d clubes (%.0f%%) en quiebra -- deberia ser menos del 15%%." % [quebrados, total, proporcion * 100.0])
