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

## §7.4.1/§7.4.7: cada cuántas fechas de liga cae una ronda de copa ENTRE
## SEMANA. Antes las copas se resolvían de una sola vez al cerrar la
## temporada, así que todas las fechas estaban a 7 días una de otra y
## elegir la carga de entrenamiento no tenía consecuencia: sin semanas
## apretadas, "Intenso" gana siempre.
const FECHAS_ENTRE_RONDAS_COPA := 4
## Fechas de liga que se juegan antes de sortear las copas de división.
## Cinco: la copa de división clasifica por la tabla EN CURSO, así que
## hace falta tabla. Con menos fechas casi todos empatan y el corte del
## 16° lo decide el desempate por nombre en vez de la cancha.
##
## Tiene que caer antes de la primera ronda de copa de división, que es el
## slot par siguiente: fecha 8 (ver _copas_de_la_ronda).
const FECHAS_PARA_COPA_DIVISION := 5
## Cada cuántas fechas de liga cae una ronda internacional, y en cuáles.
## Cae en las fechas IMPARES: las copas domésticas caen en los múltiplos
## de FECHAS_ENTRE_RONDAS_COPA (4), que son todos pares, así que las dos
## competencias nunca se pisan el miércoles.
##
## Dos fechas por ronda no es un número al azar: la Copa de Campeones
## necesita 13 rondas (8 de fase de liga + playoff + 4 de knockout) más la
## previa, y una temporada de 38 fechas tiene 19 miércoles impares. Con
## una ronda cada cuatro fechas no entraban ni la mitad.
const FECHAS_ENTRE_RONDAS_INTERNACIONAL := 2
## Reparto de la semana con partido entre semana: domingo, miércoles, y el
## domingo siguiente.
const DIAS_HASTA_COPA := 3
const DIAS_DESPUES_DE_COPA := 4
const DIVISION_INICIAL := 9  # 0-indexado: división 10, la última (GDD original)
const MAX_NOTICIAS_GUARDADAS := 400
## Cuantas se guardan de CADA categoria. Ver _recortar_noticias.
const MAX_POR_CATEGORIA := 60

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

## El calendario, en dias. Antes al jugar una fecha pasaban los 7 dias de
## un saque: todo lo que vencia en el medio —la respuesta de un club, una
## recuperacion, un informe— aparecia junto al final y no habia forma de
## reaccionar antes. El motor ya corria por dias (Team.avanzar_dias, los
## plazos de Ofertas); lo que faltaba era poder pasarlos de a uno.
##
## `dia_temporada` cuenta desde el arranque de la temporada y es el que
## decide que pasa hoy. `dia_absoluto` cuenta desde el arranque de la
## partida y solo sirve para la fecha que se muestra.
var dia_temporada: int = 0
var dia_absoluto: int = 0
## En que dia de la temporada se juega la proxima jornada de liga, y la
## proxima ronda de copa (-1 si no hay uno programado).
var dia_proximo_partido: int = 0
var dia_proxima_copa: int = -1
var dia_proximo_internacional: int = -1

## Los playoffs de ascenso ya jugados de la temporada que termina, por
## límite entre divisiones (clave String: así vuelve de JSON). Se juegan
## después de la última fecha y los aplica Piramide.fin_de_temporada. Antes
## se simulaban adentro del cierre y el club del jugador no los jugaba.
var playoffs_ascenso: Dictionary = {}

var ultimo_resultado: Dictionary = {}
var ultimo_log: Array = []
var ultimos_eventos: Array = []
## Posiciones tick a tick de los 22 + la pelota del último partido propio
## (MotorEspacial). Solo lo consume la animación — no se guarda en el save
## (son ~21.600 fotogramas) y se pierde al cerrar el juego, igual que el log.
var ultimos_fotogramas: Array = []

## Los partidos NUESTROS ya jugados, el mas reciente primero. Se guarda un
## resumen COMPACTO —marcador, las cuatro comparaciones y los hitos ya
## resueltos a nombres— y no los eventos crudos: un partido genera cientos
## de eventos y el archivo de guardado ya pesa varios megas.
var historial_partidos: Array = []

## Copas en curso. Ya no se resuelven de una sola vez al cerrar la
## temporada: se arman al empezarla y se juegan una ronda por semana
## entre fechas de liga (ver _jugar_ronda_de_copas).
var copa_nacional: Copa = null
var copas_division: Array = []
## La temporada internacional EN CURSO. Las tres copas ya no se juegan
## enteras al cerrar el año: se arman al empezarlo, con los cupos que sale
## del coeficiente y de la tabla pasada, y se juegan una ronda por semana
## entre fechas de liga (ver TemporadaInternacional).
var internacional: TemporadaInternacional = null
## Resumen plano de las tres copas internacionales para la pantalla de
## Copas: {"temporada": int, "campeones": {...}, ...}. Se rehace despues
## de cada ronda, asi que muestra la copa EN CURSO y no solo la del año
## pasado (ver TemporadaInternacional.resumen).
var copas_internacionales: Dictionary = {}
## Cuadro terminado del Rey y de la copa interna de la temporada pasada.
## Ver _guardar_copas_de_la_temporada.
var copas_pasadas: Dictionary = {}
## Todo lo que gano el club del jugador, en orden: [{temporada, titulo,
## detalle, anio}]. Ver _anotar_en_la_vitrina.
var vitrina: Array = []
## El palmares de TODAS las competencias, no solo lo que gano el club del
## jugador: competencia -> [{temporada, campeon, subcampeon}]. Ver
## _anotar_palmares y core/historial.gd.
var historial_copas: Dictionary = {}
## La foto de la ultima temporada cerrada, para la pantalla de resumen.
## Ver _guardar_resumen_de_temporada.
var resumen_temporada: Dictionary = {}
var noticias: Array = []
var ultimo_informe_economico: Dictionary = {}  # ingresos/egresos/neto del ultimo cierre de temporada
var ultima_posicion_final: Dictionary = {}  # {"posicion","total","division"} del cierre de temporada mas reciente

## La foto de las diez tablas finales de la temporada PASADA:
## nombre_club -> {"division", "posicion"}. Es lo que decide quien
## clasifica a las copas de esta temporada (ver ClasificacionCopas). Se
## saca en _cerrar_temporada, antes de que Piramide.fin_de_temporada
## resetee las tablas. Vacio en la temporada 1: ahi clasifica por
## reputacion.
var posiciones_temporada_anterior: Dictionary = {}

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
	partida_nueva(99)


## Arranca un mundo nuevo, tirando TODO lo que hubiera en memoria.
##
## `semilla` -1 = al azar. El arranque de la primera vez usa la 99 fija
## para que el mundo sea reproducible mientras se desarrolla; una partida
## nueva pedida desde el menu no, porque volver a jugar el mismo mundo con
## los mismos 200 clubes no es empezar de nuevo.
func partida_nueva(semilla: int = -1, nombre_club: String = "",
		camiseta: Color = Color.TRANSPARENT, short: Color = Color.TRANSPARENT,
		abreviacion: String = "", camiseta_secundaria: Color = Color.TRANSPARENT,
		short_secundario: Color = Color.TRANSPARENT, escudo: int = 0,
		logo: int = 0, color_escudo_elegido: Color = Color.TRANSPARENT,
		color_logo_elegido: Color = Color.TRANSPARENT) -> void:
	rng = RandomNumberGenerator.new()
	if semilla < 0:
		rng.randomize()
	else:
		rng.seed = semilla

	piramide = Piramide.generar(rng)
	# El club del jugador se renombra ACA, antes de que se armen la
	# confederacion y las copas: de ahi en mas el nombre ya viajo a
	# demasiados indices como para cambiarlo sin romper algo.
	var mio: Team = piramide.divisiones[DIVISION_INICIAL].equipos[0]
	if nombre_club.strip_edges() != "":
		var nombre_deseado := nombre_club.strip_edges()
		# El nombre puede repetirse entre partidas. Si justo choca con un
		# club generado en ESTE mundo nuevo, se mueve ese club antes de
		# renombrar al equipo del jugador.
		var ocupado: Team = null
		for liga in piramide.divisiones:
			for equipo in liga.equipos:
				if equipo != mio and equipo.nombre == nombre_deseado:
					ocupado = equipo
					break
			if ocupado != null:
				break
		if ocupado != null:
			var nombres_usados := {}
			for liga in piramide.divisiones:
				for equipo in liga.equipos:
					nombres_usados[equipo.nombre] = true
			var reemplazo := GeneradorNombres.nombre_club(rng, nombres_usados)
			piramide.renombrar(ocupado, reemplazo)
		piramide.renombrar(mio, nombre_deseado)
		mio.abreviacion = Team.abreviacion_por_defecto(mio.nombre)
	if camiseta.a > 0.0:
		mio.color_camiseta = camiseta
	if short.a > 0.0:
		mio.color_short = short
	if abreviacion.strip_edges() != "":
		mio.abreviacion = abreviacion.strip_edges().to_upper()
	if camiseta_secundaria.a > 0.0:
		mio.color_camiseta_secundaria = camiseta_secundaria
	if short_secundario.a > 0.0:
		mio.color_short_secundario = short_secundario
	mio.escudo_forma = clampi(escudo, 0, 9)
	mio.logo_forma = clampi(logo, 0, 9)
	if color_escudo_elegido.a > 0.0:
		mio.color_escudo = color_escudo_elegido
	if color_logo_elegido.a > 0.0:
		mio.color_logo = color_logo_elegido
	_sembrar_presupuestos()
	confederacion = Confederacion.generar(piramide, rng)
	seleccion = Seleccion.new()
	division_jugador = DIVISION_INICIAL
	equipo_jugador = piramide.divisiones[DIVISION_INICIAL].equipos[0]
	# Las copas se arman ANTES del objetivo: sin cupo en el Rey no se
	# puede sortear un objetivo de copa (Objetivos.generar).
	posiciones_temporada_anterior = {}
	_armar_copas()
	equipo_jugador.objetivo_temporada = Objetivos.generar(
		equipo_jugador, _es_ultima_division(DIVISION_INICIAL), liga_jugador().equipos.size(),
		rng, _clasificado_al_rey())

	# Todo lo que no vive en la piramide y quedaria colgado de la partida
	# anterior: el calendario, el ultimo partido, las noticias, el balance.
	fecha_actual = 0
	temporada_actual = 1
	Historial.temporada = temporada_actual
	# La partida arranca en receso, el dia en que abre el libro de pases
	# previo a la temporada 1. Mismo mecanismo que el receso entre
	# temporadas: `dia_temporada` negativo hasta el arranque de marzo.
	dia_absoluto = Calendario.apertura_del_mercado_previo()
	dia_temporada = -Calendario.dias_hasta_el_arranque(dia_absoluto)
	dia_proximo_partido = 0
	dia_proxima_copa = -1
	dia_proximo_internacional = -1
	playoffs_ascenso = {}
	historial_partidos = []
	copas_internacionales = {}
	copas_pasadas = {}
	vitrina = []
	historial_copas = {}
	resumen_temporada = {}
	ultimo_resultado = {}
	ultimo_log = []
	ultimos_eventos = []
	ultimos_fotogramas = []
	noticias = []
	ultimo_informe_economico = {}
	ultima_posicion_final = {}
	juego_terminado = false
	motivo_fin_partida = ""
	# El aviso de apertura sale de avanzar_un_dia, que compara ayer con hoy.
	# El primer dia de la partida no tiene ayer, asi que se avisa aca.
	_agregar_noticia("MERCADO: Se abrio el libro de pases: %d dias de mercado." % dias_de_mercado())


## El presupuesto de la PRIMERA temporada. Sin esto todos los clubes
## —incluido el tuyo— arrancan la partida con la caja en cero, porque los
## presupuestos se reparten al CERRAR una temporada (Economia): en la
## temporada 1 no habia con que fichar ni con que ofertar, y el mercado
## entero estaba muerto hasta el segundo año.
##
## Se corre como si cada club hubiera terminado a mitad de tabla, que es
## lo neutro: en esa posicion el ajuste de reputacion es cero, asi que
## sembrar la caja no le mueve la reputacion a nadie.
## Los prestamos de MEDIO año vencen a mitad de temporada, no al cierre,
## asi que hay que mirarlos mientras la temporada corre. El momento es la
## temporada como decimal: 3.5 es la mitad de la 3.
func _procesar_retornos_de_medio_ano() -> void:
	var fechas: int = liga_jugador().fixture.size()
	if fechas <= 0:
		return
	var momento: float = float(temporada_actual) + float(fecha_actual) / float(fechas)
	_avisar_opciones_por_vencer(momento)
	for liga in piramide.divisiones:
		for equipo in liga.equipos:
			for r in Prestamos.procesar_retornos(equipo, momento, equipo_jugador):
				if equipo == equipo_jugador:
					_agregar_noticia(Prestamos.texto_retorno(r), "fichajes",
						[Noticias.mencion(r["jugador"], equipo_jugador.nombre)])


## Avisa UNA vez por prestamo que la opcion de compra esta por vencer.
## Sin el aviso, la unica forma de no perderla era acordarse solo: la
## chance se muere en silencio el dia que el jugador se vuelve a su club.
func _avisar_opciones_por_vencer(momento: float) -> void:
	for id in equipo_jugador.prestados_propios:
		var info: Dictionary = equipo_jugador.prestados_propios[id]
		if float(info.get("opcion_compra", 0.0)) <= 0.0 or bool(info.get("aviso_opcion", false)):
			continue
		if momento < float(info["temporada_retorno"]) - Prestamos.AVISO_ANTES_DE_VENCER:
			continue
		var donde := Mercado.ubicar(equipo_jugador, int(id))
		if donde.is_empty():
			continue
		info["aviso_opcion"] = true
		_agregar_noticia("OPCIÓN DE COMPRA: se te vence la opción por %s (%s) por %s. Ejercela en Mercado > Cesión antes de que vuelva a su club." % [
			_nombre_completo(donde["jugador"]), donde["jugador"]["posicion"],
			Economia.formato_dinero(float(info["opcion_compra"]))],
			"fichajes", [Noticias.mencion(donde["jugador"], equipo_jugador.nombre)])


