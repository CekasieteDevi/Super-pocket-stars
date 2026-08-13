extends Node

## Autoload "GameState" — Fase 4: estado mínimo de partida para que la UI
## tenga algo real que mostrar. Fase 5: entre fecha y fecha se avanza el
## calendario (fatiga/ánimo/lesiones) y al terminar la temporada se
## envejece/entrena el plantel. Fase 7: ahora usa la pirámide real de 10
## divisiones (GDD original: el jugador arranca en la última) en vez de
## una sola liga suelta, con copas nacionales/de división y el sistema
## internacional corriendo al cierre de cada temporada. Fase 9: cantera y
## noticias.
##
## La generación de mundo horneada (Fix 10 del GDD, nombres/escudos
## reales) y el plantel de 25 con banco todavía no existen.

const DIAS_ENTRE_FECHAS := 7
const DIVISION_INICIAL := 9  # 0-indexado: división 10, la última (GDD original)
const MAX_NOTICIAS_GUARDADAS := 200

var rng: RandomNumberGenerator
var piramide: Piramide
var confederacion: Confederacion

var division_jugador: int = DIVISION_INICIAL
var equipo_jugador: Team
var fecha_actual: int = 0
var temporada_actual: int = 1

var ultimo_resultado: Dictionary = {}
var ultimo_log: Array = []
var ultimos_eventos: Array = []
var noticias: Array = []
var ultimo_informe_economico: Dictionary = {}  # ingresos/egresos/neto del ultimo cierre de temporada


func _ready() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = 99

	piramide = Piramide.generar(rng)
	confederacion = Confederacion.generar(piramide, rng)
	equipo_jugador = piramide.divisiones[DIVISION_INICIAL].equipos[0]


func liga_jugador() -> Liga:
	return piramide.divisiones[division_jugador]


func hay_fecha_pendiente() -> bool:
	return fecha_actual < liga_jugador().fixture.size()


## Juega la fecha en las 10 divisiones a la vez (mismo calendario, como en
## la realidad todas las divisiones juegan la misma fecha el mismo fin de
## semana) — si solo jugara la división del jugador, las otras 9 quedarían
## con la tabla en cero para siempre y los ascensos/descensos y copas de
## fin de temporada no tendrían con qué trabajar.
func jugar_siguiente_fecha() -> void:
	if not hay_fecha_pendiente():
		return

	for d in range(piramide.divisiones.size()):
		var liga: Liga = piramide.divisiones[d]
		if d == division_jugador:
			var r := liga.jugar_fecha(fecha_actual, rng, equipo_jugador)
			if r["resultado_seguido"] != null:
				ultimo_resultado = r["resultado_seguido"]
				ultimo_log = r["log_seguido"]
				ultimos_eventos = r["eventos_seguido"]
		else:
			liga.jugar_fecha(fecha_actual, rng)
		liga.avanzar_dias(DIAS_ENTRE_FECHAS)

	fecha_actual += 1

	if not hay_fecha_pendiente():
		_cerrar_temporada()


## Copas + internacional con la temporada recién jugada, después ascensos/
## descensos (que mueven equipos entre divisiones), y por último localiza
## en qué división quedó el equipo del jugador para la temporada nueva.
func _cerrar_temporada() -> void:
	var copa_nacional := Copas.jugar_copa_nacional(piramide, rng)
	var copas_division := Copas.jugar_copas_de_division(piramide, rng)
	var resultado_internacional := confederacion.jugar_temporada_internacional(rng)

	_agregar_noticia("COPA NACIONAL: campeón %s" % copa_nacional.campeon.nombre)
	for i in range(copas_division.size()):
		_agregar_noticia("COPA DIVISIÓN %d: campeón %s" % [i + 1, copas_division[i].campeon.nombre])
	for copa_nombre in ["campeones", "guerreros", "emergentes"]:
		var campeon: Team = resultado_internacional[copa_nombre]["campeon"]
		if campeon != null:
			_agregar_noticia("INTERNACIONAL (%s): campeón %s" % [copa_nombre.capitalize(), campeon.nombre])

	var resultado_piramide := piramide.fin_de_temporada(rng, equipo_jugador)
	for m in resultado_piramide["movimientos"]:
		if m["equipo"] == equipo_jugador.nombre:
			_agregar_noticia("%s: %s (división %d → división %d)" % [equipo_jugador.nombre, m["tipo"], m["de_division"], m["a_division"]])

	# El informe economico de CADA division se calculo antes de mover a
	# nadie, con la composicion vieja — division_jugador todavia apunta a
	# la division donde jugo esta temporada.
	var informes_economia_division: Array = resultado_piramide["informes_por_division"][division_jugador][0]
	for informe in informes_economia_division:
		if informe["equipo"] == equipo_jugador.nombre:
			ultimo_informe_economico = informe
			break

	for liga in piramide.divisiones:
		for n in liga.noticias:
			_agregar_noticia(n)
		liga.noticias.clear()

	for d in range(piramide.divisiones.size()):
		if piramide.divisiones[d].equipos.has(equipo_jugador):
			division_jugador = d
			break

	temporada_actual += 1
	fecha_actual = 0


func _agregar_noticia(texto: String) -> void:
	noticias.push_front(texto)
	if noticias.size() > MAX_NOTICIAS_GUARDADAS:
		noticias.resize(MAX_NOTICIAS_GUARDADAS)
