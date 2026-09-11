class_name FaseLiga
extends RefCounted

## Fase de liga a tabla única — Fase 7 (GDD §10.3: "Todas usan fase liga,
## como la Champions actual"). La usan las tres copas internacionales
## (Campeones 8 fechas, Guerreros/Emergentes 6 fechas cada una).
##
## Simplificación documentada: el GDD pide "4 bombos por coeficiente de
## club, cada equipo enfrenta a 2 de su bombo y 2 de cada otro" para armar
## el fixture. Emparejar por bombos así es un problema de scheduling en
## serio; acá se arman los rivales con el mismo sistema del círculo que ya
## usa la liga doméstica, tomando solo las primeras N fechas (que ya
## garantiza que nadie repite rival). No respeta bombos todavía — pendiente
## si hace falta más fidelidad al formato real.

var nombre: String
var equipos: Array = []  # Team
var tabla: Dictionary = {}  # nombre_equipo -> fila de stats
var fixture: Array = []  # fechas -> [[idx_local, idx_visitante], ...]

## El partido del equipo seguido en la fecha que se acaba de jugar, con
## fotogramas para verlo. Es TRANSITORIO: no se guarda y se pisa en cada
## fecha. Mismo contrato que Copa.seguido.
var seguido: Dictionary = {}


static func iniciar(nombre: String, equipos: Array, n_fechas: int) -> FaseLiga:
	var f := FaseLiga.new()
	f.nombre = nombre
	f.equipos = equipos.duplicate()
	for equipo in f.equipos:
		f.tabla[equipo.nombre] = {"pj": 0, "pg": 0, "pe": 0, "pp": 0, "gf": 0, "gc": 0, "dg": 0, "pts": 0}

	var fixture_completo := Liga.generar_fixture_simple(f.equipos.size())
	f.fixture = fixture_completo.slice(0, min(n_fechas, fixture_completo.size()))
	return f


## La fase entera de un saque. La usan los tests y el drenaje de fin de
## temporada; la partida la juega fecha a fecha (ver jugar_fecha).
func jugar_temporada(rng: RandomNumberGenerator) -> void:
	for i in range(fixture.size()):
		jugar_fecha(i, rng)


## Una sola fecha. La fase de liga internacional se juega intercalada con
## el campeonato, una fecha por semana, y el cruce del jugador lo tiene
## que poder mirar (ver TemporadaInternacional).
##
## El empate es un resultado: acá no hay alargue ni penales, así que el
## partido va con `es_eliminatoria` en false (ver Copa.jugar_partido).
func jugar_fecha(indice: int, rng: RandomNumberGenerator, equipo_seguido: Team = null) -> void:
	seguido = {}
	if indice < 0 or indice >= fixture.size():
		return
	for partido in fixture[indice]:
		var home: Team = equipos[partido[0]]
		var away: Team = equipos[partido[1]]
		var es_el_del_jugador: bool = home == equipo_seguido or away == equipo_seguido
		var r := Copa.jugar_partido(home, away, rng, es_el_del_jugador, false)
		var gl: int = r["goles_local"]
		var gv: int = r["goles_visitante"]
		_actualizar_tabla(home.nombre, away.nombre, gl, gv)
		if es_el_del_jugador:
			var ganador := ""
			if gl > gv:
				ganador = home.nombre
			elif gv > gl:
				ganador = away.nombre
			seguido = {
				"local": home.nombre, "visitante": away.nombre,
				"gl": gl, "gv": gv, "ganador": ganador,
				"definicion": "90 minutos", "penales_texto": "",
				"goles_log": r.get("goles_log", []), "log": r.get("log", []),
				"eventos": r.get("eventos", []), "fotogramas": r.get("fotogramas", []),
			}


## El cruce que le toca a un equipo en una fecha: [local, visitante], o
## vacío si esa fecha descansa (fixture impar) o si no juega esta fase.
func cruce_de(equipo: Team, indice: int) -> Array:
	if equipo == null or indice < 0 or indice >= fixture.size():
		return []
	for partido in fixture[indice]:
		var home: Team = equipos[partido[0]]
		var away: Team = equipos[partido[1]]
		if home == equipo or away == equipo:
			return [home, away]
	return []


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


func tabla_ordenada() -> Array:
	var nombres := tabla.keys()
	nombres.sort_custom(func(a, b):
		var fa: Dictionary = tabla[a]
		var fb: Dictionary = tabla[b]
		if fa["pts"] != fb["pts"]:
			return fa["pts"] > fb["pts"]
		if fa["dg"] != fb["dg"]:
			return fa["dg"] > fb["dg"]
		if fa["gf"] != fb["gf"]:
			return fa["gf"] > fb["gf"]
		# Ultimo desempate: el nombre. Sin el, dos equipos con los mismos
		# puntos, la misma diferencia y los mismos goles quedaban en el
		# orden en que el diccionario devuelve sus claves, y ese orden lo
		# fija el ORDEN DE CARGA: la misma tabla guardada y recargada
		# salia distinta. Lo cazo test_internacional_jugable.
		return str(a) < str(b)
	)
	return nombres


## Los Team en el orden final de tabla (para armar el bracket de octavos).
func equipos_ordenados() -> Array:
	var mapa := {}
	for equipo in equipos:
		mapa[equipo.nombre] = equipo
	var out := []
	for nombre in tabla_ordenada():
		out.append(mapa[nombre])
	return out


## Guardado. Los equipos viajan por NOMBRE y se relocalizan al cargar con
## el índice que arma Confederacion, igual que Copa.
func guardar() -> Dictionary:
	var nombres := []
	for e in equipos:
		nombres.append(e.nombre)
	return {"nombre": nombre, "equipos": nombres, "tabla": tabla, "fixture": fixture}


static func cargar(datos: Dictionary, indice: Dictionary) -> FaseLiga:
	var f := FaseLiga.new()
	f.nombre = str(datos.get("nombre", ""))
	for n in datos.get("equipos", []):
		if indice.has(str(n)):
			f.equipos.append(indice[str(n)])
	for nombre_equipo in datos.get("tabla", {}):
		var fila: Dictionary = datos["tabla"][nombre_equipo]
		var limpia := {}
		# El JSON devuelve todo como float. La tabla se compara y se
		# imprime como entero, así que se vuelve a enteros acá y no en
		# cada lugar que la lee.
		for clave in fila:
			limpia[clave] = int(fila[clave])
		f.tabla[str(nombre_equipo)] = limpia
	for fecha in datos.get("fixture", []):
		var pares := []
		for par in fecha:
			pares.append([int(par[0]), int(par[1])])
		f.fixture.append(pares)
	return f
