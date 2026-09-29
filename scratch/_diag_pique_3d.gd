extends SceneTree
## Pelotas altas que caen sueltas (bug 3D-10) en el partido del prototipo 3D:
##   --fixed-fps 30 -- division=1 semilla=N [sin_piques] [detalle]
## Por cada vuelo de VistaCancha3D._piques (sin_piques: los mismos, sin el
## arreglo): cuántas veces pica la pelota dibujada, la velocidad horizontal
## antes de tocar el piso y medio tick después (MUERTA si queda por debajo del
## 30%), el salto máximo por cuadro (SALTO si pasa 40 m/s) y la velocidad al
## tomarla.
var _p: Prototipo3D
var _n := 0
var _prev := Vector3.INF
var _datos := {}
var _lista: Array = []
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
	if _lista.is_empty() and not v._piques.is_empty():
		_lista = v._piques.duplicate()
		if OS.get_cmdline_user_args().has("sin_piques"):
			v._piques.clear()
	var pos := rep.posicion
	if pos >= float(rep.fotogramas.size() - 2) or _n > 80000:
		_resumen()
		quit(); return
	var seg := v._segundos
	var bola := v._pelota.global_position
	var radio := VistaCancha3D.RADIO_PELOTA * VistaCancha3D.ESCALA_PELOTA
	var vel := Vector2.ZERO
	var salto := 0.0
	if _prev != Vector3.INF and seg > 0.0:
		vel = Vector2(bola.x - _prev.x, bola.z - _prev.z) / seg
		salto = (bola - _prev).length() / seg
	var y_prev := _prev.y
	_prev = bola
	for p in _lista:
		if pos < float(p["desde"]) or pos > float(p["fin"]): continue
		var llave := "%.0f" % float(p["desde"])
		if not _datos.has(llave):
			_datos[llave] = {"p": p, "piques": 0, "sube": false, "antes": 0.0, "despues": -1.0, "toca_en": -1.0, "salto": 0.0, "toma": 0.0, "alto_max": 0.0}
		var d: Dictionary = _datos[llave]
		d["salto"] = maxf(float(d["salto"]), salto)
		# Toca el piso: queda en el piso, o bajaba y vuelve a subir desde cerca
		# del piso (a 30 fps el cuadro justo del toque casi nunca sale).
		var rebota := bool(d.get("bajando", false)) and bola.y > y_prev and y_prev < radio + 0.5
		var toca := bola.y < radio + 0.08 or rebota
		d["bajando"] = bola.y < y_prev
		if pos > float(p["desde"]) + 1.0:
			if float(d["toca_en"]) < 0.0:
				if toca:
					d["toca_en"] = pos
				else:
					d["antes"] = vel.length()
			else:
				if float(d["despues"]) < 0.0 and pos >= float(d["toca_en"]) + 0.5:
					d["despues"] = vel.length()
				d["alto_max"] = maxf(float(d["alto_max"]), bola.y - radio)
				if rebota and pos > float(d["toca_en"]) + 0.1:
					d["piques"] = int(d["piques"]) + 1
			if float(d["toca_en"]) == pos and rebota:
				d["primero_rebota"] = true
		if pos > float(p["fin"]) - 0.1:
			d["toma"] = vel.length()
		if OS.get_cmdline_user_args().has("detalle"):
			print("  %.2f %s bola (%.1f,%.2f,%.1f) %.1f m/s" % [pos, llave, bola.x, bola.y, bola.z, vel.length()])
func _resumen() -> void:
	var casos := {}
	for llave in _datos:
		var d: Dictionary = _datos[llave]
		var p: Dictionary = d["p"]
		var marcas := []
		# El primer toque cuenta como pique si de ahí volvió a subir.
		if bool(d.get("primero_rebota", false)): d["piques"] = int(d["piques"]) + 1
		var queda := float(d["despues"]) / maxf(float(d["antes"]), 0.01)
		if float(d["antes"]) > 5.0 and queda < 0.3: marcas.append("MUERTA")
		if float(d["salto"]) > 40.0: marcas.append("SALTO")
		if int(d["piques"]) == 0: marcas.append("SIN_PIQUE")
		for mk in marcas: casos[mk] = int(casos.get(mk, 0)) + 1
		print("PIQUE desde %.2f toca %.2f fin %.0f | piques %d alto %.2f antes %.1f despues %.1f m/s (%.0f%%) toma %.1f salto %.1f %s" % [
			float(p["desde"]), float(p["toca"]), float(p["fin"]), int(d["piques"]), float(d["alto_max"]),
			float(d["antes"]), float(d["despues"]), queda * 100.0, float(d["toma"]), float(d["salto"]), " ".join(marcas)])
	print("RESUMEN piques %d %s" % [_datos.size(), casos])
