extends SceneTree

## La tabla objetivo la da el motor espacial, que es el que juega tus
## partidos de liga y ya se comporta bien. El abstracto tiene que dar lo
## mismo. Numeros del espacial, medidos con estos mismos equipos y semilla:
##
##   86 vs 86  ->  1.80 - 0.97
##   86 vs 80  ->  2.67 - 0.47
##   86 vs 74  ->  5.03 - 0.10
##   86 vs 62  ->  5.53 - 0.07

const SEED := 700
const PARTIDOS := 30
const OBJETIVO := [[1.80, 0.97], [2.67, 0.47], [5.03, 0.10], [5.53, 0.07]]


func _init() -> void:
	print("desnivel |   abstracto   |   objetivo    | tarjetas")
	var pares := [[0, 0], [0, 1], [0, 2], [0, 4]]
	for i in range(pares.size()):
		var par: Array = pares[i]
		var ga := 0
		var gb := 0
		var amarillas := 0
		var tiros := 0
		var maximo := 0
		for n in range(PARTIDOS):
			var rng := RandomNumberGenerator.new()
			rng.seed = SEED + n
			var a := Team.generar("A", rng, 0, NivelDivision.potencial(par[0]),
				"Uruguay", NivelDivision.realizacion(par[0]))
			var b := Team.generar("B", rng, 400, NivelDivision.potencial(par[1]),
				"Uruguay", NivelDivision.realizacion(par[1]))
			var r := MatchEngine.simular(a, b, rng, false)
			ga += int(r["goles_local"])
			gb += int(r["goles_visitante"])
			maximo = maxi(maximo, maxi(int(r["goles_local"]), int(r["goles_visitante"])))
			for e in r["eventos"]:
				if str(e.get("tipo", "")) == "tarjeta":
					amarillas += 1
				if ["tiro", "tiro_puerta", "rebote"].has(str(e.get("tipo", ""))):
					tiros += 1
		print("%2d puntos | %5.2f - %5.2f | %5.2f - %5.2f | %.2f tarj, %.1f tiros (max %d goles)" % [
			int(NivelDivision.media_de(par[0]) - NivelDivision.media_de(par[1])),
			float(ga) / PARTIDOS, float(gb) / PARTIDOS,
			OBJETIVO[i][0], OBJETIVO[i][1], float(amarillas) / PARTIDOS,
			float(tiros) / PARTIDOS, maximo])
	quit()
