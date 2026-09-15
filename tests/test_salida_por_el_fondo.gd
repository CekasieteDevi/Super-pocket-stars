extends SceneTree

## La pelota que se va por el fondo no se mete en la red de afuera ni
## frena donde, en pantalla, queda encima del dibujo del arco. Antes un
## remate cruzado desde la banda terminaba adentro de la red, y el 38% de
## las salidas por el fondo frenaba sobre el dibujo del arco
## (tests/_diag_pelota_en_la_red.gd).
## Correr con: godot --headless --script tests/test_salida_por_el_fondo.gd

const SEED := 2718
const L := MotorEspacial.MEDIO_LARGO

var fallos := 0


func _init() -> void:
	_test_el_cruzado_desde_la_banda_se_abre()
	_test_el_remate_de_frente_no_cambia()
	_test_el_rebote_del_palo_no_vuelve_a_la_cancha()
	_test_ninguna_salida_toca_el_arco()
	print("FALLOS=%d" % fallos)
	quit()


func _ok(condicion: bool, texto: String) -> void:
	if condicion:
		print("OK: " + texto)
	else:
		print("FALLA: " + texto)
		fallos += 1


func _test_el_cruzado_desde_la_banda_se_abre() -> void:
	print("=== Remate cruzado desde la banda ===")
	var desde := Vector2(L - 10.0, -20.0)
	var cruce := MotorEspacial._cruce_fuera_del_arco(desde, Vector2(L, -4.5))
	var descanso := MotorEspacial._descanso_detras_del_arco(desde, cruce)
	_ok(cruce.y < -7.0, "cruza la línea en y=%.1f, lejos del palo" % cruce.y)
	_ok(is_equal_approx(descanso.x, L + MotorEspacial.DESCANSO_FONDO),
		"frena %.1f m detrás de la línea" % (descanso.x - L))


func _test_el_remate_de_frente_no_cambia() -> void:
	print("\n=== Remate de frente, abierto ===")
	var desde := Vector2(L - 16.0, 0.0)
	var cruce := MotorEspacial._cruce_fuera_del_arco(desde, Vector2(L, -4.5))
	_ok(is_equal_approx(cruce.y, -4.5), "el cruce queda donde iba: y=%.2f" % cruce.y)


func _test_el_rebote_del_palo_no_vuelve_a_la_cancha() -> void:
	print("\n=== Del palo al córner ===")
	var desde := Vector2(L, MotorEspacial.ARCO_MEDIO_ANCHO)
	var cruce := MotorEspacial._cruce_fuera_del_arco(desde, Vector2(L, 6.0))
	var descanso := MotorEspacial._descanso_detras_del_arco(desde, cruce)
	_ok(descanso.x >= L and descanso.y > 8.2, "sigue por la línea hasta (%.1f, %.1f)" % [descanso.x, descanso.y])
	var detras := MotorEspacial._descanso_detras_del_arco(Vector2(L + 1.0, 2.0), Vector2(L, 5.0))
	_ok(detras.x > L, "desde atrás de la línea no vuelve a la cancha: x=%.1f" % detras.x)


func _test_ninguna_salida_toca_el_arco() -> void:
	print("\n=== Ninguna salida por el fondo atraviesa la red ni frena sobre el arco ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var atraviesan := 0
	var encima := 0
	var casos := 600
	for i in range(casos):
		var lado := 1.0 if i % 2 == 0 else -1.0
		var desde := Vector2(lado * rng.randf_range(L - 35.0, L - 0.5), rng.randf_range(-33.0, 33.0))
		var y := rng.randf_range(MotorEspacial.ARCO_MEDIO_ANCHO, 12.0) * (1.0 if rng.randf() < 0.5 else -1.0)
		var cruce := MotorEspacial._cruce_fuera_del_arco(desde, Vector2(lado * L, y))
		var descanso := MotorEspacial._descanso_detras_del_arco(desde, cruce)
		# Del cruce al descanso, en pasos chicos: nunca adentro del arco.
		for k in range(21):
			var p := cruce.lerp(descanso, k / 20.0)
			var fondo := absf(p.x) - L
			if fondo > 0.0 and fondo < MotorEspacial.PROFUNDIDAD_ARCO and absf(p.y) < MotorEspacial.ARCO_MEDIO_ANCHO:
				atraviesan += 1
				break
		if _encima_del_arco(descanso):
			encima += 1
			if encima <= 5:
				print("  desde (%.1f, %.1f) cruce (%.1f, %.1f) descanso (%.1f, %.1f)" % [
					desde.x, desde.y, cruce.x, cruce.y, descanso.x, descanso.y])
	_ok(atraviesan == 0, "%d de %d atraviesan la red" % [atraviesan, casos])
	_ok(encima == 0, "%d de %d frenan sobre el dibujo del arco" % [encima, casos])


## Misma caja que tests/_diag_pelota_en_la_red.gd.
func _encima_del_arco(pos: Vector2) -> bool:
	var lado := signf(pos.x)
	var caja := Rect2(VistaCancha._q(Vector3(lado * L, -VistaCancha.ARCO_MEDIO_ANCHO, 0)), Vector2.ZERO)
	for x in [L, L + VistaCancha.ARCO_FONDO]:
		for y in [-VistaCancha.ARCO_MEDIO_ANCHO, VistaCancha.ARCO_MEDIO_ANCHO]:
			for z in [0.0, VistaCancha.ARCO_ALTO]:
				caja = caja.expand(VistaCancha._q(Vector3(lado * x, y, z)))
	return caja.grow(0.4).has_point(VistaCancha._q(Vector3(pos.x, pos.y, 0)))
