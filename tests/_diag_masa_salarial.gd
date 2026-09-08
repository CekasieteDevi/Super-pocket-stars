extends SceneTree

## La masa salarial REAL que paga cada division (equipo.sueldos, lo que
## sale por caja) contra sus ingresos, en temporada 1 y en la 7.
##
## Es el control de la amortiguacion por division
## (ValorJugador.media_salarial). Antes de aplicarla, medido con la misma
## semilla: temporada 7 pagaba 108-137% de los ingresos en sueldos de
## division 4 para abajo, o sea toda la piramide baja en rojo estructural.

const SEED := 777
const TEMPORADAS := 6


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var piramide := Piramide.generar(rng)
	_reporte(piramide, "TEMPORADA 1")
	for t in range(TEMPORADAS):
		piramide.jugar_temporada(rng)
		piramide.fin_de_temporada(rng, null, t)
	_reporte(piramide, "TEMPORADA %d" % (TEMPORADAS + 1))
	quit()


func _reporte(piramide: Piramide, titulo: String) -> void:
	print("")
	print("=== %s ===" % titulo)
	print("div | media once | ingresos | sueldos | %ing | neto | clubes en rojo | mas caro")
	for d in range(10):
		var liga: Liga = piramide.divisiones[d]
		var n: int = liga.equipos.size()
		var suma_ing := 0.0
		var suma_sue := 0.0
		var suma_neto := 0.0
		var suma_media := 0.0
		var en_rojo := 0
		var caro := 0.0
		for i in range(n):
			var e: Team = liga.equipos[i]
			var informe := Economia.calcular_temporada(e, i + 1, n, d)
			suma_ing += float(informe["ingresos"])
			suma_sue += float(informe["sueldos"])
			suma_neto += float(informe["neto"])
			suma_media += e.media_equipo()
			if float(informe["neto"]) < 0.0:
				en_rojo += 1
			for id in e.sueldos:
				caro = maxf(caro, float(e.sueldos[id]))
		print("%3d | %10.1f | %8s | %8s | %3.0f%% | %9s | %2d/%d | %s" % [
			d + 1, suma_media / n,
			Economia.formato_dinero(suma_ing / n),
			Economia.formato_dinero(suma_sue / n),
			suma_sue / suma_ing * 100.0,
			Economia.formato_dinero(suma_neto / n),
			en_rojo, n, Economia.formato_dinero(caro)])
