extends SceneTree

## El expulsado se va CAMINANDO y el juego lo espera; y cuando un equipo
## se queda con menos de siete, el partido se cancela.
##
## Antes desaparecia de un fotograma al otro —y encima tarde, porque la
## limpieza de expulsados corria cada 20 ticks y la roja puede caer en
## cualquiera: 11 de 14 seguian jugando 2,4 segundos de promedio—. Ahora
## el juego queda detenido mientras el expulsado camina hasta el lateral,
## a la altura del medio de la cancha, y recien cuando sale se cobra la
## falta.

const SEED := 5150
const PARTIDOS := 25


func _init() -> void:
	var fallas := 0
	fallas += _test_camina_y_sale()
	fallas += _test_sin_gente_se_cancela()
	fallas += _test_los_cambios_se_ven()
	fallas += _test_el_tiempo_detenido_se_repone()
	print("FALLOS=%d" % fallas)
	quit()


func _test_camina_y_sale() -> int:
	var rojas := 0
	var caminaron := 0
	var salieron := 0
	var termino_el_partido := 0
	var pelota_quieta := 0
	var ticks_total := 0

	for i in range(PARTIDOS):
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + i
		var casa := Team.generar("Casa", rng, 0)
		var visita := Team.generar("Visita", rng, 400)
		var r := MotorEspacial.simular(casa, visita, rng, true)
		var fotogramas: Array = r["fotogramas"]

		for ev in r["eventos"]:
			if str(ev.get("tipo", "")) != "tarjeta":
				continue
			if not str(ev.get("resultado", "")).begins_with("roja"):
				continue
			rojas += 1
			var clave := MotorEspacial.clave_de(
				int(ev["jugador_id"]), str(ev["equipo"]) == casa.nombre)
			var desde := -1
			for f in range(fotogramas.size()):
				if int(fotogramas[f]["minuto"]) >= int(ev["minuto"]):
					desde = f
					break
			if desde < 0:
				continue

			# Cuantos fotogramas sigue en cancha, donde queda, y si la
			# pelota se movio mientras tanto.
			var ticks := 0
			var ultima_y := 0.0
			var pelota_ini := Vector2.ZERO
			var pelota_fin := Vector2.ZERO
			for f in range(desde, fotogramas.size()):
				var esta := false
				for j in fotogramas[f]["jugadores"]:
					if int(j["id"]) == clave:
						esta = true
						ultima_y = float(j["y"])
						break
				if not esta:
					break
				if ticks == 0:
					pelota_ini = Vector2(
						float(fotogramas[f]["pelota"]["x"]), float(fotogramas[f]["pelota"]["y"]))
				pelota_fin = Vector2(
					float(fotogramas[f]["pelota"]["x"]), float(fotogramas[f]["pelota"]["y"]))
				ticks += 1
			if ticks == 0:
				continue
			caminaron += 1
			ticks_total += ticks
			# La pelota esta parada esperando el saque: se le permite el
			# acomodo al punto de la falta, no que siga rodando.
			if pelota_ini.distance_to(pelota_fin) < 20.0:
				pelota_quieta += 1
			if absf(ultima_y) >= MotorEspacial.MEDIO_ANCHO:
				salieron += 1
			elif desde + ticks >= fotogramas.size():
				# Se acabo el partido mientras caminaba: es correcto.
				termino_el_partido += 1

	var fallas := 0
	if rojas < 5:
		print("FALLA: solo %d rojas en %d partidos, la muestra no alcanza." % [rojas, PARTIDOS])
		return 1

	if caminaron == rojas:
		print("OK: los %d expulsados caminan hacia afuera (%.1f s de promedio)." % [
			rojas, float(ticks_total) / caminaron * MotorEspacial.TICK_SEG])
	else:
		print("FALLA: solo %d de %d expulsados caminaron; el resto desaparecio." % [
			caminaron, rojas])
		fallas += 1

	if salieron + termino_el_partido == caminaron:
		print("OK: %d salieron pasando la linea y %d se quedaron caminando porque termino el partido." % [
			salieron, termino_el_partido])
	else:
		print("FALLA: %d de %d no salieron ni tenian el partido terminado." % [
			caminaron - salieron - termino_el_partido, caminaron])
		fallas += 1

	if pelota_quieta == caminaron:
		print("OK: el juego estuvo detenido en las %d salidas." % caminaron)
	else:
		print("FALLA: en %d de %d salidas la pelota siguio en juego mientras caminaba." % [
			caminaron - pelota_quieta, caminaron])
		fallas += 1
	return fallas


