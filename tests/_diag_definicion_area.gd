extends SceneTree

## Mide qué decide el que tiene la pelota frente al arco rival. No es un
## test: mide. Motivo: en los partidos del usuario el delantero frente al
## arco la pasaba al costado o atrás en lugar de rematar.
##
## Zona: dentro del área rival, con |y| <= ANCHO_FRENTE. Para cada decisión
## tomada ahí anota lo elegido, si el remate estaba entre las opciones, la
## probabilidad que le daba el softmax y qué opción le ganaba.
##
## Uso:
##   <godot> --path . --headless --script tests/_diag_definicion_area.gd -- partidos=10
##   Agregar `guardado` para jugar con el club del guardado (solo lectura).

const SEED := 61300
const ANCHO_FRENTE := 12.0

const ESCENARIOS := [
	{"a": 0, "b": 0},
	{"a": 4, "b": 4},
	{"a": 9, "b": 9},
]

var partidos := 8
var usar_guardado := false


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		var partes: PackedStringArray = arg.split("=")
		if partes.size() == 2 and partes[0] == "partidos":
			partidos = maxi(1, int(partes[1]))
		if arg == "guardado":
			usar_guardado = true
	call_deferred("_correr")


func _correr() -> void:
	var muestras: Array = []
	var goles := 0
	var tiros := 0
	var n := 0
	var pares: Array = []
	if usar_guardado:
		var gs := root.get_node("GameState")
		assert(gs.cargar_partida())
		var propio: Team = gs.equipo_jugador
		var liga: Liga = gs.piramide.divisiones[gs.division_jugador]
		var k := 0
		for rival in liga.equipos:
			if rival == propio:
				continue
			pares.append([propio, rival] if k % 2 == 0 else [rival, propio])
			k += 1
			if pares.size() >= partidos:
				break
	for par in pares:
		var r := _partido_con(par[0], par[1], SEED + n * 17)
		muestras.append_array(r["muestras"])
		goles += int(r["goles"])
		tiros += int(r["tiros"])
		n += 1
	if not usar_guardado:
		for esc in ESCENARIOS:
			for i in range(partidos):
				var rng := RandomNumberGenerator.new()
				rng.seed = SEED + i * 17
				var a := Team.generar("A", rng, 0, NivelDivision.potencial(esc["a"]),
					"Uruguay", NivelDivision.realizacion(esc["a"]))
				var b := Team.generar("B", rng, 400, NivelDivision.potencial(esc["b"]),
					"Uruguay", NivelDivision.realizacion(esc["b"]))
				var r := _partido_con(a, b, SEED + i * 17)
				muestras.append_array(r["muestras"])
				goles += int(r["goles"])
				tiros += int(r["tiros"])
				n += 1
	_informar(muestras, n, goles, tiros)
	quit()


func _partido_con(a: Team, b: Team, semilla: int) -> Dictionary:
	var rng_p := RandomNumberGenerator.new()
	rng_p.seed = semilla
	var res := MotorEspacial.simular(a, b, rng_p, true)
	var st: Dictionary = res["stats"]
	return {
		"muestras": _decisiones(res["fotogramas"]),
		"goles": int(res.get("goles_local", a.goles)) + int(res.get("goles_visitante", b.goles)),
		"tiros": int(st["tiros"]["home"]) + int(st["tiros"]["away"]),
	}


func _decisiones(fotos: Array) -> Array:
	var salida: Array = []
	for k in range(1, fotos.size()):
		var d = fotos[k].get("decision", null)
		if d == null or is_same(d, fotos[k - 1].get("decision", null)):
			continue
		var previo: Dictionary = fotos[k - 1]
		var p := int(previo["pelota"]["poseedor_id"])
		if p == -1:
			continue
		var j := _jugador(previo, p)
		if j.is_empty() or str(j["rol"]) == "ARQ" or str(j["rol"]) != str(d["jugador_rol"]):
			continue
		var local: bool = bool(j["equipo_local"])
		var pos := Vector2(float(j["x"]), float(j["y"]))
		if not MotorEspacial._en_el_area(pos, local) or absf(pos.y) > ANCHO_FRENTE:
			continue
		var arco := MotorEspacial.arco_rival(local)
		var hacia_arco: Vector2 = (arco - pos).normalized()
		var mira := Vector2(float(j["ox"]), float(j["oy"]))
		var opciones: Array = d["opciones"]
		var temp: float = float(d["temperatura"])
		var max_u := -INF
		for o in opciones:
			max_u = maxf(max_u, float(o["utilidad"]))
		var suma := 0.0
		var p_tiro := 0.0
		var u_tiro := -INF
		var mejor_otro := {}
		for o in opciones:
			var e: float = exp((float(o["utilidad"]) - max_u) / temp)
			suma += e
			if str(o["tipo"]) == "tiro":
				p_tiro = e
				u_tiro = float(o["utilidad"])
			elif mejor_otro.is_empty() or float(o["utilidad"]) > float(mejor_otro["utilidad"]):
				mejor_otro = o
		var elegido := str(d["tipo"])
		var destino := "-"
		if elegido in ["pase", "pase_hueco", "pase_largo", "pared", "centro"]:
			# Adónde fue: el pase que sale se ve en el fotograma siguiente.
			var avance := _avance_del_pase(fotos, k, pos, local)
			destino = "atras" if avance < -2.0 else ("costado" if avance < 3.0 else "adelante")
		salida.append({
			"dist": pos.distance_to(arco), "elegido": elegido, "destino": destino,
			"hay_tiro": u_tiro > -INF, "p_tiro": p_tiro / suma if suma > 0.0 else 0.0,
			"u_tiro": u_tiro, "mejor_otro": mejor_otro, "temp": temp,
			"de_frente": mira.dot(hacia_arco),
		})
	return salida


