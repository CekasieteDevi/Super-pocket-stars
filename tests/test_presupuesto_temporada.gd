extends SceneTree

## El presupuesto se reinicia cada temporada (modo carrera) y el mercado
## no tiene direccion: cualquier club le puede comprar a cualquiera.

const SEED := 3131


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_test_el_sobrante_se_pierde(rng)
	_test_la_deuda_se_arrastra(rng)
	_test_el_sueldo_no_lleva_el_escalon_de_elite(rng)
	_test_se_le_puede_comprar_a_cualquier_division(rng)
	quit()


func _test_el_sobrante_se_pierde(rng: RandomNumberGenerator) -> void:
	print("=== Lo que no gastaste no se acumula ===")
	# Antes se sumaba temporada a temporada y a las ocho un club de primera
	# tenia $157M dormidos: con suficientes años cualquiera compraba
	# cualquier cosa.
	var liga := Liga.new()
	liga.inicializar(["A", "B"], rng, 0, 5)
	var e: Team = liga.equipos[0]
	Economia.procesar_temporada(e, 1, 20, liga.division)
	var primera: float = e.caja["fichajes"]
	Economia.procesar_temporada(e, 1, 20, liga.division)
	var segunda: float = e.caja["fichajes"]
	if absf(segunda - primera) < primera * 0.35:
		print("OK: dos temporadas seguidas dan presupuestos parecidos (%s y %s), no el doble." % [
			Economia.formato_dinero(primera), Economia.formato_dinero(segunda)])
	else:
		print("FALLA: paso de %s a %s." % [
			Economia.formato_dinero(primera), Economia.formato_dinero(segunda)])


func _test_la_deuda_se_arrastra(rng: RandomNumberGenerator) -> void:
	print("\n=== Pero la deuda si se arrastra ===")
	# Si no, la quiebra se limpiaria sola cada temporada y
	# Economia._recalcular_quiebra no volveria a dispararse nunca.
	var liga := Liga.new()
	liga.inicializar(["C", "D"], rng, 0, 5)
	var e: Team = liga.equipos[0]
	Economia.procesar_temporada(e, 1, 20, liga.division)
	var limpio: float = e.caja["fichajes"]
	e.caja["fichajes"] = -500000.0
	Economia.procesar_temporada(e, 1, 20, liga.division)
	var con_deuda: float = e.caja["fichajes"]
	if con_deuda < limpio - 400000.0:
		print("OK: arrancar debiendo $500.000 deja %s en vez de %s." % [
			Economia.formato_dinero(con_deuda), Economia.formato_dinero(limpio)])
	else:
		print("FALLA: la deuda se evaporo (%s contra %s)." % [
			Economia.formato_dinero(con_deuda), Economia.formato_dinero(limpio)])


func _test_el_sueldo_no_lleva_el_escalon_de_elite(rng: RandomNumberGenerator) -> void:
	print("\n=== El pase explota, el sueldo no ===")
	# Con el sueldo atado al valor de pase, un plantel que mejoraba dos
	# puntos multiplicaba su masa salarial y las divisiones 2 a 4 cerraban
	# en rojo (15 de 20 clubes en division 3).
	var crack := {"media": 95.0, "edad": 26}
	var pase := ValorJugador.calcular(crack, 50.0, 3)
	var salario := ValorJugador.base_salarial(crack, 50.0, 3)
	var normal := {"media": 60.0, "edad": 26}
	if pase > salario * 20.0 and is_equal_approx(ValorJugador.base_salarial(normal, 50.0, 3), ValorJugador.calcular(normal, 50.0, 3)):
		print("OK: media 95 vale %s de pase y %s de base salarial; media 60 no cambia." % [
			Economia.formato_dinero(pase), Economia.formato_dinero(salario)])
	else:
		print("FALLA: pase %s, base salarial %s." % [
			Economia.formato_dinero(pase), Economia.formato_dinero(salario)])


func _test_se_le_puede_comprar_a_cualquier_division(rng: RandomNumberGenerator) -> void:
	print("\n=== Se le compra a cualquier division, no solo hacia abajo ===")
	var p := Piramide.generar(rng)
	var hacia_arriba := 0
	var hacia_abajo := 0
	var misma := 0
	var divisiones_compradoras := {}
	for _t in range(6):
		for liga in p.divisiones:
			for e in liga.equipos:
				e.caja["fichajes"] = 2000000.0
		for t in Mercado.ventana_entre_divisiones(p, rng, null):
			divisiones_compradoras[int(t["a_division"])] = true
			if int(t["de_division"]) < int(t["a_division"]):
				hacia_arriba += 1
			elif int(t["de_division"]) > int(t["a_division"]):
				hacia_abajo += 1
			else:
				misma += 1
	if hacia_arriba > 0 and misma > 0 and divisiones_compradoras.size() == p.divisiones.size():
		print("OK: %d compras a una division mejor, %d a una peor, %d en la propia; compraron las %d divisiones." % [
			hacia_arriba, hacia_abajo, misma, divisiones_compradoras.size()])
	else:
		print("FALLA: arriba %d, abajo %d, misma %d, compraron %d divisiones." % [
			hacia_arriba, hacia_abajo, misma, divisiones_compradoras.size()])
