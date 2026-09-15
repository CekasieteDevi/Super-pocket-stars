class_name Motivacion
extends RefCounted

## §8.4 #26-30: los modificadores de MOTIVACIÓN, que son los que llenan el
## bloque D.
##
## Medido dentro de media temporada real, el bloque D estaba vacío en el
## 91% de los duelos: promediaba 0,27 sobre un tope de 12, mientras los
## otros tres bloques se usaban en el 99,8%. La causa era que de los cinco
## modificadores que el GDD le asigna, cuatro no existían y el único que
## sí (#30) estaba sumado al bloque C por error.
##
## Acá viven los que se pueden construir con lo que el juego ya sabe:
##
##   #26 Ex club — +4 contra su ex equipo.
##   #27 Título o descenso en juego en las últimas 5 fechas — +4.
##
##   #28 David vs Goliat — +3 al de división muy inferior en copa.
##
## El único que sigue sin existir es:
##
##   #29 Presión de la prensa (−3 tras una nota negativa) necesita prensa
##       que corra DURANTE la temporada. Hoy las noticias se generan solo
##       al cerrar el año, así que no hay nada que pueda pesar en la fecha
##       siguiente.

## §8.4#26. Volver a jugar contra el club que te dejó ir motiva.
const BONUS_EX_CLUB := 4.0

## §8.4#27. Quedan pocas fechas y hay algo en juego de verdad.
const BONUS_RECTA_FINAL := 4.0
const FECHAS_DE_RECTA_FINAL := 5

## §8.4#28. El efecto copa: el chico que se cruza a uno de arriba juega
## el partido de su vida. Solo el CHICO lo recibe.
const BONUS_DAVID := 3.0

## Cuántas categorías de diferencia hacen falta para que el cruce cuente
## como "división muy inferior". Con una sola no alcanza: un club de
## quinta contra uno de cuarta es un rival difícil, no una hazaña.
const DIVISIONES_DE_DIFERENCIA := 2


## Cuántos puestos desde arriba cuentan como "peleando el título" y desde
## abajo como "peleando el descenso". Coinciden con las zonas reales de
## la pirámide (ver core/piramide.gd): 1° a 3° suben o pelean el playoff,
## 18° a 20° bajan o lo juegan.
const PUESTOS_DE_ARRIBA := 3
const PUESTOS_DE_ABAJO := 3


## §3: el ánimo entra al duelo. Lineal alrededor de 50, que es neutro y
## es donde nace todo jugador: con 100 suma esto, con 0 lo resta. El
## ±3 queda por debajo de los bonus de ocasión (+4) porque el ánimo está
## prendido todo el año y los otros solo en partidos puntuales.
##
## Medido con tests/_diag_animo_bola_de_nieve.gd (divisiones 1, 5 y 10,
## 4 semillas): el desvío de puntos pasa de ~16 a ~17,5 y queda dentro
## del ruido entre semillas. Subir Team.DERIVA_ANIMO_POR_SEMANA a 1,5 o 2
## no achica esa brecha y aplasta el ánimo contra 50: con 2, el top 3
## termina en 55 y el bonus casi desaparece. Por eso la deriva quedó en 1.
const BONUS_ANIMO_MAXIMO := 3.0


## Lo que suma la motivación para este jugador en este partido.
static func modificador(jugador: Dictionary, equipo: Team, rival: Team) -> float:
	var animo: float = clampf(equipo.animo.get(jugador["id"], 50.0), 0.0, 100.0)
	var total := (animo - 50.0) / 50.0 * BONUS_ANIMO_MAXIMO
	if es_ex_club(jugador, rival):
		total += BONUS_EX_CLUB
	if equipo.recta_final_caliente:
		total += BONUS_RECTA_FINAL
	if es_david(equipo, rival):
		total += BONUS_DAVID
	return total


## ¿Es el chico de un cruce de copa contra alguien de mucho mas arriba?
##
## `division_actual` es 0 para primera, asi que un numero MAS ALTO es una
## categoria peor. Si alguno de los dos no sabe en que division esta
## (-1), no hay efecto copa: es mejor no dar nada que dar el bonus al
## que no corresponde.
static func es_david(equipo: Team, rival: Team) -> bool:
	if not equipo.en_copa:
		return false
	if equipo.division_actual < 0 or rival.division_actual < 0:
		return false
	return equipo.division_actual - rival.division_actual >= DIVISIONES_DE_DIFERENCIA


static func es_ex_club(jugador: Dictionary, rival: Team) -> bool:
	var ex: Array = jugador.get("ex_clubes", [])
	return ex.has(rival.nombre)


## Marca a los equipos que se juegan algo en las últimas fechas. Lo llama
## Liga antes de cada fecha, para los veinte de la división.
##
## Se mira la tabla del momento y no el objetivo de la directiva: pelear
## el descenso motiva aunque tu objetivo del año fuera otro, y al revés,
## un club que ya cumplió su objetivo sigue peleando el título si está
## tercero a cuatro fechas del final.
static func marcar_recta_final(liga: Liga, fecha_idx: int) -> void:
	var faltan: int = liga.fixture.size() - fecha_idx
	var en_recta: bool = faltan <= FECHAS_DE_RECTA_FINAL
	if not en_recta:
		for e in liga.equipos:
			e.recta_final_caliente = false
		return

	var orden: Array = liga.tabla_ordenada()
	var total: int = orden.size()
	for e in liga.equipos:
		var pos: int = orden.find(e.nombre) + 1
		e.recta_final_caliente = pos > 0 and (
			pos <= PUESTOS_DE_ARRIBA or pos > total - PUESTOS_DE_ABAJO)
