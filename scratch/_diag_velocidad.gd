extends SceneTree
## Velocidad dibujada (m/s de partido) del que lleva la pelota, cada 0.25
## tick, en reproducción real: -- clip=16 desde=342 hasta=353
var _m: MuestraAnimaciones3D
var _n := 0
var _desde := 0.0
var _hasta := 0.0
var _prev := Vector3.INF
var _t_prev := 0.0
var _modelo: Jugador3D = null
var _max := 0.0

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2 and kv[0] == "desde": _desde = float(kv[1])
		if kv.size() == 2 and kv[0] == "hasta": _hasta = float(kv[1])
	_m = (load("res://match/3d/muestra_animaciones_3d.tscn") as PackedScene).instantiate()
	root.add_child(_m)
	process_frame.connect(_ver)

func _ver() -> void:
	_n += 1
	if _n > 1500: quit()
	if _m.reproductor == null or _m.reproductor.vista == null: return
	var v := _m.reproductor.vista as VistaCancha3D
	var pos := _m.reproductor.posicion
	if pos < _desde: return
	if pos > _hasta:
		print("VELOCIDAD MAXIMA %.1f m/s" % _max)
		quit()
		return
	if _modelo == null:
		var bola := Vector2(v._pelota.global_position.x, v._pelota.global_position.z)
		for p in v._pies:
			if str(p["accion"]).begins_with("regate") and (p["pos"] as Vector2).distance_to(bola) < 2.5:
				_modelo = p["modelo"]
		_t_prev = pos
		return
	if pos - _t_prev < 0.25: return
	var g := _modelo.global_position
	if _prev != Vector3.INF:
		var vel := Vector2(g.x - _prev.x, g.z - _prev.z).length() / ((pos - _t_prev) * 0.25)
		_max = maxf(_max, vel)
		var b := v._pelota.global_position
		for p in v._pies:
			if p["modelo"] == _modelo:
				var bola_cruda := Vector2.ZERO
				for e in v.entidades:
					if str(e.get("tipo", "")) == "pelota": bola_cruda = e["pos"]
				print("    desvio %s  conduccion %s  correccion %s  pelota cruda-cuerpo %.2f  accion %s fase %.2f" % [str(p["desvio"]), str(v._conduccion),
					str(v._correccion), bola_cruda.distance_to(p["pos"]), p["accion"], float(p["fase"])])
		print("pos %.2f  %.1f m/s  anim=%s  frente (%.2f,%.2f)  pelota-cuerpo %.2f m  pelota y %.2f" % [pos, vel, _modelo._anim_actual,
			sin(_modelo.rotation.y), cos(_modelo.rotation.y), Vector2(b.x - g.x, b.z - g.z).length(), b.y])
	_prev = g
	_t_prev = pos
