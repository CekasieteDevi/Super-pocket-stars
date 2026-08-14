class_name Clima
extends RefCounted

## Clima del partido (§8.4 #18-20) — se sortea una vez por partido, no por
## club: es ambiental, afecta a los dos equipos por igual. 5% de que salga
## algo distinto de un día normal (a pedido explícito, para que sea un
## evento raro y no algo que se ve todos los partidos).
const PROB_CLIMA_ESPECIAL := 0.05
const OPCIONES := ["Lluvia", "Calor", "Viento"]

const MALUS_LLUVIA := 6.0
const MALUS_VIENTO := 8.0
const FACTOR_ENERGIA_CALOR := 1.3  # "energía cae 30% más rápido"

## "" = día normal (95% de las veces).
static func generar(rng: RandomNumberGenerator) -> String:
	if rng.randf() >= PROB_CLIMA_ESPECIAL:
		return ""
	return OPCIONES[rng.randi() % OPCIONES.size()]


## Bloque C ambiental — mismo valor para los dos equipos, así que no
## favorece a ninguno por sí solo: solo entra si ESE jugador está haciendo
## la acción que ese clima castiga (gambeta/control con lluvia, tiro con
## viento), no como un bonus/malus parejo que se cancelaría en el neto.
## §8.4: lluvia también castiga el agarre del arquero — se aproxima con el
## mismo malus sobre "reflejos" (el atributo que ya usa el arquero en el
## duelo de tiro a puerta), no hay un atributo "agarre" aislado en el motor.
static func modificador(clima: String, atributo: String) -> float:
	match clima:
		"Lluvia":
			if atributo == "control" or atributo == "reflejos":
				return -MALUS_LLUVIA
		"Viento":
			if atributo == "tiro":
				return -MALUS_VIENTO
	return 0.0


## Calor no es un modificador de bloque C — acelera el desgaste real
## (Team.desgastar), no la probabilidad de un duelo puntual.
static func factor_energia(clima: String) -> float:
	return FACTOR_ENERGIA_CALOR if clima == "Calor" else 1.0
