extends SceneTree

## Cuánto salta el ejecutor de un balón parado en el tick del saque, y
## cuánto cuesta en juego esperar a que llegue. Mide goles, remates y
## ticks detenidos con las mismas semillas, para comparar antes y después.
const SEED := 4400
const PARTIDOS := 60


func _init() -> void:
	var saltos := []
	var goles := 0
	var remates := 0
	var detenidos := 0
	var ticks := 0
	var reinicios := 0
	var tipos := {}
	var directos := 0
	for division in [9, 4, 0]:
		for i in range(PARTIDOS):
			var r1 := RandomNumberGenerator.new()
			r1.seed = SEED + i
			var a := Team.generar("A", r1, 0, NivelDivision.potencial(division),
				"Uruguay", NivelDivision.realizacion(division))
			var b := Team.generar("B", r1, 400, NivelDivision.potencial(division),
				"Uruguay", NivelDivision.realizacion(division))
			var r2 := RandomNumberGenerator.new()
			r2.seed = SEED + i
			var res := MotorEspacial.simular(a, b, r2, true)
			goles += int(res["goles_local"]) + int(res["goles_visitante"])
			remates += int(res["stats"]["tiros"]["home"]) + int(res["stats"]["tiros"]["away"])
			for ev in res["eventos"]:
				var tp := str(ev.get("tipo", ""))
				if tp in ["falta", "corner", "lateral", "saque_arco", "gol", "penal"]:
					tipos[tp] = int(tipos.get(tp, 0)) + 1
			directos += int(res["stats"].get("libres_directos", 0)) if res["stats"].has("libres_directos") else 0
			var lista: Array = res["fotogramas"]
			ticks += lista.size()
			for k in range(1, lista.size()):
				var fa: Dictionary = lista[k - 1]
				var fb: Dictionary = lista[k]
				if int(fb.get("detenido", 0)) > 0:
					detenidos += 1
				# Tick del saque: el juego venía detenido y arranca.
				if int(fa.get("detenido", 0)) <= 0 or int(fb.get("detenido", 0)) != 0 \
						or bool(fb.get("corte", false)):
					continue
				reinicios += 1
				var maximo := 0.0
				for jb in fb["jugadores"]:
					for ja in fa["jugadores"]:
						if ja["id"] == jb["id"]:
							maximo = maxf(maximo, Vector2(ja["x"], ja["y"]).distance_to(Vector2(jb["x"], jb["y"])))
				saltos.append(maximo)
	saltos.sort()
	var grandes := saltos.filter(func(s): return s > 2.0).size()
	var n := float(PARTIDOS * 3)
	print("REINICIOS=%d SALTO>2m=%d (%.1f%%) p50=%.2f p90=%.2f max=%.2f" % [
		reinicios, grandes, 100.0 * grandes / maxf(1.0, saltos.size()),
		saltos[saltos.size() / 2], saltos[int(saltos.size() * 0.9)], saltos[-1]])
	print("GOLES/PARTIDO=%.2f REMATES/PARTIDO=%.2f TICKS=%.0f DETENIDOS=%.1f%%" % [
		goles / n, remates / n, ticks / n, 100.0 * detenidos / maxf(1.0, ticks)])
	for tp in tipos:
		tipos[tp] = snappedf(float(tipos[tp]) / n, 0.01)
	print("POR_PARTIDO ", tipos, " DIRECTOS=", directos)
	quit()
