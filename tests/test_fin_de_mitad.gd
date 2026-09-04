extends SceneTree

## Una mitad no se termina con una jugada a medio jugar.
##
## Bug encontrado jugando la 1.5: minuto 97, corner para el jugador, y el
## partido cerro con la pelota en el banderin. El corner nunca se pateo.
##
## La regla que se fijo:
##  - Lo que se cobro ANTES de que se acabara el tiempo se ejecuta.
##  - La mitad cierra en el primer corte NUEVO: gol, pelota afuera,
##    atajada o falta. Eso que se cobra ya no se patea.
##  - El penal es la excepcion: cobrado en el descuento, igual se patea.

const SEED := 909
const PARTIDOS := 40


func _init() -> void:
	var fallos := 0
	fallos += _test_ninguna_mitad_queda_a_medias()
	fallos += _test_que_cuenta_como_jugada_sin_terminar()
	print("FALLOS=%d" % fallos)
	quit()


## El sintoma directo: `cortadas` cuenta las mitades que se cerraron con
## una pelota parada sin ejecutar, un centro en el aire o un remate
## viajando. Tiene que dar cero.
func _test_ninguna_mitad_queda_a_medias() -> int:
	print("=== Ninguna mitad cierra con la jugada sin terminar ===")
	var cortadas := {}
	var total := 0
	for i in range(PARTIDOS):
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + i
		var casa := Team.generar("Casa", rng, 0)
		var visita := Team.generar("Visita", rng, 400)
		var res := MotorEspacial.simular(casa, visita, rng)
		for tipo in res["stats"]["cortadas"]:
			cortadas[tipo] = int(cortadas.get(tipo, 0)) + int(res["stats"]["cortadas"][tipo])
			total += int(res["stats"]["cortadas"][tipo])
	if total > 0:
		print("FALLA: %d de %d mitades cerraron a medias: %s" % [
			total, PARTIDOS * 2, str(cortadas)])
		return 1
	print("OK: las %d mitades de %d partidos cerraron con la jugada terminada." % [
		PARTIDOS * 2, PARTIDOS])
	return 0


## El contrato de _hay_algo_sin_terminar, que es lo que decide si la
## mitad sigue. El saque del medio NO cuenta: un gol sobre la hora
## termina la mitad, no la estira hasta la reanudacion.
func _test_que_cuenta_como_jugada_sin_terminar() -> int:
	print("=== Que cuenta como jugada sin terminar ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var casa := Team.generar("Casa", rng, 0)
	var visita := Team.generar("Visita", rng, 400)
	casa.reset_partido()
	visita.reset_partido()
	casa.local = true
	visita.local = false
	casa.clima_partido = Clima.generar(rng)
	visita.clima_partido = casa.clima_partido
	casa.arbitro_partido = Arbitro.generar(rng)
	visita.arbitro_partido = casa.arbitro_partido
	var estado := MotorEspacial.crear_estado(casa, visita, rng)

	var casos := [
		# [descripcion, balon_parado, detenido, en_vuelo, es_remate, esperado]
		["cancha vacia de jugadas", {}, 0, false, false, false],
		["corner por patear", {"tipo": "corner"}, 20, false, false, true],
		["falta por patear", {"tipo": "directo"}, 14, false, false, true],
		["penal por patear", {"tipo": "penal"}, 20, false, false, true],
		["gol: saque del medio", {"tipo": "saque_medio"}, 10, false, false, false],
		["arranque de tiempo", {"tipo": "saque_inicial"}, 12, false, false, false],
		["centro en el aire", {}, 0, true, false, true],
		["remate viajando", {}, 0, false, true, true],
	]
	var fallos := 0
	for caso in casos:
		if (caso[1] as Dictionary).is_empty():
			estado.erase("balon_parado")
		else:
			estado["balon_parado"] = caso[1]
		estado["detenido"] = caso[2]
		estado["pelota"]["en_vuelo"] = caso[3]
		estado["pelota"]["es_remate"] = caso[4]
		var dio: bool = MotorEspacial._hay_algo_sin_terminar(estado)
		if dio != bool(caso[5]):
			print("FALLA: %s dio %s y tenia que dar %s." % [caso[0], dio, caso[5]])
			fallos += 1
	if fallos == 0:
		print("OK: los %d casos de fin de mitad responden como se fijo." % casos.size())
	return fallos
