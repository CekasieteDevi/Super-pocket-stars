extends SceneTree

## Formaciones (§8.1): que el motor reparta por SLOT y no por puesto, que
## la formacion sobreviva un guardado y que cambiar de formacion cambie
## de verdad donde se para la gente.
## Correr con: godot --headless --script tests/test_formaciones.gd

const SEED := 4242


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_test_todas_tienen_once_slots()
	_test_el_motor_usa_la_formacion(rng)
	_test_tres_defensores_no_se_apilan(rng)
	_test_intercambiar(rng)
	_test_sobrevive_guardado(rng)
	quit()


func _test_todas_tienen_once_slots() -> void:
	print("=== Toda formacion tiene 11 slots y un solo arquero ===")
	var ok := true
	var detalle := ""
	for nombre in Formaciones.lista():
		var roles := Formaciones.roles(nombre)
		var arqueros := 0
		for r in roles:
			if r == "ARQ":
				arqueros += 1
		if roles.size() != 11 or arqueros != 1:
			ok = false
			detalle += " %s(%d slots, %d ARQ)" % [nombre, roles.size(), arqueros]
	if ok:
		print("OK: %d formaciones, todas con 11 slots y 1 arquero." % Formaciones.lista().size())
	else:
		print("FALLA:%s" % detalle)


func _test_el_motor_usa_la_formacion(rng: RandomNumberGenerator) -> void:
	print("\n=== El motor arma la cancha con la formacion del equipo ===")
	var a := Team.generar("A", rng)
	var b := Team.generar("B", rng, 100)
	a.formacion = "3-5-2"
	a.reset_partido()
	b.reset_partido()
	var st := MotorEspacial.crear_estado(a, b, rng)
	var conteo := {}
	for c in st["jugadores"]:
		if not st["jugadores"][c]["equipo_local"]:
			continue
		var r: String = st["jugadores"][c]["rol"]
		conteo[r] = int(conteo.get(r, 0)) + 1
	var esperado := Formaciones.conteo("3-5-2")
	var ok: bool = conteo == esperado
	if ok:
		print("OK: 3-5-2 pone %s en la cancha." % [conteo])
	else:
		print("FALLA: en cancha %s, la formacion pide %s" % [conteo, esperado])


func _test_tres_defensores_no_se_apilan(rng: RandomNumberGenerator) -> void:
	print("\n=== Con 3 defensores nadie queda apilado ===")
	var a := Team.generar("A", rng)
	var b := Team.generar("B", rng, 100)
	a.formacion = "5-3-2"
	a.reset_partido()
	b.reset_partido()
	var st := MotorEspacial.crear_estado(a, b, rng)
	var pos := []
	for c in st["jugadores"]:
		if st["jugadores"][c]["equipo_local"]:
			pos.append(st["jugadores"][c]["pos"])
	var minima := 999.0
	for i in range(pos.size()):
		for k in range(i + 1, pos.size()):
			minima = minf(minima, pos[i].distance_to(pos[k]))
	if minima > 0.5:
		print("OK: los 11 arrancan separados (el par mas cercano, a %.1f m)." % minima)
	else:
		print("FALLA: hay dos jugadores a %.1f m, se apilaron." % minima)


func _test_intercambiar(rng: RandomNumberGenerator) -> void:
	print("\n=== intercambiar() mueve jugadores entre slots y con el banco ===")
	var a := Team.generar("A", rng)
	var id_slot0: int = a.jugadores[0]["id"]
	var id_slot5: int = a.jugadores[5]["id"]
	var ok: bool = a.intercambiar(id_slot0, id_slot5)
	ok = ok and a.jugadores[0]["id"] == id_slot5 and a.jugadores[5]["id"] == id_slot0

	var id_titular: int = a.jugadores[3]["id"]
	var id_banco: int = a.banco[2]["id"]
	ok = ok and a.intercambiar(id_titular, id_banco)
	ok = ok and a.jugadores[3]["id"] == id_banco and a.banco[2]["id"] == id_titular
	ok = ok and not a.intercambiar(id_banco, id_banco)  # el mismo, no hace nada
	ok = ok and a.jugadores.size() == 11 and a.banco.size() == 7

	if ok:
		print("OK: intercambio entre titulares y con el banco, sin perder a nadie.")
	else:
		print("FALLA: titulares %d, banco %d" % [a.jugadores.size(), a.banco.size()])


func _test_sobrevive_guardado(rng: RandomNumberGenerator) -> void:
	print("\n=== La formacion sobrevive un guardar/cargar ===")
	var a := Team.generar("A", rng)
	a.formacion = "4-3-3"
	var cargado := Team.cargar(JSON.parse_string(JSON.stringify(a.guardar())))
	var b := Team.generar("B", rng)
	var datos := b.guardar()
	datos.erase("formacion")  # guardado viejo, sin el campo
	var viejo := Team.cargar(JSON.parse_string(JSON.stringify(datos)))
	if cargado.formacion == "4-3-3" and viejo.formacion == Formaciones.POR_DEFECTO:
		print("OK: round-trip conserva 4-3-3, y un guardado viejo cae al %s." % Formaciones.POR_DEFECTO)
	else:
		print("FALLA: cargado=%s viejo=%s" % [cargado.formacion, viejo.formacion])
