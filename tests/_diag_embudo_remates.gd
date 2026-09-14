extends SceneTree

## Etapa 9, aceptacion final: embudo de remates de los DOS motores con los
## mismos planteles, ida y vuelta. No es un test: mide. La validacion final
## (docs/mediciones/calibracion_final.md) encontro al espacial entre 18% y
## 50% por debajo del abstracto en goles, y pedia separar generacion de
## ocasiones, punteria y resolucion del arquero antes de tocar pesos.
##
## Etapas del embudo, por partido:
## - remates: todo intento con evento final (el espacial incluye bloqueados;
##   el abstracto no bloquea).
## - al arco: tiro_puerta y rebote (abstracto); tiro_puerta (espacial).
## - goles de juego: sin penales.
## Aparte, en el espacial: bloqueados, afuera, palo, cabezazos, libres,
## penales, arco desprotegido y la presion media del remate.
##
## Uso:
##   <godot> --path . --headless --script tests/_diag_embudo_remates.gd -- parejas=50 celda=0 salida=user://embudo_0
##
## `pesos=seccion.clave:valor,...` pisa pesos del json en memoria, para barrer
## sin editar el archivo. Ejemplo: pesos=tiro.geometria:10

const SEED := 97000
const ESCENARIOS := [[0, 0], [0, 3], [4, 4], [4, 7], [9, 9], [9, 6]]
const ESTILOS := [["Tiki taka", "Juego directo"], ["Presion alta", "Contragolpe"]]

var parejas := 50
var celda := -1
var ruta := ""


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		var partes := arg.split("=", true, 1)
		if partes.size() != 2:
			continue
		match partes[0]:
			"parejas": parejas = maxi(1, int(partes[1]))
			"celda": celda = int(partes[1])
			"salida": ruta = partes[1]
			"pesos": _pisar_pesos(partes[1])
	var filas: Array = []
	for i in range(ESCENARIOS.size()):
		if celda >= 0 and i != celda:
			continue
		var esc: Array = ESCENARIOS[i]
		var suma_e := {}
		var suma_a := {}
		var n := 0
		for indice in range(parejas):
			var estilos: Array = ESTILOS[indice % ESTILOS.size()]
			for vuelta in [false, true]:
				var e := _espacial(esc, estilos, SEED + indice, vuelta)
				var a := _abstracto(esc, estilos, SEED + indice, vuelta)
				filas.append({"division_a": esc[0] + 1, "division_b": esc[1] + 1,
					"semilla": SEED + indice, "vuelta": vuelta, "espacial": e, "abstracto": a})
				for k in e:
					suma_e[k] = float(suma_e.get(k, 0.0)) + float(e[k])
				for k in a:
					suma_a[k] = float(suma_a.get(k, 0.0)) + float(a[k])
				n += 1
		_imprimir(esc, suma_e, suma_a, n)
	if ruta != "":
		var archivo := FileAccess.open(ruta + ".json", FileAccess.WRITE)
		if archivo != null:
			archivo.store_string(JSON.stringify({"semilla": SEED, "parejas": parejas, "celda": celda,
				"motor_sha256": FileAccess.get_sha256("res://core/motor_espacial.gd"),
				"pesos_sha256": FileAccess.get_sha256("res://data/utility_pesos.json"),
				"filas": filas}, "\t"))
			archivo.close()
	quit()


func _pisar_pesos(texto: String) -> void:
	var w: Dictionary = MotorEspacial.pesos()
	for par in texto.split(","):
		var kv := par.split(":")
		var ruta_clave := kv[0].split(".")
		w[ruta_clave[0]][ruta_clave[1]] = float(kv[1])
		print("PESO %s = %s" % [kv[0], kv[1]])


func _equipos(esc: Array, estilos: Array, semilla: int) -> Array:
	var generador := RandomNumberGenerator.new()
	generador.seed = semilla
	var a := Team.generar("A", generador, 0, NivelDivision.potencial(esc[0]), "Uruguay", NivelDivision.realizacion(esc[0]))
	var b := Team.generar("B", generador, 400, NivelDivision.potencial(esc[1]), "Uruguay", NivelDivision.realizacion(esc[1]))
	a.estilo = estilos[0]
	b.estilo = estilos[1]
	return [a, b]


