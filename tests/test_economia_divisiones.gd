extends SceneTree

## Calibracion de MULTIPLICADOR_DIVISION, medida sobre las diez ligas
## ENTERAS. La vez anterior se calibro con un club por division y quedo
## mal sin que nadie se enterara durante mucho tiempo, asi que el objetivo
## queda escrito como test.
##
## Los dos objetivos:
##  1. El mejor jugador de tu division cuesta entre 2 y 3 temporadas de
##     presupuesto de fichajes: para traerlo hay que vender.
##  2. Nadie nace quebrado.

const SEED := 777
const TEMPORADAS_MIN := 1.8
const TEMPORADAS_MAX := 3.2


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var piramide := Piramide.generar(rng)

	var fallo := false
	var en_rojo_total := 0
	var peor_ratio := 0.0
	var mejor_ratio := 99.0

	for d in range(10):
		var liga: Liga = piramide.divisiones[d]
		var n: int = liga.equipos.size()
		var suma_neto := 0.0
		var suma_mejores := 0.0
		for i in range(n):
			var e: Team = liga.equipos[i]
			var r := Economia.procesar_temporada(e, i + 1, n, d)
			suma_neto += float(r["neto"])
			if float(r["neto"]) < 0.0:
				en_rojo_total += 1
			var mejor_del_club := 0.0
			for j in e.jugadores:
				mejor_del_club = maxf(mejor_del_club, ValorJugador.calcular(j, 50.0, 3))
			suma_mejores += mejor_del_club

		var fichajes: float = (suma_neto / n) * Economia.PRESUPUESTO_PORCENTAJES["fichajes"]
		if fichajes <= 0.0:
			print("FALLA: division %d no deja nada para fichajes." % (d + 1))
			fallo = true
			continue
		var temporadas: float = (suma_mejores / n) / fichajes
		peor_ratio = maxf(peor_ratio, temporadas)
		mejor_ratio = minf(mejor_ratio, temporadas)
		if temporadas < TEMPORADAS_MIN or temporadas > TEMPORADAS_MAX:
			print("FALLA: en division %d el mejor jugador cuesta %.1f temporadas de presupuesto (se busca entre %.1f y %.1f)." % [
				d + 1, temporadas, TEMPORADAS_MIN, TEMPORADAS_MAX])
			fallo = true

	if en_rojo_total > 0:
		print("FALLA: %d clubes de 200 cierran la primera temporada en rojo." % en_rojo_total)
		fallo = true

	if not fallo:
		print("OK: en las diez divisiones el mejor jugador cuesta entre %.1f y %.1f temporadas de fichajes, y ninguno de los 200 clubes cierra en rojo." % [
			mejor_ratio, peor_ratio])

	_test_la_plata_crece_con_la_categoria(piramide)
	quit()


## Subir de division tiene que traer mas plata, siempre. Si un escalon
## diera menos que el de abajo, ascender seria un castigo economico.
func _test_la_plata_crece_con_la_categoria(_piramide: Piramide) -> void:
	print("\n=== Cada division de arriba multiplica mas que la de abajo ===")
	for d in range(9):
		var arriba: float = Economia.MULTIPLICADOR_DIVISION[d]
		var abajo: float = Economia.MULTIPLICADOR_DIVISION[d + 1]
		if arriba <= abajo:
			print("FALLA: division %d multiplica %.2f y division %d %.2f." % [
				d + 1, arriba, d + 2, abajo])
			return
	print("OK: de %.2f en primera a %.2f en decima, siempre bajando." % [
		Economia.MULTIPLICADOR_DIVISION[0], Economia.MULTIPLICADOR_DIVISION[9]])
