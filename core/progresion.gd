class_name Progresion
extends RefCounted

## Progresión por edad y entrenamiento — Fase 5 (GDD §7.1, §4 punto 2).
##
## Sin calendario semanal real todavía (eso necesita más UI/economía de
## fases posteriores), la ganancia de entrenamiento se aplica una sola vez
## por temporada, al final: crecimiento hacia el potencial para los jóvenes,
## declive diferenciado por grupo de atributos para los veteranos.

## La edad pesa poco a propósito: lo que decide el crecimiento son los
## minutos y el rendimiento. Con 2.0 a los 17 y un GOAT a 2.0, un DC de
## media 50 subía 23 puntos en una temporada y llegaba a 84 a los 18.
const CURVA_EDAD := [
	{"min": 15, "max": 18, "mult": 1.25},
	{"min": 19, "max": 23, "mult": 1.15},
	{"min": 24, "max": 28, "mult": 1.0},
	{"min": 29, "max": 32, "mult": 0.5},
	{"min": 33, "max": 35, "mult": 0.2},
	{"min": 36, "max": 37, "mult": 0.0},
]

## §7.1: los físicos bajan primero y más fuerte, los técnicos poco, y los
## mentales siguen subiendo un toque incluso en declive (valor negativo).
const DECLIVE_POR_GRUPO := {
	"fisico": 1.0,
	"defensivo": 0.6,
	"tecnico": 0.3,
	"mental": -0.15,
}

## §4 punto 2: un GOAT crece más rápido que un Del montón. La diferencia
## era 2x y se bajó a 1.3x porque el tier ya paga dos veces: el GOAT tiene
## el techo más alto, y la distancia al techo ya lo hace crecer más.
const VELOCIDAD_POR_TIER := {
	"GOAT": 1.3, "Idolo": 1.24, "Prodigio": 1.18, "Prometedor": 1.12,
	"Solido": 1.06, "Correcto": 1.03, "Del monton": 1.0, "Justito": 0.97,
	"Limitado": 0.94, "Descarte": 0.91,
}

## Fracción de la distancia al techo que se cierra por temporada, antes de
## multiplicadores. Calibrada con tests/_diag_desarrollo_por_rendimiento.gd.
const TASA_CRECIMIENTO := 0.08
## Rendimientos decrecientes: el crecimiento escala con
## (distancia / DISTANCIA_REFERENCIA) ^ EXPONENTE_CERCANIA. A 25 puntos del
## techo el factor es 1; a 5 puntos es 0.57; a 1 punto, 0.32. Los últimos
## puntos cuestan años.
const DISTANCIA_REFERENCIA := 25.0
const EXPONENTE_CERCANIA := 0.35

## §7.1 minutos: el que no juega crece a este piso. Entrenar sirve, pero
## sin partidos no alcanza.
const PISO_SIN_JUGAR := 0.25
## Partidos-equivalentes para el efecto pleno. Medido en la pirámide
## (tests/_diag_rendimiento_por_puesto.gd): el titular p75 juega 33 de 38.
const PARTIDOS_PLENOS := 30.0
## La cantera no juega la liga: juega sus propios partidos de juveniles.
## Cuenta como media temporada de titular.
const PARTIDOS_CANTERA := 15.0

## §7.1 rendimiento: el factor va de RENDIMIENTO_MINIMO a RENDIMIENTO_MAXIMO.
## Cada desvío por encima de lo esperable para su puesto suma
## RENDIMIENTO_POR_DESVIO.
const RENDIMIENTO_POR_DESVIO := 0.35
const RENDIMIENTO_MINIMO := 0.6
const RENDIMIENTO_MAXIMO := 1.5
## Partidos que hacen falta para creerle a la muestra a medias. Con 4
## partidos y dos goles, un DC no es un crack: el factor casi no se mueve.
const PARTIDOS_CONFIANZA := 10.0

