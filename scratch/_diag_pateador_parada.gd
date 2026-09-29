extends SceneTree
## Bug 3D-05: hacia dónde mira el que patea un tiro libre o un córner.
##   --fixed-fps 30 -- division=1 semilla=N [detalle]
## Por cada falta/córner: el ejecutor (patea/saque_arco en el primer tick con
## el juego andando) y adónde va la pelota (unos ticks después del saque).
## De 6 ticks antes al saque, el ángulo entre el frente del modelo y la
## pelota->destino. MIRA_MAL si pasa 60° con el modelo quieto al lado de la
## pelota (a menos de 2 m).
var _p: Prototipo3D
var _n := 0
var _paradas := []
var _peor := {}
var _casos := 0
func _initialize() -> void:
	_p = (load("res://match/3d/prototipo_3d.tscn") as PackedScene).instantiate()
	root.add_child(_p)
	process_frame.connect(_ver)
func _armar(fotos: Array) -> void:
	for k in fotos.size():
		for ev in fotos[k].get("eventos", []):
			var tipo := str(ev.get("tipo", ""))
			if tipo not in ["falta", "corner"]: continue
			var s := k + 1
			while s < fotos.size() and int(fotos[s].get("detenido", 0)) > 0: s += 1
			if s + 3 >= fotos.size(): continue
			var ej := -1
			for a in fotos[s].get("acciones", []):
				if str(a["accion"]) in [MotorEspacial.ACCION_PATEA, "saque_arco"]: ej = int(a["clave"])
			if ej == -1: continue
			var bola := Vector2(fotos[s - 1]["pelota"]["x"], fotos[s - 1]["pelota"]["y"])
			var dest := Vector2(fotos[s + 3]["pelota"]["x"], fotos[s + 3]["pelota"]["y"])
			_paradas.append({"tipo": tipo, "k": k, "s": s, "ej": ej, "bola": bola, "dir": (dest - bola).normalized(), "min": int(fotos[k].get("minuto", 0))})
func _ver() -> void:
	_n += 1
	var rep := _p.reproductor
	if rep == null or rep.vista == null: return
	if _n == 3: _armar(rep.fotogramas)
	if _n < 4: return
	var v := rep.vista as VistaCancha3D
	var pos := rep.posicion
	if pos >= float(rep.fotogramas.size() - 2) or _n > 80000:
		for i in _paradas.size():
			var p: Dictionary = _paradas[i]
			var w: Array = _peor.get(i, [0.0, ""])
			var mal := float(w[0]) > 60.0
			if mal: _casos += 1
			print("%s %s min %d saque %d ej %d peor %.0f° %s" % ["MIRA_MAL" if mal else "ok", p["tipo"], p["min"], p["s"], p["ej"], w[0], w[1]])
		print("RESUMEN MIRA_MAL ", _casos, " de ", _paradas.size())
		quit(); return
	for i in _paradas.size():
		var p: Dictionary = _paradas[i]
		if pos < float(p["s"]) - 6.0 or pos > float(p["s"]) + 0.3: continue
		for pie in v._pies:
			if int(pie["id"]) != int(p["ej"]): continue
			var m: Jugador3D = pie["modelo"]
			var aqui := Vector2(m.global_position.x, m.global_position.z)
			if aqui.distance_to(p["bola"]) > 2.0: continue
			var frente := Vector2(sin(m.rotation.y), cos(m.rotation.y))
			var ang := absf(rad_to_deg(frente.angle_to(p["dir"])))
			if OS.get_cmdline_user_args().has("detalle"): print("  %.2f %s ej %d %s ang %.0f" % [pos, p["tipo"], p["ej"], m._anim_actual, ang])
			var w: Array = _peor.get(i, [0.0, ""])
			if ang > float(w[0]): _peor[i] = [ang, "%.1f %s" % [pos, m._anim_actual]]
