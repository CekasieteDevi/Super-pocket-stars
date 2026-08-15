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
var seleccion: Seleccion

## Rivales de amistoso de la selección: mismo criterio de fuerza que
## Confederacion (lerp 75->45 según el orden), sin necesitar clubes del
## exterior de por medio — un amistoso de selecciones, no de clubes.
const PAISES_RIVALES_SELECCION := ["Brasil", "España", "Argentina", "Alemania", "Francia", "Portugal", "México", "Colombia"]

var division_jugador: int = DIVISION_INICIAL
var equipo_jugador: Team
var fecha_actual: int = 0
var temporada_actual: int = 1

var ultimo_resultado: Dictionary = {}
var ultimo_log: Array = []
var ultimos_eventos: Array = []
var noticias: Array = []
var ultimo_informe_economico: Dictionary = {}  # ingresos/egresos/neto del ultimo cierre de temporada
var ultima_posicion_final: Dictionary = {}  # {"posicion","total","division"} del cierre de temporada mas reciente

## §10.5/§15: fin de partida real. Una vez true, jugar_siguiente_fecha() no
## avanza mas — la unica salida es borrar la partida y empezar una nueva.
var juego_terminado: bool = false
var motivo_fin_partida: String = ""


## Si hay una partida guardada, arranca retomándola — si no, "guardar la
## partida" no serviría de nada en la práctica (¿quién va a acordarse de
## tocar "Cargar partida" cada vez que abre el juego?). El botón "Cargar
## partida" sigue estando para descartar progreso reciente sin guardar y
## volver al último guardado sin reiniciar la app entera.
func _ready() -> void:
	if hay_partida_guardada() and cargar_partida():
		return

	rng = RandomNumberGenerator.new()
	rng.seed = 99

	piramide = Piramide.generar(rng)
	confederacion = Confederacion.generar(piramide, rng)
	seleccion = Seleccion.new()
	equipo_jugador = piramide.divisiones[DIVISION_INICIAL].equipos[0]
	equipo_jugador.objetivo_temporada = Objetivos.generar(
		equipo_jugador, _es_ultima_division(DIVISION_INICIAL), liga_jugador().equipos.size(), rng)


func liga_jugador() -> Liga:
	return piramide.divisiones[division_jugador]


func _es_ultima_division(division_idx: int) -> bool:
	return division_idx == piramide.divisiones.size() - 1


func hay_fecha_pendiente() -> bool:
	return fecha_actual < liga_jugador().fixture.size()