func _espacial(esc: Array, estilos: Array, semilla: int, vuelta: bool) -> Dictionary:
	var eq := _equipos(esc, estilos, semilla)
	var a: Team = eq[0]
	var b: Team = eq[1]
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var local: Team = b if vuelta else a
	var visita: Team = a if vuelta else b
	var res := MotorEspacial.simular(local, visita, rng, false, false, true)
	var m := {"goles": 0.0, "goles_a": 0.0, "remates": 0.0, "al_arco": 0.0, "goles_juego": 0.0,
		"bloqueados": 0.0, "afuera": 0.0, "palo": 0.0, "atajadas": 0.0, "penales": 0.0,
		"goles_penal": 0.0, "cabezazos": 0.0, "goles_cabeza": 0.0, "libres": 0.0,
		"goles_libre": 0.0, "desprotegido": 0.0, "presion_suma": 0.0, "cobertura_suma": 0.0,
		"distancia_suma": 0.0, "registrados": 0.0, "remates_a": 0.0,
		"pie_libres": 0.0, "pie_presion_suma": 0.0, "duelos": 0.0, "fuerza_suma": 0.0,
		"tecnica_suma": 0.0,
		"p0_n": 0.0, "p0_arco": 0.0, "p0_gol": 0.0, "p1_n": 0.0, "p1_arco": 0.0, "p1_gol": 0.0,
		"p2_n": 0.0, "p2_arco": 0.0, "p2_gol": 0.0,
		"d0_n": 0.0, "d0_gol": 0.0, "d1_n": 0.0, "d1_gol": 0.0, "d2_n": 0.0, "d2_gol": 0.0, "d3_n": 0.0, "d3_gol": 0.0}
	m["goles"] = float(res["goles_local"]) + float(res["goles_visitante"])
	m["goles_a"] = float(res["goles_visitante"] if vuelta else res["goles_local"])
	var por_id := {}
	for r in res["stats"].get("registro_remates", []):
		por_id[int(r["remate_id"])] = r
	for ev in res["eventos"]:
		var tipo: String = str(ev["tipo"])
		if tipo == "penal":
			m["penales"] += 1.0
			if str(ev["resultado"]) == "gol":
				m["goles_penal"] += 1.0
			continue
		if tipo != "tiro" and tipo != "tiro_puerta":
			continue
		m["remates"] += 1.0
		if str(ev["equipo"]) == "A":
			m["remates_a"] += 1.0
		var resultado: String = str(ev["resultado"])
		match resultado:
			"bloqueado": m["bloqueados"] += 1.0
			"afuera": m["afuera"] += 1.0
			"palo": m["palo"] += 1.0
			"atajada": m["atajadas"] += 1.0
		if tipo == "tiro_puerta":
			m["al_arco"] += 1.0
		var gol := tipo == "tiro_puerta" and resultado == "gol"
		if gol:
			m["goles_juego"] += 1.0
		var reg: Dictionary = por_id.get(int(ev.get("remate_id", -1)), {})
		if reg.is_empty():
			continue
		m["registrados"] += 1.0
		var ocasion: Dictionary = reg.get("ocasion", {})
		m["presion_suma"] += float(ocasion.get("presion", 0.0))
		m["cobertura_suma"] += float(ocasion.get("cobertura_arquero", 0.0))
		m["distancia_suma"] += float(reg.get("distancia", 0.0))
		if bool(ocasion.get("arco_desprotegido", false)):
			m["desprotegido"] += 1.0
		if tipo == "tiro_puerta":
			# Lo que llega al duelo con el arquero: factor de fuerza y tecnica.
			var ej: Dictionary = reg.get("ejecucion", {})
			m["duelos"] += 1.0
			m["fuerza_suma"] += float(ej.get("factor_fuerza", 1.0))
			m["tecnica_suma"] += float(reg.get("tiro", 0.0))
		if str(reg.get("atributo", "tiro")) == "tiro":
			# Remates de pie: presion sin el bloqueador (solo los no bloqueados)
			# y conversion por tramo de distancia (todos).
			var dist: float = float(reg.get("distancia", 0.0))
			var dk := "d0" if dist < 11.0 else ("d1" if dist < 18.0 else ("d2" if dist < 25.0 else "d3"))
			m[dk + "_n"] += 1.0
			if gol: m[dk + "_gol"] += 1.0
			if resultado != "bloqueado":
				var psb: float = float(ocasion.get("presion_sin_bloqueador", ocasion.get("presion", 0.0)))
				m["pie_libres"] += 1.0
				m["pie_presion_suma"] += psb
				var pk := "p0" if psb < 0.33 else ("p1" if psb < 0.66 else "p2")
				m[pk + "_n"] += 1.0
				if tipo == "tiro_puerta": m[pk + "_arco"] += 1.0
				if gol: m[pk + "_gol"] += 1.0
		match str(reg.get("atributo", "tiro")):
			"cabezazo":
				m["cabezazos"] += 1.0
				if gol: m["goles_cabeza"] += 1.0
			"tiros_libres":
				m["libres"] += 1.0
				if gol: m["goles_libre"] += 1.0
	return m


