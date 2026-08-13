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
		var r := MatchEngine.simular(home, away, rng, con_log)
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
func procesar_economia_y_mercado_y_progresion(rng: RandomNumberGenerator) -> Array:
	var orden_final := tabla_ordenada()
	var informes_economia := []
	for i in range(orden_final.size()):
		var nombre: String = orden_final[i]
		for equipo in equipos:
			if equipo.nombre == nombre:
				var informe := Economia.procesar_temporada(equipo, i + 1, orden_final.size())
				informe["equipo"] = nombre
				informes_economia.append(informe)
				break

	var transferencias := Mercado.ejecutar_ventana(self, rng)
	for t in transferencias:
		noticias.append("FICHAJES: jugador #%d (%s) pasa de %s a %s por $%.0f" % [t["jugador_id"], t["posicion"], t["de"], t["a"], t["valor"]])

	var reporte_cantera := []
	for equipo in equipos:
		_avanzar_contratos(equipo, rng)
		for jugador in equipo.jugadores:
			Progresion.aplicar_temporada(jugador, rng)
		var reporte := _procesar_cantera(equipo, rng)
		reporte_cantera.append(reporte)
		for r in reporte["promovidos"]:
			noticias.append("CANTERA: %s hace debutar a un canterano en %s" % [equipo.nombre, r["promovido"]["posicion"]])
		if not reporte["liberados"].is_empty():
			noticias.append("CANTERA: %s deja libres a %d juveniles que no debutaron a tiempo" % [equipo.nombre, reporte["liberados"].size()])
		equipo.recalcular_capitan()

	return [informes_economia, transferencias, reporte_cantera]


## §17: envejece a los juveniles (crecen igual que cualquiera, §7.1),
## libera a los que llegaron a los 20 sin debutar, genera la camada nueva
## y deja que la IA promueva a los que ya superan claramente a su titular.
func _procesar_cantera(equipo: Team, rng: RandomNumberGenerator) -> Dictionary:
	for juvenil in equipo.cantera:
		Progresion.aplicar_temporada(juvenil, rng)
	var liberados := equipo.liberar_veteranos_de_cantera()
	var nuevos := equipo.generar_camada(rng)
	var promovidos := equipo.promover_automatico()
	return {"equipo": equipo.nombre, "liberados": liberados, "nuevos": nuevos, "promovidos": promovidos}


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
func nueva_temporada(rng: RandomNumberGenerator) -> Array:
	var resultado := procesar_economia_y_mercado_y_progresion(rng)
	iniciar_temporada()
	return resultado


## §9.3: si el contrato llega a 0 debería salir gratis al mercado de libres,
## pero sin plantel de 25 todavía (fase 14) perder un titular deja al
## equipo corto de jugadores — así que por ahora se renueva solo con un
## contrato nuevo. Simplificación documentada, no la regla final del GDD.
func _avanzar_contratos(equipo: Team, rng: RandomNumberGenerator) -> void:
	for id in equipo.contratos.keys():
		equipo.contratos[id] -= 1
		if equipo.contratos[id] <= 0:
			equipo.contratos[id] = rng.randi_range(2, 4)


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