func _todas_las_cajas_vacias() -> bool:
	for liga in piramide.divisiones:
		for equipo in liga.equipos:
			for categoria in equipo.caja:
				if not is_zero_approx(float(equipo.caja[categoria])):
					return false
	return true


func _sembrar_presupuestos() -> void:
	for d in range(piramide.divisiones.size()):
		var liga: Liga = piramide.divisiones[d]
		var medio: int = int(liga.equipos.size() / 2.0)
		for equipo in liga.equipos:
			Economia.procesar_temporada(equipo, medio, liga.equipos.size(), liga.division)


## Arma la Copa del Rey de la temporada. Se llama al empezar cada una: el
## cuadro se sortea UNA vez y después se juega ronda a ronda.
##
## No entran todos: clasifican 128 al Rey, por la tabla de la temporada
## pasada (ver ClasificacionCopas). 128 es potencia de 2, así que ningún
## club pasa sin jugar.
##
## Las copas de división NO se sortean acá: esperan a la fecha
## FECHAS_PARA_COPA_DIVISION y clasifican por la tabla en curso (ver
## _armar_copas_de_division). Hasta entonces `copas_division` queda vacío.
## La temporada internacional arranca ACA tambien, y por el mismo motivo
## que el Rey: sus cupos salen de la tabla de la temporada pasada y sus
## cruces se juegan repartidos en el calendario, no de un saque al cerrar
## el año (ver TemporadaInternacional).
func _armar_copas() -> void:
	copa_nacional = Copa.iniciar("Copa del Rey",
		ClasificacionCopas.clasificados_nacional(piramide, posiciones_temporada_anterior), rng)
	copas_division = []
	internacional = confederacion.iniciar_temporada(rng, posiciones_temporada_anterior)
	dia_proximo_internacional = -1
	# `copas_internacionales` NO se pisa aca: la temporada internacional
	# nueva no tiene nada que mostrar hasta que se juega la previa, y
	# vaciarla dejaba la pantalla de Copas sin el campeon del año pasado
	# justo cuando se acaba de consagrar. Se rehace sola en la primera
	# ronda (ver _jugar_ronda_internacional).


## Sortea las diez copas de división con la tabla de la temporada EN
## CURSO, a las FECHAS_PARA_COPA_DIVISION fechas.
##
## Antes se sorteaban al empezar la temporada, con la tabla del año
## pasado, y el que ascendía quedaba afuera SIEMPRE: llegaba a la división
## nueva con la peor clave de mérito de las veinte. Con la tabla en curso
## el que ascendió y el que descendió clasifican por lo que hicieron en la
## cancha, en la misma tabla que los demás.
## `avisar` en false lo usa la carga de una partida vieja: ahi el sorteo
## se rehace para tapar un guardado sin cuadros, y una noticia de algo que
## ya paso hace fechas confunde.
func _armar_copas_de_division(avisar: bool = true) -> void:
	copas_division = []
	for d in range(piramide.divisiones.size()):
		copas_division.append(Copa.iniciar("Copa Division %d" % (d + 1),
			ClasificacionCopas.clasificados_por_tabla(piramide.divisiones[d]), rng))
	if avisar:
		_avisar_copa_de_division()


## Si el club del jugador entró a la copa de su división, con la posición
## que lo dejó adentro o afuera. Va en el momento del sorteo, no al cerrar
## la temporada anterior: recién acá se sabe.
func _avisar_copa_de_division() -> void:
	var interna: Copa = copas_division[division_jugador] if division_jugador < copas_division.size() else null
	if interna == null:
		return
	var puesto: int = liga_jugador().tabla_ordenada().find(equipo_jugador.nombre) + 1
	if interna.participa(equipo_jugador):
		_agregar_noticia("COPA DE LA DIVISIÓN %d: %s clasifica (va %d° a las %d fechas, entran los %d mejores)." % [
			division_jugador + 1, equipo_jugador.nombre, puesto,
			FECHAS_PARA_COPA_DIVISION, ClasificacionCopas.CUPOS_COPA_DIVISION], "campeones")
	else:
		_agregar_noticia("COPA DE LA DIVISIÓN %d: %s se queda afuera (va %d° a las %d fechas, entran los %d mejores)." % [
			division_jugador + 1, equipo_jugador.nombre, puesto,
			FECHAS_PARA_COPA_DIVISION, ClasificacionCopas.CUPOS_COPA_DIVISION], "campeones")


## Un cuadro sorteado ANTES de las copas por clasificación: reparte pases
## libres en la primera ronda, que es justo lo que el sistema nuevo no
## hace. Solo cuenta si la copa no arrancó (sin rondas jugadas).
func _hay_cuadro_viejo() -> bool:
	for copa in ([copa_nacional] + copas_division):
		if copa == null:
			continue
		if copa.historial.is_empty() and not copa.equipos_con_bye.is_empty():
			return true
	return false


## Si el club del jugador tiene cupo en el Rey de esta temporada.
func _clasificado_al_rey() -> bool:
	return copa_nacional != null and copa_nacional.participa(equipo_jugador)


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
				ultimos_fotogramas = r.get("fotogramas_seguido", [])
				_registrar_en_historial()
			# Solo las de NUESTRA division: las de las otras nueve son
			# doscientos clubes de los que no se sabe ni el nombre de un
			# jugador, y taparian el feed.
			_noticias_de_lesiones(r.get("lesionados", []))
		else:
			liga.jugar_fecha(fecha_actual, rng)

	# Los sponsors no cobran aca: solo se anota que jugaron una fecha mas
	# bajo contrato. Cobran al cerrar la temporada, prorrateados por esas
	# fechas (ver Sponsors.cobrar_temporada).
	Sponsors.registrar_partido(equipo_jugador)

	fecha_actual += 1

	# El sorteo de las copas de division cae aca, con la tabla ya cerrada
	# de esta fecha. Va antes de agendar la ronda de copa porque
	# _toca_ronda_de_copa() mira si hay copa de division pendiente.
	if fecha_actual == FECHAS_PARA_COPA_DIVISION:
		_armar_copas_de_division()

	# Los dias NO pasan aca: los pasa avanzar_un_dia(), de a uno, para que
	# se pueda ver y frenar lo que vence en el medio. Lo unico que se hace
	# es AGENDAR: la proxima jornada a los 7 dias y, si toca, la ronda de
	# copa el miercoles del medio. La semana apretada sigue existiendo
	# igual —dos partidos en 7 dias— que es lo que le da sentido a elegir
	# la carga de entrenamiento.
	dia_proximo_partido = dia_temporada + DIAS_ENTRE_FECHAS
	if _toca_ronda_de_copa():
		dia_proxima_copa = dia_temporada + DIAS_HASTA_COPA
	if _toca_ronda_internacional():
		dia_proximo_internacional = dia_temporada + DIAS_HASTA_COPA


## El cuadro terminado del Rey y de la copa de TU division. La de las
## otras nueve no se guarda: son cuadros de veinte clubes que no volves a
## mirar, y el guardado no tiene por que cargarlos.
##
## `division` se anota porque si ascendiste o descendiste, la copa interna
## que jugaste no es la de la division en la que vas a estar el año que
## viene, y decir "Copa de la División 9" cuando ya estas en la 8 seria
## contar mal la historia.
func _guardar_copas_de_la_temporada() -> void:
	copas_pasadas = {"temporada": temporada_actual, "division": division_jugador + 1}
	if copa_nacional != null:
		copas_pasadas["rey"] = {
			"rondas": copa_nacional.historial,
			"campeon": copa_nacional.campeon.nombre if copa_nacional.campeon != null else "",
		}
	if division_jugador < copas_division.size():
		var interna: Copa = copas_division[division_jugador]
		copas_pasadas["interna"] = {
			"rondas": interna.historial,
			"campeon": interna.campeon.nombre if interna.campeon != null else "",
		}


## Le paga al campeon y al finalista de una copa. `factor` es 1.0 para las
## que no escalan con la division (el Rey y las internacionales, que son
## la misma competencia para todos) y el factor de la division para la
## copa interna. Devuelve lo que cobro el campeon, para la noticia.
##
## No va a la caja: la caja se REINICIA en el cierre de temporada, y las
## copas terminan justo ahi. Se acumula en Team.premios_copa y lo cobra
## Economia.procesar_temporada como un ingreso mas de la temporada.
func _pagar_premio_de_copa(copa: Copa, premios: Dictionary, factor: float) -> float:
	if copa == null or copa.campeon == null:
		return 0.0
	var al_campeon: float = float(premios[1]) * factor
	copa.campeon.premios_copa += al_campeon
	var perdedor := _club_por_nombre(copa.finalista())
	if perdedor != null:
		perdedor.premios_copa += float(premios[2]) * factor
	return al_campeon


## Un dia de sponsors: se caen las ofertas viejas y puede llegar una
## nueva. Solo llega si hay lugar libre — es lo que obliga a cancelar un
## contrato chico para hacerle sitio a uno grande.
func _avanzar_sponsors() -> void:
	for caida in Sponsors.avanzar_dias(equipo_jugador, 1):
		_agregar_noticia("SPONSOR: %s se cansó de esperar y retiró su oferta." % caida["nombre"])
	var tabla := liga_jugador().tabla_ordenada()
	var puesto: int = tabla.find(equipo_jugador.nombre) + 1
	if puesto <= 0:
		puesto = tabla.size()
	for oferta in Sponsors.tirar_ofertas(
			equipo_jugador, division_jugador, puesto, tabla.size(), rng):
		_agregar_noticia("SPONSOR: %s quiere poner su marca en tu camiseta (%s por partido)." % [
			oferta["nombre"], Economia.formato_dinero(oferta["pago"])])


## La foto de la temporada que se termina: la tabla final, los mejores de
## la liga y todos los campeones. La pantalla de resumen se dibuja de aca
## y no de los objetos vivos porque para cuando el jugador la mira ya se
## reseteo la tabla, ya se repartieron los ascensos y los cuadros de copa
## nuevos pisaron a los viejos.
func _guardar_resumen_de_temporada(tabla_final: Array, posicion_final: int,
		internacional: Dictionary) -> void:
	var liga := liga_jugador()
	var filas := []
	for nombre in tabla_final:
		var f: Dictionary = liga.tabla[nombre].duplicate()
		f["equipo"] = nombre
		filas.append(f)

	var campeones := []
	if not tabla_final.is_empty():
		campeones.append({
			"que": "Liga · División %d" % (division_jugador + 1),
			"quien": str(tabla_final[0])})
	if division_jugador < copas_division.size():
		var interna: Copa = copas_division[division_jugador]
		if interna.campeon != null:
			campeones.append({
				"que": "Copa de la División %d" % (division_jugador + 1),
				"quien": interna.campeon.nombre})
	if copa_nacional != null and copa_nacional.campeon != null:
		campeones.append({"que": "Copa del Rey", "quien": copa_nacional.campeon.nombre})
	for clave in ["campeones", "guerreros", "emergentes"]:
		if not internacional.has(clave):
			continue
		var c: Team = internacional[clave]["campeon"]
		if c != null:
			campeones.append({"que": "Copa de %s" % clave.capitalize(), "quien": c.nombre})

	resumen_temporada = {
		"temporada": temporada_actual,
		"anio": int(Calendario.fecha(dia_absoluto)["year"]),
		"division": division_jugador + 1,
		"posicion": posicion_final,
		"total": tabla_final.size(),
		"tabla": filas,
		"goleadores": EstadisticasLiga.ranking(liga.estadisticas, "goles", 3),
		"asistencias": EstadisticasLiga.ranking(liga.estadisticas, "asistencias", 3),
		"vallas": EstadisticasLiga.ranking(liga.estadisticas, "vallas", 3),
		"campeones": campeones,
	}


## Quien gano cada competencia de la temporada, TODAS y no solo las del
## club del jugador. Los nombres de competencia son los que muestra la
## pantalla de palmares: la liga y la copa van por division.
func _anotar_palmares(internacional: Dictionary) -> void:
	for d in range(piramide.divisiones.size()):
		var orden: Array = piramide.divisiones[d].tabla_ordenada()
		if orden.size() >= 2:
			Historial.anotar_titulo(historial_copas, "Liga · División %d" % (d + 1),
				str(orden[0]), str(orden[1]))
	for d in range(copas_division.size()):
		var interna: Copa = copas_division[d]
		if interna != null and interna.campeon != null:
			Historial.anotar_titulo(historial_copas, "Copa de la División %d" % (d + 1),
				interna.campeon.nombre, interna.finalista())
	if copa_nacional != null and copa_nacional.campeon != null:
		Historial.anotar_titulo(historial_copas, "Copa del Rey",
			copa_nacional.campeon.nombre, copa_nacional.finalista())
	for clave in ["campeones", "guerreros", "emergentes"]:
		if not internacional.has(clave):
			continue
		var campeon = internacional[clave].get("campeon")
		var knockout = internacional[clave].get("knockout")
		if campeon is Team:
			Historial.anotar_titulo(historial_copas, "Copa de %s" % clave.capitalize(),
				campeon.nombre, knockout.finalista() if knockout is Copa else "")


