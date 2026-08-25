class_name NivelDivision
extends RefCounted

## Qué tan fuerte arranca cada división de la pirámide.
##
## Antes las 10 divisiones salían del mismo molde: la primera y la décima
## tenían la misma media (46 contra 47). En un juego cuyo bucle central es
## subir de categoría eso quiere decir que ascender no te enfrenta a
## rivales mejores — el ascenso era un cambio de nombre, no de dificultad.
##
## El gradiente son DOS cosas a la vez, y hacen falta las dos:
##
##   POTENCIAL: el techo. Un jugador de décima no llega a lo que llega uno
##   de primera ni entrenando toda la vida.
##
##   De la mitad de la tabla para abajo el gradiente lo hace sobre todo el
##   POTENCIAL y no la realización, a propósito: así el plantel con el que
##   arranca el jugador es flojo pero tiene recorrido, en vez de flojo y
##   además terminado.
##
##   REALIZACION: cuánto de ese techo trae puesto al empezar la partida
##   (ver PlayerGenerator._roll_attribute). La primera está llena de
##   jugadores hechos, en su pico; más abajo hay gente joven, cruda, con
##   margen. Sin esto el gradiente topea en media 73, porque la media es
##   el techo REALIZADO y nadie nace realizado del todo.
##
## Consecuencia buscada: los cracks de primera de la IA ya casi no crecen
## —están terminados— y vos subís desde abajo con un plantel con margen.
## El que asciende tiene menos media pero más recorrido.

## Índice 0 = primera división. Media del once que da cada fila, medida
## con tests/_diag_gradiente.gd — si se tocan estos números hay que
## volver a correrlo, no estimarlos.
const NIVELES := [
	{"potencial": 97, "realizacion": Vector2(0.87, 0.99)},  # media ~86
	{"potencial": 93, "realizacion": Vector2(0.81, 0.96)},  # media ~80
	{"potencial": 86, "realizacion": Vector2(0.77, 0.93)},  # media ~74
	{"potencial": 82, "realizacion": Vector2(0.73, 0.92)},  # media ~68
	{"potencial": 79, "realizacion": Vector2(0.68, 0.90)},  # media ~62
	{"potencial": 74, "realizacion": Vector2(0.64, 0.88)},  # media ~56
	{"potencial": 69, "realizacion": Vector2(0.61, 0.86)},  # media ~51
	{"potencial": 65, "realizacion": Vector2(0.58, 0.84)},  # media ~46
	{"potencial": 60, "realizacion": Vector2(0.56, 0.82)},  # media ~41
	{"potencial": 55, "realizacion": Vector2(0.55, 0.80)},  # media ~37
]

## Cuánto del techo realizado trae un suplente respecto de un titular de
## su mismo club. Es proporcional a propósito: un escalón fijo de 10
## puntos sería irrelevante en primera y demoledor en décima. Con 0.80 el
## banco queda siempre ~20% por debajo del once, que es la relación que
## se midió y que hace que perder un titular cueste algo (ver
## Lesiones.RIESGO_BASE — sin escalón, ninguna tasa de lesión se siente).
const FACTOR_SUPLENTE := 0.80


static func _fila(division: int) -> Dictionary:
	return NIVELES[clamp(division, 0, NIVELES.size() - 1)]


## Potencial objetivo de un club de esta división (0 = primera).
static func potencial(division: int) -> int:
	return int(_fila(division)["potencial"])


## Banda de techo realizado de un TITULAR de esta división.
static func realizacion(division: int) -> Vector2:
	return _fila(division)["realizacion"]


## La misma banda, achicada, para el banco.
static func realizacion_suplente(division: int) -> Vector2:
	return realizacion(division) * FACTOR_SUPLENTE
