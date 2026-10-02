extends SceneTree

## Etapa 7 del Motor V2 (docs/motor_v2.md): el reporte de calibración. Juega
## los MISMOS planteles con la MISMA semilla en el Motor V2 (con reglas, sin
## vista) y en el motor espacial, ida y vuelta, y compara por partido: goles,
## remates, posesión, pases, faltas, tarjetas, offside, penales y cuánto gana
## el mejor equipo. No es un test: mide.
##
##   <godot> --path . --headless --script tests/_diag_calibracion_v2.gd -- parejas=100 escenario=0 semilla=97000 salida=user://calibracion_v2_0
##
## `escenario`: índice de ESCENARIOS (-1 = todos). `parejas`: cada pareja son
## dos partidos (ida y vuelta). `motor=v2|espacial|ambos`.
## `fisica=seccion.clave:valor,...` y `pesos=seccion.clave:valor,...` pisan en
## memoria data/fisica_v2.json y data/utility_pesos.json, para barrer un
## parámetro sin editar el archivo.

const SEED := 97000
## Las diez divisiones parejas (0 = primera), las tres desparejas de
## tests/_diag_embudo_remates.gd (tres divisiones de diferencia: un cruce de
## copa) y tres de divisiones vecinas (unos 5 puntos de media: lo que separa
## al mejor del peor de una liga). En las desparejas A es el de mejor división
## en dos y el de peor en una, como en tests/_diag_realismo.gd.
const ESCENARIOS := [[0, 0], [1, 1], [2, 2], [3, 3], [4, 4], [5, 5], [6, 6], [7, 7], [8, 8], [9, 9],
	[0, 3], [4, 7], [9, 6], [0, 1], [4, 5], [9, 8]]
const ESTILOS := [["Tiki taka", "Juego directo"], ["Presión alta", "Contragolpe"]]
## Lo que se compara, en el orden del reporte.
const METRICAS := ["goles", "remates", "al_arco", "posesion_a", "pases", "pases_completos", "faltas", "amarillas",
	"rojas", "offsides", "penales", "puntos_a", "dif_a"]

## Minutos de verdad que puede durar un partido del V2 (dura unos 5): pasado
## esto quedó colgado (una pelota parada que no se saca; el reloj la espera).
const PASOS_TOPE := 60 * 60 * 20

## El rango de cada cosa alrededor del motor espacial: [fracción, piso]. Pasa
## si la diferencia no supera la fracción del valor del espacial ni, para lo
## que pasa pocas veces por partido, el piso. Con 200 partidos el error de la
## media de los goles es 0,1 (5%): un rango más fino mediría ruido.
const RANGOS := {
	"goles": [0.2, 0.0], "remates": [0.2, 0.0], "al_arco": [0.25, 0.0], "posesion_a": [0.0, 5.0],
	"pases": [0.25, 0.0], "pases_completos": [0.2, 0.0], "faltas": [0.25, 0.0], "amarillas": [0.3, 0.3],
	"rojas": [0.0, 0.08], "offsides": [0.0, 0.2], "penales": [0.0, 0.1], "puntos_a": [0.0, 0.3], "dif_a": [0.2, 0.4],
}

var parejas := 10
var escenario := -1
var semilla := SEED
var motor := "ambos"
var ruta := ""


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		var partes := arg.split("=", true, 1)
		if partes.size() != 2:
			continue
		match partes[0]:
			"parejas": parejas = maxi(1, int(partes[1]))
			"escenario": escenario = int(partes[1])
			"semilla": semilla = int(partes[1])
			"motor": motor = partes[1]
			"salida": ruta = partes[1]
			"pesos": _pisar(MotorEspacial.pesos(), partes[1], "PESO")
			"fisica": _pisar(FisicaV2.datos(), partes[1], "FISICA")
	var celdas: Array = []
	for i in ESCENARIOS.size():
		if escenario >= 0 and i != escenario:
			continue
		var esc: Array = ESCENARIOS[i]
		var celda := {"division_a": esc[0] + 1, "division_b": esc[1] + 1, "partidos": parejas * 2}
		for nombre in ["v2", "espacial"]:
			if motor != "ambos" and motor != nombre:
				continue
			var suma := {}
			var cuadrados := {}
			var t0 := Time.get_ticks_msec()
			for indice in parejas:
				var estilos: Array = ESTILOS[indice % ESTILOS.size()]
				for vuelta in [false, true]:
					var m: Dictionary = _v2(esc, estilos, semilla + indice, vuelta) if nombre == "v2" \
						else _espacial(esc, estilos, semilla + indice, vuelta)
					for k in m:
						suma[k] = float(suma.get(k, 0.0)) + float(m[k])
						cuadrados[k] = float(cuadrados.get(k, 0.0)) + float(m[k]) * float(m[k])
			var n := float(parejas * 2)
			var media := {}
			var error := {}
			for k in suma:
				media[k] = suma[k] / n
				# Error estándar de la media: lo que se mueve el número solo por
				# cambiar de semilla. Una diferencia menor a dos errores es ruido.
				error[k] = sqrt(maxf(cuadrados[k] / n - media[k] * media[k], 0.0) / n)
			celda[nombre] = media
			celda[nombre + "_error"] = error
			celda[nombre + "_seg"] = (Time.get_ticks_msec() - t0) / 1000.0 / n
		_imprimir(celda)
		celdas.append(celda)
	if ruta != "":
		var archivo := FileAccess.open(ruta + ".json", FileAccess.WRITE)
		if archivo != null:
			archivo.store_string(JSON.stringify({"semilla": semilla, "parejas": parejas, "celdas": celdas}, "\t"))
			archivo.close()
	quit()


