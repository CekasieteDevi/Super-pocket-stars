extends "res://tests/test_identificador_remate.gd"


func _init() -> void:
	for local in [true, false]:
		for distancia in [0.3, 2.0, 15.0]:
			for y in [-3.0, 0.0, 3.0]:
				for manotazo in [false, true]:
					_test_salida(local, distancia, y, manotazo)
	_test_continuidad_visual()
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


func _test_continuidad_visual() -> void:
	var base := {"periodo": 1, "acciones": [], "jugadores": [], "lateral_preparacion": {}}
	var antes := base.duplicate(true)
	antes["pelota"] = {"x": 0.0, "y": 0.0, "z": 0.4, "poseedor_id": -1,
		"es_pase": false, "es_remate": true, "saliendo": false}
	var desviada := base.duplicate(true)
	desviada["pelota"] = {"x": 2.0, "y": 0.0, "z": 0.3, "poseedor_id": -1,
		"es_pase": false, "es_remate": false, "saliendo": true}
	var corner := base.duplicate(true)
	corner["pelota"] = {"x": 4.0, "y": 0.0, "z": 0.0, "poseedor_id": -1,
		"es_pase": false, "es_remate": false, "saliendo": false}
	var coreografia := CoreografiaPartido.new()
	coreografia.configurar([antes, desviada, corner], {})
	_comprobar((coreografia.pelota(0, 0.5)["pos"] as Vector2).is_equal_approx(Vector2(1.0, 0.0)),
		"la pelota se ve entre el remate y el manotazo")
	_comprobar((coreografia.pelota(1, 0.5)["pos"] as Vector2).is_equal_approx(Vector2(2.0, 0.0)),
		"la colocacion del corner conserva el corte")
