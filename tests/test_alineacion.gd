extends SceneTree

## Alineacion (core/alineacion.gd): que nadie salga a la cancha lesionado
## ni suspendido.
##
## Antes no lo miraba nadie: reset_partido() mandaba a los once titulares
## sin preguntar, el lesionado jugaba, y recien lo sacaban en la primera
## ventana de cambios.

const SEED := 5150


func _init() -> void:
	var fallas := 0
	fallas += _test_detecta_lesionados_y_suspendidos()
	fallas += _test_solo_mira_titulares()
	fallas += _test_el_reemplazo_es_de_la_misma_posicion()
	fallas += _test_arreglar_deja_el_once_sano()
	fallas += _test_sin_suplente_sano()
	fallas += _test_no_toma_dos_veces_al_mismo()
	fallas += _test_la_liga_arregla_sola()
	fallas += _test_texto_corto_distingue_los_tres_motivos()
	fallas += _test_acomodar_devuelve_cada_uno_a_su_puesto()
	fallas += _test_acomodar_no_toca_un_once_sano()
	fallas += _test_sin_del_puesto_elige_con_el_castigo()
	fallas += _test_la_ia_ficha_el_puesto_que_le_falta()
	print("FALLOS=%d" % fallas)
	quit()


func _equipo() -> Team:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	return Team.generar("Prueba", rng, 0)


func _test_detecta_lesionados_y_suspendidos() -> int:
	var fallas := 0
	var equipo := _equipo()
	if Alineacion.hay_problema(equipo):
		print("FALLA: un plantel recien generado ya tiene titulares indisponibles.")
		fallas += 1

	var lesionado := int(equipo.jugadores[3]["id"])
	var suspendido := int(equipo.jugadores[7]["id"])
	equipo.lesionar(lesionado, "desgarro", 20)
	equipo.suspendidos[suspendido] = 1

	var lista := Alineacion.indisponibles(equipo)
	if lista.size() != 2:
		print("FALLA: detecto %d indisponibles y tendrian que ser 2." % lista.size())
		fallas += 1
	if Alineacion.motivo(equipo, lesionado) != Alineacion.LESIONADO:
		print("FALLA: no reconoce al lesionado.")
		fallas += 1
	if Alineacion.motivo(equipo, suspendido) != Alineacion.SUSPENDIDO:
		print("FALLA: no reconoce al suspendido.")
		fallas += 1
	if not Alineacion.texto_motivo(equipo, suspendido).contains("1 fecha"):
		print("FALLA: el texto del suspendido no dice las fechas (%s)." % Alineacion.texto_motivo(equipo, suspendido))
		fallas += 1
	if fallas == 0:
		print("OK: detecta lesionados y suspendidos, y explica por que (%s / %s)." % [
			Alineacion.texto_motivo(equipo, lesionado),
			Alineacion.texto_motivo(equipo, suspendido)])
	return fallas


func _test_solo_mira_titulares() -> int:
	var equipo := _equipo()
	# Un suplente roto no molesta a nadie: no iba a entrar igual.
	equipo.lesionar(int(equipo.banco[0]["id"]), "esguince", 15)
	if Alineacion.hay_problema(equipo):
		print("FALLA: un suplente lesionado dispara el aviso.")
		return 1
	print("OK: un suplente lesionado no dispara el aviso, solo cuentan los titulares.")
	return 0


