class_name Fans
extends RefCounted

## La HINCHADA del club: cuántos son, de verdad.
##
## Antes era un número de 0 a 100 que subía medio punto por victoria. Eso
## tenía dos problemas grandes. El primero es que un club de primera y uno
## de décima podían tener el mismo número, y en el fútbol un grande tiene
## millones de hinchas y uno de barrio tiene dos mil: no es una diferencia
## de grado, es de orden de magnitud. El segundo es que solo se ganaban
## GANANDO partidos, así que un quinto de primera que nunca hace una racha
## se quedaba en cero para siempre — el club más grande de la tabla sin
## nadie en la cancha.
##
## Ahora `Team.fans` es la cantidad de hinchas y crece de forma
## MULTIPLICATIVA: un porcentaje por temporada, no una cantidad fija. Así
## la escala se abre sola —los de arriba crecen en millones y los de abajo
## en cientos— y ascender de verdad te cambia de liga de hinchada.
##
## Lo consumen dos cosas, y las dos quieren "qué tan grande es esta
## hinchada", no el número crudo: el modificador de público en los duelos
## de local (core/publico.gd) y la ocupación del estadio
## (Economia.BONUS_OCUPACION_FANS). Para eso está `apoyo()`, que devuelve
## 0..1 comparando contra lo que le corresponde a su división.

## Hinchada de referencia de cada división, de primera (0) a décima (9).
## La escalera es geométrica: cada división vale ~2,8 veces la de abajo,
## así que entre la décima y la primera hay un factor de 20.000. Son los
## órdenes de magnitud del fútbol real —un club de barrio con dos mil
## hinchas y uno grande con decenas de millones— y es lo que hace que
## ascender se sienta.
const REFERENCIA_POR_DIVISION := [
	40000000.0, 14000000.0, 5000000.0, 1800000.0, 640000.0,
	230000.0, 82000.0, 29000.0, 10000.0, 3500.0,
]

## Con cuánto arranca un club: una fracción de lo que le corresponde a su
## división. No arranca en cero —un club existe antes de que vos llegues y
## tiene su gente— pero sí bastante abajo, para que haya a dónde crecer.
const FRACCION_INICIAL := 0.6

## Cuánto se mueve la hinchada por temporada, en porcentaje. Salir campeón
## la hace crecer un 30%; salir último la achica un 22%. Compuesto sobre
## varias temporadas eso multiplica o divide de verdad.
##
## La rampa tiene que ser casi simétrica. Con +35/-18 el promedio de la
## división crecía un 8,5% por temporada y, con el tirón hacia la
## referencia frenándola, el equilibrio quedaba en 4,3 veces la
## referencia: medido a ocho temporadas, primera pasaba de 24 M a 62 M de
## media y seguía subiendo hacia el techo de FANS_MAX. Con +30/-22 el
## equilibrio del club promedio queda en ~1,56 veces la referencia — el
## mundo crece un poco y ahí se planta.
##
## Lo que NO se acota es el club que gana siempre: con +30% todas las
## temporadas el tirón no alcanza a frenarlo y crece hasta el techo. Es a
## propósito — es el club que se hace grande.
const CRECIMIENTO_CAMPEON := 0.30
const CRECIMIENTO_ULTIMO := -0.22

## Y además tira hacia la referencia de su división: un recién ascendido
## crece hacia su categoría nueva en unas temporadas en vez de saltar de
## golpe, y uno que descendió se desinfla. Es la fracción del camino que
## recorre por temporada.
##
## Tiene que ser CHICA. Con 0.25 el tirón se comía el resultado deportivo
## entero: un club que salía último cinco temporadas seguidas terminaba
## con más hinchas que al empezar, porque perder un 18% y después
## recorrer un cuarto del camino hacia la referencia daba positivo. Es
## el piso de la categoría, no el destino.
const ATRACCION_A_LA_REFERENCIA := 0.10

## Techo y piso: nadie tiene menos de un puñado de fieles ni más que el
## club más grande imaginable.
const FANS_MIN := 200.0
const FANS_MAX := 120000000.0

## Lo que mueve un partido suelto. Es chico a propósito: la hinchada la
## construye la TEMPORADA, no el partido del domingo. Se mantiene para que
## una racha se note dentro del año.
const GANANCIA_POR_VICTORIA := 0.004
const UMBRAL_RACHA_SIN_GANAR := 5
const PERDIDA_POR_RACHA := 0.006


## La hinchada que le corresponde a un club de esta division.
static func referencia(division: int) -> float:
	if division < 0:
		return REFERENCIA_POR_DIVISION[REFERENCIA_POR_DIVISION.size() - 1]
	return REFERENCIA_POR_DIVISION[clampi(division, 0, REFERENCIA_POR_DIVISION.size() - 1)]


static func inicial(division: int) -> float:
	return referencia(division) * FRACCION_INICIAL


