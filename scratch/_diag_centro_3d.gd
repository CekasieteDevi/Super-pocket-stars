extends SceneTree
## Centros bajados de pecho en el aire (bug 3D-09) en el partido del prototipo 3D:
##   --fixed-fps 30 -- division=1 semilla=N [corte_viejo] [detalle]
## Por cada centro de VistaCancha3D._centros: altura mínima de la pelota antes
## de la toma (PISO si toca el piso), distancia pelota-pecho en la toma, salto
## máximo de la pelota por cuadro (m/s), velocidad máxima del receptor yendo y
## con la pose de pecho (PATINA si pasa 3 m/s con la pose quieta).
var _p: Prototipo3D
var _n := 0
var _prev_bola := Vector3.INF
var _prev_rec := {}
var _datos := {}
var _guardados: Array = []
func _initialize() -> void:
	_p = (load("res://match/3d/prototipo_3d.tscn") as PackedScene).instantiate()
	root.add_child(_p)
	process_frame.connect(_ver)
func _ver() -> void:
	_n += 1
	var rep := _p.reproductor
	if rep == null or rep.vista == null: return
	if _n < 4: return
	var v := rep.vista as VistaCancha3D
	var pos := rep.posicion
	# Para comparar con el dibujo de antes: sin los centros de 3D-09.
	if OS.get_cmdline_user_args().has("sin_centros") and not v._centros.is_empty():
		for c in v._centros:
			_datos["%d_%d" % [int(c["clave"]), int(c["control"])]] = {"c": c, "min_y": INF, "d_toma": INF, "salto": 0.0, "vel_va": 0.0, "vel_pecho": 0.0, "anim": {}}
		_guardados = v._centros.duplicate()
		v._centros.clear()
		for id in v._recepciones:
			for w in v._recepciones[id]:
				if (w as Array).size() > 6: (w as Array).resize(6)
	var lista: Array = v._centros if _guardados.is_empty() else _guardados
	if pos >= float(rep.fotogramas.size() - 2) or _n > 80000:
		_resumen(v)
		quit(); return
	var seg := v._segundos
	var bola := v._pelota.global_position
	var vel_bola := 0.0
	if _prev_bola != Vector3.INF and seg > 0.0:
		vel_bola = (bola - _prev_bola).length() / seg
	_prev_bola = bola
	for c in lista:
		var t0 := float(c["arranca"]) - 1.0
		var t1 := float(c["control"]) + 2.0
		if pos < t0 or pos > t1: continue
		var llave := "%d_%d" % [int(c["clave"]), int(c["control"])]
		if not _datos.has(llave):
			_datos[llave] = {"c": c, "min_y": INF, "d_toma": INF, "salto": 0.0, "vel_va": 0.0, "vel_pecho": 0.0, "anim": {}}
		var d: Dictionary = _datos[llave]
		var pie := {}
		for p in v._pies:
			if int(p["id"]) == int(c["clave"]): pie = p
		if pie.is_empty(): continue
		var m: Jugador3D = pie["modelo"]
		var aqui := Vector2(m.global_position.x, m.global_position.z)
		var vel := 0.0
		if _prev_rec.has(llave) and seg > 0.0:
			vel = aqui.distance_to(_prev_rec[llave]) / seg
		_prev_rec[llave] = aqui
		var anim := str(m._anim_actual)
		d["anim"][anim] = true
		var toma := float(c["toma"])
		if pos >= float(c["desde"]) + (0.3 if bool(c.get("pique", false)) else 0.0) and pos < toma - 0.1:
			d["min_y"] = minf(float(d["min_y"]), bola.y)
		if pos >= float(c["desde"]) and pos <= float(c["fin"]) + 1.0 and seg > 0.0:
			d["salto"] = maxf(float(d["salto"]), vel_bola)
		if absf(pos - toma) < 0.1:
			d["d_toma"] = minf(float(d["d_toma"]), bola.distance_to(m.ancla("Pecho")))
		if pos < toma:
			d["vel_va"] = maxf(float(d["vel_va"]), vel)
		elif anim == "Pecho" and str(pie["accion"]) == "pecho" and float(pie["fase"]) < VistaCancha3D.RECEPCION_LISTA_FASE:
			# Media en la pose quieta (un salto de un cuadro no es patinar).
			if not d.has("pose_desde"):
				d["pose_desde"] = [pos, aqui]
			var ini: Array = d["pose_desde"]
			if pos - float(ini[0]) > 0.2:
				d["vel_pecho"] = aqui.distance_to(ini[1]) / ((pos - float(ini[0])) * MotorEspacial.TICK_SEG)
		if OS.get_cmdline_user_args().has("detalle"):
			var rm := VistaCancha3D._motor_de(rep.fotogramas, int(c["clave"]), pos)
			var bm := VistaCancha3D._bola_motor(rep.fotogramas, pos)
			print("  %.2f %s acc=%s fase %.2f anim %s vel %.1f desvio %s rec (%.1f,%.1f) motor (%.1f,%.1f) | bola (%.1f,%.2f,%.1f) motor (%.1f,%.1f) %.1f m/s pecho %.2f" % [pos, llave,
				str(pie["accion"]), float(pie["fase"]), anim, vel, str(pie["desvio"]), aqui.x, aqui.y, rm.x, rm.y, bola.x, bola.y, bola.z, bm.x, bm.y, vel_bola,
				bola.distance_to(m.ancla("Pecho"))])
func _resumen(v: VistaCancha3D) -> void:
	var casos := {}
	for llave in _datos:
		var d: Dictionary = _datos[llave]
		var c: Dictionary = d["c"]
		var marcas := []
		if float(d["min_y"]) < 0.4: marcas.append("PISO")
		if float(d["d_toma"]) > 0.5: marcas.append("LEJOS")
		if float(d["vel_pecho"]) > 3.0: marcas.append("PATINA")
		if float(d["salto"]) > 30.0: marcas.append("SALTO")
		if float(d["vel_va"]) > 10.0: marcas.append("CORRE")
		for mk in marcas: casos[mk] = int(casos.get(mk, 0)) + 1
		print("CENTRO %s%s desde %.1f toma %.2f junta %.2f control %d fin %.2f | min_y %.2f d_toma %.2f salto %.1f m/s va %.1f m/s pecho %.1f m/s %s %s" % [
			llave, " PIQUE" if bool(c.get("pique", false)) else "", float(c["desde"]), float(c["toma"]), float(c["junta"]), int(c["control"]), float(c["fin"]),
			float(d["min_y"]), float(d["d_toma"]), float(d["salto"]), float(d["vel_va"]), float(d["vel_pecho"]),
			str(d["anim"].keys()), " ".join(marcas)])
	print("RESUMEN centros %d %s" % [_datos.size(), casos])
