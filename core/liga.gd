class_name Liga
extends RefCounted

## Fase 3 (GDD §10, §15 decisión 11): liga de 20 equipos, calendario ida y
## vuelta (sistema del círculo) y tabla de posiciones. Todavía sin
## ascensos/descensos ni las 10 divisiones — eso es §10 completo, fase 7.

var equipos: Array = []  # Team
var tabla: Dictionary = {}  # nombre_equipo -> fila de stats
var fixture: Array = []  # fechas -> [[idx_local, idx_visitante], ...]


## Sistema del círculo: fija el equipo 0 y rota el resto. Da n-1 fechas donde
## cada equipo juega una vez contra todos; la vuelta repite invirtiendo local.
static func generar_fixture_ida_vuelta(n: int) -> Array:
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

	var vuelta := []
	for ronda in ida:
		var ronda_vuelta := []
		for partido in ronda:
			ronda_vuelta.append([partido[1], partido[0]])
		vuelta.append(ronda_vuelta)

	return ida + vuelta


func inicializar(nombres_equipos: Array, rng: RandomNumberGenerator) -> void:
	equipos.clear()
	tabla.clear()
	for nombre in nombres_equipos:
		var equipo := Team.generar(nombre, rng)
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

	for partido in fecha:
		var home: Team = equipos[partido[0]]
		var away: Team = equipos[partido[1]]
		var con_log: bool = equipo_seguido != null and (home == equipo_seguido or away == equipo_seguido)
		var r := MatchEngine.simular(home, away, rng, con_log)
		_actualizar_tabla(home.nombre, away.nombre, r["goles_local"], r["goles_visitante"])
		resultados_texto.append("%s %d-%d %s" % [home.nombre, r["goles_local"], r["goles_visitante"], away.nombre])
		if con_log:
			resultado_seguido = {"local": home.nombre, "visitante": away.nombre, "gl": r["goles_local"], "gv": r["goles_visitante"]}
			log_seguido = r["log"]

	return {"resultados_texto": resultados_texto, "resultado_seguido": resultado_seguido, "log_seguido": log_seguido}


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
