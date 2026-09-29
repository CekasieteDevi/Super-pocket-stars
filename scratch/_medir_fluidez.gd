extends SceneTree
## Fluidez de los jugadores en fotogramas del motor (juego corriendo):
## frenadas en seco (de >4 m/s a <0.8 m/s en un tick), arranques en seco
## (de <0.8 a >4) y cambios de velocidad de más de 3 m/s por tick.
func _initialize() -> void:
	var total := {"frenadas": 0, "arranques": 0, "saltos": 0, "muestras": 0}
	for n in 4:
		var rng := RandomNumberGenerator.new()
		rng.seed = PrototipoVista.SEMILLA + n
		var d := 0
		var local := Team.generar("Atlético Prueba", rng, 0, NivelDivision.potencial(d), "Uruguay", NivelDivision.realizacion(d))
		var visita := Team.generar("Deportivo Banco", rng, 1000, NivelDivision.potencial(d), "Uruguay", NivelDivision.realizacion(d))
		var fotos: Array = MotorEspacial.simular(local, visita, rng, true)["fotogramas"]
		for k in range(2, fotos.size()):
			var f2: Dictionary = fotos[k]; var f1: Dictionary = fotos[k - 1]; var f0: Dictionary = fotos[k - 2]
			if int(f2.get("detenido", 0)) > 0 or int(f1.get("detenido", 0)) > 0 or int(f0.get("detenido", 0)) > 0:
				continue
			if bool(f2.get("reubicacion", false)) or bool(f1.get("reubicacion", false)):
				continue
			var p0 := {}; var p1 := {}
			for j in f0["jugadores"]: p0[j["id"]] = Vector2(j["x"], j["y"])
			for j in f1["jugadores"]: p1[j["id"]] = Vector2(j["x"], j["y"])
			for j in f2["jugadores"]:
				if not p0.has(j["id"]) or not p1.has(j["id"]): continue
				var v1: float = (p1[j["id"]] as Vector2).distance_to(p0[j["id"]]) / MotorEspacial.TICK_SEG
				var v2: float = Vector2(j["x"], j["y"]).distance_to(p1[j["id"]]) / MotorEspacial.TICK_SEG
				total["muestras"] += 1
				if v1 > 4.0 and v2 < 0.8: total["frenadas"] += 1
				if v1 < 0.8 and v2 > 4.0: total["arranques"] += 1
				if absf(v2 - v1) > 3.0: total["saltos"] += 1
	print("FLUIDEZ 4 partidos: ", total, " por partido: frenadas %.0f arranques %.0f saltos %.0f" % [total["frenadas"] / 4.0, total["arranques"] / 4.0, total["saltos"] / 4.0])
	quit()
