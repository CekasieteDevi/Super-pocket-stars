extends SceneTree

## Instalaciones del club (§9.5) — mejorar(), y los efectos que producen en
## el resto del motor. Correr con: godot --headless --script tests/test_instalaciones.gd

const SEED := 8080


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	_test_mejorar_sube_nivel_y_gasta(rng)
	_test_mejorar_rechazo_sin_fondos(rng)
	_test_mejorar_rechazo_nivel_maximo(rng)
	_test_scouting_sube_nivel_de_scout(rng)
	_test_efectos_escalan_con_el_nivel(rng)
	_test_entrenamiento_escala_cupos_y_crecimiento(rng)

	quit()


func _test_mejorar_sube_nivel_y_gasta(rng: RandomNumberGenerator) -> void:
	print("=== mejorar(): sube nivel y descuenta del presupuesto de Mejoras ===")
	var equipo := Team.generar("ClubA", rng, 0)
	equipo.caja["mejoras"] = 1000000.0

	var costo_esperado := Instalaciones.costo_siguiente_nivel(1)
	var resultado := Instalaciones.mejorar(equipo, "estadio")

	var ok: bool = resultado["exito"]
	ok = ok and equipo.instalaciones["estadio"] == 2
	ok = ok and is_equal_approx(resultado["costo"], costo_esperado)
	ok = ok and is_equal_approx(equipo.caja["mejoras"], 1000000.0 - costo_esperado)

	if ok:
		print("OK: nivel subio a 2 y se desconto el costo del presupuesto de Mejoras.")
	else:
		print("FALLA: %s (instalaciones=%s, caja=%s)" % [resultado, equipo.instalaciones, equipo.caja["mejoras"]])


func _test_mejorar_rechazo_sin_fondos(rng: RandomNumberGenerator) -> void:
	print("\n=== mejorar(): rechazo sin fondos ===")
	var equipo := Team.generar("ClubB", rng, 1000)
	equipo.caja["mejoras"] = 0.0

	var resultado := Instalaciones.mejorar(equipo, "medica")
	if not resultado["exito"] and equipo.instalaciones["medica"] == 1:
		print("OK: se rechazo por falta de fondos, el nivel no cambio.")
	else:
		print("FALLA: %s" % [resultado])


func _test_mejorar_rechazo_nivel_maximo(rng: RandomNumberGenerator) -> void:
	print("\n=== mejorar(): rechazo en el nivel maximo ===")
	var equipo := Team.generar("ClubC", rng, 2000)
	equipo.caja["mejoras"] = 100000000.0
	equipo.instalaciones["juveniles"] = Instalaciones.NIVEL_MAXIMO

	var resultado := Instalaciones.mejorar(equipo, "juveniles")
	if not resultado["exito"]:
		print("OK: no se puede subir mas alla del nivel maximo.")
	else:
		print("FALLA: se esperaba un rechazo en el nivel maximo.")


func _test_scouting_sube_nivel_de_scout(rng: RandomNumberGenerator) -> void:
	print("\n=== mejorar('scouting'): tambien sube Scout.nivel ===")
	var equipo := Team.generar("ClubD", rng, 3000)
	equipo.caja["mejoras"] = 100000000.0

	for i in range(4):
		Instalaciones.mejorar(equipo, "scouting")

	var ok: bool = equipo.instalaciones["scouting"] == 5
	ok = ok and equipo.scouts[0]["nivel"] > 1
	ok = ok and equipo.scouts[0]["nivel"] <= Scout.NIVEL_MAXIMO

	if ok:
		print("OK: subir scouting tambien sube el nivel real del scout (nivel=%d)." % equipo.scouts[0]["nivel"])
	else:
		print("FALLA: instalaciones=%s scouts=%s" % [equipo.instalaciones, equipo.scouts])


func _test_efectos_escalan_con_el_nivel(rng: RandomNumberGenerator) -> void:
	print("\n=== Los efectos (riesgo de lesion, recuperacion, aforo, camada) escalan con el nivel ===")
	var equipo := Team.generar("ClubE", rng, 4000)

	var riesgo_nivel1 := Instalaciones.factor_riesgo_lesion(equipo)
	var recuperacion_nivel1 := Instalaciones.factor_recuperacion_fatiga(equipo)
	var aforo_nivel1 := Instalaciones.factor_aforo(equipo)
	var camada_nivel1 := Instalaciones.cantidad_camada(equipo)

	equipo.instalaciones["medica"] = 5
	equipo.instalaciones["estadio"] = 5
	equipo.instalaciones["juveniles"] = 5

	var riesgo_nivel5 := Instalaciones.factor_riesgo_lesion(equipo)
	var recuperacion_nivel5 := Instalaciones.factor_recuperacion_fatiga(equipo)
	var aforo_nivel5 := Instalaciones.factor_aforo(equipo)
	var camada_nivel5 := Instalaciones.cantidad_camada(equipo)

	var ok: bool = riesgo_nivel5 < riesgo_nivel1
	ok = ok and recuperacion_nivel5 > recuperacion_nivel1
	ok = ok and aforo_nivel5 > aforo_nivel1
	ok = ok and camada_nivel5 > camada_nivel1

	if ok:
		print("OK: nivel 5 reduce el riesgo de lesion y sube recuperacion/aforo/camada respecto a nivel 1.")
	else:
		print("FALLA: riesgo %.4f->%.4f recuperacion %.2f->%.2f aforo %.2f->%.2f camada %d->%d" % [
			riesgo_nivel1, riesgo_nivel5, recuperacion_nivel1, recuperacion_nivel5,
			aforo_nivel1, aforo_nivel5, camada_nivel1, camada_nivel5
		])


func _test_entrenamiento_escala_cupos_y_crecimiento(rng: RandomNumberGenerator) -> void:
	print("\n=== Entrenamiento: cupos de foco (=nivel) y +1%%/nivel de crecimiento, tope +4%% a nivel 5 ===")
	var equipo := Team.generar("ClubF", rng, 0)

	var cupos_nivel1 := Instalaciones.limite_foco_individual(equipo)
	var factor_nivel1 := Instalaciones.factor_entrenamiento(equipo)
	equipo.instalaciones["entrenamiento"] = 3
	var cupos_nivel3 := Instalaciones.limite_foco_individual(equipo)
	equipo.instalaciones["entrenamiento"] = 5
	var cupos_nivel5 := Instalaciones.limite_foco_individual(equipo)
	var factor_nivel5 := Instalaciones.factor_entrenamiento(equipo)

	# El cupo sube con el nivel hasta 3 y ahi se planta: del 4 en adelante
	# las instalaciones siguen valiendo por el +% de crecimiento, no por
	# mas jugadores en foco.
	var ok: bool = cupos_nivel1 == 1 and cupos_nivel3 == 3 and cupos_nivel5 == 3
	ok = ok and is_equal_approx(factor_nivel1, 1.0)
	ok = ok and is_equal_approx(factor_nivel5, 1.04)

	if ok:
		print("OK: cupos 1->3->3 (tope duro), factor de crecimiento 1.00x->1.04x.")
	else:
		print("FALLA: cupos %d/%d/%d factor %.3f->%.3f" % [
			cupos_nivel1, cupos_nivel3, cupos_nivel5, factor_nivel1, factor_nivel5])