func _abstracto(esc: Array, estilos: Array, semilla: int, vuelta: bool) -> Dictionary:
	var eq := _equipos(esc, estilos, semilla)
	var a: Team = eq[0]
	var b: Team = eq[1]
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var res := MatchEngine.simular(b if vuelta else a, a if vuelta else b, rng)
	var m := {"goles": 0.0, "goles_a": 0.0, "remates": 0.0, "al_arco": 0.0, "goles_juego": 0.0,
		"afuera": 0.0, "palo": 0.0, "atajadas": 0.0, "rebotes": 0.0, "ataques": 0.0, "remates_a": 0.0}
	m["goles"] = float(res["goles_local"]) + float(res["goles_visitante"])
	m["goles_a"] = float(res["goles_visitante"] if vuelta else res["goles_local"])
	for ev in res["eventos"]:
		var tipo: String = str(ev["tipo"])
		var resultado: String = str(ev.get("resultado", ""))
		if tipo == "gambeta" and resultado == "tira":
			m["ataques"] += 1.0
		if tipo != "tiro" and tipo != "tiro_puerta" and tipo != "rebote":
			continue
		m["remates"] += 1.0
		if str(ev["equipo"]) == "A":
			m["remates_a"] += 1.0
		if tipo == "rebote":
			m["rebotes"] += 1.0
		if tipo == "tiro":
			if resultado == "palo": m["palo"] += 1.0
			else: m["afuera"] += 1.0
		else:
			m["al_arco"] += 1.0
			if resultado == "gol": m["goles_juego"] += 1.0
			else: m["atajadas"] += 1.0
	return m


func _imprimir(esc: Array, e: Dictionary, a: Dictionary, n: int) -> void:
	var f := func(d: Dictionary, k: String) -> float: return float(d.get(k, 0.0)) / float(n)
	print("== D%d/D%d, %d partidos ==" % [esc[0] + 1, esc[1] + 1, n])
	print("motor      goles  golesA remates remA  al_arco  goles_j  conv_arco  conv_rem  precision")
	for par in [["espacial", e], ["abstracto", a]]:
		var d: Dictionary = par[1]
		var rem: float = f.call(d, "remates")
		var arco: float = f.call(d, "al_arco")
		var gj: float = f.call(d, "goles_juego")
		print("%-9s %6.2f %6.2f %7.2f %5.2f %7.2f %8.2f %9.1f%% %8.1f%% %9.1f%%" % [par[0],
			f.call(d, "goles"), f.call(d, "goles_a"), rem, f.call(d, "remates_a"), arco, gj,
			100.0 * gj / maxf(arco, 0.001), 100.0 * gj / maxf(rem, 0.001), 100.0 * arco / maxf(rem, 0.001)])
	var reg: float = maxf(float(e.get("registrados", 0.0)), 1.0)
	print("espacial: bloq %.2f afuera %.2f palo %.2f atajadas %.2f | cabezazos %.2f (%.2f goles) libres %.2f (%.2f) penales %.2f (%.2f) | desprotegido %.3f | presion %.3f cobertura %.3f dist %.1f" % [
		f.call(e, "bloqueados"), f.call(e, "afuera"), f.call(e, "palo"), f.call(e, "atajadas"),
		f.call(e, "cabezazos"), f.call(e, "goles_cabeza"), f.call(e, "libres"), f.call(e, "goles_libre"),
		f.call(e, "penales"), f.call(e, "goles_penal"), f.call(e, "desprotegido"),
		float(e.get("presion_suma", 0.0)) / reg, float(e.get("cobertura_suma", 0.0)) / reg,
		float(e.get("distancia_suma", 0.0)) / reg])
	var pie: float = maxf(float(e.get("pie_libres", 0.0)), 1.0)
	var txt := "pie no bloqueados: presion media %.3f |" % (float(e.get("pie_presion_suma", 0.0)) / pie)
	for k in ["p0", "p1", "p2"]:
		var nk: float = maxf(float(e.get(k + "_n", 0.0)), 1.0)
		txt += " %s n=%d arco %.0f%% gol %.0f%% |" % [k, int(e.get(k + "_n", 0.0)), 100.0 * float(e.get(k + "_arco", 0.0)) / nk, 100.0 * float(e.get(k + "_gol", 0.0)) / nk]
	for k in ["d0", "d1", "d2", "d3"]:
		var nd: float = maxf(float(e.get(k + "_n", 0.0)), 1.0)
		txt += " %s n=%d gol %.0f%%" % [k, int(e.get(k + "_n", 0.0)), 100.0 * float(e.get(k + "_gol", 0.0)) / nd]
	print(txt)
	var du: float = maxf(float(e.get("duelos", 0.0)), 1.0)
	print("duelo con el arquero: factor_fuerza medio %.4f, atributo medio %.1f" % [
		float(e.get("fuerza_suma", 0.0)) / du, float(e.get("tecnica_suma", 0.0)) / du])
	print("abstracto: afuera %.2f palo %.2f atajadas %.2f rebotes %.2f ataques %.2f" % [
		f.call(a, "afuera"), f.call(a, "palo"), f.call(a, "atajadas"), f.call(a, "rebotes"), f.call(a, "ataques")])
