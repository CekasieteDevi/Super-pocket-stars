extends SceneTree

## La copa de división clasifica por la tabla EN CURSO, a las cinco
## fechas, y no por la tabla del año pasado.
##
## El bug que arregla: con la tabla del año pasado el que ascendía quedaba
## afuera SIEMPRE. Su clave de mérito traía la división de abajo (el
## campeón de la 10ª llegaba con 901) y eso es peor que el último de la
## división nueva (819), así que los 16 cupos se los llevaban los que ya
## estaban más los que habían descendido. Ascender costaba la copa.
##
## Correr con: godot --path . --headless --script tests/test_copa_division_por_tabla_actual.gd

const SEED := 4402

var fallos := 0


func _init() -> void:
	_test_corte_por_tabla()
	_test_ascendido_puede_clasificar()

	print("FALLOS=%d" % fallos)
	quit()


func _ok(condicion: bool, mensaje: String) -> void:
	if condicion:
		print("OK: %s" % mensaje)
	else:
		fallos += 1
		print("FALLA: %s" % mensaje)


func _clubes_del_cuadro(copa: Copa) -> Array:
	var salida := []
	for p in copa.partidos_pendientes:
		salida.append(p[0].nombre)
		salida.append(p[1].nombre)
	for e in copa.equipos_con_bye:
		salida.append(e.nombre)
	return salida


## El corte de los 16, sobre una liga con tabla puesta a mano: puntos
## primero, después diferencia, después goles a favor, y el nombre como
## último desempate.
func _test_corte_por_tabla() -> void:
	print("=== El corte de los 16 sale de la tabla ===")
	var piramide := Piramide.generar(RandomNumberGenerator.new())
	var liga: Liga = piramide.divisiones[0]

	# Puntos decrecientes por posición en el array. Los que caen 16° y 17°
	# empatan en todo: son los dos que se pelean el último cupo, y ahí el
	# corte lo tiene que decidir el nombre.
	for i in range(liga.equipos.size()):
		var nombre: String = liga.equipos[i].nombre
		liga.tabla[nombre]["pts"] = maxi(100 - i * 3, 1)
		liga.tabla[nombre]["dg"] = 0
		liga.tabla[nombre]["gf"] = 0
	var empatados: Array = [liga.equipos[15].nombre, liga.equipos[16].nombre]
	liga.tabla[empatados[1]]["pts"] = int(liga.tabla[empatados[0]]["pts"])

	var clasificados := ClasificacionCopas.clasificados_por_tabla(liga)
	_ok(clasificados.size() == 16,
		"entran 16 (entraron %d)." % clasificados.size())

	var en_orden := true
	for i in range(15):
		en_orden = en_orden and clasificados[i].nombre == liga.equipos[i].nombre
	_ok(en_orden, "los 15 primeros salen en el orden de la tabla.")

	empatados.sort()
	_ok(clasificados[15].nombre == empatados[0],
		"con puntos, diferencia y goles iguales corta el nombre (entró %s)." % clasificados[15].nombre)


## El camino de verdad: una temporada completa, el cierre con sus
## ascensos, y las cinco fechas de la temporada nueva que disparan el
## sorteo. Todo club del cuadro tiene que estar entre los 16 primeros de
## la tabla de HOY, y los ascendidos tienen que poder entrar.
func _test_ascendido_puede_clasificar() -> void:
	print("\n=== Un club que ascendió puede jugar la copa de su división nueva ===")
	var gs = load("res://game/game_state.gd").new()
	gs.partida_nueva(SEED, "Club Prueba")
	while gs.hay_fecha_pendiente():
		gs.jugar_siguiente_fecha()
	gs._cerrar_temporada()

	# La división de la temporada 1, para saber quién subió y quién bajó.
	var division_vieja := {}
	for nombre in gs.posiciones_temporada_anterior:
		division_vieja[nombre] = int(gs.posiciones_temporada_anterior[nombre]["division"])

	_ok(gs.copas_division.is_empty(),
		"la temporada 2 arranca sin copas de división sorteadas.")
	for i in range(gs.FECHAS_PARA_COPA_DIVISION):
		gs.jugar_siguiente_fecha()
	_ok(gs.copas_division.size() == gs.piramide.divisiones.size(),
		"a las %d fechas están las %d copas de división." % [
			gs.FECHAS_PARA_COPA_DIVISION, gs.copas_division.size()])

	# La comprobación va por PUNTOS, no por posición en tabla_ordenada():
	# ese orden no desempata por nombre y a cinco fechas hay empates de
	# sobra, así que el club 16° y el 17° se intercambian solos entre dos
	# llamadas y la comparación por posición daría falsos negativos.
	var todos_en_los_16 := true
	var ascendidos_dentro := 0
	var ascendidos_totales := 0
	for d in range(gs.piramide.divisiones.size()):
		var liga: Liga = gs.piramide.divisiones[d]
		var cuadro: Array = _clubes_del_cuadro(gs.copas_division[d])
		var peor_adentro := 999
		var mejor_afuera := -1
		for equipo in liga.equipos:
			var pts := int(liga.tabla[equipo.nombre]["pts"])
			if cuadro.has(equipo.nombre):
				peor_adentro = mini(peor_adentro, pts)
			else:
				mejor_afuera = maxi(mejor_afuera, pts)
		if peor_adentro < mejor_afuera:
			todos_en_los_16 = false
			print("  División %d: el peor del cuadro tiene %d pts y afuera quedó uno con %d" % [
				d + 1, peor_adentro, mejor_afuera])
		for equipo in liga.equipos:
			# Ascendió: la división de la temporada pasada es un número
			# MAYOR (la 10ª es la de abajo, la 1ª la de arriba).
			if int(division_vieja.get(equipo.nombre, d + 1)) <= d + 1:
				continue
			ascendidos_totales += 1
			if cuadro.has(equipo.nombre):
				ascendidos_dentro += 1

	_ok(todos_en_los_16, "nadie fuera de los 16 primeros entra al cuadro.")
	print("Ascendidos: %d, de los cuales clasificaron %d." % [
		ascendidos_totales, ascendidos_dentro])
	_ok(ascendidos_totales > 0, "hubo ascensos que medir.")
	# Con el sistema viejo este número era CERO, sin excepción: el
	# ascendido llegaba con la peor clave de mérito de las veinte.
	_ok(ascendidos_dentro > 0, "al menos un ascendido clasifica a la copa de su división nueva.")
