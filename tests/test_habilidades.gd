extends SceneTree

## Habilidades por puesto, múltiples por jugador y efectos acumulables.

const SEED := 7373


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_test_formato_generado(rng)
	_test_pools_por_puesto(rng)
	_test_se_generan_varias(rng)
	_test_bonus_acumulados()
	_test_bufon()
	_test_atajapenales()
	_test_migracion_y_limpieza(rng)
	quit()


func _test_formato_generado(rng: RandomNumberGenerator) -> void:
	var jugador := PlayerGenerator.generate(0, rng, "MC")
	if jugador.has("habilidades") and jugador["habilidades"] is Array:
		print("OK: jugador usa lista de habilidades: %s" % [jugador["habilidades"]])
	else:
		print("FALLA: formato de habilidades=%s" % [jugador.get("habilidades", "NO EXISTE")])


func _test_pools_por_puesto(rng: RandomNumberGenerator) -> void:
	var defensa := Habilidades.nombres_para_posicion("DFC")
	var delantero := Habilidades.nombres_para_posicion("DC")
	var arquero := Habilidades.nombres_para_posicion("ARQ")
	var ok := "Ladrón" in defensa and "Recuperación" in defensa
	ok = ok and not ("Ladrón" in delantero) and not ("Recuperación" in delantero)
	ok = ok and "Atajapenales" in arquero and not ("Cañón" in arquero)
	if ok:
		print("OK: DFC defensivo, DC ofensivo, ARQ específico")
	else:
		print("FALLA: pools por puesto: DFC=%s DC=%s ARQ=%s" % [defensa, delantero, arquero])


func _test_se_generan_varias(rng: RandomNumberGenerator) -> void:
	var encontro_varias := false
	for i in range(2000):
		var habilidades: Array = Habilidades.generar("MC", rng)
		if habilidades.size() > 1:
			encontro_varias = true
		var nombres := {}
		for habilidad in habilidades:
			if nombres.has(habilidad["nombre"]):
				print("FALLA: nombre repetido %s" % habilidad["nombre"])
				return
			nombres[habilidad["nombre"]] = true
	if encontro_varias:
		print("OK: se generan varias habilidades sin repetir")
	else:
		print("FALLA: no se generaron combinaciones")


func _test_bonus_acumulados() -> void:
	var jugador := {"posicion": "DFC", "media": 85.0, "habilidades": [
		{"nombre": "Ladrón", "nivel": 2},
		{"nombre": "Recuperación", "nivel": 3},
	]}
	var bonus := Habilidades.modificador_partido(jugador, "quite")
	var ok := is_equal_approx(bonus, 10.0)
	ok = ok and is_equal_approx(Habilidades.factor_cooldown_recuperacion(jugador), 0.35)
	if ok:
		print("OK: Ladrón plata + Recuperación oro acumulan efectos")
	else:
		print("FALLA: bonus=%.2f cooldown=%.2f" % [bonus, Habilidades.factor_cooldown_recuperacion(jugador)])


func _test_atajapenales() -> void:
	var arquero := {"media": 85.0, "habilidades": [{"nombre": "Atajapenales", "nivel": 3}]}
	if is_equal_approx(Habilidades.bonus_atajapenales(arquero), 0.13):
		print("OK: Atajapenales oro resta 13%")
	else:
		print("FALLA: Atajapenales no aplica")


func _test_bufon() -> void:
	var jugador := {"media": 85.0, "habilidades": [{"nombre": "Bufon", "nivel": 3}]}
	if is_equal_approx(Habilidades.factor_cooldown_regate(jugador), 0.55):
		print("OK: Bufon oro reduce cooldown de regates")
	else:
		print("FALLA: Bufon no reduce cooldown")


func _test_migracion_y_limpieza(rng: RandomNumberGenerator) -> void:
	var jugador := PlayerGenerator.generate(0, rng, "DFC")
	var techos := {}
	for attr in jugador["atributos"]:
		techos[attr] = 60
	jugador["potenciales"] = techos
	jugador["habilidad"] = {"nombre": "Ladrón", "nivel": 2}
	Habilidades.corregir_habilidad_por_techo(jugador)
	var migro: bool = jugador["habilidades"].size() == 1
	var bajo_migrado: bool = jugador["habilidades"][0]["nivel"] == 1

	jugador["posicion"] = "DC"
	jugador["habilidades"] = [{"nombre": "Ladrón", "nivel": 2}]
	Habilidades.corregir_habilidad_por_techo(jugador)
	var elimino_incompatible: bool = jugador["habilidades"].is_empty()
	jugador["habilidades"] = [{"nombre": "Cañón", "nivel": 2}]
	Habilidades.corregir_habilidad_por_techo(jugador)
	var bajo_a_bronce: bool = jugador["habilidades"].size() == 1 \
		and jugador["habilidades"][0]["nivel"] == 1
	if migro and bajo_migrado and elimino_incompatible and bajo_a_bronce:
		print("OK: guardado viejo migra y habilidad defensiva no entra en DC")
	else:
		print("FALLA: limpieza/migración=%s" % jugador)
