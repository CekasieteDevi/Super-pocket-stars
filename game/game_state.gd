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
## Reparto de la semana con partido entre semana: domingo, miércoles, y el
## domingo siguiente.
const DIAS_HASTA_COPA := 3
const DIAS_DESPUES_DE_COPA := 4
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

var ultimo_resultado: Dictionary = {}
var ultimo_log: Array = []
var ultimos_eventos: Array = []
## Posiciones tick a tick de los 22 + la pelota del último partido propio
## (MotorEspacial). Solo lo consume la animación — no se guarda en el save
## (son ~21.600 fotogramas) y se pierde al cerrar el juego, igual que el log.
var ultimos_fotogramas: Array = []

## Copas en curso. Ya no se resuelven de una sola vez al cerrar la
## temporada: se arman al empezarla y se juegan una ronda por semana
## entre fechas de liga (ver _jugar_ronda_de_copas).
var copa_nacional: Copa = null
var copas_division: Array = []
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
	partida_nueva(99)


## Arranca un mundo nuevo, tirando TODO lo que hubiera en memoria.
##
## `semilla` -1 = al azar. El arranque de la primera vez usa la 99 fija
## para que el mundo sea reproducible mientras se desarrolla; una partida
## nueva pedida desde el menu no, porque volver a jugar el mismo mundo con
## los mismos 200 clubes no es empezar de nuevo.
func partida_nueva(semilla: int = -1, nombre_club: String = "",
		camiseta: Color = Color.TRANSPARENT, short: Color = Color.TRANSPARENT) -> void:
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
		piramide.renombrar(mio, nombre_club)
	if camiseta.a > 0.0:
		mio.color_camiseta = camiseta
	if short.a > 0.0:
		mio.color_short = short
	_sembrar_presupuestos()
	confederacion = Confederacion.generar(piramide, rng)
	seleccion = Seleccion.new()
	division_jugador = DIVISION_INICIAL
	equipo_jugador = piramide.divisiones[DIVISION_INICIAL].equipos[0]
	equipo_jugador.objetivo_temporada = Objetivos.generar(
		equipo_jugador, _es_ultima_division(DIVISION_INICIAL), liga_jugador().equipos.size(), rng)
	_armar_copas()

	# Todo lo que no vive en la piramide y quedaria colgado de la partida
	# anterior: el calendario, el ultimo partido, las noticias, el balance.
	fecha_actual = 0
	temporada_actual = 1
	dia_temporada = 0
	dia_absoluto = 0
	dia_proximo_partido = 0
	dia_proxima_copa = -1
	ultimo_resultado = {}
	ultimo_log = []
	ultimos_eventos = []
	ultimos_fotogramas = []
	noticias = []
	ultimo_informe_economico = {}
	ultima_posicion_final = {}
	juego_terminado = false
	motivo_fin_partida = ""


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
	for liga in piramide.divisiones:
		for equipo in liga.equipos:
			for j in Prestamos.procesar_retornos(equipo, momento):
				if equipo == equipo_jugador:
					_agregar_noticia("PRÉSTAMOS: vuelve %s del préstamo." % j["posicion"])


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


## Arma las copas de la temporada. Se llama al empezar cada una: los
## cuadros se sortean UNA vez y después se juegan ronda a ronda.
func _armar_copas() -> void:
	var todos := []
	for liga in piramide.divisiones:
		for equipo in liga.equipos:
			todos.append(equipo)
	copa_nacional = Copa.iniciar("Copa Nacional", todos, rng)
	copas_division = []
	for d in range(piramide.divisiones.size()):
		copas_division.append(Copa.iniciar(
			"Copa Division %d" % (d + 1), piramide.divisiones[d].equipos.duplicate(), rng))


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
		else:
			liga.jugar_fecha(fecha_actual, rng)

	fecha_actual += 1

	# Los dias NO pasan aca: los pasa avanzar_un_dia(), de a uno, para que
	# se pueda ver y frenar lo que vence en el medio. Lo unico que se hace
	# es AGENDAR: la proxima jornada a los 7 dias y, si toca, la ronda de
	# copa el miercoles del medio. La semana apretada sigue existiendo
	# igual —dos partidos en 7 dias— que es lo que le da sentido a elegir
	# la carga de entrenamiento.
	dia_proximo_partido = dia_temporada + DIAS_ENTRE_FECHAS
	if _toca_ronda_de_copa():
		dia_proxima_copa = dia_temporada + DIAS_HASTA_COPA


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
	# El dia absoluto solo alimenta la fecha que se muestra, asi que para
	# un guardado viejo alcanza con estimarlo.
	dia_absoluto = int(datos.get("dia_absoluto",
		(temporada_actual - 1) * maxi(fechas_por_temporada, 1) * DIAS_ENTRE_FECHAS
			+ dia_temporada))


