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


## Solo visual (ui/cancha.gd) — cuánto retrocede el bloque de un equipo
## cuando NO tiene la pelota, como fracción del empuje que hace el rival
## que ataca. 0.5 es el comportamiento "neutro" (retrocede a la mitad de
## lo que el rival avanza). Negativo significa que en vez de retroceder
## empuja hacia adelante — Presión alta va a buscar la pelota en vez de
## replegarse. No afecta al resultado del partido, solo a cómo se ve.
const RETROCESO_SIN_PELOTA := {
	"Presión alta": -0.5, "Tiki taka": 0.35, "Juego directo": 0.5,
	"Físico": 0.5, "Contragolpe": 0.65, "Defensivo": 0.8,
}
const RETROCESO_DEFAULT := 0.5


static func retroceso_sin_pelota(estilo: String) -> float:
	return RETROCESO_SIN_PELOTA.get(estilo, RETROCESO_DEFAULT)


## Cuantos jugadores de campo suben AL AREA en un corner propio, sin
## contar al que lo tira. El resto no se queda en su casillero: sube a la
## mitad de la cancha a jugar el rebote.
##
## Es lo que hace que la filosofia se vea en la pelota parada. Un equipo
## fisico manda a todos, incluidos los centrales, que es de donde saca sus
## goles; uno de contragolpe deja gente atras esperando justamente eso.
const SUBEN_AL_CORNER := {
	"Físico": 8, "Juego directo": 7, "Presión alta": 7,
	"Tiki taka": 5, "Defensivo": 4, "Contragolpe": 4,
}
const SUBEN_AL_CORNER_DEFAULT := 5


static func suben_al_corner(estilo: String) -> int:
	return int(SUBEN_AL_CORNER.get(estilo, SUBEN_AL_CORNER_DEFAULT))
