class_name Reputacion
extends RefCounted

## El PRESTIGIO del club: cuánto pesa su nombre.
##
## Antes se movía en un solo lugar y por una sola cosa —dónde terminabas
## en la tabla, ±2,5 por temporada—, así que ganar la Copa del Rey, subir
## de categoría o meterse en una internacional no valían nada. Y como
## arranca según la media del plantel, en la práctica la reputación era un
## sinónimo de "en qué división estás": ir de 35 a 70 eran quince
## temporadas ganando la liga.
##
## Ahora la mueven los TÍTULOS y los ascensos además de la tabla, y se
## mueve más rápido. Lo que sigue siendo cierto es que es lenta: es el
## prestigio, no la forma. Una gran temporada suma unos pocos puntos; lo
## que cambia un club es encadenar varias.
##
## La consumen la ocupación del estadio, la resistencia del vendedor en el
## mercado, el escalón del objetivo de la directiva y —desde ahora— el
## mínimo que piden los sponsors.

const MINIMO := 0.0
const MAXIMO := 100.0

## La tabla: de +4 saliendo primero a -4 saliendo último. El doble que
## antes, porque con ±2,5 una carrera entera no alcanzaba para cambiar de
## escalón.
const POR_TABLA := 4.0

## Los títulos. La copa de tu división vale poco —son cinco partidos entre
## los mismos veinte de siempre—, la liga vale, el Rey vale mucho porque
## es contra las diez divisiones, y una internacional te cambia el nombre.
const POR_LIGA := 5.0
const POR_COPA_DIVISION := 2.0
const POR_COPA_DEL_REY := 8.0
const POR_INTERNACIONAL := 12.0

## Subir y bajar de categoría. Bajar duele más que subir: costar años
## construir y una temporada perderlo es lo que hace que descender se
## sienta.
const POR_ASCENSO := 6.0
const POR_DESCENSO := -8.0

## Y cada temporada tira un poco hacia lo que le corresponde a su
## división. Sin esto la reputación DERIVA: medido sobre ocho
## temporadas, la décima caía de 34 a 27 de media —le entran los
## descendidos con su -8 y no tiene nada abajo que la compense— y la
## segunda tenía clubes con más prestigio que los de primera. Como los
## sponsors piden un mínimo relativo a la división, esa deriva terminaba
## secando de sponsors a las divisiones de abajo.
##
## Es chica a propósito: un club que gana no vuelve al montón, se queda
## arriba. Lo que hace es que la categoría sea el piso y el techo
## naturales, y que el prestigio que ganaste sea TUYO y no del ruido.
const ATRACCION_A_LA_REFERENCIA := 0.10


## Lo que suma la posición final: lineal, de +POR_TABLA al primero a
## -POR_TABLA al último, cero en el medio de la tabla.
static func por_posicion(posicion: int, total: int) -> float:
	if total <= 1:
		return 0.0
	var t: float = 1.0 - float(posicion - 1) / float(total - 1)
	return lerpf(-POR_TABLA, POR_TABLA, t)


## Aplica un cambio dejando la reputación dentro de rango.
static func sumar(equipo: Team, cuanto: float) -> void:
	equipo.reputacion = clampf(equipo.reputacion + cuanto, MINIMO, MAXIMO)


## Cuánto vale un título, por su clave. Las claves son las que usa la
## vitrina (ver GameState._anotar_en_la_vitrina) para que no haya dos
## listas de nombres de títulos que se puedan desincronizar.
static func por_titulo(titulo: String) -> float:
	if titulo == "Liga":
		return POR_LIGA
	if titulo == "Copa de división":
		return POR_COPA_DIVISION
	if titulo == "Copa del Rey":
		return POR_COPA_DEL_REY
	if titulo.begins_with("Copa de "):
		# Campeones, Guerreros, Emergentes.
		return POR_INTERNACIONAL
	return 0.0


## La reputación que le corresponde a un club NORMAL de esta división.
##
## No es una tabla nueva: es la misma cuenta con la que nace la reputación
## de un club (Economia.reputacion_inicial) aplicada a la media típica de
## la división (NivelDivision.media_de). Así hay un solo lugar donde vive
## la relación entre nivel y prestigio, y si se toca el gradiente esto se
## mueve solo. Da ~77 en primera y ~35 en décima.
##
## La usan los sponsors: el mínimo que pide cada uno es esta referencia
## más un escalón según lo que paga.
static func referencia(division: int) -> float:
	# Sin division conocida se toma la mas baja, no la mas alta: un -1 que
	# se colara como "primera" le pediria prestigio de primera a un club
	# de decima y lo dejaria sin un solo sponsor.
	var d: int = division if division >= 0 else NivelDivision.NIVELES.size() - 1
	return Economia.reputacion_inicial(NivelDivision.media_de(d))


## El tirón de cada temporada hacia la reputación que le corresponde a la
## división en la que juega. Va en el cierre de temporada, después de la
## tabla y antes de que los ascensos muevan a nadie.
static func tirar_a_la_referencia(equipo: Team, division: int) -> void:
	equipo.reputacion = clampf(
		lerpf(equipo.reputacion, referencia(division), ATRACCION_A_LA_REFERENCIA),
		MINIMO, MAXIMO)
