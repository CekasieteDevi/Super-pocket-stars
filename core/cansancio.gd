class_name Cansancio
extends RefCounted

## Energía, franjas de rendimiento, desgaste, recuperación y rotación.
##
## Todas las perillas de balance del cansancio viven acá. El estado no
## vive acá: la energía dentro del partido es `Team.resistencia` y la que
## se arrastra entre partidos es `Team.fatiga_acumulada` (las dos de 0 a 1).
## Este archivo solo dice cuánto baja, cuánto vuelve y qué cuesta.
##
## Antes el cansancio casi no existía. `Duel.factor_energia` restaba un
## poco en forma continua y `Team.desgastar` multiplicaba por
## (1,3 − energía/100): un jugador de energía 86 se cansaba la mitad que
## uno de 37. Medido el 2026-09-23 (30 partidos por división, SEED 4400):
## la resistencia final media era 84% en división 10 y 94% en división 1,
## y en división 1 nadie terminaba debajo de 85%. Sin cansancio no había
## cambios (0,03 por partido en división 1) ni motivo para rotar.


# --- Franjas -----------------------------------------------------------

## Una franja es un tramo de energía con el mismo castigo a los atributos.
## El límite va en porcentaje entero para que "75%" caiga en la franja
## de −10%, como lo dice la regla: 100–76, 75–51, 50–26 y 25–0.
const FRANJA_PISO_PCT := [76, 51, 26, 0]
## Cuánto rinden los atributos en cada franja.
## La cuarta franja (25% o menos) castiga −35% y no −30%: ahí el jugador
## ya no rinde ni para defenderse, y el salto grande hace que dejarlo en
## cancha sea una decisión mala a propósito. La acompaña más riesgo de
## lesión (RIESGO_LESION_POR_FRANJA).
const FACTOR_FRANJA := [1.0, 0.90, 0.80, 0.65]
const NOMBRE_FRANJA := ["fresco", "cansado", "muy cansado", "agotado"]
## Multiplica el riesgo de lesión de Lesiones.evaluar_riesgo, que ya sube
## en forma continua con el cansancio. Solo el agotado paga un extra: un
## músculo sin reserva es el que se rompe.
const RIESGO_LESION_POR_FRANJA := [1.0, 1.0, 1.0, 1.5]


static func porcentaje(energia: float) -> int:
	return roundi(clampf(energia, 0.0, 1.0) * 100.0)


## 0 = fresco, 1 = cansado, 2 = muy cansado, 3 = agotado.
static func franja(energia: float) -> int:
	var pct := porcentaje(energia)
	for i in range(FRANJA_PISO_PCT.size()):
		if pct >= int(FRANJA_PISO_PCT[i]):
			return i
	return FRANJA_PISO_PCT.size() - 1


## Lo que rinde un atributo con esta energía. Es el único castigo por
## cansancio: lo usan los dos motores a través de Duel.atributo_efectivo,
## así que la franja se recalcula en cada duelo, con la energía de ese
## momento. Antes del partido rige igual, porque el partido arranca con
## la energía que el jugador trae de la semana (Team.reset_partido).
static func factor_stats(energia: float) -> float:
	return float(FACTOR_FRANJA[franja(energia)])


static func riesgo_lesion(energia: float) -> float:
	return float(RIESGO_LESION_POR_FRANJA[franja(energia)])


# --- Desgaste dentro del partido ---------------------------------------

## Nadie baja de acá dentro de un partido. Antes el piso era 55%, y con
## ese piso la franja de −20% no podía existir.
const ENERGIA_MINIMA := 0.10

## Lo que pierde por minuto un jugador de campo de energía 50, en fracción
## de energía. Es la base del desgaste: minutos jugados. Encima se suma
## la intensidad que ya cobra cada motor (duelos, y en el espacial
## también las corridas). Calibrado para que un titular que arranca al
## 100% termine el partido cerca de 65%: cruza a la franja de −10% entre
## el 60' y el 75', que es cuando en el fútbol entran los cambios.
const DESGASTE_POR_MINUTO := 0.0035

## Esfuerzo relativo de cada puesto. Sale de las distancias típicas que
## recorre cada puesto en un partido (volantes y laterales ~11–12 km,
## centrales ~10 km, arquero ~5 km), relativas a 11 km.
const DESGASTE_POR_PUESTO := {
	"ARQ": 0.35, "DFC": 0.85, "LAT": 1.05, "MC": 1.10,
	"MCO": 1.00, "EXT": 1.10, "DC": 0.95,
}

## Cuánto cambia el desgaste con el atributo `energia`. Con 0,6 un
## jugador de energía 86 se cansa 27% menos que uno de 37. Antes era 53%
## menos, y la división 1 prácticamente no se cansaba.
const PESO_ATRIBUTO_ENERGIA := 0.6