## Qué tan grande es esta hinchada PARA SU CATEGORÍA, de 0 a 1.
##
## Es lo que consumen el público y la ocupación del estadio, y va en
## escala logarítmica a propósito: entre 2.000 y 4.000 hinchas hay la
## misma diferencia perceptible que entre 20 y 40 millones. Con el número
## crudo, cualquier club de primera saturaría en 1 y cualquiera de décima
## daría 0, y el estadio de décima estaría siempre vacío.
##
## La escala va de un CUARTO de la referencia (0) a CUATRO VECES la
## referencia (1), con la referencia justo en 0.5. La primera versión iba
## de la mitad al doble y no servía: como los clubes arrancan por debajo
## de su referencia, todos daban 0 —estadio vacío y ningún sponsor
## mirándote— y no había forma de distinguir a un club flojo de uno
## normal. Con dos octavas para cada lado hay lugar para crecer y para
## caerse.
const OCTAVAS := 2.0


static func apoyo(equipo: Team, division: int) -> float:
	var ref := referencia(division)
	if ref <= 0.0 or equipo.fans <= 0.0:
		return 0.0
	var t: float = (log(equipo.fans / ref) / log(2.0) / OCTAVAS + 1.0) / 2.0
	return clampf(t, 0.0, 1.0)


## Un partido jugado. Mueve poco: la hinchada la construye la temporada.
static func actualizar_por_resultado(equipo: Team, goles_propios: int, goles_rival: int) -> void:
	if goles_propios > goles_rival:
		equipo.fans = clampf(equipo.fans * (1.0 + GANANCIA_POR_VICTORIA), FANS_MIN, FANS_MAX)
		equipo.racha_sin_ganar = 0
		return
	equipo.racha_sin_ganar += 1
	if equipo.racha_sin_ganar >= UMBRAL_RACHA_SIN_GANAR:
		equipo.fans = clampf(equipo.fans * (1.0 - PERDIDA_POR_RACHA), FANS_MIN, FANS_MAX)


## El cierre de temporada: crece o se achica según dónde terminaste, y
## además tira hacia lo que le corresponde a su división.
static func actualizar_por_temporada(equipo: Team, posicion: int, total: int,
		division: int) -> void:
	# De +CRECIMIENTO_CAMPEON saliendo primero a CRECIMIENTO_ULTIMO
	# saliendo ultimo, lineal en el medio.
	var t: float = 1.0 - float(posicion - 1) / float(maxi(total - 1, 1))
	var tasa: float = lerpf(CRECIMIENTO_ULTIMO, CRECIMIENTO_CAMPEON, t)
	var nuevos: float = equipo.fans * (1.0 + tasa)
	# Y el tiron hacia la referencia de la division.
	var ref := referencia(division)
	nuevos = lerpf(nuevos, ref, ATRACCION_A_LA_REFERENCIA)
	equipo.fans = clampf(nuevos, FANS_MIN, FANS_MAX)


## Ascender o descender cambia de categoria de hinchada: el tiron hacia la
## referencia nueva hace el resto en las temporadas siguientes, pero el
## salto en si tambien se nota en el momento.
static func actualizar_por_movimiento_de_division(equipo: Team, ascendio: bool) -> void:
	var factor: float = 1.5 if ascendio else 0.7
	equipo.fans = clampf(equipo.fans * factor, FANS_MIN, FANS_MAX)


## "2,4 M" / "18 mil" / "850". Un numero de ocho digitos no se lee.
static func texto(cantidad: float) -> String:
	if cantidad >= 1000000.0:
		return "%.1f M" % (cantidad / 1000000.0)
	if cantidad >= 1000.0:
		return "%.0f mil" % (cantidad / 1000.0)
	return "%d" % int(round(cantidad))


## Hasta la v1.5 `fans` era un puntaje de 0 a 100. Cualquier valor por
## debajo de este tope viene de una partida vieja: no hay club con
## doscientos hinchas (FANS_MIN es 200 y la decima arranca en 1.225).
const TOPE_ESCALA_VIEJA := 150.0


## Reinterpreta el puntaje viejo como lo que significaba —que tan grande
## era la hinchada para su division— y devuelve la cantidad equivalente.
## Es la inversa de apoyo(): 0 = un cuarto de la referencia, 100 = cuatro
## veces la referencia.
static func migrar_del_puntaje_viejo(puntaje: float, division: int) -> float:
	var t: float = clampf(puntaje, 0.0, 100.0) / 100.0
	var exponente: float = lerpf(-OCTAVAS, OCTAVAS, t)
	return clampf(referencia(division) * pow(2.0, exponente), FANS_MIN, FANS_MAX)


## La inversa de apoyo(): cuantos hinchas hacen falta para llegar a este
## apoyo en esta division. Es para MOSTRAR el requisito de un sponsor —
## "pide una hinchada de 45 mil" se entiende, "pide apoyo 0.5" no.
static func fans_para_apoyo(apoyo_objetivo: float, division: int) -> float:
	var exponente: float = lerpf(-OCTAVAS, OCTAVAS, clampf(apoyo_objetivo, 0.0, 1.0))
	return clampf(referencia(division) * pow(2.0, exponente), FANS_MIN, FANS_MAX)
