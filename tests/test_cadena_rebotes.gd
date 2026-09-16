extends SceneTree

## Escena cerrada: dos rebotes aereos, duelo de cabeza ganado por el ataque
## y volea final. Si cambia una regla real, este clip tiene que seguir siendo
## visible y terminar en un solo gol local.
func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260915
	var casa := Team.generar("Casa", rng, 0)
	var visita := Team.generar("Visita", rng, 400)
	var propio := RandomNumberGenerator.new()
	propio.seed = Laboratorio.SEMILLA
	var resultado := Laboratorio.generar("cadena_rebotes", casa, visita, propio)

	assert(int(resultado["goles_local"]) == 1)
	assert(int(resultado["goles_visitante"]) == 0)

	var rebotes_aereos := 0
	var duelos_ganados := 0
	for evento in resultado["eventos"]:
		if str(evento.get("tipo", "")) != "rebote_arquero":
			continue
		if str(evento.get("resultado", "")) == "alto":
			rebotes_aereos += 1
		if str(evento.get("resultado", "")) == "control_atacante":
			duelos_ganados += 1
	assert(rebotes_aereos == 2)
	assert(duelos_ganados == 2)

	var cabezazos := 0
	var voleas := 0
	for fotograma in resultado["fotogramas"]:
		for accion in fotograma.get("acciones", []):
			if str(accion.get("accion", "")) == MotorEspacial.ACCION_CABECEA:
				cabezazos += 1
			if str(accion.get("accion", "")) == "volea":
				voleas += 1
	assert(cabezazos == 1)
	assert(voleas == 1)
	print("OK: cadena de 2 rebotes aereos, cabeza ganada y volea al gol.")
	quit()
