class_name Team
extends RefCounted

## Equipo para el motor de partido — Fase 2. Todavía no es el club de la
## partida (eso llega con la economía/plantel en fases posteriores): acá es
## solo la plantilla titular necesaria para simular duelos.

const FORMACION := ["ARQ", "DFC", "DFC", "LAT", "LAT", "MC", "MC", "MCO", "EXT", "EXT", "DC"]

var nombre: String
var jugadores: Array = []  # 11 dicts (PlayerGenerator.generate), uno por puesto de FORMACION
var local: bool = false
var armonia: float = 0.0  # placeholder hasta que exista §3 (vestuario real)
var racha: int = 0
var avance: int = 0  # pases consecutivos exitosos en la zona de armado, ver MatchEngine
var goles: int = 0
var capitan_id: int = -1
var resistencia: Dictionary = {}  # jugador_id -> % de resistencia en el partido actual (0..1)


static func generar(nombre: String, rng: RandomNumberGenerator) -> Team:
	var t := Team.new()
	t.nombre = nombre
	var next_id := 0
	var mejor_media := -1.0
	for pos in FORMACION:
		var jugador := PlayerGenerator.generate(next_id, rng, pos)
		next_id += 1
		t.jugadores.append(jugador)
		if jugador["media"] > mejor_media:
			mejor_media = jugador["media"]
			t.capitan_id = jugador["id"]
	t.armonia = rng.randf_range(-3.0, 5.0)
	return t


func reset_partido() -> void:
	racha = 0
	avance = 0
	goles = 0
	resistencia.clear()
	for j in jugadores:
		resistencia[j["id"]] = 1.0


func jugadores_por_posiciones(posiciones: Array) -> Array:
	var out := []
	for j in jugadores:
		if posiciones.has(j["posicion"]):
			out.append(j)
	return out


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


## Desgaste simple por participación en un duelo. La resistencia nunca baja de
## 0.55 en esta fase: el sistema de fatiga/lesiones completo es §7 y §2.3,
## todavía no construido.
func desgastar(jugador_id: int, energia_attr: int) -> void:
	var decay: float = 0.006 * (1.3 - float(energia_attr) / 100.0)
	resistencia[jugador_id] = max(0.55, resistencia_pct(jugador_id) - decay)
