extends SceneTree
var _m: MuestraAnimaciones3D
var _n := 0
func _initialize() -> void:
	_m = (load("res://match/3d/muestra_animaciones_3d.tscn") as PackedScene).instantiate()
	root.add_child(_m)
	process_frame.connect(_ver)
func _ver() -> void:
	_n += 1
	if _n > 3000: quit()
	if _m.reproductor == null or _m.reproductor.vista == null: return
	var v := _m.reproductor.vista as VistaCancha3D
	var pos := _m.reproductor.posicion
	if pos < 620.0 or _n % 10 != 0: return
	if pos > 626.0: quit(); return
	var m: Jugador3D = v._personas.get("of_asistente_derecho")
	var o := m.global_position
	var h := m.hueso("Brazo.R").origin - o
	var c := m.hueso("Antebrazo.R").origin - o
	var mano := m.ancla("Mano_R") - o
	var anim := m.animador
	print("pos %.2f anim=%s t=%.2f esc=%s hombro=%s codo=%s mano=%s" % [pos, anim.current_animation, anim.current_animation_position, str(m.scale), str(h.snapped(Vector3.ONE*0.01)), str(c.snapped(Vector3.ONE*0.01)), str(mano.snapped(Vector3.ONE*0.01))])