## Juega la fecha en las 10 divisiones a la vez (mismo calendario, como en
## la realidad todas las divisiones juegan la misma fecha el mismo fin de
## semana) — si solo jugara la división del jugador, las otras 9 quedarían
## con la tabla en cero para siempre y los ascensos/descensos y copas de
## fin de temporada no tendrían con qué trabajar.
func jugar_siguiente_fecha() -> void:
	if juego_terminado or not hay_fecha_pendiente():
		return

	# §8.4 #30: se recalcula antes de jugar la fecha (no al cierre) para
	# que el modificador de tensión pese en el partido de HOY si estás
	# sobre la hora y todavía no cumplís.
	var liga_del_jugador := liga_jugador()
	var posicion_actual: int = liga_del_jugador.tabla_ordenada().find(equipo_jugador.nombre) + 1
	equipo_jugador.objetivo_en_riesgo = Objetivos.esta_en_riesgo(
		equipo_jugador.objetivo_temporada, posicion_actual, fecha_actual, liga_del_jugador.fixture.size())

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
	# Posicion final ANTES de que nada mueva la tabla (fin_de_temporada mas
	# abajo la resetea para la temporada nueva) — asi el jugador se entera
	# en que puesto termino, no solo que "se acabo la temporada".
	var tabla_final := liga_jugador().tabla_ordenada()
	var posicion_final := tabla_final.find(equipo_jugador.nombre) + 1
	ultima_posicion_final = {"posicion": posicion_final, "total": tabla_final.size(), "division": division_jugador + 1}
	_agregar_noticia("%s termino la temporada %d° de %d en la Division %d." % [
		equipo_jugador.nombre, posicion_final, tabla_final.size(), division_jugador + 1
	])

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

	# division_jugador todavia apunta a la division donde jugo esta
	# temporada — fin_de_temporada() es lo que procesa cantera (necesario
	# para el objetivo de categoria "cantera" mas abajo) ademas de
	# economia/mercado/progresion y ascensos/descensos.
	var resultado_piramide := piramide.fin_de_temporada(rng, equipo_jugador, temporada_actual)
	for m in resultado_piramide["movimientos"]:
		if m["equipo"] == equipo_jugador.nombre:
			_agregar_noticia("%s: %s (división %d → división %d)" % [equipo_jugador.nombre, m["tipo"], m["de_division"], m["a_division"]])

	# El informe economico y el reporte de cantera de CADA division se
	# calcularon antes de mover a nadie, con la composicion vieja.
	var informes_economia_division: Array = resultado_piramide["informes_por_division"][division_jugador][0]
	for informe in informes_economia_division:
		if informe["equipo"] == equipo_jugador.nombre:
			ultimo_informe_economico = informe
			break

	# Team.promociones_temporada (ver core/team.gd) cuenta tanto las
	# promociones manuales del jugador humano como las automáticas de la
	# IA (el incremento vive dentro de Team.promover_juvenil/
	# promover_a_titular) — a diferencia del reporte de _procesar_cantera,
	# que para el equipo del jugador siempre viene vacío (es_protegido
	# salta el auto-promotor, la decisión es suya desde la UI).
	var promociones_cantera: int = equipo_jugador.promociones_temporada
	equipo_jugador.promociones_temporada = 0

	# §10.5/§15: evalua el objetivo que la directiva pidio para la
	# temporada que recien termino (se asigno la vez anterior que paso por
	# aca, o al arrancar la partida) ANTES de sortear el de la temporada
	# que viene. El contexto trae los tres datos posibles (posicion, copa,
	# cantera) — evaluar() solo usa el que corresponde a la categoria real
	# del objetivo.
	var contexto_objetivo := {
		"posicion_final": posicion_final,
		"rondas_copa": copa_nacional.rondas_ganadas(equipo_jugador),
		"promociones_cantera": promociones_cantera,
	}
	var objetivo_cumplido := Objetivos.evaluar(equipo_jugador.objetivo_temporada, contexto_objetivo)
	if objetivo_cumplido:
		equipo_jugador.objetivos_incumplidos_seguidos = 0
		if not equipo_jugador.objetivo_temporada.is_empty():
			_agregar_noticia("DIRECTIVA: cumpliste el objetivo de la temporada (%s)." % equipo_jugador.objetivo_temporada["descripcion"])
	else:
		equipo_jugador.objetivos_incumplidos_seguidos += 1
		_agregar_noticia("DIRECTIVA: NO cumpliste el objetivo (%s). Van %d temporada(s) seguida(s) sin cumplir." % [
			equipo_jugador.objetivo_temporada.get("descripcion", ""), equipo_jugador.objetivos_incumplidos_seguidos
		])
		if equipo_jugador.objetivos_incumplidos_seguidos >= Objetivos.MAX_INCUMPLIDOS_SEGUIDOS:
			juego_terminado = true
			motivo_fin_partida = "La directiva te destituyó: %d temporadas seguidas sin cumplir el objetivo." % equipo_jugador.objetivos_incumplidos_seguidos
			_agregar_noticia("DIRECTIVA: te destituyen. Fin de la partida.")

	for liga in piramide.divisiones:
		for n in liga.noticias:
			_agregar_noticia(n)
		liga.noticias.clear()

	# Al final de todo: con 200 clubes generando noticias de rutina (fichajes
	# libres, cantera, etc.) cada cierre, cualquier cosa agregada antes queda
	# enterrada bajo el límite de MAX_NOTICIAS_GUARDADAS — el amistoso de la
	# selección se agrega último para que sobreviva cerca del principio del
	# feed (push_front) en vez de perderse en el ruido.
	_jugar_amistoso_seleccion()

	for d in range(piramide.divisiones.size()):
		if piramide.divisiones[d].equipos.has(equipo_jugador):
			division_jugador = d
			break

	temporada_actual += 1
	fecha_actual = 0

	if not juego_terminado:
		equipo_jugador.objetivo_temporada = Objetivos.generar(
			equipo_jugador, _es_ultima_division(division_jugador), liga_jugador().equipos.size(), rng)


