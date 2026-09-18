extends SceneTree

## Requisitos de atributo de cada regate (MotorEspacial.REGATES).

const SEED := 4242

var fallos := 0


func _init() -> void:
	_test_requisitos_por_regate()
	_test_orden_de_dificultad()
	_test_sin_requisitos_no_hay_regate()
	_test_cooldown_unico_y_bufon()
	print("FALLOS=%d" % fallos)
	quit()


func _jugador(atributos: Dictionary) -> Dictionary:
	return {"atributos": atributos}


func _test_requisitos_por_regate() -> void:
	print("=== Cada regate pide su minimo en todos sus atributos ===")
	for tipo in MotorEspacial.REGATE_ACCIONES:
		var requisitos: Dictionary = MotorEspacial.REGATES[tipo]["requisitos"]
		var justo := _jugador(requisitos.duplicate())
		if not MotorEspacial.puede_regatear(justo, tipo):
			fallos += 1
			print("FALLA: %s no sale con los atributos justos." % tipo)
			continue
		for atributo in requisitos:
			var corto := requisitos.duplicate()
			corto[atributo] = float(requisitos[atributo]) - 1.0
			if MotorEspacial.puede_regatear(_jugador(corto), tipo):
				fallos += 1
				print("FALLA: %s sale con %s un punto abajo del minimo." % [tipo, atributo])
	print("OK: los %d regates respetan sus minimos." % MotorEspacial.REGATE_ACCIONES.size())


func _test_orden_de_dificultad() -> void:
	print("\n=== El mas dificil sale menos ===")
	var lista: Array = MotorEspacial.REGATE_ACCIONES
	for i in range(1, lista.size()):
		var facil: Dictionary = MotorEspacial.REGATES[lista[i - 1]]
		var dificil: Dictionary = MotorEspacial.REGATES[lista[i]]
		if float(dificil["peso"]) >= float(facil["peso"]):
			fallos += 1
			print("FALLA: %s no queda por encima de %s en dificultad." % [lista[i], lista[i - 1]])
			return
	print("OK: %s, del mas facil al mas dificil." % [lista])


func _test_sin_requisitos_no_hay_regate() -> void:
	print("\n=== Un jugador tosco no tiene ningun regate ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var local := Team.generar("Casa", rng, 0)
	var visita := Team.generar("Visita", rng, 400)
	local.reset_partido()
	visita.reset_partido()
	var estado := MotorEspacial.crear_estado(local, visita, rng)
	var clave: int = estado["jugadores"].keys()[0]
	var poseedor: Dictionary = estado["jugadores"][clave]
	var tosco := _jugador({"agilidad": 40.0, "control": 40.0, "efecto": 40.0})
	var estado_rng: int = estado["rng"].state
	var tipo := MotorEspacial._regate_disponible(estado, poseedor, tosco)
	if tipo != "":
		fallos += 1
		print("FALLA: con 40 de todo le salio %s." % tipo)
	elif estado["rng"].state != estado_rng:
		fallos += 1
		print("FALLA: sin regates posibles igual consumio azar.")
	else:
		print("OK: con 40 de todo no hay regate y no se tira el dado.")


func _test_cooldown_unico_y_bufon() -> void:
	print("\n=== Todos los regates esperan lo mismo; Bufon espera menos ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var local := Team.generar("Casa", rng, 0)
	var visita := Team.generar("Visita", rng, 400)
	local.reset_partido()
	visita.reset_partido()
	var estado := MotorEspacial.crear_estado(local, visita, rng)
	var clave: int = estado["jugadores"].keys()[0]
	var poseedor: Dictionary = estado["jugadores"][clave]
	var comun := {"media": 85.0, "habilidades": []}
	var bufon := {"media": 85.0, "habilidades": [{"nombre": "Bufon", "nivel": 3}]}
	estado["tick"] = 100
	MotorEspacial._activar_cooldown_regate(estado, poseedor, comun)
	var espera_comun: int = int(estado["regate_cooldown"][clave]) - 100
	MotorEspacial._activar_cooldown_regate(estado, poseedor, bufon)
	var espera_bufon: int = int(estado["regate_cooldown"][clave]) - 100
	var esperada := int(round(MotorEspacial.SEGUNDOS_COOLDOWN_REGATE / MotorEspacial.TICK_SEG))
	if espera_comun != esperada:
		fallos += 1
		print("FALLA: espera %d ticks y deberia esperar %d." % [espera_comun, esperada])
	elif espera_bufon >= espera_comun:
		fallos += 1
		print("FALLA: con Bufon oro espera %d ticks, igual o mas que sin (%d)." % [espera_bufon, espera_comun])
	else:
		print("OK: %d ticks despues de cualquier regate, %d con Bufon oro." % [espera_comun, espera_bufon])
