extends SceneTree
## Tiro con efecto cuadro a cuadro: -- clip=28
var _m: MuestraAnimaciones3D
var _n := 0
var _prev := -1.0
var _vueltas := 0
var _inicio := -1.0

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
	if _inicio < 0.0: _inicio = pos
	if pos < _prev - 3.0:
		_vueltas += 1
		if _vueltas >= 2: quit()
	_prev = pos
	if _vueltas < 1 or _n % 2 != 0 or pos < 654.0 or pos > 664.0: return
	if _n < 20: print("efectos ", v._efectos)
	var txt := ""
	for clave in v._personas:
		var p: Jugador3D = v._personas[clave]
		if not p.visible: continue
		var a := str(p._anim_actual)
		if a in ["Remate_Efecto", "Efecto_Acomoda", "Atajar_Volando", "Atajar_Volando_Izq", "Patear_Corriendo"] or clave.ends_with("_1"):
			txt += " %s[%s t=%.2f (%.1f,%.1f,%.2f)]" % [clave.substr(0, 12), a, p.animador.current_animation_position, p.global_position.x, p.global_position.z, p.global_position.y]
	var b := v._pelota.global_position
	var e_p := Vector2.ZERO
	for e in v.entidades:
		if str(e.get("tipo", "")) == "pelota": e_p = e["pos"]
	print("pos %.2f pelota=(%.2f,%.2f) y=%.2f rep=(%.2f,%.2f) curva=%s%s" % [pos, b.x, b.z, b.y, e_p.x, e_p.y, str(v._pelota_en_curva()), txt.replace("0_8cd926_1[Golero_Guardia", "").substr(0, 200)])
