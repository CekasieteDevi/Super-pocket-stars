extends SceneTree

## Mide cuánto tarda un atacante en jugar la pelota cuando la tiene cerca
## del arco rival. No es un test: mide. Motivo: el delantero recibe en zona
## de remate y a veces tarda varios segundos en pegarle, hasta perderla.
##
## Recorre los fotogramas del partido y arma "tenencias": tramos seguidos con
## el mismo poseedor y el juego corriendo. Para cada tenencia que empieza a
## menos de DIST_ZONA del arco rival anota los ticks, las decisiones, en qué
## tick decidió por primera vez y cómo terminó.
##
## Uso:
##   <godot> --path . --headless --script tests/_diag_demora_remate.gd -- partidos=8

const SEED := 51200
const DIST_ZONA := 22.0

const ESCENARIOS := [
	{"a": 0, "b": 0},
	{"a": 4, "b": 4},
	{"a": 9, "b": 9},
]

var partidos := 6
var solo_esc := -1


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		var partes: PackedStringArray = arg.split("=")
		if partes.size() == 2 and partes[0] == "partidos":
			partidos = maxi(1, int(partes[1]))
		if partes.size() == 2 and partes[0] == "esc":
			solo_esc = int(partes[1])
	var todas: Array = []
	var remates_totales := 0
	for n_esc in range(ESCENARIOS.size()):
		if solo_esc != -1 and n_esc != solo_esc:
			continue
		var esc: Dictionary = ESCENARIOS[n_esc]
		for i in range(partidos):
			var r := _partido(esc, SEED + i * 17)
			todas.append_array(r["tenencias"])
			remates_totales += int(r["tiros"])
	_informar(todas, remates_totales)
	quit()


