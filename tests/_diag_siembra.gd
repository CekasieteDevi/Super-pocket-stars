extends SceneTree

## Con cuanta plata arranca cada division en una partida nueva.

func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var p := Piramide.generar(rng)
	print("div | media | fichajes  | contratos | mejoras   | jugadores de su nivel que compra")
	for d in range(p.divisiones.size()):
		var liga: Liga = p.divisiones[d]
		var medio: int = int(liga.equipos.size() / 2.0)
		for e in liga.equipos:
			Economia.procesar_temporada(e, medio, liga.equipos.size(), liga.division)
		var e0: Team = liga.equipos[0]
		var tipico := ValorJugador.calcular({"media": e0.media_equipo(), "edad": 26}, 50.0, 3)
		print("%3d | %5.1f | %9s | %9s | %9s | %.1f" % [
			d + 1, e0.media_equipo(),
			Economia.formato_dinero(e0.caja["fichajes"]),
			Economia.formato_dinero(e0.caja["contratos"]),
			Economia.formato_dinero(e0.caja["mejoras"]),
			e0.caja["fichajes"] / max(1.0, tipico)])
	quit()