func _avance_del_pase(fotos: Array, k: int, desde: Vector2, local: bool) -> float:
	# El receptor es quien tiene la pelota después; se mira hasta 40 ticks.
	for m in range(k, mini(k + 40, fotos.size())):
		var p := int(fotos[m]["pelota"]["poseedor_id"])
		if p == -1:
			continue
		var j := _jugador(fotos[m], p)
		if j.is_empty():
			return 0.0
		return (float(j["x"]) - desde.x) * (1.0 if local else -1.0)
	return 0.0


func _jugador(f: Dictionary, clave: int) -> Dictionary:
	for j in f["jugadores"]:
		if int(j["id"]) == clave:
			return j
	return {}


func _informar(m: Array, n: int, goles: int, tiros: int) -> void:
	print("## Partidos %d  goles/p %.2f  remates/p %.2f" % [n, float(goles) / n, float(tiros) / n])
	print("## Decisiones en el área frente al arco: %d (%.1f por partido)" % [m.size(), float(m.size()) / n])
	var por_tipo := {}
	var por_destino := {}
	var sin_tiro := 0
	var suma_p := 0.0
	var n_con_tiro := 0
	var gana := {}
	var cerca := {"n": 0, "tiro": 0}
	for s in m:
		var clave: String = s["elegido"] + ("" if s["destino"] == "-" else "_" + s["destino"])
		por_tipo[clave] = int(por_tipo.get(clave, 0)) + 1
		if not s["hay_tiro"]:
			sin_tiro += 1
		else:
			n_con_tiro += 1
			suma_p += float(s["p_tiro"])
			if not s["mejor_otro"].is_empty() and float(s["mejor_otro"]["utilidad"]) > float(s["u_tiro"]):
				var o: Dictionary = s["mejor_otro"]
				var marcas := []
				for marca in ["pase_atras_al_area", "llegada_coordinada", "descarga_util", "aceleracion_preparada", "cambio_frente", "corrida_preparada"]:
					if bool(o["detalle"].get(marca, false)):
						marcas.append(marca)
				var g := "%s[%s]" % [o["tipo"], ",".join(marcas)]
				gana[g] = int(gana.get(g, 0)) + 1
		if float(s["dist"]) <= 12.0:
			cerca["n"] += 1
			if s["elegido"] == "tiro":
				cerca["tiro"] += 1
	var claves := por_tipo.keys()
	claves.sort_custom(func(x, y): return por_tipo[x] > por_tipo[y])
	for c in claves:
		print("  %-22s %5d  %5.1f%%" % [c, por_tipo[c], 100.0 * por_tipo[c] / maxf(m.size(), 1)])
	print("## Sin remate entre las opciones (de espaldas): %d (%.1f%%)" % [sin_tiro, 100.0 * sin_tiro / maxf(m.size(), 1)])
	print("## Probabilidad media de remate cuando estaba: %.1f%%" % [100.0 * suma_p / maxf(n_con_tiro, 1)])
	print("## A menos de 12 m: %d decisiones, remate %.1f%%" % [cerca["n"], 100.0 * cerca["tiro"] / maxf(cerca["n"], 1)])
	print("## Opción que le gana al remate (utilidad mayor):")
	var gk := gana.keys()
	gk.sort_custom(func(x, y): return gana[x] > gana[y])
	for g in gk.slice(0, 10):
		print("  %-60s %d" % [g, gana[g]])
