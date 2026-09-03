extends SceneTree

## Reputacion e hinchada despues del rework de la v1.5.
##
## Lo que se cuida: que la hinchada sea EXPONENCIAL entre divisiones (un
## club de primera no puede tener los mismos hinchas que uno de decima),
## que la reputacion se mueva por titulos y ascensos y no solo por la
## tabla, que las partidas viejas —donde `fans` era un puntaje de 0 a
## 100— se migren en vez de quedar con cuarenta hinchas, y que los
## sponsors miren reputacion y hinchada.

const SEED := 7311


func _init() -> void:
	var fallas := 0
	fallas += _test_escala_exponencial()
	fallas += _test_apoyo()
	fallas += _test_temporada()
	fallas += _test_migracion()
	fallas += _test_reputacion_fuentes()
	fallas += _test_minimos_de_sponsor()
	print("FALLOS=%d" % fallas)
	quit()


func _equipo(division: int) -> Team:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + division
	var t := Team.generar("Prueba D%d" % (division + 1), rng, 9000,
		NivelDivision.potencial(division), "Uruguay", NivelDivision.realizacion(division))
	t.division_actual = division
	t.fans = Fans.inicial(division)
	t.reputacion = Economia.reputacion_inicial(t.media_equipo())
	return t


func _test_escala_exponencial() -> int:
	var fallas := 0
	# Entre primera y decima tiene que haber ORDENES de magnitud, no una
	# diferencia de grado: es todo el punto del rework.
	var razon: float = Fans.referencia(0) / Fans.referencia(9)
	if razon < 1000.0:
		print("FALLA: primera tiene %.0fx la hinchada de decima y tendrian que ser miles." % razon)
		fallas += 1
	# Y monotona: ninguna division puede tener menos referencia que la de
	# abajo.
	for d in range(1, 10):
		if Fans.referencia(d) >= Fans.referencia(d - 1):
			print("FALLA: la division %d no tiene menos hinchada que la %d." % [d + 1, d])
			fallas += 1
	if fallas == 0:
		print("OK: la hinchada escala %.0fx entre decima y primera, monotona." % razon)
	return fallas


func _test_apoyo() -> int:
	var fallas := 0
	# El apoyo es RELATIVO a la division: el mismo club recien generado
	# tiene que dar lo mismo en primera que en decima, aunque uno tenga
	# millones de hinchas y el otro miles.
	var a1 := Fans.apoyo(_equipo(0), 0)
	var a10 := Fans.apoyo(_equipo(9), 9)
	if absf(a1 - a10) > 0.01:
		print("FALLA: mismo club relativo da apoyo %.2f en primera y %.2f en decima." % [a1, a10])
		fallas += 1
	# Y tiene que arrancar con lugar para crecer Y para caerse: si diera 0
	# de entrada, el estadio arrancaria vacio y ningun sponsor miraria.
	if a1 <= 0.05 or a1 >= 0.5:
		print("FALLA: un club recien generado arranca con apoyo %.2f; se esperaba entre 0.05 y 0.5." % a1)
		fallas += 1
	# Monotona en la cantidad.
	var e := _equipo(4)
	var antes := Fans.apoyo(e, 4)
	e.fans *= 3.0
	if Fans.apoyo(e, 4) <= antes:
		print("FALLA: triplicar la hinchada no sube el apoyo.")
		fallas += 1
	if fallas == 0:
		print("OK: el apoyo es relativo a la division (%.2f) y crece con la hinchada." % a1)
	return fallas


