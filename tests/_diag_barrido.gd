extends SceneTree

## Barre (aciertos para rematar, fallos que cortan) y mide cuanto se
## parece cada combinacion a la tabla del motor espacial.

const SEED := 700
const PARTIDOS := 20
const OBJETIVO := [[1.80, 0.97], [2.67, 0.47], [5.03, 0.10], [5.53, 0.07]]
const PARES := [[0, 0], [0, 1], [0, 2], [0, 4]]


func _init() -> void:
	print("N=duelos por ataque, K=aciertos para rematar")
	print(" N  K |  0 pts      6 pts      12 pts     24 pts   | error")
	var mejor := 999.0
	var mejor_txt := ""
	for w in range(8, 17):
		for l in range(2, w + 1):
			var fila := []
			var error := 0.0
			for i in range(PARES.size()):
				var r := _medir(PARES[i], w, l)
				fila.append(r)
				# Error relativo: importa mas equivocarse por el doble en
				# 1.8 que por 0.5 en 5.5.
				error += absf(r[0] - OBJETIVO[i][0]) / OBJETIVO[i][0]
				error += absf(r[1] - OBJETIVO[i][1]) / maxf(OBJETIVO[i][1], 0.3)
			var txt := "%2d %2d | %4.2f-%4.2f  %4.2f-%4.2f  %4.2f-%4.2f  %4.2f-%4.2f | %.2f" % [
				w, l, fila[0][0], fila[0][1], fila[1][0], fila[1][1],
				fila[2][0], fila[2][1], fila[3][0], fila[3][1], error]
			print(txt)
			if error < mejor:
				mejor = error
				mejor_txt = txt
	print("")
	print("MEJOR: %s" % mejor_txt)
	quit()


func _medir(par: Array, w: int, l: int) -> Array:
	var ga := 0
	var gb := 0
	for n in range(PARTIDOS):
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + n
		var a := Team.generar("A", rng, 0, NivelDivision.potencial(par[0]),
			"Uruguay", NivelDivision.realizacion(par[0]))
		var b := Team.generar("B", rng, 400, NivelDivision.potencial(par[1]),
			"Uruguay", NivelDivision.realizacion(par[1]))
		var r := MatchEngine.simular_con(a, b, rng, w, l)
		ga += int(r["goles_local"])
		gb += int(r["goles_visitante"])
	return [float(ga) / PARTIDOS, float(gb) / PARTIDOS]