func hay_partido_hoy() -> bool:
	return hay_fecha_pendiente() and dia_temporada >= dia_proximo_partido


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
	if juego_terminado or hay_partido_hoy():
		return []
	var noticias_antes: int = noticias.size()
	# Los que se recuperan se preguntan ANTES y DESPUES: Team.avanzar_dias
	# los devuelve, pero pasa por Liga, que resuelve los 20 clubes y no los
	# reenvia. Comparar la lista de lesionados propios es mas simple que
	# cambiar esa firma, y solo interesan los nuestros.
	var lesionados_antes := equipo_jugador.lesiones.keys()
	_avanzar_dias_todos(1)
	dia_temporada += 1
	dia_absoluto += 1

	var novedades := []
	for id in lesionados_antes:
		if equipo_jugador.esta_lesionado(int(id)):
			continue
		for j in equipo_jugador.todos_los_jugadores():
			if int(j["id"]) == int(id):
				novedades.append("%s %s se recupero de su lesion." % [
					j["nombre"], j["apellido"]])
				break

	# La ronda de copa cae el miercoles: es el segundo partido de una
	# semana apretada, no un evento aparte del calendario.
	if dia_proxima_copa >= 0 and dia_temporada >= dia_proxima_copa:
		dia_proxima_copa = -1
		_jugar_ronda_de_copas()

	# La temporada cierra cuando no quedan fechas Y ya paso la semana de
	# la ultima: si cerrara en el pitazo final, el jugador no llegaria a
	# ver el ultimo resultado ni a cobrar los ultimos dias.
	if not hay_fecha_pendiente() and dia_temporada >= dia_proximo_partido:
		_cerrar_temporada()

	for i in range(noticias_antes, noticias.size()):
		novedades.append(str(noticias[i]))
	return novedades


## Avanza hasta el proximo partido, pero FRENA si pasa algo que merece una
## decision. Saltar a ciegas seria volver al problema de antes.
func avanzar_hasta_el_partido() -> Array:
	var todo := []
	while not hay_partido_hoy() and not juego_terminado:
		var dia := avanzar_un_dia()
		todo.append_array(dia)
		if not dia.is_empty():
			break
	return todo


func _avanzar_dias_todos(dias: int) -> void:
	for liga in piramide.divisiones:
		liga.avanzar_dias(dias)
	# §9.3: las negociaciones corren con el calendario. Acá se resuelven
	# las que esperaban respuesta del otro club y aparecen las ofertas
	# nuevas por jugadores nuestros.
	for oferta in Ofertas.avanzar(equipo_jugador, dias, piramide, rng, temporada_actual, division_jugador):
		if not oferta["log"].is_empty():
			_agregar_noticia("MERCADO: %s" % oferta["log"][-1])
	for nueva in Ofertas.generar_entrantes(equipo_jugador, piramide, rng, dias, division_jugador):
		_agregar_noticia("MERCADO: %s" % nueva["log"][-1])
	Ofertas.archivar(equipo_jugador)
	_procesar_retornos_de_medio_ano()


func _toca_ronda_de_copa() -> bool:
	if copa_nacional == null:
		return false
	if fecha_actual % FECHAS_ENTRE_RONDAS_COPA != 0:
		return false
	return _hay_copa_pendiente()


func _hay_copa_pendiente() -> bool:
	if copa_nacional != null and copa_nacional.campeon == null:
		return true
	for c in copas_division:
		if c.campeon == null:
			return true
	return false