## Lo esperable por puesto, por partido jugado: [media, desvío]. Medido en
## una temporada de la pirámide con tests/_diag_rendimiento_por_puesto.gd
## (semilla 777, jugadores con 10+ partidos). El motor abstracto solo hace
## goles a DC, EXT y MCO, y asistencias a esos tres y al MC: por eso un
## defensor se mide por los goles que recibe su equipo con él en cancha.
const REFERENCIA_PUESTO := {
	"ofensivo": {"DC": [0.48, 0.30], "EXT": [0.41, 0.23], "MCO": [0.27, 0.21], "MC": [0.12, 0.08]},
	"en_contra": [1.32, 0.54],
	"diferencia": [0.0, 0.92],
}
## Cuánto pesa cada cosa según el puesto: [ofensivo, en_contra, diferencia].
## Un DC vive del gol; un central, de que no le hagan goles; todos suman
## algo de lo que hace el equipo con ellos en cancha.
const PESOS_RENDIMIENTO := {
	"DC": [0.75, 0.0, 0.25],
	"EXT": [0.6, 0.0, 0.4],
	"MCO": [0.5, 0.0, 0.5],
	"MC": [0.4, 0.3, 0.3],
	"LAT": [0.0, 0.6, 0.4],
	"DFC": [0.0, 0.7, 0.3],
	"ARQ": [0.0, 0.8, 0.2],
}

const ATTR_GROUPS_PATH := "res://data/attribute_groups.json"
static var _attr_grupo_cache: Dictionary = {}


static func _grupo_de_atributo(attr: String) -> String:
	if _attr_grupo_cache.is_empty():
		var groups = DataLoader.load_json(ATTR_GROUPS_PATH)
		var normalizado := {
			"fisicos": "fisico", "tecnicos": "tecnico",
			"defensivos": "defensivo", "mentales": "mental", "arquero": "tecnico",
		}
		for grupo in groups:
			for attr_nombre in groups[grupo]:
				_attr_grupo_cache[attr_nombre] = normalizado.get(grupo, "tecnico")
	return _attr_grupo_cache.get(attr, "tecnico")


static func _multiplicador_crecimiento(edad: int) -> float:
	for tramo in CURVA_EDAD:
		if edad >= tramo["min"] and edad <= tramo["max"]:
			return tramo["mult"]
	return -1.0  # 38+: declive


## §7.3 aprendizaje por uso. El atributo que MÁS usó en la temporada
## crece hasta un `MULTIPLICADOR_USO` más rápido; el resto, en proporción
## a cuánto lo usó. Todo escalado por cuánto jugó: un suplente que sumó
## cuatro partidos no aprende como un titular.
##
## Se normaliza contra el uso MÁXIMO del propio jugador y no contra una
## tabla por atributo, porque las escalas no son comparables: un volante
## da 40 pases por partido y remata una vez, y con una referencia común
## el `tiro` nunca sumaría nada para nadie. Lo que interesa es en qué
## gasta SUS acciones.
const MULTIPLICADOR_USO := 0.40
## Partidos-equivalentes de titular para llegar al efecto pleno. Una
## temporada son ~38 fechas, así que con media temporada de titular ya se
## nota.
const USO_TEMPORADA_PLENA := 19.0


## Techo de un atributo concreto. Cae al potencial global si el jugador
## viene de un guardado anterior a §7.2 y Team no alcanzó a migrarlo.
static func techo_de(jugador: Dictionary, atributo: String) -> int:
	var techos: Dictionary = jugador.get("potenciales", {})
	return int(techos.get(atributo, jugador["potencial"]))


