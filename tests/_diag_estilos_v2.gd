extends SceneTree

## Etapa 7 del Motor V2 (docs/motor_v2.md): la identidad de juego. Los mismos
## planteles y las mismas semillas con cada estilo de Estilos.LISTA en el
## local, contra un visitante de "Juego directo". Lo que cambia de una fila a
## otra es solo el estilo: si las filas se parecen, el estilo no se ve en la
## cancha. No es un test: mide.
##
##   <godot> --path . --headless --script tests/_diag_estilos_v2.gd -- partidos=40 division=4 semilla=97000
##
## `fisica=seccion.clave:valor,...` pisa data/fisica_v2.json en memoria.

const SEED := 97000
const RIVAL := "Juego directo"
const MEDIO_LARGO_M := 52.5
## Cada cuántos pasos se mira dónde está parado el equipo (0,5 s).
const CADA_PASOS := 30
## Tipos de pase del registro (DEC_* del cerebro): el pelotazo y el centro.
const TIPO_LARGO := 4
const TIPO_CENTRO := 5
const TIPO_DESPEJE := 7
## Un pase es hacia adelante si gana más de esto hacia el arco rival.
const ADELANTE_M := 3.0


func _init() -> void:
	var partidos := 40
	var division := 4
	var semilla := SEED
	# Con todos=1: cada estilo contra cada uno de los otros, de local y de
	# visitante. Es la medida del balance, y el cuadro de cruces dice qué
	# estilo le gana a cuál por cómo juega.
	var todos := false
	for arg in OS.get_cmdline_user_args():
		var p := arg.split("=", true, 1)
		if p.size() != 2:
			continue
		match p[0]:
			"partidos": partidos = maxi(1, int(p[1]))
			"division": division = int(p[1])
			"semilla": semilla = int(p[1])
			"fisica": _pisar(FisicaV2.datos(), p[1])
			"todos": todos = int(p[1]) == 1
	if todos:
		_todos_contra_todos(partidos, division, semilla)
		quit()
		return
	print("[estilos] D%d, %d partidos por estilo, semilla %d. El local con cada estilo contra %s. Por partido, del local." % [
		division + 1, partidos, semilla, RIVAL])
	print("[estilos] %-14s %7s %6s %6s %7s %7s %7s %7s %7s %7s %7s %6s %6s" % ["estilo", "poses.", "pases", "compl.", "largo m",
		"adel. %", "pelot.", "centros", "condu.", "remat.", "goles", "contra", "bloque"])
	for estilo in Estilos.LISTA:
		var k := {"posesion": 0.0, "pases": 0.0, "completos": 0.0, "largo": 0.0, "adelante": 0.0, "pelotazos": 0.0,
			"centros": 0.0, "remates": 0.0, "goles": 0.0, "contra": 0.0, "bloque": 0.0, "muestras": 0.0, "conduce": 0.0}
		for n in partidos:
			var c: Object = CerebroV2.armar_partido(semilla + n, estilo, RIVAL, division, division, true)
			var equipos: PackedInt32Array = c.get_equipos()
			var arqueros: PackedInt32Array = c.get_arqueros()
			var pasos := 0
			while str(c.get_estado()["periodo"]) != "terminado" and pasos < 60 * 60 * 20:
				c.simular(CADA_PASOS)
				pasos += CADA_PASOS
				if str(c.get_estado()["parada"]) != "nada":
					continue
				# El equipo 0 ataca siempre hacia +x en el motor. Con la pelota,
				# cuántos pasos la conduce; sin ella, a qué altura para el bloque.
				var poseedor := int(c.get_poseedor())
				if int(c.get_equipo_con_pelota()) == 0:
					if poseedor >= 0 and int(equipos[poseedor]) == 0 and int(c.get_receptor()) < 0:
						k["conduce"] += 1.0
					continue
				var pos: PackedVector2Array = c.get_pos()
				var suma := 0.0
				var cuantos := 0
				for i in pos.size():
					if int(equipos[i]) == 0 and int(arqueros[i]) == 0:
						suma += pos[i].x
						cuantos += 1
				if cuantos > 0:
					k["bloque"] += suma / cuantos + MEDIO_LARGO_M
					k["muestras"] += 1.0
			var cuenta: Dictionary = c.contadores()
			var total := float(cuenta["posesion_0"]) + float(cuenta["posesion_1"])
			k["posesion"] += 100.0 * float(cuenta["posesion_0"]) / maxf(total, 1.0)
			k["remates"] += float(cuenta["remates_0"])
			k["goles"] += float(cuenta["goles_0"])
			k["contra"] += float(cuenta["goles_1"])
			for r in c.registro_pases():
				if int(r["equipo"]) != 0 or int(r["tipo"]) == TIPO_DESPEJE:
					continue
				k["pases"] += 1.0
				var desde: Vector2 = r["desde"]
				var meta: Vector2 = r["meta"]
				k["largo"] += desde.distance_to(meta)
				if meta.x - desde.x > ADELANTE_M:
					k["adelante"] += 1.0
				# Resultados 0 y 1: lo recibe el buscado u otro compañero.
				if int(r["resultado"]) <= 1:
					k["completos"] += 1.0
				if int(r["tipo"]) == TIPO_LARGO:
					k["pelotazos"] += 1.0
				elif int(r["tipo"]) == TIPO_CENTRO:
					k["centros"] += 1.0
		var pases := maxf(k["pases"], 1.0)
		print("[estilos] %-14s %6.1f%% %6.1f %5.0f%% %7.1f %6.0f%% %7.2f %7.2f %6.1fs %7.2f %7.2f %6.2f %5.1fm" % [estilo,
			k["posesion"] / partidos, k["pases"] / partidos, 100.0 * k["completos"] / pases, k["largo"] / pases,
			100.0 * k["adelante"] / pases, k["pelotazos"] / partidos, k["centros"] / partidos,
			k["conduce"] * CADA_PASOS / 60.0 / partidos, k["remates"] / partidos, k["goles"] / partidos,
			k["contra"] / partidos, k["bloque"] / maxf(k["muestras"], 1.0)])
	print("[estilos] poses.: posesión. compl.: pases que llegan a un compañero. adel.: pases que ganan más de 3 m. pelot.: pelotazos. condu.: segundos con la pelota en los pies. bloque: metros desde su línea de fondo a los que se para el equipo sin la pelota.")
	quit()


