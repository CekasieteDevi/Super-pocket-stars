extends SceneTree

## El feed de noticias: que cada solapa se llene, que los jugadores que se
## nombran queden enganchados por id, y que el cierre de temporada no se
## coma las categorias chicas.

const SEED := 5150


func _init() -> void:
	var fallas := 0

	# --- Clasificacion de las que llegan como texto pelado ----------------
	var casos := {
		"Facundo Perez (DC, Rampla) se lesiona: rotura, 40 dias afuera.": "lesiones",
		"COPA NACIONAL: campeón Racing Alborada.": "campeones",
		"FICHAJES: Juan Lopez (MC) pasa de A a B por $10,000.": "fichajes",
		"Rumor: X pregunto por Y.": "rumores",
		"QUIEBRA: Deportivo X entró en números rojos.": "club",
	}
	for texto in casos:
		var esperada: String = casos[texto]
		var dio := Noticias.clasificar(texto)
		if dio != esperada:
			print("FALLA: \"%s\" se clasifico como %s y no como %s." % [texto, dio, esperada])
			fallas += 1
	print("OK: las %d clasificaciones de referencia dan lo esperado." % casos.size())

	# Una partida vieja guarda Strings pelados: no se pueden perder.
	var vieja := Noticias.normalizar("COPA DIVISIÓN 3: campeón Racing.")
	if str(vieja["texto"]).begins_with("COPA") and str(vieja["cat"]) == "campeones":
		print("OK: una noticia vieja (String) se envuelve y se clasifica sola.")
	else:
		print("FALLA: no se pudo normalizar una noticia vieja: %s" % [vieja])
		fallas += 1

	# --- Una temporada entera --------------------------------------------
	# El autoload GameState no existe en modo --script, asi que se
	# instancia el script a mano. SIN meterlo en el arbol: _ready() carga
	# la partida guardada del usuario, y este test no la tiene que tocar.
	var GameState = load("res://game/game_state.gd").new()
	GameState.partida_nueva(SEED, "Club Prueba")
	var dias := 0
	while GameState.temporada_actual == 1 and dias < 500:
		dias += 1
		if GameState.hay_partido_hoy():
			GameState.jugar_siguiente_fecha()
		elif GameState.hay_partido_de_copa_hoy():
			# La ronda de copa frena el calendario para que el jugador la
			# juegue. Sin pantalla se resuelve sola.
			GameState.resolver_ronda_de_copa()
		else:
			GameState.avanzar_un_dia()

	var por_cat := {}
	for n in GameState.noticias:
		var c := str(n.get("cat", ""))
		por_cat[c] = int(por_cat.get(c, 0)) + 1
	print("noticias por categoria: %s" % [por_cat])

	for cat in ["rumores", "fichajes", "lesiones", "campeones"]:
		if int(por_cat.get(cat, 0)) > 0:
			print("OK: la solapa %s tiene %d noticias." % [cat, int(por_cat[cat])])
		else:
			print("FALLA: la solapa %s quedo vacia despues de una temporada entera." % cat)
			fallas += 1

	# El tope por categoria: ninguna puede pasarse, y el cierre de
	# temporada no puede vaciar a las demas.
	var paso := false
	for cat in por_cat:
		if int(por_cat[cat]) > GameState.MAX_POR_CATEGORIA:
			print("FALLA: %s guardo %d noticias, el tope es %d." % [
				cat, int(por_cat[cat]), GameState.MAX_POR_CATEGORIA])
			paso = true
	if paso:
		fallas += 1
	else:
		print("OK: ninguna categoria supera el tope de %d." % GameState.MAX_POR_CATEGORIA)

	# --- Menciones --------------------------------------------------------
	var indice := {}
	for d in range(GameState.piramide.divisiones.size()):
		for club in GameState.piramide.divisiones[d].equipos:
			for j in club.jugadores + club.banco + club.cantera:
				indice[int(j["id"])] = true

	var con_mencion := 0
	var colgadas := 0
	for n in GameState.noticias:
		for m in n.get("jugadores", []):
			con_mencion += 1
			if not indice.has(int(m["id"])):
				colgadas += 1
	if con_mencion > 0:
		print("OK: %d menciones de jugadores en el feed." % con_mencion)
	else:
		print("FALLA: ninguna noticia menciona a un jugador.")
		fallas += 1
	# Alguna puede quedar colgada de verdad (se retiro, se fue al pool de
	# libres); lo que no puede es que casi todas apunten a la nada.
	if colgadas <= con_mencion / 4:
		print("OK: %d de %d menciones ya no encuentran al jugador (aceptable)." % [
			colgadas, con_mencion])
	else:
		print("FALLA: %d de %d menciones apuntan a un jugador que no existe." % [
			colgadas, con_mencion])
		fallas += 1

	# --- Guardado ---------------------------------------------------------
	var texto := JSON.stringify(GameState.noticias)
	var recargadas := []
	for n in JSON.parse_string(texto):
		recargadas.append(Noticias.normalizar(n))
	var ok_guardado: bool = recargadas.size() == GameState.noticias.size()
	for i in range(recargadas.size()):
		if str(recargadas[i]["cat"]) != str(GameState.noticias[i]["cat"]) \
				or recargadas[i]["jugadores"].size() != GameState.noticias[i]["jugadores"].size():
			ok_guardado = false
			break
	if ok_guardado:
		print("OK: las %d noticias sobreviven al guardado con su categoria y sus menciones." % recargadas.size())
	else:
		print("FALLA: las noticias no sobreviven al guardado.")
		fallas += 1

	GameState.free()
	print("FALLOS=%d" % fallas)
	quit()
