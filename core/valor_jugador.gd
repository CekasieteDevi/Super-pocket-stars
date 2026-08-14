class_name ValorJugador
extends RefCounted

## Valor de mercado del jugador — Fase 6 (GDD §9.2).
##
## f(media, edad, ánimo, habilidades, personalidad, premios, contrato
## restante, reputación del club). Acá entran media, edad, ánimo y contrato
## restante, que ya existen en el motor; habilidades/personalidad/premios y
## reputación de club quedan afuera hasta que existan esos sistemas (§5, §6,
## fase 9) y se documenta como simplificación, no como olvido.

const VALOR_BASE := 50000.0

const FACTOR_EDAD := [
	{"max": 20, "factor": 0.7},
	{"max": 23, "factor": 0.9},
	{"max": 29, "factor": 1.0},
	{"max": 32, "factor": 0.8},
	{"max": 35, "factor": 0.5},
	{"max": 999, "factor": 0.25},
]


static func _factor_edad(edad: int) -> float:
	for tramo in FACTOR_EDAD:
		if edad <= tramo["max"]:
			return tramo["factor"]
	return 0.25


## factor_contrato: antes iba de 0.4 (contrato por vencer) a 1.1 (recién
## renovado) — una renovación (2-4 años al azar, sin que el jugador haya
## cambiado en nada) podía casi DUPLICAR el valor de un día para el otro,
## haciendo que el valor de plantel saltara de forma que no tenía que ver
## con la calidad real del equipo. Sigue siendo cierto que un contrato
## corto resta valor de negociación (eso es real), pero con un rango más
## angosto (0.7-1.0) el efecto está presente sin dominar la valuación.
static func calcular(jugador: Dictionary, animo: float, contrato_restante: int) -> float:
	var factor_media: float = pow(max(jugador["media"], 1.0) / 50.0, 4.0)
	var factor_edad: float = _factor_edad(jugador["edad"])
	var factor_animo: float = 0.85 + (clamp(animo, 0.0, 100.0) / 100.0) * 0.3
	var factor_contrato: float = clamp(0.7 + 0.075 * contrato_restante, 0.7, 1.0)

	return VALOR_BASE * factor_media * factor_edad * factor_animo * factor_contrato
