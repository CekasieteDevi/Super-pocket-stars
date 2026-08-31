extends SceneTree

## §7.4.5: familiaridad tactica. Lo que se prueba es que cambiar de plan
## CUESTE y que quedarse rinda, que es el punto de la mecanica.

const SEED := 90455


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	_test_curva()
	_test_arranca_sabida_y_una_nueva_arranca_en_cero(rng)
	_test_se_asimila_jugando_y_se_oxida_la_que_no_usas(rng)
	_test_el_foco_tactico_acelera(rng)
	_test_dominar_lleva_casi_una_temporada(rng)
	_test_pesa_en_el_partido(rng)
	_test_sobrevive_un_guardado(rng)

	quit()


func _test_curva() -> void:
	print("\n=== La curva va de -8 a +5 y cruza cero en NEUTRO ===")
	var en_cero := Familiaridad.modificador_de_nivel(0.0)
	var en_neutro := Familiaridad.modificador_de_nivel(Familiaridad.NEUTRO)
	var en_tope := Familiaridad.modificador_de_nivel(100.0)
	if not is_equal_approx(en_cero, Familiaridad.MODIFICADOR_MIN):
		print("FALLA: en 0 deberia dar %.1f y dio %.2f" % [Familiaridad.MODIFICADOR_MIN, en_cero])
		return
	if absf(en_neutro) > 0.001:
		print("FALLA: en NEUTRO deberia dar 0 y dio %.2f" % en_neutro)
		return
	if not is_equal_approx(en_tope, Familiaridad.MODIFICADOR_MAX):
		print("FALLA: en 100 deberia dar %.1f y dio %.2f" % [Familiaridad.MODIFICADOR_MAX, en_tope])
		return
	# Monotona: mas familiaridad nunca puede rendir menos.
	var previo := -99.0
	for n in range(0, 101, 5):
		var m := Familiaridad.modificador_de_nivel(float(n))
		if m < previo - 0.0001:
			print("FALLA: no es monotona, en %d bajo a %.2f" % [n, m])
			return
		previo = m
	print("OK: 0 -> %.1f, %d -> %.1f, 100 -> %+.1f, y siempre creciente." % [
		en_cero, int(Familiaridad.NEUTRO), en_neutro, en_tope])


func _test_arranca_sabida_y_una_nueva_arranca_en_cero(rng: RandomNumberGenerator) -> void:
	print("\n=== El club conoce su tactica de siempre; una nueva arranca en frio ===")
	var e := Team.generar("Familiar", rng, 0)
	var nivel_propia := Familiaridad.nivel(e)
	if not is_equal_approx(nivel_propia, Familiaridad.INICIAL):
		print("FALLA: su propia tactica arranco en %.1f y deberia ser %.1f" % [
			nivel_propia, Familiaridad.INICIAL])
		return
	if Familiaridad.modificador(e) <= 0.0:
		print("FALLA: su tactica de siempre no deberia restar (%.2f)." % Familiaridad.modificador(e))
		return

	# Cambiar SOLO la formacion comparte el estilo, asi que arrastra parte
	# de lo que el equipo ya sabe.
	var estilo_original: String = e.estilo
	var otra := ""
	for f in Formaciones.lista():
		if f != e.formacion:
			otra = f
			break
	e.formacion = otra
	var esperado_parcial: float = Familiaridad.INICIAL * Familiaridad.TRASPASO_MITAD
	if not is_equal_approx(Familiaridad.nivel(e), esperado_parcial):
		print("FALLA: cambiar media tactica dio %.1f, deberia arrastrar %.1f." % [
			Familiaridad.nivel(e), esperado_parcial])
		return
	var parcial := Familiaridad.modificador(e)

	# Cambiar LAS DOS mitades es un plan completamente nuevo: no arrastra nada.
	for est in Estilos.LISTA:
		if est != estilo_original:
			e.estilo = est
			break
	if not is_equal_approx(Familiaridad.nivel(e), 0.0):
		print("FALLA: la tactica nueva entera arranco en %.1f, deberia ser 0." % Familiaridad.nivel(e))
		return
	var entero := Familiaridad.modificador(e)
	if entero >= parcial:
		print("FALLA: cambiar todo (%.2f) deberia costar mas que cambiar media (%.2f)." % [
			entero, parcial])
		return
	print("OK: la de siempre +%.0f; cambiar media cuesta %+.1f y cambiar todo %+.1f (le faltan %d fechas)." % [
		Familiaridad.INICIAL, parcial, entero, Familiaridad.fechas_para_neutro(e)])


func _test_se_asimila_jugando_y_se_oxida_la_que_no_usas(rng: RandomNumberGenerator) -> void:
	print("\n=== Se asimila jugandola, y la que dejas se oxida ===")
	var e := Team.generar("Asimila", rng, 0)
	var vieja := Familiaridad.clave_actual(e)
	for f in Formaciones.lista():
		if f != e.formacion:
			e.formacion = f
			break
	for est in Estilos.LISTA:
		if est != e.estilo:
			e.estilo = est
			break
	var nueva := Familiaridad.clave_actual(e)

	for _i in range(10):
		Familiaridad.despues_de_partido(e)

	var n_nueva: float = float(e.familiaridad[nueva])
	var n_vieja: float = float(e.familiaridad[vieja])
	if n_nueva < Familiaridad.NEUTRO:
		print("FALLA: tras 10 fechas la nueva quedo en %.1f, no llego a neutro." % n_nueva)
		return
	if n_vieja >= Familiaridad.INICIAL:
		print("FALLA: la vieja no se oxido (%.1f)." % n_vieja)
		return
	# Oxidarse tiene que ser MUCHO mas lento que aprender: si no, volver a
	# un plan viejo cuesta lo mismo que estrenar y nadie experimenta.
	var aprendido: float = n_nueva
	var olvidado: float = Familiaridad.INICIAL - n_vieja
	if olvidado >= aprendido:
		print("FALLA: olvido %.1f y aprendio %.1f; volver deberia ser mas barato." % [
			olvidado, aprendido])
		return
	print("OK: en 10 fechas la nueva subio a %.1f y la vieja bajo solo %.1f." % [n_nueva, olvidado])


