extends SceneTree
## Reproduce la muestra en vivo (con ventana) y guarda la pantalla cuando la
## reproducción pasa por los tiempos pedidos:
## -- clip=24 fotos=567.5,569 nombre=tarjeta
var _m: MuestraAnimaciones3D
var _tiempos: Array = []
var _nombre := "foto"
var _n := 0
var _cuadros := 0

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() != 2: continue
		if kv[0] == "fotos":
			for s in kv[1].split(","): _tiempos.append(float(s))
		if kv[0] == "nombre": _nombre = kv[1]
	_m = (load("res://match/3d/muestra_animaciones_3d.tscn") as PackedScene).instantiate()
	root.add_child(_m)
	process_frame.connect(_ver)

func _ver() -> void:
	_cuadros += 1
	if _cuadros > 4000 or _tiempos.is_empty():
		quit()
		return
	if _m.reproductor == null: return
	if _m.reproductor.posicion >= float(_tiempos[0]):
		root.get_texture().get_image().save_png("res://scratch/%s_%d.png" % [_nombre, _n])
		print("FOTO %s_%d en %.2f" % [_nombre, _n, _m.reproductor.posicion])
		_n += 1
		_tiempos.pop_front()