## Multiplicador del desgaste según el atributo `energia` (0–100). Vale 1
## con energía 50.
static func factor_atributo_energia(energia_attr: float) -> float:
	return 1.0 + PESO_ATRIBUTO_ENERGIA * (0.5 - energia_attr / 100.0)


static func desgaste_por_minuto(posicion: String) -> float:
	return DESGASTE_POR_MINUTO * float(DESGASTE_POR_PUESTO.get(posicion, 1.0))


# --- Recuperación entre partidos ---------------------------------------

## Lo que recupera por día de descanso un jugador de 24 a 29 años con
## energía 50. Con 0,055, una semana devuelve casi todo lo que cuesta un
## partido y media semana deja al plantel lejos del 100%: jugar dos
## veces por semana acumula cansancio (§3/§7.4.7).
const RECUPERACION_POR_DIA := 0.055

## Por edad: el joven se recupera antes y el veterano tarda más.
## [edad hasta, factor]; el último tramo cubre al resto.
const RECUPERACION_POR_EDAD := [[23, 1.10], [29, 1.00], [32, 0.90], [99, 0.80]]

## Cuánto pesa el físico (atributo `energia`) en la recuperación. Con 0,3
## un jugador de energía 90 recupera 24% más rápido que uno de 10.
const PESO_FISICO_RECUPERACION := 0.3


static func factor_recuperacion(jugador: Dictionary) -> float:
	var edad := int(jugador.get("edad", 26))
	var por_edad := 1.0
	for tramo in RECUPERACION_POR_EDAD:
		if edad <= int(tramo[0]):
			por_edad = float(tramo[1])
			break
	var energia_attr: float = float(jugador.get("atributos", {}).get("energia", 50.0))
	var por_fisico: float = 1.0 + PESO_FISICO_RECUPERACION * (energia_attr / 100.0 - 0.5)
	return por_edad * por_fisico


# --- Prioridad de partidos ---------------------------------------------

const ALTA := 0
const BAJA := 1
const NOMBRE_PRIORIDAD := ["alta", "baja"]

## Torneos de prioridad baja, por el comienzo de su nombre. Los demás
## (liga, copas internacionales, playoff) son de prioridad alta. Va por
## nombre porque así se derivan igual en una partida guardada de antes.
const TORNEOS_BAJA := ["Copa Division", "Copa del Rey", "Copa Nacional"]


static func prioridad_de_torneo(nombre: String) -> int:
	for prefijo in TORNEOS_BAJA:
		if nombre.begins_with(str(prefijo)):
			return BAJA
	return ALTA


# --- Rotación antes del partido ----------------------------------------

## Un rival es "muy inferior" si su media de equipo está esta cantidad de
## puntos o más por debajo. Cada división de la pirámide separa entre 5
## y 6 puntos de media (NivelDivision.media_de), así que es un rival de
## unas dos categorías más abajo.
const DIFERENCIA_RIVAL_INFERIOR := 10.0

## En un partido de prioridad baja, un titular fresco descansa si hay un
## reemplazo del puesto que rinde hasta esta cantidad de puntos menos.
## Contra un rival muy inferior descansa con cualquier reemplazo.
const MARGEN_ROTACION_BAJA := 8.0


## Rotar o no a un titular antes del partido.
##
## Prioridad alta: juega salvo que esté en 50% o menos. Contra un rival
## muy inferior también descansa el que está en la franja de −10%.
## Prioridad baja: descansa todo el que no está fresco; el fresco
## descansa si el reemplazo alcanza (ver MARGEN_ROTACION_BAJA).
## Devuelve el motivo, o "" si juega.
static func motivo_rotacion(energia: float, prioridad: int, rival_inferior: bool) -> String:
	var f := franja(energia)
	if prioridad == ALTA:
		if f >= 2:
			return "descansa: %d%% de energía" % porcentaje(energia)
		if f == 1 and rival_inferior:
			return "descansa: rival muy inferior"
		return ""
	if f >= 1:
		return "descansa: %d%% de energía" % porcentaje(energia)
	return "rota: copa menor"


# --- Cambios dentro del partido ----------------------------------------

## Energía a la que un club cambia a un jugador de campo en las ventanas
## de cambio, según su configuración. "equilibrado" cambia al que cae a la
## franja de −10%; "descanso" se anticipa; "rendimiento" aguanta hasta la
## franja de −20%.
const UMBRAL_CAMBIO := {"descanso": 0.80, "equilibrado": 0.75, "rendimiento": 0.50}


static func umbral_cambio(config: String) -> float:
	return float(UMBRAL_CAMBIO.get(config, UMBRAL_CAMBIO["equilibrado"]))
