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
## De los ~30 rasgos, quedan sin conectar los que piden un sistema que el
## motor todavía no tiene (offside, consistencia por duelo, calendario
## denso, convocatoria separada del plantel, racha de titular/banco) — ver
## el docstring de modificador_partido() para el detalle exacto. El resto
## ya engancha en algún lado real: bloque D del duelo
## (modificador_partido), penales (bonus_penal, ver Penales.gd), tarjetas
## (factor_amarilla/factor_roja, ver MatchEngine._chequear_tarjeta), ánimo
## post-partido (ajustar_delta_animo, ver Team.actualizar_post_partido),
## entrenamiento/lesión/sueldo/armonía (funciones más abajo) y mentores
## (core/mentores.gd, vía Progresion.aplicar_temporada).

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


## §8.4 modificador 25 (visitante), comportamiento de Egoísta, y los
## rasgos atados al minuto del partido: bloque D del duelo (§8.5) para
## ESTE jugador en ESTE partido. Ansioso -4% de visitante; Egoísta
## favorece su propio tiro por sobre el pase del equipo; Lento de arranque
## castiga los primeros 15'; Se apaga y Clutch/Frágil mental se reparten
## los últimos 15'/10' (Clutch y Frágil mental también entran en penales,
## ver Penales.gd → bonus_penal); Creador y Nunca rendirse dan un bonus
## pasivo en su atributo de firma (pases/quite) todo el partido.
##
## Pendientes reales (necesitan contexto que el motor todavía no
## distingue): Protagonista (fuerza relativa del rival jugador a jugador),
## Enfocado (no hay offside modelado), Adaptable (no hay penalización de
## "fuera de posición" que cancelar), Metódico (no hay variación de
## consistencia por duelo), Madrugador (no hay noción de calendario denso
## en el motor), Comodón/Rencoroso (necesitan contar partidos seguidos
## como titular/en el banco), Impuntual (no hay paso de "convocatoria"
## separado del plantel), Dependiente (definir "compañero clave" es
## ambiguo), Pie preferido (no se modela pierna dominante por acción).
const UMBRAL_ARRANQUE := 15
const UMBRAL_ULTIMOS_15 := 75
const UMBRAL_ULTIMOS_10 := 80
const MALUS_ARRANQUE := 5.0
const MALUS_SE_APAGA := 5.0
const BONUS_CLUTCH_PARTIDO := 5.0
const MALUS_FRAGIL_MENTAL_PARTIDO := 8.0
const BONUS_CREADOR := 3.0
const BONUS_NUNCA_RENDIRSE := 3.0


static func modificador_partido(jugador: Dictionary, es_local: bool, atributo: String, minuto: int = 0) -> float:
	var mod := 0.0
	if tiene(jugador, "Ansioso") and not es_local:
		mod -= 4.0
	if tiene(jugador, "Egoista") and atributo == "tiro":
		mod += 2.0
	if tiene(jugador, "Lento de arranque") and minuto <= UMBRAL_ARRANQUE:
		mod -= MALUS_ARRANQUE
	if tiene(jugador, "Se apaga") and minuto >= UMBRAL_ULTIMOS_15:
		mod -= MALUS_SE_APAGA
	if tiene(jugador, "Clutch") and minuto >= UMBRAL_ULTIMOS_15:
		mod += BONUS_CLUTCH_PARTIDO
	if tiene(jugador, "Fragil mental") and minuto >= UMBRAL_ULTIMOS_10:
		mod -= MALUS_FRAGIL_MENTAL_PARTIDO
	if tiene(jugador, "Creador") and atributo == "pases":
		mod += BONUS_CREADOR
	if tiene(jugador, "Nunca rendirse") and atributo == "quite":
		mod += BONUS_NUNCA_RENDIRSE
	return mod


## §8.7 (Penales.gd, fuera del duelo normal — mismo motivo que
## Habilidades.bonus_atajapenales): Pícaro suma su toque de picada,
## Clutch rinde mejor bajo presión, Frágil mental se derrumba.
const BONUS_PICARO_PENAL := 0.06
const BONUS_CLUTCH_PENAL := 0.05
const MALUS_FRAGIL_MENTAL_PENAL := 0.08


static func bonus_penal(jugador: Dictionary) -> float:
	var bonus := 0.0
	if tiene(jugador, "Picaro"):
		bonus += BONUS_PICARO_PENAL
	if tiene(jugador, "Clutch"):
		bonus += BONUS_CLUTCH_PENAL
	if tiene(jugador, "Fragil mental"):
		bonus -= MALUS_FRAGIL_MENTAL_PENAL
	return bonus


## §8.7 (MatchEngine._chequear_tarjeta): cuánto multiplica este jugador
## las chances base de tarjeta. Varios pueden aplicar a la vez (un jugador
## tiene como mucho 1 positiva + 1 negativa, y estos rasgos están
## repartidos en las dos listas), por eso se van MULTIPLICANDO en vez de
## cortar en el primer if que matchee.
const FACTOR_MALA_PINTA := 1.3
const FACTOR_CALENTON_AMARILLA := 1.3
const FACTOR_CALENTON_ROJA := 1.8
const FACTOR_LLORON_AMARILLA := 1.3
const FACTOR_CANCHERO := 0.7
const FACTOR_CALMADO := 0.85


static func factor_amarilla(jugador: Dictionary) -> float:
	var factor := 1.0
	if tiene(jugador, "Mala pinta"):
		factor *= FACTOR_MALA_PINTA
	if tiene(jugador, "Calenton"):
		factor *= FACTOR_CALENTON_AMARILLA
	if tiene(jugador, "Lloron"):
		factor *= FACTOR_LLORON_AMARILLA
	if tiene(jugador, "Canchero"):
		factor *= FACTOR_CANCHERO
	if tiene(jugador, "Calmado"):
		factor *= FACTOR_CALMADO
	return factor


static func factor_roja(jugador: Dictionary) -> float:
	var factor := 1.0
	if tiene(jugador, "Mala pinta"):
		factor *= FACTOR_MALA_PINTA
	if tiene(jugador, "Calenton"):
		factor *= FACTOR_CALENTON_ROJA
	if tiene(jugador, "Canchero"):
		factor *= FACTOR_CANCHERO
	if tiene(jugador, "Calmado"):
		factor *= FACTOR_CALMADO
	return factor


## §3/§6 (Team.actualizar_post_partido): Positivo no pierde ánimo por
## perder; Bajón lo pierde al doble; Ególatra lo pierde fuerte si no es
## "la figura" del equipo. Simplificación: el motor solo modela UN jugador
## destacado por equipo (el capitán, siempre el de mayor media — ver
## Team.recalcular_capitan), así que "ni capitán ni figura" se aproxima
## con "no es el capitán".
const MALUS_EGOLATRA := 4.0


static func ajustar_delta_animo(jugador: Dictionary, delta: float, es_capitan: bool) -> float:
	if delta < 0.0 and tiene(jugador, "Bajon"):
		delta *= 2.0
	if delta < 0.0 and tiene(jugador, "Positivo"):
		delta = 0.0
	if tiene(jugador, "Egolatra") and not es_capitan:
		delta -= MALUS_EGOLATRA
	return delta
