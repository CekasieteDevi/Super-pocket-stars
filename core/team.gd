class_name Team
extends RefCounted

## Equipo para el motor de partido — Fase 2, extendido en Fase 5 con estado
## que persiste entre partidos (fatiga acumulada, ánimo, lesiones). Todavía
## no es el club de la partida completo (eso llega con la economía/plantel
## de 25 en fases posteriores): acá es la plantilla titular fija de 11.

const FORMACION := ["ARQ", "DFC", "DFC", "LAT", "LAT", "MC", "MC", "MCO", "EXT", "EXT", "DC"]

## §3: cuánto recupera la fatiga acumulada por día de descanso entre fechas.
const RECUPERACION_FATIGA_POR_DIA := 0.1
## §3: velocidad de la deriva natural del ánimo hacia 50 (por semana).
const DERIVA_ANIMO_POR_SEMANA := 1.0

var nombre: String
var jugadores: Array = []  # 11 dicts (PlayerGenerator.generate), uno por puesto de FORMACION
var local: bool = false
var armonia: float = 0.0  # placeholder hasta que exista §3 completo (vestuario real)
var racha: int = 0
var avance: int = 0  # pases consecutivos exitosos en la zona de armado, ver MatchEngine
var goles: int = 0
var capitan_id: int = -1
var resistencia: Dictionary = {}  # jugador_id -> % de resistencia en el partido actual (0..1)

## Fase 5: estado que persiste entre partidos (a diferencia de resistencia,
## que es solo dentro de un partido y siempre arranca desde fatiga_acumulada).
var fatiga_acumulada: Dictionary = {}  # jugador_id -> 0..1, 1 = totalmente descansado
var animo: Dictionary = {}  # jugador_id -> 0..100 (§3)
var lesiones: Dictionary = {}  # jugador_id -> {"tipo":String, "dias_restantes":int}


static func generar(nombre: String, rng: RandomNumberGenerator) -> Team:
	var t := Team.new()
	t.nombre = nombre
	var next_id := 0
	for pos in FORMACION:
		var jugador := PlayerGenerator.generate(next_id, rng, pos)
		next_id += 1
		t.jugadores.append(jugador)
		t.fatiga_acumulada[jugador["id"]] = 1.0
		t.animo[jugador["id"]] = 50.0
	t.armonia = rng.randf_range(-3.0, 5.0)
	t.recalcular_capitan()
	return t


func recalcular_capitan() -> void:
	var mejor_media := -1.0
	for j in jugadores:
		if j["media"] > mejor_media:
			mejor_media = j["media"]
			capitan_id = j["id"]


func reset_partido() -> void:
	racha = 0
	avance = 0
	goles = 0
	resistencia.clear()
	for j in jugadores:
		resistencia[j["id"]] = fatiga_acumulada.get(j["id"], 1.0)


func jugadores_por_posiciones(posiciones: Array) -> Array:
	var out := []
	for j in jugadores:
		if posiciones.has(j["posicion"]):
			out.append(j)
	return out


## Como jugadores_por_posiciones pero descarta lesionados. Si no queda nadie
## sano en esas posiciones, cae a cualquier sano; si NADIE está sano (sin
## plantel de 25 puede pasar), devuelve la lista completa como último
## recurso — hueco conocido hasta que exista el plantel de 25 (§14).
func jugadores_disponibles_por_posiciones(posiciones: Array) -> Array:
	var en_posicion := []
	var sanos := []
	for j in jugadores:
		if esta_lesionado(j["id"]):
			continue
		sanos.append(j)
		if posiciones.has(j["posicion"]):
			en_posicion.append(j)
	if not en_posicion.is_empty():
		return en_posicion
	if not sanos.is_empty():
		return sanos
	return jugadores


func arquero() -> Dictionary:
	for j in jugadores:
		if j["posicion"] == "ARQ":
			return j
	return jugadores[0]


func media_equipo() -> float:
	var total := 0.0
	for j in jugadores:
		total += j["media"]
	return total / jugadores.size()


func resistencia_pct(jugador_id: int) -> float:
	return resistencia.get(jugador_id, 1.0)


## Desgaste simple por participación en un duelo. La resistencia nunca baja
## de 0.55 dentro de un partido.
func desgastar(jugador_id: int, energia_attr: int) -> void:
	var decay: float = 0.006 * (1.3 - float(energia_attr) / 100.0)
	resistencia[jugador_id] = max(0.55, resistencia_pct(jugador_id) - decay)


func esta_lesionado(jugador_id: int) -> bool:
	return lesiones.has(jugador_id)


func lesionar(jugador_id: int, tipo: String, dias: int) -> void:
	lesiones[jugador_id] = {"tipo": tipo, "dias_restantes": dias}


## Se llama al terminar cada partido: la resistencia con la que se terminó
## pasa a ser el nuevo piso de fatiga acumulada (§3, "energía" de mediano
## plazo), y el ánimo se mueve según el resultado (±3, tope real ±6 con el
## bonus de gol) siguiendo el GDD §3 simplificado — todavía no hay xG ni
## stats de pases/duelos por jugador para el criterio completo por puesto.
func actualizar_post_partido(goles_propios: int, goles_rival: int, goleadores_ids: Array) -> void:
	for j in jugadores:
		var id: int = j["id"]
		fatiga_acumulada[id] = resistencia_pct(id)

		var delta := 0.0
		if goles_propios > goles_rival:
			delta = 3.0
		elif goles_propios < goles_rival:
			delta = -3.0
		if goleadores_ids.has(id):
			delta += 2.0
		delta = clamp(delta, -6.0, 6.0)
		animo[id] = clamp(animo.get(id, 50.0) + delta, 0.0, 100.0)


## Avanza el calendario entre fechas: recupera fatiga, hace derivar el ánimo
## hacia 50 y cuenta los días de lesión. Devuelve los ids que se recuperaron.
func avanzar_dias(dias: int) -> Array:
	for j in jugadores:
		var id: int = j["id"]
		fatiga_acumulada[id] = min(1.0, fatiga_acumulada.get(id, 1.0) + RECUPERACION_FATIGA_POR_DIA * dias)
		var actual: float = animo.get(id, 50.0)
		var deriva: float = clamp(50.0 - actual, -DERIVA_ANIMO_POR_SEMANA, DERIVA_ANIMO_POR_SEMANA) * (dias / 7.0)
		animo[id] = clamp(actual + deriva, 0.0, 100.0)

	var recuperados := []
	for id in lesiones.keys():
		lesiones[id]["dias_restantes"] -= dias
		if lesiones[id]["dias_restantes"] <= 0:
			recuperados.append(id)
	for id in recuperados:
		lesiones.erase(id)
	return recuperados
