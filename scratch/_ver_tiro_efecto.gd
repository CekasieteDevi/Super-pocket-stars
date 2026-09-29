extends SceneTree
## La jugada tiro_efecto del Laboratorio cuadro a cuadro: -- semilla=N
func _initialize() -> void:
	var semilla := Laboratorio.SEMILLA
	for a in OS.get_cmdline_user_args():
		if a.begins_with("semilla="): semilla = int(a.trim_prefix("semilla="))
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var casa := Team.generar("Atlético Prueba", rng)
	var visita := Team.generar("Deportivo Banco", rng, 1000)
	var r := Laboratorio.generar("tiro_efecto", casa, visita, rng)
	var fotos: Array = r["fotogramas"]
	print("semilla %d fotogramas %d goles %d-%d" % [semilla, fotos.size(), r["goles_local"], r["goles_visitante"]])
	for i in mini(fotos.size(), 40):
		var f: Dictionary = fotos[i]
		var acc := []
		for a in f.get("acciones", []): acc.append("%s:%s f=%.2f" % [a.get("clave", a.get("id", "")), a["accion"], float(a.get("fase", 0))])
		var ev := []
		for e in f.get("eventos", []): ev.append("%s/%s" % [e.get("tipo", ""), e.get("resultado", "")])
		var arq := ""
		for j in f["jugadores"]:
			if float(j["x"]) > 45.0: arq += " %s:%s(%.1f,%.1f)" % [str(j["id"]), str(j.get("rol", "")), j["x"], j["y"]]
		print("%d pelota=(%.2f,%.2f) z=%s det=%s %s acc=%s ev=%s tr=%s" % [i, f["pelota"]["x"], f["pelota"]["y"], str(f["pelota"].get("z", "")), str(f.get("detenido", "")), arq, str(acc), str(ev), str(f["pelota"].get("trayectoria", {}))])
		for e in f.get("eventos", []): print("   EV ", e)
	quit()