## Los titulos que ganaste esta temporada. Va al cerrarla, con las copas
## ya terminadas y ANTES de que los ascensos muevan de division: el titulo
## se gano en la division en la que se jugo.
##
## Se guarda el titulo, no el objeto: dentro de tres temporadas la copa,
## la liga y hasta el plantel van a ser otros, y lo unico que sigue
## valiendo es la linea que dice que lo ganaste.
func _anotar_en_la_vitrina(posicion_final: int, internacional: Dictionary) -> void:
	var division := division_jugador + 1
	if posicion_final == 1:
		_sumar_titulo("Liga", "División %d" % division)
	if division_jugador < copas_division.size():
		var interna: Copa = copas_division[division_jugador]
		if interna.campeon == equipo_jugador:
			_sumar_titulo("Copa de división", "División %d" % division)
	if copa_nacional != null and copa_nacional.campeon == equipo_jugador:
		_sumar_titulo("Copa del Rey", "las diez divisiones")
	for clave in ["campeones", "guerreros", "emergentes"]:
		if not internacional.has(clave):
			continue
		if internacional[clave]["campeon"] == equipo_jugador:
			_sumar_titulo("Copa de %s" % clave.capitalize(), "internacional")


## Lo que suma ganar una copa, para TODOS los clubes y no solo el tuyo: si
## el prestigio de los rivales no se moviera, en diez temporadas el unico
## club con nombre del pais serias vos. La liga y los ascensos los suman
## Liga.fin_de_temporada y Piramide; aca van las copas, que son lo unico
## que solo GameState sabe quien gano.
func _reputacion_por_copas(internacional: Dictionary) -> void:
	# Los nombres de titulo son los MISMOS que van a la vitrina (ver
	# _anotar_en_la_vitrina): asi no hay dos listas que se puedan
	# desincronizar y lo que la vitrina dice que ganaste es exactamente lo
	# que te sumo prestigio.
	for copa in copas_division:
		if copa != null and copa.campeon != null:
			Reputacion.sumar(copa.campeon, Reputacion.por_titulo("Copa de división"))
	if copa_nacional != null and copa_nacional.campeon != null:
		Reputacion.sumar(copa_nacional.campeon, Reputacion.por_titulo("Copa del Rey"))
	for clave in ["campeones", "guerreros", "emergentes"]:
		if not internacional.has(clave):
			continue
		var campeon = internacional[clave].get("campeon")
		if campeon is Team:
			Reputacion.sumar(campeon, Reputacion.por_titulo("Copa de %s" % clave.capitalize()))


func _sumar_titulo(titulo: String, detalle: String) -> void:
	vitrina.append({
		"temporada": temporada_actual, "titulo": titulo, "detalle": detalle,
		# El año del calendario: "temporada 4" no le dice nada a nadie
		# dentro de tres partidas, la fecha si.
		"anio": int(Calendario.fecha(dia_absoluto)["year"]),
	})
	_agregar_noticia("VITRINA: %s gana %s (%s)." % [
		equipo_jugador.nombre, titulo, detalle], "campeones")


## Quien se rompio en la fecha, con que y por cuanto tiempo. Va al feed
## con el jugador clickeable: de ahi se le abre la ficha y, si es de otro
## club, se lo puede mandar a investigar — un titular lesionado tres meses
## es exactamente cuando un club escucha ofertas.
func _noticias_de_lesiones(lesionados: Array) -> void:
	for les in lesionados:
		var j: Dictionary = les["jugador"]
		var club := str(les["club"])
		_agregar_noticia("%s (%s, %s) se lesiona: %s, %d dias afuera." % [
			_nombre_completo(j), j["posicion"], club, les["tipo"], int(les["dias"])],
			"lesiones", [Noticias.mencion(j, club)])


static func _nombre_completo(j: Dictionary) -> String:
	return "%s %s" % [j.get("nombre", ""), j.get("apellido", "")]


## Hoy hay partido de liga y no se puede avanzar el dia sin jugarlo.
## Repone el calendario de un guardado. Una partida guardada ANTES de que
## existiera el calendario no tiene ningun dia: se derivan de la jornada y
## queda parada EN el dia del proximo partido, que es exactamente donde
## estaba. Sin esto, esas partidas se perderian.
##
## Esta aparte y recibe `fechas_por_temporada` para poder probarla sin
## tocar el archivo de guardado de verdad.
func restaurar_calendario(datos: Dictionary, fechas_por_temporada: int) -> void:
	dia_temporada = int(datos.get("dia_temporada", fecha_actual * DIAS_ENTRE_FECHAS))
	dia_proximo_partido = int(datos.get("dia_proximo_partido", dia_temporada))
	dia_proxima_copa = int(datos.get("dia_proxima_copa", -1))
	dia_proximo_internacional = int(datos.get("dia_proximo_internacional", -1))
	# El dia absoluto solo alimenta la fecha que se muestra, asi que para
	# un guardado viejo alcanza con estimarlo.
	dia_absoluto = int(datos.get("dia_absoluto",
		(temporada_actual - 1) * maxi(fechas_por_temporada, 1) * DIAS_ENTRE_FECHAS
			+ dia_temporada))


func hay_partido_hoy() -> bool:
	return hay_fecha_pendiente() and dia_temporada >= dia_proximo_partido


## Estamos en ventana de mercado: se puede ofertar y te pueden ofertar.
func hay_mercado_abierto() -> bool:
	return Calendario.hay_mercado(dia_absoluto)


## Dias que le quedan a la ventana (-1 si esta cerrada).
func dias_de_mercado() -> int:
	return Calendario.dias_de_mercado_restantes(dia_absoluto)


## Estamos en receso: terminó la temporada y todavía no arrancó la nueva.
func en_receso() -> bool:
	return dia_temporada < 0


## Cuantos dias faltan para el proximo partido (0 = hoy).
func dias_hasta_el_partido() -> int:
	if not hay_fecha_pendiente():
		return -1
	return maxi(dia_proximo_partido - dia_temporada, 0)


## Pasa UN dia. Devuelve lo que paso ese dia, para que la UI lo cuente:
## sin eso, avanzar el dia seria un boton que no da ninguna informacion.
##
## Si hoy hay partido no avanza nada: primero se juega.
func avanzar_un_dia() -> Array:
	if (juego_terminado or hay_partido_hoy() or hay_partido_de_copa_hoy()
			or hay_partido_internacional_hoy() or hay_partido_de_playoff_hoy()):
		return []
	var noticias_antes: int = noticias.size()
	# Los que se recuperan se preguntan ANTES y DESPUES: Team.avanzar_dias
	# los devuelve, pero pasa por Liga, que resuelve los 20 clubes y no los
	# reenvia. Comparar la lista de lesionados propios es mas simple que
	# cambiar esa firma, y solo interesan los nuestros.
	var lesionados_antes := equipo_jugador.lesiones.keys()
	var habia_mercado := hay_mercado_abierto()
	_avanzar_dias_todos(1)
	dia_temporada += 1
	dia_absoluto += 1

	# Se cerro el libro de pases: se cae todo lo que estaba en el aire,
	# incluso lo que ya tenia acuerdo entre clubes. Es lo que le da peso a
	# la ventana — si aceptas una oferta el ultimo dia y no la firmas,
	# perdiste la oportunidad.
	var caidas := []
	if habia_mercado and not hay_mercado_abierto():
		caidas = Ofertas.cancelar_por_cierre_de_mercado(equipo_jugador)
		for texto in caidas:
			_agregar_noticia("MERCADO: %s" % texto)
		# Al historial en el acto: con el mercado cerrado no queda nada
		# que decidir, asi que no tienen por que seguir en la lista.
		Ofertas.archivar(equipo_jugador)

	var novedades := []
	for id in lesionados_antes:
		if equipo_jugador.esta_lesionado(int(id)):
			continue
		for j in equipo_jugador.todos_los_jugadores():
			if int(j["id"]) == int(id):
				novedades.append("%s %s se recupero de su lesion." % [
					j["nombre"], j["apellido"]])
				break

	_avanzar_sponsors()

	# Los rumores son de todos los dias de mercado: es la parte del feed
	# que te dice a quien mirar mientras la ventana esta abierta.
	if hay_mercado_abierto():
		for r in Rumores.generar(liga_jugador(), rng, equipo_jugador):
			_agregar_noticia(str(r["texto"]), "rumores",
				[Noticias.mencion(r["jugador"], str(r["club"]))])

	# La ronda de copa cae el miercoles: es el segundo partido de una
	# semana apretada, no un evento aparte del calendario.
	#
	# Se resuelve sola solo si el jugador NO tiene cruce. Si lo tiene, la
	# ronda queda esperando: hay_partido_de_copa_hoy() frena el calendario
	# hasta que el jugador aprieta Jugar en la portada.
	if dia_proxima_copa >= 0 and dia_temporada >= dia_proxima_copa and copa_de_hoy() == null:
		dia_proxima_copa = -1
		_jugar_ronda_de_copas()

	# La ronda internacional cae el mismo miercoles, en las fechas
	# impares: nunca la misma semana que la copa domestica (ver
	# FECHAS_ENTRE_RONDAS_INTERNACIONAL). Misma regla que la copa: se
	# resuelve sola solo si el jugador no tiene cruce.
	if (dia_proximo_internacional >= 0 and dia_temporada >= dia_proximo_internacional
			and not hay_partido_internacional_hoy()):
		dia_proximo_internacional = -1
		_jugar_ronda_internacional()

	# La temporada cierra cuando no quedan fechas Y ya paso la semana de
	# la ultima: si cerrara en el pitazo final, el jugador no llegaria a
	# ver el ultimo resultado ni a cobrar los ultimos dias.
	if _termino_la_liga():
		# Los playoffs de ascenso van primero: son la continuacion de la
		# liga. Los de la IA se juegan solos; si el club del jugador tiene
		# cruce, la temporada lo espera igual que a una copa.
		_jugar_playoffs(null, true)
		# Hacen falta trece rondas de copa y en el calendario entran nueve
		# miercoles: las que sobran se juegan aca, antes de cerrar. Si en
		# alguna juega el equipo del jugador, la temporada ESPERA a que la
		# juegue el — la semifinal y la final de la Copa Nacional caen casi
		# siempre en este tramo.
		if _hay_copa_pendiente():
			dia_proxima_copa = dia_temporada
			while _hay_copa_pendiente() and copa_de_hoy() == null:
				_jugar_ronda_de_copas()
		# Lo mismo con la internacional: la Copa de Campeones necesita 14
		# rondas contando la previa y no siempre entran todas en el
		# calendario. Las que falten se juegan aca, y si en alguna juega el
		# club del jugador, la temporada lo espera.
		if _hay_internacional_pendiente():
			dia_proximo_internacional = dia_temporada
			while _hay_internacional_pendiente() and not hay_partido_internacional_hoy():
				_jugar_ronda_internacional()
		# Sin `return`: las noticias de las rondas que si se jugaron recien
		# se juntan al final de esta funcion, y salteando el tramo se
		# perderian.
		if (copa_de_hoy() == null and not hay_partido_internacional_hoy()
				and not hay_partido_de_playoff_hoy()):
			dia_proxima_copa = -1
			dia_proximo_internacional = -1
			_cerrar_temporada()

	# La apertura y el cierre del mercado se avisan siempre: son los dos
	# dias del ano en que cambia lo que se puede hacer.
	if not habia_mercado and hay_mercado_abierto():
		novedades.append("Se abrio el libro de pases: %d dias de mercado." % dias_de_mercado())
	elif habia_mercado and not hay_mercado_abierto():
		novedades.append("Se cerro el libro de pases.")

	# Las nuevas quedan ADELANTE: _agregar_noticia hace push_front. Leerlas
	# desde `noticias_antes` hacia el final devolvia las mas viejas del
	# feed —las que quedaron corridas— y no las que acababan de pasar.
	for i in range(noticias.size() - noticias_antes):
		# Los rumores no frenan el calendario. Van al feed igual, pero
		# "Ir al proximo partido" mira esta lista para saber si paso algo
		# que merece una decision, y con un rumor por dia de mercado el
		# boton no avanzaba nunca mas de un dia.
		if str(noticias[i].get("cat", "")) == "rumores":
			continue
		novedades.append(str(noticias[i]["texto"]))
	return novedades


## Avanza hasta el proximo partido, pero FRENA si pasa algo que merece una
## decision. Saltar a ciegas seria volver al problema de antes.
func avanzar_hasta_el_partido() -> Array:
	var todo := []
	while not hay_partido_hoy() and not hay_partido_de_copa_hoy() 			and not hay_partido_internacional_hoy() and not hay_partido_de_playoff_hoy() 			and not juego_terminado:
		var dia := avanzar_un_dia()
		todo.append_array(dia)
		if not dia.is_empty():
			break
	return todo


