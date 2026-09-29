extends SceneTree
## Goles, remates, pases y frenadas en seco en N partidos por nivel: -- n=20
func _initialize() -> void:
	var n := 20
	var divisiones := [0, 4, 9]
	var base := 555000
	for a in OS.get_cmdline_user_args():
		if a.begins_with("n="): n = int(a.trim_prefix("n="))
		for clave in ["frenada", "giro_acel", "arranque_extra"]:
			if a.begins_with(clave + "="): MotorEspacial.pesos()["fisica"][clave] = float(a.trim_prefix(clave + "="))
		if a.begins_with("div="): divisiones = [int(a.trim_prefix("div=")) - 1]
		if a.begins_with("base="): base = int(a.trim_prefix("base="))
	print("frenada=", MotorEspacial.pesos()["fisica"].get("frenada", "(no)"))
	for division in divisiones:
		var goles := 0; var remates := 0; var pases := 0; var frenadas := 0; var perdidos := 0
		for m in n:
			var rng := RandomNumberGenerator.new()
			rng.seed = base + m * 7 + division * 1000
			var local := Team.generar("A", rng, 0, NivelDivision.potencial(division), "Uruguay", NivelDivision.realizacion(division))
			var visita := Team.generar("B", rng, 1000, NivelDivision.potencial(division), "Uruguay", NivelDivision.realizacion(division))
			var r := MotorEspacial.simular(local, visita, rng, true)
			goles += int(r["goles_local"]) + int(r["goles_visitante"])
			var fotos: Array = r["fotogramas"]
			for k in range(2, fotos.size()):
				for e in fotos[k].get("eventos", []):
					var t := str(e.get("tipo", ""))
					if t in ["tiro", "tiro_puerta"]: remates += 1
					if t == "pase":
						pases += 1
						if str(e.get("resultado", "")) == "pierde": perdidos += 1
				if int(fotos[k].get("detenido", 0)) > 0 or int(fotos[k - 1].get("detenido", 0)) > 0 or int(fotos[k - 2].get("detenido", 0)) > 0: continue
				var p0 := {}; var p1 := {}
				for j in fotos[k - 2]["jugadores"]: p0[j["id"]] = Vector2(j["x"], j["y"])
				for j in fotos[k - 1]["jugadores"]: p1[j["id"]] = Vector2(j["x"], j["y"])
				for j in fotos[k]["jugadores"]:
					if not p0.has(j["id"]) or not p1.has(j["id"]): continue
					var v1: float = (p1[j["id"]] as Vector2).distance_to(p0[j["id"]]) / 0.25
					var v2: float = Vector2(j["x"], j["y"]).distance_to(p1[j["id"]]) / 0.25
					if v1 > 4.0 and v2 < 0.8: frenadas += 1
		print("DIV %d: goles %.2f remates %.1f pases %.1f (perdidos %.1f) frenadas %.0f por partido" % [division + 1, goles / float(n), remates / float(n), pases / float(n), perdidos / float(n), frenadas / float(n)])
	quit()
