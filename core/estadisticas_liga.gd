class_name EstadisticasLiga
extends RefCounted

## Estadisticas INDIVIDUALES acumuladas de toda la liga a lo largo de la
## temporada: goleadores, asistencias, vallas invictas y tarjetas.
##
## La tabla de posiciones ya contaba lo colectivo, pero de los jugadores no
## quedaba rastro: un delantero podia meter veinte goles y no aparecer en
## ningun lado. Esto se acumula partido a partido en Liga.jugar_fecha(),
## para TODOS los partidos de la fecha y no solo el del jugador — si no,
## el "goleador de la liga" seria siempre alguien del plantel propio.
##
## Los dos motores entran por el mismo lugar (Liga.jugar_fecha) y entregan
## el mismo shape (goles_log + eventos), asi que esto no sabe cual se uso
## ni tiene por que saberlo.

## Una fila por jugador. Las claves del diccionario son el id EN TEXTO
## porque esto se guarda como JSON y JSON no tiene claves numericas: si se
## guardaran como int, al cargar volverian como String igual y la partida
## cargada acumularia en filas nuevas.
const CLAVES_CONTADAS := ["goles", "asistencias", "vallas", "amarillas", "rojas"]


static func fila_vacia(nombre: String, equipo: String, posicion: String) -> Dictionary:
	return {
		"nombre": nombre, "equipo": equipo, "posicion": posicion,
		"goles": 0, "asistencias": 0, "vallas": 0, "amarillas": 0, "rojas": 0,
	}


## Suma lo que paso en UN partido. `stats` se modifica in place.
static func registrar_partido(stats: Dictionary, home: Team, away: Team, r: Dictionary) -> void:
	var equipos := [home, away]

	for gol in r.get("goles_log", []):
		var eq: Team = home if str(gol["equipo"]) == home.nombre else away
		_sumar(stats, eq, int(gol.get("jugador_id", -1)), "goles")
		# asistencia_id llega en -1 cuando el gol no tuvo pase previo
		# (gambeta, rebote, penal) — eso NO es una asistencia de nadie.
		_sumar(stats, eq, int(gol.get("asistencia_id", -1)), "asistencias")

	for ev in r.get("eventos", []):
		if str(ev.get("tipo", "")) != "tarjeta":
			continue
		var eq_t: Team = null
		for e in equipos:
			if e.nombre == str(ev.get("equipo", "")):
				eq_t = e
		if eq_t == null:
			continue
		var res := str(ev.get("resultado", ""))
		var id_t := int(ev.get("jugador_id", -1))
		if res == "amarilla":
			_sumar(stats, eq_t, id_t, "amarillas")
		else:
			# La roja por doble amarilla trae ADEMAS la segunda amarilla,
			# que no se emite como evento propio: sin esto, el que se va
			# expulsado por dos amarillas figura con una sola.
			if res == "roja_doble_amarilla":
				_sumar(stats, eq_t, id_t, "amarillas")
			_sumar(stats, eq_t, id_t, "rojas")

	# Un 0-3 administrativo no le da la valla invicta a un arquero que no
	# jugo: nadie le ataja nada al equipo que no se presento.
	if bool(r.get("forfeit", false)):
		return
	# Valla invicta: es del arquero, no del equipo. Se le da al que termino
	# el partido bajo los tres palos (Team.arquero()); si lo cambiaron a
	# los 80', el suplente se queda con el cero, que es la convencion
	# menos discutible sin minutos jugados por jugador.
	if int(r.get("goles_visitante", 0)) == 0:
		_sumar(stats, home, int(home.arquero().get("id", -1)), "vallas")
	if int(r.get("goles_local", 0)) == 0:
		_sumar(stats, away, int(away.arquero().get("id", -1)), "vallas")


static func _sumar(stats: Dictionary, equipo: Team, jugador_id: int, clave: String) -> void:
	if jugador_id < 0:
		return
	var k := str(jugador_id)
	if not stats.has(k):
		var j := _buscar(equipo, jugador_id)
		if j.is_empty():
			return
		stats[k] = fila_vacia(
			"%s %s" % [j.get("nombre", ""), j.get("apellido", "")],
			equipo.nombre, str(j.get("posicion", "")))
	else:
		# Se fichó a mitad de temporada: lo que hizo antes sigue contando,
		# pero la tabla tiene que decir en qué club está jugando ahora.
		stats[k]["equipo"] = equipo.nombre
	stats[k][clave] = int(stats[k][clave]) + 1


static func _buscar(equipo: Team, jugador_id: int) -> Dictionary:
	for j in equipo.jugadores:
		if int(j["id"]) == jugador_id:
			return j
	for j in equipo.banco:
		if int(j["id"]) == jugador_id:
			return j
	return {}


## Los mejores por una de CLAVES_CONTADAS, de mayor a menor. Devuelve
## filas planas (id incluido) listas para pintar. Los que estan en cero no
## entran: una lista de goleadores con 300 jugadores en 0 no es una lista.
static func ranking(stats: Dictionary, clave: String, tope: int = 30) -> Array:
	var filas := []
	for k in stats:
		var f: Dictionary = stats[k]
		if int(f.get(clave, 0)) <= 0:
			continue
		var fila := f.duplicate()
		fila["id"] = int(k)
		filas.append(fila)
	# Desempate por nombre para que el orden sea ESTABLE: sin esto dos
	# jugadores con los mismos goles se intercambiaban de puesto en cada
	# refresco segun como quedara el diccionario.
	filas.sort_custom(func(a, b):
		if int(a[clave]) != int(b[clave]):
			return int(a[clave]) > int(b[clave])
		return str(a["nombre"]) < str(b["nombre"])
	)
	if filas.size() > tope:
		filas.resize(tope)
	return filas


## JSON devuelve todo numero como float, asi que una tabla cargada traia
## "12.0 goles". Se convierte al cargar, igual que Liga.tabla.
static func cargar(datos: Dictionary) -> Dictionary:
	var stats := {}
	for k in datos:
		var origen: Dictionary = datos[k]
		var fila := fila_vacia(
			str(origen.get("nombre", "")), str(origen.get("equipo", "")),
			str(origen.get("posicion", "")))
		for c in CLAVES_CONTADAS:
			fila[c] = int(origen.get(c, 0))
		stats[str(k)] = fila
	return stats
