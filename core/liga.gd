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

## Agentes libres (§9.3 extendido): jugadores sin club, fichables sin fee de
## transferencia. Ver core/agentes_libres.gd. Pool por división, igual que
## el resto del mercado.
var agentes_libres: Array = []


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
	}


static func cargar(datos: Dictionary) -> Liga:
	var l := Liga.new()
	for ed in datos["equipos"]:
		l.equipos.append(Team.cargar(ed))
	l.tabla = datos["tabla"]
	l.fixture = datos["fixture"]
	l.noticias = datos.get("noticias", [])
	l.agentes_libres = datos.get("agentes_libres", [])
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
func inicializar(nombres_equipos: Array, rng: RandomNumberGenerator, id_inicial: int = 0) -> void:
	equipos.clear()
	tabla.clear()
	var siguiente_id := id_inicial
	for nombre in nombres_equipos:
		var equipo := Team.generar(nombre, rng, siguiente_id)
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
## El plantel activo (titulares+banco) tiene 18 jugadores en total, así
## que el mínimo tiene que ser MENOR a 18 — si fuera igual, una sola
## lesión (algo que pasa todo el tiempo en una temporada de 38 fechas) te
## dejaría corto automáticamente. 15 deja margen para hasta 3 lesionados
## simultáneos, que es lo esperable en un plantel real, sin volver el
## chequeo inútil.
const MINIMO_DISPONIBLES := 15
## Multa por no poder presentar el mínimo, descontada del presupuesto de
## Mantenimiento (administrativo, no es un gasto de plantel). Bajada de
## $30,000 a $5,000 junto con el ajuste de PRECIO_ENTRADA (Economia.gd,
## feedback de playtesting): a $30,000 la multa, calibrada cuando un club
## de división baja ganaba ~$800,000 por temporada, pasó a ser ~20% del
## ingreso de un club real (~$150,000) en vez de una fracción chica —
## unos pocos forfeits por mala suerte con lesiones alcanzaban para
## mandar a un club sano a quiebra técnica. $5,000 sigue siendo un golpe
## real (nadie quiere pagarla), pero no un evento que quiebra un club por
## sí solo.
const MULTA_NO_PRESENTARSE := 5000.0


## Simula una sola fecha (todos sus partidos) y actualiza la tabla.
## Si se pasa equipo_seguido, además devuelve el resultado y el log
## detallado de su partido para mostrarlo en la UI.
func jugar_fecha(idx: int, rng: RandomNumberGenerator, equipo_seguido: Team = null) -> Dictionary:
	var fecha: Array = fixture[idx]
	var resultados_texto := []
	var resultado_seguido = null
	var log_seguido := []
	var eventos_seguido := []

	for partido in fecha:
		var home: Team = equipos[partido[0]]
		var away: Team = equipos[partido[1]]
		var con_log: bool = equipo_seguido != null and (home == equipo_seguido or away == equipo_seguido)

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

		var r: Dictionary
		if home_corto or away_corto:
			r = _resolver_forfeit(home, away, home_corto, away_corto)
		else:
			r = MatchEngine.simular(home, away, rng, con_log)

		_servir_suspensiones(home, suspendidos_previos_home)
		_servir_suspensiones(away, suspendidos_previos_away)

		_actualizar_tabla(home.nombre, away.nombre, r["goles_local"], r["goles_visitante"])
		_actualizar_estado_jugadores(home, away, r)
		resultados_texto.append("%s %d-%d %s" % [home.nombre, r["goles_local"], r["goles_visitante"], away.nombre])
		if con_log:
			resultado_seguido = {"local": home.nombre, "visitante": away.nombre, "gl": r["goles_local"], "gv": r["goles_visitante"]}
			log_seguido = r["log"]
			eventos_seguido = r["eventos"]

	return {
		"resultados_texto": resultados_texto, "resultado_seguido": resultado_seguido,
		"log_seguido": log_seguido, "eventos_seguido": eventos_seguido,
	}


