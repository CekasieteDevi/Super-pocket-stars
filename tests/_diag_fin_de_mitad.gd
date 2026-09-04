extends SceneTree

## Como termina cada mitad. Mide el bug de la 1.5: se cobro un corner en
## el minuto 97 y el tiempo se acabo antes de que lo patearan.
##
## `cortadas` es el sintoma: mitades que se cerraron con una pelota
## parada sin ejecutar o un remate viajando. Tiene que ser 0.
## Los goles van al lado porque el descuento agrega juego: si suben
## mucho, el descuento se paso de largo.

const SEED := 909
const PARTIDOS := 60


func _init() -> void:
	var goles := 0
	var cortadas := {}
	var reinicios := {}
	var penales := 0
	for i in range(PARTIDOS):
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + i
		var casa := Team.generar("Casa", rng, 0)
		var visita := Team.generar("Visita", rng, 400)
		var r := MotorEspacial.simular(casa, visita, rng)
		goles += int(r["goles_local"]) + int(r["goles_visitante"])
		penales += int(r["stats"]["penales"])
		for k in r["stats"]["cortadas"]:
			cortadas[k] = int(cortadas.get(k, 0)) + int(r["stats"]["cortadas"][k])
		for k in r["stats"]["reinicios"]:
			reinicios[k] = int(reinicios.get(k, 0)) + int(r["stats"]["reinicios"][k])

	var mitades := PARTIDOS * 2
	var total := 0
	for k in cortadas:
		total += int(cortadas[k])
	print("%d partidos (%d mitades), semilla %d" % [PARTIDOS, mitades, SEED])
	print("  goles por partido:   %.2f" % (float(goles) / PARTIDOS))
	print("  penales por partido: %.2f" % (float(penales) / PARTIDOS))
	print("  MITADES CORTADAS con la jugada sin terminar: %d de %d (%.1f%%)" % [
		total, mitades, 100.0 * total / mitades])
	for k in cortadas:
		print("    %-14s %d" % [k, int(cortadas[k])])
	for k in reinicios:
		print("  reinicio %-12s %.2f por partido" % [k, float(reinicios[k]) / PARTIDOS])
	quit()
