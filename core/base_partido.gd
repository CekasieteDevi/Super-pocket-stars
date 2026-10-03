class_name BasePartido
extends RefCounted

## Lo que comparten los motores de partido: MotorV2 (tus partidos) y
## MatchEngine (el resto de la liga). Salió de MotorEspacial cuando se borró
## (docs/motor_v2.md, etapa 8): las medidas de la cancha, la duración del
## partido, los pesos de data/utility_pesos.json y lo que corre cada jugador
## según sus atributos. docs/motor_espacial.md explica de dónde sale cada
## número (las referencias § de los comentarios apuntan ahí).

const PESOS_PATH := "res://data/utility_pesos.json"

## Un partido dura 2 minutos de verdad por tiempo, jugados a velocidad real.
## El reloj marca 0-90 como ficción. No se puede mostrar 90 minutos en 4 sin
## acelerar 22 veces, y a 22x un jugador que corre a 7 m/s se ve corriendo a
## 157. Costo asumido: las llegadas son más seguidas que en un partido real.
const SEGUNDOS_POR_MITAD := 120.0
const MINUTOS_MOSTRADOS_POR_MITAD := 45.0
## Alargue (§8.7): dos tiempos de 15 minutos mostrados, a la misma escala.
const MINUTOS_MOSTRADOS_POR_TIEMPO_ALARGUE := 15.0
## Segundos de verdad que puede estirarse un tiempo para terminar la jugada
## pendiente. Es un seguro: el tiempo se cierra solo cuando la jugada termina.
## Eran 90 ticks de 0,25 s del motor espacial: el peor caso encadenado, un
## córner que termina en penal.
const CIERRE_MAX_SEG := 22.5

const RADIO_CIRCULO := 9.15
## Medio ancho del arco (7,32 m reglamentarios) y alto del travesaño.
const ARCO_MEDIO_ANCHO := 3.66
const ARCO_ALTO := 2.44
## El punto del penal: 11 m del arco.
const DIST_PENAL := 11.0
## Desde más lejos que esto nadie va a buscar la pelota para ejecutar un
## córner o un centro: no llega en lo que dura la pausa.
const DIST_MAX_AL_EJECUTOR := 22.0
## Los de arriba, para la pelota parada: los que suman amenaza en el área en
## un córner propio y los que no bajan a defender un tiro libre.
const ROLES_QUE_ATACAN := ["MCO", "EXT", "DC"]
## Cuánto le achica el margen de error de desmarque el rasgo Enfocado. No es
## cero: hasta el delantero más atento se va alguna vez.
const FACTOR_OFFSIDE_ENFOCADO := 0.2
## Cuánto del reparto de experiencia sale del puesto en vez de las acciones
## del partido (MotorV2._experiencia). Con solo las acciones, el equipo del
## usuario crecía un 6% más lento que el resto de la liga (5 temporadas).
const MEZCLA_PERFIL := 0.45

## Los eventos del partido identifican a cada jugador por CLAVE, no por id:
## los ids son únicos dentro de un club pero no entre clubes. La clave del
## visitante se corre por este offset.
const OFFSET_VISITANTE := 100000

static var _pesos_cache: Dictionary = {}


static func clave_de(jugador_id: int, es_local: bool) -> int:
	return jugador_id if es_local else jugador_id + OFFSET_VISITANTE


static func pesos() -> Dictionary:
	if _pesos_cache.is_empty():
		_pesos_cache = DataLoader.load_json(PESOS_PATH)
	return _pesos_cache


## Interpola entre dos valores según un atributo de 0 a 100, leído tal cual
## (sin relativizar al nivel del partido): la velocidad, la aceleración y el
## giro son físicos y tienen que escalar con la división. Es lo que hace que
## primera se vea rápida y décima lenta.
static func _por_atributo(jugador: Dictionary, atributo: String, en_0: float, en_100: float) -> float:
	var bruto: float = float(jugador["atributos"][atributo])
	return en_0 + clampf(bruto / 100.0, 0.0, 1.0) * (en_100 - en_0)


## Velocidad punta (m/s).
static func vel_max(jugador: Dictionary) -> float:
	var f: Dictionary = pesos()["fisica"]
	return _por_atributo(jugador, "velocidad", f["vel_min"], f["vel_max"])


## Cuántos m/s gana por segundo. Un jugador de aceleración 90 llega a punta en
## ~1,7 s y uno de 20 tarda casi el doble.
static func aceleracion(jugador: Dictionary) -> float:
	var f: Dictionary = pesos()["fisica"]
	return _por_atributo(jugador, "aceleracion", f["acel_min"], f["acel_max"])


## Radianes por segundo que gira este jugador (según `agilidad`).
static func giro_de(jugador: Dictionary) -> float:
	var w := pesos_control()
	return _por_atributo(jugador, "agilidad", w["giro_lento"], w["giro_rapido"])


