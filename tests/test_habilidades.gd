extends SceneTree

## Habilidades (§5) — generación, manifestación por media, bonus en el
## bloque D del duelo (igual que Personalidad), y Atajapenales en penales.
## Correr con: godot --headless --script tests/test_habilidades.gd

const SEED := 7373


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	_test_todo_jugador_generado_tiene_el_campo(rng)
	_test_probabilidad_de_generacion_razonable(rng)
	_test_arquero_solo_saca_habilidades_de_arquero(rng)
	_test_no_manifestada_no_da_bonus(rng)
	_test_manifestada_da_bonus_solo_en_su_atributo(rng)
	_test_atajapenales_baja_la_chance_de_gol(rng)
	_test_maximo_una_habilidad_por_jugador(rng)

	quit()


func _test_todo_jugador_generado_tiene_el_campo(rng: RandomNumberGenerator) -> void:
	print("=== Todo jugador generado tiene el campo 'habilidad' (aunque sea {}) ===")
	var jugador := PlayerGenerator.generate(0, rng, "MC")
	if jugador.has("habilidad") and jugador["habilidad"] is Dictionary:
		print("OK: habilidad=%s" % [jugador["habilidad"]])
	else:
		print("FALLA: %s" % [jugador.get("habilidad", "NO EXISTE")])


func _test_probabilidad_de_generacion_razonable(rng: RandomNumberGenerator) -> void:
	print("\n=== La probabilidad de generacion (~15% con algo) se cumple en un volumen grande ===")
	var con_habilidad := 0
	var con_oro := 0
	var total := 3000
	for i in range(total):
		var h := Habilidades.generar("MC", rng)
		if not h.is_empty():
			con_habilidad += 1
			if h["nivel"] == 3:
				con_oro += 1

	var proporcion: float = float(con_habilidad) / float(total)
	# 15% esperado, con margen generoso para no ser flaky.
	if proporcion > 0.10 and proporcion < 0.20:
		print("OK: %d/%d (%.1f%%) con alguna habilidad, %d en oro (esperado ~15%%)." % [con_habilidad, total, proporcion * 100.0, con_oro])
	else:
		print("FALLA: proporcion=%.1f%%" % (proporcion * 100.0))


func _test_arquero_solo_saca_habilidades_de_arquero(rng: RandomNumberGenerator) -> void:
	print("\n=== Un ARQ solo puede sacar habilidades del pool de arquero ===")
	var nombres_arquero := {}
	for atributo in Habilidades._datos()["arquero"]:
		for n in Habilidades._datos()["arquero"][atributo]:
			nombres_arquero[n] = true

	var ok := true
	for i in range(500):
		var h := Habilidades.generar("ARQ", rng)
		if not h.is_empty() and not nombres_arquero.has(h["nombre"]):
			ok = false
			print("FALLA: ARQ saco '%s', que no es de arquero." % h["nombre"])
			break

	if ok:
		print("OK: en 500 tiradas, un ARQ nunca saco una habilidad de campo.")


func _test_no_manifestada_no_da_bonus(rng: RandomNumberGenerator) -> void:
	print("\n=== Una habilidad bajo la media minima no da bonus (esta 'dormida') ===")
	var jugador := PlayerGenerator.generate(0, rng, "DC")
	jugador["habilidad"] = {"nombre": "Cañón", "nivel": 1}
	jugador["media"] = 40.0  # bien debajo de 55 (minimo de bronce)

	var bonus := Habilidades.modificador_partido(jugador, "tiro")
	if is_equal_approx(bonus, 0.0) and not Habilidades.tiene_manifestada(jugador, "Cañón"):
		print("OK: con media 40, Cañón bronce no da bonus todavia.")
	else:
		print("FALLA: bonus=%.2f" % bonus)


func _test_manifestada_da_bonus_solo_en_su_atributo(rng: RandomNumberGenerator) -> void:
	print("\n=== Una habilidad manifestada da bonus SOLO en su atributo asociado ===")
	var jugador := PlayerGenerator.generate(0, rng, "DC")
	jugador["habilidad"] = {"nombre": "Cañón", "nivel": 2}
	jugador["media"] = 75.0  # por encima de 70 (minimo de plata)

	var bonus_tiro := Habilidades.modificador_partido(jugador, "tiro")
	var bonus_pases := Habilidades.modificador_partido(jugador, "pases")

	var ok: bool = is_equal_approx(bonus_tiro, Habilidades.BONUS_DUELO[2])
	ok = ok and is_equal_approx(bonus_pases, 0.0)
	ok = ok and Habilidades.tiene_manifestada(jugador, "Cañón")

	if ok:
		print("OK: Cañón plata da +%.1f en tiro y 0 en pases." % Habilidades.BONUS_DUELO[2])
	else:
		print("FALLA: bonus_tiro=%.2f bonus_pases=%.2f" % [bonus_tiro, bonus_pases])


func _test_atajapenales_baja_la_chance_de_gol(rng: RandomNumberGenerator) -> void:
	print("\n=== Atajapenales manifestada le baja la chance de convertir al pateador ===")
	var pateador := PlayerGenerator.generate(0, rng, "DC")
	pateador["atributos"]["tiro"] = 70

	var arquero_normal := PlayerGenerator.generate(1, rng, "ARQ")
	arquero_normal["atributos"]["reflejos"] = 70
	arquero_normal["atributos"]["estirada"] = 70
	arquero_normal["habilidad"] = {}

	var arquero_atajapenales := arquero_normal.duplicate(true)
	arquero_atajapenales["habilidad"] = {"nombre": "Atajapenales", "nivel": 3}
	arquero_atajapenales["media"] = 85.0  # por encima de 80 (minimo de oro)

	var muestras_normal := 0
	var muestras_atajapenales := 0
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 111
	var rng3 := RandomNumberGenerator.new()
	rng3.seed = 111
	for i in range(2000):
		if Penales.patear(pateador, arquero_normal, rng2):
			muestras_normal += 1
		if Penales.patear(pateador, arquero_atajapenales, rng3):
			muestras_atajapenales += 1

	if muestras_atajapenales < muestras_normal:
		print("OK: goles convertidos contra arquero normal=%d, contra Atajapenales oro=%d (menos)." % [muestras_normal, muestras_atajapenales])
	else:
		print("FALLA: normal=%d atajapenales=%d" % [muestras_normal, muestras_atajapenales])


func _test_maximo_una_habilidad_por_jugador(rng: RandomNumberGenerator) -> void:
	print("\n=== generar() nunca da mas de un nombre/nivel (no es una lista) ===")
	var h := Habilidades.generar("DC", rng)
	if h.is_empty() or (h.has("nombre") and h.has("nivel") and h.keys().size() == 2):
		print("OK: {} o {nombre, nivel} exactamente, nunca una lista de varias.")
	else:
		print("FALLA: %s" % [h])
