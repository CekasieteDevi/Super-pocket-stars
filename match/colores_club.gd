class_name ColoresClub
extends RefCounted

## De qué color juega cada club.
##
## El club del jugador ELIGE sus colores al empezar la partida y esos
## mandan. Los otros 199 no eligen nada, así que su color se deriva del
## nombre: es estable (el mismo club sale siempre del mismo color) y
## determinista entre sesiones sin ocupar lugar en el guardado.

const PALETA := [
	Color(0.90, 0.16, 0.18),  # rojo
	Color(0.15, 0.35, 0.80),  # azul
	Color(0.95, 0.78, 0.12),  # amarillo
	Color(0.10, 0.55, 0.28),  # verde
	Color(0.55, 0.16, 0.62),  # violeta
	Color(0.95, 0.45, 0.10),  # naranja
	Color(0.12, 0.62, 0.70),  # celeste
	Color(0.85, 0.85, 0.88),  # blanco
	Color(0.20, 0.20, 0.24),  # negro
	Color(0.62, 0.35, 0.16),  # marrón
]

## En el mismo orden que PALETA. Los usa la pantalla de inicio para que
## una fila de cuadraditos de color se pueda leer con el dedo encima.
const NOMBRES := ["Rojo", "Azul", "Amarillo", "Verde", "Violeta",
	"Naranja", "Celeste", "Blanco", "Negro", "Marrón"]


static func de(nombre: String) -> Color:
	return PALETA[absi(hash(nombre)) % PALETA.size()]


## El color de un club concreto: el que eligió si eligió, y si no el que
## le toca por su nombre.
static func de_equipo(equipo: Team) -> Color:
	if equipo != null and equipo.color_camiseta.a > 0.0:
		return equipo.color_camiseta
	return de(equipo.nombre if equipo != null else "")


## El par de un partido, respetando lo que cada club eligió. Si los dos
## terminan pareciéndose, se le corre el color al VISITANTE, que es lo que
## pasa en la realidad: el local juega siempre con la suya.
static func par_equipos(local: Team, visitante: Team) -> Array:
	var c_local := de_equipo(local)
	var c_visita := de_equipo(visitante)
	var idx := 0
	var intentos := 0
	while _parecidos(c_local, c_visita) and intentos < PALETA.size():
		c_visita = PALETA[idx]
		idx += 1
		intentos += 1
	return [c_local, c_visita]


## Los dos equipos de un partido no pueden verse parecido: si el visitante
## cae en un color muy cercano al del local, se lo corre al siguiente de la
## paleta que contraste. Es el equivalente de la camiseta suplente.
static func par(local: String, visitante: String) -> Array:
	var c_local := de(local)
	var c_visita := de(visitante)
	var intentos := 0
	var idx: int = absi(hash(visitante)) % PALETA.size()
	while _parecidos(c_local, c_visita) and intentos < PALETA.size():
		idx = (idx + 1) % PALETA.size()
		c_visita = PALETA[idx]
		intentos += 1
	return [c_local, c_visita]


static func _parecidos(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.55


## Camisetas de arquero. Son colores que NO están en la paleta de campo,
## a propósito: el arquero tiene que distinguirse de los 20 de campo de un
## vistazo, y si compartiera paleta tarde o temprano coincidiría con
## alguno de los dos equipos.
const PALETA_ARQUERO := [
	Color(0.55, 0.85, 0.15),  # verde flúor
	Color(0.15, 0.18, 0.22),  # negro
	Color(0.98, 0.55, 0.75),  # rosa
	Color(0.35, 0.90, 0.85),  # turquesa
]


## Los dos arqueros del partido, distintos entre sí y distintos de las dos
## camisetas de campo. Se resuelve buscando en la paleta en vez de
## derivarlo del color del club: con cuatro colores reservados siempre hay
## alguno libre, y así no hay que preocuparse de que un tinte calculado
## caiga cerca de algo que ya está en cancha.
static func arqueros(c_local: Color, c_visitante: Color) -> Array:
	var usados := [c_local, c_visitante]
	var salida := []
	for _i in range(2):
		var elegido: Color = PALETA_ARQUERO[0]
		for c in PALETA_ARQUERO:
			var libre := true
			for u in usados:
				if _parecidos(c, u):
					libre = false
					break
			if libre:
				elegido = c
				break
		usados.append(elegido)
		salida.append(elegido)
	return salida