func _test_el_reemplazo_es_de_la_misma_posicion() -> int:
	var fallas := 0
	var equipo := _equipo()
	# Se busca un titular que TENGA suplente de su posicion.
	var elegido := {}
	for j in equipo.jugadores:
		for s in equipo.banco:
			if str(s["posicion"]) == str(j["posicion"]):
				elegido = j
				break
		if not elegido.is_empty():
			break
	if elegido.is_empty():
		print("FALLA: el plantel no tiene ningun suplente que comparta puesto con un titular.")
		return 1

	equipo.lesionar(int(elegido["id"]), "desgarro", 20)
	var pasos := Alineacion.plan(equipo)
	if pasos.size() != 1 or pasos[0]["entra"].is_empty():
		print("FALLA: no encontro reemplazo.")
		return 1
	if str(pasos[0]["entra"]["posicion"]) != str(elegido["posicion"]):
		print("FALLA: reemplazo un %s con un %s habiendo del mismo puesto." % [
			elegido["posicion"], pasos[0]["entra"]["posicion"]])
		fallas += 1
	# Y de los de su puesto, el mejor.
	var mejor := -1.0
	for s in equipo.banco:
		if str(s["posicion"]) == str(elegido["posicion"]) and equipo.puede_jugar(int(s["id"])):
			mejor = maxf(mejor, float(s["media"]))
	if absf(float(pasos[0]["entra"]["media"]) - mejor) > 0.01:
		print("FALLA: no eligio al mejor suplente de esa posicion.")
		fallas += 1
	if fallas == 0:
		print("OK: entra el mejor suplente sano del mismo puesto.")
	return fallas


func _test_arreglar_deja_el_once_sano() -> int:
	var fallas := 0
	var equipo := _equipo()
	equipo.lesionar(int(equipo.jugadores[2]["id"]), "desgarro", 20)
	equipo.suspendidos[int(equipo.jugadores[5]["id"])] = 2
	var antes := equipo.jugadores.size()

	var hechos := Alineacion.arreglar(equipo)
	if hechos.size() != 2:
		print("FALLA: arreglo %d de 2." % hechos.size())
		fallas += 1
	if Alineacion.hay_problema(equipo):
		print("FALLA: despues de arreglar sigue habiendo titulares que no pueden jugar.")
		fallas += 1
	if equipo.jugadores.size() != antes:
		print("FALLA: el once quedo con %d jugadores." % equipo.jugadores.size())
		fallas += 1
	# Los que salieron tienen que estar en el banco, no desaparecidos.
	for paso in hechos:
		var sigue := false
		for s in equipo.banco:
			if int(s["id"]) == int(paso["sale"]["id"]):
				sigue = true
		if not sigue:
			print("FALLA: %s se perdio del plantel." % paso["sale"]["apellido"])
			fallas += 1
	if fallas == 0:
		print("OK: se cambian los dos, el once queda sano y los que salen van al banco.")
	return fallas


func _test_sin_suplente_sano() -> int:
	var fallas := 0
	var equipo := _equipo()
	# Se rompe medio plantel: un titular y TODO el banco.
	equipo.lesionar(int(equipo.jugadores[0]["id"]), "rotura", 90)
	for s in equipo.banco:
		equipo.lesionar(int(s["id"]), "rotura", 90)

	if Alineacion.sin_cubrir(equipo) != 1:
		print("FALLA: deberia quedar 1 titular sin cubrir y quedaron %d." % Alineacion.sin_cubrir(equipo))
		fallas += 1
	var hechos := Alineacion.arreglar(equipo)
	if not hechos.is_empty():
		print("FALLA: cambio a alguien sin tener suplentes sanos.")
		fallas += 1
	# El once sigue teniendo once: sacarlo por sacarlo lo dejaria con diez.
	if equipo.jugadores.size() != 11:
		print("FALLA: el once quedo con %d." % equipo.jugadores.size())
		fallas += 1
	if fallas == 0:
		print("OK: sin suplentes sanos no se toca nada y el once sigue siendo de once.")
	return fallas


