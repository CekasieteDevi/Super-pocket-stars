extends SceneTree

## Roles (core/roles.gd): quien patea que y quien lleva la cinta.
##
## El caso que origino todo: el penal lo pateaba el jugador con mas
## `tiro` de los once en cancha, y el arquero entraba en esa comparacion.
## Se veia al golero caminando hasta el punto del penal.

const SEED := 4477


func _init() -> void:
	var fallas := 0
	fallas += _test_el_arquero_no_patea()
	fallas += _test_automatico_por_atributo()
	fallas += _test_eleccion_del_club()
	fallas += _test_el_elegido_pierde_el_puesto()
	fallas += _test_ejecutor_mira_la_cancha()
	fallas += _test_capitan()
	fallas += _test_guardado()
	print("FALLOS=%d" % fallas)
	quit()


func _equipo() -> Team:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	return Team.generar("Prueba", rng, 0)


func _por_id(equipo: Team, id: int) -> Dictionary:
	for j in equipo.todos_los_jugadores():
		if int(j["id"]) == id:
			return j
	return {}


func _arquero_id(equipo: Team) -> int:
	for j in equipo.todos_los_jugadores():
		if str(j["posicion"]) == "ARQ":
			return int(j["id"])
	return -1


func _test_el_arquero_no_patea() -> int:
	var fallas := 0
	var equipo := _equipo()
	var arq := _arquero_id(equipo)
	if arq == -1:
		print("FALLA: el plantel generado no tiene arquero.")
		return 1

	# Se le pone al arquero el mejor `tiro` del plantel, que es
	# exactamente el caso que hacia que pateara el penal.
	var maximo := 0.0
	for j in equipo.todos_los_jugadores():
		maximo = maxf(maximo, float(j["atributos"]["tiro"]))
	_por_id(equipo, arq)["atributos"]["tiro"] = maximo + 20.0

	for clave in [Roles.PENALES, Roles.CORNERS, Roles.LIBRES_CERCA, Roles.LIBRES_LEJOS]:
		if Roles.automatico(equipo, clave) == arq:
			print("FALLA: el arquero quedo de %s en automatico." % Roles.NOMBRE[clave])
			fallas += 1
		for c in Roles.candidatos(equipo, clave):
			if int(c["id"]) == arq:
				print("FALLA: el arquero aparece entre los candidatos de %s." % Roles.NOMBRE[clave])
				fallas += 1
				break
		# Y tampoco se lo puede forzar a mano.
		Roles.asignar(equipo, clave, arq)
		if Roles.resolver(equipo, clave) == arq:
			print("FALLA: se pudo poner al arquero de %s a mano." % Roles.NOMBRE[clave])
			fallas += 1
		Roles.asignar(equipo, clave, Roles.AUTOMATICO)

	# La cinta si: un arquero capitan es de lo mas normal.
	Roles.asignar(equipo, Roles.CAPITAN, arq)
	if Roles.resolver(equipo, Roles.CAPITAN) != arq:
		print("FALLA: no se pudo hacer capitan al arquero.")
		fallas += 1
	Roles.asignar(equipo, Roles.CAPITAN, Roles.AUTOMATICO)

	if fallas == 0:
		print("OK: con el mejor tiro del plantel, el arquero no patea nada y si puede ser capitan.")
	return fallas


func _test_automatico_por_atributo() -> int:
	var fallas := 0
	var equipo := _equipo()
	var esperado := {
		Roles.PENALES: "tiro", Roles.CORNERS: "centros",
		Roles.LIBRES_CERCA: "tiros_libres", Roles.LIBRES_LEJOS: "centros",
	}
	for clave in esperado:
		var elegido := Roles.automatico(equipo, clave)
		var atributo: String = esperado[clave]
		var mejor := -1.0
		for j in equipo.todos_los_jugadores():
			if str(j["posicion"]) == "ARQ":
				continue
			mejor = maxf(mejor, float(j["atributos"][atributo]))
		if absf(float(_por_id(equipo, elegido)["atributos"][atributo]) - mejor) > 0.01:
			print("FALLA: %s no eligio al mejor en %s." % [Roles.NOMBRE[clave], atributo])
			fallas += 1
	if fallas == 0:
		print("OK: cada rol en automatico toma al mejor de su atributo, sin el arquero.")
	return fallas


func _test_eleccion_del_club() -> int:
	var fallas := 0
	var equipo := _equipo()
	# Uno cualquiera que NO sea el automatico.
	var automatico := Roles.automatico(equipo, Roles.PENALES)
	var otro := -1
	for j in Roles.candidatos(equipo, Roles.PENALES):
		if int(j["id"]) != automatico:
			otro = int(j["id"])
			break

	Roles.asignar(equipo, Roles.PENALES, otro)
	if Roles.resolver(equipo, Roles.PENALES) != otro:
		print("FALLA: la eleccion del club no se respeta.")
		fallas += 1
	if Roles.elegido(equipo, Roles.PENALES) != otro:
		print("FALLA: no quedo guardado a quien eligio el club.")
		fallas += 1

	# Y se puede volver atras.
	Roles.asignar(equipo, Roles.PENALES, Roles.AUTOMATICO)
	if Roles.resolver(equipo, Roles.PENALES) != automatico:
		print("FALLA: volver a automatico no devuelve el rol al mejor del plantel.")
		fallas += 1
	if fallas == 0:
		print("OK: el club elige, se guarda, y se puede volver a automatico.")
	return fallas


