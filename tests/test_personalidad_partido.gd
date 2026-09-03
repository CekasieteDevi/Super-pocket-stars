extends SceneTree

## Rasgos de personalidad conectados al partido (§6/§8.4/§8.7) — bloque D
## atado al minuto/marcador/plantel rival, penales, tarjetas, ánimo
## post-partido, crecimiento (Comodón) y multas (Impuntual).
## Correr con: godot --headless --script tests/test_personalidad_partido.gd

const SEED := 6363


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	_test_lento_de_arranque_castiga_los_primeros_15(rng)
	_test_se_apaga_castiga_los_ultimos_15(rng)
	_test_clutch_favorece_los_ultimos_15(rng)
	_test_fragil_mental_castiga_los_ultimos_10(rng)
	_test_creador_y_nunca_rendirse_son_pasivos_todo_el_partido(rng)
	_test_sin_rasgos_relevantes_no_hay_modificador(rng)
	_test_protagonista_escala_con_la_cantidad_de_mejores_en_el_rival(rng)
	_test_dependiente_solo_castiga_si_el_capitan_no_esta_en_cancha(rng)
	_test_impuntual_malus_parejo_todo_el_partido(rng)
	_test_bonus_penal(rng)
	_test_factor_amarilla_se_van_multiplicando(rng)
	_test_factor_roja(rng)
	_test_ajustar_delta_animo_positivo_bajon_egolatra(rng)
	_test_cruza_umbral_rencoroso(rng)
	_test_tirar_multa_impuntual(rng)
	_test_comodon_congela_el_crecimiento(rng)
	_test_metodico_baja_la_temperatura(rng)
	_test_pie_preferido_castiga_el_lado_malo(rng)
	_test_enfocado_afina_el_desmarque(rng)
	_test_integracion_tarjetas_usa_el_factor_de_personalidad(rng)
	_test_integracion_rachas_persisten_y_se_actualizan_jugando_de_verdad(rng)

	quit()


func _jugador_con(rng: RandomNumberGenerator, positiva: String = "", negativa: String = "") -> Dictionary:
	var j := PlayerGenerator.generate(0, rng, "MC")
	j["personalidades"] = {"positiva": positiva, "negativa": negativa}
	return j


## Par de equipos minimos para probar modificador_partido (que ahora pide
## equipo/rival, no solo un bool "es_local") sin generar planteles enteros
## en cada test.
func _par_equipos(rng: RandomNumberGenerator) -> Dictionary:
	var home := Team.generar("HomeTest", rng, 0)
	var away := Team.generar("AwayTest", rng, 100)
	home.local = true
	away.local = false
	return {"home": home, "away": away}


func _test_lento_de_arranque_castiga_los_primeros_15(rng: RandomNumberGenerator) -> void:
	print("=== Lento de arranque: malus solo en los primeros 15' ===")
	var eq := _par_equipos(rng)
	var j := _jugador_con(rng, "", "Lento de arranque")
	var ok := true
	ok = ok and is_equal_approx(Personalidad.modificador_partido(j, eq["home"], eq["away"], "pases", 10), -Personalidad.MALUS_ARRANQUE)
	ok = ok and is_equal_approx(Personalidad.modificador_partido(j, eq["home"], eq["away"], "pases", 16), 0.0)
	if ok:
		print("OK: -%.1f en minuto 10, 0 en minuto 16." % Personalidad.MALUS_ARRANQUE)
	else:
		print("FALLA")


func _test_se_apaga_castiga_los_ultimos_15(rng: RandomNumberGenerator) -> void:
	print("\n=== Se apaga: malus solo desde el minuto 75 ===")
	var eq := _par_equipos(rng)
	var j := _jugador_con(rng, "", "Se apaga")
	var ok := true
	ok = ok and is_equal_approx(Personalidad.modificador_partido(j, eq["home"], eq["away"], "pases", 70), 0.0)
	ok = ok and is_equal_approx(Personalidad.modificador_partido(j, eq["home"], eq["away"], "pases", 80), -Personalidad.MALUS_SE_APAGA)
	if ok:
		print("OK: 0 en minuto 70, -%.1f en minuto 80." % Personalidad.MALUS_SE_APAGA)
	else:
		print("FALLA")


