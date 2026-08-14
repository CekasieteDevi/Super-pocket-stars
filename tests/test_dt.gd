extends SceneTree

## DT rival (§8.6.4) — nivel 1-10 + rasgo (Conservador/Loco/Cantera/
## Chequera), horneado por club. Conectado en: config_cambios por default
## (nivel), modificador de bloque C atado al marcador (Loco/Conservador),
## y sesgo de cantera/mercado de la IA (Cantera/Chequera).
## Correr con: godot --headless --script tests/test_dt.gd

const SEED := 6161


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	_test_todo_equipo_generado_tiene_dt_valido(rng)
	_test_config_cambios_de_nivel(rng)
	_test_team_generar_usa_el_config_cambios_del_dt(rng)
	_test_loco_empuja_al_ataque_si_va_perdiendo_pasado_el_60(rng)
	_test_conservador_se_repliega_si_va_ganando_pasado_el_60(rng)
	_test_sin_dt_o_antes_de_tiempo_no_hay_modificador(rng)
	_test_factores_de_cantera_y_fichaje(rng)
	_test_ajuste_resistencia_venta(rng)
	_test_dt_persiste_en_guardado_y_migra_guardados_viejos(rng)

	quit()


func _test_todo_equipo_generado_tiene_dt_valido(rng: RandomNumberGenerator) -> void:
	print("=== Todo equipo generado tiene un DT con nivel 1-10 y un rasgo valido ===")
	var equipo := Team.generar("ClubA", rng, 0)
	var nivel: int = equipo.dt.get("nivel", -1)
	var rasgo: String = equipo.dt.get("rasgo", "")
	if nivel >= DT.NIVEL_MIN and nivel <= DT.NIVEL_MAX and DT.RASGOS.has(rasgo):
		print("OK: DT nivel=%d rasgo=%s" % [nivel, rasgo])
	else:
		print("FALLA: dt=%s" % [equipo.dt])


func _test_config_cambios_de_nivel(rng: RandomNumberGenerator) -> void:
	print("\n=== config_cambios_de mapea nivel -> umbral de cambios ===")
	var ok := true
	ok = ok and DT.config_cambios_de(1) == "rendimiento"
	ok = ok and DT.config_cambios_de(3) == "rendimiento"
	ok = ok and DT.config_cambios_de(4) == "equilibrado"
	ok = ok and DT.config_cambios_de(7) == "equilibrado"
	ok = ok and DT.config_cambios_de(8) == "descanso"
	ok = ok and DT.config_cambios_de(10) == "descanso"
	if ok:
		print("OK: 1-3 rendimiento, 4-7 equilibrado, 8-10 descanso.")
	else:
		print("FALLA")


func _test_team_generar_usa_el_config_cambios_del_dt(rng: RandomNumberGenerator) -> void:
	print("\n=== Team.generar() usa el config_cambios que corresponde al nivel del DT ===")
	var ok := true
	for i in range(20):
		var equipo := Team.generar("Club%d" % i, rng, i * 100)
		var esperado := DT.config_cambios_de(equipo.dt["nivel"])
		if equipo.config_cambios != esperado:
			ok = false
			print("FALLA: nivel=%d config_cambios=%s esperado=%s" % [equipo.dt["nivel"], equipo.config_cambios, esperado])
			break
	if ok:
		print("OK: config_cambios siempre coincide con DT.config_cambios_de(nivel) en 20 equipos generados.")


func _test_loco_empuja_al_ataque_si_va_perdiendo_pasado_el_60(rng: RandomNumberGenerator) -> void:
	print("\n=== Loco: bonus ofensivo / malus defensivo si va perdiendo pasado el minuto 60 ===")
	var equipo := Team.generar("ClubLoco", rng, 0)
	var rival := Team.generar("Rival", rng, 100)
	equipo.dt = {"nivel": 5, "rasgo": "Loco"}
	equipo.goles = 0
	rival.goles = 1

	var mod_ataque := DT.modificador_partido(equipo, rival, "tiro", 65)
	var mod_defensa := DT.modificador_partido(equipo, rival, "quite", 65)

	if is_equal_approx(mod_ataque, DT.BONUS_LOCO) and is_equal_approx(mod_defensa, -DT.MALUS_LOCO):
		print("OK: +%.1f en ataque, -%.1f en defensa yendo perdiendo pasado el 60." % [DT.BONUS_LOCO, DT.MALUS_LOCO])
	else:
		print("FALLA: ataque=%.1f defensa=%.1f" % [mod_ataque, mod_defensa])


func _test_conservador_se_repliega_si_va_ganando_pasado_el_60(rng: RandomNumberGenerator) -> void:
	print("\n=== Conservador: malus ofensivo / bonus defensivo si va ganando pasado el minuto 60 ===")
	var equipo := Team.generar("ClubConservador", rng, 0)
	var rival := Team.generar("Rival2", rng, 100)
	equipo.dt = {"nivel": 5, "rasgo": "Conservador"}
	equipo.goles = 2
	rival.goles = 0

	var mod_ataque := DT.modificador_partido(equipo, rival, "control", 75)
	var mod_defensa := DT.modificador_partido(equipo, rival, "reflejos", 75)

	if is_equal_approx(mod_ataque, -DT.MALUS_CONSERVADOR) and is_equal_approx(mod_defensa, DT.BONUS_CONSERVADOR):
		print("OK: -%.1f en ataque, +%.1f en defensa yendo ganando pasado el 60." % [DT.MALUS_CONSERVADOR, DT.BONUS_CONSERVADOR])
	else:
		print("FALLA: ataque=%.1f defensa=%.1f" % [mod_ataque, mod_defensa])


