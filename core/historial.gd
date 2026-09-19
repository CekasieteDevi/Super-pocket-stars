class_name Historial
extends RefCounted

## La memoria larga de la partida: la carrera de cada jugador, las
## temporadas de cada club y quien gano cada competencia.
##
## Hasta aca todo lo que se contaba moria al cerrar la temporada:
## `rendimiento` y EstadisticasLiga se resetean, la tabla tambien, y de las
## copas solo quedaba la ultima. La vitrina recordaba los titulos del club
## del jugador y nada mas.
##
## Tres cosas, cada una en el objeto que describe:
## - `jugador["carrera"]`: una fila por temporada y club, con PJ, goles y
##   asistencias. Viaja con el jugador en cada pase, asi que no hace falta
##   enganchar nada en el mercado: el pase cambia el club y el partido
##   siguiente ya abre la fila nueva.
## - `Team.historial_temporadas`: division y puesto de cada temporada.
## - `GameState.historial_copas`: competencia -> campeon y subcampeon por
##   temporada.
##
## Los jugadores retirados se van con su carrera: nadie los guarda.

## La temporada que se esta jugando. La fija GameState al arrancar, al
## cargar y al pasar de temporada. Es estatica porque Liga y Copa juegan
## partidos sin saber en que temporada estan, y pasarla por parametro
## obligaba a tocar todas las firmas de los dos motores.
static var temporada: int = 1


## El año del almanaque de una temporada. La temporada arranca en marzo y
## cierra antes de diciembre (ver Calendario), asi que entra entera en
## un año: la 1 es 2025, igual que en la vitrina.
static func anio_de(t: int) -> int:
	return Calendario.ANIO_INICIAL + t - 1


## Suma un partido a la carrera de los que lo jugaron. Los dos motores
## entregan el mismo shape (`xp` por lado y `goles_log`), asi que esto no
## sabe cual se uso.
##
## `cuenta_partido` en false es para el alargue abstracto de una copa:
## sus goles se suman, pero es el mismo partido y no otro.
static func registrar_partido(home: Team, away: Team, r: Dictionary,
		cuenta_partido: bool = true) -> void:
	var xp: Dictionary = r.get("xp", {})
	_registrar_lado(home, xp.get("home", {}), r.get("goles_log", []), cuenta_partido)
	_registrar_lado(away, xp.get("away", {}), r.get("goles_log", []), cuenta_partido)


static func _registrar_lado(equipo: Team, xp_lado: Dictionary, goles_log: Array,
		cuenta_partido: bool) -> void:
	var goles := {}
	var asistencias := {}
	for gol in goles_log:
		if str(gol.get("equipo", "")) != equipo.nombre:
			continue
		var g := int(gol.get("jugador_id", -1))
		goles[g] = int(goles.get(g, 0)) + 1
		# -1 es un gol sin pase previo: no es asistencia de nadie.
		var a := int(gol.get("asistencia_id", -1))
		if a >= 0:
			asistencias[a] = int(asistencias.get(a, 0)) + 1
	for j in equipo.todos_los_jugadores():
		var id := int(j["id"])
		var jugo := cuenta_partido and _minutos(xp_lado.get(id, null)) > 0.0
		var g := int(goles.get(id, 0))
		var a := int(asistencias.get(id, 0))
		if not jugo and g == 0 and a == 0:
			continue
		var fila := fila_abierta(j, equipo)
		if jugo:
			fila["pj"] = int(fila["pj"]) + 1
		fila["goles"] = int(fila["goles"]) + g
		fila["asistencias"] = int(fila["asistencias"]) + a


## La fraccion de partido jugada. El XP de un partido reparte `minutos/90`
## por atributo (ver Liga._acumular_rendimiento): si suma 0, no entro.
static func _minutos(d) -> float:
	if not d is Dictionary:
		return 0.0
	var total := 0.0
	for attr in d:
		total += maxf(float(d[attr]), 0.0)
	return total