func _test_clutch_favorece_los_ultimos_15(rng: RandomNumberGenerator) -> void:
	print("\n=== Clutch: bonus solo desde el minuto 75 ===")
	var eq := _par_equipos(rng)
	var j := _jugador_con(rng, "Clutch", "")
	var ok := true
	ok = ok and is_equal_approx(Personalidad.modificador_partido(j, eq["home"], eq["away"], "tiro", 60), 0.0)
	ok = ok and is_equal_approx(Personalidad.modificador_partido(j, eq["home"], eq["away"], "tiro", 85), Personalidad.BONUS_CLUTCH_PARTIDO)
	if ok:
		print("OK: 0 en minuto 60, +%.1f en minuto 85." % Personalidad.BONUS_CLUTCH_PARTIDO)
	else:
		print("FALLA")


func _test_fragil_mental_castiga_los_ultimos_10(rng: RandomNumberGenerator) -> void:
	print("\n=== Fragil mental: malus solo desde el minuto 80 ===")
	var eq := _par_equipos(rng)
	var j := _jugador_con(rng, "", "Fragil mental")
	var ok := true
	ok = ok and is_equal_approx(Personalidad.modificador_partido(j, eq["home"], eq["away"], "tiro", 77), 0.0)
	ok = ok and is_equal_approx(Personalidad.modificador_partido(j, eq["home"], eq["away"], "tiro", 82), -Personalidad.MALUS_FRAGIL_MENTAL_PARTIDO)
	if ok:
		print("OK: 0 en minuto 77, -%.1f en minuto 82." % Personalidad.MALUS_FRAGIL_MENTAL_PARTIDO)
	else:
		print("FALLA")


func _test_creador_y_nunca_rendirse_son_pasivos_todo_el_partido(rng: RandomNumberGenerator) -> void:
	print("\n=== Creador (+pases) y Nunca rendirse (+quite) valen todo el partido, sin importar el minuto ===")
	var eq := _par_equipos(rng)
	var creador := _jugador_con(rng, "Creador", "")
	var nunca_rendirse := _jugador_con(rng, "Nunca rendirse", "")
	var ok := true
	ok = ok and is_equal_approx(Personalidad.modificador_partido(creador, eq["home"], eq["away"], "pases", 1), Personalidad.BONUS_CREADOR)
	ok = ok and is_equal_approx(Personalidad.modificador_partido(creador, eq["home"], eq["away"], "pases", 89), Personalidad.BONUS_CREADOR)
	ok = ok and is_equal_approx(Personalidad.modificador_partido(creador, eq["home"], eq["away"], "tiro", 45), 0.0)  # solo en pases
	ok = ok and is_equal_approx(Personalidad.modificador_partido(nunca_rendirse, eq["home"], eq["away"], "quite", 45), Personalidad.BONUS_NUNCA_RENDIRSE)
	if ok:
		print("OK: Creador +%.1f en pases (cualquier minuto), Nunca rendirse +%.1f en quite." % [Personalidad.BONUS_CREADOR, Personalidad.BONUS_NUNCA_RENDIRSE])
	else:
		print("FALLA")


func _test_sin_rasgos_relevantes_no_hay_modificador(rng: RandomNumberGenerator) -> void:
	print("\n=== Un jugador sin personalidad (o sin rasgos de partido) no suma nada ===")
	var eq := _par_equipos(rng)
	var j := PlayerGenerator.generate(0, rng, "MC")
	j["personalidades"] = {}
	if is_equal_approx(Personalidad.modificador_partido(j, eq["home"], eq["away"], "pases", 44), 0.0):
		print("OK: 0.0")
	else:
		print("FALLA")


