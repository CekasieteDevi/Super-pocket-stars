class_name Mentores
extends RefCounted

## Mentores (§6 extendido): un veterano con la personalidad correcta
## acelera el desarrollo de los jóvenes de su propio plantel. Estaba
## documentado como pendiente en Personalidad desde que existen las
## personalidades ("necesita contexto que el motor todavía no distingue")
## — ahora que Progresion.aplicar_temporada corre por jugador dentro de un
## plantel conocido (Liga.procesar_economia_y_mercado_y_progresion), hay
## un lugar real donde engancharlo.
##
## Requisito para ser mentor: 28 años o más y alguno de los rasgos que
## hablan de liderazgo/profesionalismo. Beneficia a los jóvenes (≤21) del
## MISMO plantel — no hace falta que jueguen en la misma posición, un
## vestuario con códigos ayuda a cualquiera.

const EDAD_MINIMA_MENTOR := 28
const EDAD_MAXIMA_APRENDIZ := 21

## No se suman entre sí: el mejor rasgo presente en el plantel es el que
## cuenta (un plantel no se vuelve una academia solo por tener 3
## profesionales dando vueltas).
const BONUS_POR_RASGO := {
	"Lider nato": 0.20, "Profesional": 0.12, "Metodico": 0.10,
}


static func es_mentor(jugador: Dictionary) -> bool:
	if jugador["edad"] < EDAD_MINIMA_MENTOR:
		return false
	for rasgo in BONUS_POR_RASGO:
		if Personalidad.tiene(jugador, rasgo):
			return true
	return false


static func es_aprendiz(jugador: Dictionary) -> bool:
	return jugador["edad"] <= EDAD_MAXIMA_APRENDIZ


## El mejor bonus de mentoría disponible en todo el plantel (titulares +
## banco + cantera: un veterano en cantera cuenta tan mentor como uno
## titular, el vestuario es el mismo club).
static func mejor_bonus_disponible(equipo: Team) -> float:
	var mejor := 0.0
	for j in equipo.todos_los_jugadores() + equipo.cantera:
		if j["edad"] < EDAD_MINIMA_MENTOR:
			continue
		for rasgo in BONUS_POR_RASGO:
			if Personalidad.tiene(j, rasgo) and BONUS_POR_RASGO[rasgo] > mejor:
				mejor = BONUS_POR_RASGO[rasgo]
	return mejor


## El multiplicador de crecimiento a aplicar sobre ESTE jugador puntual,
## dado el mejor bonus disponible en su plantel — 1.0 si no es aprendiz o
## si nadie en el plantel califica como mentor.
static func multiplicador_para(jugador: Dictionary, bonus_disponible: float) -> float:
	return 1.0 + bonus_disponible if es_aprendiz(jugador) else 1.0
