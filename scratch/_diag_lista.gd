extends SceneTree
## Fotogramas de la muestra (índice de la lista): -- desde hasta [id_jugador]
var _m: MuestraAnimaciones3D

func _initialize() -> void:
	_m = (load("res://match/3d/muestra_animaciones_3d.tscn") as PackedScene).instantiate()
	_m.en_loop = false
	root.add_child(_m)
	process_frame.connect(_ver)

func _ver() -> void:
	var rep := _m.reproductor
	if rep == null or rep.fotogramas.is_empty(): return
	var args := OS.get_cmdline_user_args()
	var id := int(args[2]) if args.size() > 2 else -1
	for i in range(int(args[0]), int(args[1])):
		var f: Dictionary = rep.fotogramas[i]
		var p: Dictionary = f["pelota"]
		var txt := "%d pelota (%.2f,%.2f) z%.2f pos%s" % [i, p["x"], p["y"], float(p.get("z", 0)), p.get("poseedor_id", -1)]
		var j := VistaPartido._jugador_en(f, id)
		if not j.is_empty():
			txt += " | j (%.2f,%.2f) o(%.2f,%.2f)" % [j["x"], j["y"], float(j.get("ox", 0)), float(j.get("oy", 0))]
		for jj in f["jugadores"]:
			var d := Vector2(jj["x"], jj["y"]).distance_to(Vector2(p["x"], p["y"]))
			if d < 4.0 and int(jj["id"]) != id:
				txt += " | id%s (%.2f,%.2f)" % [jj["id"], jj["x"], jj["y"]]
		for a in f.get("acciones", []): txt += " ACC %s@%s" % [a["accion"], a["clave"]]
		if not f.get("lateral_preparacion", {}).is_empty(): txt += " LAT %s" % str(f["lateral_preparacion"])
		if bool(f.get("corte", false)): txt += " CORTE"
		if bool(f.get("reubicacion", false)): txt += " REUB"
		if bool(f.get("detenido", false)): txt += " DET"
		for ev in f.get("eventos", []): txt += " EV %s" % str(ev.get("tipo", ""))
		var c: Dictionary = rep._coreografia.contactos.get(i, {})
		if not c.is_empty(): txt += " CONTACTO %s golpe %.2f dir %s" % [c["accion"], float(c["golpe"]), str(c["direccion"])]
		print(txt)
	quit()
