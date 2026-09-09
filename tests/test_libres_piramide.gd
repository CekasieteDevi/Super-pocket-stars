extends SceneTree

## Agentes libres con pool UNICO para toda la piramide y fichaje sin
## trueque (ver core/agentes_libres.gd y Piramide.agentes_libres).
## Correr con: godot --headless --script tests/test_libres_piramide.gd

const SEED := 4242

var fallos := 0


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	_test_pool_compartido(rng)
	_test_guardar_y_cargar_no_duplica(rng)
	_test_retiro_por_edad(rng)
	_test_veto_del_club_que_lo_libero(rng)
	_test_la_ia_ficha_del_pool(rng)
	_test_sueldo_no_se_amortigua(rng)
	_test_fichar_sin_lugar(rng)
	_test_la_ia_mira_el_pool_todos_los_dias(rng)
	_test_el_club_lleno_cambia_al_peor(rng)
	_test_el_amargado_sale_a_la_lista(rng)
	_test_el_pool_no_pasa_del_tope(rng)
	_test_no_le_tocan_el_plantel_al_jugador(rng)
	_test_se_ficha_libre_con_el_mercado_cerrado()

	print("FALLOS=%d" % fallos)
	quit()


func _falla(texto: String) -> void:
	print("FALLA: %s" % texto)
	fallos += 1


## Un club de decima ve al que quedo libre en primera.
func _test_pool_compartido(rng: RandomNumberGenerator) -> void:
	print("=== Pool unico para toda la piramide ===")
	var piramide := Piramide.generar(rng)
	var club_primera: Team = piramide.divisiones[0].equipos[0]
	var jugador: Dictionary = club_primera.banco[0]
	var id: int = jugador["id"]

	AgentesLibres.liberar(
		club_primera, jugador, piramide.divisiones[0].agentes_libres, rng)

	var visto_en_decima := false
	for a in piramide.divisiones[9].agentes_libres:
		if int(a["id"]) == id:
			visto_en_decima = true
	if visto_en_decima and piramide.agentes_libres.size() == 1:
		print("OK: el que queda libre en primera lo ve la decima division.")
	else:
		_falla("el pool no es unico: decima lo ve = %s, tamaño = %d" % [
			visto_en_decima, piramide.agentes_libres.size()])


func _test_guardar_y_cargar_no_duplica(rng: RandomNumberGenerator) -> void:
	print("\n=== Guardar y cargar deja un solo pool ===")
	var piramide := Piramide.generar(rng)
	var club: Team = piramide.divisiones[3].equipos[2]
	AgentesLibres.liberar(club, club.banco[0], piramide.agentes_libres, rng)
	AgentesLibres.liberar(club, club.banco[1], piramide.agentes_libres, rng)

	var datos := piramide.guardar()
	var vuelta := Piramide.cargar(JSON.parse_string(JSON.stringify(datos)))

	var compartido := true
	for liga in vuelta.divisiones:
		if liga.agentes_libres != vuelta.agentes_libres:
			compartido = false

	if vuelta.agentes_libres.size() == 2 and compartido:
		print("OK: el pool viaja entero y una sola vez en la partida guardada.")
	else:
		_falla("al cargar quedaron %d libres (esperaba 2), compartido = %s" % [
			vuelta.agentes_libres.size(), compartido])