func _test_el_foco_tactico_acelera(rng: RandomNumberGenerator) -> void:
	print("\n=== El foco de equipo tactico acelera la asimilacion ===")
	var sin_foco := Team.generar("SinFoco", rng, 0)
	var con_foco := Team.generar("ConFoco", rng, 100)
	sin_foco.foco_equipo = "general"
	con_foco.foco_equipo = "tactico"
	# Los dos estrenan una tactica.
	sin_foco.familiaridad = {}
	con_foco.familiaridad = {}
	for _i in range(5):
		Familiaridad.despues_de_partido(sin_foco)
		Familiaridad.despues_de_partido(con_foco)
	var a := Familiaridad.nivel(sin_foco)
	var b := Familiaridad.nivel(con_foco)
	if b <= a:
		print("FALLA: con foco tactico %.1f, sin foco %.1f." % [b, a])
		return
	print("OK: 5 fechas con foco tactico dan %.1f contra %.1f sin el." % [b, a])


## Con ganancia plana, cualquier equipo saltaba de 70 a 100 en cuatro
## fechas y el "+5 por tactica dominada" era el estado normal del mundo.
func _test_dominar_lleva_casi_una_temporada(rng: RandomNumberGenerator) -> void:
	print("
=== Dominar una tactica cuesta, no se regala ===")
	var e := Team.generar("Domina", rng, 0)
	var fechas := 0
	while Familiaridad.nivel(e) < Familiaridad.MAXIMO and fechas < 200:
		Familiaridad.despues_de_partido(e)
		fechas += 1
	if fechas < 12:
		print("FALLA: llego al tope en %d fechas, demasiado rapido." % fechas)
		return
	if fechas > 38:
		print("FALLA: llego al tope en %d fechas, mas que una temporada entera." % fechas)
		return
	print("OK: desde %.0f, dominarla lleva %d fechas de las 38 de la temporada." % [
		Familiaridad.INICIAL, fechas])


func _test_pesa_en_el_partido(rng: RandomNumberGenerator) -> void:
	print("\n=== Estrenar una tactica se paga en la cancha ===")
	var muestras := 60
	var puntos_conocida := 0
	var puntos_estrenando := 0

	for i in range(muestras):
		var r1 := RandomNumberGenerator.new()
		r1.seed = 4200 + i
		var casa := Team.generar("Casa", r1, 0)
		var visita := Team.generar("Visita", r1, 100)
		var res := MatchEngine.simular(casa, visita, r1, false)
		puntos_conocida += _puntos(res["goles_local"], res["goles_visitante"])

		var r2 := RandomNumberGenerator.new()
		r2.seed = 4200 + i
		var casa2 := Team.generar("Casa", r2, 0)
		var visita2 := Team.generar("Visita", r2, 100)
		# Mismo plantel, mismo rival, misma semilla: lo unico distinto es
		# que el local estrena su tactica.
		casa2.familiaridad = {}
		var res2 := MatchEngine.simular(casa2, visita2, r2, false)
		puntos_estrenando += _puntos(res2["goles_local"], res2["goles_visitante"])

	if puntos_estrenando >= puntos_conocida:
		print("FALLA: estrenando %d puntos, con la tactica sabida %d." % [
			puntos_estrenando, puntos_conocida])
		return
	print("OK: en %d partidos, con la tactica sabida %d puntos y estrenandola %d." % [
		muestras, puntos_conocida, puntos_estrenando])


func _puntos(gf: int, gc: int) -> int:
	if gf > gc:
		return 3
	return 1 if gf == gc else 0


func _test_sobrevive_un_guardado(rng: RandomNumberGenerator) -> void:
	print("\n=== Sobrevive un guardado, y una partida vieja no queda castigada ===")
	var e := Team.generar("Guardado", rng, 0)
	Familiaridad.despues_de_partido(e)
	var esperado := Familiaridad.nivel(e)
	var vuelto := Team.cargar(e.guardar())
	if not is_equal_approx(Familiaridad.nivel(vuelto), esperado):
		print("FALLA: guardo %.1f y volvio %.1f." % [esperado, Familiaridad.nivel(vuelto)])
		return

	# Una partida guardada ANTES de §7.4.5 no trae el campo.
	var datos := e.guardar()
	datos.erase("familiaridad")
	var viejo := Team.cargar(datos)
	if not is_equal_approx(Familiaridad.nivel(viejo), Familiaridad.INICIAL):
		print("FALLA: una partida vieja quedo en %.1f, deberia migrar a %.1f." % [
			Familiaridad.nivel(viejo), Familiaridad.INICIAL])
		return
	print("OK: guarda y carga bien, y una partida vieja migra a %.1f." % Familiaridad.INICIAL)
