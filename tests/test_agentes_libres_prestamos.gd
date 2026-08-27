extends SceneTree

## Agentes libres (AgentesLibres) y prestamos (Prestamos) — plantel de 25
## extendido. Correr con: godot --headless --script tests/test_agentes_libres_prestamos.gd

const SEED := 7070


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	_test_liberar_y_fichar_libre(rng)
	_test_avanzar_contratos_libera_no_protegido_pero_no_protegido(rng)
	_test_prestamo_desde_banco_y_retorno(rng)
	_test_prestamo_desde_cantera_y_retorno(rng)
	_test_prestamo_rechazo_sin_fondos(rng)
	_test_prestamo_rechazo_no_es_banco_ni_cantera(rng)

	quit()


func _test_liberar_y_fichar_libre(rng: RandomNumberGenerator) -> void:
	print("=== AgentesLibres: liberar + fichar ===")
	var equipo := Team.generar("ClubA", rng, 0)
	var pool := []

	var jugador: Dictionary = equipo.banco[0]
	var id_liberado: int = jugador["id"]
	var posicion: String = jugador["posicion"]

	AgentesLibres.liberar(equipo, jugador, pool, rng)

	var ok: bool = pool.size() == 1 and pool[0]["id"] == id_liberado
	ok = ok and not equipo.sueldos.has(id_liberado) and not equipo.contratos.has(id_liberado)
	ok = ok and equipo.banco.size() == 7  # el puesto se repuso, no quedo un hueco
	ok = ok and equipo.banco[0]["posicion"] == posicion  # el reemplazo es de la misma posicion

	if not ok:
		print("FALLA: liberar no dejo el estado esperado.")
		quit()
		return

	# Fichar del pool: otro club se lleva al liberado.
	var otro := Team.generar("ClubB", rng, 1000)
	otro.caja["fichajes"] = 1000000.0
	var saliente_id: int = otro.banco[0]["id"]

	var resultado := AgentesLibres.fichar(otro, pool, id_liberado, 0, true)

	ok = resultado["exito"]
	ok = ok and otro.banco[0]["id"] == id_liberado
	ok = ok and otro.sueldos.has(id_liberado) and not otro.sueldos.has(saliente_id)
	ok = ok and pool.size() == 1 and pool[0]["id"] == saliente_id  # el desplazado entra al pool a su vez

	if ok:
		print("OK: liberar manda al pool y repone el puesto; fichar saca del pool y el desplazado entra a su vez.")
	else:
		print("FALLA: %s" % [resultado])


func _test_avanzar_contratos_libera_no_protegido_pero_no_protegido(rng: RandomNumberGenerator) -> void:
	print("\n=== Liga._avanzar_contratos: protegido nunca pierde jugadores por vencimiento ===")
	var liga := Liga.new()
	liga.inicializar(["Protegido", "Rival"], rng, 0)
	var protegido: Team = liga.equipos[0]

	for id in protegido.contratos.keys():
		protegido.contratos[id] = 1
	for j in protegido.todos_los_jugadores():
		j["edad"] = 35  # maxima probabilidad de irse, para forzar el caso si no estuviera protegido

	var ids_antes := []
	for j in protegido.todos_los_jugadores():
		ids_antes.append(j["id"])

	for i in range(5):
		liga._avanzar_contratos(protegido, rng, true)

	var ids_despues := []
	for j in protegido.todos_los_jugadores():
		ids_despues.append(j["id"])

	if ids_antes == ids_despues:
		print("OK: el plantel protegido no perdio a nadie por vencimiento de contrato.")
	else:
		print("FALLA: el equipo protegido perdio jugadores por vencimiento.")


