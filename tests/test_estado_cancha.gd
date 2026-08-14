extends SceneTree

## Estado de la cancha (§8.4 #21 / §8.6.2, simplificado a un numero fijo
## por club) — rango -8..+3, correlacionado con reputacion, y el
## modificador de bloque C solo pega en pases/control.
## Correr con: godot --headless --script tests/test_estado_cancha.gd

const SEED := 5858


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	_test_siempre_dentro_del_rango(rng)
	_test_correlaciona_con_reputacion(rng)
	_test_modificador_solo_en_pases_y_control(rng)
	_test_todo_equipo_generado_tiene_calidad_cancha(rng)
	_test_persiste_en_guardado_y_migra_guardados_viejos(rng)

	quit()


func _test_siempre_dentro_del_rango(rng: RandomNumberGenerator) -> void:
	print("=== generar() siempre cae dentro de [-8, 3] ===")
	var ok := true
	for i in range(2000):
		var reputacion := rng.randf_range(0.0, 100.0)
		var calidad := EstadoCancha.generar(reputacion, rng)
		if calidad < EstadoCancha.MINIMO or calidad > EstadoCancha.MAXIMO:
			ok = false
			print("FALLA: reputacion=%.1f calidad=%.2f" % [reputacion, calidad])
			break
	if ok:
		print("OK: 2000 tiradas, siempre dentro de [%.0f, %.0f]." % [EstadoCancha.MINIMO, EstadoCancha.MAXIMO])


func _test_correlaciona_con_reputacion(rng: RandomNumberGenerator) -> void:
	print("\n=== En promedio, mas reputacion da mejor cancha ===")
	var muestras := 500
	var suma_baja := 0.0
	var suma_alta := 0.0
	for i in range(muestras):
		suma_baja += EstadoCancha.generar(10.0, rng)
		suma_alta += EstadoCancha.generar(90.0, rng)
	var promedio_baja: float = suma_baja / muestras
	var promedio_alta: float = suma_alta / muestras
	if promedio_alta > promedio_baja:
		print("OK: reputacion 10 -> %.2f promedio, reputacion 90 -> %.2f promedio." % [promedio_baja, promedio_alta])
	else:
		print("FALLA: baja=%.2f alta=%.2f" % [promedio_baja, promedio_alta])


func _test_modificador_solo_en_pases_y_control(rng: RandomNumberGenerator) -> void:
	print("\n=== El modificador solo pega en pases/control, no en tiro/quite/reflejos ===")
	var ok := true
	ok = ok and is_equal_approx(EstadoCancha.modificador(-8.0, "pases"), -8.0)
	ok = ok and is_equal_approx(EstadoCancha.modificador(-8.0, "control"), -8.0)
	ok = ok and is_equal_approx(EstadoCancha.modificador(-8.0, "tiro"), 0.0)
	ok = ok and is_equal_approx(EstadoCancha.modificador(-8.0, "quite"), 0.0)
	ok = ok and is_equal_approx(EstadoCancha.modificador(-8.0, "reflejos"), 0.0)
	if ok:
		print("OK: pega en pases/control, no en el resto.")
	else:
		print("FALLA")


func _test_todo_equipo_generado_tiene_calidad_cancha(rng: RandomNumberGenerator) -> void:
	print("\n=== Todo equipo generado tiene calidad_cancha dentro de rango ===")
	var equipo := Team.generar("ClubCancha", rng, 0)
	if equipo.calidad_cancha >= EstadoCancha.MINIMO and equipo.calidad_cancha <= EstadoCancha.MAXIMO:
		print("OK: calidad_cancha=%.2f" % equipo.calidad_cancha)
	else:
		print("FALLA: calidad_cancha=%.2f" % equipo.calidad_cancha)


func _test_persiste_en_guardado_y_migra_guardados_viejos(rng: RandomNumberGenerator) -> void:
	print("\n=== calidad_cancha sobrevive el guardado, y un guardado viejo (sin la clave) migra ===")
	var equipo := Team.generar("ClubGuardadoCancha", rng, 0)
	var datos := equipo.guardar()
	var cargado := Team.cargar(JSON.parse_string(JSON.stringify(datos)))

	var datos_viejos := equipo.guardar()
	datos_viejos.erase("calidad_cancha")
	var cargado_1 := Team.cargar(JSON.parse_string(JSON.stringify(datos_viejos)))
	var cargado_2 := Team.cargar(JSON.parse_string(JSON.stringify(datos_viejos)))

	var ok: bool = is_equal_approx(cargado.calidad_cancha, equipo.calidad_cancha)
	ok = ok and cargado_1.calidad_cancha >= EstadoCancha.MINIMO and cargado_1.calidad_cancha <= EstadoCancha.MAXIMO
	ok = ok and is_equal_approx(cargado_1.calidad_cancha, cargado_2.calidad_cancha)  # estable entre cargas

	if ok:
		print("OK: round-trip preserva el valor; guardado viejo migra a uno valido y estable.")
	else:
		print("FALLA: cargado=%.2f cargado_1=%.2f cargado_2=%.2f" % [cargado.calidad_cancha, cargado_1.calidad_cancha, cargado_2.calidad_cancha])