## §14: "si no llegás a MINIMO_DISPONIBLES, perdés el partido por no
## presentarte" — 0-3 en contra + multa. Devuelve el mismo formato que
## MatchEngine.simular() para que el resto de jugar_fecha() no note la
## diferencia. Si a los DOS equipos les falta gente a la vez (rarísimo),
## se resuelve como empate administrativo 0-0 con multa para ambos, para
## no romper la simetría de goles a favor/en contra de la tabla.
func _resolver_forfeit(home: Team, away: Team, home_corto: bool, away_corto: bool) -> Dictionary:
	var gl := 0
	var gv := 0
	if home_corto and not away_corto:
		gv = 3
		home.caja["mantenimiento"] -= MULTA_NO_PRESENTARSE
		noticias.append("%s no pudo presentar %d jugadores disponibles: pierde 0-3 y paga una multa." % [home.nombre, MINIMO_DISPONIBLES])
	elif away_corto and not home_corto:
		gl = 3
		away.caja["mantenimiento"] -= MULTA_NO_PRESENTARSE
		noticias.append("%s no pudo presentar %d jugadores disponibles: pierde 0-3 y paga una multa." % [away.nombre, MINIMO_DISPONIBLES])
	else:
		home.caja["mantenimiento"] -= MULTA_NO_PRESENTARSE
		away.caja["mantenimiento"] -= MULTA_NO_PRESENTARSE
		noticias.append("%s y %s no pudieron presentar %d disponibles cada uno: empate administrativo, ambos multados." % [home.nombre, away.nombre, MINIMO_DISPONIBLES])
	return {"goles_local": gl, "goles_visitante": gv, "log": [], "goles_log": [], "eventos": []}


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
				var informe := Economia.procesar_temporada(equipo, i + 1, orden_final.size())
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
		noticias.append("FICHAJES: jugador #%d (%s) pasa de %s a %s por $%.0f" % [t["jugador_id"], t["posicion"], t["de"], t["a"], t["valor"]])

	var reporte_cantera := []
	for equipo in equipos:
		var vueltos := Prestamos.procesar_retornos(equipo, temporada_actual)
		for j in vueltos:
			noticias.append("PRÉSTAMOS: %s vuelve a %s tras el préstamo." % [j["posicion"], equipo.nombre])

		_avanzar_contratos(equipo, rng, equipo == equipo_protegido)
		var bonus_mentor := Mentores.mejor_bonus_disponible(equipo)

		# §7.4 punto 3: la IA mantiene el foco de quien ya lo tenía (para
		# que llegue a las 2 temporadas seguidas) y llena los cupos que
		# sobren. Al equipo del jugador humano no se le toca — el foco
		# individual lo elige él desde la UI.
		if equipo != equipo_protegido:
			Entrenamiento.asignar_foco_automatico_ia(equipo, rng)
		var mult_entrenamiento := Instalaciones.factor_entrenamiento(equipo)

		for jugador in equipo.todos_los_jugadores():
			var foco: String = equipo.foco_individual.get(jugador["id"], "")
			Progresion.aplicar_temporada(jugador, rng, Mentores.multiplicador_para(jugador, bonus_mentor), mult_entrenamiento, foco)
			Entrenamiento.actualizar_racha(jugador, foco)
			var aprendida := Aprendizaje.procesar_jugador(jugador, equipo, temporada_actual, rng)
			if not aprendida.is_empty():
				noticias.append("APRENDIZAJE: un %s de %s aprende %s (bronce)." % [jugador["posicion"], equipo.nombre, aprendida["nombre"]])

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
		var foco: String = equipo.foco_individual.get(juvenil["id"], "")
		Progresion.aplicar_temporada(juvenil, rng, Mentores.multiplicador_para(juvenil, bonus_mentor), mult_entrenamiento, foco)
		Entrenamiento.actualizar_racha(juvenil, foco)
		var aprendida := Aprendizaje.procesar_jugador(juvenil, equipo, temporada_actual, rng)
		if not aprendida.is_empty():
			aprendizajes.append({"jugador": juvenil, "habilidad": aprendida})
	var liberados := equipo.liberar_veteranos_de_cantera()
	var nuevos := equipo.generar_camada(rng, Instalaciones.cantidad_camada(equipo))
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
## puesto lo ocupa un refuerzo nuevo. Al jugador humano todavía no se le
## vencen los contratos solos (sin una pantalla de "renovar", forzar la
## salida de alguien de su plantel sin que él lo decida sería sacarle el
## control) — simplificación documentada, no la regla final del GDD.
func _avanzar_contratos(equipo: Team, rng: RandomNumberGenerator, es_protegido: bool = false) -> void:
	for id in equipo.contratos.keys().duplicate():
		equipo.contratos[id] -= 1
		if equipo.contratos[id] > 0:
			continue

		var jugador := _buscar_en_plantel(equipo, id)

		if es_protegido:
			_renovar_contrato(equipo, id, jugador, rng)
			continue

		if jugador.is_empty():
			_renovar_contrato(equipo, id, jugador, rng)
			continue

		var edad: int = jugador.get("edad", 25)
		var probabilidad_irse: float = clamp(0.10 + max(0, edad - 27) * 0.03, 0.10, 0.55)
		if rng.randf() >= probabilidad_irse:
			_renovar_contrato(equipo, id, jugador, rng)
			continue

		AgentesLibres.liberar(equipo, jugador, agentes_libres, rng)
		noticias.append("AGENTES LIBRES: un %s queda libre, se va de %s." % [jugador["posicion"], equipo.nombre])


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
	var valor := ValorJugador.calcular(jugador, equipo.animo.get(id, 50.0), anios)
	equipo.sueldos[id] = Economia.sueldo_sugerido(valor) * Personalidad.factor_sueldo(jugador)


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
	for j in equipo.jugadores:
		if j["id"] == jugador_id:
			return j
	for j in equipo.banco:
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
