extends SceneTree

## Cuanto vale un jugador y cuanto gana un club, por division.

func _init() -> void:
	print("=== Cuanto vale un jugador (animo 50, contrato 3 años) ===")
	print("media | 19 años  | 26 años  | 33 años  | sueldo anual (26)")
	for media in [40, 50, 60, 70, 80, 90, 99]:
		var fila := []
		for edad in [19, 26, 33]:
			var j := {"media": float(media), "edad": edad}
			fila.append(Economia.formato_dinero(ValorJugador.calcular(j, 50.0, 3)))
		var v26 := ValorJugador.calcular({"media": float(media), "edad": 26}, 50.0, 3)
		print("%5d | %-8s | %-8s | %-8s | %s" % [
			media, fila[0], fila[1], fila[2], Economia.formato_dinero(Economia.sueldo_sugerido(v26))])

	print("\n=== Cuanto gana un club por temporada (mitad de tabla) ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4321
	var p := Piramide.generar(rng)
	print("div | media |    ingresos |    sueldos  |        neto | de su nivel | temporadas para un 99")
	for d in range(p.divisiones.size()):
		var liga: Liga = p.divisiones[d]
		var e: Team = liga.equipos[0]
		var media := e.media_equipo()
		var r := Economia.procesar_temporada(e, 10, liga.equipos.size(), liga.division)
		var ing: float = float(r["ingresos"])
		var egr: float = float(r["egresos"])
		# Lo que cuesta un titular tipico de esa division.
		var tipico := ValorJugador.calcular({"media": media, "edad": 26}, 50.0, 3)
		# Cuantas temporadas de presupuesto de fichajes cuesta un media 99.
		var fichajes: float = (ing - egr) * Economia.PRESUPUESTO_PORCENTAJES["fichajes"]
		var elite := ValorJugador.calcular({"media": 99.0, "edad": 26}, 50.0, 3)
		print("%3d | %5.1f | %11s | %11s | %11s | %.1f | %.1f" % [
			d + 1, media, Economia.formato_dinero(ing), Economia.formato_dinero(egr),
			Economia.formato_dinero(ing - egr), (ing - egr) / max(1.0, tipico),
			elite / max(1.0, fichajes)])
	quit()