## Los pesos de cada sección de data/utility_pesos.json con sus valores por
## defecto, ya leídos (se consultan en cada partido).
static var _pesos_control_cache: Dictionary = {}

static func pesos_control() -> Dictionary:
	if not _pesos_control_cache.is_empty():
		return _pesos_control_cache
	var d: Dictionary = pesos().get("control", {})
	_pesos_control_cache = {
		"giro_lento": float(d.get("giro_lento", 4.0)),
		"giro_rapido": float(d.get("giro_rapido", 9.0)),
		"rapidez_para_girar": float(d.get("rapidez_para_girar", 2.0)),
		"cono_sin_giro": float(d.get("cono_sin_giro", 2.0)),
		"peso_velocidad": float(d.get("peso_velocidad", 0.3)),
		"peso_altura": float(d.get("peso_altura", 0.2)),
		"peso_presion": float(d.get("peso_presion", 0.3)),
		"peso_angulo": float(d.get("peso_angulo", 0.2)),
		"demora_facil": float(d.get("demora_facil", 0.6)),
		"demora_dificil": float(d.get("demora_dificil", 1.6)),
		"malo_max": float(d.get("malo_max", 0.3)),
		"alivio_control": float(d.get("alivio_control", 0.8)),
		"mezcla_absoluta": float(d.get("mezcla_absoluta", 0.5)),
		"toque_largo_min": float(d.get("toque_largo_min", 2.0)),
		"toque_largo_max": float(d.get("toque_largo_max", 6.0)),
		"toque_desvio": float(d.get("toque_desvio", 0.9)),
		"fraccion_para_definir": float(d.get("fraccion_para_definir", 0.4)),
	}
	return _pesos_control_cache


static var _pesos_esfuerzo_cache: Dictionary = {}

static func pesos_esfuerzo() -> Dictionary:
	if not _pesos_esfuerzo_cache.is_empty():
		return _pesos_esfuerzo_cache
	var d: Dictionary = pesos().get("esfuerzo", {})
	_pesos_esfuerzo_cache = {
		"peso_aceleracion": float(d.get("peso_aceleracion", 0.5)),
		"umbral_sprint": float(d.get("umbral_sprint", 0.55)),
		"consumo_sprint": float(d.get("consumo_sprint", 0.10)),
		"recuperacion_reserva": float(d.get("recuperacion_reserva", 0.07)),
		"reserva_para_frenar": float(d.get("reserva_para_frenar", 0.5)),
		"piso_sprint": float(d.get("piso_sprint", 0.85)),
		"desgaste_por_segundo": float(d.get("desgaste_por_segundo", 0.0)),
		"recuperacion_entretiempo": float(d.get("recuperacion_entretiempo", 0.0)),
		"tope_entretiempo": float(d.get("tope_entretiempo", 0.0)),
	}
	return _pesos_esfuerzo_cache


static var _pesos_arquero_cache: Dictionary = {}

static func pesos_arquero() -> Dictionary:
	if not _pesos_arquero_cache.is_empty():
		return _pesos_arquero_cache
	var d: Dictionary = pesos().get("arquero", {})
	_pesos_arquero_cache = {
		"reaccion_lenta": float(d.get("reaccion_lenta", 0.6)),
		"reaccion_rapida": float(d.get("reaccion_rapida", 0.15)),
		"ventaja_base": float(d.get("ventaja_base", 0.25)),
		"ventaja_por_metro": float(d.get("ventaja_por_metro", 0.02)),
		"achique_min": float(d.get("achique_min", 2.5)),
		"achique_max": float(d.get("achique_max", 6.5)),
		"achique_dist_rival": float(d.get("achique_dist_rival", 24.0)),
		"achique_margen_pelota": float(d.get("achique_margen_pelota", 4.0)),
		"achique_carril": float(d.get("achique_carril", 2.5)),
		"volver_umbral": float(d.get("volver_umbral", 2.0)),
		"alcance_descuelgue": float(d.get("alcance_descuelgue", 1.0)),
		"cobertura_peso": float(d.get("cobertura_peso", 0.3)),
		"cobertura_referencia": float(d.get("cobertura_referencia", 0.648)),
		"rechazo_amenaza_corner": float(d.get("rechazo_amenaza_corner", 0.45)),
		"rechazo_amenaza_suelta": float(d.get("rechazo_amenaza_suelta", 0.5)),
		"rechazo_radio_amenaza": float(d.get("rechazo_radio_amenaza", 10.0)),
		"rechazo_centralidad": float(d.get("rechazo_centralidad", 1.0)),
		"rechazo_dispersion": float(d.get("rechazo_dispersion", 1.6)),
		"rechazo_dist_comoda": float(d.get("rechazo_dist_comoda", 25.0)),
	}
	return _pesos_arquero_cache