func _test_el_elegido_pierde_el_puesto() -> int:
	var fallas := 0
	var equipo := _equipo()
	var automatico := Roles.automatico(equipo, Roles.CORNERS)
	var otro := -1
	for j in Roles.candidatos(equipo, Roles.CORNERS):
		if int(j["id"]) != automatico:
			otro = int(j["id"])
			break
	Roles.asignar(equipo, Roles.CORNERS, otro)

	# Lesionado: no patea. De nada sirve un pateador que esta tres meses
	# afuera.
	equipo.lesiones[otro] = {"tipo": "prueba", "dias_restantes": 40}
	if Roles.resolver(equipo, Roles.CORNERS) != automatico:
		print("FALLA: un lesionado sigue ocupando el rol.")
		fallas += 1
	equipo.lesiones.erase(otro)

	# Suspendido: tampoco.
	equipo.suspendidos[otro] = 2
	if Roles.resolver(equipo, Roles.CORNERS) != automatico:
		print("FALLA: un suspendido sigue ocupando el rol.")
		fallas += 1
	equipo.suspendidos.erase(otro)

	# Y si se va del club, la eleccion se limpia sola.
	for i in range(equipo.jugadores.size()):
		if int(equipo.jugadores[i]["id"]) == otro:
			equipo.jugadores.remove_at(i)
			break
	for i in range(equipo.banco.size()):
		if int(equipo.banco[i]["id"]) == otro:
			equipo.banco.remove_at(i)
			break
	equipo.recalcular_capitan()
	if Roles.elegido(equipo, Roles.CORNERS) != Roles.AUTOMATICO:
		print("FALLA: se vendio al jugador y el rol lo sigue apuntando.")
		fallas += 1
	if fallas == 0:
		print("OK: lesion, suspension y venta le sacan el rol al elegido.")
	return fallas


func _test_ejecutor_mira_la_cancha() -> int:
	var fallas := 0
	var equipo := _equipo()
	equipo.reset_partido()
	var candidatos := Roles.candidatos(equipo, Roles.PENALES)
	var designado := int(candidatos[0]["id"])
	Roles.asignar(equipo, Roles.PENALES, designado)

	if Roles.ejecutor(equipo, Roles.PENALES, equipo.en_cancha) != designado 			and equipo.en_cancha.has(designado):
		print("FALLA: el designado esta en cancha y no patea.")
		fallas += 1

	# Lo sacan: patea otro, y ese otro tiene que estar jugando.
	var en_cancha: Array = equipo.en_cancha.duplicate()
	en_cancha.erase(designado)
	var sustituto := Roles.ejecutor(equipo, Roles.PENALES, en_cancha)
	if sustituto == designado:
		print("FALLA: patea alguien que no esta en la cancha.")
		fallas += 1
	if not en_cancha.has(sustituto):
		print("FALLA: el sustituto tampoco esta en la cancha.")
		fallas += 1
	if fallas == 0:
		print("OK: si al designado lo cambian o lo expulsan, patea otro de los que juegan.")
	return fallas


func _test_capitan() -> int:
	var fallas := 0
	var equipo := _equipo()
	var automatico := equipo.capitan_id

	var otro := -1
	for j in equipo.jugadores:
		if int(j["id"]) != automatico:
			otro = int(j["id"])
			break
	Roles.asignar(equipo, Roles.CAPITAN, otro)
	# capitan_id es lo que lee MatchEngine para el +2 de bloque B: tiene
	# que quedar sincronizado con la eleccion, no solo el diccionario.
	if equipo.capitan_id != otro:
		print("FALLA: elegir capitan no actualizo capitan_id (%d)." % equipo.capitan_id)
		fallas += 1
	equipo.recalcular_capitan()
	if equipo.capitan_id != otro:
		print("FALLA: recalcular_capitan piso la eleccion del club.")
		fallas += 1

	Roles.asignar(equipo, Roles.CAPITAN, Roles.AUTOMATICO)
	if equipo.capitan_id != automatico:
		print("FALLA: volver a automatico no devuelve la cinta al de mas media.")
		fallas += 1
	if fallas == 0:
		print("OK: la cinta sigue la eleccion del club y vuelve al de mas media en automatico.")
	return fallas


func _test_guardado() -> int:
	var fallas := 0
	var equipo := _equipo()
	var candidatos := Roles.candidatos(equipo, Roles.LIBRES_CERCA)
	var elegido := int(candidatos[2]["id"])
	Roles.asignar(equipo, Roles.LIBRES_CERCA, elegido)

	var cargado := Team.cargar(JSON.parse_string(JSON.stringify(equipo.guardar())))
	if Roles.elegido(cargado, Roles.LIBRES_CERCA) != elegido:
		print("FALLA: el rol no sobrevivio el guardar/cargar (%d)." % Roles.elegido(cargado, Roles.LIBRES_CERCA))
		fallas += 1
	if typeof(cargado.roles[Roles.LIBRES_CERCA]) != TYPE_INT:
		print("FALLA: el id del rol volvio como float.")
		fallas += 1

	# Una partida vieja no trae la clave: todo en automatico, que es como
	# se comportaba antes de que existieran los roles.
	var datos := equipo.guardar()
	datos.erase("roles")
	var viejo := Team.cargar(JSON.parse_string(JSON.stringify(datos)))
	for clave in Roles.CLAVES:
		if Roles.elegido(viejo, clave) != Roles.AUTOMATICO:
			print("FALLA: una partida sin roles carga con %s asignado." % clave)
			fallas += 1
	if fallas == 0:
		print("OK: los roles se guardan como enteros y una partida vieja arranca en automatico.")
	return fallas
