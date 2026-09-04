class_name Objetivos
extends RefCounted

## Objetivos de directiva y game over (§10.5/§15: "Objetivos de directiva
## por temporada. Si no cumplís 2 seguidos, te echan → fin de partida"; y
## el Fix #6: "en división 10 no hay descenso: si terminás último 2 años
## seguidos → quiebra deportiva / game over" — ambas reglas se resuelven
## con el mismo mecanismo acá, el objetivo de la última división ES "no
## terminar último").
##
## No hay un catálogo de "objetivo real" explícito en el GDD más allá del
## ejemplo de posición en la tabla, así que se armaron 3 categorías
## razonables para un directorio real: tabla (posición final, como antes),
## copa (llegar lejos en la Copa Nacional) y cantera (hacer debutar
## juveniles). La última división es siempre "tabla" (el Fix #6 es
## específicamente sobre no descender/no terminar último, no tiene
## sentido mezclarlo con copa o cantera).

const MAX_INCUMPLIDOS_SEGUIDOS := 2

## §12 (Piramide): 19° y 20° de 20 descienden directo — evitar el
## descenso significa terminar por encima de esa zona (con margen de un
## puesto extra por el 18° que juega playoff, más seguro que justo al límite).
const MARGEN_ZONA_DESCENSO := 2

## Reparto de categorías para divisiones que no son la última (ver
## generar) — la posición en la tabla sigue siendo la más común, como
## sería en un directorio real, pero copa/cantera le dan variedad.
const PROB_CATEGORIA_COPA := 0.25
const PROB_CATEGORIA_CANTERA := 0.15  # el resto (60%) es "tabla"


## `en_copa_nacional` = el club tiene cupo en el Rey de esta temporada.
## Sin cupo el objetivo de copa es imposible de cumplir y son dos
## incumplidos seguidos para que te echen, así que ese tramo del sorteo
## cae en "tabla". Se sigue tirando el mismo randf igual: la categoría
## cambia, la secuencia del rng no, y las semillas de los tests siguen
## valiendo.
static func generar(equipo: Team, es_ultima_division: bool, total_equipos: int,
		rng: RandomNumberGenerator, en_copa_nacional: bool = true) -> Dictionary:
	if es_ultima_division:
		return _generar_tabla(equipo, es_ultima_division, total_equipos)

	var roll := rng.randf()
	if roll < PROB_CATEGORIA_COPA:
		if not en_copa_nacional:
			return _generar_tabla(equipo, es_ultima_division, total_equipos)
		return _generar_copa(equipo)
	if roll < PROB_CATEGORIA_COPA + PROB_CATEGORIA_CANTERA:
		return _generar_cantera()
	return _generar_tabla(equipo, es_ultima_division, total_equipos)


static func _generar_tabla(equipo: Team, es_ultima_division: bool, total_equipos: int) -> Dictionary:
	if es_ultima_division:
		return {
			"categoria": "tabla", "tipo": "sobrevivir",
			"descripcion": "No terminar último de la división (evitar la quiebra deportiva).",
			"posicion_maxima": total_equipos - 1,
		}
	if equipo.reputacion >= 70.0:
		return {
			"categoria": "tabla", "tipo": "titulo",
			"descripcion": "Pelear el título: terminar entre los primeros 3.",
			"posicion_maxima": 3,
		}
	if equipo.reputacion >= 45.0:
		var mitad: int = int(ceil(total_equipos / 2.0))
		return {
			"categoria": "tabla", "tipo": "mitad_superior",
			"descripcion": "Terminar en la mitad superior de la tabla (entre los primeros %d)." % mitad,
			"posicion_maxima": mitad,
		}
	var limite: int = total_equipos - MARGEN_ZONA_DESCENSO
	return {
		"categoria": "tabla", "tipo": "evitar_descenso",
		"descripcion": "Evitar el descenso: terminar entre los primeros %d." % limite,
		"posicion_maxima": limite,
	}


## §10.1 (Copa Nacional, 128 clubes clasificados, eliminación directa —
## ver core/copa.gd Copa.rondas_ganadas y core/clasificacion_copas.gd). Un club de reputación alta debería llegar lejos;
## uno chico ya cumple ganando su primer cruce.
static func _generar_copa(equipo: Team) -> Dictionary:
	var rondas: int
	if equipo.reputacion >= 70.0:
		rondas = 5
	elif equipo.reputacion >= 45.0:
		rondas = 3
	else:
		rondas = 1
	return {
		"categoria": "copa",
		"descripcion": "Copa del Rey: ganar al menos %d ronda%s." % [rondas, "" if rondas == 1 else "s"],
		"rondas_minimas": rondas,
	}


## §17 (cantera): hacer debutar al menos un canterano (cantera->banco o
## banco->titular, ver Liga._procesar_cantera) en la temporada. Sin
## escalar por reputación — un club grande igual necesita mostrar que
## invierte en las juveniles.
const PROMOCIONES_MINIMAS_CANTERA := 1


static func _generar_cantera() -> Dictionary:
	return {
		"categoria": "cantera",
		"descripcion": "Hacer debutar al menos %d canterano%s en el plantel." % [PROMOCIONES_MINIMAS_CANTERA, "" if PROMOCIONES_MINIMAS_CANTERA == 1 else "s"],
		"promociones_minimas": PROMOCIONES_MINIMAS_CANTERA,
	}


## Sin objetivo asignado (partida recién migrada de un guardado viejo, o
## un club de la IA que nunca tiene uno) no penaliza — se considera
## cumplido para no gatillar un game over de la nada. contexto: {
## "posicion_final":int, "rondas_copa":int, "promociones_cantera":int } —
## solo hace falta llenar la clave que corresponda a la categoría real del
## objetivo, las demás se ignoran.
static func evaluar(objetivo: Dictionary, contexto: Dictionary) -> bool:
	if objetivo.is_empty():
		return true
	match objetivo.get("categoria", "tabla"):
		"copa":
			return int(contexto.get("rondas_copa", 0)) >= int(objetivo["rondas_minimas"])
		"cantera":
			return int(contexto.get("promociones_cantera", 0)) >= int(objetivo["promociones_minimas"])
		_:
			return int(contexto.get("posicion_final", 999999)) <= int(objetivo["posicion_maxima"])


## §8.4 #30 "Objetivo de directiva en riesgo — −2 (tensión)": solo entra
## en las últimas FECHAS_TENSION fechas de la temporada, y solo pesa para
## objetivos de categoría "tabla" — copa se resuelve de una sola vez al
## cierre (no hay "posición actual" a mitad de camino) y cantera no tiene
## sentido de urgencia por fecha (documentado, no una limitación grave).
const FECHAS_TENSION := 5
const MALUS_EN_RIESGO := -2.0


static func esta_en_riesgo(objetivo: Dictionary, posicion_actual: int, fecha_actual: int, total_fechas: int) -> bool:
	if objetivo.is_empty() or objetivo.get("categoria", "tabla") != "tabla":
		return false
	if fecha_actual < total_fechas - FECHAS_TENSION:
		return false
	return posicion_actual > objetivo["posicion_maxima"]