## Guarda el partido recien jugado como un resumen que se basta solo: la
## pantalla de historial no vuelve a mirar los eventos ni los planteles,
## que para entonces ya cambiaron de jugadores y hasta de division.
## `torneo` vacio = partido de liga. Con nombre = cruce de copa, y ahi el
## numero de fecha no significa nada: lo que ubica al partido es la copa.
func _registrar_en_historial(torneo: String = "") -> void:
	if ultimo_resultado.is_empty():
		return
	var local := str(ultimo_resultado.get("local", ""))
	var visitante := str(ultimo_resultado.get("visitante", ""))
	var stats := EstadisticasPartido.calcular(ultimos_eventos, local, visitante)

	var hitos := []
	for gol in ultimo_resultado.get("goles_log", []):
		hitos.append({
			"minuto": int(gol.get("minuto", 0)), "tipo": "gol",
			"equipo": str(gol.get("equipo", "")),
			"quien": _nombre_de_jugador(int(gol.get("jugador_id", -1)), local, visitante),
			"detalle": "",
		})
	for ev in ultimos_eventos:
		var tipo := str(ev.get("tipo", ""))
		if tipo != "tarjeta" and tipo != "cambio":
			continue
		hitos.append({
			"minuto": int(ev.get("minuto", 0)), "tipo": tipo,
			"equipo": str(ev.get("equipo", "")),
			"quien": str(ev.get("jugador_posicion", "")),
			"detalle": str(ev.get("resultado", "")),
		})
	hitos.sort_custom(func(a, b): return int(a["minuto"]) < int(b["minuto"]))

	historial_partidos.push_front({
		"temporada": temporada_actual,
		"torneo": torneo,
		"fecha": fecha_actual + 1,
		"dia": dia_absoluto,
		"division": division_jugador + 1,
		"local": local, "visitante": visitante,
		"gl": int(ultimo_resultado.get("gl", 0)),
		"gv": int(ultimo_resultado.get("gv", 0)),
		"stats": stats, "hitos": hitos,
		"analisis": _datos_de_analisis_partido(local, visitante, stats),
		"forfeit": bool(ultimo_resultado.get("forfeit", false)),
		"definicion": str(ultimo_resultado.get("definicion", "90 minutos")),
		"penales_texto": str(ultimo_resultado.get("penales_texto", "")),
		"ganador": str(ultimo_resultado.get("ganador", "")),
	})


## De id de jugador a nombre, buscando en los dos planteles del partido.
## Se resuelve ACA, al registrar: mas adelante el jugador puede haberse
## ido del club y el historial mostraria "?".
func _nombre_de_jugador(id: int, local: String, visitante: String) -> String:
	if id < 0:
		return "?"
	# En toda la piramide: el rival de copa o de playoff puede ser de otra
	# division.
	for nombre in [local, visitante]:
		var e := _club_por_nombre(nombre)
		if e == null:
			continue
		for j in e.jugadores + e.banco + e.cantera:
			if int(j["id"]) == id:
				return "%s %s" % [j.get("nombre", "?"), j.get("apellido", "")]
	return "?"


## Foto de los factores que pueden explicar el resultado. Se guarda junto
## al partido porque calidad, animo y tactica cambian despues.
func _datos_de_analisis_partido(local: String, visitante: String,
		stats: Dictionary) -> Dictionary:
	var salida := {"local": {}, "visitante": {}}
	for nombre in [local, visitante]:
		var fila: Dictionary = stats.get(nombre, {})
		var datos := {
			"media": 0.0, "division": 0, "formacion": "", "estilo": "",
			"tactica": 0.0, "animo": 50.0, "atajadas": 0,
			"tiros_fuera": int(fila.get("tiros", 0)) - int(fila.get("tiros_al_arco", 0)),
		}
		var equipo := _club_por_nombre(nombre)
		if equipo != null:
			datos["media"] = equipo.media_equipo()
			datos["division"] = equipo.division_actual + 1 if equipo.division_actual >= 0 else 0
			datos["formacion"] = equipo.formacion
			datos["estilo"] = equipo.estilo
			datos["tactica"] = Familiaridad.nivel(equipo)
			datos["animo"] = _animo_medio(equipo)
		for evento in ultimos_eventos:
			if str(evento.get("equipo", "")) != nombre:
				continue
			var tipo := str(evento.get("tipo", ""))
			var resultado := str(evento.get("resultado", ""))
			if tipo in ["tiro_puerta", "rebote", "penal"] \
					and resultado in ["atajada", "atajado"]:
				datos["atajadas"] = int(datos["atajadas"]) + 1
		salida["local" if nombre == local else "visitante"] = datos
	return salida


func _animo_medio(equipo: Team) -> float:
	if equipo.jugadores.is_empty():
		return 50.0
	var total := 0.0
	for jugador in equipo.jugadores:
		total += float(equipo.animo.get(int(jugador["id"]), 50.0))
	return total / float(equipo.jugadores.size())


## El jugador por el que va una negociacion, para que su nombre quede
## clickeable en el feed. Puede ser de otro club (oferta nuestra) o del
## nuestro (oferta que nos hacen), asi que se busca en los dos lados.
func _mencion_de_oferta(oferta: Dictionary) -> Array:
	var id := int(oferta.get("jugador_id", -1))
	if id < 0:
		return []
	for j in equipo_jugador.todos_los_jugadores():
		if int(j["id"]) == id:
			return [Noticias.mencion(j, equipo_jugador.nombre)]
	var club := _club_por_nombre(str(oferta.get("club", "")))
	if club != null:
		var donde := Mercado.ubicar(club, id)
		if not donde.is_empty():
			return [Noticias.mencion(donde["jugador"], club.nombre)]
	return []


## Como se titula la noticia de una negociacion. Una VENTA cerrada lleva
## el nombre del club propio adelante a proposito: el cartel de novedades
## pone primero las lineas que nombran a tu club, y la venta de un jugador
## tuyo es la que menos se puede perder.
func _prefijo_de_oferta(oferta: Dictionary) -> String:
	if bool(oferta.get("entrante", false)) and str(oferta.get("estado", "")) == Ofertas.CERRADA:
		return "VENTA (%s): " % equipo_jugador.nombre
	return "MERCADO: "


func _avanzar_dias_todos(dias: int) -> void:
	for liga in piramide.divisiones:
		liga.avanzar_dias(dias)
	# Los rivales del exterior tambien: sus copas se juegan repartidas en
	# la temporada, asi que sin recuperacion llegarian rotos a la final.
	if confederacion != null:
		confederacion.avanzar_dias(dias)
	# §9.3: las negociaciones corren con el calendario. Acá se resuelven
	# las que esperaban respuesta del otro club y aparecen las ofertas
	# nuevas por jugadores nuestros.
	# Las negociaciones solo corren con el mercado ABIERTO: fuera de la
	# ventana nadie contesta ni viene a buscar a nadie.
	if hay_mercado_abierto():
		for oferta in Ofertas.avanzar(equipo_jugador, dias, piramide, rng, temporada_actual,
				division_jugador, float(temporada_actual) + _fraccion_de_temporada()):
			if not oferta["log"].is_empty():
				_agregar_noticia("%s%s" % [_prefijo_de_oferta(oferta), oferta["log"][-1]],
					"fichajes", _mencion_de_oferta(oferta))
		for nueva in Ofertas.generar_entrantes(equipo_jugador, piramide, rng, dias, division_jugador):
			_agregar_noticia("MERCADO: %s" % nueva["log"][-1],
				"fichajes", _mencion_de_oferta(nueva))
		# Los pedidos de CESION entran por la misma lista de ofertas, pero
		# solo por los que abriste en la solapa Cesion (core/cesiones.gd).
		var pedido := Cesiones.generar_pedido(equipo_jugador, piramide, rng, dias, division_jugador)
		if not pedido.is_empty():
			_agregar_noticia("CESION: %s" % pedido["log"][-1],
				"fichajes", _mencion_de_oferta(pedido))
		_avanzar_cesiones_ia(dias)
	Ofertas.archivar(equipo_jugador)
	# El mercado de libres corre todos los dias, con la ventana abierta o
	# cerrada: no es una transferencia entre clubes.
	_avanzar_agentes_libres(dias)
	_procesar_retornos_de_medio_ano()


## Los clubes de la IA se ceden jugadores entre ellos (Cesiones.ronda_ia).
## Igual que con los libres, solo se avisan las que tocan a un club de TU
## division: son unas 160 por ventana en toda la piramide.
func _avanzar_cesiones_ia(dias: int) -> void:
	var momento: float = float(temporada_actual) + _fraccion_de_temporada()
	for c in Cesiones.ronda_ia(piramide, rng, dias, equipo_jugador, momento):
		var dueno: Team = c["dueno"]
		var pide: Team = c["pide"]
		if dueno.division_actual != division_jugador and pide.division_actual != division_jugador:
			continue
		var j: Dictionary = c["jugador"]
		_agregar_noticia("CESIONES: %s cede a %s (%s, media %d) a %s por %s." % [
			dueno.nombre, _nombre_completo(j), str(j["posicion"]), int(j["media"]),
			pide.nombre, Prestamos.ETIQUETAS_DURACION.get(str(c["duracion"]), "1 temporada").to_lower()],
			"fichajes", [Noticias.mencion(j, pide.nombre)])


## Los clubes de la IA salen a buscar al pool de libres. Solo se avisan
## los de TU division: son 200 clubes fichando todos los dias y el feed no
## puede ser una lista de fichajes ajenos. Los tuyos los decidis vos.
func _avanzar_agentes_libres(dias: int) -> void:
	for ficha in AgentesLibres.ronda_diaria(piramide, rng, dias, equipo_jugador):
		var club: Team = ficha["club"]
		if club.division_actual != division_jugador:
			continue
		var entra: Dictionary = ficha["entra"]
		var texto := "AGENTES LIBRES: %s ficha libre a %s (%s, media %d)." % [
			club.nombre, _nombre_completo(entra), str(entra["posicion"]),
			int(entra["media"])]
		var sale: Dictionary = ficha["sale"]
		if not sale.is_empty():
			texto += " Deja libre a un %s de media %d." % [
				str(sale["posicion"]), int(sale["media"])]
		_agregar_noticia(texto, "fichajes", [Noticias.mencion(entra, club.nombre)])


func _toca_ronda_de_copa() -> bool:
	if copa_nacional == null:
		return false
	if fecha_actual % FECHAS_ENTRE_RONDAS_COPA != 0:
		return false
	return _hay_copa_pendiente()


## Le toca ronda internacional en las fechas IMPARES, para no chocar con
## la copa domestica (ver FECHAS_ENTRE_RONDAS_INTERNACIONAL).
func _toca_ronda_internacional() -> bool:
	if not _hay_internacional_pendiente():
		return false
	return fecha_actual % FECHAS_ENTRE_RONDAS_INTERNACIONAL == 1


func _hay_internacional_pendiente() -> bool:
	return internacional != null and internacional.hay_pendiente()


func _hay_copa_pendiente() -> bool:
	if copa_nacional != null and copa_nacional.campeon == null:
		return true
	for c in copas_division:
		if c.campeon == null:
			return true
	return false


## Las copas a las que les toca ronda en este slot. Una ronda por slot,
## alternando: los slots impares son de la Copa Nacional y los pares de
## las diez copas de division. Dos partidos entre semana ademas de la liga
## seria un calendario que no existe.
##
## El ultimo caso —devolver la nacional aunque no sea su turno— es lo que
## permite drenar las rondas que sobran al cerrar la temporada: entran
## nueve slots y hacen falta trece rondas. Sin eso, un cierre con la
## nacional pendiente y las de division terminadas no jugaba ninguna ronda
## y el bucle de drenaje no cortaba nunca.
func _copas_de_la_ronda() -> Array:
	var slot: int = int(fecha_actual / FECHAS_ENTRE_RONDAS_COPA)
	var nacional_pendiente: bool = copa_nacional != null and copa_nacional.campeon == null
	var de_division := []
	for c in copas_division:
		if c.campeon == null:
			de_division.append(c)
	if slot % 2 == 1 and nacional_pendiente:
		return [copa_nacional]
	if not de_division.is_empty():
		return de_division
	return [copa_nacional] if nacional_pendiente else []


## La copa en la que al jugador le toca jugar HOY, o null. Es un dato
## DERIVADO del cuadro y del calendario: no agrega nada al guardado, asi
## que un cruce pendiente sobrevive a guardar y cargar la partida.
func copa_de_hoy() -> Copa:
	if juego_terminado or dia_proxima_copa < 0 or dia_temporada < dia_proxima_copa:
		return null
	for c in _copas_de_la_ronda():
		if not c.cruce_de(equipo_jugador).is_empty():
			return c
	return null


func hay_partido_de_copa_hoy() -> bool:
	return copa_de_hoy() != null


## El rival del cruce de copa de hoy, o null. En la Copa Nacional puede
## ser de cualquiera de las diez divisiones.
func rival_de_copa() -> Team:
	var c := copa_de_hoy()
	if c == null:
		return null
	var cruce: Array = c.cruce_de(equipo_jugador)
	return cruce[1] if cruce[0] == equipo_jugador else cruce[0]


## Si el cruce de copa de hoy lo juega de local.
func copa_de_local() -> bool:
	var c := copa_de_hoy()
	if c == null:
		return false
	return c.cruce_de(equipo_jugador)[0] == equipo_jugador


## Juega la ronda de copa de hoy CON el partido del jugador adentro: el
## suyo con el motor espacial y fotogramas, el resto simulado. La llama el
## boton de la portada. Antes esta ronda se resolvia sola y el jugador se
## enteraba del resultado por el feed.
func jugar_partido_de_copa() -> void:
	if copa_de_hoy() == null:
		return
	dia_proxima_copa = -1
	_jugar_ronda_de_copas(equipo_jugador)


## Resuelve la ronda de copa de hoy SIN mirar el cruce propio. Es lo que
## usa el modo "saltar la temporada" y lo que necesita cualquiera que
## maneje el calendario sin pantalla: el dia no avanza mientras haya un
## cruce de copa sin jugar, igual que no avanza con un partido de liga sin
## jugar. Jugarlo a mano y verlo es jugar_partido_de_copa().
func resolver_ronda_de_copa() -> void:
	if dia_proxima_copa < 0 or dia_temporada < dia_proxima_copa:
		return
	dia_proxima_copa = -1
	_jugar_ronda_de_copas()


