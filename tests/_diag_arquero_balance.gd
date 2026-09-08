extends SceneTree

## Que le hace al balance sacar al arquero del desplazamiento por estilo.
## Mismas semillas antes y despues: goles, tiros y atajadas por partido.

const SEED := 4242
const PARTIDOS := 40
const ESTILOS := ["Presión alta", "Tiki taka", "Juego directo", "Físico", "Contragolpe", "Defensivo"]


func _init() -> void:
	print("estilo (los dos equipos) | goles/partido | tiros al arco/partido")
	var goles_todos := 0.0
	for estilo in ESTILOS:
		var goles := 0
		var a_puerta := 0
		for p in range(PARTIDOS):
			var rng := RandomNumberGenerator.new()
			rng.seed = SEED + p * 977
			var casa := Team.generar("Casa", rng, p * 100)
			var visita := Team.generar("Visita", rng, 500 + p * 100)
			casa.estilo = estilo
			visita.estilo = estilo
			var res := MotorEspacial.simular(casa, visita, rng)
			goles += int(res["goles_local"]) + int(res["goles_visitante"])
			for ev in res["eventos"]:
				if str(ev.get("tipo", "")) in ["tiro_puerta", "penal"]:
					a_puerta += 1
		goles_todos += float(goles) / float(PARTIDOS)
		print("%-24s | %.2f          | %.2f" % [
			estilo, float(goles) / float(PARTIDOS), float(a_puerta) / float(PARTIDOS)])
	print("promedio de los seis estilos: %.2f goles/partido" % (goles_todos / float(ESTILOS.size())))
	quit()
