extends SceneTree

## Cuantas rondas de ida y vuelta tarda en cerrar segun lo que ofrezcas.
## Cada ronda es un click de "Ofrecer" en el modal, asi que de esto
## depende que la negociacion se sienta como una charla o como una grilla.

func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	print("cesion=%.2f piso=%.2f" % [
		Renovaciones.CESION_POR_RONDA, Renovaciones.PISO_DE_CESION])
	print("ofrecido | rondas hasta cerrar")
	for pct in [0.98, 0.95, 0.92, 0.90, 0.88, 0.86, 0.84, 0.82, 0.80, 0.76]:
		var equipo := Team.generar("C", rng, 42)
		var jugador: Dictionary = equipo.jugadores[0]
		equipo.contratos[jugador["id"]] = 1
		var oferta: float = Renovaciones.pide_ahora(equipo, jugador, 2) * pct
		var rondas := 0
		var resp := "contraoferta"
		while resp == "contraoferta" and rondas < 30:
			resp = str(Renovaciones.ofrecer(equipo, jugador, 2, oferta)["respuesta"])
			rondas += 1
		print("%6.0f%% | %d (%s)" % [pct * 100.0, rondas, resp])
	quit()