## El cruce internacional que le toca al jugador HOY, o vacio. Mismo
## contrato que copa_de_hoy(): es un dato DERIVADO del cuadro y del
## calendario, asi que sobrevive a guardar y cargar la partida.
func cruce_internacional_de_hoy() -> Dictionary:
	if juego_terminado or internacional == null:
		return {}
	if dia_proximo_internacional < 0 or dia_temporada < dia_proximo_internacional:
		return {}
	return internacional.cruce_de(equipo_jugador)


func hay_partido_internacional_hoy() -> bool:
	return not cruce_internacional_de_hoy().is_empty()


## Como se llama el torneo y la ronda del partido internacional de hoy,
## para el encabezado de la portada. Ejemplo: "Copa de Guerreros ·
## Fecha 3 de la fase de liga".
func torneo_internacional_de_hoy() -> String:
	var cruce := cruce_internacional_de_hoy()
	if cruce.is_empty():
		return ""
	return "%s  ·  %s" % [str(cruce["torneo"]), str(cruce["ronda"])]


func rival_internacional() -> Team:
	var cruce := cruce_internacional_de_hoy()
	if cruce.is_empty():
		return null
	return cruce["visitante"] if cruce["local"] == equipo_jugador else cruce["local"]


func internacional_de_local() -> bool:
	var cruce := cruce_internacional_de_hoy()
	return not cruce.is_empty() and cruce["local"] == equipo_jugador


## Juega la ronda internacional de hoy CON el partido del jugador adentro:
## el suyo con el motor espacial y fotogramas, el resto simulado. La llama
## el boton de la portada.
func jugar_partido_internacional() -> void:
	if not hay_partido_internacional_hoy():
		return
	dia_proximo_internacional = -1
	_jugar_ronda_internacional(equipo_jugador)


## Resuelve la ronda internacional de hoy SIN mirar el cruce propio. Es lo
## que usa el modo "saltar la temporada", igual que resolver_ronda_de_copa.
func resolver_ronda_internacional() -> void:
	if dia_proximo_internacional < 0 or dia_temporada < dia_proximo_internacional:
		return
	dia_proximo_internacional = -1
	_jugar_ronda_internacional()


## Se jugó la última fecha y pasó su semana: es el momento del cierre, y
## antes del cierre, del playoff de ascenso.
func _termino_la_liga() -> bool:
	return not hay_fecha_pendiente() and dia_temporada >= dia_proximo_partido


## El cruce de playoff de ascenso que le toca al jugador HOY, o vacío.
## Mismo contrato que copa_de_hoy(): sale de la tabla final y de lo que ya
## se jugó, así que sobrevive a guardar y cargar la partida.
func cruce_de_playoff_de_hoy() -> Dictionary:
	if juego_terminado or not _termino_la_liga():
		return {}
	for cruce in piramide.cruces_de_playoff():
		if playoffs_ascenso.has(str(cruce["limite"])):
			continue
		if cruce["local"] == equipo_jugador or cruce["visitante"] == equipo_jugador:
			return cruce
	return {}


func hay_partido_de_playoff_hoy() -> bool:
	return not cruce_de_playoff_de_hoy().is_empty()


func rival_de_playoff() -> Team:
	var cruce := cruce_de_playoff_de_hoy()
	if cruce.is_empty():
		return null
	return cruce["visitante"] if cruce["local"] == equipo_jugador else cruce["local"]


func playoff_de_local() -> bool:
	var cruce := cruce_de_playoff_de_hoy()
	return not cruce.is_empty() and cruce["local"] == equipo_jugador


## Para el encabezado de la portada. Ejemplo: "Playoff de ascenso ·
## División 9 vs División 10".
func torneo_playoff_de_hoy() -> String:
	var cruce := cruce_de_playoff_de_hoy()
	if cruce.is_empty():
		return ""
	return "Playoff de ascenso  ·  División %d vs División %d" % [
		int(cruce["limite"]) + 1, int(cruce["limite"]) + 2]


## Juega el playoff del jugador con el motor espacial y fotogramas. La
## llama el boton de la portada.
func jugar_partido_de_playoff() -> void:
	if not hay_partido_de_playoff_hoy():
		return
	_jugar_playoffs(equipo_jugador, false)


## Resuelve los playoffs que falten SIN mirar el propio. Es lo que usa el
## modo "saltar la temporada", igual que resolver_ronda_de_copa.
func resolver_playoffs() -> void:
	_jugar_playoffs(null, false)


## Juega los playoffs de ascenso que falten. `esperar_al_jugador` deja
## pendiente el cruce del club del jugador para que lo juegue desde la
## portada. `equipo_seguido` pide su partido con fotogramas.
##
## Es un cruce de copa: no termina empatado (ver Piramide.jugar_playoff).
func _jugar_playoffs(equipo_seguido: Team, esperar_al_jugador: bool) -> void:
	for cruce in piramide.cruces_de_playoff():
		var clave := str(cruce["limite"])
		if playoffs_ascenso.has(clave):
			continue
		var local: Team = cruce["local"]
		var visitante: Team = cruce["visitante"]
		var es_el_del_jugador: bool = local == equipo_jugador or visitante == equipo_jugador
		if es_el_del_jugador and esperar_al_jugador:
			continue
		var mirado: bool = es_el_del_jugador and equipo_seguido == equipo_jugador
		var r := Piramide.jugar_playoff(local, visitante, rng, mirado)
		var fila := Copa.fila_de_historial(r)
		playoffs_ascenso[clave] = fila
		var sube: bool = r["ganador"] == visitante

		var division_arriba: int = int(cruce["limite"]) + 1
		if mirado:
			_tomar_ultimo_partido("Playoff de ascenso", Copa.detalle_seguido(r))
		var cierre := ""
		if str(fila["definicion"]) != "90 minutos":
			cierre = " en %s%s" % [fila["definicion"], fila["penales_texto"]]
		var desenlace := ("%s asciende a la División %d y %s desciende." % [
			visitante.nombre, division_arriba, local.nombre]) if sube \
			else ("%s se queda en la División %d." % [local.nombre, division_arriba])
		_agregar_noticia("PLAYOFF DE ASCENSO (División %d vs %d): %s %d-%d %s%s. %s" % [
			division_arriba, division_arriba + 1, local.nombre, int(fila["gl"]), int(fila["gv"]),
			visitante.nombre, cierre, desenlace], "campeones")


func _jugar_ronda_internacional(equipo_seguido: Team = null) -> void:
	if internacional == null:
		return
	internacional.jugar_siguiente_ronda(rng, equipo_seguido)
	if not internacional.seguido.is_empty():
		_tomar_partido_de_torneo(internacional.torneo_seguido, internacional.seguido,
			internacional.seguido_eliminatorio)
	# El resumen se rehace despues de CADA ronda: es lo que mira la
	# pantalla de Copas, y con la copa a medio jugar tambien hay tabla y
	# cuadro para mirar.
	copas_internacionales = internacional.resumen(temporada_actual)


func _jugar_ronda_de_copas(equipo_seguido: Team = null) -> void:
	for c in _copas_de_la_ronda():
		c.jugar_siguiente_ronda(rng, equipo_seguido)
		if not c.seguido.is_empty():
			_tomar_partido_de_copa(c)
		if c.campeon == null:
			continue
		if c == copa_nacional:
			var plata := _pagar_premio_de_copa(c, Economia.PREMIO_COPA_REY, 1.0)
			_agregar_noticia("COPA DEL REY: campeón %s (%s)." % [
				c.campeon.nombre, Economia.formato_dinero(plata)], "campeones")
		else:
			# La copa de division SI escala con la division: es una
			# competencia de esa division y su plata vale lo que vale ahi.
			var i: int = copas_division.find(c)
			var plata := _pagar_premio_de_copa(c, Economia.PREMIO_COPA_DIVISION,
				Economia.factor_division(i))
			_agregar_noticia("COPA DIVISIÓN %d: campeón %s (%s)." % [
				i + 1, c.campeon.nombre, Economia.formato_dinero(plata)], "campeones")


## El cruce de copa que acaba de jugar el jugador pasa a ser "el ultimo
## partido": es lo que mira la pantalla animada y lo que entra al
## historial, igual que un partido de liga.
func _tomar_partido_de_copa(c: Copa) -> void:
	_tomar_partido_de_torneo(c.nombre, c.seguido, true)


## El partido de torneo que acaba de jugar el jugador —una ronda de copa o
## un cruce internacional— pasa a ser "el ultimo partido": es lo que mira
## la pantalla animada y lo que entra al historial, igual que un partido
## de liga.
##
## `eliminatorio` en false son las fechas de la fase de liga
## internacional: ahi el empate es un resultado y nadie queda eliminado,
## asi que la noticia no puede decir "pasas de ronda".
func _tomar_partido_de_torneo(nombre_torneo: String, s: Dictionary,
		eliminatorio: bool) -> void:
	if s.is_empty():
		return
	_tomar_ultimo_partido(nombre_torneo, s)
	var paso: bool = str(s["ganador"]) == equipo_jugador.nombre
	var cierre := ""
	if str(s["definicion"]) != "90 minutos":
		cierre = " en %s%s" % [s["definicion"], s["penales_texto"]]
	var desenlace := ""
	if eliminatorio:
		desenlace = " Pasás de ronda." if paso else " Quedás eliminado."
	_agregar_noticia("%s: %s %d-%d %s%s.%s" % [
		nombre_torneo.to_upper(), s["local"], s["gl"], s["gv"], s["visitante"], cierre,
		desenlace], "campeones")


## El partido que acaba de jugar el jugador fuera de la liga pasa a ser
## "el ultimo partido": lo mira la pantalla animada y entra al historial.
func _tomar_ultimo_partido(nombre_torneo: String, s: Dictionary) -> void:
	ultimo_resultado = {
		"local": s["local"], "visitante": s["visitante"],
		"gl": s["gl"], "gv": s["gv"], "goles_log": s["goles_log"],
		# Como se cerro el cruce. Un cruce definido por penales termina
		# empatado en el marcador, asi que sin esto el resumen del partido
		# decia "Empate" justo despues de que el jugador viera ganar (o
		# perder) la tanda.
		"definicion": s["definicion"], "penales_texto": s["penales_texto"],
		"ganador": s["ganador"],
		"forfeit": bool(s.get("forfeit", false)),
	}
	ultimo_log = s["log"]
	ultimos_eventos = s["eventos"]
	ultimos_fotogramas = s["fotogramas"]
	_registrar_en_historial(nombre_torneo)


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

	# El campeon de cada division. Es el titulo mas grande del año y no
	# estaba en ningun lado: se sabia quien ascendia, no quien salio
	# campeon. Va antes de las copas para que quede arriba en el feed.
	for d in range(piramide.divisiones.size()):
		var orden: Array = piramide.divisiones[d].tabla_ordenada()
		if not orden.is_empty():
			_agregar_noticia("LIGA: campeón de la División %d: %s." % [
				d + 1, orden[0]], "campeones")

	# ACA, con las diez tablas todavía enteras: mas abajo
	# piramide.fin_de_temporada las resetea y mueve clubes de division, y
	# las copas de la temporada que viene se sortean con esta foto (ver
	# _armar_copas).
	posiciones_temporada_anterior = ClasificacionCopas.posiciones_finales(piramide)

	# Las copas vienen jugándose entre semana desde la primera fecha; si
	# quedó alguna ronda sin jugar (temporada corta, pocas fechas), se
	# termina acá para que siempre haya campeón.
	while _hay_copa_pendiente():
		_jugar_ronda_de_copas()

	# La internacional viene jugandose desde la primera fecha igual que
	# las copas. Lo que quede sin jugar se termina aca —el drenaje de
	# avanzar_un_dia ya espero al jugador— y recien despues se cierra:
	# ahi se recalculan los coeficientes de los doce paises y deriva la
	# fuerza de los clubes del exterior para el año que viene.
	#
	# `internacional` en null es una partida guardada de antes de que las
	# copas internacionales se jugaran repartidas: se arma y se juega
	# entera aca, como se hacia siempre.
	if internacional == null:
		internacional = confederacion.iniciar_temporada(rng, posiciones_temporada_anterior)
	while internacional.hay_pendiente():
		_jugar_ronda_internacional()
	var resultado_internacional := confederacion.cerrar_temporada(internacional, rng)
	copas_internacionales = internacional.resumen(temporada_actual)
	# ACA y no mas abajo: fin_de_temporada() resetea la tabla y las
	# estadisticas individuales para la temporada nueva, asi que despues
	# de esa linea ya no hay tabla final ni goleador que mostrar.
	_guardar_resumen_de_temporada(tabla_final, posicion_final, resultado_internacional)
	# Mismo momento y por lo mismo: tablas enteras y copas terminadas.
	Historial.cerrar_temporada(piramide)
	_anotar_palmares(resultado_internacional)

	for copa_nombre in ["campeones", "guerreros", "emergentes"]:
		var campeon: Team = resultado_internacional[copa_nombre]["campeon"]
		if campeon != null:
			var plata := _pagar_premio_de_copa(
				resultado_internacional[copa_nombre]["knockout"],
				Economia.PREMIO_COPA_INTERNACIONAL, 1.0)
			_agregar_noticia("INTERNACIONAL (%s): campeón %s (%s)." % [
				copa_nombre.capitalize(), campeon.nombre,
				Economia.formato_dinero(plata)], "campeones")

	# division_jugador todavia apunta a la division donde jugo esta
	# temporada — fin_de_temporada() es lo que procesa cantera (necesario
	# para el objetivo de categoria "cantera" mas abajo) ademas de
	# economia/mercado/progresion y ascensos/descensos.
	# Los sponsors cobran ACA: tiene que ser antes de fin_de_temporada,
	# que es quien llama a Economia.procesar_temporada y arma con el
	# ingreso del año el presupuesto del que viene.
	Sponsors.cobrar_temporada(equipo_jugador)

	var resultado_piramide := piramide.fin_de_temporada(rng, equipo_jugador, temporada_actual, playoffs_ascenso)
	playoffs_ascenso = {}
	# Los que colgaron los botines sin club: es por donde se vacia el pool
	# de libres (ver AgentesLibres.envejecer_pool). Se nombra al de mejor
	# media, que es el unico que alguien podria estar esperando fichar.
	var retirados: Array = resultado_piramide.get("retirados", [])
	if not retirados.is_empty():
		var mejor: Dictionary = retirados[0]
		for r in retirados:
			if float(r["media"]) > float(mejor["media"]):
				mejor = r
		if retirados.size() == 1:
			_agregar_noticia("SE RETIRA: %s (%s, %d años) cuelga los botines sin conseguir club." % [
				_nombre_completo(mejor), mejor["posicion"], int(mejor["edad"])], "fichajes")
		else:
			_agregar_noticia("SE RETIRAN: %d jugadores sin club cuelgan los botines. El mas conocido, %s (%s, %d años, media %d)." % [
				retirados.size(), _nombre_completo(mejor), mejor["posicion"],
				int(mejor["edad"]), int(mejor["media"])], "fichajes")
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
		# Liga manda casi todo como String pelado y alguna ya estructurada
		# (los fichajes, que nombran al jugador): normalizar acepta las dos.
		for n in liga.noticias:
			_agregar_entrada(Noticias.normalizar(n))
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
	Historial.temporada = temporada_actual
	fecha_actual = 0
	# Entre temporada y temporada hay RECESO: la nueva arranca siempre el
	# mismo dia de marzo, no al dia siguiente de terminar la anterior. Sin
	# eso el almanaque se corria —la temporada dura 266 dias, asi que la
	# segunda iria de noviembre a agosto y la tercera de agosto a mayo— y
	# los meses de mercado caerian en un momento distinto de cada
	# temporada. El receso ademas es cuando cae la ventana de enero.
	#
	# `dia_temporada` arranca NEGATIVO y va subiendo: mientras sea menor
	# que 0 no hay fecha que jugar, solo dias que pasar. `dia_absoluto` no
	# se reinicia nunca: es el que lleva la fecha real.
	dia_temporada = -Calendario.dias_hasta_el_arranque(dia_absoluto)
	dia_proximo_partido = 0
	dia_proxima_copa = -1
	dia_proximo_internacional = -1
	# Antes de tirarlos: las copas TERMINAN al cerrar la temporada y los
	# cuadros nuevos las pisan en el acto, asi que el cuadro terminado —el
	# unico que tiene campeon— no se llegaba a ver nunca. Se guarda el de
	# la que a esta altura ya se jugo entera.
	_guardar_copas_de_la_temporada()
	_reputacion_por_copas(resultado_internacional)
	_anotar_en_la_vitrina(posicion_final, resultado_internacional)

	# Los sponsors miran la tabla final: el que pidio algo y no lo tuvo se
	# va. Va DESPUES de fin_de_temporada a proposito: ahi es donde
	# procesar_temporada cobra lo que juntaron, asi que el que se va cobra
	# igual la temporada que jugo y recien despues deja el lugar libre.
	# La division es la que se JUGO: los ascensos todavia no corrieron.
	for s in Sponsors.evaluar_temporada(
			equipo_jugador, posicion_final, tabla_final.size(), division_jugador):
		var motivo := str(Sponsors.TEXTO_REQUISITO.get(s["requisito"], "")).to_lower()
		if Sponsors.cumple(str(s["requisito"]), posicion_final, tabla_final.size()):
			# Cumplio en la cancha pero el club se le quedo chico: es el
			# otro lado del requisito de reputacion y hinchada.
			motivo = str(Sponsors.texto_minimos(
				str(s["requisito"]), division_jugador)).to_lower().trim_prefix("pide ")
		_agregar_noticia("SPONSOR: %s corta el contrato con %s — pedia %s" % [
			s["nombre"], equipo_jugador.nombre, motivo])
	# Cuadros nuevos con los equipos YA movidos de división.
	_armar_copas()
	_avisar_clasificacion_a_copas()

	if not juego_terminado:
		equipo_jugador.objetivo_temporada = Objetivos.generar(
			equipo_jugador, _es_ultima_division(division_jugador), liga_jugador().equipos.size(),
			rng, _clasificado_al_rey())


