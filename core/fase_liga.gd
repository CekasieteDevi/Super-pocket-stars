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


static func iniciar(nombre: String, equipos: Array, n_fechas: int) -> FaseLiga:
	var f := FaseLiga.new()
	f.nombre = nombre
	f.equipos = equipos.duplicate()
	for equipo in f.equipos:
		f.tabla[equipo.nombre] = {"pj": 0, "pg": 0, "pe": 0, "pp": 0, "gf": 0, "gc": 0, "dg": 0, "pts": 0}

	var fixture_completo := Liga.generar_fixture_simple(f.equipos.size())
	f.fixture = fixture_completo.slice(0, min(n_fechas, fixture_completo.size()))
	return f


func jugar_temporada(rng: RandomNumberGenerator) -> void:
	for fecha in fixture:
		for partido in fecha:
			var home: Team = equipos[partido[0]]
			var away: Team = equipos[partido[1]]
			var r := MatchEngine.simular(home, away, rng, false)
			_actualizar_tabla(home.nombre, away.nombre, r["goles_local"], r["goles_visitante"])


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
		return fa["gf"] > fb["gf"]
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