func _partido(esc: Dictionary, semilla: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var a := Team.generar("A", rng, 0, NivelDivision.potencial(esc["a"]),
		"Uruguay", NivelDivision.realizacion(esc["a"]))
	var b := Team.generar("B", rng, 400, NivelDivision.potencial(esc["b"]),
		"Uruguay", NivelDivision.realizacion(esc["b"]))
	var rng_p := RandomNumberGenerator.new()
	rng_p.seed = semilla
	var res := MotorEspacial.simular(a, b, rng_p, true)
	var st: Dictionary = res["stats"]
	return {
		"tenencias": _tenencias(res["fotogramas"]),
		"tiros": int(st["tiros"]["home"]) + int(st["tiros"]["away"]),
	}


func _tenencias(fotos: Array) -> Array:
	var salida: Array = []
	var i := 0
	while i < fotos.size():
		var f: Dictionary = fotos[i]
		var p := int(f["pelota"]["poseedor_id"])
		if p == -1 or int(f.get("detenido", 0)) > 0:
			i += 1
			continue
		var j := _jugador(f, p)
		if j.is_empty() or str(j["rol"]) == "ARQ":
			i += 1
			continue
		var local: bool = bool(j["equipo_local"])
		var arco := Vector2(MotorEspacial.MEDIO_LARGO if local else -MotorEspacial.MEDIO_LARGO, 0.0)
		var pos0 := Vector2(float(j["x"]), float(j["y"]))
		var dist0: float = pos0.distance_to(arco)
		# Una tenencia: mientras el mismo poseedor siga con la pelota.
		var k := i
		var decisiones: Array = []
		var decision_previa = f.get("decision", null)
		var primera := -1
		var dist_min: float = dist0
		while k + 1 < fotos.size() and int(fotos[k + 1]["pelota"]["poseedor_id"]) == p \
				and int(fotos[k + 1].get("detenido", 0)) == 0:
			k += 1
			var jk := _jugador(fotos[k], p)
			if not jk.is_empty():
				dist_min = minf(dist_min, Vector2(float(jk["x"]), float(jk["y"])).distance_to(arco))
			var d = fotos[k].get("decision", null)
			if d != null and not is_same(d, decision_previa):
				decisiones.append({"tick": k - i, "tipo": str(d["tipo"]), "opciones": d["opciones"]})
				if primera == -1:
					primera = k - i
				decision_previa = d
		# La decision que suelta la pelota se toma en el tick en que se va:
		# el fotograma siguiente ya no lo tiene de poseedor.
		var fin := "otro"
		if k + 1 < fotos.size():
			var sig: Dictionary = fotos[k + 1]
			var d_sig = sig.get("decision", null)
			if d_sig != null and not is_same(d_sig, decision_previa):
				decisiones.append({"tick": k + 1 - i, "tipo": str(d_sig["tipo"]), "opciones": d_sig["opciones"]})
				if primera == -1:
					primera = k + 1 - i
			var p2 := int(sig["pelota"]["poseedor_id"])
			if bool(sig["pelota"]["es_remate"]):
				fin = "tiro"
			elif int(sig.get("detenido", 0)) > 0:
				fin = "parado"
			elif p2 == -1 and bool(sig["pelota"]["es_pase"]):
				fin = "pase"
			elif p2 == -1:
				fin = "suelta"
			else:
				var j2 := _jugador(sig, p2)
				if not j2.is_empty() and bool(j2["equipo_local"]) != local:
					fin = "robo"
				else:
					fin = "pase"
		if dist_min <= DIST_ZONA and str(j["rol"]) in ["DC", "EXT", "MCO"]:
			salida.append({"rol": str(j["rol"]), "dist": dist0, "dist_min": dist_min,
					"en_area": MotorEspacial._en_el_area(pos0, local), "ticks": k - i + 1,
					"fin": fin, "decisiones": decisiones, "primera": primera})
		i = k + 1
	return salida


func _jugador(f: Dictionary, clave: int) -> Dictionary:
	for j in f["jugadores"]:
		if int(j["id"]) == clave:
			return j
	return {}


func _informar(todas: Array, remates: int) -> void:
	print("## Tenencias de atacantes a menos de %.0f m del arco: %d (remates totales %d)" % [
		DIST_ZONA, todas.size(), remates])
	var por_fin := {}
	var hist := {}
	var suma_ticks := 0
	var suma_primera := 0
	var n_primera := 0
	var conducir_con_tiro := 0
	var decisiones_con_tiro := 0
	var largas_robadas := 0
	var tipos := {}
	for t in todas:
		por_fin[t["fin"]] = int(por_fin.get(t["fin"], 0)) + 1
		var tramo: int = mini(int(t["ticks"]), 20)
		hist[tramo] = int(hist.get(tramo, 0)) + 1
		suma_ticks += int(t["ticks"])
		if int(t["primera"]) >= 0:
			suma_primera += int(t["primera"])
			n_primera += 1
		if int(t["ticks"]) >= 8 and t["fin"] == "robo":
			largas_robadas += 1
		for d in t["decisiones"]:
			tipos[d["tipo"]] = int(tipos.get(d["tipo"], 0)) + 1
			var tenia_tiro := false
			for op in d["opciones"]:
				if str(op["tipo"]) == "tiro":
					tenia_tiro = true
			if tenia_tiro:
				decisiones_con_tiro += 1
				if d["tipo"] == "conducir":
					conducir_con_tiro += 1
	var n: float = maxf(float(todas.size()), 1.0)
	print("ticks medios con la pelota: %.2f (%.2f s)" % [suma_ticks / n, suma_ticks / n * 0.25])
	print("tick medio de la primera decision: %.2f" % [float(suma_primera) / maxf(n_primera, 1.0)])
	print("finales: %s" % [por_fin])
	print("decisiones: %s" % [tipos])
	print("decisiones con tiro disponible: %d, de ellas conducir: %d" % [decisiones_con_tiro, conducir_con_tiro])
	print("tenencias de 8+ ticks que terminan en robo: %d" % largas_robadas)
	var claves := hist.keys()
	claves.sort()
	for c in claves:
		print("  %s%2d ticks: %d" % ["+" if c == 20 else " ", c, hist[c]])
	# Tiempo hasta rematar, solo las que terminan en remate.
	var hasta_tiro := {}
	for t in todas:
		if t["fin"] == "tiro":
			var c2: int = mini(int(t["ticks"]), 20)
			hasta_tiro[c2] = int(hasta_tiro.get(c2, 0)) + 1
	print("ticks hasta el remate: %s" % [hasta_tiro])
	# Perdidas sin haber decidido nunca: la perdio esperando.
	var sin_decidir := {}
	var hist_primera := {}
	for t in todas:
		if int(t["primera"]) == -1:
			sin_decidir[t["fin"]] = int(sin_decidir.get(t["fin"], 0)) + 1
		else:
			var c3: int = mini(int(t["primera"]), 20)
			hist_primera[c3] = int(hist_primera.get(c3, 0)) + 1
	print("tenencias que terminan sin ninguna decision: %s" % [sin_decidir])
	var cl := hist_primera.keys()
	cl.sort()
	var txt := ""
	for c in cl:
		txt += "%d:%d " % [c, hist_primera[c]]
	print("tick de la primera decision: %s" % txt)
	# Solo las que arrancan dentro del area: ahi rige demora_para_definir.
	var area := {}
	var area_fin := {}
	for t in todas:
		if not bool(t["en_area"]):
			continue
		area_fin[t["fin"]] = int(area_fin.get(t["fin"], 0)) + 1
		var c4: int = mini(int(t["primera"]), 20)
		area[c4] = int(area.get(c4, 0)) + 1
	var ca := area.keys()
	ca.sort()
	var txt2 := ""
	for c in ca:
		txt2 += "%d:%d " % [c, area[c]]
	print("EN EL AREA finales: %s" % [area_fin])
	print("EN EL AREA primera decision (-1 = ninguna): %s" % txt2)