## Clasificar a la Copa del Rey es un resultado de la temporada que
## termino, y el jugador no tiene de donde deducirlo: los cupos salen de
## la tabla final de CADA division y el cuadro nuevo ya esta sorteado.
##
## La copa de division no se avisa aca: se sortea a las cinco fechas de la
## temporada nueva y la avisa _avisar_copa_de_division().
func _avisar_clasificacion_a_copas() -> void:
	var puesto := int(ultima_posicion_final.get("posicion", 0))
	var division_jugada := int(ultima_posicion_final.get("division", division_jugador + 1))
	var cupos_rey := ClasificacionCopas.cupos_de(division_jugada - 1)
	if _clasificado_al_rey():
		_agregar_noticia("COPA DEL REY: %s clasifica (salió %d° en la División %d, entran los primeros %d)." % [
			equipo_jugador.nombre, puesto, division_jugada, cupos_rey], "campeones")
	else:
		_agregar_noticia("COPA DEL REY: %s se queda afuera (salió %d° en la División %d, entran los primeros %d)." % [
			equipo_jugador.nombre, puesto, division_jugada, cupos_rey], "campeones")
	_avisar_cupo_internacional()


## El cupo internacional sale de la División 1 y del coeficiente del país,
## asi que solo lo puede tener un club de primera. Se avisa igual que el
## del Rey: el cuadro ya esta sorteado y el jugador no tiene de donde
## deducirlo.
func _avisar_cupo_internacional() -> void:
	if internacional == null:
		return
	var clave := internacional.copa_de(equipo_jugador)
	if clave == "":
		return
	var donde := "la previa de la Copa de Campeones"
	if clave != "previa":
		donde = "la Copa de %s" % clave.capitalize()
	_agregar_noticia("INTERNACIONAL: %s juega %s esta temporada." % [
		equipo_jugador.nombre, donde], "campeones")



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
## Mensaje unico de mercado cerrado: lo comparten todas las operaciones y
## la UI, para que digan exactamente lo mismo.
const MERCADO_CERRADO := "El libro de pases esta cerrado. Se abre en enero y en julio."


func _mercado_cerrado() -> Dictionary:
	return {"exito": false, "motivo": MERCADO_CERRADO}


func ofertar_por_jugador(vendedor: Team, jugador_objetivo_id: int) -> Dictionary:
	if not hay_mercado_abierto():
		return _mercado_cerrado()
	# Compra al contado, la misma operacion que hace la IA: cualquiera del
	# plantel o de la cantera del vendedor, de la division que sea.
	var resultado := Mercado.comprar_al_contado(equipo_jugador, vendedor, jugador_objetivo_id, rng)
	if resultado["exito"]:
		_agregar_noticia("FICHAJE: %s ficha a %s (%s) de %s por %s." % [
			equipo_jugador.nombre, _nombre_completo(resultado["jugador"]),
			resultado["posicion"], vendedor.nombre,
			Economia.formato_dinero(resultado["precio"])],
			"fichajes", [Noticias.mencion(resultado["jugador"], equipo_jugador.nombre)])
	return resultado


## §9.3 rework: mandar una oferta ya no se resuelve en el acto. Queda
## abierta y el club se toma unos dias (ver core/ofertas.gd), asi que el
## mercado pasa a ser algo que hay que administrar: mandas tres y esperas.
func enviar_oferta(vendedor: Team, jugador_id: int, monto: float) -> Dictionary:
	if not hay_mercado_abierto():
		return _mercado_cerrado()
	if Negociacion.bloqueado(vendedor, jugador_id, temporada_actual):
		return {"exito": false, "motivo": "%s no te quiere escuchar por este jugador hasta la temporada que viene." % vendedor.nombre}
	var donde := Mercado.ubicar(vendedor, jugador_id)
	if donde.is_empty():
		return {"exito": false, "motivo": "Ese jugador ya no está en ese club."}
	for o in equipo_jugador.ofertas:
		if int(o["jugador_id"]) == jugador_id and Ofertas.abierta(o):
			return {"exito": false, "motivo": "Ya tenés una negociación abierta por él."}
	if equipo_jugador.caja["fichajes"] < monto:
		return {"exito": false, "motivo": "No te alcanza el presupuesto de Fichajes."}

	var oferta := Ofertas.nueva(
		equipo_jugador.siguiente_id_oferta, vendedor.nombre, donde["jugador"], monto, false, rng)
	equipo_jugador.siguiente_id_oferta += 1
	oferta["log"].append("Ofertaste %s a %s." % [Economia.formato_dinero(monto), vendedor.nombre])
	equipo_jugador.ofertas.append(oferta)
	return {"exito": true, "oferta": oferta}


func _oferta_por_id(oferta_id: int) -> Dictionary:
	for o in equipo_jugador.ofertas:
		if int(o["id"]) == oferta_id:
			return o
	return {}


## Responder a una negociacion que quedo de nuestro lado. `accion` es
## "aceptar", "rechazar" o "contraofertar".
##
## Aceptar una oferta ENTRANTE no cierra nada: manda al comprador a hablar
## de contrato con tu jugador, y eso puede salir mal. Aceptar una SALIENTE
## (o sea, pagar lo que te contraofertaron) te deja en acuerdo de clubes y
## el contrato lo arreglas vos.
func responder_oferta(oferta_id: int, accion: String, monto: float = 0.0) -> Dictionary:
	# Rechazar se puede SIEMPRE. Decir que no es bajarse de la mesa, no una
	# operacion de mercado, y bloquearlo dejaba al jugador encerrado: con
	# una negociacion vieja abierta y el libro cerrado no podia ni
	# aceptarla ni sacarsela de encima.
	if accion != "rechazar" and not hay_mercado_abierto():
		return _mercado_cerrado()
	var oferta := _oferta_por_id(oferta_id)
	if oferta.is_empty():
		return {"exito": false, "motivo": "Esa negociación ya no existe."}
	if str(oferta["estado"]) != Ofertas.PENDIENTE_NOSOTROS:
		return {"exito": false, "motivo": "No es tu turno en esa negociación."}

	match accion:
		"rechazar":
			Ofertas.rechazar(oferta)
			# Se archiva EN EL ACTO: rechazar algo y que siga en la lista
			# hasta que pase un dia es no haberlo rechazado.
			Ofertas.archivar(equipo_jugador)
			return {"exito": true, "oferta": oferta}
		"contraofertar":
			if not bool(oferta["entrante"]) and equipo_jugador.caja["fichajes"] < monto:
				return {"exito": false, "motivo": "No te alcanza el presupuesto de Fichajes."}
			Ofertas.contraofertar(oferta, monto, rng)
			return {"exito": true, "oferta": oferta}
		"aceptar":
			if bool(oferta["entrante"]):
				# Aceptar una CESION tampoco cierra nada: el jugador tiene
				# la ultima palabra igual que en una venta (Cesiones.cerrar).
				if str(oferta.get("tipo", "compra")) == "cesion":
					oferta["estado"] = Ofertas.ACUERDO_CLUB
					oferta["dias"] = float(rng.randi_range(
						Ofertas.DIAS_RESPUESTA_MIN, Ofertas.DIAS_RESPUESTA_MAX))
					oferta["log"].append("Aceptaste los terminos. Ahora falta que el jugador quiera ir.")
					return {"exito": true, "oferta": oferta}
				Ofertas.aceptar_entrante(oferta, rng)
				return {"exito": true, "oferta": oferta}
			if equipo_jugador.caja["fichajes"] < float(oferta["monto"]):
				return {"exito": false, "motivo": "No te alcanza el presupuesto de Fichajes."}
			oferta["estado"] = Ofertas.ACUERDO_CLUB
			oferta["log"].append("Aceptaste pagar %s." % Economia.formato_dinero(oferta["monto"]))
			return {"exito": true, "oferta": oferta}
	return {"exito": false, "motivo": "Acción desconocida."}


## Retirar una negociacion abierta que NO espera respuesta nuestra. Igual
## que rechazar, se puede con el mercado cerrado: bajarse no es operar.
func retirar_oferta(oferta_id: int) -> Dictionary:
	var oferta := _oferta_por_id(oferta_id)
	if oferta.is_empty() or not Ofertas.abierta(oferta):
		return {"exito": false, "motivo": "Esa negociación ya no existe."}
	Ofertas.retirar(oferta)
	Ofertas.archivar(equipo_jugador)
	return {"exito": true, "oferta": oferta}


## Los prestados que TENES vos y todavia se pueden comprar: el jugador,
## el club dueño, el precio pactado y cuando se vence la chance. La UI los
## muestra en el panel Cesion — la opcion se ejerce ANTES de que venza el
## prestamo, porque al vencer el jugador se vuelve a su club.
func opciones_de_compra_abiertas() -> Array:
	var salida := []
	for id in equipo_jugador.prestados_propios:
		var info: Dictionary = equipo_jugador.prestados_propios[id]
		var precio: float = float(info.get("opcion_compra", 0.0))
		if precio <= 0.0:
			continue
		var donde := Mercado.ubicar(equipo_jugador, int(id))
		if donde.is_empty():
			continue
		var dueno = info["club_dueno"]
		salida.append({
			"jugador": donde["jugador"],
			"dueno": dueno.nombre if dueno is Team else str(dueno),
			"precio": precio,
			"temporada_retorno": float(info["temporada_retorno"]),
		})
	return salida


