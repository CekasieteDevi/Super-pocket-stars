class_name Liga
extends RefCounted

## Fase 3 (GDD §10, §15 decisión 11): liga de 20 equipos, calendario ida y
## vuelta (sistema del círculo) y tabla de posiciones. Todavía sin
## ascensos/descensos ni las 10 divisiones — eso es §10 completo, fase 7.

var equipos: Array = []  # Team
var tabla: Dictionary = {}  # nombre_equipo -> fila de stats
var fixture: Array = []  # fechas -> [[idx_local, idx_visitante], ...]

## Fase 9: feed de noticias (fichajes, cantera). Sin nombres de jugador
## todavía (eso es contenido pendiente, Fix 10 del GDD) — se identifican
## por posición e id. Lesiones/resultados destacados quedan pendientes de
## conectar acá.
var noticias: Array = []
## En que escalon de la piramide esta esta liga (0 = primera). Lo necesita
## la economia: los ingresos escalan con la categoria (ver
## Economia.factor_division). -1 = liga suelta, sin escalon (tests).
var division: int = -1

## Agentes libres (§9.3 extendido): jugadores sin club, fichables sin fee de
## transferencia. Ver core/agentes_libres.gd.
##
## Dentro de una pirámide esta lista NO es propia: las diez divisiones
## apuntan a la misma (Piramide._compartir_pool), así que el que queda
## libre en primera lo ve también un club de décima. Una Liga suelta (los
## tests) usa la suya y no cambia nada.
var agentes_libres: Array = []

## Estadisticas individuales de la temporada (goleadores, asistencias,
## vallas invictas, tarjetas) de TODA la liga. Ver core/estadisticas_liga.gd.
var estadisticas: Dictionary = {}


## Guardado de partida — ver Team.guardar() para el detalle de por qué se
## puede guardar entero como JSON. fixture es una lista de [int,int]
## planos, JSON-safe tal cual; tabla ya está indexada por nombre (String),
## no necesita conversión de claves.
func guardar() -> Dictionary:
	var equipos_datos := []
	for e in equipos:
		equipos_datos.append(e.guardar())
	return {
		"equipos": equipos_datos, "tabla": tabla, "fixture": fixture,
		"noticias": noticias, "agentes_libres": agentes_libres,
		"estadisticas": estadisticas,
	}


static func cargar(datos: Dictionary) -> Liga:
	var l := Liga.new()
	for ed in datos["equipos"]:
		l.equipos.append(Team.cargar(ed))
	# JSON devuelve TODO numero como float, asi que una tabla cargada
	# traia los puntos como 42.0 y se mostraban asi. Son partidos, goles y
	# puntos: enteros. Se convierten aca, en la carga, y no al pintarlos —
	# si no, cada pantalla que muestre la tabla tiene que acordarse.
	l.tabla = {}
	for nombre in datos["tabla"]:
		var fila := {}
		for clave in datos["tabla"][nombre]:
			fila[clave] = int(datos["tabla"][nombre][clave])
		l.tabla[nombre] = fila
	l.fixture = datos["fixture"]
	l.noticias = datos.get("noticias", [])
	l.agentes_libres = datos.get("agentes_libres", [])
	l.estadisticas = EstadisticasLiga.cargar(datos.get("estadisticas", {}))
	return l


## Sistema del círculo: fija el equipo 0 y rota el resto. Da n-1 fechas donde
## cada equipo juega una vez contra todos, sin repetir rival — la base que
## reutiliza FaseLiga (Fase 7) para las copas internacionales, que solo
## necesitan las primeras N fechas de esto en vez de todas las n-1.
static func generar_fixture_simple(n: int) -> Array:
	var arr := []
	for i in range(n):
		arr.append(i)

	var n_rounds := n - 1
	var mitad := n / 2
	var ida := []

	for r in range(n_rounds):
		var ronda := []
		for i in range(mitad):
			var home: int = arr[i]
			var away: int = arr[n - 1 - i]
			if i == 0 and r % 2 == 1:
				var tmp := home
				home = away
				away = tmp
			ronda.append([home, away])
		ida.append(ronda)

		var last: int = arr[n - 1]
		for i in range(n - 1, 1, -1):
			arr[i] = arr[i - 1]
		arr[1] = last

	return ida


## Da la ida y la vuelta completas (2*(n-1) fechas, cada equipo juega dos
## veces contra todos). Lo que usa la liga de 20 equipos de cada división.
static func generar_fixture_ida_vuelta(n: int) -> Array:
	var ida := generar_fixture_simple(n)
	var vuelta := []
	for ronda in ida:
		var ronda_vuelta := []
		for partido in ronda:
			ronda_vuelta.append([partido[1], partido[0]])
		vuelta.append(ronda_vuelta)

	return ida + vuelta


