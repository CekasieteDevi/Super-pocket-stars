extends SceneTree

## Motor V2 (docs/motor_v2.md, etapa 6, revisión visual): mide lo que el
## usuario vio mal en el partido, para comparar antes y después de cada arreglo
## con la misma semilla.
## - Controles: a qué rapidez sale la pelota, cuánto se aleja del que la
##   controló y quién la toca después ("la pelota tiene manteca").
## - Después del control sin rivales cerca: a qué rapidez anda el que la
##   controló y cuánto tiempo tiene la pelota entre las piernas.
## - Frenada: metros que recorre un jugador desde que corre hasta que queda
##   parado ("juegan en hielo").
## - Peleas lejos de la pelota: segundos con dos rivales encimados a más de
##   LEJOS_M de la pelota.
## - Saque del arquero con la mano: cuántos terminan en lateral.
##
##   <godot> --path . --headless --script tests/_diag_sensaciones_v2.gd -- [semilla=N] [partidos=N] [minutos=N]

const SEED := 20261010
const PASO_SEG := 1.0 / 60.0
## Seguimiento de un control: hasta el toque siguiente o este tope.
const SEGUIR_SEG := 4.0
## "Sin rivales cerca".
const LIBRE_M := 6.0
const VENTANA_LIBRE_SEG := 1.5
## Pelota entre las piernas: su centro adentro del radio de las piernas más el suyo.
const ENTRE_PIERNAS_M := 0.31
const LEJOS_M := 10.0
const ENCIMADOS_M := 0.8
## Frenada: de más de CORRE_MS a menos de PARADO_MS.
const CORRE_MS := 5.0
const PARADO_MS := 0.5
const SAQUE_SEGUIR_SEG := 8.0