## Ejerces la opcion de compra de un prestado tuyo: te lo quedas al precio
## que el dueño pactó cuando te lo cedio.
func ejercer_opcion_de_compra(jugador_id: int) -> Dictionary:
	# NO pide el libro de pases abierto, a diferencia de todo el resto del
	# mercado. La opcion no es una operacion nueva: es un derecho que
	# quedo firmado cuando se acordo la cesion, y el precio ya estaba
	# pactado. Con el gate puesto, un prestamo que vencia fuera de la
	# ventana te dejaba mirando como se iba el jugador sin poder ejercerla.
	if not equipo_jugador.prestados_propios.has(jugador_id):
		return {"exito": false, "motivo": "Ese jugador no está a préstamo en tu club."}
	var info: Dictionary = equipo_jugador.prestados_propios[jugador_id]
	var dueno = info["club_dueno"]
	if not (dueno is Team):
		dueno = _club_por_nombre(str(dueno))
	if dueno == null:
		return {"exito": false, "motivo": "Ese club ya no existe."}

	var donde := Mercado.ubicar(equipo_jugador, jugador_id)
	if donde.is_empty():
		return {"exito": false, "motivo": "Ese jugador ya no está en tu plantel."}
	var jugador: Dictionary = donde["jugador"]
	# El jugador tiene la ultima palabra tambien acá: comprarlo es un pase,
	# no una renovacion, y puede no querer quedarse.
	var sueldo_actual := Prestamos.sueldo_de_referencia(dueno, jugador)
	var pretende := Negociacion.sueldo_pretendido(jugador, sueldo_actual,
		dueno.division_actual, equipo_jugador.division_actual)
	var detalle := Negociacion.interes_jugador(jugador, equipo_jugador.animo.get(jugador_id, 50.0),
		sueldo_actual, pretende, dueno.division_actual, equipo_jugador.division_actual)
	if not detalle["acepta"]:
		return {"exito": false, "motivo": "No quiere quedarse: %s" % Negociacion.motivo_rechazo(detalle)}

	var r := Prestamos.ejercer_opcion(equipo_jugador, dueno, jugador_id, pretende)
	if not r["exito"]:
		return r
	_agregar_noticia("OPCIÓN DE COMPRA: %s ejerce la opción por %s (%s) y le paga %s a %s." % [
		equipo_jugador.nombre, _nombre_completo(jugador), jugador["posicion"],
		Economia.formato_dinero(r["precio"]), dueno.nombre],
		"fichajes", [Noticias.mencion(jugador, equipo_jugador.nombre)])
	return r


## Contraofertar los TERMINOS de un pedido de cesion. No hay un solo
## numero que mover: se discuten el fee, cuanto del sueldo te sacan de
## encima, cuanto dura, la opcion de compra y el plus que le ponen al
## jugador para convencerlo (ver core/cesiones.gd).
func contraofertar_cesion(oferta_id: int, terminos: Dictionary) -> Dictionary:
	if not hay_mercado_abierto():
		return _mercado_cerrado()
	var oferta := _oferta_por_id(oferta_id)
	if oferta.is_empty() or str(oferta.get("tipo", "compra")) != "cesion":
		return {"exito": false, "motivo": "Esa cesión ya no existe."}
	if str(oferta["estado"]) != Ofertas.PENDIENTE_NOSOTROS:
		return {"exito": false, "motivo": "No es tu turno en esa negociación."}
	if float(terminos.get("porcentaje_sueldo", 1.0)) < Prestamos.PORCENTAJE_SUELDO_MINIMO:
		return {"exito": false, "motivo": "Pedís que te cubran menos del %d%% del sueldo: eso no es una cesión, es un depósito." % int(
			Prestamos.PORCENTAJE_SUELDO_MINIMO * 100.0)}
	Cesiones.contraofertar(oferta, terminos, rng)
	return {"exito": true, "oferta": oferta}


## Lo que el club que pide llega a pagar como maximo, para que la UI pueda
## mostrar hasta donde apretar. Vacio si el club o el jugador ya no estan.
func topes_de_cesion(oferta: Dictionary) -> Dictionary:
	var pide := _club_por_nombre(str(oferta["club"]))
	var donde := Mercado.ubicar(equipo_jugador, int(oferta["jugador_id"]))
	if pide == null or donde.is_empty():
		return {}
	var temporadas: float = float(Prestamos.DURACIONES.get(str(oferta.get("duracion", "una")), 1.0))
	return Cesiones.topes(pide, equipo_jugador, donde["jugador"], temporadas)


## Ultimo tramo de una oferta NUESTRA ya acordada con el club: el contrato
## con el jugador. La clausula es tuya: ponersela alta lo blinda contra
## que te lo saquen, pero a el lo encierra y lo cobra (ver
## Negociacion.PESO_CLAUSULA).
func cerrar_fichaje(oferta_id: int, sueldo: float, anios: int,
		_clausula_obsoleta: float = 0.0) -> Dictionary:
	if not hay_mercado_abierto():
		return _mercado_cerrado()
	var oferta := _oferta_por_id(oferta_id)
	if oferta.is_empty() or str(oferta["estado"]) != Ofertas.ACUERDO_CLUB or bool(oferta["entrante"]):
		return {"exito": false, "motivo": "Esa negociación no está para firmar."}
	var vendedor := _club_por_nombre(str(oferta["club"]))
	if vendedor == null:
		return {"exito": false, "motivo": "Ese club ya no existe."}
	var jugador_id := int(oferta["jugador_id"])
	var donde := Mercado.ubicar(vendedor, jugador_id)
	if donde.is_empty():
		oferta["estado"] = Ofertas.RETIRADA
		return {"exito": false, "motivo": "Ese jugador ya no está en ese club."}
	var jugador: Dictionary = donde["jugador"]

	var detalle := Negociacion.interes_jugador(
		jugador, vendedor.animo.get(jugador_id, 50.0),
		float(vendedor.sueldos.get(jugador_id, 0.0)), sueldo,
		division_de(vendedor), division_jugador)
	if not detalle["acepta"]:
		var motivo := Negociacion.motivo_rechazo(detalle)
		oferta["estado"] = Ofertas.SIN_ACUERDO
		oferta["log"].append("%s no quiso firmar con %s: %s Se queda en su club." % [
			oferta["jugador"], equipo_jugador.nombre, motivo])
		_agregar_noticia("FICHAJE: %s rechazó firmar con %s. Se queda en %s: %s" % [
			oferta["jugador"], equipo_jugador.nombre, vendedor.nombre, motivo],
			"fichajes", [Noticias.mencion(jugador, vendedor.nombre)])
		Ofertas.archivar(equipo_jugador)
		return {"exito": false, "motivo": motivo, "detalle": detalle}

	var r := Mercado.ejecutar_pase(
		equipo_jugador, vendedor, jugador_id, float(oferta["monto"]), sueldo, anios, rng)
	if not r["exito"]:
		return r
	# No se marca conocido: de uno propio la ficha se ve entera sin informe.
	# Marcarlo lo metia en "Conocidos" y disparaba "Informe nuevo listo"
	# sin que ningun investigador lo hubiera pedido.
	oferta["estado"] = Ofertas.CERRADA
	oferta["log"].append("Firmado: %d año(s) a %s." % [
		anios, Economia.formato_dinero(sueldo)])
	_agregar_noticia("FICHAJE: %s se lleva a %s (%s) de %s por %s." % [
		equipo_jugador.nombre, _nombre_completo(jugador), r["posicion"],
		vendedor.nombre, Economia.formato_dinero(oferta["monto"])],
		"fichajes", [Noticias.mencion(jugador, equipo_jugador.nombre)])
	return r


## §9.3 rework: pedir un jugador a PRESTAMO. A diferencia de una compra,
## no hay regateo por rondas: el dueño mira las condiciones (cuanto del
## sueldo le sacas de encima y, si hay opcion de compra, si el numero le
## cierra contra lo que CREE que va a valer) y contesta si o no. Despues
## falta que el jugador quiera venir.
##
## `duracion` es una clave de Prestamos.DURACIONES.
## `plus_sueldo` es lo que le ponés al jugador POR ENCIMA de lo que cobra
## hoy. Sin esto un jugador que no queria bajar de categoria no tenia
## arreglo: el reparto del sueldo es plata entre clubes y a el no le
## cambia nada, asi que el pedido se rechazaba pusieras lo que pusieras.
func pedir_prestamo(dueno: Team, jugador_id: int, duracion: String,
		porcentaje_sueldo: float, opcion_compra: float,
		plus_sueldo: float = 0.0) -> Dictionary:
	if not hay_mercado_abierto():
		return _mercado_cerrado()
	var donde := Mercado.ubicar(dueno, jugador_id)
	if donde.is_empty():
		return {"exito": false, "motivo": "Ese jugador ya no está en ese club."}
	var jugador: Dictionary = donde["jugador"]
	var temporadas: float = float(Prestamos.DURACIONES.get(duracion, 1.0))

	var r := Prestamos.evaluar_pedido(dueno, jugador, porcentaje_sueldo, opcion_compra, temporadas)
	if not r["acepta"]:
		return {"exito": false, "motivo": r["motivo"], "minimo": r.get("minimo", 0.0)}

	# El jugador tambien decide. En un prestamo el salto de categoria pesa
	# la MITAD: es temporal y lo que busca es jugar, no mudarse.
	# Un canterano no tiene ficha registrada. Leerle un sueldo 0 lo hacia
	# comparar contra cero y rechazar siempre; la referencia es la misma
	# tabla con la que Prestamos.ceder reparte el pago.
	var sueldo_actual := Prestamos.sueldo_de_referencia(dueno, jugador)
	var plus: float = maxf(0.0, plus_sueldo)
	var div_origen := division_de(dueno)
	var salto: int = division_jugador - div_origen
	var detalle := Negociacion.interes_jugador(
		jugador, dueno.animo.get(jugador_id, 50.0), sueldo_actual, sueldo_actual + plus,
		div_origen, div_origen + int(round(salto / 2.0)))
	if not detalle["acepta"]:
		return {"exito": false, "motivo": Negociacion.motivo_rechazo(detalle),
			"detalle": detalle, "plus_sugerido": _plus_para_convencer(detalle, sueldo_actual)}

	var cierre := Prestamos.ceder(dueno, equipo_jugador, jugador_id,
		float(temporada_actual) + _fraccion_de_temporada(),
		temporadas, porcentaje_sueldo, opcion_compra, plus)
	if not cierre["exito"]:
		return cierre
	# Sin marcar_conocido, por lo mismo que en cerrar_fichaje.
	_agregar_noticia("PRÉSTAMO: %s se lleva a %s (%s) de %s por %s (fee %s)." % [
		equipo_jugador.nombre, _nombre_completo(jugador), jugador["posicion"],
		dueno.nombre, Prestamos.ETIQUETAS_DURACION.get(duracion, duracion),
		Economia.formato_dinero(cierre["fee"])],
		"fichajes", [Noticias.mencion(jugador, equipo_jugador.nombre)])
	return cierre


## Cuanto plus haria falta para dar vuelta un rechazo, en plata. Devuelve
## 0.0 si ni con el tope de PESO_SUELDO alcanza — ahi el "no" es de verdad
## y hay que decirselo al jugador en vez de hacerlo tirar plata al vacio.
func _plus_para_convencer(detalle: Dictionary, sueldo_actual: float) -> float:
	return Negociacion.plus_para_convencer(detalle, sueldo_actual)


## Cuanto de la temporada va corrido, de 0 a 1. Lo usa el prestamo para
## saber cuando vence.
func _fraccion_de_temporada() -> float:
	var fechas: int = liga_jugador().fixture.size()
	if fechas <= 0:
		return 0.0
	return float(fecha_actual) / float(fechas)


func _club_por_nombre(nombre: String) -> Team:
	for liga in piramide.divisiones:
		for e in liga.equipos:
			if e.nombre == nombre:
				return e
	if confederacion != null:
		var exterior: Variant = confederacion.indice_de_equipos().get(nombre, null)
		if exterior is Team:
			return exterior
	return null


## Las negociaciones que estan de tu lado esperando respuesta, para que la
## UI pueda avisar sin recorrer todo.
func ofertas_para_responder() -> int:
	var n := 0
	for o in equipo_jugador.ofertas:
		if str(o["estado"]) == Ofertas.PENDIENTE_NOSOTROS:
			n += 1
	return n


## En que division esta un club. -1 si no aparece (no deberia pasar).
func division_de(club: Team) -> int:
	for d in range(piramide.divisiones.size()):
		if piramide.divisiones[d].equipos.has(club):
			return d
	return division_jugador


## Fuerza la venta pagando la cláusula de rescisión completa — sin la
## resistencia que puede rechazar una oferta común (Mercado.pagar_clausula).
func pagar_clausula(vendedor: Team, jugador_objetivo_id: int) -> Dictionary:
	if not hay_mercado_abierto():
		return _mercado_cerrado()
	var resultado := Mercado.comprar_al_contado(equipo_jugador, vendedor, jugador_objetivo_id, rng)
	if resultado["exito"]:
		_agregar_noticia("CLÁUSULA: %s paga la cláusula de %s (%s, %s) por %s." % [
			equipo_jugador.nombre, _nombre_completo(resultado["jugador"]),
			resultado["posicion"], vendedor.nombre,
			Economia.formato_dinero(resultado["precio"])],
			"fichajes", [Noticias.mencion(resultado["jugador"], equipo_jugador.nombre)])
	return resultado


## El pool de agentes libres, uno solo para toda la piramide (ver
## Piramide.agentes_libres). Las diez divisiones apuntan a esta misma
## lista, asi que da igual por cual se pregunte.
func agentes_libres() -> Array:
	return piramide.agentes_libres