func _test_sin_dt_o_antes_de_tiempo_no_hay_modificador(rng: RandomNumberGenerator) -> void:
	print("\n=== Sin DT, antes del minuto 60, o empatado/en contra del rasgo: modificador 0 ===")
	var equipo := Team.generar("ClubSinDT", rng, 0)
	var rival := Team.generar("RivalSinDT", rng, 100)
	equipo.dt = {"nivel": 5, "rasgo": "Loco"}
	equipo.goles = 0
	rival.goles = 1

	var ok := true
	ok = ok and is_equal_approx(DT.modificador_partido(equipo, rival, "tiro", 40), 0.0)  # antes del minuto 60
	equipo.goles = 1
	rival.goles = 1
	ok = ok and is_equal_approx(DT.modificador_partido(equipo, rival, "tiro", 65), 0.0)  # empatado, Loco no aplica
	var equipo_sin_dt := Team.generar("ClubVacio", rng, 200)
	equipo_sin_dt.dt = {}
	ok = ok and is_equal_approx(DT.modificador_partido(equipo_sin_dt, rival, "tiro", 65), 0.0)  # sin dt

	if ok:
		print("OK: 0.0 en los tres casos donde no deberia aplicar.")
	else:
		print("FALLA")


func _test_factores_de_cantera_y_fichaje(rng: RandomNumberGenerator) -> void:
	print("\n=== Cantera promueve mas facil y compra mas exigente; Chequera al reves ===")
	var cantera_equipo := Team.generar("ClubCantera", rng, 0)
	cantera_equipo.dt = {"nivel": 5, "rasgo": "Cantera"}
	var chequera_equipo := Team.generar("ClubChequera", rng, 100)
	chequera_equipo.dt = {"nivel": 5, "rasgo": "Chequera"}
	var normal_equipo := Team.generar("ClubNormal", rng, 200)
	normal_equipo.dt = {"nivel": 5, "rasgo": "Conservador"}

	var ok := true
	ok = ok and DT.factor_umbral_cantera(cantera_equipo) < DT.factor_umbral_cantera(normal_equipo)
	ok = ok and DT.factor_umbral_cantera(chequera_equipo) > DT.factor_umbral_cantera(normal_equipo)
	ok = ok and DT.factor_umbral_fichaje(chequera_equipo) < DT.factor_umbral_fichaje(normal_equipo)
	ok = ok and DT.factor_umbral_fichaje(cantera_equipo) > DT.factor_umbral_fichaje(normal_equipo)
	if ok:
		print("OK: Cantera mas laxo con la cantera y mas exigente comprando, Chequera al reves; un rasgo neutro no cambia nada.")
	else:
		print("FALLA")


func _test_ajuste_resistencia_venta(rng: RandomNumberGenerator) -> void:
	print("\n=== Chequera baja la resistencia de venta, Cantera la sube un poco ===")
	var chequera_equipo := Team.generar("ClubChequera2", rng, 0)
	chequera_equipo.dt = {"nivel": 5, "rasgo": "Chequera"}
	var cantera_equipo := Team.generar("ClubCantera2", rng, 100)
	cantera_equipo.dt = {"nivel": 5, "rasgo": "Cantera"}

	if DT.ajuste_resistencia_venta(chequera_equipo) < 0.0 and DT.ajuste_resistencia_venta(cantera_equipo) > 0.0:
		print("OK: Chequera=%.2f Cantera=%.2f" % [DT.ajuste_resistencia_venta(chequera_equipo), DT.ajuste_resistencia_venta(cantera_equipo)])
	else:
		print("FALLA")


func _test_dt_persiste_en_guardado_y_migra_guardados_viejos(rng: RandomNumberGenerator) -> void:
	print("\n=== dt sobrevive un guardar/cargar, y un guardado viejo (sin 'dt') se migra ===")
	var equipo := Team.generar("ClubGuardadoDT", rng, 0)
	var datos := equipo.guardar()
	var cargado := Team.cargar(JSON.parse_string(JSON.stringify(datos)))

	var datos_viejos := equipo.guardar()
	datos_viejos.erase("dt")
	var cargado_1 := Team.cargar(JSON.parse_string(JSON.stringify(datos_viejos)))
	var cargado_2 := Team.cargar(JSON.parse_string(JSON.stringify(datos_viejos)))

	var ok: bool = cargado.dt["nivel"] == equipo.dt["nivel"] and cargado.dt["rasgo"] == equipo.dt["rasgo"]
	ok = ok and DT.RASGOS.has(cargado_1.dt["rasgo"]) and cargado_1.dt["nivel"] >= DT.NIVEL_MIN and cargado_1.dt["nivel"] <= DT.NIVEL_MAX
	ok = ok and cargado_1.dt["nivel"] == cargado_2.dt["nivel"] and cargado_1.dt["rasgo"] == cargado_2.dt["rasgo"]

	if ok:
		print("OK: round-trip preserva el DT, y un guardado viejo migra a un DT valido y estable entre cargas.")
	else:
		print("FALLA: cargado=%s cargado_1=%s cargado_2=%s" % [cargado.dt, cargado_1.dt, cargado_2.dt])
