class_name Rivalidad
extends RefCounted

## Rival directo / clásico (§8.4 #14) — "±0 pero +50% de tarjetas y de
## varianza (más caótico)". Los clubes del exterior tienen ciudad (vía su
## plantilla de nombre, §10.1) pero los 200 uruguayos no, así que la
## rivalidad se hornea como un pareo fijo DENTRO de la división en la que
## el club nace (Piramide.generar, ver hornear_clasicos) — se mantiene
## aunque el club ascienda/descienda después, como una rivalidad real que
## no depende de en qué categoría estás jugando hoy.

const FACTOR_TARJETAS := 1.5
const VARIANZA := 3.0


## equipos: los 20 de una división recién generada. Los empareja de a 2
## en el orden en que ya están (que sale de un sorteo de nombres, así que
## el pareo en sí también es efectivamente al azar) — cada club queda con
## exactamente un clásico, para siempre.
static func hornear_clasicos(equipos: Array) -> void:
	for i in range(0, equipos.size() - 1, 2):
		var a: Team = equipos[i]
		var b: Team = equipos[i + 1]
		a.rival_directo = b.nombre
		b.rival_directo = a.nombre


static func es_clasico(equipo: Team, rival: Team) -> bool:
	return equipo.rival_directo == rival.nombre or rival.rival_directo == equipo.nombre


static func factor_tarjetas(es_clasico: bool) -> float:
	return FACTOR_TARJETAS if es_clasico else 1.0


## "Más caótico": una variación aleatoria extra de bloque C (± varios
## puntos) que no favorece a nadie en particular, sube o baja para
## cualquiera de los dos lados — el resultado de un clásico se vuelve
## menos predecible que el de un partido cualquiera entre los mismos
## equipos, sin regalarle nada a uno ni al otro.
static func variacion(es_clasico: bool, rng: RandomNumberGenerator) -> float:
	return rng.randfn(0.0, VARIANZA) if es_clasico else 0.0