func _test_prestamo_desde_banco_y_retorno(rng: RandomNumberGenerator) -> void:
	print("\n=== Prestamos: ceder desde banco y retorno automatico ===")
	var origen := Team.generar("Dueno", rng, 2000)
	var destino := Team.generar("Prestador", rng, 3000)
	destino.caja["fichajes"] = 1000000.0

	var jugador_id: int = origen.banco[0]["id"]
	var banco_origen_antes: int = origen.banco.size()

	var resultado := Prestamos.ceder(origen, destino, jugador_id, 1)

	var ok: bool = resultado["exito"]
	ok = ok and origen.banco.size() == banco_origen_antes - 1  # hueco real, no se repone
	# El dueño CONSERVA el registro: desde el reparto de sueldo (§9.3
	# rework) sigue pagando su parte mientras dura el prestamo. Con el
	# reparto por defecto —el que recibe paga todo— esa parte es cero,
	# que es distinto de no estar.
	ok = ok and origen.sueldos.has(jugador_id) and is_zero_approx(float(origen.sueldos[jugador_id]))
	ok = ok and destino.banco.size() == 8  # se agrega de mas, no pisa a nadie
	ok = ok and destino.sueldos.has(jugador_id)
	ok = ok and origen.prestados_afuera.has(jugador_id)
	ok = ok and destino.prestados_propios.has(jugador_id)

	if not ok:
		print("FALLA en ceder(): %s" % [resultado])
		quit()
		return

	# Todavia no vuelve en la misma temporada.
	var vueltos := Prestamos.procesar_retornos(origen, 1)
	ok = vueltos.is_empty() and origen.prestados_afuera.has(jugador_id)

	# Vuelve cuando llega la temporada de retorno.
	vueltos = Prestamos.procesar_retornos(origen, 2)
	ok = ok and vueltos.size() == 1 and vueltos[0]["id"] == jugador_id
	ok = ok and not origen.prestados_afuera.has(jugador_id)
	ok = ok and not destino.prestados_propios.has(jugador_id)
	ok = ok and not destino.sueldos.has(jugador_id)
	ok = ok and origen.sueldos.has(jugador_id)

	var vuelve_en_banco := false
	for j in origen.banco:
		if j["id"] == jugador_id:
			vuelve_en_banco = true
			break

	if ok and vuelve_en_banco:
		print("OK: el prestamo deja un hueco real en origen, agrega de mas en destino, y vuelve solo al cierre correcto.")
	else:
		print("FALLA: el retorno del prestamo no dejo el estado esperado.")


func _test_prestamo_desde_cantera_y_retorno(rng: RandomNumberGenerator) -> void:
	print("\n=== Prestamos: ceder desde cantera vuelve a cantera ===")
	var origen := Team.generar("DuenoCantera", rng, 4000)
	origen.generar_camada(rng, 1)
	var juvenil_id: int = origen.cantera[0]["id"]

	var destino := Team.generar("PrestadorCantera", rng, 5000)
	destino.caja["fichajes"] = 1000000.0

	var resultado := Prestamos.ceder(origen, destino, juvenil_id, 1)
	if not resultado["exito"]:
		print("FALLA en ceder() desde cantera: %s" % [resultado])
		return

	var vueltos := Prestamos.procesar_retornos(origen, 2)
	var vuelve_a_cantera := false
	for j in origen.cantera:
		if j["id"] == juvenil_id:
			vuelve_a_cantera = true
			break

	if vueltos.size() == 1 and vuelve_a_cantera:
		print("OK: el juvenil cedido desde cantera vuelve a cantera, no al banco.")
	else:
		print("FALLA: el retorno desde cantera no funciono como se esperaba.")


func _test_prestamo_rechazo_sin_fondos(rng: RandomNumberGenerator) -> void:
	print("\n=== Prestamos: rechazo sin fondos para el fee ===")
	var origen := Team.generar("DuenoRico", rng, 6000)
	var destino := Team.generar("PrestadorPobre", rng, 7000)
	destino.caja["fichajes"] = 0.0

	var jugador_id: int = origen.banco[0]["id"]
	var resultado := Prestamos.ceder(origen, destino, jugador_id, 1)

	if not resultado["exito"] and resultado.has("fee"):
		print("OK: se rechazo el prestamo por falta de fondos para el fee.")
	else:
		print("FALLA: se esperaba un rechazo por fondos insuficientes.")


func _test_prestamo_rechazo_no_es_banco_ni_cantera(rng: RandomNumberGenerator) -> void:
	print("\n=== Prestamos: rechazo si el jugador es titular ===")
	var origen := Team.generar("DuenoTitular", rng, 8000)
	var destino := Team.generar("PrestadorTitular", rng, 9000)
	destino.caja["fichajes"] = 1000000.0

	var jugador_id: int = origen.jugadores[0]["id"]
	var resultado := Prestamos.ceder(origen, destino, jugador_id, 1)

	if not resultado["exito"]:
		print("OK: no se puede prestar a un titular.")
	else:
		print("FALLA: se esperaba que se rechazara el prestamo de un titular.")
