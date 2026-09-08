extends SceneTree

## Mantenimiento como costo fijo del club que ESCALA con la division.
##
## Antes eran $25.000 planos para todos y no habia forma de gastarlos: se
## descontaban de los ingresos y en paralelo el club recibia una reserva
## de $12.500 que solo servia para pagar multas. Las multas se eliminaron
## y la reserva con ellas (ver Economia.CATEGORIAS_CAJA).
##
## Lo que se mide ahora es lo que reemplazo a todo eso: que el
## mantenimiento no dependa de lo que el club gaste en sueldos, y que
## pese lo mismo en proporcion arriba que abajo de la piramide. Con
## $25.000 planos se comia el 46% de los ingresos de un club de decima y
## era ruido en primera.
##
## Correr con: godot --headless --script tests/test_economia_mantenimiento.gd

const SEED := 4242

var fallos := 0


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	_test_no_depende_de_los_sueldos(rng)
	_test_escala_con_la_division(rng)
	_test_ninguna_categoria_de_caja_sobra(rng)

	print("\nFALLOS=%d" % fallos)
	quit()


func _test_no_depende_de_los_sueldos(rng: RandomNumberGenerator) -> void:
	print("=== Mantenimiento: el mismo costo con sueldos bajos o altos ===")
	var barato := Team.generar("Barato", rng, 0)
	var caro := Team.generar("Caro", rng, 1000)
	for id in caro.sueldos:
		caro.sueldos[id] *= 20.0  # simula haber fichado carisimo

	var informe_barato := Economia.calcular_temporada(barato, 10, 20, 5)
	var informe_caro := Economia.calcular_temporada(caro, 10, 20, 5)

	if is_equal_approx(informe_barato["mantenimiento"], informe_caro["mantenimiento"]):
		print("OK: los dos pagan %s de mantenimiento en la misma division." % (
			Economia.formato_dinero(informe_barato["mantenimiento"])))
	else:
		print("FALLA: barato=%s caro=%s" % [
			informe_barato["mantenimiento"], informe_caro["mantenimiento"]])
		fallos += 1


func _test_escala_con_la_division(rng: RandomNumberGenerator) -> void:
	print("\n=== Mantenimiento: sube con la categoria y no aplasta a las de abajo ===")
	var equipo := Team.generar("ClubEscala", rng, 7)

	var anterior := 0.0
	var sube_siempre := true
	for d in range(9, -1, -1):
		var m: float = Economia.MANTENIMIENTO_BASE * Economia.factor_division(d)
		if m <= anterior:
			sube_siempre = false
		anterior = m

	# Lo que importa de verdad: cuanto de los ingresos se lleva. Con
	# $25.000 planos decima entregaba el 46% y primera casi nada.
	var informe_decima := Economia.calcular_temporada(equipo, 10, 20, 9)
	var peso: float = float(informe_decima["mantenimiento"]) / float(informe_decima["ingresos"])

	if sube_siempre and peso < 0.30:
		print("OK: el mantenimiento sube de decima a primera y en decima se lleva el %.0f%% de los ingresos." % (peso * 100.0))
	else:
		print("FALLA: sube_siempre=%s peso_en_decima=%.0f%%" % [sube_siempre, peso * 100.0])
		fallos += 1


func _test_ninguna_categoria_de_caja_sobra(rng: RandomNumberGenerator) -> void:
	print("\n=== La caja no tiene categorias que el jugador no pueda gastar ===")
	var equipo := Team.generar("ClubCaja", rng, 11)
	Economia.procesar_temporada(equipo, 10, 20, 7)

	var sobra := []
	for categoria in equipo.caja:
		if not Economia.PRESUPUESTO_PORCENTAJES.has(categoria):
			sobra.append(categoria)

	if sobra.is_empty() and equipo.caja.size() == Economia.CATEGORIAS_CAJA.size():
		print("OK: las %d categorias de la caja son las tres que se reparten del neto." % equipo.caja.size())
	else:
		print("FALLA: sobran %s en la caja (%s)." % [sobra, equipo.caja.keys()])
		fallos += 1
