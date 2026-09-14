extends SceneTree

## El primer pase de un saque del medio nunca puede ser offside: los 22
## están en su propia mitad. El bug: la línea de offside no se recalcula
## con el juego detenido, así que el saque se juzgaba con la línea del
## ataque que terminó en gol.

const SEED := 7310

var fallos := 0


func _armar_estado(rng: RandomNumberGenerator) -> Dictionary:
	var casa := Team.generar("Casa", rng, 0)
	var visita := Team.generar("Visita", rng, 0)
	casa.reset_partido()
	visita.reset_partido()
	casa.local = true
	visita.local = false
	casa.clima_partido = Clima.generar(rng)
	visita.clima_partido = casa.clima_partido
	casa.arbitro_partido = Arbitro.generar(rng)
	visita.arbitro_partido = casa.arbitro_partido
	return MotorEspacial.crear_estado(casa, visita, rng)


func _init() -> void:
	var marcados := 0
	var mirados := 0
	for i in 20:
		for saca_local in [true, false]:
			var rng := RandomNumberGenerator.new()
			rng.seed = SEED + i
			var estado := _armar_estado(rng)
			# La línea que deja un ataque que terminó en gol: el que ataca
			# con la línea alta y el rival hundido en su área.
			if saca_local:
				estado["linea_offside"] = {"local": -15.0, "away": -45.0}
			else:
				estado["linea_offside"] = {"local": 45.0, "away": 15.0}
			MotorEspacial._reiniciar_desde_medio(estado, saca_local)
			var pelota: Dictionary = estado["pelota"]
			var tope := 60
			while not pelota["en_vuelo"] and tope > 0:
				MotorEspacial._tick(estado, false)
				tope -= 1
			if not pelota["en_vuelo"]:
				continue
			mirados += 1
			if bool(pelota.get("offside", false)):
				marcados += 1
	if mirados == 0:
		fallos += 1
		print("FALLA: ningún saque del medio salió como pase.")
	elif marcados > 0:
		fallos += 1
		print("FALLA: %d de %d saques del medio salieron marcados offside." % [marcados, mirados])
	else:
		print("OK: ninguno de %d saques del medio salió marcado offside." % mirados)
	print("\nFALLOS=%d" % fallos)
	quit()