## id_inicial: mismo motivo que Team.generar — si esta Liga es una división
## de una Piramide (Fase 7), cada división necesita su propio rango de ids
## para que un ascenso/descenso no pise jugadores de otra división.
## division: 0 = primera. Decide con qué nivel nacen los planteles (ver
## NivelDivision). -1 = sin gradiente, planteles al azar como antes —
## lo usan los tests que arman una liga suelta y no les importa el nivel.
func inicializar(nombres_equipos: Array, rng: RandomNumberGenerator, id_inicial: int = 0, division: int = -1) -> void:
	equipos.clear()
	tabla.clear()
	self.division = division
	var potencial := NivelDivision.potencial(division) if division >= 0 else -1
	var realizacion := NivelDivision.realizacion(division) if division >= 0 else PlayerGenerator.REALIZACION_TITULAR
	var siguiente_id := id_inicial
	for nombre in nombres_equipos:
		var equipo := Team.generar(nombre, rng, siguiente_id, potencial, "Uruguay", realizacion)
		# §8.4#28: el club tiene que saber en que categoria juega, si no un
		# cruce de copa no puede saber que esta cruzando divisiones.
		equipo.division_actual = division
		equipo.fans = Fans.inicial(division)
		siguiente_id += Team.RANGO_IDS_RESERVADO
		equipos.append(equipo)
		tabla[nombre] = _fila_vacia()
	fixture = generar_fixture_ida_vuelta(equipos.size())


func _fila_vacia() -> Dictionary:
	return {"pj": 0, "pg": 0, "pe": 0, "pp": 0, "gf": 0, "gc": 0, "dg": 0, "pts": 0}


## Simula todas las fechas del fixture de una. Para jugar de a una fecha
## (como hace la UI) usar jugar_fecha().
func jugar_temporada(rng: RandomNumberGenerator, con_log: bool = false) -> Array:
	var resumen := []
	for idx in range(fixture.size()):
		var r := jugar_fecha(idx, rng)
		if con_log:
			resumen.append(r["resultados_texto"])
	return resumen


## §14: mínimo de titulares+banco sanos para poder presentarte a jugar.
## Un plantel arranca con 18 (once + banco) y puede llegar a 40
## (Team.PLANTEL_MAXIMO), así que el mínimo tiene que ser MENOR a 18 — si
## fuera igual, una sola lesión (algo que pasa todo el tiempo en una
## temporada de 38 fechas) te dejaría corto automáticamente. 15 deja
## margen para hasta 3 lesionados simultáneos con el plantel más chico
## posible, sin volver el chequeo inútil.
const MINIMO_DISPONIBLES := 15
## No presentarte no lleva multa: el castigo es perder 0-3, y con eso
## alcanza. La multa salía del presupuesto de Mantenimiento, que era la
## única razón por la que esa categoría existía; al sacarla, la categoría
## se fue con ella (ver Economia.CATEGORIAS_CAJA).


## Simula una sola fecha (todos sus partidos) y actualiza la tabla.
## Si se pasa equipo_seguido, además devuelve el resultado y el log
## detallado de su partido para mostrarlo en la UI.
func jugar_fecha(idx: int, rng: RandomNumberGenerator, equipo_seguido: Team = null) -> Dictionary:
	# §8.4#27: quien se esta jugando algo de verdad en esta fecha. Se
	# recalcula para los veinte antes de jugar, como objetivo_en_riesgo.
	Motivacion.marcar_recta_final(self, idx)
	var fecha: Array = fixture[idx]
	var resultados_texto := []
	# Los que se rompen en esta fecha, para el feed de noticias. Se
	# detectan comparando antes/despues de cada partido y no dentro del
	# motor porque los dos motores lesionan por caminos distintos y este
	# es el unico lugar por el que pasan los dos.
	var lesionados := []
	var resultado_seguido = null
	var log_seguido := []
	var eventos_seguido := []
	var fotogramas_seguido := []

	for partido in fecha:
		var home: Team = equipos[partido[0]]
		var away: Team = equipos[partido[1]]
		# Nadie sale a la cancha lesionado ni suspendido. A los clubes de
		# la IA se les arregla el once solo: no hay quien lo revise, y sin
		# esto serian los unicos que juegan con gente que no puede jugar.
		# Al club del jugador se le avisa antes, en la pantalla, para que
		# elija el reemplazo — cuando llega aca ya viene arreglado, y esto
		# queda de red por si acaso.
		Alineacion.arreglar(home)
		Alineacion.arreglar(away)
		var con_log: bool = equipo_seguido != null and (home == equipo_seguido or away == equipo_seguido)

		# §14 + §17: antes de dar por perdido el partido, el club echa mano
		# de la cantera. Recién si ni con los juveniles llega al mínimo
		# pierde 0-3. Los convocados vuelven solos a la reserva cuando el
		# plantel se recupera, así que esto corre todas las fechas.
		_convocar_emergencia(home)
		_convocar_emergencia(away)

		var home_corto: bool = home.jugadores_sanos_count() < MINIMO_DISPONIBLES
		var away_corto: bool = away.jugadores_sanos_count() < MINIMO_DISPONIBLES
		# Snapshot ANTES del partido: las suspensiones que ya tenía cada
		# equipo se sirven (descuentan) por este partido que se está por
		# jugar. Una tarjeta roja del PROPIO partido (si hay) se agrega
		# recién durante MatchEngine.simular(), así que queda afuera de este
		# snapshot y no se descuenta hasta la fecha siguiente — si no, una
		# expulsión de hoy se perdonaría sola en el mismo cierre.
		var suspendidos_previos_home: Array = home.suspendidos.keys().duplicate()
		var suspendidos_previos_away: Array = away.suspendidos.keys().duplicate()
		var lesionados_previos := {
			home: home.lesiones.keys().duplicate(),
			away: away.lesiones.keys().duplicate(),
		}

		var r: Dictionary
		if home_corto or away_corto:
			r = _resolver_forfeit(home, away, home_corto, away_corto)
		elif con_log:
			# El partido del jugador se simula con el motor espacial
			# (coordenadas reales, 22 jugadores, utility AI). Los demás
			# siguen con el motor abstracto, que es más rápido y alcanza:
			# la profundidad asimétrica es deliberada, ver
			# docs/motor_espacial.md.
			r = MotorEspacial.simular(home, away, rng, true)
		else:
			r = MatchEngine.simular(home, away, rng, false)

		_servir_suspensiones(home, suspendidos_previos_home)
		_servir_suspensiones(away, suspendidos_previos_away)

		for eq in lesionados_previos:
			lesionados.append_array(_lesionados_nuevos(eq, lesionados_previos[eq]))
		# Un partido cancelado por falta de jugadores no dejaba ningun
		# rastro en la liga: se otorgaba el 3-0 y el usuario no se
		# enteraba de por que su rival tenia tres goles de la nada.
		if bool(r.get("cancelado", false)):
			var castigado: String = home.nombre if int(r["goles_local"]) == 0 else away.nombre
			noticias.append("%s se quedo sin jugadores en cancha: pierde 0-3 y el partido se cancela." % castigado)
		_actualizar_tabla(home.nombre, away.nombre, r["goles_local"], r["goles_visitante"])
		EstadisticasLiga.registrar_partido(estadisticas, home, away, r)
		_actualizar_estado_jugadores(home, away, r)
		resultados_texto.append("%s %d-%d %s" % [home.nombre, r["goles_local"], r["goles_visitante"], away.nombre])
		if con_log:
			resultado_seguido = {"local": home.nombre, "visitante": away.nombre,
				"gl": r["goles_local"], "gv": r["goles_visitante"],
				# Quien los hizo: lo usa el resumen de fin de partido, y
				# era el unico dato del partido que no llegaba a la UI.
				"goles_log": r.get("goles_log", [])}
			log_seguido = r["log"]
			eventos_seguido = r["eventos"]
			fotogramas_seguido = r.get("fotogramas", [])

	return {
		"resultados_texto": resultados_texto, "resultado_seguido": resultado_seguido,
		"log_seguido": log_seguido, "eventos_seguido": eventos_seguido,
		"fotogramas_seguido": fotogramas_seguido,
		"lesionados": lesionados,
	}