## Cuánto acelera este atributo por haberlo usado en la cancha.
static func multiplicador_uso(jugador: Dictionary, atributo: String) -> float:
	var uso: Dictionary = jugador.get("xp_uso", {})
	if uso.is_empty():
		return 1.0
	var maximo := 0.0
	var total := 0.0
	for a in uso:
		maximo = maxf(maximo, float(uso[a]))
		total += float(uso[a])
	if maximo <= 0.0:
		return 1.0
	# `total` viene en partidos-equivalentes (cada partido reparte
	# minutos/90 entre los atributos), así que mide cuánto jugó.
	var carga: float = clampf(total / USO_TEMPORADA_PLENA, 0.0, 1.0)
	var relativo: float = clampf(float(uso.get(atributo, 0.0)) / maximo, 0.0, 1.0)
	return 1.0 + MULTIPLICADOR_USO * relativo * carga


## §7.1 minutos: de PISO_SIN_JUGAR (no jugó) a 1 (PARTIDOS_PLENOS o más).
static func factor_minutos(jugador: Dictionary, en_cantera: bool = false) -> float:
	var partidos := PARTIDOS_CANTERA if en_cantera \
		else float(jugador.get("rendimiento", {}).get("partidos", 0.0))
	return PISO_SIN_JUGAR + (1.0 - PISO_SIN_JUGAR) * clampf(partidos / PARTIDOS_PLENOS, 0.0, 1.0)


## §7.1 rendimiento: cuántos desvíos rindió por encima de lo esperable para
## su puesto. Positivo = mejor que el promedio. Sin partidos da 0.
static func desvios_rendimiento(jugador: Dictionary) -> float:
	var rend: Dictionary = jugador.get("rendimiento", {})
	var partidos := float(rend.get("partidos", 0.0))
	if partidos <= 0.0:
		return 0.0
	var puesto := str(jugador.get("posicion", ""))
	var pesos: Array = PESOS_RENDIMIENTO.get(puesto, [0.0, 0.5, 0.5])
	var z := 0.0
	var ref_of: Array = REFERENCIA_PUESTO["ofensivo"].get(puesto, [])
	if pesos[0] > 0.0 and not ref_of.is_empty():
		var ofensivo := (float(rend.get("goles", 0.0)) + 0.6 * float(rend.get("asistencias", 0.0))) / partidos
		z += pesos[0] * (ofensivo - ref_of[0]) / ref_of[1]
	var ref_ec: Array = REFERENCIA_PUESTO["en_contra"]
	# Menos goles recibidos es mejor: el signo va dado vuelta.
	z += pesos[1] * (ref_ec[0] - float(rend.get("en_contra", 0.0)) / partidos) / ref_ec[1]
	var ref_dif: Array = REFERENCIA_PUESTO["diferencia"]
	var diferencia := (float(rend.get("a_favor", 0.0)) - float(rend.get("en_contra", 0.0))) / partidos
	z += pesos[2] * (diferencia - ref_dif[0]) / ref_dif[1]
	# Una muestra chica se acerca a 0: cuatro partidos buenos no alcanzan.
	return z * partidos / (partidos + PARTIDOS_CONFIANZA)


static func factor_rendimiento(jugador: Dictionary) -> float:
	return clampf(1.0 + RENDIMIENTO_POR_DESVIO * desvios_rendimiento(jugador),
		RENDIMIENTO_MINIMO, RENDIMIENTO_MAXIMO)


