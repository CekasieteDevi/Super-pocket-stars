extends SceneTree

## De donde salen los cabezazos y cuantos hay. El cabezazo es el unico
## remate que no se juega con el pie, asi que es la unica fuente de la
## pose CABECEA: si el motor los emite poco, el sprite no se ve nunca.

const SEMILLA := 20260908
const PARTIDOS := 30


func _init() -> void:
	var total := {"intentos": 0, "caidos": 0, "ganados": 0, "cabezazos": 0, "descolgado": 0}
	var tiros := 0
	var goles := 0
	for i in range(PARTIDOS):
		var rng := RandomNumberGenerator.new()
		rng.seed = SEMILLA + i
		var local := Team.generar("Local %d" % i, rng)
		var visita := Team.generar("Visita %d" % i, rng, 1000)
		var r := MotorEspacial.simular(local, visita, rng, false)
		var c: Dictionary = r["stats"]["centros"]
		for k in total:
			total[k] += int(c.get(k, 0))
		goles += int(r["goles_local"]) + int(r["goles_visitante"])
		for ev in r["eventos"]:
			if str(ev.get("tipo", "")) in ["tiro", "tiro_puerta"]:
				tiros += 1

	print("en %d partidos:" % PARTIDOS)
	print("  centros intentados: %d  (%.1f por partido)" % [
		total["intentos"], float(total["intentos"]) / PARTIDOS])
	print("  llegaron a caer:    %d" % total["caidos"])
	print("  los descuelga el arquero: %d" % total["descolgado"])
	print("  los gana el atacante:     %d" % total["ganados"])
	print("  TERMINAN EN CABEZAZO:     %d  (%.2f por partido)" % [
		total["cabezazos"], float(total["cabezazos"]) / PARTIDOS])
	print("  remates totales: %d -> el %.1f%% son de cabeza" % [
		tiros, 100.0 * total["cabezazos"] / maxf(tiros, 1)])
	print("  goles: %d" % goles)
	quit()