## Los que se lesionaron en el partido que acaba de terminar: los que
## estan en la lista de lesionados y no estaban antes de jugar.
func _lesionados_nuevos(equipo: Team, previos: Array) -> Array:
	var salida := []
	for id in equipo.lesiones:
		if previos.has(id):
			continue
		var j := _buscar_en_plantel(equipo, int(id))
		if j.is_empty():
			continue
		var les: Dictionary = equipo.lesiones[id]
		salida.append({
			"jugador": j, "club": equipo.nombre,
			"tipo": str(les["tipo"]), "dias": int(les["dias_restantes"]),
		})
	return salida


func _convocar_emergencia(equipo: Team) -> void:
	var r := equipo.ajustar_convocatorias_de_emergencia(MINIMO_DISPONIBLES)
	if r["subidos"].is_empty():
		return
	var nombres := []
	for j in r["subidos"]:
		nombres.append("%s (%s, %d años)" % [j["nombre"], j["posicion"], int(j["edad"])])
	noticias.append("%s no llega a %d disponibles y sube de la cantera a %s." % [
		equipo.nombre, MINIMO_DISPONIBLES, ", ".join(nombres)])


## §14: "si no llegás a MINIMO_DISPONIBLES, perdés el partido por no
## presentarte" — 0-3 en contra. Devuelve el mismo formato que
## MatchEngine.simular() para que el resto de jugar_fecha() no note la
## diferencia. Si a los DOS equipos les falta gente a la vez (rarísimo),
## se resuelve como empate administrativo 0-0 para ambos, para
## no romper la simetría de goles a favor/en contra de la tabla.
func _resolver_forfeit(home: Team, away: Team, home_corto: bool, away_corto: bool) -> Dictionary:
	# expulsados_partido dura SOLO el partido en curso y lo limpia
	# reset_partido(), que corre dentro de simular(). Un forfeit no simula
	# nada, asi que sin esto los expulsados del ultimo partido jugado
	# quedaban marcados para siempre: la suspension se servia igual (ver
	# _servir_suspensiones mas abajo) pero puede_jugar() los seguia
	# contando como no disponibles, y el equipo arrastraba un jugador
	# menos en el conteo por el resto de la partida.
	home.expulsados_partido.clear()
	away.expulsados_partido.clear()
	var gl := 0
	var gv := 0
	if home_corto and not away_corto:
		gv = 3
		noticias.append("%s no pudo presentar %d jugadores disponibles: pierde 0-3." % [home.nombre, MINIMO_DISPONIBLES])
	elif away_corto and not home_corto:
		gl = 3
		noticias.append("%s no pudo presentar %d jugadores disponibles: pierde 0-3." % [away.nombre, MINIMO_DISPONIBLES])
	else:
		noticias.append("%s y %s no pudieron presentar %d disponibles cada uno: empate administrativo." % [home.nombre, away.nombre, MINIMO_DISPONIBLES])
	# `forfeit` lo mira EstadisticasLiga: un 0-3 administrativo no le da
	# la valla invicta a un arquero que no jugo.
	return {"goles_local": gl, "goles_visitante": gv, "log": [], "goles_log": [],
		"eventos": [], "forfeit": true}


