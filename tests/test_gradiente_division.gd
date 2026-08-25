extends SceneTree

## La piramide tiene gradiente de calidad por division, y la economia
## acompaña. Antes las 10 divisiones salian del mismo molde (media 46
## arriba y 47 abajo) y ascender no cambiaba nada.

const SEED := 4321


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var piramide := Piramide.generar(rng)

	_test_gradiente_de_calidad(piramide)
	_test_extremos_en_rango(piramide)
	_test_tier_significa_algo(piramide)
	_test_nadie_nace_quebrado(piramide)
	_test_liga_suelta_sin_escalon(rng)
	quit()


func _media_division(piramide: Piramide, d: int) -> float:
	var total := 0.0
	var n := 0.0
	for e in piramide.divisiones[d].equipos:
		total += e.media_equipo()
		n += 1.0
	return total / n


func _test_gradiente_de_calidad(piramide: Piramide) -> void:
	print("=== Cada division es mejor que la de abajo ===")
	var ok := true
	var anterior := 999.0
	for d in range(piramide.divisiones.size()):
		var m := _media_division(piramide, d)
		if m >= anterior:
			print("FALLA: division %d (media %.1f) no es peor que la de arriba (%.1f)." % [d + 1, m, anterior])
			ok = false
		anterior = m
	if ok:
		print("OK: las 10 divisiones bajan de media monotonamente.")


func _test_extremos_en_rango(piramide: Piramide) -> void:
	print("\n=== Los extremos son los pedidos ===")
	var primera := _media_division(piramide, 0)
	var decima := _media_division(piramide, piramide.divisiones.size() - 1)
	if primera >= 84.0 and primera <= 89.0:
		print("OK: division 1 con media %.1f (pedido 85-88)." % primera)
	else:
		print("FALLA: division 1 con media %.1f, fuera de 84-89." % primera)
	if decima >= 34.0 and decima <= 40.0:
		print("OK: division 10 con media %.1f (pedido 35-40)." % decima)
	else:
		print("FALLA: division 10 con media %.1f, fuera de 34-40." % decima)


func _test_tier_significa_algo(piramide: Piramide) -> void:
	print("\n=== El tier de genetica sale del potencial, no es 'Extranjero' ===")
	# Importa porque Progresion.VELOCIDAD_POR_TIER y Aprendizaje lo leen: un
	# tier que no esta en la tabla cae al 1.0 por defecto y deja de pesar.
	var validos := {}
	for t in Genetics.get_tiers():
		validos[t["tier"]] = true
	var malos := 0
	for d in range(piramide.divisiones.size()):
		for e in piramide.divisiones[d].equipos:
			for j in e.todos_los_jugadores():
				if not validos.has(j["genetica_tier"]):
					malos += 1
	if malos == 0:
		print("OK: todos los jugadores tienen un tier de la tabla.")
	else:
		print("FALLA: %d jugadores con un tier que no esta en genetics_tiers.json." % malos)


func _test_nadie_nace_quebrado(piramide: Piramide) -> void:
	print("\n=== Ninguna division nace en rojo ===")
	# Los sueldos siguen al valor del jugador y por eso escalan x12 con el
	# nivel; los ingresos son constantes fijas. Sin el multiplicador por
	# categoria, primera arrancaba en -353k y quebraba de entrada.
	var ok := true
	for d in range(piramide.divisiones.size()):
		var liga: Liga = piramide.divisiones[d]
		var e: Team = liga.equipos[0]
		var r := Economia.procesar_temporada(e, 10, liga.equipos.size(), liga.division)
		var neto: float = float(r["ingresos"]) - float(r["egresos"])
		if neto <= 0.0:
			print("FALLA: division %d cierra la temporada en %.0f." % [d + 1, neto])
			ok = false
	if ok:
		print("OK: las 10 divisiones cierran en positivo a mitad de tabla.")


func _test_liga_suelta_sin_escalon(rng: RandomNumberGenerator) -> void:
	print("\n=== Una liga suelta no tiene escalon ni multiplicador ===")
	var liga := Liga.new()
	liga.inicializar(["A", "B"], rng, 0)
	if liga.division == -1 and is_equal_approx(Economia.factor_division(liga.division), 1.0):
		print("OK: division -1 y multiplicador 1.0 (lo que usan los tests viejos).")
	else:
		print("FALLA: liga suelta con division %d y factor %.2f." % [
			liga.division, Economia.factor_division(liga.division)])
