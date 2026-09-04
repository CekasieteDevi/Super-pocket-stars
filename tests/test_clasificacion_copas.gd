extends SceneTree

## Clasificación a las copas domésticas (core/clasificacion_copas.gd).
## Correr con: godot --path . --headless --script tests/test_clasificacion_copas.gd
##
## Qué verificamos:
##   1. Los cupos suman 128, que es potencia de 2 — el cuadro del Rey sale
##      perfecto y NADIE pasa sin jugar.
##   2. Con tabla de la temporada anterior, entran los primeros de cada
##      división y no un club cualquiera.
##   3. Un club que descendió entra a la copa interna de su división nueva
##      por delante de los de esa división: clasifica por donde JUGÓ.
##   4. Sin temporada anterior (partida recién empezada) clasifica por
##      reputación y la cantidad es la misma.
##   5. Las dos copas se juegan enteras sin un solo bye: 7 rondas el Rey,
##      4 la interna.

const SEED := 4242

var fallos := 0


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var piramide := Piramide.generar(rng)

	_test_cupos()
	_test_sin_temporada_anterior(piramide, rng)
	_test_con_tabla(piramide)
	_test_descendido_entra_primero(piramide)
	_test_copas_sin_bye(piramide, rng)

	print("FALLOS=%d" % fallos)
	quit()


func _ok(condicion: bool, mensaje: String) -> void:
	if condicion:
		print("OK: %s" % mensaje)
	else:
		fallos += 1
		print("FALLA: %s" % mensaje)


func _es_potencia_de_dos(n: int) -> bool:
	return n > 0 and (n & (n - 1)) == 0


func _test_cupos() -> void:
	print("=== Cupos ===")
	var total := ClasificacionCopas.total_copa_nacional()
	print("Cupos por division: %s  total=%d" % [ClasificacionCopas.CUPOS_COPA_NACIONAL, total])
	_ok(total == 128, "los cupos del Rey suman 128.")
	_ok(_es_potencia_de_dos(total), "el total del Rey es potencia de 2 (cuadro sin byes).")
	_ok(_es_potencia_de_dos(ClasificacionCopas.CUPOS_COPA_DIVISION),
		"los cupos de la copa de division (%d) son potencia de 2." % ClasificacionCopas.CUPOS_COPA_DIVISION)
	# Los cupos no pueden subir al bajar de division: la 5a no puede tener
	# mas lugares que la 4a.
	var baja_o_igual := true
	for d in range(1, ClasificacionCopas.CUPOS_COPA_NACIONAL.size()):
		if int(ClasificacionCopas.CUPOS_COPA_NACIONAL[d]) > int(ClasificacionCopas.CUPOS_COPA_NACIONAL[d - 1]):
			baja_o_igual = false
	_ok(baja_o_igual, "los cupos nunca suben al bajar de division.")


func _test_sin_temporada_anterior(piramide: Piramide, _rng: RandomNumberGenerator) -> void:
	print("\n=== Temporada 1 (sin tabla anterior) ===")
	var clasificados := ClasificacionCopas.clasificados_nacional(piramide, {})
	_ok(clasificados.size() == 128, "clasifican 128 al Rey sin tabla previa (fueron %d)." % clasificados.size())
	var nombres := {}
	for e in clasificados:
		nombres[e.nombre] = true
	_ok(nombres.size() == clasificados.size(), "no hay un club repetido en el Rey.")

	# El orden dentro de cada division sale de la reputacion: el primer
	# clasificado de una division tiene que ser el de reputacion mas alta.
	var primera: Array = ClasificacionCopas.clasificados_de_division(piramide, 0, {})
	_ok(primera.size() == ClasificacionCopas.CUPOS_COPA_DIVISION,
		"la copa de la Division 1 arranca con %d clubes." % ClasificacionCopas.CUPOS_COPA_DIVISION)
	var mejor_reputacion := -1.0
	for e in piramide.divisiones[0].equipos:
		mejor_reputacion = maxf(mejor_reputacion, e.reputacion)
	_ok(is_equal_approx(primera[0].reputacion, mejor_reputacion),
		"sin tabla previa el primer clasificado es el de mas reputacion.")