## Fase 5: §3 (ánimo según el resultado) y la fatiga acumulada que arranca
## el próximo partido (§7.4 punto 7).
func _actualizar_estado_jugadores(home: Team, away: Team, r: Dictionary) -> void:
	var goleadores_local := []
	var goleadores_visitante := []
	for gol in r["goles_log"]:
		if gol["equipo"] == home.nombre:
			goleadores_local.append(gol["jugador_id"])
		else:
			goleadores_visitante.append(gol["jugador_id"])
	home.actualizar_post_partido(r["goles_local"], r["goles_visitante"], goleadores_local)
	away.actualizar_post_partido(r["goles_visitante"], r["goles_local"], goleadores_visitante)
	Fans.actualizar_por_resultado(home, r["goles_local"], r["goles_visitante"])
	Fans.actualizar_por_resultado(away, r["goles_visitante"], r["goles_local"])
	_actualizar_rachas_titular_banco(home)
	_actualizar_rachas_titular_banco(away)
	# §7.4.5: la tactica se asimila JUGANDOLA. Va aca y no en el motor
	# porque tiene que correr una sola vez por partido, y el motor
	# espacial y el abstracto entran los dos por este mismo camino.
	Familiaridad.despues_de_partido(home)
	Familiaridad.despues_de_partido(away)
	# §7.4.6: la quimica se hace jugando juntos, asi que se cuenta el once.
	Quimica.despues_de_partido(home)
	Quimica.despues_de_partido(away)
	# §7.3: el uso del partido se acumula en el jugador y lo consume
	# Progresion al cerrar la temporada. Los dos motores entregan el mismo
	# shape, así que esto no sabe cuál se usó — y no tiene por qué.
	var xp: Dictionary = r.get("xp", {})
	_acumular_xp(home, xp.get("home", {}))
	_acumular_xp(away, xp.get("away", {}))
	# §7.1: lo que HIZO en la cancha (goles, asistencias, goles recibidos)
	# también lo consume Progresion. Sale de goles_log y del marcador, que
	# los dos motores entregan igual: el club del usuario no crece a otro
	# ritmo por jugar con el motor espacial.
	_acumular_rendimiento(home, xp.get("home", {}), r, true)
	_acumular_rendimiento(away, xp.get("away", {}), r, false)
	# Lo que hace el cedido en el club que lo pidio, para poder contarselo
	# al dueño cuando vuelve (ver Prestamos.procesar_retornos). Los goles
	# ya los cuenta EstadisticasLiga, pero por LIGA: el prestado juega en
	# otra division y su linea vive en otra tabla que el dueño no mira.
	_contar_prestamo(home, r.get("goles_log", []))
	_contar_prestamo(away, r.get("goles_log", []))


static func _contar_prestamo(equipo: Team, goles_log: Array) -> void:
	if equipo.prestados_propios.is_empty():
		return
	for j in equipo.jugadores:
		if equipo.prestados_propios.has(int(j["id"])):
			j["partidos_prestamo"] = int(j.get("partidos_prestamo", 0)) + 1
	for gol in goles_log:
		if str(gol.get("equipo", "")) != equipo.nombre:
			continue
		var id := int(gol.get("jugador_id", -1))
		if not equipo.prestados_propios.has(id):
			continue
		for j in equipo.todos_los_jugadores():
			if int(j["id"]) == id:
				j["goles_prestamo"] = int(j.get("goles_prestamo", 0)) + 1
				break


static func _acumular_xp(equipo: Team, por_jugador: Dictionary) -> void:
	if por_jugador.is_empty():
		return
	for j in equipo.todos_los_jugadores():
		var d = por_jugador.get(j["id"], null)
		if d == null:
			continue
		var acum: Dictionary = j.get("xp_uso", {})
		for a in d:
			acum[a] = float(acum.get(a, 0.0)) + float(d[a])
		j["xp_uso"] = acum


## Los minutos salen del XP del partido: los dos motores reparten
## `minutos/90` por jugador, así que la suma ya es la fracción jugada. Los
## goles del marcador se reparten por esa fracción porque el motor
## abstracto no sabe quién estaba en la cancha en cada gol.
static func _acumular_rendimiento(equipo: Team, xp_equipo: Dictionary, r: Dictionary, es_local: bool) -> void:
	if xp_equipo.is_empty():
		return
	var a_favor := float(r["goles_local"] if es_local else r["goles_visitante"])
	var en_contra := float(r["goles_visitante"] if es_local else r["goles_local"])
	var goles := {}
	var asistencias := {}
	for gol in r.get("goles_log", []):
		if str(gol.get("equipo", "")) != equipo.nombre:
			continue
		var g := int(gol.get("jugador_id", -1))
		goles[g] = int(goles.get(g, 0)) + 1
		var a := int(gol.get("asistencia_id", -1))
		asistencias[a] = int(asistencias.get(a, 0)) + 1
	for j in equipo.todos_los_jugadores():
		var id := int(j["id"])
		var d = xp_equipo.get(id, null)
		if d == null:
			continue
		var fraccion := 0.0
		for attr in d:
			fraccion += maxf(float(d[attr]), 0.0)
		if fraccion <= 0.0:
			continue
		var rend: Dictionary = j.get("rendimiento", {})
		rend["partidos"] = float(rend.get("partidos", 0.0)) + fraccion
		rend["goles"] = float(rend.get("goles", 0.0)) + float(goles.get(id, 0))
		rend["asistencias"] = float(rend.get("asistencias", 0.0)) + float(asistencias.get(id, 0))
		rend["a_favor"] = float(rend.get("a_favor", 0.0)) + a_favor * fraccion
		rend["en_contra"] = float(rend.get("en_contra", 0.0)) + en_contra * fraccion
		j["rendimiento"] = rend