## Una ronda por slot, alternando qué copa se juega: dos partidos entre
## semana además de la liga sería un calendario que no existe.
func _jugar_ronda_de_copas() -> void:
	var slot: int = int(fecha_actual / FECHAS_ENTRE_RONDAS_COPA)
	var toca_nacional: bool = slot % 2 == 1
	if toca_nacional and copa_nacional != null and copa_nacional.campeon == null:
		copa_nacional.jugar_siguiente_ronda(rng)
		if copa_nacional.campeon != null:
			_agregar_noticia("COPA NACIONAL: campeón %s" % copa_nacional.campeon.nombre)
		return
	for i in range(copas_division.size()):
		var c: Copa = copas_division[i]
		if c.campeon == null:
			c.jugar_siguiente_ronda(rng)
			if c.campeon != null:
				_agregar_noticia("COPA DIVISIÓN %d: campeón %s" % [i + 1, c.campeon.nombre])


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

	# Las copas vienen jugándose entre semana desde la primera fecha; si
	# quedó alguna ronda sin jugar (temporada corta, pocas fechas), se
	# termina acá para que siempre haya campeón.
	while _hay_copa_pendiente():
		_jugar_ronda_de_copas()
	var resultado_internacional := confederacion.jugar_temporada_internacional(rng)

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
	# El calendario arranca de nuevo: dia 0 de temporada, primera jornada
	# hoy. `dia_absoluto` NO se reinicia — es el que lleva la fecha real y
	# tiene que seguir corriendo de una temporada a la otra.
	dia_temporada = 0
	dia_proximo_partido = 0
	dia_proxima_copa = -1
	# Cuadros nuevos con los equipos YA movidos de división.
	_armar_copas()

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
	# Compra al contado, la misma operacion que hace la IA: cualquiera del
	# plantel o de la cantera del vendedor, de la division que sea.
	var resultado := Mercado.comprar_al_contado(equipo_jugador, vendedor, jugador_objetivo_id, rng)
	if resultado["exito"]:
		_agregar_noticia("FICHAJE: %s ficha a un %s de %s por %s" % [
			equipo_jugador.nombre, resultado["posicion"], vendedor.nombre,
			Economia.formato_dinero(resultado["precio"])
		])
	return resultado


## §9.3 rework: mandar una oferta ya no se resuelve en el acto. Queda
## abierta y el club se toma unos dias (ver core/ofertas.gd), asi que el
## mercado pasa a ser algo que hay que administrar: mandas tres y esperas.
func enviar_oferta(vendedor: Team, jugador_id: int, monto: float) -> Dictionary:
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
	var oferta := _oferta_por_id(oferta_id)
	if oferta.is_empty():
		return {"exito": false, "motivo": "Esa negociación ya no existe."}
	if str(oferta["estado"]) != Ofertas.PENDIENTE_NOSOTROS:
		return {"exito": false, "motivo": "No es tu turno en esa negociación."}

	match accion:
		"rechazar":
			Ofertas.rechazar(oferta)
			return {"exito": true, "oferta": oferta}
		"contraofertar":
			if not bool(oferta["entrante"]) and equipo_jugador.caja["fichajes"] < monto:
				return {"exito": false, "motivo": "No te alcanza el presupuesto de Fichajes."}
			Ofertas.contraofertar(oferta, monto, rng)
			return {"exito": true, "oferta": oferta}
		"aceptar":
			if bool(oferta["entrante"]):
				Ofertas.aceptar_entrante(oferta, rng)
				return {"exito": true, "oferta": oferta}
			if equipo_jugador.caja["fichajes"] < float(oferta["monto"]):
				return {"exito": false, "motivo": "No te alcanza el presupuesto de Fichajes."}
			oferta["estado"] = Ofertas.ACUERDO_CLUB
			oferta["log"].append("Aceptaste pagar %s." % Economia.formato_dinero(oferta["monto"]))
			return {"exito": true, "oferta": oferta}
	return {"exito": false, "motivo": "Acción desconocida."}


## Ultimo tramo de una oferta NUESTRA ya acordada con el club: el contrato
## con el jugador. La clausula es tuya: ponersela alta lo blinda contra
## que te lo saquen, pero a el lo encierra y lo cobra (ver
## Negociacion.PESO_CLAUSULA).
func cerrar_fichaje(oferta_id: int, sueldo: float, anios: int, clausula: float) -> Dictionary:
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

	var normal: float = maxf(1.0, ValorJugador.calcular(
		jugador, vendedor.animo.get(jugador_id, 50.0), 3) * Team.FACTOR_CLAUSULA)
	var detalle := Negociacion.interes_jugador(
		jugador, vendedor.animo.get(jugador_id, 50.0),
		float(vendedor.sueldos.get(jugador_id, 0.0)), sueldo,
		_division_de(vendedor), division_jugador, clausula / normal)
	if not detalle["acepta"]:
		return {"exito": false, "motivo": Negociacion.motivo_rechazo(detalle), "detalle": detalle}

	var r := Mercado.ejecutar_pase(
		equipo_jugador, vendedor, jugador_id, float(oferta["monto"]), sueldo, anios, rng)
	if not r["exito"]:
		return r
	equipo_jugador.clausulas[jugador_id] = clausula
	Investigadores.marcar_conocido(equipo_jugador, jugador_id)
	oferta["estado"] = Ofertas.CERRADA
	oferta["log"].append("Firmado: %d año(s) a %s, cláusula %s." % [
		anios, Economia.formato_dinero(sueldo), Economia.formato_dinero(clausula)])
	_agregar_noticia("FICHAJE: %s se lleva a un %s de %s por %s." % [
		equipo_jugador.nombre, r["posicion"], vendedor.nombre,
		Economia.formato_dinero(oferta["monto"])])
	return r