## Envejece un año al jugador y mueve sus atributos. Modifica el dict in
## place. mult_mentor (§6 extendido, Mentores.multiplicador_para): bonus de
## crecimiento si hay un veterano líder en su plantel y este jugador es
## joven — 1.0 si no aplica ninguna de las dos cosas. mult_entrenamiento
## (§9.5, Instalaciones.factor_entrenamiento): bonus de instalaciones y
## carga, sobre TODO el crecimiento. `mult_area` es el multiplicador por
## atributo que deja el foco de equipo (§7.4.2, ver
## FocoEquipo.multiplicadores). Vacio = sin enfasis.
##
## El foco individual (×2 sobre un atributo elegido) se sacó el
## 2026-09-14. Medido con semilla fija: un DC de 17 con foco en
## tiro, uso y foco de equipo técnico cerraba el 100% de la distancia a su
## techo en UNA temporada, porque todos los bonus se multiplican.
##
## `en_cantera`: el juvenil no juega la liga, así que sus minutos cuentan
## como PARTIDOS_CANTERA y su rendimiento como neutro.
static func aplicar_temporada(jugador: Dictionary, rng: RandomNumberGenerator, mult_mentor: float = 1.0,
		mult_entrenamiento: float = 1.0, mult_area: Dictionary = {}, en_cantera: bool = false) -> void:
	jugador["edad"] += 1
	var mult_edad := _multiplicador_crecimiento(jugador["edad"])
	var mult_tier: float = VELOCIDAD_POR_TIER.get(jugador["genetica_tier"], 1.0)
	var mult_personalidad: float = Personalidad.factor_entrenamiento(jugador)
	var mult_juego: float = factor_minutos(jugador, en_cantera) \
		* (1.0 if en_cantera else factor_rendimiento(jugador))

	# §6 Comodón: "si es titular fijo 15 partidos, deja de crecer" — se
	# congela del todo el crecimiento de esta temporada (ni siquiera el
	# ruido aleatorio), no solo se lo reduce. El declive de veteranos NO
	# se ve afectado (esta bandera solo pesa en la rama de crecimiento).
	var congelado_por_comodon: bool = Personalidad.tiene(jugador, "Comodon") and \
		int(jugador.get("partidos_seguidos_titular", 0)) >= Personalidad.UMBRAL_COMODON

	for attr in jugador["atributos"].keys():
		var valor_actual: float = jugador["atributos"][attr]
		var cambio := 0.0

		if mult_edad >= 0.0:
			if not congelado_por_comodon:
				# §7.2: el techo es el de ESTE atributo, no el global. Un
				# jugador de potencial 80 puede tener tope 92 en tiro y 68
				# en pases, y crece hacia cada uno por separado.
				var distancia: float = float(techo_de(jugador, attr)) - valor_actual
				if distancia > 0.0:
					var mult_uso: float = multiplicador_uso(jugador, attr)
					var mult_equipo: float = float(mult_area.get(attr, 1.0))
					var cercania: float = pow(distancia / DISTANCIA_REFERENCIA, EXPONENTE_CERCANIA)
					cambio = distancia * cercania * TASA_CRECIMIENTO * mult_edad * mult_tier * mult_juego \
						* mult_personalidad * mult_mentor * mult_entrenamiento * mult_uso * mult_equipo
				cambio += rng.randfn(0.0, 0.6)
				# El techo es techo: el ruido aleatorio no puede empujar
				# por encima. Antes se sumaba igual estando ya en el tope,
				# y como era un paseo al azar sin nada que lo trajera de
				# vuelta, en doce temporadas un atributo se despegaba hasta
				# 10 puntos de su propio techo.
				var techo_attr: float = float(techo_de(jugador, attr))
				if valor_actual + cambio > techo_attr:
					cambio = maxf(techo_attr - valor_actual, 0.0)
		else:
			var grupo := _grupo_de_atributo(attr)
			var factor_declive: float = DECLIVE_POR_GRUPO.get(grupo, 0.5)
			cambio = -factor_declive * (1.0 + rng.randf() * 0.5)
			cambio += rng.randfn(0.0, 0.6)

		jugador["atributos"][attr] = clamp(round(valor_actual + cambio), 0, 100)

	# El uso se consume al cerrar la temporada: lo que jugó este año no
	# puede seguir acelerándolo el año que viene.
	jugador["xp_uso"] = {}
	jugador["rendimiento"] = {}
	jugador["media"] = PlayerGenerator.compute_media(jugador["atributos"], jugador["posicion"])
	var mejor := PlayerGenerator.best_position(jugador["atributos"])
	jugador["mejor_posicion"] = mejor["posicion"]
	jugador["media_mejor_posicion"] = mejor["media"]