## §6: racha de partidos SEGUIDOS de titular (Comodón, ver Progresion.
## aplicar_temporada) y de banco (Rencoroso, dispara UNA vez al cruzar el
## umbral — ver Personalidad.cruza_umbral_rencoroso). Jugar de titular
## corta cualquier racha de banco y viceversa; la cantera no cuenta para
## ninguna de las dos (no es parte del plantel de partido).
func _actualizar_rachas_titular_banco(equipo: Team) -> void:
	for j in equipo.jugadores:
		j["partidos_seguidos_titular"] = int(j.get("partidos_seguidos_titular", 0)) + 1
		j["partidos_seguidos_banco"] = 0
	# Las reservas cuentan igual que el banco: estan todavia mas lejos de
	# jugar, asi que el que se amarga por no jugar se amarga tambien ahi.
	for j in equipo.banco + equipo.reservas:
		j["partidos_seguidos_titular"] = 0
		j["partidos_seguidos_banco"] = int(j.get("partidos_seguidos_banco", 0)) + 1
		if Personalidad.cruza_umbral_rencoroso(j):
			var id: int = j["id"]
			equipo.animo[id] = clamp(equipo.animo.get(id, 50.0) - Personalidad.MALUS_RENCOROSO, 0.0, 100.0)
			noticias.append("%s: un %s lleva %d partidos seguidos en el banco y esta descontento, pide salir." % [
				equipo.nombre, j["posicion"], Personalidad.UMBRAL_RENCOROSO
			])


## Entre fecha y fecha: recupera fatiga, hace derivar el ánimo y cuenta los
## días de lesión de los 20 equipos. dias=7 asume calendario semanal.
func avanzar_dias(dias: int = 7) -> void:
	for equipo in equipos:
		equipo.avanzar_dias(dias)


## Procesa la economía de cada club con la tabla recién jugada (§9.1), corre
## una ventana de mercado (§9.3) y envejece/entrena a todos los jugadores
## (§7.1). No toca fixture/tabla — eso es iniciar_temporada(), separado para
## que Piramide (Fase 7) pueda mover equipos de división entre una cosa y
## la otra (ascensos/descensos se deciden con la tabla vieja, pero el
## fixture nuevo tiene que armarse con la composición de equipos ya nueva).
func procesar_economia_y_mercado_y_progresion(rng: RandomNumberGenerator, equipo_protegido: Team = null, temporada_actual: int = 0) -> Array:
	var orden_final := tabla_ordenada()
	var informes_economia := []
	for i in range(orden_final.size()):
		var nombre: String = orden_final[i]
		for equipo in equipos:
			if equipo.nombre == nombre:
				var informe := Economia.procesar_temporada(equipo, i + 1, orden_final.size(), division)
				# El campeon de la division: el titulo pesa aparte de la
				# tabla. Las copas las suma GameState, que es el unico que
				# sabe quien las gano (ver Reputacion.por_titulo).
				if i == 0:
					Reputacion.sumar(equipo, Reputacion.por_titulo("Liga"))
				informe["equipo"] = nombre
				informes_economia.append(informe)

				# Un club en quiebra no se queda ahí para siempre — si es de
				# la IA, se liquida solo (Economia.procesar_quiebra). Al
				# equipo del jugador humano no se le vende nada sin que él
				# lo decida (mismo criterio que mercado/cantera), pero se le
				# avisa fuerte: la decisión de a quién vender es suya.
				#
				# La noticia de "entró en quiebra" es aparte de la de
				# "vende de urgencia" (más abajo) — es puro color/chusmerío
				# para que se note el momento exacto en que un club cae,
				# no solo que después vendió a alguien.
				if equipo.quebrado:
					noticias.append("QUIEBRA: %s entró en números rojos." % equipo.nombre)

				if equipo == equipo_protegido:
					if equipo.quebrado:
						noticias.append("QUIEBRA: %s está en números rojos. Vendé jugadores vos mismo (Mercado/cláusulas) antes de que sea peor." % equipo.nombre)
				else:
					var ventas := Economia.procesar_quiebra(equipo, rng)
					for v in ventas:
						noticias.append("QUIEBRA: %s vende de urgencia a un %s por %s para pagar deudas." % [equipo.nombre, v["posicion"], Economia.formato_dinero(v["ingreso"])])
				break

	var transferencias := Mercado.ejecutar_ventana(self, rng, equipo_protegido)
	for t in transferencias:
		var quien: Dictionary = t.get("jugador", {})
		var como := "%s %s" % [quien.get("nombre", ""), quien.get("apellido", "")]
		noticias.append(Noticias.crear(
			"FICHAJES: %s (%s) pasa de %s a %s por %s." % [
				como.strip_edges(), t["posicion"], t["de"], t["a"],
				Economia.formato_dinero(t["valor"])],
			"fichajes", [Noticias.mencion(quien, str(t["a"]))]))

	var reporte_cantera := []
	for equipo in equipos:
		# float: los prestamos de medio año vencen a mitad de temporada
		# (ver Prestamos.procesar_retornos). Al cierre ya vencio todo lo
		# que tenia que vencer este año.
		# El equipo protegido decide sus opciones de compra a mano
		# (GameState.ejercer_opcion_de_compra): la IA no las ejerce por el.
		var vueltos := Prestamos.procesar_retornos(equipo, float(temporada_actual), equipo_protegido)
		for r in vueltos:
			# El club del jugador humano se entera de COMO le fue al
			# cedido; de los ajenos alcanza con que vuelva.
			if equipo == equipo_protegido:
				noticias.append(Noticias.crear(Prestamos.texto_retorno(r), "fichajes",
					[Noticias.mencion(r["jugador"], equipo.nombre)]))
			else:
				noticias.append("PRÉSTAMOS: %s vuelve a %s tras el préstamo." % [
					r["jugador"]["posicion"], equipo.nombre])

		_avanzar_contratos(equipo, rng, equipo == equipo_protegido)
		var bonus_mentor := Mentores.mejor_bonus_disponible(equipo)

		# §7.4.1: la carga de entrenamiento de la temporada, promediada
		# semana a semana, entra acá junto con las instalaciones.
		var mult_entrenamiento: float = Instalaciones.factor_entrenamiento(equipo) * equipo.factor_carga_temporada()
		# §7.4.2: que practico el plantel entero esta temporada.
		var mult_area := FocoEquipo.multiplicadores(
			equipo.reparto_foco(), PlayerGenerator.get_all_attributes())

		for jugador in equipo.todos_los_jugadores():
			Aprendizaje.actualizar_racha(jugador)
			Progresion.aplicar_temporada(jugador, rng, Mentores.multiplicador_para(jugador, bonus_mentor), mult_entrenamiento, mult_area)
			var aprendida := Aprendizaje.procesar_jugador(jugador, equipo, temporada_actual, rng)
			if not aprendida.is_empty():
				noticias.append("APRENDIZAJE: un %s de %s aprende %s (bronce)." % [jugador["posicion"], equipo.nombre, aprendida["nombre"]])
		# §7.4.1: la carga acumulada ya se consumió en mult_entrenamiento.
		equipo.reiniciar_carga()

		var reporte := _procesar_cantera(equipo, rng, equipo == equipo_protegido, bonus_mentor, temporada_actual)
		reporte_cantera.append(reporte)
		for r in reporte["promovidos"]:
			noticias.append("CANTERA: %s hace debutar a un canterano en %s (banco)" % [equipo.nombre, r["promovido"]["posicion"]])
		for r in reporte["promovidos_a_titular"]:
			noticias.append("PLANTEL: %s sube a un suplente a titular en %s" % [equipo.nombre, r["entra"]["posicion"]])
		if not reporte["liberados"].is_empty():
			noticias.append("CANTERA: %s deja libres a %d juveniles que no debutaron a tiempo" % [equipo.nombre, reporte["liberados"].size()])
		for a in reporte["aprendizajes"]:
			noticias.append("APRENDIZAJE: un juvenil (%s) de %s aprende %s (bronce)." % [a["jugador"]["posicion"], equipo.nombre, a["habilidad"]["nombre"]])
		equipo.recalcular_capitan()
		# Recien ahora: ya vencieron los contratos, ya entraron los
		# reemplazos y ya subieron los canteranos. Esta es la caja con la
		# que el club arranca de verdad, y el cero contra el que la UI
		# mide lo que el jugador gasta (ver Economia.fotografiar_caja).
		Economia.fotografiar_caja(equipo)

	return [informes_economia, transferencias, reporte_cantera]


