extends "res://tests/test_identificador_remate.gd"


func _init() -> void:
	for local in [true, false]:
		for distancia in [0.3, 2.0, 15.0]:
			for y in [-3.0, 0.0, 3.0]:
				for manotazo in [false, true]:
					_test_salida(local, distancia, y, manotazo)
	print("FALLOS=%d" % fallos)
	quit(1 if fallos else 0)


func _test_salida(local: bool, distancia: float, y: float, manotazo: bool) -> void:
	var escena := _escena(local, distancia, 50.0)
	var estado: Dictionary = escena["estado"]
	var pelota: Dictionary = estado["pelota"]
	var arco := MotorEspacial.arco_rival(local)
	var desde: Vector2 = escena["poseedor"]["pos"]
	desde.y = y
	pelota["pos"] = desde if manotazo else desde + Vector2(-2.0 if local else 2.0, 0.0)
	if manotazo:
		MotorEspacial._manotear_al_corner(estado, local)
	else:
		MotorEspacial._desviar_afuera(estado, desde, not local)
	var destino: Vector2 = pelota["destino_pos"]
	var t := (arco.x - desde.x) / (destino.x - desde.x)
	var cruce := desde.lerp(destino, t)
	_comprobar(pelota["origen_pos"].is_equal_approx(desde)
		and absf(cruce.y) >= MotorEspacial.ARCO_MEDIO_ANCHO + 1.49
		and t > 0.0 and t < 1.0,
		"rechazo cruza fuera del poste: local=%s distancia=%.1f y=%.1f manotazo=%s" % [local, distancia, y, manotazo])
	for tick in range(100):
		if not pelota.has("saliendo"):
			break
		MotorEspacial._avanzar_pelota(estado)
	_comprobar(estado["reinicios"].get("corner", 0) == 1
		and escena["casa"].goles == 0 and escena["visita"].goles == 0,
		"salida mantiene corner sin gol")