func _test_temporada() -> int:
	var fallas := 0
	# Salir campeon varias temporadas seguidas tiene que MULTIPLICAR la
	# hinchada, no sumarle una constante.
	var campeon := _equipo(5)
	var inicial := campeon.fans
	for t in range(5):
		Fans.actualizar_por_temporada(campeon, 1, 20, 5)
	if campeon.fans <= inicial * 1.3:
		print("FALLA: cinco titulos llevan la hinchada de %s a %s." % [
			Fans.texto(inicial), Fans.texto(campeon.fans)])
		fallas += 1
	# Y salir ultimo la tiene que achicar.
	var ultimo := _equipo(5)
	var antes := ultimo.fans
	for t in range(5):
		Fans.actualizar_por_temporada(ultimo, 20, 20, 5)
	if ultimo.fans >= antes:
		print("FALLA: cinco temporadas ultimo no achican la hinchada (%s -> %s)." % [
			Fans.texto(antes), Fans.texto(ultimo.fans)])
		fallas += 1
	# Ascender cambia de categoria de hinchada.
	var sube := _equipo(5)
	var previo := sube.fans
	Fans.actualizar_por_movimiento_de_division(sube, true)
	if sube.fans <= previo:
		print("FALLA: ascender no suma hinchas.")
		fallas += 1
	if fallas == 0:
		print("OK: campeon %s -> %s, ultimo %s -> %s en cinco temporadas." % [
			Fans.texto(inicial), Fans.texto(campeon.fans),
			Fans.texto(antes), Fans.texto(ultimo.fans)])
	return fallas


func _test_migracion() -> int:
	var fallas := 0
	# Una partida vieja guardaba fans como 0..100. Leido crudo, un club de
	# primera quedaria con 45 hinchas. La migracion la hace la piramide al
	# cargar, que es donde se sabe en que division juega cada club.
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var p := Piramide.generar(rng)
	var datos := p.guardar()
	# Se ensucia el guardado como lo tendria una partida de la v1: todos
	# los clubes con un puntaje de dos digitos.
	for ld in datos["divisiones"]:
		for ed in ld["equipos"]:
			ed["fans"] = 45.0
	var cargada := Piramide.cargar(datos)
	var primera: Team = cargada.divisiones[0].equipos[0]
	var decima: Team = cargada.divisiones[9].equipos[0]
	if primera.fans < 1000.0:
		print("FALLA: una partida vieja con fans=45 carga con %s hinchas en primera." % Fans.texto(primera.fans))
		fallas += 1
	# El valor migrado tiene que caer cerca del apoyo que representaba, y
	# tiene que dar LO MISMO en las dos puntas: era un puntaje relativo.
	var apoyo := Fans.apoyo(primera, 0)
	if absf(apoyo - 0.45) > 0.05:
		print("FALLA: fans=45 migra a apoyo %.2f y tendria que dar ~0.45." % apoyo)
		fallas += 1
	if absf(apoyo - Fans.apoyo(decima, 9)) > 0.01:
		print("FALLA: el mismo puntaje viejo migra distinto en primera y en decima.")
		fallas += 1
	# Y una partida NUEVA no se tiene que tocar: sus numeros ya son
	# grandes y estan arriba del tope de la escala vieja.
	var intacta := Piramide.cargar(p.guardar())
	var antes: float = p.divisiones[0].equipos[0].fans
	if absf(intacta.divisiones[0].equipos[0].fans - antes) > 1.0:
		print("FALLA: una partida nueva se migra igual (%s -> %s)." % [
			Fans.texto(antes), Fans.texto(intacta.divisiones[0].equipos[0].fans)])
		fallas += 1
	if fallas == 0:
		print("OK: fans=45 migra a %s en primera y %s en decima (apoyo %.2f en las dos)." % [
			Fans.texto(primera.fans), Fans.texto(decima.fans), apoyo])
	return fallas