func _test_no_toma_dos_veces_al_mismo() -> int:
	var fallas := 0
	var equipo := _equipo()
	# Dos titulares del MISMO puesto rotos: el mejor suplente de ese
	# puesto no puede entrar por los dos.
	var puesto := ""
	var ids := []
	for j in equipo.jugadores:
		var cuantos := 0
		for k in equipo.jugadores:
			if str(k["posicion"]) == str(j["posicion"]):
				cuantos += 1
		if cuantos >= 2:
			puesto = str(j["posicion"])
			break
	for j in equipo.jugadores:
		if str(j["posicion"]) == puesto and ids.size() < 2:
			ids.append(int(j["id"]))
	for id in ids:
		equipo.lesionar(id, "desgarro", 20)

	var pasos := Alineacion.plan(equipo)
	var entrantes := []
	for paso in pasos:
		if paso["entra"].is_empty():
			continue
		var id := int(paso["entra"]["id"])
		if entrantes.has(id):
			print("FALLA: el mismo suplente entra por dos titulares.")
			fallas += 1
		entrantes.append(id)
	Alineacion.arreglar(equipo)
	if Alineacion.hay_problema(equipo):
		print("FALLA: quedaron titulares rotos despues de arreglar.")
		fallas += 1
	if fallas == 0:
		print("OK: dos bajas del mismo puesto entran dos suplentes distintos.")
	return fallas


## La red de la liga: aunque nadie mire, ningun club sale con lesionados.
func _test_la_liga_arregla_sola() -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var liga := Liga.new()
	var nombres := []
	for i in range(20):
		nombres.append("Club %d" % i)
	liga.inicializar(nombres, rng, 0, 5)

	# Se rompe un titular en cada club y se anota quien es. Se anota
	# tambien si ese club TENIA con quien reemplazarlo: el que no tiene
	# suplente sano se queda con el roto, y eso es lo correcto.
	var rotos := {}
	var reemplazables := {}
	for e in liga.equipos:
		var id := int(e.jugadores[4]["id"])
		e.lesionar(id, "desgarro", 30)
		rotos[e.nombre] = id
		reemplazables[e.nombre] = Alineacion.sin_cubrir(e) == 0

	liga.jugar_fecha(0, rng, null)

	var quedaron := []
	var cubribles := 0
	for e in liga.equipos:
		if not bool(reemplazables[e.nombre]):
			continue
		cubribles += 1
		for j in e.jugadores:
			if int(j["id"]) == int(rotos[e.nombre]):
				quedaron.append(e.nombre)
	if cubribles == 0:
		print("FALLA: ningun club tenia suplente; la prueba no prueba nada.")
		return 1
	if not quedaron.is_empty():
		print("FALLA: %d de %d clubes salieron con el lesionado en el once (%s)." % [
			quedaron.size(), cubribles, str(quedaron)])
		return 1
	print("OK: los %d clubes con suplente sano sacaron al lesionado del once solos." % cubribles)
	return 0


## El texto corto es lo unico que se lee en el cubo de la pantalla de
## Formacion: si el suspendido y el lesionado dijeran lo mismo, la
## pantalla no serviria para elegir a quien cambiar.
func _test_texto_corto_distingue_los_tres_motivos() -> int:
	var fallas := 0
	var equipo := _equipo()
	var sano := int(equipo.jugadores[0]["id"])
	var lesionado := int(equipo.jugadores[1]["id"])
	var suspendido := int(equipo.jugadores[2]["id"])
	var expulsado := int(equipo.jugadores[3]["id"])
	equipo.lesionar(lesionado, "desgarro", 12)
	equipo.suspendidos[suspendido] = 2
	equipo.expulsados_partido[expulsado] = true

	var textos := {
		sano: "",
		lesionado: "Lesión 12 d",
		suspendido: "Susp. 2 f",
		expulsado: "Expulsado",
	}
	for id in textos:
		var visto := Alineacion.texto_motivo_corto(equipo, int(id))
		if visto != str(textos[id]):
			print("FALLA: texto corto de %d dice \"%s\" y esperaba \"%s\"." % [
				id, visto, str(textos[id])])
			fallas += 1
	if fallas == 0:
		print("OK: el texto corto distingue lesión, suspensión y expulsión.")
	return fallas