## Fichar un agente libre (AgentesLibres.fichar): sin fee de
## transferencia, solo el sueldo que se acordo negociando. No sale nadie
## a cambio — entra al banco y ocupa un lugar vacante del plantel.
func fichar_agente_libre(jugador_id: int, anios: int, sueldo: float) -> Dictionary:
	# SIN chequeo de ventana de mercado, a proposito: un jugador sin club
	# no es una transferencia. No hay club vendedor ni fee, asi que no hay
	# nada que el libro de pases tenga que regular (ver
	# AgentesLibres.ronda_diaria, que hace lo mismo con la IA).
	var resultado := AgentesLibres.fichar(
		equipo_jugador, agentes_libres(), jugador_id, anios, sueldo)
	if resultado["exito"]:
		_agregar_noticia("AGENTE LIBRE: %s ficha a %s (%s) por %d año%s a %s. Llega sin club y sin costo de pase." % [
			equipo_jugador.nombre, _nombre_completo(resultado["entra"]),
			resultado["entra"]["posicion"], int(resultado["anios"]),
			"" if int(resultado["anios"]) == 1 else "s",
			Economia.formato_dinero(float(resultado["sueldo"]))],
			"fichajes", [Noticias.mencion(resultado["entra"], equipo_jugador.nombre)])
	return resultado


## Cedés a un jugador tuyo a un club concreto, con los terminos ya
## arreglados. La via normal es la CESION negociada (core/cesiones.gd):
## esto es el ultimo tramo, y lo usan los tests y el cierre de una
## negociacion que ya paso por la mesa.
func ceder_a_prestamo(jugador_id: int, club_destino: Team) -> Dictionary:
	if not hay_mercado_abierto():
		return _mercado_cerrado()
	var resultado := Prestamos.ceder(equipo_jugador, club_destino, jugador_id, float(temporada_actual))
	if resultado["exito"]:
		_agregar_noticia("PRÉSTAMO: %s cede a %s (%s) a %s por esta temporada." % [
			equipo_jugador.nombre, _nombre_completo(resultado["jugador"]),
			resultado["jugador"]["posicion"], club_destino.nombre],
			"fichajes", [Noticias.mencion(resultado["jugador"], club_destino.nombre)])
	return resultado


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
	# Se alterna jugar y pasar dias, igual que lo hace el jugador. Con el
	# calendario, jugar_siguiente_fecha() ya no adelanta el tiempo: solo
	# agenda. Encadenando fechas sin dias en el medio, el plantel no
	# recuperaria fatiga, las ofertas no venceriann nunca y la temporada
	# no cerraria — la temporada entera se jugaria en un mismo dia.
	#
	# El tope de pasos es una red: son ~270 dias de temporada y si algun
	# dia dejara de avanzar, esto colgaria el juego en vez de fallar.
	var pasos := 0
	while temporada_actual == temporada_inicial and pasos < 5000:
		pasos += 1
		if hay_partido_hoy():
			jugar_siguiente_fecha()
			continue
		# Modo "saltar la temporada": la ronda de copa se resuelve sola,
		# sin frenar a mirar el cruce propio. Si frenara, avanzar_un_dia()
		# no avanzaria mas y esto giraria hasta el tope de pasos.
		if hay_partido_de_copa_hoy():
			resolver_ronda_de_copa()
			continue
		if hay_partido_internacional_hoy():
			resolver_ronda_internacional()
			continue
		if hay_partido_de_playoff_hoy():
			resolver_playoffs()
			continue
		# Las novedades se descartan a proposito: esto es el modo
		# "saltar la temporada", no se frena por nada.
		avanzar_un_dia()


## `categoria` vacia = que la adivine el texto (ver Noticias.clasificar).
## `jugadores` son las menciones clickeables de la noticia: con eso el
## feed puede abrir la ficha del que se nombra.
func _agregar_noticia(texto: String, categoria: String = "",
		jugadores: Array = []) -> void:
	_agregar_entrada(Noticias.crear(texto, categoria, jugadores))


func _agregar_entrada(entrada: Dictionary) -> void:
	noticias.push_front(entrada)
	_recortar_noticias()


## El tope es POR CATEGORIA y no del feed entero.
##
## Con un tope global, el cierre de temporada metia de un saque cientos de
## noticias de rutina de los 200 clubes de la piramide —cantera,
## aprendizaje, agentes libres, todas "club"— y empujaba fuera del tope
## todo lo demas: la solapa de campeones quedaba vacia el mismo dia en que
## se repartieron los titulos, y las lesiones de la temporada tampoco
## llegaban a verse.
func _recortar_noticias() -> void:
	if noticias.size() <= MAX_POR_CATEGORIA:
		return
	var vistas := {}
	var quedan := []
	for n in noticias:
		var cat := str(n.get("cat", "club"))
		var cuantas: int = int(vistas.get(cat, 0))
		if cuantas >= MAX_POR_CATEGORIA:
			continue
		vistas[cat] = cuantas + 1
		quedan.append(n)
	if quedan.size() > MAX_NOTICIAS_GUARDADAS:
		quedan.resize(MAX_NOTICIAS_GUARDADAS)
	noticias = quedan


## Guardado de partida (§12 del GDD) — un solo slot por ahora (no pedido
## multi-partida), en user:// como JSON: más fácil de depurar que binario,
## y a esta escala (200 clubes, ~4000 jugadores) el tamaño/velocidad no es
## un problema real. rng.state (no solo el seed) se guarda para que la
## sim continúe exactamente donde estaba, no desde el mismo arranque de
## siempre.
const RUTA_PARTIDA := "user://partida.json"


func hay_partida_guardada() -> bool:
	return FileAccess.file_exists(RUTA_PARTIDA)


## Datos del archivo guardado, para que la pantalla pueda decir QUE hay
## en vez de solo "hay una partida guardada".
func info_partida_guardada() -> Dictionary:
	if not hay_partida_guardada():
		return {}
	var t := Time.get_datetime_dict_from_unix_time(
		int(FileAccess.get_modified_time(RUTA_PARTIDA)))
	return {
		"cuando": "%02d/%02d/%d %02d:%02d" % [t["day"], t["month"], t["year"], t["hour"], t["minute"]],
		"megas": float(FileAccess.open(RUTA_PARTIDA, FileAccess.READ).get_length()) / 1048576.0,
	}


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
		"dia_temporada": dia_temporada,
		"dia_absoluto": dia_absoluto,
		"dia_proximo_partido": dia_proximo_partido,
		"dia_proxima_copa": dia_proxima_copa,
		"dia_proximo_internacional": dia_proximo_internacional,
		"playoffs_ascenso": playoffs_ascenso,
		"historial_partidos": historial_partidos,
		"copas_internacionales": copas_internacionales,
		"copas_pasadas": copas_pasadas,
		"vitrina": vitrina, "resumen_temporada": resumen_temporada,
		"historial_copas": historial_copas,
		"noticias": noticias,
		"ultimo_informe_economico": ultimo_informe_economico,
		"ultima_posicion_final": ultima_posicion_final,
		"posiciones_temporada_anterior": posiciones_temporada_anterior,
		"juego_terminado": juego_terminado,
		"motivo_fin_partida": motivo_fin_partida,
		# El último partido jugado se guarda (resultado, log y eventos, no
		# los fotogramas: son 960 cuadros de 22 jugadores y harían pesar el
		# archivo megabytes). Sin esto, al cargar la pantalla de Partido
		# decía "todavía no jugaste ninguna fecha", que era mentira.
		"ultimo_resultado": ultimo_resultado,
		"ultimo_log": ultimo_log,
		"ultimos_eventos": ultimos_eventos,
		# Las copas en curso también: perder el cuadro a mitad de
		# temporada al cargar sería inaceptable. Solo guardan nombres, así
		# que pesan nada (ver Copa.guardar).
		"copa_nacional": copa_nacional.guardar() if copa_nacional != null else {},
		"copas_division": _guardar_copas_division(),
		# La internacional tambien queda a medio jugar: sin esto, cargar
		# una partida en junio perdia la fase de liga entera.
		"internacional": internacional.guardar() if internacional != null else {},
	}


	var file := FileAccess.open(RUTA_PARTIDA, FileAccess.WRITE)
	file.store_string(JSON.stringify(datos))
	file.close()


func _guardar_copas_division() -> Array:
	var out := []
	for c in copas_division:
		out.append(c.guardar())
	return out


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
	Historial.temporada = temporada_actual
	restaurar_calendario(datos, liga_jugador().fixture.size())
	# Las de una partida vieja son Strings pelados: se envuelven y se les
	# adivina la categoria por el texto en vez de tirarlas.
	noticias = []
	for n in datos["noticias"]:
		noticias.append(Noticias.normalizar(n))
	playoffs_ascenso = datos.get("playoffs_ascenso", {})
	historial_partidos = datos.get("historial_partidos", [])
	copas_internacionales = datos.get("copas_internacionales", {})
	copas_pasadas = datos.get("copas_pasadas", {})
	vitrina = datos.get("vitrina", [])
	historial_copas = datos.get("historial_copas", {})
	resumen_temporada = datos.get("resumen_temporada", {})
	ultimo_informe_economico = datos["ultimo_informe_economico"]
	ultima_posicion_final = datos["ultima_posicion_final"]
	# Un guardado anterior a las copas por clasificación no la trae: las
	# copas de esa temporada quedan armadas como estaban y la foto se
	# llena sola en el próximo cierre.
	posiciones_temporada_anterior = datos.get("posiciones_temporada_anterior", {})
	juego_terminado = datos.get("juego_terminado", false)

	# Una partida guardada ANTES del libro de pases puede traer
	# negociaciones abiertas en un mes sin mercado: el cierre solo se
	# dispara el dia en que la ventana se cierra, y ese dia ya paso. Sin
	# esto quedaban colgadas para siempre — visibles, imposibles de
	# aceptar y (hasta recien) imposibles de rechazar. Va DESPUES de
	# cargar las noticias: si no, el aviso se pisa.
	if not hay_mercado_abierto():
		for aviso in Ofertas.cancelar_por_cierre_de_mercado(equipo_jugador):
			_agregar_noticia("MERCADO: %s" % aviso)
		Ofertas.archivar(equipo_jugador)
	motivo_fin_partida = datos.get("motivo_fin_partida", "")

	# Migración: un guardado hecho en la temporada 1 ANTES de que
	# existiera la siembra tiene la caja de TODOS en cero y se quedaría
	# así hasta el cierre de temporada, con el mercado muerto. Se detecta
	# porque ningún club de ninguna división tiene un peso en ninguna
	# categoría, que en una partida en curso no pasa nunca.
	if _todas_las_cajas_vacias():
		_sembrar_presupuestos()

	# Resultado, log y eventos del último partido vuelven tal cual estaban.
	# Los FOTOGRAMAS no: no se guardan por tamaño, así que la repetición
	# animada no está disponible hasta jugar la próxima fecha. Es lo único
	# que se pierde al cargar.
	# Las copas vuelven con su cuadro y su historial. Solo se rearman si el
	# guardado es anterior a que existieran las copas intercaladas.
	var datos_nacional: Dictionary = datos.get("copa_nacional", {})
	var datos_division: Array = datos.get("copas_division", [])
	# `copas_division` vacio es lo NORMAL antes de la fecha
	# FECHAS_PARA_COPA_DIVISION: todavia no se sortearon. Solo es un
	# guardado incompleto si ya deberian estar.
	var faltan_de_division: bool = datos_division.size() != piramide.divisiones.size() 		and not (datos_division.is_empty() and fecha_actual < FECHAS_PARA_COPA_DIVISION)
	if datos_nacional.is_empty() or faltan_de_division:
		_armar_copas()
		if fecha_actual >= FECHAS_PARA_COPA_DIVISION:
			_armar_copas_de_division(false)
	else:
		copa_nacional = Copa.cargar(datos_nacional, piramide)
		copas_division = []
		for d in datos_division:
			copas_division.append(Copa.cargar(d, piramide))
		# Migración a las copas por clasificación: un guardado anterior
		# trae los cuadros viejos, con los 200 clubes y sus pases libres.
		# Se resortean SOLO si todavía no se jugó una ronda — ahí no hay
		# nada que perder. Con una ronda jugada el cuadro viejo se termina
		# como está y el nuevo entra en la temporada que viene.
		if _hay_cuadro_viejo():
			_armar_copas()
			if fecha_actual >= FECHAS_PARA_COPA_DIVISION:
				_armar_copas_de_division(false)
	# La internacional vuelve igual que las copas, con su fase de liga y
	# su cuadro a medio jugar. Los equipos se relocalizan con el indice de
	# la confederacion, que junta la piramide y los clubes del exterior:
	# la mitad de los participantes no esta en la piramide.
	#
	# Un guardado anterior a que la internacional se jugara repartida no
	# la trae. Ahi queda en null a proposito: la temporada en curso la
	# resuelve entera al cerrar, como se hacia siempre, y la que viene ya
	# arranca con el calendario nuevo.
	var datos_internacional: Dictionary = datos.get("internacional", {})
	if datos_internacional.is_empty():
		internacional = null
	else:
		internacional = TemporadaInternacional.cargar(
			datos_internacional, confederacion.indice_de_equipos())
		copas_internacionales = internacional.resumen(temporada_actual)

	ultimo_resultado = datos.get("ultimo_resultado", {})
	ultimo_log = datos.get("ultimo_log", [])
	ultimos_eventos = datos.get("ultimos_eventos", [])
	ultimos_fotogramas = []

	return true


func borrar_partida() -> void:
	if hay_partida_guardada():
		DirAccess.remove_absolute(RUTA_PARTIDA)