## §17: envejece a los juveniles (crecen igual que cualquiera, §7.1),
## libera a los que llegaron a los 20 sin debutar, y genera la camada
## nueva. Para los equipos de la IA, además deja que se promuevan solos
## (cantera->banco y banco->titular) — para el equipo del jugador humano
## (es_protegido) esas dos decisiones quedan para que las tome desde la UI,
## igual que el mercado no lo toca a él.
func _procesar_cantera(equipo: Team, rng: RandomNumberGenerator, es_protegido: bool = false,
		bonus_mentor: float = 0.0, temporada_actual: int = 0) -> Dictionary:
	var mult_entrenamiento := Instalaciones.factor_entrenamiento(equipo)
	var aprendizajes := []
	for juvenil in equipo.cantera:
		Aprendizaje.actualizar_racha(juvenil)
		Progresion.aplicar_temporada(juvenil, rng, Mentores.multiplicador_para(juvenil, bonus_mentor), mult_entrenamiento,
			FocoEquipo.multiplicadores(equipo.reparto_foco(), PlayerGenerator.get_all_attributes()), true)
		var aprendida := Aprendizaje.procesar_jugador(juvenil, equipo, temporada_actual, rng)
		if not aprendida.is_empty():
			aprendizajes.append({"jugador": juvenil, "habilidad": aprendida})
	var liberados := equipo.liberar_veteranos_de_cantera()
	# La cantera de un club de decima no produce los mismos juveniles que
	# la de uno de primera (ver Team.nivel_potencial).
	var nuevos := equipo.generar_camada(rng, Instalaciones.cantidad_camada(equipo),
		equipo.nivel_potencial() + Instalaciones.bonus_potencial_juveniles(equipo))
	var promovidos := []
	var promovidos_a_titular := []
	if not es_protegido:
		# §8.6.4: un DT Cantera promueve con mucha menos exigencia, uno
		# Chequera casi no lo hace (prefiere resolverlo en el mercado).
		var umbral := 3.0 * DT.factor_umbral_cantera(equipo)
		promovidos = equipo.promover_automatico(umbral)
		promovidos_a_titular = equipo.promover_banco_automatico(umbral)
	return {
		"equipo": equipo.nombre, "liberados": liberados, "nuevos": nuevos,
		"promovidos": promovidos, "promovidos_a_titular": promovidos_a_titular,
		"aprendizajes": aprendizajes,
	}


