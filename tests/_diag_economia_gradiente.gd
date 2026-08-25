extends SceneTree

## Que le hace el gradiente por division a la economia. Interesa sobre
## todo la division 10, que es donde arranca el jugador y donde se
## calibro el balance: antes todos los clubes nacian con reputacion 46
## (media pareja) y ahora decima nace en ~37.

func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4321
	var p := Piramide.generar(rng)
	print("div | media | reput | ingresos | egresos | neto | valor jugador | ingresos/jugador")
	for d in range(p.divisiones.size()):
		var liga: Liga = p.divisiones[d]
		var e: Team = liga.equipos[0]
		var rep := e.reputacion
		var media := e.media_equipo()
		var r := Economia.procesar_temporada(e, 10, liga.equipos.size(), liga.division)
		var valor := ValorJugador.calcular(e.jugadores[0], 50.0, 3)
		var ing: float = float(r.get("ingresos", 0.0))
		var egr: float = float(r.get("egresos", 0.0))
		print("%3d | %5.1f | %5.1f | %8.0f | %7.0f | %7.0f | %13.0f | %.1fx" % [
			d + 1, media, rep, ing, egr, ing - egr, valor, ing / max(1.0, valor)])
	quit()
