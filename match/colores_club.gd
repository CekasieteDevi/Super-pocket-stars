class_name ColoresClub
extends RefCounted

## De qué color juega cada club.
##
## OJO: el GDD habla de la camiseta del club, pero `Team` HOY NO GUARDA
## ningún color — no existe el dato. Mientras tanto se deriva del nombre,
## que es estable (el mismo club siempre sale del mismo color) y
## determinista entre sesiones sin tocar el save.
##
## Cuando se agreguen camisetas de verdad, ESTE es el único archivo a
## cambiar: el resto de la vista ya pide el color por acá.

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


static func de(nombre: String) -> Color:
	return PALETA[absi(hash(nombre)) % PALETA.size()]


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
