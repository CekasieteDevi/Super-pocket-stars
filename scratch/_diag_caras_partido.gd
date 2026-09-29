extends SceneTree
## Fotos de las caras en el partido del prototipo 3D (medición, no test):
##   <godot> --path . --rendering-method gl_compatibility --rendering-driver opengl3
##     --script scratch/_diag_caras_partido.gd -- division=1 semilla=22
## En cada momento guarda la vista del juego y una de cerca del jugador.
## Momentos (semilla 22): cae 24 (clave 8), lesión 93 (clave 5), gol
## visitante 112 (festejo), juego normal 60.
var _p: Prototipo3D
var _n := 0
var _i := 0
var _saltado := false
var _espera := 0
const MOMENTOS := [
	{"t": 60.0, "clave": 8, "nombre": "normal"},
	{"t": 25.5, "clave": 8, "nombre": "cae"},
	{"t": 96.0, "clave": 5, "nombre": "lesion"},
	{"t": 112.0, "clave": 101009, "nombre": "gol", "festejo": true},
]
func _initialize() -> void:
	_p = (load("res://match/3d/prototipo_3d.tscn") as PackedScene).instantiate()
	root.add_child(_p)
	process_frame.connect(_ver)
func _ver() -> void:
	_n += 1
	var rep := _p.reproductor
	if rep == null or rep.vista == null or _n < 4: return
	var v := rep.vista as VistaCancha3D
	if _i >= MOMENTOS.size():
		quit(); return
	var m: Dictionary = MOMENTOS[_i]
	if not _saltado:
		v.camara_forzada = null
		rep.posicion = float(m["t"]) - (3.0 if m.get("festejo", false) else 0.0)
		rep.velocidad = 1.0
		_saltado = true
		_espera = 0
		return
	if m.get("festejo", false):
		if rep._idx_congelado == -1: return
		_espera += 1
		if _espera < 90: return
	else:
		# Casi quieto (la pausa oscurece la pantalla).
		if rep.posicion < float(m["t"]):
			rep.velocidad = 1.0
			return
		rep.velocidad = 0.02
		_espera += 1
		if _espera < 8: return
	var dir := OS.get_environment("TEMP") + "/caras/"
	if _espera == 90 or _espera == 8:
		root.get_texture().get_image().save_png(dir + "partido_%s_juego.png" % m["nombre"])
		# De cerca: frente al jugador.
		for p in v._personas.values():
			var j := p as Jugador3D
			if j.visible and j.clave_motor == int(m["clave"]):
				# Frente a la cara, siguiendo el hueso de la cabeza (el que
				# cae o está tirado la tiene mirando a cualquier lado).
				var h := j.hueso("Cabeza")
				var arriba := h.basis.y.normalized()
				var frente := h.basis.z.normalized() * signf(j.scale.x)
				var cara := h.origin + arriba * 0.28 * Jugador3D.ESCALA_CHIBI
				var ojo := cara + frente * 1.6 + arriba * 0.25
				v.camara_forzada = Transform3D(Basis.looking_at(cara - ojo, arriba), ojo)
				print(m["nombre"], " gesto ", j.gesto, " cara ", j.cara)
		return
	root.get_texture().get_image().save_png(dir + "partido_%s_cerca.png" % m["nombre"])
	rep.velocidad = 1.0
	_i += 1
	_saltado = false
