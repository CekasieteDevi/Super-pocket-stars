extends SceneTree
## Recorrido de la pelota de un tiro libre del Laboratorio: -- semilla
func _initialize() -> void:
	for s_txt in OS.get_cmdline_user_args():
		var s := int(s_txt)
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var casa := Team.generar("Atlético Prueba", rng)
		var visita := Team.generar("Deportivo Banco", rng, 1000)
		var fotos: Array = Laboratorio.generar("tiro_libre", casa, visita, rng)["fotogramas"]
		var txt := ""
		for k in range(20, mini(fotos.size(), 32)):
			var p: Dictionary = fotos[k]["pelota"]
			txt += " %d:(%.1f,%.1f,z%.1f)%s" % [k, p["x"], p["y"], float(p.get("z", 0)),
				",".join(fotos[k].get("eventos", []).map(func(e): return str(e.get("tipo", "")) + "/" + str(e.get("resultado", ""))))]
		print("SEMILLA %d total %d |%s" % [s, fotos.size(), txt])
	quit()
