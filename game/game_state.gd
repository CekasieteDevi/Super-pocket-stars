extends Node

## Autoload "GameState" — Fase 4: estado mínimo de partida para que la UI
## tenga algo real que mostrar (liga generada, equipo del jugador, calendario).
## Fase 5: entre fecha y fecha se avanza el calendario (fatiga/ánimo/lesiones)
## y al terminar la temporada se envejece/entrena el plantel y arranca otra.
## La generación de mundo horneada (Fix 10 del GDD) y el plantel de 25 con
## economía llegan en fases posteriores; por ahora "el equipo del jugador"
## es simplemente el primero de una liga de 20 generada al azar.

const N_EQUIPOS := 20
const DIAS_ENTRE_FECHAS := 7

var rng: RandomNumberGenerator
var liga: Liga
var equipo_jugador: Team
var fecha_actual: int = 0
var temporada_actual: int = 1

var ultimo_resultado: Dictionary = {}
var ultimo_log: Array = []


func _ready() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = 99

	var nombres := []
	for i in range(N_EQUIPOS):
		nombres.append("Club %02d" % (i + 1))

	liga = Liga.new()
	liga.inicializar(nombres, rng)
	equipo_jugador = liga.equipos[0]


func hay_fecha_pendiente() -> bool:
	return fecha_actual < liga.fixture.size()


func jugar_siguiente_fecha() -> void:
	if not hay_fecha_pendiente():
		return

	var r := liga.jugar_fecha(fecha_actual, rng, equipo_jugador)
	if r["resultado_seguido"] != null:
		ultimo_resultado = r["resultado_seguido"]
		ultimo_log = r["log_seguido"]
	fecha_actual += 1

	liga.avanzar_dias(DIAS_ENTRE_FECHAS)

	if not hay_fecha_pendiente():
		liga.nueva_temporada(rng)
		temporada_actual += 1
		fecha_actual = 0
