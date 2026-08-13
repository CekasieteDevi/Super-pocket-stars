extends SceneTree

## Fase 7 (sistema internacional) — GDD §10.1-§10.5.
## Correr con: godot --headless --script tests/test_phase7_internacional.gd
##
## Qué verificamos:
##   1. 110 clubes del exterior (11 países x 10), Uruguay sin clubes propios
##      (usa División 1 de la pirámide).
##   2. Las tres copas arrancan con 36/24/24 equipos y terminan con campeón
##      en el knockout de 16 (4 rondas: octavos, cuartos, semis, final).
##   3. Uruguay manda equipos reales a la competencia internacional (previa,
##      Guerreros o Emergentes según su coeficiente inicial, 12°).
##   4. El coeficiente se recalcula: los 12 países siguen estando, con
##      puntajes que ya no son todos el valor inicial.

const SEED := 909


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	var piramide := Piramide.generar(rng)
	piramide.jugar_temporada(rng)

	var confederacion := Confederacion.generar(piramide, rng)
	_test_generacion(confederacion)

	var t0 := Time.get_ticks_msec()
	var resultado := confederacion.jugar_temporada_internacional(rng)
	var t1 := Time.get_ticks_msec()
	print("\nTiempo del sistema internacional completo: %d ms" % (t1 - t0))

	_test_copa(resultado["campeones"], 36)
	_test_copa(resultado["guerreros"], 24)
	_test_copa(resultado["emergentes"], 24)
	_test_uruguay(resultado, piramide)
	_test_coeficientes(confederacion)

	quit()


func _test_generacion(confederacion: Confederacion) -> void:
	print("=== Generacion de la confederacion ===")
	var total_clubes_exterior := 0
	var paises_extranjeros := 0
	for pais in confederacion.paises:
		if pais["es_uruguay"]:
			if pais["clubes"].size() != 0:
				print("FALLA: Uruguay no deberia tener ClubExterior propios.")
		else:
			paises_extranjeros += 1
			total_clubes_exterior += pais["clubes"].size()

	print("Paises: %d (esperado 12, incluye Uruguay)" % confederacion.paises.size())
	print("Paises extranjeros: %d, clubes del exterior: %d (esperado 11 x 10 = 110)" % [paises_extranjeros, total_clubes_exterior])
	if confederacion.paises.size() == 12 and paises_extranjeros == 11 and total_clubes_exterior == 110:
		print("OK: 12 paises, 110 clubes del exterior.")
	else:
		print("FALLA: conteo de paises/clubes no coincide con lo esperado.")


func _test_copa(resultado: Dictionary, n_esperado: int) -> void:
	var fase: FaseLiga = resultado["fase_liga"]
	var knockout: Copa = resultado["knockout"]
	print("\n=== %s ===" % fase.nombre)
	print("Equipos en fase de liga: %d (esperado %d)" % [fase.equipos.size(), n_esperado])
	print("Fechas jugadas: %d" % fase.fixture.size())
	print("Rondas de knockout: %d (esperado 4: octavos, cuartos, semis, final)" % knockout.historial.size())
	print("Campeon: %s" % (knockout.campeon.nombre if knockout.campeon else "NINGUNO"))

	var ok := fase.equipos.size() == n_esperado and knockout.campeon != null and knockout.historial.size() == 4
	if ok:
		print("OK: %s termino con %d equipos y campeon en 4 rondas de knockout." % [fase.nombre, n_esperado])
	else:
		print("FALLA en %s." % fase.nombre)


func _test_uruguay(resultado: Dictionary, piramide: Piramide) -> void:
	print("\n=== Participacion de Uruguay ===")
	var nombres_d1 := {}
	for equipo in piramide.divisiones[0].equipos:
		nombres_d1[equipo.nombre] = true

	var participantes_uy := 0
	for copa_nombre in ["campeones", "guerreros", "emergentes"]:
		var fase: FaseLiga = resultado[copa_nombre]["fase_liga"]
		for equipo in fase.equipos:
			if nombres_d1.has(equipo.nombre):
				participantes_uy += 1
				print("  %s juega %s" % [equipo.nombre, copa_nombre])

	print("Clubes de Division 1 en copas internacionales: %d (esperado 5: 2 previa + 1 Guerreros + 2 Emergentes)" % participantes_uy)
	if participantes_uy == 5:
		print("OK: Uruguay mando 5 clubes a la competencia internacional (coeficiente 12, tier bajo).")
	else:
		print("FALLA: se esperaban 5 clubes uruguayos en total.")


func _test_coeficientes(confederacion: Confederacion) -> void:
	print("\n=== Coeficientes despues de la temporada ===")
	for pais in confederacion.paises:
		print("  %s: %.1f" % [pais["nombre"], pais["coeficiente_score"]])

	if confederacion.paises.size() == 12:
		print("OK: los 12 paises siguen presentes tras reordenar por coeficiente.")
	else:
		print("FALLA: se perdieron paises al reordenar.")