## Amistoso de la selección (una vez por cierre de temporada): convoca a
## los mejores de toda la pirámide, arma un rival de fuerza pareja a un
## país al azar, y juega. Si alguien se lesiona jugando para la selección,
## la lesión se le devuelve a SU CLUB REAL (Team.lesionar) — irse a la
## selección tiene un riesgo real, no es un paréntesis gratis. Si algún
## convocado es del equipo del jugador humano, queda una noticia aparte
## (es LA noticia que a un jugador de este juego le importa ver).
func _jugar_amistoso_seleccion() -> void:
	var convocatoria := seleccion.convocar(piramide)
	var uruguay: Team = convocatoria["equipo"]
	var clubes_por_jugador: Dictionary = convocatoria["clubes_por_jugador"]

	var pais_rival: String = PAISES_RIVALES_SELECCION[rng.randi() % PAISES_RIVALES_SELECCION.size()]
	var fuerza_rival: float = rng.randf_range(55.0, 85.0)
	var rival := Seleccion.generar_rival(pais_rival, fuerza_rival, rng)

	var local_es_uruguay := rng.randf() < 0.5
	var home := uruguay if local_es_uruguay else rival
	var away := rival if local_es_uruguay else uruguay
	var r := MatchEngine.simular(home, away, rng, false)

	var goles_uruguay: int = r["goles_local"] if local_es_uruguay else r["goles_visitante"]
	var goles_rival: int = r["goles_visitante"] if local_es_uruguay else r["goles_local"]
	_agregar_noticia("SELECCIÓN: Uruguay %d-%d %s (amistoso)" % [goles_uruguay, goles_rival, pais_rival])

	for j in uruguay.todos_los_jugadores():
		var id: int = j["id"]
		if not uruguay.esta_lesionado(id):
			continue
		var club_real: Team = clubes_por_jugador.get(id)
		if club_real == null:
			continue
		var info: Dictionary = uruguay.lesiones[id]
		club_real.lesionar(id, info["tipo"], info["dias_restantes"])
		_agregar_noticia("SELECCIÓN: %s de %s se lesiona jugando el amistoso (%s, %d días)." % [
			j["posicion"], club_real.nombre, info["tipo"], info["dias_restantes"]
		])

	for j in uruguay.todos_los_jugadores():
		if clubes_por_jugador.get(j["id"]) == equipo_jugador:
			_agregar_noticia("SELECCIÓN: %s (%s) es convocado a la Selección Uruguay." % [j["posicion"], equipo_jugador.nombre])


## Oferta del jugador humano por un jugador de otro club (pantalla de
## Mercado). Wrapper sobre Mercado.ofertar_por_jugador() que además deja
## una noticia si la oferta se concreta.
func ofertar_por_jugador(vendedor: Team, jugador_objetivo_id: int) -> Dictionary:
	var resultado := Mercado.ofertar_por_jugador(equipo_jugador, vendedor, jugador_objetivo_id, rng)
	if resultado["exito"]:
		_agregar_noticia("FICHAJE: %s ficha a un %s de %s por $%.0f (sale un %s)" % [
			equipo_jugador.nombre, resultado["posicion"], vendedor.nombre,
			resultado["diferencia"], resultado["jugador_sale"]["posicion"]
		])
	return resultado