func _test_reputacion_fuentes() -> int:
	var fallas := 0
	# La tabla: primero suma, ultimo resta.
	if Reputacion.por_posicion(1, 20) <= 0.0:
		print("FALLA: salir campeon no suma reputacion.")
		fallas += 1
	if Reputacion.por_posicion(20, 20) >= 0.0:
		print("FALLA: salir ultimo no resta reputacion.")
		fallas += 1
	# Los titulos valen, y valen distinto: una internacional no puede
	# valer lo mismo que la copa de tu division.
	var orden := ["Copa de división", "Liga", "Copa del Rey", "Copa de Campeones"]
	for i in range(1, orden.size()):
		if Reputacion.por_titulo(orden[i]) <= Reputacion.por_titulo(orden[i - 1]):
			print("FALLA: %s no vale mas que %s." % [orden[i], orden[i - 1]])
			fallas += 1
	# Y ganar la copa del Rey tiene que pesar mas que una temporada
	# entera de tabla: es lo que antes no valia nada.
	if Reputacion.por_titulo("Copa del Rey") <= Reputacion.por_posicion(1, 20):
		print("FALLA: la Copa del Rey vale menos que salir primero en la tabla.")
		fallas += 1
	# Descender tiene que doler mas que ascender.
	if absf(Reputacion.POR_DESCENSO) <= Reputacion.POR_ASCENSO:
		print("FALLA: descender (%.1f) no duele mas que ascender (%.1f)." % [
			Reputacion.POR_DESCENSO, Reputacion.POR_ASCENSO])
		fallas += 1
	# La referencia por division tiene que ordenar las diez.
	for d in range(1, 10):
		if Reputacion.referencia(d) >= Reputacion.referencia(d - 1):
			print("FALLA: la reputacion de referencia de la division %d no baja." % (d + 1))
			fallas += 1
	# Y no se puede pasar de rango por mucho que ganes.
	var e := _equipo(0)
	for i in range(200):
		Reputacion.sumar(e, Reputacion.POR_INTERNACIONAL)
	if e.reputacion > Reputacion.MAXIMO:
		print("FALLA: la reputacion se paso de %.0f." % Reputacion.MAXIMO)
		fallas += 1
	if fallas == 0:
		print("OK: tabla ±%.1f, liga %.1f, Rey %.1f, internacional %.1f; referencia D1 %.0f / D10 %.0f." % [
			Reputacion.POR_TABLA, Reputacion.POR_LIGA, Reputacion.POR_COPA_DEL_REY,
			Reputacion.POR_INTERNACIONAL, Reputacion.referencia(0), Reputacion.referencia(9)])
	return fallas


func _test_minimos_de_sponsor() -> int:
	var fallas := 0
	var e := _equipo(5)
	# Un club recien generado tiene que poder conseguir sponsors chicos y
	# NO los grandes: si no, conseguir sponsors sigue siendo gratis.
	if not Sponsors.tiene_el_nombre(e, "ninguno", 5):
		print("FALLA: un club normal no llega ni al sponsor sin requisitos.")
		fallas += 1
	if Sponsors.tiene_el_nombre(e, "campeon", 5):
		print("FALLA: un club recien generado ya califica para el sponsor mas grande.")
		fallas += 1
	# Y con reputacion e hinchada de grande, si.
	var grande := _equipo(5)
	grande.reputacion = Reputacion.MAXIMO
	grande.fans = Fans.fans_para_apoyo(1.0, 5)
	if not Sponsors.tiene_el_nombre(grande, "campeon", 5):
		print("FALLA: un club enorme no califica para el sponsor mas grande.")
		fallas += 1
	# El minimo tiene que escalar con la division: el sponsor de decima
	# que pide prestigio pide prestigio DE DECIMA.
	if Sponsors.reputacion_minima("top3", 0) <= Sponsors.reputacion_minima("top3", 9):
		print("FALLA: el minimo de reputacion no escala con la division.")
		fallas += 1
	# Las ofertas que llegan tienen que respetarlo.
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for i in range(60):
		var o := Sponsors.generar_oferta(e, 5, rng)
		if o.is_empty():
			continue
		if not Sponsors.tiene_el_nombre(e, str(o["requisito"]), 5):
			print("FALLA: llego una oferta (%s) que el club no califica." % o["nombre"])
			fallas += 1
			break
		e.sponsors_ofertas.clear()
	# Y al cerrar la temporada se cae el que ya no puede sostener, aunque
	# haya cumplido en la cancha.
	var caido := _equipo(5)
	caido.sponsors = [{
		"nombre": "Grande SA", "requisito": "campeon", "pago": 100.0,
		"division": 6, "desde": 1, "cobrado": 0.0, "partidos": 10,
	}]
	var caidos := Sponsors.evaluar_temporada(caido, 1, 20, 5)
	if caidos.size() != 1:
		print("FALLA: el sponsor grande se queda con un club que no da la talla.")
		fallas += 1
	if fallas == 0:
		print("OK: minimos por division (top3 pide %.0f en D1 y %.0f en D10) y se aplican en las dos puntas." % [
			Sponsors.reputacion_minima("top3", 0), Sponsors.reputacion_minima("top3", 9)])
	return fallas
