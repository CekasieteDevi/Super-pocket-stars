class_name Estilos
extends RefCounted

## Estilo de juego (§8.6.2/§8.6.3) — identidad fija del club (horneada al
## generarlo, como nombre/escudo) y elegible para el equipo del jugador.
## El choque de estilos es "piedra-papel-tijera suave": ±3pp en el bloque C
## del duelo (MatchEngine._bloques_equipo), inclina el resultado pero nunca
## lo decide por sí solo.

const LISTA := ["Tiki taka", "Contragolpe", "Juego directo", "Presión alta", "Defensivo", "Físico"]

const BONUS := 3.0

## GDD §8.6.3, tabla de matchups. No es una matriz simétrica (ganarle a X no
## implica que X te pierda a vos): es un grafo dirigido tal cual está en el
## documento, cada estilo declara a quién le gana y contra quién pierde.
const MATRIZ := {
	"Tiki taka": {"gana_a": ["Presión alta"], "pierde_contra": ["Defensivo"]},
	"Contragolpe": {"gana_a": ["Presión alta"], "pierde_contra": ["Defensivo"]},
	"Juego directo": {"gana_a": ["Tiki taka"], "pierde_contra": ["Físico"]},
	"Presión alta": {"gana_a": ["Juego directo"], "pierde_contra": ["Contragolpe"]},
	"Defensivo": {"gana_a": ["Tiki taka", "Contragolpe"], "pierde_contra": ["Presión alta"]},
	"Físico": {"gana_a": ["Tiki taka"], "pierde_contra": ["Juego directo"]},
}


static func generar(rng: RandomNumberGenerator) -> String:
	return LISTA[rng.randi() % LISTA.size()]


## Modificador de bloque C para un equipo con estilo "mio" jugando contra un
## rival con estilo "rival" — se calcula por separado para cada lado (por
## eso es asimétrico: yo puedo ganarle a tu estilo sin que vos me pierdas a
## mi, tal cual la tabla del GDD).
static func modificador(mio: String, rival: String) -> float:
	if mio == "" or rival == "" or not MATRIZ.has(mio):
		return 0.0
	var entrada: Dictionary = MATRIZ[mio]
	if entrada["gana_a"].has(rival):
		return BONUS
	if entrada["pierde_contra"].has(rival):
		return -BONUS
	return 0.0
