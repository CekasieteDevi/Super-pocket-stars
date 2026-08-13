class_name Duel
extends RefCounted

## Motor de duelo — GDD §8.1, §8.5, §8.6.
## P_final = clamp(P_base*100 + mod_neto, 3, 97), con mod_neto = clamp(mod_atacante - mod_defensor, -25, 25)
## y cada bloque (A/B/C/D) topeado antes de sumarse.

const BLOCK_CAPS := {"A": 15.0, "B": 15.0, "C": 15.0, "D": 12.0}
const MOD_NETO_CAP := 25.0
const P_MIN := 3.0
const P_MAX := 97.0

## Cuánto castiga la energía baja a cada grupo de atributos (§8.1: los físicos
## se resienten fuerte, los técnicos poco, los mentales casi nada).
const ENERGIA_K := {"fisico": 0.35, "tecnico": 0.15, "defensivo": 0.20, "mental": 0.05}


static func factor_energia(grupo: String, energia_pct: float) -> float:
	var k: float = ENERGIA_K.get(grupo, 0.15)
	return 1.0 - (1.0 - clamp(energia_pct, 0.0, 1.0)) * k


static func atributo_efectivo(valor: float, grupo: String, energia_pct: float) -> float:
	return valor * factor_energia(grupo, energia_pct)


static func p_base(atacante_efectivo: float, defensor_efectivo: float) -> float:
	var diff := atacante_efectivo - defensor_efectivo
	return 100.0 / (1.0 + pow(10.0, -diff / 25.0))


static func _clamp_bloque(valor: float, bloque: String) -> float:
	var cap: float = BLOCK_CAPS[bloque]
	return clamp(valor, -cap, cap)


## bloques: Dictionary con hasta las claves "A","B","C","D" -> suma cruda de
## los modificadores de ese bloque. Bloques ausentes cuentan como 0 (todavía
## no implementados en esta fase, ej. clima o ánimo de temporada).
static func _mod_total(bloques: Dictionary) -> float:
	var total := 0.0
	for b in bloques:
		total += _clamp_bloque(bloques[b], b)
	return total


static func resolver(atacante_efectivo: float, defensor_efectivo: float,
		bloques_atacante: Dictionary, bloques_defensor: Dictionary) -> Dictionary:
	var base := p_base(atacante_efectivo, defensor_efectivo)
	var mod_a := _mod_total(bloques_atacante)
	var mod_d := _mod_total(bloques_defensor)
	var neto: float = clamp(mod_a - mod_d, -MOD_NETO_CAP, MOD_NETO_CAP)
	var final_p: float = clamp(base + neto, P_MIN, P_MAX)
	return {"base": base, "mod_atacante": mod_a, "mod_defensor": mod_d, "neto": neto, "final": final_p}


static func gana_atacante(resultado: Dictionary, rng: RandomNumberGenerator) -> bool:
	return rng.randf() * 100.0 < resultado["final"]
