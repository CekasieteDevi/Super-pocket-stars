extends SceneTree
## Un tiro libre en detalle: -- semilla_n tick_falta
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]); var k0 := int(args[1])
	var rng := RandomNumberGenerator.new()
	rng.seed = PrototipoVista.SEMILLA + n
	var local := Team.generar("Atlético Prueba", rng)
	var visita := Team.generar("Deportivo Banco", rng, 1000)
	var fotos: Array = MotorEspacial.simular(local, visita, rng, true)["fotogramas"]
	for k in range(k0, mini(fotos.size(), k0 + 26)):
		var f: Dictionary = fotos[k]
		var p: Dictionary = f["pelota"]
		var bola := Vector2(p["x"], p["y"])
		var cerca := []
		for j in f["jugadores"]:
			var d := Vector2(j["x"], j["y"]).distance_to(bola)
			if d < 12.0:
				cerca.append("%s%s(%.1f,%.1f)" % ["L" if j["equipo_local"] else "V", j["id"], j["x"], j["y"]])
		print("%d det=%s foco=%s bola(%.1f,%.1f) pos%s ev=%s acc=%s | %s" % [k, str(f.get("detenido")), str(f.get("foco")), bola.x, bola.y,
			p.get("poseedor_id", -1), f.get("eventos", []).map(func(e): return e.get("tipo", "")),
			f.get("acciones", []).map(func(a): return str(a["accion"]) + "@" + str(a["clave"])), " ".join(cerca)])
	quit()
