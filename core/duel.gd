class_name Duel
extends RefCounted

## Motor de duelo — GDD §8.1, §8.5, §8.6.
## P_final = clamp(P_base*100 + mod_neto, 3, 97), con mod_neto = clamp(mod_atacante - mod_defensor, -25, 25)
## y cada bloque (A/B/C/D) topeado antes de sumarse.

const BLOCK_CAPS := {"A": 15.0, "B": 15.0, "C": 15.0, "D": 12.0}
const MOD_NETO_CAP := 25.0
const P_MIN := 3.0
const P_MAX := 97.0

## El castigo por cansancio sale de la franja de energía (Cansancio), igual
## para todos los grupos de atributos. Antes cada grupo tenía su pendiente
## continua (físico 0,35, técnico 0,15, defensivo 0,20, mental 0,05), y
## con la energía casi siempre arriba de 85% el castigo no se notaba.
## `grupo` queda en la firma porque lo pasan todos los llamadores.
static func atributo_efectivo(valor: float, _grupo: String, energia_pct: float) -> float:
	return valor * Cansancio.factor_stats(energia_pct)


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