func _pisar(datos: Dictionary, texto: String, etiqueta: String) -> void:
	for par in texto.split(","):
		var kv := par.split(":")
		var clave := kv[0].split(".")
		datos[clave[0]][clave[1]] = float(kv[1])
		print("%s %s = %s" % [etiqueta, kv[0], kv[1]])


## Los mismos planteles que tests/_diag_embudo_remates.gd. Cada corrida los
## arma de nuevo: el partido muta al Team.
func _equipos(esc: Array, estilos: Array, semilla_partido: int) -> Array:
	var generador := RandomNumberGenerator.new()
	generador.seed = semilla_partido
	var a := Team.generar("A", generador, 0, NivelDivision.potencial(esc[0]), "Uruguay", NivelDivision.realizacion(esc[0]))
	var b := Team.generar("B", generador, 400, NivelDivision.potencial(esc[1]), "Uruguay", NivelDivision.realizacion(esc[1]))
	a.estilo = estilos[0]
	b.estilo = estilos[1]
	return [a, b]


func _resultado(m: Dictionary, goles_a: float, goles_b: float) -> void:
	m["goles"] = goles_a + goles_b
	m["dif_a"] = goles_a - goles_b
	m["puntos_a"] = 3.0 if goles_a > goles_b else (1.0 if goles_a == goles_b else 0.0)
	m["gana_a"] = 1.0 if goles_a > goles_b else 0.0
	m["empate"] = 1.0 if goles_a == goles_b else 0.0


func _v2(esc: Array, estilos: Array, semilla_partido: int, vuelta: bool) -> Dictionary:
	var eq := _equipos(esc, estilos, semilla_partido)
	var c: Object = CerebroV2.armar(eq[1] if vuelta else eq[0], eq[0] if vuelta else eq[1], semilla_partido, true)
	var pasos := 0
	# Un partido que no termina no cuelga la medición: se corta y se cuenta.
	while str(c.get_estado()["periodo"]) != "terminado" and pasos < PASOS_TOPE:
		c.simular(600)
		pasos += 600
	var k: Dictionary = c.contadores()
	var lado_a := "1" if vuelta else "0"
	var lado_b := "0" if vuelta else "1"
	var m := {}
	_resultado(m, float(k["goles_" + lado_a]), float(k["goles_" + lado_b]))
	m["remates"] = float(k["remates"])
	m["al_arco"] = float(k["remates_gol"]) + float(k["remates_atajado"])
	m["posesion_a"] = 100.0 * float(k["posesion_" + lado_a]) / maxf(float(k["posesion_0"]) + float(k["posesion_1"]), 1.0)
	# Sin los despejes: el motor espacial no los cuenta como pases intentados.
	m["pases"] = float(k["pases"]) - float(k["pases_despeje"])
	m["despejes"] = float(k["pases_despeje"])
	m["pases_completos"] = float(k["completados"]) + float(k["completados_otro"])
	m["pases_globo"] = float(k["pases_globo"])
	m["faltas"] = float(k["faltas_0"]) + float(k["faltas_1"])
	m["amarillas"] = float(k["amarillas_0"]) + float(k["amarillas_1"])
	m["rojas"] = float(k["rojas_0"]) + float(k["rojas_1"])
	m["offsides"] = float(k["offsides_cobrados_0"]) + float(k["offsides_cobrados_1"])
	m["penales"] = float(k["penales"])
	m["corners"] = float(k.get("paradas_corner", 0))
	m["laterales"] = float(k.get("paradas_lateral", 0))
	m["minutos"] = pasos / 3600.0
	m["colgado"] = 1.0 if pasos >= PASOS_TOPE else 0.0
	m["correcciones"] = float(k["correcciones"])
	m["saltos_pelota"] = float(k["saltos_pelota"])
	return m


