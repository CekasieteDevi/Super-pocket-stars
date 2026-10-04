class_name Estilos
extends RefCounted

## Estilo de juego (§8.6.2/§8.6.3) — identidad fija del club (horneada al
## generarlo, como nombre/escudo) y elegible para el equipo del jugador.
## El estilo cambia lo que busca el equipo en la cancha (PLANES). Ningún
## estilo le gana a otro por tabla: la ventaja sale de cómo juega cada uno.

const LISTA := ["Tiki taka", "Contragolpe", "Juego directo", "Presión alta", "Defensivo", "Físico"]

## Intencion espacial. Cambiar de estilo cambia las opciones que busca el
## equipo, no sus atributos.
## Las magnitudes se contrastan con _diag_identidad_tactica y goles_motores.
const PLANES := {
	"Tiki taka": {"asociacion": 1.0, "verticalidad": 0.15, "amplitud": 0.65, "transicion": 0.25},
	"Contragolpe": {"asociacion": 0.15, "verticalidad": 1.0, "amplitud": 1.0, "transicion": 1.0},
	"Presión alta": {"asociacion": 0.55, "verticalidad": 0.65, "amplitud": 0.65, "transicion": 0.7},
	"Juego directo": {"asociacion": 0.2, "verticalidad": 0.85, "amplitud": 0.8, "transicion": 0.6},
	"Defensivo": {"asociacion": 0.3, "verticalidad": 0.45, "amplitud": 0.55, "transicion": 0.45},
	"Físico": {"asociacion": 0.25, "verticalidad": 0.7, "amplitud": 0.8, "transicion": 0.5},
}

## Cuanto busca el equipo la pelota al area desde la banda. No reemplaza la
## posicion ni la calidad del jugador: solo inclina la eleccion entre centro,
## pase y conduccion cuando el centro esta disponible.
const INTENCION_CENTRO := {
	"Tiki taka": 0.35, "Contragolpe": 0.95, "Juego directo": 1.30,
	"Presión alta": 0.80, "Defensivo": 0.30, "Físico": 1.40,
}

## Multiplica la chance de elegir palomita DESPUÉS de que el centro común
## ganó el duelo aéreo. Se deriva de la misma intención de centro: un estilo
## que cuelga más pelotas también busca más la variante acrobática.
const MULTIPLICADOR_PALOMITA_BASE := 2.8
const MULTIPLICADOR_PALOMITA_POR_CENTRO := 2.8

static func plan(estilo: String) -> Dictionary:
	return PLANES.get(estilo, PLANES["Juego directo"])

static func intencion_centro(estilo: String) -> float:
	return float(INTENCION_CENTRO.get(estilo, 1.0))


static func multiplicador_palomita(estilo: String) -> float:
	return MULTIPLICADOR_PALOMITA_BASE + MULTIPLICADOR_PALOMITA_POR_CENTRO * intencion_centro(estilo)

## Cuánto pican los delanteros a la espalda de la defensa rival (0 = nunca).
## Es de los estilos verticales: el Contragolpe vive de eso y el Juego
## directo lo busca con el pelotazo. Contra una línea adelantada es lo que
## deja a un delantero solo frente al arquero, o en offside.
const PIQUE_A_LA_ESPALDA := {"Contragolpe": 1.0, "Juego directo": 0.7}


static func pique_a_la_espalda(estilo: String) -> float:
	return float(PIQUE_A_LA_ESPALDA.get(estilo, 0.0))


static func generar(rng: RandomNumberGenerator) -> String:
	return LISTA[rng.randi() % LISTA.size()]


## Cuánto retrocede el bloque de un equipo cuando NO tiene la pelota, como
## fracción del empuje rival. Lo usan la cancha y el motor espacial: 0.5 es
## "neutro"; negativo empuja hacia adelante y expone la espalda.
const RETROCESO_SIN_PELOTA := {
	"Presión alta": 0.0, "Tiki taka": 0.35, "Juego directo": 0.5,
	"Físico": 0.5, "Contragolpe": 0.65, "Defensivo": 0.8,
}
const RETROCESO_DEFAULT := 0.5


static func retroceso_sin_pelota(estilo: String) -> float:
	return RETROCESO_SIN_PELOTA.get(estilo, RETROCESO_DEFAULT)


## Cuanto sube el bloque de atras cuando el equipo SI tiene la pelota y
## la mete en campo rival. Es la contraparte de RETROCESO_SIN_PELOTA: sin
## esto el estilo solo cambiaba como se defiende, y atacando los seis
## estilos paraban a sus volantes exactamente en el mismo lugar.
##
## Como el retroceso, se mide contra el DEFAULT y no contra cero: asi el
## equilibrio del motor no se mueve y lo unico que cambia es la
## diferencia ENTRE estilos.
##
## Presion alta y Tiki taka juegan con el equipo junto y arriba, asi que
## sus volantes acompañan. Contragolpe y Defensivo dejan gente atras — es
## justo de lo que viven.
const ACOMPANAMIENTO := {
	"Presión alta": 1.35, "Tiki taka": 1.25, "Juego directo": 1.0,
	"Físico": 1.0, "Contragolpe": 0.7, "Defensivo": 0.55,
}
const ACOMPANAMIENTO_DEFAULT := 1.0


static func acompanamiento(estilo: String) -> float:
	return float(ACOMPANAMIENTO.get(estilo, ACOMPANAMIENTO_DEFAULT))


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


## A partir de cuantos jugadores al corner un estilo tambien CUELGA AL
## AREA las faltas lejanas, en vez de jugarlas cortas. Da Fisico (8),
## Juego directo (7) y Presion alta (7); Tiki taka (5), Defensivo (4) y
## Contragolpe (4) las siguen jugando cortas, que es lo que uno espera de
## cada uno.
##
## Se deriva de SUBEN_AL_CORNER en vez de tener tabla propia: las dos
## preguntas son la misma —cuanto cree este estilo en la pelota al area—
## y con dos tablas se podian contradecir. La contra es que quedan
## acopladas: mover cuantos suben al corner puede cambiar quien cuelga
## las faltas lejanas.
const CUELGA_DE_LEJOS_MINIMO := 7


static func cuelga_de_lejos(estilo: String) -> bool:
	return suben_al_corner(estilo) >= CUELGA_DE_LEJOS_MINIMO