func _test_protagonista_escala_con_la_cantidad_de_mejores_en_el_rival(rng: RandomNumberGenerator) -> void:
	print("\n=== Protagonista: escala segun cuantos jugadores del RIVAL tienen mas media que el ===")
	var eq := _par_equipos(rng)
	var home: Team = eq["home"]
	var away: Team = eq["away"]
	var j := _jugador_con(rng, "Protagonista", "")
	j["media"] = 60.0

	for jr in away.todos_los_jugadores():
		jr["media"] = 30.0  # nadie mejor -> sin bonus
	var sin_mejores := Personalidad.modificador_partido(j, home, away, "pases", 10)

	for i in range(2):
		away.todos_los_jugadores()[i]["media"] = 90.0
	var con_2_mejores := Personalidad.modificador_partido(j, home, away, "pases", 10)

	for i in range(6):
		away.todos_los_jugadores()[i]["media"] = 90.0
	var con_6_mejores := Personalidad.modificador_partido(j, home, away, "pases", 10)

	var ok := true
	ok = ok and is_equal_approx(sin_mejores, 0.0)
	ok = ok and is_equal_approx(con_2_mejores, Personalidad.BONUS_PROTAGONISTA_BAJO)
	ok = ok and is_equal_approx(con_6_mejores, Personalidad.BONUS_PROTAGONISTA_ALTO)

	if ok:
		print("OK: 0 sin mejores, +%.1f con 2 mejores, +%.1f con 6 mejores." % [Personalidad.BONUS_PROTAGONISTA_BAJO, Personalidad.BONUS_PROTAGONISTA_ALTO])
	else:
		print("FALLA: sin=%.1f con2=%.1f con6=%.1f" % [sin_mejores, con_2_mejores, con_6_mejores])


func _test_dependiente_solo_castiga_si_el_capitan_no_esta_en_cancha(rng: RandomNumberGenerator) -> void:
	print("\n=== Dependiente: malus solo si el capitan NO esta en cancha ===")
	var eq := _par_equipos(rng)
	var home: Team = eq["home"]
	home.reset_partido()
	var j := _jugador_con(rng, "", "Dependiente")

	var con_capitan := Personalidad.modificador_partido(j, home, eq["away"], "pases", 10)
	home.en_cancha.erase(home.capitan_id)
	var sin_capitan := Personalidad.modificador_partido(j, home, eq["away"], "pases", 10)

	if is_equal_approx(con_capitan, 0.0) and is_equal_approx(sin_capitan, -Personalidad.MALUS_DEPENDIENTE):
		print("OK: 0 con el capitan en cancha, -%.1f sin el." % Personalidad.MALUS_DEPENDIENTE)
	else:
		print("FALLA: con_capitan=%.1f sin_capitan=%.1f" % [con_capitan, sin_capitan])


func _test_impuntual_malus_parejo_todo_el_partido(rng: RandomNumberGenerator) -> void:
	print("\n=== Impuntual: malus chico y parejo, sin importar minuto/atributo ===")
	var eq := _par_equipos(rng)
	var j := _jugador_con(rng, "", "Impuntual")
	var ok := true
	ok = ok and is_equal_approx(Personalidad.modificador_partido(j, eq["home"], eq["away"], "pases", 1), -Personalidad.MALUS_IMPUNTUAL_PARTIDO)
	ok = ok and is_equal_approx(Personalidad.modificador_partido(j, eq["home"], eq["away"], "tiro", 89), -Personalidad.MALUS_IMPUNTUAL_PARTIDO)
	if ok:
		print("OK: -%.1f siempre." % Personalidad.MALUS_IMPUNTUAL_PARTIDO)
	else:
		print("FALLA")