## El pool se vacia por donde se vacia en la vida real: envejecen y
## cuelgan los botines.
func _test_retiro_por_edad(rng: RandomNumberGenerator) -> void:
	print("
=== Los libres envejecen y se retiran ===")
	var equipo := Team.generar("ClubViejo", rng, 0)
	var pool := []
	AgentesLibres.liberar(equipo, equipo.banco[0], pool, rng)
	pool[0]["edad"] = 25
	var edad_antes: int = int(pool[0]["edad"])

	var retirados := AgentesLibres.envejecer_pool(pool, rng)
	if pool.size() != 1 or not retirados.is_empty():
		_falla("un jugador de %d años se retiro." % edad_antes)
		return
	if int(pool[0]["edad"]) != edad_antes + 1:
		_falla("no envejecio: quedo en %d." % int(pool[0]["edad"]))
		return

	# Uno que ya paso la edad de retiro seguro se va en la primera vuelta.
	pool[0]["edad"] = AgentesLibres.EDAD_RETIRO_SEGURO - 1
	retirados = AgentesLibres.envejecer_pool(pool, rng)
	if not (pool.is_empty() and retirados.size() == 1):
		_falla("a los %d no se retiro: quedan %d en el pool." % [
			AgentesLibres.EDAD_RETIRO_SEGURO, pool.size()])
		return

	# Y el joven que nadie ficha tampoco se queda para siempre: a las
	# TEMPORADAS_SIN_CLUB deja el futbol aunque le sobre edad.
	AgentesLibres.liberar(equipo, equipo.banco[1], pool, rng)
	pool[0]["edad"] = 22
	for i in range(AgentesLibres.TEMPORADAS_SIN_CLUB - 1):
		AgentesLibres.envejecer_pool(pool, rng)
		if pool.is_empty():
			_falla("el joven se fue en la temporada %d." % (i + 1))
			return
		pool[0]["edad"] = 22  # que no lo saque la edad, que lo saque el reloj
	AgentesLibres.envejecer_pool(pool, rng)

	if pool.is_empty():
		print("OK: envejece de a una temporada, a los %d se retira y el que no consigue club se va a las %d." % [
			AgentesLibres.EDAD_RETIRO_SEGURO, AgentesLibres.TEMPORADAS_SIN_CLUB])
	else:
		_falla("el joven sigue en el pool despues de %d temporadas sin club." % AgentesLibres.TEMPORADAS_SIN_CLUB)


## Dejarlo ir y recuperarlo gratis dos dias despues seria un truco para
## bajarle el sueldo a un titular.
func _test_veto_del_club_que_lo_libero(rng: RandomNumberGenerator) -> void:
	print("
=== El club que lo largo no lo puede volver a fichar ===")
	var equipo := Team.generar("ClubArrepentido", rng, 0)
	equipo.caja["contratos"] = 10000000.0
	var pool := []
	var jugador: Dictionary = equipo.banco[2]
	var id: int = jugador["id"]
	AgentesLibres.liberar(equipo, jugador, pool, rng)

	# Se le hace lugar en el plantel para que el rechazo sea por el veto y
	# no por el plantel lleno.
	var suplente: Dictionary = equipo.banco[0]
	equipo.banco.remove_at(0)
	equipo._limpiar_registro(int(suplente["id"]))

	var pide := AgentesLibres.sueldo_libre(jugador, 2)
	var r := AgentesLibres.fichar(equipo, pool, id, 2, pide * 2.0)
	if bool(r.get("exito", false)):
		_falla("se lo volvio a fichar el mismo club que lo largo.")
		return

	# Otro club si puede, y ahi el veto se termina.
	var otro := Team.generar("ClubVecino", rng, 1000)
	otro.caja["contratos"] = 10000000.0
	otro.banco.remove_at(0)
	var del_pool := AgentesLibres.fichar_ia(otro, pool, str(jugador["posicion"]))
	if del_pool.is_empty() or int(del_pool["id"]) != id:
		_falla("el otro club no se lo pudo llevar.")
		return
	if del_pool.has("club_libero"):
		_falla("el veto sobrevivio al fichaje.")
		return
	print("OK: al que dejo ir no lo puede refichar, y otro club si.")


## Los 200 clubes de la piramide se sirven del pool antes de inventar un
## refuerzo de la nada.
func _test_la_ia_ficha_del_pool(rng: RandomNumberGenerator) -> void:
	print("
=== La IA ficha del pool para tapar un vencimiento ===")
	var liga := Liga.new()
	liga.inicializar(["ClubIA", "Otro"], rng, 0)
	var club: Team = liga.equipos[0]
	club.caja["contratos"] = 10000000.0

	# Un crack sin club, del puesto que le va a quedar vacante.
	var saliente: Dictionary = club.jugadores[10]
	var crack := PlayerGenerator.generate(90000, rng, str(saliente["posicion"]), 95)
	crack["media"] = 88.0
	crack["edad"] = 27
	crack["club_libero"] = "Otro"
	liga.agentes_libres.append(crack)

	var salida := AgentesLibres.liberar(
		club, saliente, liga.agentes_libres, rng)

	var entra: Dictionary = salida.get("jugador", {})
	var ok: bool = bool(salida.get("del_pool", false))
	ok = ok and not entra.is_empty() and int(entra["id"]) == int(crack["id"])
	ok = ok and liga.agentes_libres.size() == 1  # queda el que acaba de salir
	ok = ok and int(liga.agentes_libres[0]["id"]) == int(saliente["id"])
	ok = ok and abs(float(club.sueldos.get(int(crack["id"]), 0.0))
		- AgentesLibres.sueldo_libre(crack, AgentesLibres.CONTRATO_LIBRE_ANIOS)) < 0.01

	if ok:
		print("OK: el club de la IA tapa el puesto con el libre y le paga la tabla.")
	else:
		_falla("la IA no ficho del pool: %s" % [salida])


## Un crack sin club pide lo que vale, no lo que pagaria la division del
## club que lo mira: si se amortizara, firmaria por dos pesos en decima.
func _test_sueldo_no_se_amortigua(rng: RandomNumberGenerator) -> void:
	print("\n=== Un libre pide sueldo sin amortiguar por division ===")
	var chico := Team.generar("ClubDecima", rng, 0, -1)
	chico.division_actual = 9
	var crack := PlayerGenerator.generate(50000, rng, "DC", 95)
	crack["media"] = 90.0
	crack["edad"] = 26

	var pide_libre := Renovaciones.sueldo_pretendido(chico, crack, 2)

	# El mismo jugador, pero ya del club: ahi si se amortigua.
	chico.contratos[int(crack["id"])] = 2
	var pide_propio := Renovaciones.sueldo_pretendido(chico, crack, 2)
	chico.contratos.erase(int(crack["id"]))

	if pide_libre > pide_propio:
		print("OK: pide %s de libre contra %s si ya fuera del club." % [
			Economia.formato_dinero(pide_libre), Economia.formato_dinero(pide_propio)])
	else:
		_falla("el libre pide %s y el propio %s: la amortiguacion no se salteo." % [
			Economia.formato_dinero(pide_libre), Economia.formato_dinero(pide_propio)])


func _test_fichar_sin_lugar(rng: RandomNumberGenerator) -> void:
	print("\n=== Fichar un libre suma al plantel, hasta el tope ===")
	var equipo := Team.generar("ClubLleno", rng, 0)
	equipo.caja["contratos"] = 10000000.0
	var pool := []
	var otro := Team.generar("ClubVecino", rng, 1000)
	var agente: Dictionary = otro.banco[0]
	AgentesLibres.liberar(otro, agente, pool, rng)

	# Un club recien generado tiene 18 y el tope son 40: le sobran lugares,
	# asi que el libre entra sin desplazar a nadie.
	var pide := Renovaciones.pide_ahora(equipo, agente, 2)
	var ofrenda := AgentesLibres.fichar(
		equipo, pool, int(agente["id"]), 2, pide * Renovaciones.FRACCION_INSULTO * 0.5)
	if bool(ofrenda.get("exito", false)):
		_falla("ficho con una oferta que ofende.")
		return

	# Se ofendio: no atiende. Se limpia el bloqueo para probar el fichaje
	# en si, que es lo que mide este test.
	equipo.renovaciones.erase(int(agente["id"]))

	var r := AgentesLibres.fichar(equipo, pool, int(agente["id"]), 3, pide * 1.5)
	if not bool(r.get("exito", false)):
		_falla("no ficho: %s" % str(r.get("motivo", "")))
		return

	var ok: bool = equipo.todos_los_jugadores().size() == Team.plantel_de_la_ia() + 1
	ok = ok and pool.is_empty()
	ok = ok and int(equipo.contratos.get(int(agente["id"]), 0)) == 3
	ok = ok and not equipo.renovaciones.has(int(agente["id"]))
	if not ok:
		_falla("plantel %d, pool %d, contrato %d" % [
			equipo.todos_los_jugadores().size(), pool.size(),
			int(equipo.contratos.get(int(agente["id"]), 0))])
		return
	print("OK: entra al banco por 3 años, no sale nadie y el plantel queda en %d." % [
		equipo.todos_los_jugadores().size()])

	# El tope si frena: con 40 no entra nadie mas.
	while equipo.todos_los_jugadores().size() < Team.PLANTEL_MAXIMO:
		equipo.banco.append(PlayerGenerator.generate(
			95000 + equipo.banco.size(), rng, "MC", 50))
	pool.append(PlayerGenerator.generate(96000, rng, "MC", 60))
	var lleno := AgentesLibres.fichar(equipo, pool, 96000, 2, 9999999.0)
	if bool(lleno.get("exito", false)):
		_falla("ficho con el plantel en el tope de %d." % Team.PLANTEL_MAXIMO)
	else:
		print("OK: con %d en el plantel ya no entra nadie." % Team.PLANTEL_MAXIMO)


## Con el pool cargado de cracks, la rueda diaria los coloca. Antes el
## pool solo se movia en el cierre de temporada y con un hueco del mismo
## puesto: un crack sin club se quedaba ahi para siempre.
func _test_la_ia_mira_el_pool_todos_los_dias(rng: RandomNumberGenerator) -> void:
	print("
=== Los clubes miran la lista de libres todos los dias ===")
	var piramide := Piramide.generar(rng)
	var pool: Array = piramide.agentes_libres
	# Piramide.generar deja la caja en cero: los presupuestos los siembra
	# GameState al empezar la partida. Sin plata no ficha nadie y el test
	# mediria eso y no la rueda diaria.
	for liga in piramide.divisiones:
		for club in liga.equipos:
			club.caja["contratos"] = 100000000.0
	# Diez cracks sin club, uno por puesto de la formacion.
	var puestos := Team.FORMACION.duplicate()
	for i in range(10):
		var crack := PlayerGenerator.generate(90000 + i, rng, str(puestos[i % puestos.size()]), 99)
		crack["media"] = 95.0
		pool.append(crack)

	var antes := pool.size()
	var hechos := AgentesLibres.ronda_diaria(piramide, rng, 30, null)
	var quedan := 0
	for a in pool:
		if float(a["media"]) >= 95.0:
			quedan += 1
	if hechos.size() > 0 and quedan == 0:
		print("OK: %d fichajes en 30 dias y ningun crack quedo libre (pool %d -> %d)." % [
			hechos.size(), antes, pool.size()])
	else:
		_falla("%d fichajes, quedaron %d cracks libres." % [hechos.size(), quedan])


## El club completo no se queda afuera: cambia al peor de ese puesto.
func _test_el_club_lleno_cambia_al_peor(rng: RandomNumberGenerator) -> void:
	print("
=== Un club completo cambia al peor de ese puesto ===")
	var equipo := Team.generar("ClubCompleto", rng, 0)
	equipo.caja["contratos"] = 100000000.0
	var pool := []
	var crack := PlayerGenerator.generate(91000, rng, "DC", 99)
	crack["media"] = 95.0
	pool.append(crack)

	# El peor DC del club, que es a quien tiene que largar.
	var peor := {}
	for j in equipo.jugadores + equipo.banco:
		if str(j["posicion"]) != "DC":
			continue
		if peor.is_empty() or float(j["media"]) < float(peor["media"]):
			peor = j
	if peor.is_empty():
		print("OK (sin DC en este plantel, nada que medir).")
		return

	var ficha := AgentesLibres._mirar_el_pool(equipo, pool)
	var entro := false
	for j in equipo.jugadores + equipo.banco:
		if int(j["id"]) == 91000:
			entro = true
	var salio := pool.size() == 1 and int(pool[0]["id"]) == int(peor["id"])
	# El club de la IA no acumula: mantiene su once y su banco
	# (Team.plantel_de_la_ia), aunque el tope legal sean 40.
	var plantel_ok: bool = equipo.todos_los_jugadores().size() == Team.plantel_de_la_ia()
	if not ficha.is_empty() and entro and salio and plantel_ok:
		print("OK: entra el de 95.0 y sale el DC de %.1f. El plantel sigue en %d." % [
			float(peor["media"]), Team.plantel_de_la_ia()])
	else:
		print("FALLA: ficha=%s entro=%s salio=%s plantel=%d" % [
			ficha.is_empty(), entro, salio, equipo.todos_los_jugadores().size()])
		fallos += 1


## Sin esto la lista solo se llena una vez al año y entre cierre y cierre
## no aparece nada que valga la pena mirar.
func _test_el_amargado_sale_a_la_lista(rng: RandomNumberGenerator) -> void:
	print("
=== El suplente amargado se va libre solo ===")
	var equipo := Team.generar("ClubAmargo", rng, 0)
	var suplente: Dictionary = equipo.banco[0]
	var id := int(suplente["id"])
	equipo.animo[id] = AgentesLibres.ANIMO_DE_RUPTURA - 1.0
	var pool := []

	AgentesLibres._soltar_amargado(equipo, pool, rng)
	var esta_en_pool: bool = pool.size() == 1 and int(pool[0]["id"]) == id
	var fuera_del_banco := true
	for j in equipo.banco:
		if int(j["id"]) == id:
			fuera_del_banco = false
	# Y no se lo puede volver a fichar: se fue peleado.
	if esta_en_pool and fuera_del_banco and AgentesLibres.veta_a(equipo, pool[0]):
		print("OK: sale del banco, entra a la lista y su club no lo puede refichar.")
	else:
		_falla("pool=%d fuera=%s" % [pool.size(), fuera_del_banco])


## La lista tiene tope: sin el, la rueda diaria la hacia crecer sin freno
## y la partida guardada engordaba (440 -> 1232 en tres temporadas).
func _test_el_pool_no_pasa_del_tope(rng: RandomNumberGenerator) -> void:
	print("
=== La lista de libres tiene tope ===")
	var piramide := Piramide.generar(rng)
	var pool: Array = piramide.agentes_libres
	for i in range(AgentesLibres.TOPE_POOL + 200):
		var j := PlayerGenerator.generate(92000 + i, rng, "MC", 40)
		j["media"] = 20.0 + float(i % 30)
		pool.append(j)

	AgentesLibres.ronda_diaria(piramide, rng, 1, null)
	var peor := 100.0
	for a in pool:
		peor = minf(peor, float(a["media"]))
	if pool.size() <= AgentesLibres.TOPE_POOL and peor > 20.0:
		print("OK: %d libres (tope %d) y los de menor media son los que se van." % [
			pool.size(), AgentesLibres.TOPE_POOL])
	else:
		_falla("pool=%d peor=%.1f" % [pool.size(), peor])


## Al club del jugador humano no le tocan el plantel: sus fichajes los
## decide el.
func _test_no_le_tocan_el_plantel_al_jugador(rng: RandomNumberGenerator) -> void:
	print("
=== Nadie le mueve el plantel al jugador ===")
	var piramide := Piramide.generar(rng)
	var mio: Team = piramide.divisiones[0].equipos[0]
	mio.caja["contratos"] = 100000000.0
	for j in mio.banco:
		mio.animo[int(j["id"])] = 0.0
	var pool: Array = piramide.agentes_libres
	for i in range(20):
		var crack := PlayerGenerator.generate(93000 + i, rng, "MC", 99)
		crack["media"] = 99.0
		pool.append(crack)

	var antes := []
	for j in mio.todos_los_jugadores():
		antes.append(int(j["id"]))
	AgentesLibres.ronda_diaria(piramide, rng, 20, mio)
	var ahora := []
	for j in mio.todos_los_jugadores():
		ahora.append(int(j["id"]))
	if antes == ahora:
		print("OK: los %d del plantel del jugador siguen todos." % antes.size())
	else:
		_falla("el plantel del jugador cambio: %d -> %d" % [antes.size(), ahora.size()])


## Un jugador sin club no es una transferencia: no hay club vendedor ni
## fee, asi que el libro de pases no lo regula. Antes se rechazaba con el
## mercado cerrado igual que una compra.
func _test_se_ficha_libre_con_el_mercado_cerrado() -> void:
	print("
=== Un libre se ficha con el mercado cerrado ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var piramide := Piramide.generar(rng)
	# GameState es autoload y en un --script no existe: se instancia a
	# mano y no se agrega al arbol (su _ready cargaria la partida real).
	var gs = load("res://game/game_state.gd").new()
	gs.piramide = piramide
	gs.rng = rng
	gs.temporada_actual = 1
	gs.division_jugador = 4
	gs.equipo_jugador = piramide.divisiones[4].equipos[0]
	gs._sembrar_presupuestos()
	var mio: Team = gs.equipo_jugador
	mio.caja["contratos"] = 100000000.0

	# Un dia con el libro de pases CERRADO.
	var dia := 0
	while dia < 400 and Calendario.hay_mercado(dia):
		dia += 1
	gs.dia_absoluto = dia

	# Lugar en el plantel: sin un hueco no entra nadie, con mercado o sin el.
	var suplente: Dictionary = mio.banco[0]
	mio.banco.remove_at(0)
	mio._limpiar_registro(int(suplente["id"]))

	var agente := PlayerGenerator.generate(94000, rng, "MC", 70)
	piramide.agentes_libres.append(agente)
	var pide := Renovaciones.pide_ahora(mio, agente, 2)

	var r: Dictionary = gs.fichar_agente_libre(94000, 2, pide * 1.5)
	var esta := false
	for j in mio.todos_los_jugadores():
		if int(j["id"]) == 94000:
			esta = true
	if bool(r.get("exito", false)) and esta and not gs.hay_mercado_abierto():
		print("OK: ficho un libre con el libro de pases cerrado.")
	else:
		_falla("exito=%s esta=%s mercado_abierto=%s motivo=%s" % [
			r.get("exito", false), esta, gs.hay_mercado_abierto(),
			str(r.get("motivo", ""))])
	gs.free()
