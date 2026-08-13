extends SceneTree

## Fase 7 del roadmap (GDD §10): 10 divisiones con ascensos y descensos.
## Copas nacionales e internacionales quedan para un paso siguiente.
## Correr con: godot --headless --script tests/test_phase7.gd
##
## Qué verificamos:
##   1. 200 clubes en 10 divisiones de 20, cada uno con ids de jugador únicos
##      en toda la pirámide (no solo dentro de su división).
##   2. Después de una temporada + fin_de_temporada(): cada división sigue
##      teniendo exactamente 20 equipos, y division1 recibe ascendidos /
##      division10 no manda a nadie a descender (Fix #6 del GDD).
##   3. Un equipo puntual que ascendió realmente aparece en la división de
##      arriba al año siguiente.
##   4. Tiempo total de una temporada completa (10 divisiones x 380 partidos).

const SEED := 3030


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	var piramide := Piramide.generar(rng)

	_test_generacion(piramide)

	var t0 := Time.get_ticks_msec()
	piramide.jugar_temporada(rng)
	var t1 := Time.get_ticks_msec()
	print("\nTiempo de la temporada completa (10 divisiones x 380 partidos): %d ms" % (t1 - t0))

	# Guardamos quién terminó 1° en división 10 antes de fin_de_temporada
	# (que resetea la tabla) para poder verificar que aparezca en división 9.
	var campeon_d10: String = piramide.divisiones[9].tabla_ordenada()[0]

	var resultado := piramide.fin_de_temporada(rng)

	_test_conteo_equipos(piramide)
	_test_movimientos(resultado["movimientos"], piramide, campeon_d10)


func _test_generacion(piramide: Piramide) -> void:
	print("=== Generacion de la piramide ===")
	print("Divisiones: %d" % piramide.divisiones.size())

	var total_equipos := 0
	var ids_vistos := {}
	var colisiones := 0
	for liga in piramide.divisiones:
		total_equipos += liga.equipos.size()
		for equipo in liga.equipos:
			for j in equipo.jugadores:
				if ids_vistos.has(j["id"]):
					colisiones += 1
				ids_vistos[j["id"]] = true

	print("Equipos totales: %d (esperado 200)" % total_equipos)
	print("Jugadores totales: %d (esperado 2200)" % ids_vistos.size())
	if total_equipos == 200 and colisiones == 0 and ids_vistos.size() == 2200:
		print("OK: 200 clubes, 2200 jugadores, ningun id de jugador se repite en toda la piramide.")
	else:
		print("FALLA: total_equipos=%d colisiones=%d jugadores_unicos=%d" % [total_equipos, colisiones, ids_vistos.size()])


func _test_conteo_equipos(piramide: Piramide) -> void:
	print("\n=== Conteo de equipos por division despues de ascensos/descensos ===")
	var ok := true
	for d in range(piramide.divisiones.size()):
		var n: int = piramide.divisiones[d].equipos.size()
		if n != 20:
			ok = false
		print("Division %d: %d equipos" % [d + 1, n])
	if ok:
		print("OK: las 10 divisiones tienen 20 equipos cada una.")
	else:
		print("FALLA: alguna division no quedo en 20 equipos.")


func _test_movimientos(movimientos: Array, piramide: Piramide, campeon_d10: String) -> void:
	print("\n=== Movimientos de ascenso/descenso ===")
	print("Total de movimientos: %d" % movimientos.size())
	var por_tipo := {}
	for m in movimientos:
		por_tipo[m["tipo"]] = por_tipo.get(m["tipo"], 0) + 1
	for tipo in por_tipo:
		print("  %s: %d" % [tipo, por_tipo[tipo]])

	var esperado_min := (Piramide.N_DIVISIONES - 1) * 4  # al menos 2 directos + 2 del cruce, por limite
	if movimientos.size() >= esperado_min:
		print("OK: hay al menos %d movimientos (2 ascensos directos + 2 descensos directos por cada uno de los 9 limites)." % esperado_min)
	else:
		print("FALLA: se esperaban al menos %d movimientos, hubo %d." % [esperado_min, movimientos.size()])

	# El campeon de division 10 tiene que estar ahora en division 9.
	var nombres_d9 := []
	for equipo in piramide.divisiones[8].equipos:
		nombres_d9.append(equipo.nombre)
	if nombres_d9.has(campeon_d10):
		print("OK: el campeon de division 10 (%s) ahora juega en division 9." % campeon_d10)
	else:
		print("FALLA: el campeon de division 10 (%s) no aparece en division 9." % campeon_d10)

	# Nunca debería aparecer una "división 11" en ningún movimiento.
	var hay_division_11 := false
	for m in movimientos:
		if m["de_division"] == 11 or m["a_division"] == 11:
			hay_division_11 = true
	if not hay_division_11:
		print("OK: ningun movimiento referencia una division 11 (que no existe).")
	else:
		print("FALLA: aparece una division 11 en algun movimiento.")

	quit()
