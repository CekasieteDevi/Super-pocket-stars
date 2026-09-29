extends SceneTree
## El árbitro en la tarjeta, cuadro a cuadro: -- clip=25
var _m: MuestraAnimaciones3D
var _n := 0
var _vueltas := 0
var _prev := -1.0

func _initialize() -> void:
	_m = (load("res://match/3d/muestra_animaciones_3d.tscn") as PackedScene).instantiate()
	root.add_child(_m)
	process_frame.connect(_ver)

func _ver() -> void:
	_n += 1
	if _m.reproductor == null or _m.reproductor.vista == null: return
	var v := _m.reproductor.vista as VistaCancha3D
	var pos := _m.reproductor.posicion
	if pos < _prev - 5.0:
		_vueltas += 1
		if _vueltas >= 1: quit()
	_prev = pos
	if _n == 40:
		for t in v._tarjetas:
			print("TARJETA falta=%s saque=%s roja=%s lugar=%s" % [t["falta"], t["saque"], t["roja"], str(t["lugar"])])
		for i in range(580, 600):
			for e in _m.reproductor.fotogramas[i].get("eventos", []):
				print("  EV %d %s %s" % [i, e.get("tipo", ""), e.get("resultado", "")])
	if _n % 8 != 0: return
	var m: Jugador3D = v._personas.get("of_arbitro")
	var cosas: Dictionary = v._utileria.get("of_arbitro", {})
	var tj: Node3D = cosas.get("tarjeta")
	var r: Dictionary = v._tarjetas[0] if not v._tarjetas.is_empty() else {}
	if m == null: return
	print("pos %.2f anim=%s t=%.2f tarjeta=%s llega=%s fin=%s dibujado=(%.1f,%.1f)" % [pos, m._anim_actual,
		m.animador.current_animation_position, tj.visible if tj else "-", str(r.get("llega", "-")), str(r.get("fin", "-")),
		m.global_position.x, m.global_position.z])
