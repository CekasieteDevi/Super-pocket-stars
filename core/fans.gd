class_name Fans
extends RefCounted

## Fans (§8.4 #22, "Público") — a diferencia de calidad_cancha/estilo/DT
## (identidad fija, horneada al generar el club), esto arranca en 0 para
## TODOS los clubes ("empezamos sin fans, no va nadie al estadio") y
## evoluciona con el tiempo: ganar partidos suma, una racha larga sin
## ganar resta, ascender/descender pesa fuerte. Team.fans (0-100),
## Team.racha_sin_ganar (contador auxiliar, no es la misma "racha" que
## Team.racha del motor de partido — esa es dentro de un partido, esta es
## entre partidos).
##
## Alimenta dos cosas: el modificador de bloque C de "público" (ver
## core/publico.gd) y la OCUPACION del estadio, donde suma hasta un +30%
## encima de la base de reputación (Economia.BONUS_OCUPACION_FANS).
##
## Lo segundo llegó después y este comentario decía lo contrario —que
## Fans deliberadamente no tocaba los ingresos— durante varias
## iteraciones, que es peor que no tener comentario: manda a buscar la
## plata de las entradas al lugar equivocado.

const GANANCIA_POR_VICTORIA := 0.5
const UMBRAL_RACHA_SIN_GANAR := 5  # partidos seguidos sin ganar antes de empezar a perder fans
const PERDIDA_POR_RACHA := 1.0
const BONUS_ASCENSO := 8.0
const PERDIDA_DESCENSO := 8.0
const FANS_MIN := 0.0
const FANS_MAX := 100.0


## Se llama una vez por equipo por partido jugado de verdad (no en un
## forfeit — ver Liga._actualizar_estado_jugadores). Un empate no suma ni
## resta por sí solo, pero SÍ cuenta como "no ganó" para la racha.
static func actualizar_por_resultado(equipo: Team, goles_propios: int, goles_rival: int) -> void:
	if goles_propios > goles_rival:
		equipo.fans = clamp(equipo.fans + GANANCIA_POR_VICTORIA, FANS_MIN, FANS_MAX)
		equipo.racha_sin_ganar = 0
		return

	equipo.racha_sin_ganar += 1
	if equipo.racha_sin_ganar >= UMBRAL_RACHA_SIN_GANAR:
		equipo.fans = clamp(equipo.fans - PERDIDA_POR_RACHA, FANS_MIN, FANS_MAX)


static func actualizar_por_movimiento_de_division(equipo: Team, ascendio: bool) -> void:
	if ascendio:
		equipo.fans = clamp(equipo.fans + BONUS_ASCENSO, FANS_MIN, FANS_MAX)
	else:
		equipo.fans = clamp(equipo.fans - PERDIDA_DESCENSO, FANS_MIN, FANS_MAX)
