class_name Puestos
extends RefCounted

## §8.4 #4: jugar fuera de la posición natural. De −4 a −12 según qué tan
## lejos esté el puesto que le tocó del que sabe jugar.
##
## Hasta ahora el castigo era solo EMERGENTE: un defensor puesto de 9
## remataba con su `tiro`, que es bajo, y con eso alcanzaba. Pero eso no
## captura lo que el modificador dice — un central de 9 no solo remata
## peor, es que no sabe moverse ahí— y dejaba a Adaptable ("juega fuera
## de posición sin penalización") sin nada que cancelar: un rasgo que el
## generador repartía y que no hacía absolutamente nada.
##
## Es el modificador que le pone precio a arrastrar jugadores por la
## cancha en la pantalla de Formación. Antes mover a un lateral al medio
## era gratis y ahora se paga, que es lo que vuelve la decisión una
## decisión.

## Dónde vive cada puesto, para poder medir distancias entre ellos:
## `linea` va de atrás (0) hacia adelante (4), y `banda` marca si el
## puesto es por afuera.
const MAPA := {
	"ARQ": {"linea": 0, "banda": false},
	"DFC": {"linea": 1, "banda": false},
	"LAT": {"linea": 1, "banda": true},
	"MC": {"linea": 2, "banda": false},
	"MCO": {"linea": 3, "banda": false},
	"EXT": {"linea": 3, "banda": true},
	"DC": {"linea": 4, "banda": false},
}

## Los siete puestos que existen, de atrás hacia adelante. Es la lista
## canónica: la usa Formaciones para armar un banco que cubra TODOS los
## puestos y no solo los de la formación con la que arranca el club.
const TODOS := ["ARQ", "DFC", "LAT", "MC", "MCO", "EXT", "DC"]


## Puntos por cada escalón de distancia, hasta el tope del GDD.
const POR_ESCALON := 4.0
const MAXIMO := 12.0


## Cuántos escalones hay entre dos puestos. Cambiar de línea cuesta uno
## por línea; salir del carril (de central a lateral, de enganche a
## extremo) cuesta uno más, porque es otro trabajo aunque esté a la misma
## altura de la cancha.
static func distancia(natural: String, asignado: String) -> int:
	if natural == asignado:
		return 0
	# El arquero es un caso aparte y no una línea más: un arquero de
	# campo, o cualquiera al arco, es lo más lejos que se puede estar.
	if natural == "ARQ" or asignado == "ARQ":
		return 3
	if not MAPA.has(natural) or not MAPA.has(asignado):
		return 0
	var a: Dictionary = MAPA[natural]
	var b: Dictionary = MAPA[asignado]
	var d: int = absi(int(a["linea"]) - int(b["linea"]))
	if bool(a["banda"]) != bool(b["banda"]):
		d += 1
	return d


## El modificador en puntos porcentuales: 0 si está en su puesto,
## negativo si no. Nunca pasa de −12.
static func modificador(natural: String, asignado: String) -> float:
	return -minf(MAXIMO, float(distancia(natural, asignado)) * POR_ESCALON)


## Lo que le cuesta a ESTE jugador el puesto que le tocó en el once.
##
## `Adaptable` lo cancela entero: es lo que el GDD dice que hace ("juega
## fuera de posición sin penalización") y es la única forma de que el
## rasgo signifique algo.
static func modificador_de(jugador: Dictionary, asignado: String) -> float:
	if Personalidad.tiene(jugador, "Adaptable"):
		return 0.0
	return modificador(str(jugador.get("posicion", asignado)), asignado)
