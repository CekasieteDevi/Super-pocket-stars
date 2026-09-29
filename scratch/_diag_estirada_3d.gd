extends SceneTree
## Estiradas del arquero en un partido dibujado en 3D: cuánto se corre la
## cadera a lo largo de la línea del arco (motor, origen del modelo y cadera
## dibujada) y el salto de la cadera al terminar la animación.
##   --fixed-fps 30 -- division=1 [semilla=N] [detalle]
var _p: Prototipo3D
var _n := 0
var _vuelos := {}  # clave -> {inicio, muestras: [[t, motor, origen, cadera, anim]]}
var _hechos: Array = []
var _detalle := false
func _initialize() -> void:
	_detalle = OS.get_cmdline_user_args().has("detalle")
	_p = (load("res://match/3d/prototipo_3d.tscn") as PackedScene).instantiate()
	root.add_child(_p)
	process_frame.connect(_ver)
func _ver() -> void:
	_n += 1
	var rep := _p.reproductor
	if rep == null or rep.vista == null or _n < 4: return
	var v := rep.vista as VistaCancha3D
	var pos := rep.posicion
	if pos >= float(rep.fotogramas.size() - 2) or _n > 80000:
		for c in _vuelos.keys(): _cerrar(c)
		_resumen()
		quit(); return
	var i := 0
	for ent in v.entidades:
		var tipo := str(ent.get("tipo", ""))
		if tipo != "jugador" and tipo != "oficial": continue
		var clave := v._clave(ent, i)
		i += 1
		if tipo != "jugador": continue
		var p3: Jugador3D = v._personas.get(clave)
		if p3 == null: continue
		var anim := str(p3._anim_actual)
		var cad := p3.hueso("Cadera").origin
		var muestra := [pos, ent["pos"] as Vector2, Vector2(p3.global_position.x, p3.global_position.z), Vector2(cad.x, cad.z), anim, p3.animador.current_animation_position if p3.animador else -1.0, str(v._mira_vuela.get(int(v._jugadores_cuadro[i - 1]["id"]), []).slice(2)) if i - 1 < v._jugadores_cuadro.size() else ""]
		if anim.begins_with("Atajar_Volando"):
			if not _vuelos.has(clave) or bool(_vuelos[clave].get("cerrando", false)) and pos - float(_vuelos[clave]["fin"]) > 6.0:
				if _vuelos.has(clave): _cerrar(clave)
				_vuelos[clave] = {"inicio": pos, "muestras": [], "anim": anim}
			_vuelos[clave]["fin"] = pos
			_vuelos[clave]["cerrando"] = false
		if _vuelos.has(clave):
			var vu: Dictionary = _vuelos[clave]
			vu["muestras"].append(muestra)
			if not anim.begins_with("Atajar_Volando"):
				vu["cerrando"] = true
				if pos - float(vu["fin"]) > 6.0: _cerrar(clave)
func _cerrar(clave: String) -> void:
	var vu: Dictionary = _vuelos[clave]
	_vuelos.erase(clave)
	var m: Array = vu["muestras"]
	if m.size() < 3: return
	var ini: Array = m[0]
	var k_fin := 0
	for k in m.size():
		if str(m[k][4]).begins_with("Atajar_Volando"): k_fin = k
	var fin: Array = m[k_fin]
	var ult: Array = m[-1]
	# El eje: a lo largo de la línea del arco, hacia donde se tira la cadera.
	var lado := signf((fin[3] as Vector2).y - (ini[3] as Vector2).y)
	if lado == 0.0: lado = 1.0
	var salto := 0.0
	var salto_t := 0.0
	for k in range(1, m.size()):
		var dt := float(m[k][0]) - float(m[k - 1][0])
		if dt <= 0.0: continue
		var vel := (m[k][3] as Vector2).distance_to(m[k - 1][3]) / (dt * MotorEspacial.TICK_SEG)
		var velm := (m[k][1] as Vector2).distance_to(m[k - 1][1]) / (dt * MotorEspacial.TICK_SEG)
		if vel - velm > salto:
			salto = vel - velm
			salto_t = float(m[k][0])
	var d := {"clave": clave, "t": float(ini[0]), "anim": vu["anim"],
		"motor": ((fin[1] as Vector2).y - (ini[1] as Vector2).y) * lado,
		"cadera": ((fin[3] as Vector2).y - (ini[3] as Vector2).y) * lado,
		"cadera_menos_motor_fin": ((fin[3] as Vector2).y - (fin[1] as Vector2).y) * lado,
		"cadera_menos_motor_despues": ((ult[3] as Vector2).y - (ult[1] as Vector2).y) * lado,
		"salto": salto, "salto_t": salto_t}
	_hechos.append(d)
	print("VUELO t %.1f %s %s | motor %.2f m, cadera %.2f m, cadera-motor al terminar %.2f, 6 ticks despues %.2f | exceso %.1f m/s en %.1f" % [
		d["t"], clave.substr(0, 12), d["anim"], d["motor"], d["cadera"], d["cadera_menos_motor_fin"], d["cadera_menos_motor_despues"], salto, salto_t])
	if _detalle:
		for s in m:
			print("   %.2f %s t=%.2f motor(%.2f,%.2f) origen(%.2f,%.2f) cadera(%.2f,%.2f) %s" % [s[0], s[4], s[5], s[1].x, s[1].y, s[2].x, s[2].y, s[3].x, s[3].y, s[6]])
func _resumen() -> void:
	var n := _hechos.size()
	if n == 0:
		print("RESUMEN sin estiradas"); return
	var suma := {"motor": 0.0, "cadera": 0.0, "cadera_menos_motor_fin": 0.0, "salto": 0.0}
	var peor := 0.0
	for d in _hechos:
		for c in suma: suma[c] += absf(float(d[c]))
		peor = maxf(peor, float(d["salto"]))
	print("RESUMEN %d estiradas | medias: motor %.2f cadera %.2f |cadera-motor| al terminar %.2f exceso %.1f m/s (peor %.1f)" % [n,
		suma["motor"] / n, suma["cadera"] / n, suma["cadera_menos_motor_fin"] / n, suma["salto"] / n, peor])
