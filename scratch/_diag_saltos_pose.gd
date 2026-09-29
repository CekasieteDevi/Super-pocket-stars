extends SceneTree
## Reproducción real a 60 fps: cuánto se mueven los pies y la cabeza del que
## lleva la pelota entre dos cuadros, relativo a su cuerpo. Un cambio de
## animación sin mezcla aparece como un salto grande.
## -- clip=16 desde=346 hasta=349
var _m: MuestraAnimaciones3D
var _n := 0
var _desde := 0.0
var _hasta := 0.0
var _modelo: Jugador3D = null
var _prev := {}
var _peor := 0.0
var _peor_en := ""

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
	if _n > 3000: quit()
	if _m.reproductor == null or _m.reproductor.vista == null: return
	var v := _m.reproductor.vista as VistaCancha3D
	var pos := _m.reproductor.posicion
	if pos < _desde: return
	if pos > _hasta:
		print("PEOR SALTO DE POSE %.3f m en %s" % [_peor, _peor_en])
		quit()
		return
	if _modelo == null:
		var bola := Vector2(v._pelota.global_position.x, v._pelota.global_position.z)
		for p in v._pies:
			if str(p["accion"]).begins_with("regate") and (p["pos"] as Vector2).distance_to(bola) < 2.0:
				_modelo = p["modelo"]
		return
	var cuerpo := _modelo.global_position
	for nombre in ["Pie_R", "Pie_L", "Frente", "Mano_L", "Mano_R"]:
		var rel := _modelo.ancla(nombre) - cuerpo
		if _prev.has(nombre):
			var d: float = (rel - _prev[nombre]).length()
			if d > _peor:
				_peor = d
				_peor_en = "%s pos %.2f anim %s" % [nombre, pos, _modelo._anim_actual]
		_prev[nombre] = rel
