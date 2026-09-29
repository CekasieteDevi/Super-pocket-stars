extends SceneTree
## Remates al arco en el 3D (ver VistaCancha3D._preparar_remates): altura a la
## que llega cada uno y cómo lo ataja (o intenta) el arquero. Con `detalle`
## recorre cada remate de a 0.1 tick: alto de la pelota y de las manos del
## arquero, su animación y la distancia pelota-manos.
##   -- division=1 semilla=5 [detalle]
var _p: Prototipo3D
var _n := 0
var _detalle := false
var _cola: Array = []
var _t := 0.0
var _r := {}
func _initialize() -> void:
	_detalle = OS.get_cmdline_user_args().has("detalle")
	_p = (load("res://match/3d/prototipo_3d.tscn") as PackedScene).instantiate()
	root.add_child(_p)
	process_frame.connect(_ver)
func _ver() -> void:
	_n += 1
	var rep := _p.reproductor
	if rep == null or rep.vista == null or _n < 5:
		return
	var v := rep.vista as VistaCancha3D
	if _n == 5:
		v._preparar_bloqueos(rep)
		if v.sin_remates:
			v.sin_remates = false
			v._preparar_remates(rep, rep.fotogramas)
		var cuenta := {}
		for r in v._remates_3d:
			var f := "%s/%s" % ["gol" if r["gol"] else "atajada", r["forma"]]
			cuenta[f] = int(cuenta.get(f, 0)) + 1
			print("REMATE golpe %.2f llega %.2f min %d arq %d | %s %s | h %.2f alto %.2f z0 %.2f" % [
				float(r["golpe"]), float(r["llega"]), int(rep.fotogramas[int(r["golpe"])].get("minuto", 0)), int(r["arquero"]),
				"GOL" if r["gol"] else "atajada", r["forma"], float(r["h"]), float(r["alto"]), float(r["z0"])])
		print("TOTAL ", cuenta)
		if not _detalle:
			quit()
			return
		_cola = v._remates_3d.duplicate()
		# Los mismos remates, dibujados como antes (sin alturas ni paradas).
		if OS.get_cmdline_user_args().has("sin_remates"):
			v._remates_3d.clear()
		_siguiente(rep)
		return
	if _r.is_empty():
		quit()
		return
	var m: Jugador3D = null
	for pie in v._pies:
		if int(pie.get("id", -1)) == int(_r["arquero"]):
			m = pie["modelo"]
	var bola := v._pelota.global_position
	if m != null:
		var manos := (m.ancla("Mano_L") + m.ancla("Mano_R")) * 0.5
		print("  t %.2f pelota y %.2f | manos y %.2f | d %.2f | %s %.2f" % [rep.posicion, bola.y, manos.y,
			bola.distance_to(manos), m._anim_actual, m.animador.current_animation_position if m.animador else -1.0])
	_t += 0.1
	if _t > float(_r["llega"]) + 1.5:
		_siguiente(rep)
		return
	rep.posicion = _t
func _siguiente(rep) -> void:
	if _cola.is_empty():
		_r = {}
		return
	_r = _cola.pop_front()
	print("== golpe %.2f %s %s h %.2f" % [float(_r["golpe"]), "GOL" if _r["gol"] else "atajada", _r["forma"], float(_r["h"])])
	_t = float(_r["golpe"]) - 0.3
	rep.posicion = _t
	rep._idx_narrado = int(_t)
	rep._relato_restante = 0.0
	rep._festejo_restante = 0.0
	rep._idx_congelado = -1
	rep._festejo_grupo.clear()