func _test_con_tabla(piramide: Piramide) -> void:
	print("\n=== Con la tabla de la temporada anterior ===")
	# Tabla inventada: en cada division el orden es el del array de
	# equipos, asi el resultado esperado se sabe de antemano.
	var posiciones := {}
	for d in range(piramide.divisiones.size()):
		var equipos: Array = piramide.divisiones[d].equipos
		for i in range(equipos.size()):
			posiciones[equipos[i].nombre] = {"division": d + 1, "posicion": i + 1}

	var clasificados := ClasificacionCopas.clasificados_nacional(piramide, posiciones)
	_ok(clasificados.size() == 128, "clasifican 128 al Rey con tabla (fueron %d)." % clasificados.size())

	var por_division := {}
	for e in clasificados:
		var d: int = int(posiciones[e.nombre]["division"])
		por_division[d] = int(por_division.get(d, 0)) + 1
	var cupos_ok := true
	for d in range(piramide.divisiones.size()):
		var esperado := ClasificacionCopas.cupos_de(d)
		if int(por_division.get(d + 1, 0)) != esperado:
			cupos_ok = false
			print("  Division %d: %d clasificados, esperado %d" % [d + 1, int(por_division.get(d + 1, 0)), esperado])
	_ok(cupos_ok, "cada division aporta exactamente sus cupos.")

	# El ultimo de una division con 8 cupos (la 10a) no puede estar.
	var ultimo_de_decima: Team = piramide.divisiones[9].equipos[19]
	var esta := false
	for e in clasificados:
		if e == ultimo_de_decima:
			esta = true
	_ok(not esta, "el 20° de la Division 10 no clasifica al Rey.")

	var interna: Array = ClasificacionCopas.clasificados_de_division(piramide, 9, posiciones)
	_ok(interna.size() == 16, "la copa interna arranca con 16 (fueron %d)." % interna.size())
	_ok(interna[0] == piramide.divisiones[9].equipos[0],
		"el 1° de la tabla anterior encabeza la copa interna.")
	var entra_el_ultimo := false
	for e in interna:
		if e == ultimo_de_decima:
			entra_el_ultimo = true
	_ok(not entra_el_ultimo, "el 20° de la tabla anterior no entra a la copa interna.")


func _test_descendido_entra_primero(piramide: Piramide) -> void:
	print("\n=== Un club que descendio ===")
	# Se simula el descenso a mano: un club de la division 10 con tabla de
	# la division 9. No hace falta moverlo de liga — lo que decide es la
	# clave de merito, que trae la division donde jugo.
	var posiciones := {}
	var decima: Array = piramide.divisiones[9].equipos
	for i in range(decima.size()):
		posiciones[decima[i].nombre] = {"division": 10, "posicion": i + 1}
	# El que salio ULTIMO de la decima, pero venia de la novena: aunque
	# haya salido 20°, jugo una division mas arriba.
	var descendido: Team = decima[19]
	posiciones[descendido.nombre] = {"division": 9, "posicion": 20}

	var interna: Array = ClasificacionCopas.clasificados_de_division(piramide, 9, posiciones)
	_ok(interna[0] == descendido,
		"el que bajo de la Division 9 encabeza la copa interna de la 10.")
	_ok(interna.size() == 16, "siguen entrando 16.")


func _test_copas_sin_bye(piramide: Piramide, rng: RandomNumberGenerator) -> void:
	print("\n=== Las copas se juegan enteras, sin byes ===")
	var rey := Copa.iniciar("Copa del Rey", ClasificacionCopas.clasificados_nacional(piramide, {}), rng)
	_ok(rey.equipos_con_bye.is_empty(), "el Rey arranca sin un solo club esperando.")
	_ok(rey.partidos_pendientes.size() == 64, "la primera ronda del Rey son 64 cruces (fueron %d)." % rey.partidos_pendientes.size())
	var rondas_con_bye := 0
	while rey.campeon == null:
		rey.jugar_siguiente_ronda(rng)
		if not rey.equipos_con_bye.is_empty():
			rondas_con_bye += 1
	_ok(rondas_con_bye == 0, "ninguna ronda del Rey reparte pases libres.")
	_ok(rey.historial.size() == 7, "el Rey termina en 7 rondas (fueron %d)." % rey.historial.size())
	_ok(rey.campeon != null, "el Rey tiene campeon.")

	var interna := Copa.iniciar("Copa Division 10",
		ClasificacionCopas.clasificados_de_division(piramide, 9, {}), rng)
	_ok(interna.equipos_con_bye.is_empty(), "la copa interna arranca sin byes.")
	while interna.campeon == null:
		interna.jugar_siguiente_ronda(rng)
	_ok(interna.historial.size() == 4, "la copa interna termina en 4 rondas (fueron %d)." % interna.historial.size())
	_ok(interna.campeon != null, "la copa interna tiene campeon.")

	# El cuadro tiene que arrancar en octavos: cuatro columnas con nombre,
	# ninguna "Ronda previa".
	var cuadro := CuadroCopa.desde_copa(interna)
	var titulos := []
	for col in cuadro["columnas"]:
		titulos.append(str(col["titulo"]))
	print("Columnas de la copa interna: %s" % [titulos])
	_ok(not titulos.has("Ronda previa"), "el cuadro de la interna no tiene ronda previa.")