func _espacial(esc: Array, estilos: Array, semilla_partido: int, vuelta: bool) -> Dictionary:
	var eq := _equipos(esc, estilos, semilla_partido)
	var a: Team = eq[0]
	var b: Team = eq[1]
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla_partido
	var res := MotorEspacial.simular(b if vuelta else a, a if vuelta else b, rng)
	var st: Dictionary = res["stats"]
	var lado_a := "away" if vuelta else "home"
	var m := {}
	_resultado(m, float(res["goles_visitante"] if vuelta else res["goles_local"]),
		float(res["goles_local"] if vuelta else res["goles_visitante"]))
	var al_arco := 0.0
	for ev in res["eventos"]:
		if str(ev["tipo"]) == "tiro_puerta":
			al_arco += 1.0
	m["remates"] = float(st["tiros"]["home"]) + float(st["tiros"]["away"])
	m["al_arco"] = al_arco
	m["posesion_a"] = 100.0 * float(st["posesion"][lado_a]) / maxf(float(st["posesion"]["home"]) + float(st["posesion"]["away"]), 1.0)
	m["pases"] = float(st["pase_detalle"]["intentos"])
	m["pases_completos"] = float(st["pases"]["home"]) + float(st["pases"]["away"])
	m["faltas"] = float(st["faltas"])
	m["amarillas"] = float(_contar(a.amarillas_partido)) + float(_contar(b.amarillas_partido))
	m["rojas"] = float(a.expulsados_partido.size()) + float(b.expulsados_partido.size())
	m["offsides"] = float(st["offsides"])
	m["penales"] = float(st["penales"])
	return m


## Lo que pide la etapa 7: goles, remates, posesión, pases, faltas y tarjetas,
## y que el mejor equipo gane lo que tiene que ganar. Al arco, offside y
## penales se muestran y no cuentan. Puntos y diferencia de gol cuentan solo
## si las divisiones son distintas: en un partido parejo no hay mejor equipo y
## lo que se ve es el ruido de quién quedó como A.
func _cuenta(metrica: String, celda: Dictionary) -> bool:
	if metrica in ["al_arco", "offsides", "penales"]:
		return false
	if metrica in ["puntos_a", "dif_a"]:
		return celda["division_a"] != celda["division_b"]
	return true


func _contar(cuentas: Dictionary) -> int:
	var total := 0
	for id in cuentas:
		total += int(cuentas[id])
	return total


func _imprimir(celda: Dictionary) -> void:
	print("[calibracion] == D%d/D%d, %d partidos, semilla %d ==" % [celda["division_a"], celda["division_b"],
		celda["partidos"], semilla])
	var v: Dictionary = celda.get("v2", {})
	var e: Dictionary = celda.get("espacial", {})
	print("[calibracion]   %-16s %9s %7s %9s %7s %7s" % ["", "V2", "±", "espacial", "±", "V2/esp"])
	var afuera := 0
	var cuentan := 0
	for k in METRICAS:
		var texto := "[calibracion]   %-16s" % k
		texto += (" %9.2f %7.2f" % [v[k], celda["v2_error"][k]]) if v.has(k) else " %9s %7s" % ["-", "-"]
		texto += (" %9.2f %7.2f" % [e[k], celda["espacial_error"][k]]) if e.has(k) else " %9s %7s" % ["-", "-"]
		if v.has(k) and e.has(k):
			texto += (" %7.2f" % (float(v[k]) / float(e[k]))) if absf(float(e[k])) > 0.001 else " %7s" % "-"
			var rango: Array = RANGOS[k]
			var pasa: bool = absf(float(v[k]) - float(e[k])) <= maxf(float(rango[0]) * absf(float(e[k])), float(rango[1]))
			if not _cuenta(k, celda):
				texto += "  (no cuenta)"
			else:
				texto += "  ok" if pasa else "  FUERA"
				cuentan += 1
				if not pasa:
					afuera += 1
		print(texto)
	if not v.is_empty() and not e.is_empty():
		print("[calibracion]   %s: %d de %d fuera de rango" % ["PASA" if afuera == 0 else "NO PASA", afuera, cuentan])
	if not v.is_empty():
		print("[calibracion]   V2: gana A %.0f%% empata %.0f%% | globos %.0f%% de los pases | córners %.1f laterales %.1f | %.1f min de verdad | correcciones %d saltos %d colgados %d | %.2f s por partido" % [
			100.0 * v["gana_a"], 100.0 * v["empate"], 100.0 * v["pases_globo"] / maxf(v["pases"], 1.0), v["corners"],
			v["laterales"], v["minutos"], int(v["correcciones"] * celda["partidos"]),
			int(v["saltos_pelota"] * celda["partidos"]), int(v["colgado"] * celda["partidos"]), celda["v2_seg"]])
	if not e.is_empty():
		print("[calibracion]   espacial: gana A %.0f%% empata %.0f%%" % [100.0 * e["gana_a"], 100.0 * e["empate"]])
