class_name Arbitro
extends RefCounted

## Árbitro del partido (§8.4 #23) — se sortea uno de los tres tipos por
## partido, siempre hay alguno dirigiendo (a diferencia del clima, acá no
## existe un "árbitro normal" separado en el GDD).
const TIPOS := ["Estricto", "Permisivo", "Casero"]

const FACTOR_TARJETAS_ESTRICTO := 1.5
const FACTOR_TARJETAS_PERMISIVO := 0.6
const BONUS_CASERO := 2.0


static func generar(rng: RandomNumberGenerator) -> String:
	return TIPOS[rng.randi() % TIPOS.size()]


## Multiplica las chances base de amarilla/roja del motor (MatchEngine.
## CHANCE_AMARILLA/CHANCE_ROJA_DIRECTA).
static func factor_tarjetas(arbitro: String) -> float:
	match arbitro:
		"Estricto":
			return FACTOR_TARJETAS_ESTRICTO
		"Permisivo":
			return FACTOR_TARJETAS_PERMISIVO
	return 1.0


## Bloque C — el árbitro "casero" favorece al local, nada más. Estricto/
## Permisivo solo tocan tarjetas (factor_tarjetas), no la probabilidad de
## los duelos.
static func modificador(arbitro: String, es_local: bool) -> float:
	if arbitro == "Casero" and es_local:
		return BONUS_CASERO
	return 0.0
