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

	# Fichar del pool: otro club se lleva al liberado. No sale nadie a
	# cambio — se SUMA al plantel, que tiene lugar hasta
	# Team.PLANTEL_MAXIMO.
	var otro := Team.generar("ClubB", rng, 1000)
	otro.caja["fichajes"] = 1000000.0
	otro.caja["contratos"] = 1000000.0
	var plantel_antes: int = otro.todos_los_jugadores().size()

	var agente: Dictionary = pool[0]
	var pide := Renovaciones.pide_ahora(otro, agente, 2)
	var resultado := AgentesLibres.fichar(otro, pool, id_liberado, 2, pide)

	ok = bool(resultado.get("exito", false))
	ok = ok and otro.banco[otro.banco.size() - 1]["id"] == id_liberado
	ok = ok and otro.sueldos.has(id_liberado)
	# El sueldo es el negociado, no el de tabla.
	ok = ok and abs(float(otro.sueldos[id_liberado]) - pide) < 0.01
	ok = ok and otro.todos_los_jugadores().size() == plantel_antes + 1
	ok = ok and pool.is_empty()  # no entra nadie al pool a cambio

	if ok:
		print("OK: liberar manda al pool y repone el puesto; fichar entra al banco sin desplazar a nadie.")
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

	# Cinco vueltas de _avanzar_contratos vencen a todo el plantel activo,
	# y sin renovar se van todos libres: al club del jugador humano ya no
	# se le renueva solo (ver core/renovaciones.gd) ni se le inventa un
	# reemplazo (ver AgentesLibres._dejar_hueco). Lo que se chequea es que
	# el plantel se achique con lo que ya tenia —sin jugadores nuevos— y
	# que igual quede en pie un equipo que pueda jugar.
	var nadie_nuevo := true
	for id in ids_despues:
		if not ids_antes.has(id):
			nadie_nuevo = false

	var hay_equipo: bool = protegido.jugadores.size() >= MatchEngine.MINIMO_EN_CANCHA
	if nadie_nuevo and ids_despues.size() < ids_antes.size() and hay_equipo:
		print("OK: al protegido se le vencen los contratos, el plantel se achica sin inventar jugadores y nunca baja de %d titulares." % MatchEngine.MINIMO_EN_CANCHA)
	else:
		print("FALLA: antes=%d despues=%d nadie_nuevo=%s titulares=%d" % [
			ids_antes.size(), ids_despues.size(), nadie_nuevo,
			protegido.jugadores.size()])


func _test_prestamo_desde_banco_y_retorno(rng: RandomNumberGenerator) -> void:
	print("\n=== Prestamos: ceder desde banco y retorno automatico ===")
	var origen := Team.generar("Dueno", rng, 2000)
	var destino := Team.generar("Prestador", rng, 3000)
	destino.caja["fichajes"] = 1000000.0
	destino.caja["contratos"] = 1000000.0

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
	# El banco del destino ya tenia sus 7 suplentes, asi que el prestado
	# entra como RESERVA: se agrega de mas y no pisa a nadie.
	ok = ok and destino.banco.size() == Team.max_suplentes()
	ok = ok and destino.reservas.size() == 1
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
	# procesar_retornos devuelve REPORTES, no jugadores: ademas del que
	# vuelve trae cuanto jugo, cuanto metio y cuanto crecio afuera.
	ok = ok and vueltos.size() == 1 and vueltos[0]["jugador"]["id"] == jugador_id
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
	destino.caja["contratos"] = 1000000.0

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


## El contrato cambio con la cesion negociada (core/cesiones.gd): a un
## titular TUYO lo podes ceder —vos decidis sobre los tuyos, y el once lo
## tapa el mejor suplente del puesto—, mientras que al titular AJENO lo
## sigue frenando Prestamos.evaluar_pedido, que es quien contesta cuando
## le pedis prestado a un club de la IA.
func _test_prestamo_rechazo_no_es_banco_ni_cantera(rng: RandomNumberGenerator) -> void:
	print("\n=== Prestamos: al titular propio se lo puede ceder, al ajeno no ===")
	var origen := Team.generar("DuenoTitular", rng, 8000)
	var destino := Team.generar("PrestadorTitular", rng, 9000)
	destino.caja["fichajes"] = 1000000.0
	destino.caja["contratos"] = 1000000.0

	var titular: Dictionary = origen.jugadores[0]
	var jugador_id: int = titular["id"]
	var puesto: String = titular["posicion"]
	var titulares_antes: int = origen.jugadores.size()

	# Al DUEÑO de la IA no se lo sacan: evaluar_pedido dice que no.
	var pedido := Prestamos.evaluar_pedido(origen, titular, 1.0, 0.0, 1.0)
	if pedido["acepta"]:
		print("FALLA: un club de la IA acepto prestar a su titular.")
		return

	var resultado := Prestamos.ceder(origen, destino, jugador_id, 1)
	if not resultado["exito"]:
		print("FALLA: no dejo ceder a un titular propio: %s" % resultado["motivo"])
		return
	for j in origen.jugadores:
		if int(j["id"]) == jugador_id:
			print("FALLA: el cedido sigue en el once del dueño.")
			return
	if origen.jugadores.size() != titulares_antes:
		print("FALLA: el once quedo en %d y no lo tapo nadie." % origen.jugadores.size())
		return
	print("OK: el titular propio (%s) se cede y el once lo tapa un suplente; al ajeno lo frena evaluar_pedido." % puesto)
