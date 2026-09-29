extends SceneTree
## Jugadores que andan de espaldas (bug 3D-04) en un partido del prototipo 3D:
##   --fixed-fps 30 -- division=1 semilla=N [desde=T] [hasta=T] [detalle]
## Con una animación de andar y a más de 0.8 m/s, el frente del modelo contra
## hacia donde se mueve el dibujo: ESPALDAS si el ángulo pasa 110° durante
## 0.2 s de partido o más, con la acción del motor (ESPALDAS_PECHO, ...).
var _p: Prototipo3D
var _n := 0
var _casos := {}
var _prev := {}
var _desde := 0.0
var _hasta := INF
const ANDAR := ["Caminar", "Trotar", "Correr", "Forcejear", "Forcejear_Izq"]
func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("desde="): _desde = float(a.trim_prefix("desde="))
		if a.begins_with("hasta="): _hasta = float(a.trim_prefix("hasta="))
	_p = (load("res://match/3d/prototipo_3d.tscn") as PackedScene).instantiate()
	root.add_child(_p)
	process_frame.connect(_ver)
func _ver() -> void:
	_n += 1
	var rep := _p.reproductor
	if rep == null or rep.vista == null: return
	if _n == 3 and _desde > 0.0:
		rep.posicion = _desde
	if _n < 4: return
	var v := rep.vista as VistaCancha3D
	var pos := rep.posicion
	if pos >= minf(_hasta, float(rep.fotogramas.size() - 2)) or _n > 60000:
		print("RESUMEN ", _casos, " cuadros ", _n)
		quit(); return
	var seg := v._segundos
	for pie in v._pies:
		var p: Jugador3D = pie["modelo"]
		var id := int(pie["id"])
		var aqui := Vector2(p.global_position.x, p.global_position.z)
		var antes: Vector2 = _prev.get(id, aqui)
		_prev[id] = aqui
		if seg <= 0.0: continue
		var a := str(p._anim_actual)
		if a not in ANDAR: continue
		var vel := (aqui - antes) / seg
		if vel.length() < 0.8: continue
		var frente := Vector2(sin(p.rotation.y), cos(p.rotation.y))
		var ang := rad_to_deg(frente.angle_to(vel.normalized()))
		var acc := str(pie["accion"])
		if absf(ang) < 110.0:
			_cerrar(id)
			continue
		if not _tramo.has(id):
			_tramo[id] = {"desde": pos, "seg": 0.0, "acc": acc, "anim": a, "ang": 0.0, "vel": 0.0}
		var t: Dictionary = _tramo[id]
		t["seg"] = float(t["seg"]) + seg
		t["ang"] = maxf(float(t["ang"]), absf(ang))
		t["vel"] = maxf(float(t["vel"]), vel.length())
		if acc != "" and str(t["acc"]) == "": t["acc"] = acc
		if OS.get_cmdline_user_args().has("detalle"): print("  %.2f id %d %s acc=%s ang %.0f vel %.1f" % [pos, id, a, acc, ang, vel.length()])
	for id in _tramo.keys():
		if not v._pies.any(func(pp): return int(pp["id"]) == id): _cerrar(id)
var _tramo := {}
## Un tramo de espaldas terminado: cuenta si duró 0.2 s de partido o más
## (girando a 10 rad/s pasa 110-180° unos 0.1 s: eso no es andar de espaldas).
func _cerrar(id: int) -> void:
	if not _tramo.has(id): return
	var t: Dictionary = _tramo[id]
	_tramo.erase(id)
	if float(t["seg"]) < 0.2: return
	var acc := str(t["acc"])
	var tipo := "ESPALDAS" + ("_" + acc.to_upper() if acc != "" else "")
	_casos[tipo] = int(_casos.get(tipo, 0)) + 1
	var rep := _p.reproductor
	var f: Dictionary = rep.fotogramas[mini(int(t["desde"]), rep.fotogramas.size() - 1)]
	print("CASO %s tick %.1f min %d | id %d %s %.2f s hasta %.1f m/s %.0f°" % [tipo, float(t["desde"]), int(f.get("minuto", 0)), id, str(t["anim"]), float(t["seg"]), float(t["vel"]), float(t["ang"])])