func _test_bonus_penal(rng: RandomNumberGenerator) -> void:
	print("\n=== bonus_penal: Picaro y Clutch suman, Fragil mental resta ===")
	var picaro := _jugador_con(rng, "Picaro", "")
	var clutch := _jugador_con(rng, "Clutch", "")
	var fragil := _jugador_con(rng, "", "Fragil mental")
	var neutro := _jugador_con(rng, "", "")
	var ok := true
	ok = ok and is_equal_approx(Personalidad.bonus_penal(picaro), Personalidad.BONUS_PICARO_PENAL)
	ok = ok and is_equal_approx(Personalidad.bonus_penal(clutch), Personalidad.BONUS_CLUTCH_PENAL)
	ok = ok and is_equal_approx(Personalidad.bonus_penal(fragil), -Personalidad.MALUS_FRAGIL_MENTAL_PENAL)
	ok = ok and is_equal_approx(Personalidad.bonus_penal(neutro), 0.0)
	if ok:
		print("OK: Picaro=+%.2f Clutch=+%.2f Fragil mental=-%.2f neutro=0." % [Personalidad.BONUS_PICARO_PENAL, Personalidad.BONUS_CLUTCH_PENAL, Personalidad.MALUS_FRAGIL_MENTAL_PENAL])
	else:
		print("FALLA")


func _test_factor_amarilla_se_van_multiplicando(rng: RandomNumberGenerator) -> void:
	print("\n=== factor_amarilla: Calenton (negativa) y Canchero (positiva) pueden coexistir y se multiplican ===")
	var j := _jugador_con(rng, "Canchero", "Calenton")
	var esperado: float = Personalidad.FACTOR_CALENTON_AMARILLA * Personalidad.FACTOR_CANCHERO
	if is_equal_approx(Personalidad.factor_amarilla(j), esperado):
		print("OK: factor=%.3f (Calenton x Canchero)." % Personalidad.factor_amarilla(j))
	else:
		print("FALLA: factor=%.3f esperado=%.3f" % [Personalidad.factor_amarilla(j), esperado])


func _test_factor_roja(rng: RandomNumberGenerator) -> void:
	print("\n=== factor_roja: Calenton sube mucho mas la roja que la amarilla ===")
	var j := _jugador_con(rng, "", "Calenton")
	if Personalidad.factor_roja(j) > Personalidad.factor_amarilla(j):
		print("OK: roja=%.2fx > amarilla=%.2fx." % [Personalidad.factor_roja(j), Personalidad.factor_amarilla(j)])
	else:
		print("FALLA")


func _test_ajustar_delta_animo_positivo_bajon_egolatra(rng: RandomNumberGenerator) -> void:
	print("\n=== ajustar_delta_animo: Positivo anula la caida por perder, Bajon la duplica, Egolatra castiga si no es capitan ===")
	var positivo := _jugador_con(rng, "Positivo", "")
	var bajon := _jugador_con(rng, "", "Bajon")
	var egolatra := _jugador_con(rng, "", "Egolatra")
	var neutro := _jugador_con(rng, "", "")

	var ok := true
	ok = ok and is_equal_approx(Personalidad.ajustar_delta_animo(positivo, -3.0, false), 0.0)
	ok = ok and is_equal_approx(Personalidad.ajustar_delta_animo(bajon, -3.0, false), -6.0)
	ok = ok and is_equal_approx(Personalidad.ajustar_delta_animo(egolatra, 3.0, false), 3.0 - Personalidad.MALUS_EGOLATRA)
	ok = ok and is_equal_approx(Personalidad.ajustar_delta_animo(egolatra, 3.0, true), 3.0)  # es capitan, no se le aplica
	ok = ok and is_equal_approx(Personalidad.ajustar_delta_animo(neutro, -3.0, false), -3.0)  # sin cambios
	ok = ok and is_equal_approx(Personalidad.ajustar_delta_animo(positivo, 3.0, false), 3.0)  # ganando, Positivo no toca nada

	if ok:
		print("OK: Positivo anula perder, Bajon duplica, Egolatra castiga solo si no es capitan.")
	else:
		print("FALLA")


