extends SceneTree
## Nivel de los equipos del prototipo 3D (misma semilla).
func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = PrototipoVista.SEMILLA
	var local := Team.generar("Atlético Prueba", rng)
	var visita := Team.generar("Deportivo Banco", rng, 1000)
	for t: Team in [local, visita]:
		var m: float = t.media_equipo()
		print("%s media %.1f -> como un equipo de la división %d | estilo %s formación %s" % [t.nombre, m, NivelDivision.division_para_media(m) + 1, str(t.estilo), str(t.formacion)])
		var titulares: Array = t.jugadores
		var medias := []
		for j in titulares:
			medias.append("%s %d" % [str(j.get("posicion", j.get("rol", ""))), int(round(float(j["media"])))])
		print("   medias titulares: ", medias)
	quit()