## Con menos de siete en cancha el partido se abandona (Regla 3): se
## arranca con 11, asi que son cinco expulsados. Gana el rival, no importa
## como iba el marcador.
func _test_sin_gente_se_cancela() -> int:
	var fallas := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var casa := Team.generar("Casa", rng, 0)
	var visita := Team.generar("Visita", rng, 400)
	casa.reset_partido()
	visita.reset_partido()

	# Con uno menos de los que cancelan todavia se juega.
	for i in range(MatchEngine.EXPULSADOS_QUE_CANCELAN - 1):
		casa.expulsados_partido[int(casa.jugadores[i + 1]["id"])] = true
	var quedan: int = 11 - (MatchEngine.EXPULSADOS_QUE_CANCELAN - 1)
	if MatchEngine.sin_jugadores(casa):
		print("FALLA: con %d expulsados (%d en cancha) ya se cancela, y tendria que seguir." % [
			MatchEngine.EXPULSADOS_QUE_CANCELAN - 1, quedan])
		fallas += 1
	else:
		print("OK: con %d expulsados (%d en cancha, el minimo es %d) el partido sigue." % [
			MatchEngine.EXPULSADOS_QUE_CANCELAN - 1, quedan, MatchEngine.MINIMO_EN_CANCHA])

	# El ultimo lo termina. Y el que se queda sin gente iba GANANDO, para
	# comprobar que el marcador no importa.
	casa.goles = 5
	visita.goles = 0
	casa.expulsados_partido[int(casa.jugadores[MatchEngine.EXPULSADOS_QUE_CANCELAN]["id"])] = true
	var log := []
	var eventos := []
	if not MatchEngine.cancelar_si_falta_gente(casa, visita, 70, log, eventos):
		print("FALLA: con %d expulsados (%d en cancha) el partido no se cancelo." % [
			MatchEngine.EXPULSADOS_QUE_CANCELAN, 11 - MatchEngine.EXPULSADOS_QUE_CANCELAN])
		return fallas + 1

	if casa.goles == 0 and visita.goles == MatchEngine.GOLES_POR_CANCELACION:
		print("OK: iba ganando 5-0 y termina perdiendo %d-%d." % [casa.goles, visita.goles])
	else:
		print("FALLA: el marcador quedo %d-%d." % [casa.goles, visita.goles])
		fallas += 1

	var hubo_evento := false
	for e in eventos:
		if str(e.get("tipo", "")) == "cancelado" and str(e.get("equipo", "")) == casa.nombre:
			hubo_evento = true
	if hubo_evento and not log.is_empty():
		print("OK: queda el evento y la linea de relato.")
	else:
		print("FALLA: no se anoto el evento de cancelacion (%d eventos, %d lineas)." % [
			eventos.size(), log.size()])
		fallas += 1
	return fallas