## Resetea la tabla y arma el fixture para self.equipos tal como estén en
## este momento (después de que Piramide, si corresponde, ya movió a los
## ascendidos/descendidos).
func iniciar_temporada() -> void:
	tabla.clear()
	# Las individuales son DE LA TEMPORADA, igual que la tabla: arrancan
	# de cero con el fixture nuevo.
	estadisticas.clear()
	for equipo in equipos:
		tabla[equipo.nombre] = _fila_vacia()
	fixture = generar_fixture_ida_vuelta(equipos.size())


## Fin de temporada para una liga suelta (sin pirámide de divisiones): todo
## el procesamiento de una y el fixture nuevo, de un saque.
func nueva_temporada(rng: RandomNumberGenerator, equipo_protegido: Team = null, temporada_actual: int = 0) -> Array:
	var resultado := procesar_economia_y_mercado_y_progresion(rng, equipo_protegido, temporada_actual)
	iniciar_temporada()
	return resultado


## §9.3: si el contrato llega a 0, el club de la IA decide si renueva o deja
## salir al jugador libre (más probable cuanto más veterano) — si lo deja
## salir, se va al pool de agentes libres (ver AgentesLibres.liberar) y su
## puesto lo ocupa un refuerzo nuevo.
##
## Al club del jugador humano le pasa lo MISMO. Antes se le renovaba todo
## solo, porque no había pantalla para decidirlo: el sueldo se recalculaba
## al valor de hoy y la masa salarial subía sola todas las temporadas
## contra un ingreso que tiene techo. Ahora la pantalla existe (Club ›
## Renovaciones, ver core/renovaciones.gd) y el que no arregló se va,
## igual que en cualquier club.
## Una linea del cartel de vencimientos. Se guardan nombres y numeros ya
## resueltos y no los jugadores enteros: esto va a la partida guardada y
## un plantel duplicado adentro del club no se puede volver a leer.
func _anotar_vencimiento(equipo: Team, sale: Dictionary, salida: Dictionary,
		sale_sueldo: float) -> Dictionary:
	var entra: Dictionary = salida.get("jugador", {})
	# Sin cantera no entra nadie: el puesto queda vacante y lo resuelve el
	# jugador (ver AgentesLibres._dejar_hueco). El aviso lo dice asi.
	var id_entra: int = int(entra["id"]) if not entra.is_empty() else -1
	var sube: Dictionary = salida.get("sube", {})
	return {
		"hueco": bool(salida.get("hueco", false)),
		"tapa_banco": ("%s %s" % [
			sube.get("nombre", ""), sube.get("apellido", "")]).strip_edges(),
		"tapa_banco_puesto": str(sube.get("posicion", "")),
		"sale": ("%s %s" % [sale.get("nombre", ""), sale.get("apellido", "")]).strip_edges(),
		"sale_puesto": str(sale["posicion"]),
		"sale_edad": int(sale.get("edad", 0)),
		"sale_media": int(sale.get("media", 0)),
		"sale_sueldo": sale_sueldo,
		"entra": ("%s %s" % [entra.get("nombre", ""), entra.get("apellido", "")]).strip_edges(),
		"entra_puesto": str(entra.get("posicion", "")),
		"entra_edad": int(entra.get("edad", 0)),
		"entra_media": int(entra.get("media", 0)),
		"entra_sueldo": float(equipo.sueldos.get(id_entra, 0.0)),
		"entra_anios": int(equipo.contratos.get(id_entra, 0)),
		"de_cantera": bool(salida.get("de_cantera", false)),
	}


