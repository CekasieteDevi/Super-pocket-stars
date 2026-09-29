extends SceneTree
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]); var desde := int(args[1]); var hasta := int(args[2])
	var rng := RandomNumberGenerator.new()
	rng.seed = PrototipoVista.SEMILLA + n
	var local := Team.generar("Atlético Prueba", rng)
	var visita := Team.generar("Deportivo Banco", rng, 1000)
	var fotos: Array = MotorEspacial.simular(local, visita, rng, true)["fotogramas"]
	var seguidos := {}
	for i in range(desde, hasta):
		for a in fotos[i].get("acciones", []): seguidos[int(a["clave"])] = true
	for i in range(desde, hasta):
		var f: Dictionary = fotos[i]
		var p: Dictionary = f["pelota"]
		var txt := "%d pelota (%.1f,%.1f) z%.1f pos%s rem%s" % [i, p["x"], p["y"], float(p.get("z", 0)), p.get("poseedor_id", -1), p.get("es_remate", false)]
		for j in f["jugadores"]:
			var d := Vector2(j["x"], j["y"]).distance_to(Vector2(p["x"], p["y"]))
			if d < 5.0:
				txt += " | id%s %s (%.1f,%.1f) o(%.1f,%.1f)" % [j["id"], j.keys().filter(func(k): return k in ["clave", "equipo", "local", "equipo_local"]).map(func(k): return str(j[k])), j["x"], j["y"], float(j.get("ox", 0)), float(j.get("oy", 0))]
		for a in f.get("acciones", []): txt += " ACC " + str(a["accion"]) + "@" + str(a["clave"])
		for e in f.get("eventos", []): txt += " EV " + str(e.get("tipo", ""))
		print(txt)
	quit()
