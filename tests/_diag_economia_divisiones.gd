extends SceneTree

## Cierra una temporada de las DIEZ divisiones enteras y mira el neto de
## cada club, no de uno de muestra. MULTIPLICADOR_DIVISION se calibro con
## un club por division, y ademas hoy cambio la reputacion inicial, de la
## que cuelga el aforo.

func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var piramide := Piramide.generar(rng)

	print("div | valor plantel | ingresos prom |    neto prom | presup.fichajes | fichajes/valor | mejor jugador")
	for d in range(10):
		var liga: Liga = piramide.divisiones[d]
		var n: int = liga.equipos.size()
		var suma_ing := 0.0
		var suma_egr := 0.0
		var suma_neto := 0.0
		var peor := INF
		var en_rojo := 0
		for i in range(n):
			var e: Team = liga.equipos[i]
			# Posicion i+1: se reparte de primero a ultimo, que es el
			# abanico completo de premios y sponsor.
			var r := Economia.procesar_temporada(e, i + 1, n, d)
			suma_ing += float(r["ingresos"])
			suma_egr += float(r["egresos"])
			suma_neto += float(r["neto"])
			peor = minf(peor, float(r["neto"]))
			if float(r["neto"]) < 0.0:
				en_rojo += 1
		var suma_valor := 0.0
		var mejor_jug := 0.0
		for e2 in liga.equipos:
			for j in e2.jugadores:
				var v := ValorJugador.calcular(j, 50.0, 3)
				suma_valor += v
				mejor_jug = maxf(mejor_jug, v)
		var valor_prom := suma_valor / n
		var fichajes: float = (suma_neto / n) * Economia.PRESUPUESTO_PORCENTAJES["fichajes"]
		print("%3d | %13s | %13s | %12s | %15s | %13.0f%% | %13s" % [
			d + 1,
			Economia.formato_dinero(valor_prom),
			Economia.formato_dinero(suma_ing / n),
			Economia.formato_dinero(suma_neto / n),
			Economia.formato_dinero(fichajes),
			fichajes / maxf(valor_prom, 1.0) * 100.0,
			Economia.formato_dinero(mejor_jug)])
	quit()
