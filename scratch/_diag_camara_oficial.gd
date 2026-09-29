extends SceneTree
## Cámara y asistente cuadro a cuadro durante un offside: -- clip=26
var _m: MuestraAnimaciones3D
var _n := 0
var _prev := -1.0
var _vueltas := 0

func _initialize() -> void:
	_m = (load("res://match/3d/muestra_animaciones_3d.tscn") as PackedScene).instantiate()
	root.add_child(_m)
	process_frame.connect(_ver)

func _ver() -> void:
	_n += 1
	if _n > 4000: quit()
	if _m.reproductor == null or _m.reproductor.vista == null: return
	var v := _m.reproductor.vista as VistaCancha3D
	var pos := _m.reproductor.posicion
	if pos < _prev - 3.0:
		_vueltas += 1
		if _vueltas >= 2: quit()
	_prev = pos
	if _vueltas < 1 or _n % 4 != 0: return
	var txt := ""
	for e in v.entidades:
		if str(e.get("tipo", "")) != "oficial": continue
		var s := str(e.get("senal", ""))
		var clave := "of_%s" % str(e.get("rol_oficial", ""))
		var m: Jugador3D = v._personas.get(clave)
		if s != "" and s != "bandera_baja" or clave.begins_with("of_asist"):
			txt += " %s[%s %s t=%.2f p=(%.1f,%.1f)]" % [clave, s, m._anim_actual if m else "-", m.animador.current_animation_position if m else 0.0, m.global_position.x if m else 0.0, m.global_position.z if m else 0.0]
	var c := v._camara_3d.global_position
	print("pos %.2f pelota=(%.1f,%.1f) centro=(%.1f,%.1f) cam3d=(%.1f,%.1f,%.1f) foco=%s peso=%.2f zoom=%.2f festejo=%.2f%s" % [pos,
		v._pelota.global_position.x, v._pelota.global_position.z, v.camara.centro.x, v.camara.centro.y, c.x, c.y, c.z,
		str(v._foco_oficial), v._foco_peso, v._foco_zoom, _m.reproductor._festejo_restante, txt])