## Fuerza la venta pagando la cláusula de rescisión completa — sin la
## resistencia que puede rechazar una oferta común (Mercado.pagar_clausula).
func pagar_clausula(vendedor: Team, jugador_objetivo_id: int) -> Dictionary:
	var resultado := Mercado.pagar_clausula(equipo_jugador, vendedor, jugador_objetivo_id)
	if resultado["exito"]:
		_agregar_noticia("CLÁUSULA: %s paga la cláusula de un %s de %s por $%.0f (sale un %s)" % [
			equipo_jugador.nombre, resultado["posicion"], vendedor.nombre,
			resultado["clausula"], resultado["jugador_sale"]["posicion"]
		])
	return resultado


## Fichar del pool de agentes libres de tu división (AgentesLibres.fichar):
## sin fee de transferencia, solo el sueldo. El jugador que reemplazás pasa
## a integrar el pool en tu lugar.
func fichar_agente_libre(jugador_id: int, indice_saliente: int, es_banco: bool) -> Dictionary:
	var resultado := AgentesLibres.fichar(equipo_jugador, liga_jugador().agentes_libres, jugador_id, indice_saliente, es_banco)
	if resultado["exito"]:
		_agregar_noticia("AGENTE LIBRE: %s ficha a un %s libre (sale un %s al pool)." % [
			equipo_jugador.nombre, resultado["entra"]["posicion"], resultado["sale"]["posicion"]
		])
	return resultado


## Cedés a un jugador de TU banco o cantera a préstamo por una temporada
## (Prestamos.ceder). Vuelve solo al cierre de la temporada de retorno.
func ceder_a_prestamo(jugador_id: int, club_destino: Team) -> Dictionary:
	var resultado := Prestamos.ceder(equipo_jugador, club_destino, jugador_id, temporada_actual)
	if resultado["exito"]:
		_agregar_noticia("PRÉSTAMO: %s cede un %s a %s por esta temporada." % [
			equipo_jugador.nombre, resultado["jugador"]["posicion"], club_destino.nombre
		])
	return resultado


## Pedís prestado a un jugador del banco/cantera de otro club de tu
## división. Vuelve solo a su club al cierre de la temporada de retorno.
func pedir_prestamo(club_origen: Team, jugador_id: int) -> Dictionary:
	var resultado := Prestamos.ceder(club_origen, equipo_jugador, jugador_id, temporada_actual)
	if resultado["exito"]:
		_agregar_noticia("PRÉSTAMO: %s recibe a préstamo un %s de %s." % [
			equipo_jugador.nombre, resultado["jugador"]["posicion"], club_origen.nombre
		])
	return resultado


## Sube un nivel de instalación del club (Instalaciones.mejorar), pagado con
## el presupuesto de Mejoras.
func mejorar_instalacion(categoria: String) -> Dictionary:
	var resultado := Instalaciones.mejorar(equipo_jugador, categoria)
	if resultado["exito"]:
		_agregar_noticia("INSTALACIONES: %s sube %s a nivel %d." % [equipo_jugador.nombre, categoria.capitalize(), resultado["nivel"]])
	return resultado


## Debug: juega todas las fechas que queden de la temporada actual de una
## sola vez (incluye el cierre). Pensado para probar rápido sin clickear
## "jugar fecha" 38 veces — no es parte del flujo normal del juego.
##
## OJO: hay_fecha_pendiente() sola NO alcanza como condición de corte acá
## — fecha_actual vuelve a 0 apenas cierra la temporada, así que
## "while hay_fecha_pendiente()" nunca daría false y simularía temporadas
## para siempre. Hay que cortar por el número de temporada, no por fecha.
func simular_temporada_completa() -> void:
	var temporada_inicial := temporada_actual
	while temporada_actual == temporada_inicial and hay_fecha_pendiente():
		jugar_siguiente_fecha()


