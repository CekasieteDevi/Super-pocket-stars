class_name Quimica
extends RefCounted

## §7.4.6: química entre jugadores. Dos que juegan mucho juntos se
## entienden: ganan puntos en las acciones ENTRE ELLOS (modificador #10
## del §8.4, de +2 a +5).
##
## Es lo que le pone un costo a rehacer el plantel todos los mercados.
## Hasta ahora vender a un titular y traer a otro con la misma media era
## neutro; con esto, romper una dupla que venía funcionando se paga, y un
## equipo que se mantiene junto rinde por encima de la suma de sus medias.
##
## A diferencia de la familiaridad táctica —que es del equipo entero y va
## en todos los duelos— esta es de a PARES y solo entra cuando la acción
## involucra a los dos: un pase de A a B. Por eso no infla el juego: la
## mayoría de los duelos no la ven.

## Partidos juntos por debajo de los cuales todavía no hay nada. "Duplas
## que juegan mucho juntas", dice el GDD: dos partidos no son mucho.
const PARTIDOS_MINIMOS := 8.0

## Partidos juntos con los que la dupla llega al tope.
const PARTIDOS_TOPE := 60.0

const BONUS_MIN := 2.0
const BONUS_MAX := 5.0

## Lo que pierde por fecha una dupla que NO jugó junta. Lento, pero hace
## que rotar tenga un precio y que la química no sea un número que solo
## sube.
const OLVIDO_POR_FECHA := 0.25


## La clave de una dupla. Ordenada, para que A-B y B-A sean lo mismo: sin
## esto la mitad de los pases leería un contador y la otra mitad otro.
static func clave(id_a: int, id_b: int) -> String:
	return "%d-%d" % [mini(id_a, id_b), maxi(id_a, id_b)]


## Cuántos partidos jugaron juntos.
static func partidos(equipo: Team, id_a: int, id_b: int) -> float:
	if id_a == id_b:
		return 0.0
	return float(equipo.quimica.get(clave(id_a, id_b), 0.0))


## De partidos juntos a puntos porcentuales.
static func bonus_de_partidos(n: float) -> float:
	if n < PARTIDOS_MINIMOS:
		return 0.0
	var t := clampf(
		(n - PARTIDOS_MINIMOS) / (PARTIDOS_TOPE - PARTIDOS_MINIMOS), 0.0, 1.0)
	return lerpf(BONUS_MIN, BONUS_MAX, t)


static func bonus(equipo: Team, id_a: int, id_b: int) -> float:
	return bonus_de_partidos(partidos(equipo, id_a, id_b))


## Se llama UNA vez por equipo por fecha jugada. Suma un partido a cada
## dupla que estuvo en el once, y oxida al resto.
##
## Se cuenta el ONCE y no el plantel: la química se hace jugando juntos,
## no compartiendo vestuario.
static func despues_de_partido(equipo: Team) -> void:
	var en_cancha := []
	for j in equipo.jugadores:
		en_cancha.append(int(j["id"]))

	var jugaron := {}
	for i in range(en_cancha.size()):
		for k in range(i + 1, en_cancha.size()):
			var c := clave(en_cancha[i], en_cancha[k])
			jugaron[c] = true
			equipo.quimica[c] = minf(
				PARTIDOS_TOPE, float(equipo.quimica.get(c, 0.0)) + 1.0)

	# Oxidar las duplas que no jugaron, y de paso tirar las que ya no
	# existen: si uno de los dos se fue del club, el contador es basura que
	# se arrastraría para siempre en el guardado.
	var vigentes := {}
	for j in equipo.todos_los_jugadores():
		vigentes[int(j["id"])] = true
	for c in equipo.quimica.keys():
		if jugaron.has(c):
			continue
		var partes: PackedStringArray = str(c).split("-")
		if partes.size() < 2 or not vigentes.has(int(partes[0])) \
				or not vigentes.has(int(partes[1])):
			equipo.quimica.erase(c)
			continue
		var v: float = float(equipo.quimica[c]) - OLVIDO_POR_FECHA
		if v <= 0.0:
			equipo.quimica.erase(c)
		else:
			equipo.quimica[c] = v


## Las mejores duplas de un jugador, para la UI. Devuelve una lista de
## {"id", "partidos", "bonus"} de mayor a menor, solo las que ya suman.
static func mejores_duplas(equipo: Team, jugador_id: int, tope: int = 4) -> Array:
	var lista := []
	for j in equipo.todos_los_jugadores():
		var otro := int(j["id"])
		if otro == jugador_id:
			continue
		var n := partidos(equipo, jugador_id, otro)
		var b := bonus_de_partidos(n)
		if b <= 0.0:
			continue
		lista.append({"id": otro, "partidos": n, "bonus": b})
	lista.sort_custom(func(a, b): return float(a["partidos"]) > float(b["partidos"]))
	return lista.slice(0, tope)
