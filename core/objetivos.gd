class_name Objetivos
extends RefCounted

## Objetivos de directiva y game over (§10.5/§15: "Objetivos de directiva
## por temporada. Si no cumplís 2 seguidos, te echan → fin de partida"; y
## el Fix #6: "en división 10 no hay descenso: si terminás último 2 años
## seguidos → quiebra deportiva / game over" — ambas reglas se resuelven
## con el mismo mecanismo acá, el objetivo de la última división ES "no
## terminar último").
##
## El objetivo se arma según la reputación del club y la división en la
## que va a jugar la temporada que arranca — no hay un "objetivo real"
## explícito en el GDD más allá de ese ejemplo, así que se definieron 4
## niveles de ambición razonables por reputación.

const MAX_INCUMPLIDOS_SEGUIDOS := 2

## §12 (Piramide): 19° y 20° de 20 descienden directo — evitar el
## descenso significa terminar por encima de esa zona (con margen de un
## puesto extra por el 18° que juega playoff, más seguro que justo al límite).
const MARGEN_ZONA_DESCENSO := 2


static func generar(equipo: Team, es_ultima_division: bool, total_equipos: int) -> Dictionary:
	if es_ultima_division:
		return {
			"tipo": "sobrevivir",
			"descripcion": "No terminar último de la división (evitar la quiebra deportiva).",
			"posicion_maxima": total_equipos - 1,
		}
	if equipo.reputacion >= 70.0:
		return {
			"tipo": "titulo",
			"descripcion": "Pelear el título: terminar entre los primeros 3.",
			"posicion_maxima": 3,
		}
	if equipo.reputacion >= 45.0:
		var mitad: int = int(ceil(total_equipos / 2.0))
		return {
			"tipo": "mitad_superior",
			"descripcion": "Terminar en la mitad superior de la tabla (entre los primeros %d)." % mitad,
			"posicion_maxima": mitad,
		}
	var limite: int = total_equipos - MARGEN_ZONA_DESCENSO
	return {
		"tipo": "evitar_descenso",
		"descripcion": "Evitar el descenso: terminar entre los primeros %d." % limite,
		"posicion_maxima": limite,
	}


## Sin objetivo asignado (partida recién migrada de un guardado viejo, o
## un club de la IA que nunca tiene uno) no penaliza — se considera
## cumplido para no gatillar un game over de la nada.
static func evaluar(objetivo: Dictionary, posicion_final: int) -> bool:
	if objetivo.is_empty():
		return true
	return posicion_final <= objetivo["posicion_maxima"]


## §8.4 #30 "Objetivo de directiva en riesgo — −2 (tensión)": solo entra
## en las últimas FECHAS_TENSION fechas de la temporada (una reacción
## tardía a la presión, no algo que pesa desde la fecha 1), y solo si la
## posición actual todavía no cumple el objetivo.
const FECHAS_TENSION := 5
const MALUS_EN_RIESGO := -2.0


static func esta_en_riesgo(objetivo: Dictionary, posicion_actual: int, fecha_actual: int, total_fechas: int) -> bool:
	if objetivo.is_empty():
		return false
	if fecha_actual < total_fechas - FECHAS_TENSION:
		return false
	return posicion_actual > objetivo["posicion_maxima"]