func _agregar_noticia(texto: String) -> void:
	noticias.push_front(texto)
	if noticias.size() > MAX_NOTICIAS_GUARDADAS:
		noticias.resize(MAX_NOTICIAS_GUARDADAS)


## Guardado de partida (§12 del GDD) — un solo slot por ahora (no pedido
## multi-partida), en user:// como JSON: más fácil de depurar que binario,
## y a esta escala (200 clubes, ~4000 jugadores) el tamaño/velocidad no es
## un problema real. rng.state (no solo el seed) se guarda para que la
## sim continúe exactamente donde estaba, no desde el mismo arranque de
## siempre.
const RUTA_PARTIDA := "user://partida.json"


func hay_partida_guardada() -> bool:
	return FileAccess.file_exists(RUTA_PARTIDA)


func guardar_partida() -> void:
	var datos := {
		"version": 1,
		"rng_seed": rng.seed,
		"rng_state": rng.state,
		"piramide": piramide.guardar(),
		"confederacion": confederacion.guardar(),
		"seleccion": seleccion.guardar(),
		"division_jugador": division_jugador,
		"equipo_jugador_nombre": equipo_jugador.nombre,
		"fecha_actual": fecha_actual,
		"temporada_actual": temporada_actual,
		"noticias": noticias,
		"ultimo_informe_economico": ultimo_informe_economico,
		"ultima_posicion_final": ultima_posicion_final,
		"juego_terminado": juego_terminado,
		"motivo_fin_partida": motivo_fin_partida,
	}
	var file := FileAccess.open(RUTA_PARTIDA, FileAccess.WRITE)
	file.store_string(JSON.stringify(datos))
	file.close()


## Devuelve true si pudo cargar. No toca nada del estado actual si falla
## (archivo corrupto, versión futura, etc.) — la partida en curso sigue
## intacta y jugable, simplemente no se reemplazó por nada.
func cargar_partida() -> bool:
	if not hay_partida_guardada():
		return false

	var file := FileAccess.open(RUTA_PARTIDA, FileAccess.READ)
	var texto := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(texto) != OK:
		return false
	var datos: Dictionary = json.data

	var nueva_piramide := Piramide.cargar(datos["piramide"])
	var nuevo_equipo_jugador: Team = null
	var nueva_division: int = datos["division_jugador"]
	var nombre_buscado: String = datos["equipo_jugador_nombre"]
	for e in nueva_piramide.divisiones[nueva_division].equipos:
		if e.nombre == nombre_buscado:
			nuevo_equipo_jugador = e
			break
	if nuevo_equipo_jugador == null:
		return false  # guardado corrupto/incompatible: no se pudo relocalizar al equipo del jugador

	rng = RandomNumberGenerator.new()
	rng.seed = int(datos["rng_seed"])
	rng.state = int(datos["rng_state"])

	piramide = nueva_piramide
	confederacion = Confederacion.cargar(datos["confederacion"], piramide)
	seleccion = Seleccion.cargar(datos["seleccion"])
	division_jugador = nueva_division
	equipo_jugador = nuevo_equipo_jugador
	fecha_actual = datos["fecha_actual"]
	temporada_actual = datos["temporada_actual"]
	noticias = datos["noticias"]
	ultimo_informe_economico = datos["ultimo_informe_economico"]
	ultima_posicion_final = datos["ultima_posicion_final"]
	juego_terminado = datos.get("juego_terminado", false)
	motivo_fin_partida = datos.get("motivo_fin_partida", "")

	# Resultado/log/eventos del último partido son de la sesión anterior y
	# ya no tienen mucho sentido mostrados sueltos (el jugador ni se
	# acuerda de qué partido era) — se limpian, la próxima fecha los llena de nuevo.
	ultimo_resultado = {}
	ultimo_log = []
	ultimos_eventos = []

	return true


func borrar_partida() -> void:
	if hay_partida_guardada():
		DirAccess.remove_absolute(RUTA_PARTIDA)