func _init() -> void:
	var semilla := SEED
	var partidos := 3
	var minutos := 10.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("semilla="):
			semilla = int(a.split("=")[1])
		elif a.begins_with("partidos="):
			partidos = int(a.split("=")[1])
		elif a.begins_with("minutos="):
			minutos = float(a.split("=")[1])
	var m := {"salida_ms": [], "separacion_m": [], "hasta_toque_seg": [], "rapidez_control": [], "libre_rapidez": [],
		"libre_entre_piernas_seg": [], "frenada_m": [], "frenada_seg": []}
	var sigue := {"mismo": 0, "companero": 0, "rival": 0, "nadie": 0}
	var saques := {"total": 0, "lateral": 0, "companero": 0, "rival": 0, "otro": 0}
	var de_arco := {"total": 0, "lateral": 0, "companero": 0, "rival": 0, "otro": 0}
	var pelea := {"controlada": 0.0, "pase": 0.0, "suelta": 0.0}
	var pelea_seg := 0.0
	# Controles y cuántos se pierden (la toca un rival, sale o queda suelta) según el rival más cercano.
	var por_presion := {"apretado": [0, 0], "medio": [0, 0], "libre": [0, 0]}
	var jugado_seg := 0.0
	for n in partidos:
		var c: Object = CerebroV2.armar_partido(semilla + n, "", "", -1, -1, true)
		var total := int(minutos * 3600.0)
		var k_previo: Dictionary = c.contadores()
		var control := {}
		var saque := {}
		var arco := {}
		var frenando := {}
		for paso in total:
			c.avanzar()
			if str(c.get_estado()["periodo"]) == "terminado":
				break
			var k: Dictionary = c.contadores()
			var pos: PackedVector2Array = c.get_pos()
			var rapidez: PackedFloat32Array = c.get_rapidez()
			var equipos: PackedInt32Array = c.get_equipos()
			var bola: Vector3 = c.get_pelota_pos()
			var bola2 := Vector2(bola.x, bola.z)
			var parada := str(c.get_estado()["parada"])
			var toques := int(k["pases"]) + int(k["conducciones"]) + int(k["controles"]) + int(k["remates"])
			var toques_previos := int(k_previo["pases"]) + int(k_previo["conducciones"]) + int(k_previo["controles"]) \
				+ int(k_previo["remates"])
			var toco: int = c.get_ultimo_toque()
			if parada == "nada":
				jugado_seg += PASO_SEG
			# --- El control en seguimiento ---
			if not control.is_empty():
				var i: int = control["i"]
				var fin := ""
				if i >= pos.size() or parada != "nada":
					fin = "nadie"
				elif toques != toques_previos:
					fin = "mismo" if toco == i else ("companero" if toco >= 0 and equipos[toco] == control["equipo"] else "rival")
				elif float(paso - int(control["paso"])) * PASO_SEG > SEGUIR_SEG:
					fin = "nadie"
				else:
					control["separacion"] = maxf(control["separacion"], pos[i].distance_to(bola2))
					var t := float(paso - int(control["paso"])) * PASO_SEG
					if control["libre"] and t <= VENTANA_LIBRE_SEG:
						control["suma_rapidez"] += rapidez[i]
						control["pasos"] += 1
						if pos[i].distance_to(bola2) < ENTRE_PIERNAS_M:
							control["entre_piernas"] += PASO_SEG
				if fin != "":
					sigue[fin] += 1
					var tramo: String = "apretado" if float(control["cerca"]) < 3.0 else ("libre" if control["libre"] else "medio")
					por_presion[tramo][0] += 1
					if fin == "rival" or fin == "nadie":
						por_presion[tramo][1] += 1
						if tramo == "libre" and _detalles < DETALLES:
							_detalles += 1
							print("[sensaciones]    perdido libre: %s a los %.2f s, salió a %.1f m/s, el jugador iba a %.1f m/s, ángulo entre los dos %.0f°, separación %.1f m, parte %s, rival a %.1f m, pelota venía a %.1f m/s alto %.2f, parada %s" % [
								fin, float(paso - int(control["paso"])) * PASO_SEG, control["salida"], control["corria"],
								control["angulo"], control["separacion"], control["parte"], control["cerca"], control["venia"], control["alto"], parada])
					m["separacion_m"].append(control["separacion"])
					m["hasta_toque_seg"].append(float(paso - int(control["paso"])) * PASO_SEG)
					if control["libre"] and int(control["pasos"]) > 0:
						m["libre_rapidez"].append(float(control["suma_rapidez"]) / float(control["pasos"]))
						m["libre_entre_piernas_seg"].append(control["entre_piernas"])
					control = {}
			# --- Un control nuevo ---
			if int(k["controles"]) > int(k_previo["controles"]) and toco >= 0 and toco < pos.size() \
					and int(k["entradas_limpias"]) == int(k_previo["entradas_limpias"]) and c.get_poseedor() == toco:
				var vel: Vector3 = c.get_pelota_vel()
				var cerca := INF
				for o in pos.size():
					if equipos[o] != equipos[toco]:
						cerca = minf(cerca, pos[o].distance_to(pos[toco]))
				m["salida_ms"].append(Vector2(vel.x, vel.z).length())
				m["rapidez_control"].append(rapidez[toco])
				control = {"i": toco, "equipo": equipos[toco], "paso": paso, "separacion": 0.0, "libre": cerca > LIBRE_M, "cerca": cerca,
					"suma_rapidez": 0.0, "pasos": 0, "entre_piernas": 0.0,
					"salida": Vector2(vel.x, vel.z).length(), "corria": rapidez[toco],
					"angulo": rad_to_deg(absf(Vector2(vel.x, vel.z).angle_to(pos[toco] - _pos_previa[toco]))) if toco < _pos_previa.size() and (pos[toco] - _pos_previa[toco]).length() > 1e-4 else -1.0,
					"parte": c.get_accion(toco), "venia": _vel_previa.length(), "alto": bola.y}
			# --- Saque del arquero con la mano ---
			if not saque.is_empty():
				var fin_s := ""
				if parada == "lateral":
					fin_s = "lateral"
				elif parada != "nada":
					fin_s = "otro"
				elif int(k["controles"]) > int(k_previo["controles"]) and toco >= 0:
					fin_s = "companero" if equipos[toco] == saque["equipo"] else "rival"
				elif float(paso - int(saque["paso"])) * PASO_SEG > SAQUE_SEGUIR_SEG:
					fin_s = "otro"
				if fin_s != "":
					saques[fin_s] += 1
					saque = {}
			# --- Saque de arco (con el pie) ---
			if not arco.is_empty():
				var fin_a := ""
				if parada == "lateral":
					fin_a = "lateral"
				elif parada != "nada" and paso > int(arco["paso"]) + 30:
					fin_a = "otro"
				elif int(k["controles"]) > int(k_previo["controles"]) and toco >= 0:
					fin_a = "companero" if equipos[toco] == arco["equipo"] else "rival"
				elif float(paso - int(arco["paso"])) * PASO_SEG > SAQUE_SEGUIR_SEG:
					fin_a = "otro"
				if fin_a != "":
					de_arco[fin_a] += 1
					arco = {}
			if int(k["saques_saque_arco"]) > int(k_previo["saques_saque_arco"]):
				de_arco["total"] += 1
				arco = {"paso": paso, "equipo": int(c.get_equipo_con_pelota())}
			if int(k["arquero_mano"]) > int(k_previo["arquero_mano"]):
				saques["total"] += 1
				saque = {"paso": paso, "equipo": int(c.get_equipo_con_pelota())}
			# --- Frenadas ---
			for i in pos.size():
				var v := rapidez[i]
				if frenando.has(i):
					var f: Dictionary = frenando[i]
					f["m"] += v * PASO_SEG
					f["seg"] += PASO_SEG
					if v > float(f["previa"]) + 0.05:
						frenando.erase(i)
					elif v < PARADO_MS:
						m["frenada_m"].append(f["m"])
						m["frenada_seg"].append(f["seg"])
						frenando.erase(i)
					else:
						f["previa"] = v
				elif v > CORRE_MS and i < _previa.size() and v < _previa[i] - 0.01:
					frenando[i] = {"m": 0.0, "seg": 0.0, "previa": v}
			_previa = rapidez
			_pos_previa = pos
			_vel_previa = c.get_pelota_vel()
			# --- Peleas lejos de la pelota (cada 6 pasos) ---
			if paso % 6 == 0 and parada == "nada":
				var hay := false
				for a in pos.size():
					if hay:
						break
					if pos[a].distance_to(bola2) < LEJOS_M:
						continue
					for b in range(a + 1, pos.size()):
						if equipos[a] != equipos[b] and pos[a].distance_to(pos[b]) < ENCIMADOS_M \
								and pos[b].distance_to(bola2) >= LEJOS_M and (rapidez[a] > 1.0 or rapidez[b] > 1.0):
							hay = true
							break
				if hay:
					pelea_seg += 6.0 * PASO_SEG
					var como := "controlada" if c.get_poseedor() >= 0 else ("pase" if c.get_receptor() >= 0 else "suelta")
					pelea[como] += 6.0 * PASO_SEG
			k_previo = k
	print("[sensaciones] %d partidos de %.0f min desde la semilla %d, %.1f min con la pelota en juego" % [partidos, minutos,
		semilla, jugado_seg / 60.0])
	print("[sensaciones] controles seguidos: %d" % m["separacion_m"].size())
	_linea("pelota al salir del control (m/s)", m["salida_ms"])
	_linea("rapidez del que controla en el toque (m/s)", m["rapidez_control"])
	_linea("separación máxima pelota-jugador hasta el toque siguiente (m)", m["separacion_m"])
	_linea("segundos hasta el toque siguiente", m["hasta_toque_seg"])
	var n_sigue: int = maxi(1, int(sigue["mismo"]) + int(sigue["companero"]) + int(sigue["rival"]) + int(sigue["nadie"]))
	print("[sensaciones] después del control la toca: el mismo %.0f%%, un compañero %.0f%%, un rival %.0f%%, nadie o sale %.0f%%" % [
		100.0 * sigue["mismo"] / n_sigue, 100.0 * sigue["companero"] / n_sigue, 100.0 * sigue["rival"] / n_sigue,
		100.0 * sigue["nadie"] / n_sigue])
	for tramo in ["apretado", "medio", "libre"]:
		print("[sensaciones]    rival %s: %d controles, se pierden %.0f%%" % [{"apretado": "a menos de 3 m", "medio": "entre 3 y 6 m",
			"libre": "a más de 6 m"}[tramo], por_presion[tramo][0], 100.0 * por_presion[tramo][1] / maxi(1, por_presion[tramo][0])])
	_linea("sin rivales a %.0f m: rapidez media en los %.1f s siguientes (m/s)" % [LIBRE_M, VENTANA_LIBRE_SEG], m["libre_rapidez"])
	_linea("sin rivales: segundos con la pelota entre las piernas", m["libre_entre_piernas_seg"])
	_linea("frenada de más de %.0f m/s a parado (m)" % CORRE_MS, m["frenada_m"])
	_linea("frenada (s)", m["frenada_seg"])
	print("[sensaciones] rivales encimados a más de %.0f m de la pelota: %.1f s por cada 10 min de juego" % [LEJOS_M,
		pelea_seg / maxf(jugado_seg, 1.0) * 600.0])
	print("[sensaciones]    con la pelota controlada %.1f s, en un pase %.1f s, suelta %.1f s (totales)" % [pelea["controlada"],
		pelea["pase"], pelea["suelta"]])
	print("[sensaciones] saques del arquero con la mano: %s" % [saques])
	print("[sensaciones] saques de arco: %s" % [de_arco])
	quit()


var _previa := PackedFloat32Array()
var _pos_previa := PackedVector2Array()
var _vel_previa := Vector3.ZERO
var _detalles := 0
const DETALLES := 0


func _linea(nombre: String, valores: Array) -> void:
	if valores.is_empty():
		print("[sensaciones] %s: sin datos" % nombre)
		return
	var v := valores.duplicate()
	v.sort()
	var suma := 0.0
	for x in v:
		suma += float(x)
	print("[sensaciones] %s: n %d, media %.2f, mediana %.2f, 90%% %.2f, máx %.2f" % [nombre, v.size(), suma / v.size(),
		v[v.size() / 2], v[int(v.size() * 0.9)], v[-1]])