func _avanzar_contratos(equipo: Team, rng: RandomNumberGenerator, es_protegido: bool = false) -> void:
	for id in equipo.contratos.keys().duplicate():
		equipo.contratos[id] -= 1
		if equipo.contratos[id] > 0:
			continue

		var jugador := _buscar_en_plantel(equipo, id)

		if es_protegido:
			if jugador.is_empty():
				_renovar_contrato(equipo, id, jugador, rng)
				continue
			# El piso: un equipo que no llega a MINIMO_EN_CANCHA no puede
			# jugar (ver MatchEngine), y el plantel se achica de verdad
			# cuando no hay ni cantera ni banco para tapar el puesto. Ahi
			# el club renueva a la fuerza: quedarse sin equipo no es una
			# decision que el juego pueda dejar tomar.
			var sin_relevo: bool = equipo.cantera.is_empty() and equipo.banco.is_empty()
			if sin_relevo and equipo.jugadores.size() <= MatchEngine.MINIMO_EN_CANCHA:
				_renovar_contrato(equipo, id, jugador, rng)
				noticias.append("CONTRATOS: %s no tiene con quien reemplazarlo y le renueva a la fuerza a un %s. Sin el, el equipo no llega a los %d para jugar." % [
					equipo.nombre, jugador["posicion"], MatchEngine.MINIMO_EN_CANCHA])
				continue

			# El sueldo del que se va se lee ACA: liberar lo da de baja
			# (Team._limpiar_registro) y despues ya no esta.
			var sueldo_saliente: float = float(
				equipo.sueldos.get(int(jugador["id"]), 0.0))
			# El club del jugador tapa el hueco con su propia cantera y
			# no con un fichaje que no pidio: ver
			# AgentesLibres._reemplazo_para.
			var salida := AgentesLibres.liberar(
				equipo, jugador, agentes_libres, rng, true)
			# String plano y no Noticias.crear: las noticias de contratos
			# de esta funcion son todas strings y el array se lee mezclado.
			noticias.append("CONTRATOS: se te fue libre un %s de %s. No le renovaste a tiempo (Club › Renovaciones)." % [jugador["posicion"], equipo.nombre])
			if bool(salida.get("de_cantera", false)):
				noticias.append("CANTERA: sube un juvenil (%s) a tapar ese puesto." % str(salida["jugador"]["posicion"]))
			else:
				noticias.append("PLANTEL: no quedaban juveniles en la cantera y el puesto de %s quedo sin cubrir. Resolvelo en Mercado o subiendo un juvenil." % jugador["posicion"])
			# Para el cartel que el jugador lee al empezar la temporada:
			# su plantel cambio sin que el decidiera nada, asi que tiene
			# que enterarse de quien se fue y quien lo tapa.
			equipo.vencimientos_del_cierre.append(
				_anotar_vencimiento(equipo, jugador, salida, sueldo_saliente))
			continue

		if jugador.is_empty():
			_renovar_contrato(equipo, id, jugador, rng)
			continue

		var edad: int = jugador.get("edad", 25)
		var probabilidad_irse: float = clamp(0.10 + max(0, edad - 27) * 0.03, 0.10, 0.55)
		if rng.randf() >= probabilidad_irse:
			_renovar_contrato(equipo, id, jugador, rng)
			continue

		var salida_ia := AgentesLibres.liberar(equipo, jugador, agentes_libres, rng)
		noticias.append("AGENTES LIBRES: un %s queda libre, se va de %s." % [jugador["posicion"], equipo.nombre])
		# El club de la IA tapa el puesto con el pool si encuentra a
		# alguien que pueda pagar (ver AgentesLibres.fichar_ia). Se avisa
		# porque es la señal de que el mercado de libres se mueve solo.
		if bool(salida_ia.get("del_pool", false)):
			noticias.append("AGENTES LIBRES: %s ficha libre a un %s de media %d." % [
				equipo.nombre, str(salida_ia["jugador"]["posicion"]),
				int(salida_ia["jugador"]["media"])])


## Renueva por 2-4 años y RECALCULA el sueldo según el valor actual del
## jugador — antes quedaba congelado en lo que costaba cuando se lo
## registró (ficharlo, o la generación inicial del plantel), así que un
## jugador que mejoraba muchísimo seguía cobrando lo mismo para siempre.
## Ahora, mejorar te cuesta mantenerlo, como en la realidad.
func _renovar_contrato(equipo: Team, id: int, jugador: Dictionary, rng: RandomNumberGenerator) -> void:
	var anios := rng.randi_range(2, 4)
	equipo.contratos[id] = anios
	if jugador.is_empty():
		return
	# base_salarial, no calcular: el sueldo no lleva el escalon de elite
	# (ver ValorJugador.base_salarial).
	var base := ValorJugador.base_salarial(
		jugador, equipo.animo.get(id, 50.0), anios, equipo.division_actual)
	equipo.sueldos[id] = Economia.sueldo_sugerido(base) * Personalidad.factor_sueldo(jugador)


## Descuenta 1 partido de suspensión a los ids que YA estaban suspendidos
## antes de este partido (ver el snapshot en jugar_fecha). Los que llegan
## a 0 quedan disponibles otra vez.
func _servir_suspensiones(equipo: Team, ids: Array) -> void:
	for id in ids:
		if not equipo.suspendidos.has(id):
			continue
		equipo.suspendidos[id] -= 1
		if equipo.suspendidos[id] <= 0:
			equipo.suspendidos.erase(id)


func _buscar_en_plantel(equipo: Team, jugador_id: int) -> Dictionary:
	for j in equipo.todos_los_jugadores():
		if j["id"] == jugador_id:
			return j
	return {}


func _actualizar_tabla(local: String, visitante: String, gl: int, gv: int) -> void:
	var fl: Dictionary = tabla[local]
	var fv: Dictionary = tabla[visitante]

	fl["pj"] += 1
	fv["pj"] += 1
	fl["gf"] += gl
	fl["gc"] += gv
	fv["gf"] += gv
	fv["gc"] += gl
	fl["dg"] = fl["gf"] - fl["gc"]
	fv["dg"] = fv["gf"] - fv["gc"]

	if gl > gv:
		fl["pg"] += 1
		fl["pts"] += 3
		fv["pp"] += 1
	elif gl < gv:
		fv["pg"] += 1
		fv["pts"] += 3
		fl["pp"] += 1
	else:
		fl["pe"] += 1
		fv["pe"] += 1
		fl["pts"] += 1
		fv["pts"] += 1


## Orden estándar: puntos, luego diferencia de gol, luego goles a favor.
func tabla_ordenada() -> Array:
	var nombres := tabla.keys()
	nombres.sort_custom(func(a, b):
		var fa: Dictionary = tabla[a]
		var fb: Dictionary = tabla[b]
		if fa["pts"] != fb["pts"]:
			return fa["pts"] > fb["pts"]
		if fa["dg"] != fb["dg"]:
			return fa["dg"] > fb["dg"]
		return fa["gf"] > fb["gf"]
	)
	return nombres