## §9.3 rework: pedir un jugador a PRESTAMO. A diferencia de una compra,
## no hay regateo por rondas: el dueño mira las condiciones (cuanto del
## sueldo le sacas de encima y, si hay opcion de compra, si el numero le
## cierra contra lo que CREE que va a valer) y contesta si o no. Despues
## falta que el jugador quiera venir.
##
## `duracion` es una clave de Prestamos.DURACIONES.
func pedir_prestamo(dueno: Team, jugador_id: int, duracion: String,
		porcentaje_sueldo: float, opcion_compra: float) -> Dictionary:
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
	var sueldo_actual: float = float(dueno.sueldos.get(jugador_id, 0.0))
	var div_origen := _division_de(dueno)
	var salto: int = division_jugador - div_origen
	var detalle := Negociacion.interes_jugador(
		jugador, dueno.animo.get(jugador_id, 50.0), sueldo_actual, sueldo_actual,
		div_origen, div_origen + int(round(salto / 2.0)))
	if not detalle["acepta"]:
		return {"exito": false, "motivo": Negociacion.motivo_rechazo(detalle), "detalle": detalle}

	var cierre := Prestamos.ceder(dueno, equipo_jugador, jugador_id,
		float(temporada_actual) + _fraccion_de_temporada(),
		temporadas, porcentaje_sueldo, opcion_compra)
	if not cierre["exito"]:
		return cierre
	Investigadores.marcar_conocido(equipo_jugador, jugador_id)
	_agregar_noticia("PRÉSTAMO: %s se lleva a un %s de %s por %s (fee %s)." % [
		equipo_jugador.nombre, jugador["posicion"], dueno.nombre,
		Prestamos.ETIQUETAS_DURACION.get(duracion, duracion),
		Economia.formato_dinero(cierre["fee"])])
	return cierre


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
func _division_de(club: Team) -> int:
	for d in range(piramide.divisiones.size()):
		if piramide.divisiones[d].equipos.has(club):
			return d
	return division_jugador


## Fuerza la venta pagando la cláusula de rescisión completa — sin la
## resistencia que puede rechazar una oferta común (Mercado.pagar_clausula).
func pagar_clausula(vendedor: Team, jugador_objetivo_id: int) -> Dictionary:
	var resultado := Mercado.comprar_al_contado(equipo_jugador, vendedor, jugador_objetivo_id, rng, true)
	if resultado["exito"]:
		_agregar_noticia("CLÁUSULA: %s paga la cláusula de un %s de %s por %s" % [
			equipo_jugador.nombre, resultado["posicion"], vendedor.nombre,
			Economia.formato_dinero(resultado["precio"])
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
	var resultado := Prestamos.ceder(equipo_jugador, club_destino, jugador_id, float(temporada_actual))
	if resultado["exito"]:
		_agregar_noticia("PRÉSTAMO: %s cede un %s a %s por esta temporada." % [
			equipo_jugador.nombre, resultado["jugador"]["posicion"], club_destino.nombre
		])
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
		# Las novedades se descartan a proposito: esto es el modo
		# "saltar la temporada", no se frena por nada.
		avanzar_un_dia()


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
		"noticias": noticias,
		"ultimo_informe_economico": ultimo_informe_economico,
		"ultima_posicion_final": ultima_posicion_final,
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
	restaurar_calendario(datos, liga_jugador().fixture.size())
	noticias = datos["noticias"]
	ultimo_informe_economico = datos["ultimo_informe_economico"]
	ultima_posicion_final = datos["ultima_posicion_final"]
	juego_terminado = datos.get("juego_terminado", false)
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
	if datos_nacional.is_empty() or datos_division.size() != piramide.divisiones.size():
		_armar_copas()
	else:
		copa_nacional = Copa.cargar(datos_nacional, piramide)
		copas_division = []
		for d in datos_division:
			copas_division.append(Copa.cargar(d, piramide))
	ultimo_resultado = datos.get("ultimo_resultado", {})
	ultimo_log = datos.get("ultimo_log", [])
	ultimos_eventos = datos.get("ultimos_eventos", [])
	ultimos_fotogramas = []

	return true


func borrar_partida() -> void:
	if hay_partida_guardada():
		DirAccess.remove_absolute(RUTA_PARTIDA)
