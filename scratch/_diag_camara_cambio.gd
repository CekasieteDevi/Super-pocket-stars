extends SceneTree
## Bug 3D-07: un cambio antes de cobrar una falta o un lateral y la cámara se
## queda con el jugador del cambio (el `foco` del fotograma): no se ve el cobro.
##   --fixed-fps 30 -- division=1 semilla=N [corte_viejo] [detalle]
## Por cada tramo con `foco` que termina con el juego reanudándose (el primer
## tick sin foco tiene detenido 0 y la pelota se mueve o alguien patea), se
## reproduce desde 12 ticks antes del saque hasta 2 después y se mira si la
## pelota dibujada está en cuadro. NO_SE_VE si en los 2 ticks antes del saque
## o en el saque la pelota queda fuera de la cámara (o a más de 12 m del
## centro de la cámara).
var _p: Prototipo3D
var _n := 0
var _casos := []
var _i := 0
var _saltado := false
var _peor := 0.0
var _fuera := 0
var _malos := 0
func _initialize() -> void:
	_p = (load("res://match/3d/prototipo_3d.tscn") as PackedScene).instantiate()
	root.add_child(_p)
	process_frame.connect(_ver)
func _armar(fotos: Array) -> void:
	for k in range(1, fotos.size() - 1):
		if fotos[k].get("foco", null) != null or fotos[k - 1].get("foco", null) == null: continue
		if int(fotos[k].get("detenido", 0)) > 0: continue
		var p0 := Vector2(float(fotos[k - 1]["pelota"]["x"]), float(fotos[k - 1]["pelota"]["y"]))
		var p1 := Vector2(float(fotos[k]["pelota"]["x"]), float(fotos[k]["pelota"]["y"]))
		if p0.distance_to(p1) < 0.5 and fotos[k].get("acciones", []).is_empty(): continue
		_casos.append({"s": k, "min": int(fotos[k].get("minuto", 0))})
func _ver() -> void:
	_n += 1
	var rep := _p.reproductor
	if rep == null or rep.vista == null: return
	if _n == 3:
		_armar(rep.fotogramas)
		print("casos ", _casos.size())
	if _n < 4: return
	if _i >= _casos.size():
		print("RESUMEN NO_SE_VE ", _malos, " de ", _casos.size())
		quit(); return
	var c: Dictionary = _casos[_i]
	var s := float(c["s"])
	if not _saltado:
		rep.posicion = s - 12.0
		_saltado = true
		_peor = 0.0
		_fuera = 0
		return
	var v := rep.vista as VistaCancha3D
	var pos := rep.posicion
	var bola: Vector3 = v._pelota.global_position
	var cam: Camera3D = v._camara_3d
	var en_cuadro := cam.is_position_in_frustum(bola)
	var d := Vector2(bola.x, bola.z).distance_to(v.camara.centro)
	if OS.get_cmdline_user_args().has("detalle"):
		print("  %.2f bola (%.1f,%.1f) centro (%.1f,%.1f) d %.1f %s" % [pos, bola.x, bola.z, v.camara.centro.x, v.camara.centro.y, d, "ve" if en_cuadro else "FUERA"])
	if pos >= s - 2.0 and pos <= s + 0.2:
		_peor = maxf(_peor, d)
		if not en_cuadro or d > 12.0: _fuera += 1
	if pos > s + 2.0 or _n > 200000:
		var mal := _fuera > 0
		if mal: _malos += 1
		print("%s saque %d min %d peor_dist %.1f cuadros_fuera %d" % ["NO_SE_VE" if mal else "ok", int(s), int(c["min"]), _peor, _fuera])
		_i += 1
		_saltado = false
