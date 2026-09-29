extends SceneTree
## Recorrido de la pelota dibujada entre dos tiempos de la muestra y cuánto se
## aparta de la recta entre el primero y el último: -- desde=161 hasta=164
var _m: MuestraAnimaciones3D
var _t := 0.0
var _hasta := 0.0
var _puntos: Array = []
var _cuadro := 0

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2 and kv[0] == "desde": _t = float(kv[1])
		if kv.size() == 2 and kv[0] == "hasta": _hasta = float(kv[1])
	_m = (load("res://match/3d/muestra_animaciones_3d.tscn") as PackedScene).instantiate()
	_m.en_loop = false
	root.add_child(_m)
	process_frame.connect(_paso)

func _paso() -> void:
	var rep := _m.reproductor
	if rep == null or rep.fotogramas.is_empty(): return
	rep.pausado = true
	var v := rep.vista as VistaCancha3D
	if _cuadro > 0:
		var b: Vector3 = v._pelota.global_position
		_puntos.append(Vector2(b.x, b.z))
		print("t=%.2f pelota (%.2f, %.2f) y=%.2f" % [_t - 0.1, b.x, b.z, b.y])
	_cuadro += 1
	if _t > _hasta + 0.001:
		var a: Vector2 = _puntos[0]
		var z: Vector2 = _puntos[-1]
		var dir := (z - a).normalized()
		var peor := 0.0
		for p in _puntos:
			var d: Vector2 = p - a
			peor = maxf(peor, absf(d.x * dir.y - d.y * dir.x))
		print("DESVIO MAXIMO de la recta: %.2f m" % peor)
		quit()
		return
	var idx := int(_t)
	rep.posicion = _t
	rep._mostrar(idx, _t - idx)
	_t += 0.1