## Un once con el arquero de 9 y el 9 al arco: acomodar los devuelve.
func _test_acomodar_devuelve_cada_uno_a_su_puesto() -> int:
	var equipo := _equipo()
	var roles: Array = Formaciones.roles_compartidos(equipo.formacion)
	var ultimo := equipo.jugadores.size() - 1
	var tmp: Dictionary = equipo.jugadores[0]
	equipo.jugadores[0] = equipo.jugadores[ultimo]
	equipo.jugadores[ultimo] = tmp
	if not Alineacion.acomodar(equipo):
		print("FALLA: acomodar no cambio un once con el arquero de delantero.")
		return 1
	for i in range(roles.size()):
		if str(equipo.jugadores[i]["posicion"]) != str(roles[i]):
			print("FALLA: el slot %d (%s) quedo con un %s." % [
				i, roles[i], equipo.jugadores[i]["posicion"]])
			return 1
	print("OK: acomodar devuelve al arquero al arco y al 9 adelante.")
	return 0


func _test_acomodar_no_toca_un_once_sano() -> int:
	var equipo := _equipo()
	var antes := equipo.jugadores.map(func(j): return int(j["id"]))
	var banco_antes := equipo.banco.map(func(j): return int(j["id"]))
	if Alineacion.acomodar(equipo) 			or antes != equipo.jugadores.map(func(j): return int(j["id"])) 			or banco_antes != equipo.banco.map(func(j): return int(j["id"])):
		print("FALLA: acomodar movio a alguien en un plantel recien generado.")
		return 1
	print("OK: acomodar deja igual un once que ya calza con su formacion.")
	return 0


## Sin arquero sano, el arco lo ocupa el que menos pierde. Un arquero de
## campo cuesta el maximo (Puestos.MAXIMO), asi que ningun arquero
## suplente puede ganarle un puesto de campo a uno de campo parecido.
func _test_sin_del_puesto_elige_con_el_castigo() -> int:
	var equipo := _equipo()
	var arq: Dictionary = {}
	var ext: Dictionary = {}
	for s in equipo.banco:
		if str(s["posicion"]) == "ARQ" and arq.is_empty():
			arq = s
		if str(s["posicion"]) == "EXT" and ext.is_empty():
			ext = s
	if arq.is_empty() or ext.is_empty():
		print("FALLA: el banco generado no tiene arquero y extremo; la prueba no prueba nada.")
		return 1
	# Mismos atributos y sin Adaptable (cancela el castigo): solo el
	# castigo los separa.
	arq["atributos"] = ext["atributos"].duplicate()
	arq["personalidades"] = {}
	ext["personalidades"] = {}
	var fuera := Alineacion.rinde_en(arq, "MC")
	var cerca := Alineacion.rinde_en(ext, "MC")
	if fuera >= cerca:
		print("FALLA: con los mismos atributos, el arquero rinde de volante %.1f y el extremo %.1f." % [fuera, cerca])
		return 1
	print("OK: con los mismos atributos, el extremo rinde mas de volante (%.1f) que el arquero (%.1f)." % [cerca, fuera])
	return 0


## Un club sin arquero suplente lo sale a buscar al pool.
func _test_la_ia_ficha_el_puesto_que_le_falta() -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var equipo := _equipo()
	equipo.caja["contratos"] = 1.0e9
	var libre := PlayerGenerator.generate(999001, rng, "ARQ")
	var pool := [libre]
	# El arquero suplente pasa a ser un DC: le sobra un DC y le falta un ARQ.
	for i in range(equipo.banco.size()):
		if str(equipo.banco[i]["posicion"]) == "ARQ":
			equipo.banco[i]["posicion"] = "DC"
	var ficha := AgentesLibres.cubrir_faltante(equipo, pool)
	if ficha.is_empty() or int(ficha["entra"]["id"]) != 999001:
		print("FALLA: el club sin arquero suplente no ficho al arquero libre.")
		return 1
	if ficha["sale"].is_empty() or str(ficha["sale"]["posicion"]) != "DC":
		print("FALLA: para hacerle lugar tenia que irse el DC que sobra.")
		return 1
	if not AgentesLibres.cubrir_faltante(equipo, pool).is_empty():
		print("FALLA: con el plantel ya completo, el club siguio fichando.")
		return 1
	print("OK: el club sin arquero suplente ficha uno y larga al DC que le sobra.")
	return 0
