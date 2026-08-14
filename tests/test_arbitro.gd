extends SceneTree

## Árbitro del partido (§8.4 #23) — siempre hay uno de los 3 tipos (a
## diferencia del clima, no hay "árbitro normal" separado), factor de
## tarjetas, y el bonus de "casero" solo para el local.
## Correr con: godot --headless --script tests/test_arbitro.gd

const SEED := 4747


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	_test_siempre_hay_un_arbitro_valido(rng)
	_test_factor_tarjetas(rng)
	_test_casero_solo_favorece_al_local(rng)
	_test_estricto_y_permisivo_no_dan_bonus_de_bloque_c(rng)

	quit()


func _test_siempre_hay_un_arbitro_valido(rng: RandomNumberGenerator) -> void:
	print("=== generar() siempre devuelve uno de los 3 tipos, nunca vacio ===")
	var ok := true
	for i in range(500):
		var arbitro := Arbitro.generar(rng)
		if not Arbitro.TIPOS.has(arbitro):
			ok = false
			print("FALLA: '%s'" % arbitro)
			break
	if ok:
		print("OK: 500 tiradas, siempre Estricto/Permisivo/Casero.")


func _test_factor_tarjetas(rng: RandomNumberGenerator) -> void:
	print("\n=== Estricto multiplica tarjetas para arriba, Permisivo para abajo ===")
	var ok := true
	ok = ok and Arbitro.factor_tarjetas("Estricto") > 1.0
	ok = ok and Arbitro.factor_tarjetas("Permisivo") < 1.0
	ok = ok and is_equal_approx(Arbitro.factor_tarjetas("Casero"), 1.0)
	if ok:
		print("OK: Estricto=%.1fx Permisivo=%.1fx Casero=1.0x." % [Arbitro.factor_tarjetas("Estricto"), Arbitro.factor_tarjetas("Permisivo")])
	else:
		print("FALLA")


func _test_casero_solo_favorece_al_local(rng: RandomNumberGenerator) -> void:
	print("\n=== 'Casero' da bonus de bloque C solo si es_local=true ===")
	var ok := true
	ok = ok and is_equal_approx(Arbitro.modificador("Casero", true), Arbitro.BONUS_CASERO)
	ok = ok and is_equal_approx(Arbitro.modificador("Casero", false), 0.0)
	if ok:
		print("OK: +%.1f de local, 0 de visitante." % Arbitro.BONUS_CASERO)
	else:
		print("FALLA")


func _test_estricto_y_permisivo_no_dan_bonus_de_bloque_c(rng: RandomNumberGenerator) -> void:
	print("\n=== Estricto/Permisivo no tocan el bloque C, solo tarjetas ===")
	var ok := true
	ok = ok and is_equal_approx(Arbitro.modificador("Estricto", true), 0.0)
	ok = ok and is_equal_approx(Arbitro.modificador("Estricto", false), 0.0)
	ok = ok and is_equal_approx(Arbitro.modificador("Permisivo", true), 0.0)
	if ok:
		print("OK: 0.0 en los tres casos.")
	else:
		print("FALLA")