func _todos_contra_todos(partidos: int, division: int, semilla: int) -> void:
	var k := {}
	# cruces[a][b]: goles de diferencia de `a` contra `b`, sumados.
	var cruces := {}
	for e in Estilos.LISTA:
		k[e] = {"n": 0.0, "puntos": 0.0, "favor": 0.0, "contra": 0.0, "posesion": 0.0, "remates": 0.0, "pases": 0.0}
		cruces[e] = {}
		for rival in Estilos.LISTA:
			cruces[e][rival] = 0.0
	for a in Estilos.LISTA:
		for b in Estilos.LISTA:
			if a == b:
				continue
			for n in partidos:
				var c: Object = CerebroV2.armar_partido(semilla + n, a, b, division, division, true)
				var pasos := 0
				while str(c.get_estado()["periodo"]) != "terminado" and pasos < 60 * 60 * 20:
					c.simular(600)
					pasos += 600
				var cuenta: Dictionary = c.contadores()
				var goles := [float(cuenta["goles_0"]), float(cuenta["goles_1"])]
				var total := float(cuenta["posesion_0"]) + float(cuenta["posesion_1"])
				var pases := [0.0, 0.0]
				for r in c.registro_pases():
					if int(r["tipo"]) != TIPO_DESPEJE:
						pases[int(r["equipo"])] += 1.0
				var estilos := [a, b]
				for lado in 2:
					var d: Dictionary = k[estilos[lado]]
					d["n"] += 1.0
					d["favor"] += goles[lado]
					cruces[estilos[lado]][estilos[1 - lado]] += goles[lado] - goles[1 - lado]
					d["contra"] += goles[1 - lado]
					d["puntos"] += 3.0 if goles[lado] > goles[1 - lado] else (1.0 if goles[lado] == goles[1 - lado] else 0.0)
					d["posesion"] += 100.0 * float(cuenta["posesion_%d" % lado]) / maxf(total, 1.0)
					d["remates"] += float(cuenta["remates_%d" % lado])
					d["pases"] += pases[lado]
	print("[estilos] Todos contra todos, D%d, %d partidos por cruce, semilla %d. Por partido." % [division + 1, partidos, semilla])
	print("[estilos] %-14s %7s %7s %7s %7s %7s %7s %7s" % ["estilo", "puntos", "favor", "contra", "dif.", "poses.", "remat.", "pases"])
	for e in Estilos.LISTA:
		var d: Dictionary = k[e]
		var n: float = maxf(d["n"], 1.0)
		print("[estilos] %-14s %7.2f %7.2f %7.2f %+7.2f %6.1f%% %7.2f %7.1f" % [e, d["puntos"] / n, d["favor"] / n, d["contra"] / n,
			(d["favor"] - d["contra"]) / n, d["posesion"] / n, d["remates"] / n, d["pases"] / n])
	# Cada cruce se juega de local y de visitante: 2 × partidos.
	print("[estilos] Cruces: goles de diferencia por partido de la fila contra la columna (%d partidos por cruce)." % (partidos * 2))
	var cabecera := "[estilos] %-14s" % ""
	for rival in Estilos.LISTA:
		cabecera += " %13s" % rival
	print(cabecera)
	for e in Estilos.LISTA:
		var fila := "[estilos] %-14s" % e
		for rival in Estilos.LISTA:
			fila += (" %13s" % "-") if rival == e else (" %+13.2f" % (float(cruces[e][rival]) / (partidos * 2.0)))
		print(fila)


func _pisar(datos: Dictionary, texto: String) -> void:
	for par in texto.split(","):
		var kv := par.split(":")
		var clave := kv[0].split(".")
		datos[clave[0]][clave[1]] = float(kv[1])
		print("FISICA %s = %s" % [kv[0], kv[1]])