func _test_cruza_umbral_rencoroso(rng: RandomNumberGenerator) -> void:
	print("\n=== cruza_umbral_rencoroso: true SOLO justo al llegar al umbral, no antes ni despues ===")
	var j := _jugador_con(rng, "", "Rencoroso")
	var ok := true
	for n in range(0, Personalidad.UMBRAL_RENCOROSO):
		j["partidos_seguidos_banco"] = n
		if Personalidad.cruza_umbral_rencoroso(j):
			ok = false
	j["partidos_seguidos_banco"] = Personalidad.UMBRAL_RENCOROSO
	ok = ok and Personalidad.cruza_umbral_rencoroso(j)
	j["partidos_seguidos_banco"] = Personalidad.UMBRAL_RENCOROSO + 1
	ok = ok and not Personalidad.cruza_umbral_rencoroso(j)  # ya paso, no vuelve a disparar

	if ok:
		print("OK: dispara solo exactamente en el partido %d." % Personalidad.UMBRAL_RENCOROSO)
	else:
		print("FALLA")


func _test_tirar_multa_impuntual(rng: RandomNumberGenerator) -> void:
	print("\n=== tirar_multa_impuntual: solo con el rasgo, y respeta la chance en el agregado ===")
	var no_impuntual := _jugador_con(rng, "", "")
	if Personalidad.tirar_multa_impuntual(no_impuntual, rng):
		print("FALLA: nunca deberia tirar sin el rasgo.")
		return

	var impuntual := _jugador_con(rng, "", "Impuntual")
	var multas := 0
	var intentos := 2000
	for i in range(intentos):
		if Personalidad.tirar_multa_impuntual(impuntual, rng):
			multas += 1
	var proporcion: float = float(multas) / float(intentos)
	if proporcion > Personalidad.CHANCE_MULTA_IMPUNTUAL * 0.5 and proporcion < Personalidad.CHANCE_MULTA_IMPUNTUAL * 1.5:
		print("OK: %.1f%% de multas en %d intentos (esperado ~%.0f%%)." % [proporcion * 100.0, intentos, Personalidad.CHANCE_MULTA_IMPUNTUAL * 100.0])
	else:
		print("FALLA: proporcion=%.1f%%" % (proporcion * 100.0))


func _test_comodon_congela_el_crecimiento(rng: RandomNumberGenerator) -> void:
	print("\n=== Comodon: si es titular fijo 15 partidos, deja de crecer esa temporada ===")
	var joven := PlayerGenerator.generate(0, rng, "MC")
	joven["potencial"] = 90
	joven["edad"] = 20
	for attr in joven["atributos"]:
		joven["atributos"][attr] = 40
	joven["personalidades"] = {"positiva": "", "negativa": "Comodon"}

	var sin_racha: Dictionary = joven.duplicate(true)
	var con_racha: Dictionary = joven.duplicate(true)
	con_racha["partidos_seguidos_titular"] = Personalidad.UMBRAL_COMODON

	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 222
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 222

	Progresion.aplicar_temporada(sin_racha, rng_a)
	Progresion.aplicar_temporada(con_racha, rng_b)

	var crecio_normal: bool = sin_racha["atributos"]["tiro"] > 40
	var congelado: bool = con_racha["atributos"]["tiro"] == 40

	if crecio_normal and congelado:
		print("OK: sin racha crecio a %d, con 15 partidos seguidos de titular se quedo en 40." % sin_racha["atributos"]["tiro"])
	else:
		print("FALLA: sin_racha=%d con_racha=%d" % [sin_racha["atributos"]["tiro"], con_racha["atributos"]["tiro"]])