## Un cambio no es un jugador que desaparece y otro que aparece: el que
## sale se va por el lateral y el suplente entra por ahi mismo.
func _test_los_cambios_se_ven() -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var casa := Team.generar("Casa", rng, 0)
	var visita := Team.generar("Visita", rng, 400)
	var propio := RandomNumberGenerator.new()
	propio.seed = Laboratorio.SEMILLA
	var r := Laboratorio.generar("cambio", casa, visita, propio)
	var fg: Array = r["fotogramas"]
	var primeros := {}
	for j in fg[0]["jugadores"]:
		primeros[int(j["id"])] = true
	var ultimos := {}
	for j in fg[fg.size() - 1]["jugadores"]:
		ultimos[int(j["id"])] = true

	var fallas := 0
	var salieron := []
	var entraron := []
	for k in primeros:
		if not ultimos.has(k):
			salieron.append(k)
	for k in ultimos:
		if not primeros.has(k):
			entraron.append(k)
	if salieron.size() != 2 or entraron.size() != 2:
		print("FALLA: el clip del cambio tiene %d que salen y %d que entran (se esperan 2 y 2)." % [
			salieron.size(), entraron.size()])
		return 1
	if ultimos.size() != 22:
		print("FALLA: terminan %d en cancha y tienen que ser 22." % ultimos.size())
		fallas += 1

	# El que sale tiene que CRUZAR la linea, no evaporarse en el medio.
	for clave in salieron:
		var ultima := Vector2.ZERO
		for f in fg:
			for j in f["jugadores"]:
				if int(j["id"]) == clave:
					ultima = Vector2(float(j["x"]), float(j["y"]))
		if absf(ultima.y) < MotorEspacial.MEDIO_ANCHO:
			print("FALLA: el que sale desaparecio en y=%.1f, adentro de la cancha." % ultima.y)
			fallas += 1

	# Y el que entra tiene que aparecer AFUERA y terminar adentro.
	for clave in entraron:
		var primera := Vector2.ZERO
		var ultima2 := Vector2.ZERO
		var visto := false
		for f in fg:
			for j in f["jugadores"]:
				if int(j["id"]) != clave:
					continue
				if not visto:
					primera = Vector2(float(j["x"]), float(j["y"]))
					visto = true
				ultima2 = Vector2(float(j["x"]), float(j["y"]))
		if absf(primera.y) < MotorEspacial.MEDIO_ANCHO:
			print("FALLA: el suplente aparecio adentro de la cancha (y=%.1f)." % primera.y)
			fallas += 1
		if absf(ultima2.y) >= MotorEspacial.MEDIO_ANCHO:
			print("FALLA: el suplente se quedo afuera (y=%.1f)." % ultima2.y)
			fallas += 1
	# La regla del cuarto arbitro: el suplente no entra hasta que el otro
	# salio. Se comprueba con lo unico que importa de verdad — que no haya
	# un solo cuadro con doce de un equipo adentro de la cancha.
	var maximo := 0
	var minimo := 99
	for f in fg:
		var dentro := 0
		for j in f["jugadores"]:
			if absf(float(j["y"])) < MotorEspacial.MEDIO_ANCHO:
				dentro += 1
		maximo = maxi(maximo, dentro)
		minimo = mini(minimo, dentro)
	if maximo > 22:
		print("FALLA: hubo un cuadro con %d jugadores adentro de la cancha." % maximo)
		fallas += 1
	elif minimo >= 22:
		print("FALLA: nunca bajo de 22 adentro, o sea que el suplente entro antes de que saliera el otro.")
		fallas += 1

	if fallas == 0:
		print("OK: en el cambio salen 2 cruzando la linea y entran 2 desde afuera, sin pasar de 22 (baja a %d)." % minimo)
	return fallas


## Animar los cambios detiene el juego, y ese tiempo se REPONE: si no, se
## come el 10% del partido y los goles bajan de 2,36 a 1,84.
func _test_el_tiempo_detenido_se_repone() -> int:
	var goles := 0
	var muestras := 15
	for i in range(muestras):
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + i
		var casa := Team.generar("Casa", rng, 0)
		var visita := Team.generar("Visita", rng, 400)
		var r := MotorEspacial.simular(casa, visita, rng, false)
		goles += int(r["goles_local"]) + int(r["goles_visitante"])
	var media: float = float(goles) / muestras
	# La referencia son los 2,3-2,4 que daba antes de animar los cambios.
	if media >= 1.9:
		print("OK: %.2f goles por partido, el tiempo de los cambios se repone." % media)
		return 0
	print("FALLA: %.2f goles por partido; animar los cambios le esta comiendo tiempo al juego." % media)
	return 1
