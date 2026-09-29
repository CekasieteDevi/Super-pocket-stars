extends SceneTree
## Pelota del 3D alrededor de los remates al palo/travesaño del prototipo:
##   --fixed-fps 30 -- division=1 semilla=5 corte_viejo [desde=T hasta=T]
## Sin desde/hasta recorre cada palo del partido (3 ticks antes, 8 después).
## Imprime cada ~0.1 tick la pelota dibujada (x, alto, y) y la del motor.
var _p: Prototipo3D
var _n := 0
var _tramos: Array = []
var _t := 0
var _ultimo := -1.0
var _prev := Vector3.INF
var _vmax := 0.0
var _vmax_en := 0.0
var _resumen := false
func _initialize() -> void:
	var desde := -1.0
	var hasta := -1.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("desde="): desde = float(a.trim_prefix("desde="))
		if a.begins_with("hasta="): hasta = float(a.trim_prefix("hasta="))
		if a == "resumen": _resumen = true
	if desde >= 0.0:
		_tramos.append([desde, hasta])
	_p = (load("res://match/3d/prototipo_3d.tscn") as PackedScene).instantiate()
	root.add_child(_p)
	process_frame.connect(_ver)
func _ver() -> void:
	_n += 1
	var rep := _p.reproductor
	if rep == null or rep.vista == null: return
	if _n == 3:
		if _tramos.is_empty():
			for k in rep.fotogramas.size():
				for e in rep.fotogramas[k].get("eventos", []):
					var palo: bool = str(e.get("resultado", "")) == "palo" or bool(e.get("palo", false))
					if palo:
						print("PALO t%d %s" % [k, str(e)])
						_tramos.append([float(k) - 3.0, float(k) + 8.0])
		if _tramos.is_empty(): quit(); return
		rep.posicion = float(_tramos[0][0])
	if _n < 4: return
	var v := rep.vista as VistaCancha3D
	var pos := rep.posicion
	var b := v._pelota.global_position
	if _prev != Vector3.INF and v._segundos > 0.0 and pos >= float(_tramos[_t][0]) and pos <= float(_tramos[_t][1]) and not VistaPartido._es_reubicacion(rep.fotogramas[mini(int(pos) + 1, rep.fotogramas.size() - 1)]):
		var vel := (b - _prev).length() / v._segundos
		if vel > _vmax:
			_vmax = vel
			_vmax_en = pos
	_prev = b
	if pos > float(_tramos[_t][1]):
		print("TRAMO %d vmax %.1f m/s en %.2f" % [_t, _vmax, _vmax_en])
		_vmax = 0.0
		_prev = Vector3.INF
		_t += 1
		if _t >= _tramos.size(): quit(); return
		rep.posicion = float(_tramos[_t][0])
		print("----")
		return
	if _resumen or (pos - _ultimo < 0.09 and pos >= _ultimo and (pos != _ultimo or _n % 4 != 0)): return
	_ultimo = pos
	var idx := mini(int(pos), rep.fotogramas.size() - 1)
	var f: Dictionary = rep.fotogramas[idx]
	var acc := []
	for a in f.get("acciones", []): acc.append("%s:%d" % [a["accion"], int(a["clave"])])
	print("fest%.2f t%.2f " % [v._festejo_ticks, v._tiempo_reproduccion], "%.2f det%d 3D(%.2f, %.2f, %.2f) motor(%.1f, %.1f, %.1f) %s" % [pos, int(f.get("detenido", 0)),
		b.x, b.y, b.z, float(f["pelota"]["x"]), float(f["pelota"].get("z", 0.0)), float(f["pelota"]["y"]), " ".join(acc)])
