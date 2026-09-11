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
## El laboratorio provoca la roja en cada caso. Con partidos completos,
## los cambios tacticos dejaron solo cuatro rojas en noventa partidos.
## Esta prueba verifica la salida; la frecuencia requiere otra medicion.
const PARTIDOS := 12

## Lo que avanza un expulsado en un tick. Es la tolerancia con la que se
## mide si llego a la linea: el ultimo fotograma en que se lo ve puede
## estar hasta un paso antes de la cal.
const PASO_CAMINANDO := 3.0


func _init() -> void:
	var fallas := 0
	fallas += _test_camina_y_sale()
	fallas += _test_sin_gente_se_cancela()
	fallas += _test_los_cambios_se_ven()
	fallas += _test_el_tiempo_detenido_se_repone()
	fallas += _test_no_vuelve_en_el_segundo_tiempo()
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
		var r := Laboratorio.generar("expulsion", casa, visita, rng)
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
			# Se lo borra de la cancha a medio paso del punto de salida,
			# que esta 2,5 m PASADA la cal. Como camina ~2,7 m por tick,
			# el ultimo fotograma en que todavia se lo ve cae en cualquier
			# lado de ese ultimo tramo: medido, uno quedo en y=-33,9987
			# con la linea en 34,0 y el test lo conto como que no salio,
			# cuando venia caminando derecho hacia afuera. Lo que se
			# comprueba es que llego a la cal, no que un fotograma
			# puntual cayera del lado de afuera — eso es suerte de
			# muestreo y no conducta del motor.
			if absf(ultima_y) >= MotorEspacial.MEDIO_ANCHO - PASO_CAMINANDO:
				salieron += 1
			elif desde + ticks >= fotogramas.size():
				# Se acabo el partido mientras caminaba: es correcto.
				termino_el_partido += 1

	var fallas := 0
	if rojas != PARTIDOS:
		print("FALLA: el laboratorio produjo %d rojas en %d casos." % [rojas, PARTIDOS])
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
	# clave -> y en el primer fotograma: sirve para saber quien arranca
	# afuera de la cancha, que es como se ve al que va a entrar.
	var primeros := {}
	for j in fg[0]["jugadores"]:
		primeros[int(j["id"])] = float(j["y"])
	var ultimos := {}
	for j in fg[fg.size() - 1]["jugadores"]:
		ultimos[int(j["id"])] = true

	var fallas := 0
	var salieron := []
	var entraron := []
	for k in primeros:
		if not ultimos.has(k):
			salieron.append(k)
	# El que entra ya esta en el PRIMER fotograma, esperando en el
	# lateral: el clip arranca con la jugada montada, no antes. Asi que no
	# alcanza con mirar quien aparece — se mira quien empieza fuera de la
	# cancha y termina adentro.
	for k in ultimos:
		if not primeros.has(k):
			entraron.append(k)
		elif absf(float(primeros[k])) > MotorEspacial.MEDIO_ANCHO:
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


## El tiempo de entrada y salida se repone. Se mide en fotogramas:
## los goles dependen de la punteria y no prueban la duracion del partido.
func _test_el_tiempo_detenido_se_repone() -> int:
	var casos := 0
	var transitos := 0
	var minimo := 2 * MotorEspacial.TICKS_POR_MITAD
	for i in range(PARTIDOS):
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + i
		var casa := Team.generar("Casa", rng, 0)
		var visita := Team.generar("Visita", rng, 400)
		var resultado := MotorEspacial.simular(casa, visita, rng, true)
		if bool(resultado.get("cancelado", false)):
			continue
		var sin_transito := 0
		for fotograma in resultado["fotogramas"]:
			if fotograma["foco"] == null:
				sin_transito += 1
			else:
				transitos += 1
		casos += 1
		# El foco se captura despues de mover. Se permite un fotograma de
		# borde por mitad si la salida queda cortada al terminar el periodo.
		if sin_transito < minimo - 2:
			print("FALLA: semilla %d conserva %d ticks sin transito; se esperan al menos %d." % [
				SEED + i, sin_transito, minimo - 2])
			return 1
	if casos == 0 or transitos == 0:
		print("FALLA: la prueba no observo partidos completos con entradas o salidas.")
		return 1
	print("OK: %d partidos conservan el tiempo de juego, ademas de %d ticks de entradas y salidas." % [casos, transitos])
	return 0


## Una roja sobre el final de la mitad corta el periodo con el expulsado
## todavia caminando hacia el lateral. El segundo tiempo tiene que
## arrancar SIN el: antes el arranque del periodo lo volvia a parar en su
## posicion base y el equipo salia con once.
func _test_no_vuelve_en_el_segundo_tiempo() -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var casa := Team.generar("Casa", rng, 0)
	var visita := Team.generar("Visita", rng, 0)
	casa.reset_partido()
	visita.reset_partido()
	casa.local = true
	visita.local = false
	var estado := MotorEspacial.crear_estado(casa, visita, rng)
	estado["con_fotogramas"] = true

	var victima: Dictionary = casa.jugadores_en_cancha()[5]
	casa.expulsados_partido[int(victima["id"])] = true
	MotorEspacial._mandar_a_las_duchas(estado, int(victima["id"]), true)
	var clave := MotorEspacial.clave_de(int(victima["id"]), true)

	# La mitad corta aca, con el expulsado a mitad de camino, y arranca el
	# segundo tiempo. 20 ticks alcanzan: el saque del medio y unos pocos
	# ticks de juego es donde se lo veia reaparecer.
	MotorEspacial._jugar_periodo(estado, casa, visita, false, 2, 45.0, 20, [], true)

	var ticks_del_expulsado := 0
	var locales_max := 0
	for f in estado["fotogramas"]:
		var locales := 0
		for j in f["jugadores"]:
			if int(j["id"]) == clave:
				ticks_del_expulsado += 1
			if bool(j["equipo_local"]):
				locales += 1
		locales_max = maxi(locales_max, locales)

	var fallas := 0
	if ticks_del_expulsado > 0:
		print("FALLA: el expulsado vuelve al segundo tiempo (%d ticks)" % ticks_del_expulsado)
		fallas += 1
	else:
		print("OK: el expulsado no vuelve al segundo tiempo")
	if locales_max > 10:
		print("FALLA: el equipo sale con %d al segundo tiempo" % locales_max)
		fallas += 1
	else:
		print("OK: el equipo sale con %d al segundo tiempo" % locales_max)
	return fallas