func _test_integracion_tarjetas_usa_el_factor_de_personalidad(_rng: RandomNumberGenerator) -> void:
	print("
=== Integracion: un defensor Calenton junta mas tarjetas en el motor real que uno Canchero ===")
	# Los dos bloques arrancan con equipos RECIEN generados y con la misma
	# semilla propia, no con el rng compartido del test. Dos motivos:
	#
	# 1. Con el rng compartido, los equipos dependen de cuantos numeros
	#    consumieron los sub-tests de arriba: agregar una prueba en otro
	#    lado cambiaba los planteles de este y con ellos el resultado.
	# 2. Reusar el mismo Team para los dos bloques no es una comparacion
	#    justa: los 80 partidos del primero dejan al plantel fatigado,
	#    lesionado y suspendido, asi que el segundo juega con otro equipo.
	var muestras := 80
	var calenton := _amarillas_con_rasgo(["", "Calenton"], muestras)
	var canchero := _amarillas_con_rasgo(["Canchero", ""], muestras)

	# Se pide una diferencia del 10% y no solo "mayor". El factor es 1.30
	# contra 0.70, casi el doble de propension: si el efecto esta vivo se
	# tiene que ver holgado. Pasar por cinco tarjetas sobre ciento veinte
	# —que es como venia pasando— es pasar por ruido.
	if calenton > canchero * 1.10:
		print("OK: Calenton=%d amarillas en %d partidos, Canchero=%d (+%.0f%%)." % [
			calenton, muestras, canchero,
			100.0 * calenton / maxf(canchero, 1) - 100.0])
	else:
		print("FALLA: calenton=%d canchero=%d" % [calenton, canchero])


## Cuantas amarillas junta un equipo cuyos MARCADORES —titulares y banco—
## tienen todos el mismo rasgo. El banco tambien: si no, los cambios
## meten gente con personalidad al azar y diluyen justo lo que se mide.
func _amarillas_con_rasgo(rasgo: Array, muestras: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31337
	var home := Team.generar("HomeTarjetas", rng, 0)
	var away := Team.generar("AwayTarjetas", rng, 100)
	for j in home.jugadores + home.banco:
		if j["posicion"] in ["DFC", "LAT", "MC"]:
			j["personalidades"] = {"positiva": rasgo[0], "negativa": rasgo[1]}
	return _amarillas_de(home, away, muestras)


## Cuantas AMARILLAS junta `home` en `muestras` partidos.
##
## No se cuentan eventos de tarjeta: la segunda amarilla no emite un
## evento "amarilla" sino uno solo de roja por doble amarilla, asi que un
## jugador MAS propenso convierte dos eventos en uno y el conteo baja.
## Contando amarillas de verdad —la doble vale dos— el efecto se ve.
func _amarillas_de(home: Team, away: Team, muestras: int) -> int:
	var total := 0
	for i in range(muestras):
		var r := RandomNumberGenerator.new()
		r.seed = 7000 + i
		var res := MatchEngine.simular(home, away, r, false)
		for ev in res["eventos"]:
			if ev["tipo"] != "tarjeta" or ev["equipo"] != home.nombre:
				continue
			match str(ev["resultado"]):
				"amarilla":
					total += 1
				"roja_doble_amarilla":
					total += 2
	return total


func _test_integracion_rachas_persisten_y_se_actualizan_jugando_de_verdad(rng: RandomNumberGenerator) -> void:
	print("\n=== Integracion: jugar fechas reales sube partidos_seguidos_titular/banco, y sobrevive un guardado ===")
	var liga := Liga.new()
	liga.inicializar(["HomeRachas", "AwayRachas"], rng, 0)
	var home: Team = liga.equipos[0]
	var titular_id: int = home.jugadores[0]["id"]
	var suplente_id: int = home.banco[0]["id"]

	var n_fechas: int = liga.fixture.size()  # 2 equipos = ida y vuelta, 2 fechas
	for fecha in range(n_fechas):
		liga.jugar_fecha(fecha, rng)
		liga.avanzar_dias(7)

	var titular: Dictionary = home.jugadores[0]
	var suplente: Dictionary = home.banco[0]
	var ok := true
	ok = ok and int(titular.get("partidos_seguidos_titular", 0)) == n_fechas
	ok = ok and int(suplente.get("partidos_seguidos_banco", 0)) == n_fechas

	var datos := home.guardar()
	var cargado := Team.cargar(JSON.parse_string(JSON.stringify(datos)))
	var titular_cargado := {}
	for j in cargado.jugadores:
		if j["id"] == titular_id:
			titular_cargado = j
			break
	ok = ok and int(titular_cargado.get("partidos_seguidos_titular", -1)) == n_fechas
	ok = ok and typeof(titular_cargado["partidos_seguidos_titular"]) == TYPE_INT

	if ok:
		print("OK: %d fechas jugadas -> titular=%d, banco=%d, y sobrevive el guardado (como int)." % [n_fechas, n_fechas, n_fechas])
	else:
		print("FALLA: titular=%d banco=%d titular_cargado=%s" % [
			titular.get("partidos_seguidos_titular", -1), suplente.get("partidos_seguidos_banco", -1), titular_cargado.get("partidos_seguidos_titular", "?")
		])


# ---------------------------------------------------------------------------
# Los tres rasgos que desbloqueo el motor espacial (ver docs/motor_espacial.md)
# ---------------------------------------------------------------------------

## Metodico juega al libro: menos temperatura en el softmax = elige mas
## seguido la opcion de mayor utilidad en vez de probar cosas.
func _test_metodico_baja_la_temperatura(rng: RandomNumberGenerator) -> void:
	print("
=== Metodico baja la temperatura del softmax ===")
	var equipo := Team.generar("ClubT", rng, 60)
	var jugador: Dictionary = equipo.jugadores[5].duplicate(true)
	jugador["personalidades"] = {}
	var t_normal := MotorEspacial.temperatura(jugador, 0.4)
	jugador["personalidades"] = {"positiva": "Metodico", "negativa": ""}
	var t_metodico := MotorEspacial.temperatura(jugador, 0.4)

	# Tambien tiene que comerse parte del nerviosismo por presion: bajo
	# presion alta la brecha entre los dos crece, no se mantiene igual.
	jugador["personalidades"] = {}
	var t_normal_presion := MotorEspacial.temperatura(jugador, 1.0)
	jugador["personalidades"] = {"positiva": "Metodico", "negativa": ""}
	var t_metodico_presion := MotorEspacial.temperatura(jugador, 1.0)

	var ok: bool = t_metodico < t_normal
	ok = ok and (t_normal_presion - t_metodico_presion) > (t_normal - t_metodico)

	if ok:
		print("OK: temperatura %.3f -> %.3f (presion baja), %.3f -> %.3f (presion alta)." % [
			t_normal, t_metodico, t_normal_presion, t_metodico_presion])
	else:
		print("FALLA: %.3f/%.3f y %.3f/%.3f" % [
			t_normal, t_metodico, t_normal_presion, t_metodico_presion])


## Pie preferido le baja las GANAS de jugar hacia su lado malo, no la
## calidad: dos opciones identicas salvo por el lado quedan con distinta
## utilidad, y la del lado bueno no se toca.
func _test_pie_preferido_castiga_el_lado_malo(rng: RandomNumberGenerator) -> void:
	print("
=== Pie preferido castiga las jugadas hacia el lado malo ===")
	var local := Team.generar("ClubP", rng, 60)
	var visita := Team.generar("RivalP", rng, 60)
	local.reset_partido()
	visita.reset_partido()
	local.local = true
	visita.local = false
	var estado := MotorEspacial.crear_estado(local, visita, rng)
	MotorEspacial._armar_jugadores(local, true, estado)
	MotorEspacial._armar_jugadores(visita, false, estado)

	# Un poseedor en el medio, y dos companeros espejados en y: la unica
	# diferencia entre las dos opciones es hacia que lado va la pelota.
	var claves: Array = estado["jugadores"].keys()
	var poseedor: Dictionary = {}
	var arriba: Dictionary = {}
	var abajo: Dictionary = {}
	for c in claves:
		var e: Dictionary = estado["jugadores"][c]
		if not e["equipo_local"] or e["rol"] == "ARQ":
			continue
		if poseedor.is_empty():
			poseedor = e
		elif arriba.is_empty():
			arriba = e
		elif abajo.is_empty():
			abajo = e
	poseedor["pos"] = Vector2(0.0, 0.0)
	arriba["pos"] = Vector2(10.0, -12.0)
	abajo["pos"] = Vector2(10.0, 12.0)

	var jugador := MotorEspacial._dict_jugador(estado, local, poseedor["jugador_id"])
	jugador["personalidades"] = {}
	var sin_rasgo := _utilidades_por_objetivo(estado, poseedor, jugador)
	jugador["personalidades"] = {"positiva": "", "negativa": "Pie preferido"}
	var con_rasgo := _utilidades_por_objetivo(estado, poseedor, jugador)

	var pie := Personalidad.pie_preferido(jugador)
	# El poseedor es local (ataca hacia +x), asi que el lado "y positivo"
	# es el mismo signo que devuelve pie_preferido.
	var clave_buena: int = abajo["clave"] if pie > 0 else arriba["clave"]
	var clave_mala: int = arriba["clave"] if pie > 0 else abajo["clave"]

	var ok: bool = con_rasgo.has(clave_mala) and sin_rasgo.has(clave_mala)
	ok = ok and con_rasgo[clave_mala] < sin_rasgo[clave_mala]
	ok = ok and is_equal_approx(con_rasgo.get(clave_buena, 0.0), sin_rasgo.get(clave_buena, 0.0))

	if ok:
		print("OK: lado malo %.3f -> %.3f, lado bueno sin cambios (%.3f)." % [
			sin_rasgo[clave_mala], con_rasgo[clave_mala], con_rasgo[clave_buena]])
	else:
		print("FALLA: malo %s->%s bueno %s->%s" % [
			sin_rasgo.get(clave_mala), con_rasgo.get(clave_mala),
			sin_rasgo.get(clave_buena), con_rasgo.get(clave_buena)])


func _utilidades_por_objetivo(estado: Dictionary, poseedor: Dictionary, jugador: Dictionary) -> Dictionary:
	var out := {}
	for o in MotorEspacial.evaluar_opciones(estado, poseedor, jugador):
		if str(o["tipo"]) == "pase" and o.has("objetivo_id"):
			out[int(o["objetivo_id"])] = float(o["utilidad"])
	return out


## Enfocado corrige dos cosas: donde se para (margen) y cuando arranca el
## desmarque (tolerancia al juzgar la infraccion).
func _test_enfocado_afina_el_desmarque(rng: RandomNumberGenerator) -> void:
	print("
=== Enfocado afina el desmarque ===")
	var local := Team.generar("ClubE", rng, 60)
	var visita := Team.generar("RivalE", rng, 60)
	local.reset_partido()
	visita.reset_partido()
	for j in local.jugadores_en_cancha():
		j["personalidades"] = {"positiva": "Enfocado", "negativa": ""}
	var estado := MotorEspacial.crear_estado(local, visita, rng)
	MotorEspacial._armar_jugadores(local, true, estado)
	MotorEspacial._armar_jugadores(visita, false, estado)

	var con_margen := 0
	var sin_margen := 0
	for c in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][c]
		if is_equal_approx(float(e["margen_offside"]), MotorEspacial.FACTOR_OFFSIDE_ENFOCADO) 				and is_equal_approx(float(e["tolerancia_offside"]), MotorEspacial.TOLERANCIA_OFFSIDE_ENFOCADO):
			con_margen += 1
		elif is_equal_approx(float(e["margen_offside"]), 1.0) 				and is_equal_approx(float(e["tolerancia_offside"]), 0.0):
			sin_margen += 1

	var ok: bool = con_margen == 11 and sin_margen == 11
	if ok:
		print("OK: los 11 con el rasgo llevan margen %.2f y tolerancia %.1f m; los 11 rivales, ninguna." % [
			MotorEspacial.FACTOR_OFFSIDE_ENFOCADO, MotorEspacial.TOLERANCIA_OFFSIDE_ENFOCADO])
	else:
		print("FALLA: con=%d sin=%d (se esperaban 11 y 11)" % [con_margen, sin_margen])
