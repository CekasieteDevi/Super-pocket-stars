class_name Personalidad
extends RefCounted

## Personalidades — Fase 9 (GDD §6, §15 decisión 6 y 17). Regla de
## generación: 1 rasgo positivo + 1 negativo, o ninguno de los dos —
## nunca uno solo suelto.
##
## Interpretación del "~8% cada una del pool positivo" del GDD (ambiguo
## sobre si aplica a las fuertes o a las comunes): acá las fuertes son
## ~20% del total repartido parejo entre las 8 (≈2,5% cada una) y las
## comunes ~80% repartido entre las 10 (≈8% cada una) — clama "8% cada
## una" para las comunes y dejan las fuertes genuinamente raras, que es
## la intención explícita del texto ("raras").
##
## No todos los efectos están conectados todavía: los que dependen de
## sistemas que no existen (minutos finales de partido, consistencia)
## quedan documentados como pendientes en vez de aproximados a la fuerza.
## Penales, tarjetas y convocatoria (selección) ya EXISTEN como sistemas
## (Penales, MatchEngine._chequear_tarjeta, Seleccion) pero todavía sin
## un rasgo de personalidad propio conectado ahí (por ejemplo, Clutch
## debería rendir mejor en penales) — pendiente real, no solo teórico
## ahora. Mentores sí está conectado (core/mentores.gd, vía
## Progresion.aplicar_temporada).

const DATA_PATH := "res://data/personalidades.json"
const P_CON_PERSONALIDAD := 0.70
const P_FUERTE_DENTRO_DE_POSITIVAS := 0.20

static var _datos_cache: Dictionary = {}


static func _datos() -> Dictionary:
	if _datos_cache.is_empty():
		_datos_cache = DataLoader.load_json(DATA_PATH)
	return _datos_cache


## Devuelve {} (sin rasgos) o {"positiva":String, "negativa":String}.
static func generar(rng: RandomNumberGenerator) -> Dictionary:
	if rng.randf() >= P_CON_PERSONALIDAD:
		return {}

	var datos := _datos()
	var positiva: String
	if rng.randf() < P_FUERTE_DENTRO_DE_POSITIVAS:
		var fuertes: Array = datos["fuertes"]
		positiva = fuertes[rng.randi() % fuertes.size()]
	else:
		var comunes: Array = datos["comunes"]
		positiva = comunes[rng.randi() % comunes.size()]

	var negativas: Array = datos["negativas"]
	var negativa: String = negativas[rng.randi() % negativas.size()]

	return {"positiva": positiva, "negativa": negativa}


static func tiene(jugador: Dictionary, nombre: String) -> bool:
	var p: Dictionary = jugador.get("personalidades", {})
	return p.get("positiva", "") == nombre or p.get("negativa", "") == nombre


## §7.4/§6: Trabajador +10%, Vago -40% de ganancia en entrenamiento.
static func factor_entrenamiento(jugador: Dictionary) -> float:
	if tiene(jugador, "Trabajador"):
		return 1.10
	if tiene(jugador, "Vago"):
		return 0.60
	return 1.0


## §2.3/§6: Ejemplar físico reduce a la mitad el riesgo de lesión,
## De cristal lo duplica.
static func factor_lesion(jugador: Dictionary) -> float:
	if tiene(jugador, "Ejemplar fisico"):
		return 0.5
	if tiene(jugador, "De cristal"):
		return 2.0
	return 1.0


## §7.4: Profesional recupera energía más rápido entre partidos;
## Fiestero la pierde más rápido (acá, se recupera más lento).
static func factor_recuperacion_fatiga(jugador: Dictionary) -> float:
	if tiene(jugador, "Profesional"):
		return 1.3
	if tiene(jugador, "Fiestero"):
		return 0.6
	return 1.0


## §9.1: Mercenario pide sueldo alto; Hincha del club acepta menos.
static func factor_sueldo(jugador: Dictionary) -> float:
	if tiene(jugador, "Mercenario"):
		return 1.35
	if tiene(jugador, "Hincha del club"):
		return 0.85
	return 1.0


## §3/§6: cuánto suma o resta este jugador a la armonía de vestuario al
## entrar al plantel.
static func bonus_armonia(jugador: Dictionary) -> float:
	var total := 0.0
	if tiene(jugador, "Lider nato"):
		total += 3.0
	if tiene(jugador, "Sociable"):
		total += 1.0
	if tiene(jugador, "Conflictivo"):
		total -= 3.0
	return total


## §8.4 modificador 25 (visitante) y comportamiento de Egoísta: bloque D
## del duelo (§8.5) para ESTE jugador en ESTE partido. Ansioso -4% de
## visitante; Egoísta favorece su propio tiro por sobre el pase del
## equipo. El resto de los rasgos con efecto en partido (Clutch, Frágil
## mental, Lento de arranque, Se apaga, Protagonista...) necesitan
## contexto que el motor todavía no distingue (penales, finales, minuto
## exacto del partido, fuerza relativa del rival) y quedan pendientes.
static func modificador_partido(jugador: Dictionary, es_local: bool, atributo: String) -> float:
	var mod := 0.0
	if tiene(jugador, "Ansioso") and not es_local:
		mod -= 4.0
	if tiene(jugador, "Egoista") and atributo == "tiro":
		mod += 2.0
	return mod