## La fila de esta temporada en este club; si no hay, la abre. Solo mira
## la ULTIMA fila: un jugador que va de A a B y vuelve a A en la misma
## temporada tiene tres filas, que es lo que paso.
static func fila_abierta(j: Dictionary, equipo: Team) -> Dictionary:
	var carrera: Array = j.get("carrera", [])
	if not carrera.is_empty():
		var ultima: Dictionary = carrera[carrera.size() - 1]
		if int(ultima.get("temporada", 0)) == temporada and str(ultima.get("club", "")) == equipo.nombre:
			return ultima
	# division 0 = club del exterior: juega la internacional pero no tiene
	# lugar en la piramide.
	var nueva := {
		"temporada": temporada, "club": equipo.nombre,
		"division": equipo.division_actual + 1,
		"pj": 0, "goles": 0, "asistencias": 0,
	}
	carrera.append(nueva)
	j["carrera"] = carrera
	return nueva


## Totales de toda la carrera.
static func totales(j: Dictionary) -> Dictionary:
	var t := {"pj": 0, "goles": 0, "asistencias": 0, "clubes": 0}
	var clubes := {}
	for f in j.get("carrera", []):
		t["pj"] += int(f.get("pj", 0))
		t["goles"] += int(f.get("goles", 0))
		t["asistencias"] += int(f.get("asistencias", 0))
		clubes[str(f.get("club", ""))] = true
	t["clubes"] = clubes.size()
	return t


## El cierre de la temporada, con las tablas todavia enteras: va ANTES de
## Piramide.fin_de_temporada, que las resetea y mueve clubes de division.
##
## Cada jugador de la piramide queda anotado en su club aunque no haya
## jugado: el suplente que no entro nunca tambien fue de ese club.
static func cerrar_temporada(piramide: Piramide) -> void:
	for d in range(piramide.divisiones.size()):
		var liga: Liga = piramide.divisiones[d]
		var orden: Array = liga.tabla_ordenada()
		for i in range(orden.size()):
			var equipo: Team = _equipo_por_nombre(liga, str(orden[i]))
			if equipo == null:
				continue
			var fila: Dictionary = liga.tabla.get(equipo.nombre, {})
			equipo.historial_temporadas.append({
				"temporada": temporada, "division": d + 1,
				"posicion": i + 1, "total": orden.size(),
				"pts": int(fila.get("pts", 0)),
			})
			for j in equipo.todos_los_jugadores():
				fila_abierta(j, equipo)


static func _equipo_por_nombre(liga: Liga, nombre: String) -> Team:
	for e in liga.equipos:
		if e.nombre == nombre:
			return e
	return null


## Anota un campeon en el palmares. `subcampeon` puede venir vacio.
static func anotar_titulo(palmares: Dictionary, competencia: String,
		campeon: String, subcampeon: String) -> void:
	if campeon == "":
		return
	var lista: Array = palmares.get(competencia, [])
	lista.append({"temporada": temporada, "campeon": campeon, "subcampeon": subcampeon})
	palmares[competencia] = lista


## Los clubes que mas veces ganaron una competencia, de mas a menos. El
## desempate son las finales perdidas: el que llego mas veces pesa mas.
static func ranking_de_titulos(lista: Array) -> Array:
	var por_club := {}
	for t in lista:
		for clave in ["campeon", "subcampeon"]:
			var club := str(t.get(clave, ""))
			if club == "":
				continue
			if not por_club.has(club):
				por_club[club] = {"club": club, "titulos": 0, "subcampeonatos": 0}
			if clave == "campeon":
				por_club[club]["titulos"] += 1
			else:
				por_club[club]["subcampeonatos"] += 1
	var filas: Array = por_club.values().filter(func(f): return int(f["titulos"]) > 0)
	filas.sort_custom(func(a, b):
		if int(a["titulos"]) != int(b["titulos"]):
			return int(a["titulos"]) > int(b["titulos"])
		return int(a["subcampeonatos"]) > int(b["subcampeonatos"]))
	return filas


## Todos los titulos de un club, del mas nuevo al mas viejo.
static func titulos_de_club(palmares: Dictionary, club: String) -> Array:
	var titulos := []
	for competencia in palmares:
		for t in palmares[competencia]:
			if str(t.get("campeon", "")) == club:
				titulos.append({"competencia": competencia, "temporada": int(t["temporada"])})
	titulos.sort_custom(func(a, b): return int(a["temporada"]) > int(b["temporada"]))
	return titulos
