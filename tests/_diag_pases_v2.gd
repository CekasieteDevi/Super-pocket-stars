extends SceneTree

## Etapa 7 del Motor V2 (docs/motor_v2.md): cómo termina cada pase, por tipo.
## Lee CanchitaV2Nativa.registro_pases() de partidos con reglas, sin vista. No
## es un test: mide.
##
##   <godot> --path . --headless --script tests/_diag_pases_v2.gd -- partidos=60 a=4 b=4 semilla=97000
##
## `a` y `b`: división de cada equipo (0 = primera). `fisica=seccion.clave:valor,...`
## pisa data/fisica_v2.json en memoria.

const SEED := 97000
const ESTILOS := [["Tiki taka", "Juego directo"], ["Presión alta", "Contragolpe"]]
## DEC_* de motor_v2/cpp/src/cerebro/cerebro.h. 0 es el pase de primera, que
## no pasa por el cerebro.
const TIPOS := ["de primera", "conducir", "pase", "al hueco", "largo", "centro", "pared", "despeje", "remate"]
## ResultadoPase de motor_v2/cpp/src/canchita.h.
const RESULTADOS := ["receptor", "otro", "el mismo", "rival", "nadie", "arquero"]


func _init() -> void:
	var partidos := 60
	var a := 4
	var b := 4
	var semilla := SEED
	for arg in OS.get_cmdline_user_args():
		var p := arg.split("=", true, 1)
		if p.size() != 2:
			continue
		match p[0]:
			"partidos": partidos = maxi(1, int(p[1]))
			"a": a = int(p[1])
			"b": b = int(p[1])
			"semilla": semilla = int(p[1])
			"fisica": _pisar(FisicaV2.datos(), p[1])
	# Por tipo: cuántos, cómo terminan y lo que explica los que se pierden.
	var filas := {}
	var cabeza := {"controles": 0.0, "fallos": 0.0}
	# Por tipo y por tramo del margen que le dio el planeador: [pases, cortados].
	var tramos := {}
	for n in partidos:
		var e: Array = ESTILOS[n % ESTILOS.size()]
		var c: Object = CerebroV2.armar_partido(semilla + n, e[0], e[1], a, b, true)
		var pasos := 0
		while str(c.get_estado()["periodo"]) != "terminado" and pasos < 60 * 60 * 20:
			c.simular(600)
			pasos += 600
		for r in c.registro_pases():
			if int(r["resultado"]) < 0:
				continue
			var tipo: String = TIPOS[int(r["tipo"])]
			if not filas.has(tipo):
				filas[tipo] = {"n": 0.0, "res": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0], "atras": 0.0, "espaldas": 0.0,
					"espaldas_perdido": 0.0, "perdido": 0.0, "no_iba": 0.0, "lejos": 0.0, "iba_frac": 0.0, "dur": 0.0,
					"largo": 0.0, "al_punto": 0.0}
			var f: Dictionary = filas[tipo]
			var res := int(r["resultado"])
			var dura := maxf(float(int(r["paso_fin"]) - int(r["paso"])), 1.0)
			var desde: Vector2 = r["desde"]
			var meta: Vector2 = r["meta"]
			var ataca := 1.0 if int(r["equipo"]) == 0 else -1.0
			var de_espaldas := float(r["de_lado"]) > 0.6
			f["n"] += 1.0
			f["res"][res] += 1.0
			f["dur"] += dura / 60.0
			f["largo"] += desde.distance_to(meta)
			f["al_punto"] += float(r["receptor_al_punto_m"])
			var margen := float(r["margen"])
			var tramo := 0 if margen < 0.0 else (1 if margen < 0.25 else (2 if margen < 0.5 else (3 if margen < 1.0 else 4)))
			if not tramos.has(tipo):
				tramos[tipo] = [[0.0, 0.0], [0.0, 0.0], [0.0, 0.0], [0.0, 0.0], [0.0, 0.0]]
			tramos[tipo][tramo][0] += 1.0
			if res == 3:
				tramos[tipo][tramo][1] += 1.0
			if (meta.x - desde.x) * ataca < -1.0:
				f["atras"] += 1.0
			if de_espaldas:
				f["espaldas"] += 1.0
			if res >= 2:
				f["perdido"] += 1.0
				f["iba_frac"] += float(r["pasos_receptor_iba"]) / dura
				if de_espaldas:
					f["espaldas_perdido"] += 1.0
				if not bool(r["receptor_iba"]):
					f["no_iba"] += 1.0
				if float(r["receptor_a_pelota_m"]) > 6.0:
					f["lejos"] += 1.0
		var k: Dictionary = c.contadores()
		for clave in k:
			if str(clave).begins_with("gestos_") or str(clave).begins_with("fallos_") or clave in ["remates_cabeza",
					"goles_cabeza", "remates_primera", "remates", "paradas_corner"]:
				cabeza[clave] = float(cabeza.get(clave, 0.0)) + float(k[clave])
	print("[pases] D%d/D%d, %d partidos, semilla %d. Por partido; los %% son del tipo." % [a + 1, b + 1, partidos, semilla])
	print("[pases] %-11s %6s | %8s %6s %8s %6s %6s %7s | %6s %6s %8s | %7s %7s %7s | %6s %6s" % ["tipo", "n", "receptor",
		"otro", "el mismo", "rival", "nadie", "arquero", "atrás", "espal.", "esp.perd", "no iba", "lejos", "iba%", "largo", "seg"])
	var total := {"n": 0.0, "ok": 0.0}
	for tipo in TIPOS:
		if not filas.has(tipo):
			continue
		var f: Dictionary = filas[tipo]
		var n: float = f["n"]
		var perdido: float = maxf(f["perdido"], 1.0)
		total["n"] += n
		total["ok"] += f["res"][0] + f["res"][1]
		print("[pases] %-11s %6.2f | %7.0f%% %5.0f%% %7.0f%% %5.0f%% %5.0f%% %6.0f%% | %5.0f%% %5.0f%% %7.0f%% | %6.0f%% %6.0f%% %6.0f%% | %6.1f %6.2f" % [
			tipo, n / partidos, 100.0 * f["res"][0] / n, 100.0 * f["res"][1] / n, 100.0 * f["res"][2] / n,
			100.0 * f["res"][3] / n, 100.0 * f["res"][4] / n, 100.0 * f["res"][5] / n, 100.0 * f["atras"] / n, 100.0 * f["espaldas"] / n,
			100.0 * f["espaldas_perdido"] / maxf(f["espaldas"], 1.0), 100.0 * f["no_iba"] / perdido,
			100.0 * f["lejos"] / perdido, 100.0 * f["iba_frac"] / perdido, f["largo"] / n, f["dur"] / n])
	print("[pases] Margen del planeador al patear (s): pases por partido y %% que corta un rival, por tramo.")
	print("[pases] %-11s %14s %14s %14s %14s %14s" % ["tipo", "< 0", "0 a 0,25", "0,25 a 0,5", "0,5 a 1", "> 1"])
	for tipo in TIPOS:
		if not tramos.has(tipo):
			continue
		var t := "[pases] %-11s" % tipo
		for tramo in tramos[tipo]:
			t += " %7.2f (%3.0f%%)" % [tramo[0] / partidos, 100.0 * tramo[1] / maxf(tramo[0], 1.0)]
		print(t)
	print("[pases] Gestos de recibir o rematar por partido, los que erran, y de esos: lejos en el piso (y a cuántos metros) o a otra altura.")
	for parte in ["pie", "muslo", "pecho", "cabeza"]:
		var g: float = maxf(cabeza.get("gestos_" + parte, 0.0), 1.0)
		var fa: float = cabeza.get("fallos_" + parte, 0.0)
		print("[pases] %-7s %6.2f gestos, erra %3.0f%% | lejos %3.0f%% (%.2f m) | altura %3.0f%%" % [parte, g / partidos,
			100.0 * fa / g, 100.0 * cabeza.get("fallos_lejos_" + parte, 0.0) / maxf(fa, 1.0),
			cabeza.get("fallos_metros_" + parte, 0.0) / maxf(cabeza.get("fallos_lejos_" + parte, 0.0), 1.0),
			100.0 * cabeza.get("fallos_altura_" + parte, 0.0) / maxf(fa, 1.0)])
	print("[pases] Por partido: remates %.2f, de primera %.2f, de cabeza %.2f (goles %.2f), córners %.2f" % [
		cabeza.get("remates", 0.0) / partidos, cabeza.get("remates_primera", 0.0) / partidos,
		cabeza.get("remates_cabeza", 0.0) / partidos, cabeza.get("goles_cabeza", 0.0) / partidos,
		cabeza.get("paradas_corner", 0.0) / partidos])
	print("[pases] total %.1f por partido, llegan a un compañero %.0f%%" % [total["n"] / partidos, 100.0 * total["ok"] / maxf(total["n"], 1.0)])
	print("[pases] atrás: hacia su arco. espal.: de espaldas a adonde la manda. esp.perd: de esos, los que no llegan a un compañero.")
	print("[pases] De los que no llegan (el mismo, rival, nadie): no iba = el receptor no iba a la pelota al terminar; lejos = estaba a más de 6 m; iba%% = parte del pase en que iba.")
	quit()


func _pisar(datos: Dictionary, texto: String) -> void:
	for par in texto.split(","):
		var kv := par.split(":")
		var clave := kv[0].split(".")
		datos[clave[0]][clave[1]] = float(kv[1])
		print("FISICA %s = %s" % [kv[0], kv[1]])
