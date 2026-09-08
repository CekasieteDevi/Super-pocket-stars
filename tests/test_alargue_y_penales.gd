extends SceneTree

## El cruce de copa del jugador se juega ENTERO en la cancha: los 90', el
## alargue y la tanda de penales.
##
## Antes el motor espacial solo sabia jugar 90 minutos. Si el cruce
## terminaba empatado, Copa llamaba a MatchEngine.simular_alargue y a
## Penales.definir por atras: el jugador miraba el partido, se le cortaba
## en el minuto 90 y el alargue y los penales le llegaban escritos en el
## resumen.

const SEED := 4242

## Cuantos cruces se prueban buscando los dos casos que hacen falta: uno
## que se defina en el alargue y uno que llegue a los penales.
const CRUCES := 60


func _init() -> void:
	var fallos := 0
	var casos := _buscar_casos()
	fallos += _test_hay_de_los_dos(casos)
	fallos += _test_el_alargue_se_ve(casos)
	fallos += _test_la_tanda_se_patea_en_la_cancha(casos)
	fallos += _test_la_tanda_no_toca_el_marcador(casos)
	fallos += _test_el_marcador_de_la_tanda_coincide(casos)
	fallos += _test_en_liga_el_empate_sigue_siendo_empate()
	fallos += _test_mirar_la_tanda_no_la_cambia()
	print("\nFALLOS=%d" % fallos)
	quit()


func _armar_cruce(rng: RandomNumberGenerator, i: int) -> Array:
	var casa := Team.generar("Casa %d" % i, rng, i * 100)
	var visita := Team.generar("Visita %d" % i, rng, 50000 + i * 100)
	Alineacion.arreglar(casa)
	Alineacion.arreglar(visita)
	return [casa, visita]


## Juega cruces hasta tener uno definido en el alargue y uno definido por
## penales. Los dos se reusan en todos los tests que siguen: cada cruce
## cuesta ~0,2 s y jugarlos de nuevo por test no aporta nada.
func _buscar_casos() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var casos := {}
	for i in range(CRUCES):
		var equipos := _armar_cruce(rng, i)
		var r := MotorEspacial.simular(equipos[0], equipos[1], rng, true, true)
		var d := str(r["definicion"])
		if d != "90 minutos" and not casos.has(d):
			casos[d] = r
		if casos.has("alargue") and casos.has("penales"):
			break
	return casos


func _test_hay_de_los_dos(casos: Dictionary) -> int:
	print("=== En %d cruces a eliminacion directa salen alargue y penales ===" % CRUCES)
	var faltan := []
	for d in ["alargue", "penales"]:
		if not casos.has(d):
			faltan.append(d)
	if not faltan.is_empty():
		print("FALLA: en %d cruces no salio ningun caso de: %s." % [CRUCES, ", ".join(faltan)])
		return 1
	print("OK: hay un cruce definido en el alargue y uno definido por penales.")
	return 0


## El alargue son 2x15' con el mismo motor, asi que deja fotogramas igual
## que una mitad: se mira, no se cuenta.
func _test_el_alargue_se_ve(casos: Dictionary) -> int:
	print("\n=== El alargue deja fotogramas: esos 30' se miran ===")
	var fallos := 0
	for d in ["alargue", "penales"]:
		if not casos.has(d):
			continue
		var r: Dictionary = casos[d]
		var en_alargue := 0
		var minuto_max := 0
		for f in r["fotogramas"]:
			if int(f["minuto"]) >= 90:
				en_alargue += 1
			minuto_max = maxi(minuto_max, int(f["minuto"]))
		if en_alargue == 0:
			print("FALLA: el cruce definido en '%s' no dejo un solo fotograma del alargue." % d)
			fallos += 1
			continue
		# Los dos tiempos del alargue son 2 * TICKS_POR_TIEMPO_ALARGUE
		# fotogramas de juego. Se pide UNO de los dos como piso: el
		# descuento y los cambios mueven el total para arriba, nunca tanto
		# para abajo.
		if en_alargue < MotorEspacial.TICKS_POR_TIEMPO_ALARGUE:
			print("FALLA: el alargue de '%s' dejo %d fotogramas, menos de %d." % [
				d, en_alargue, MotorEspacial.TICKS_POR_TIEMPO_ALARGUE])
			fallos += 1
			continue
		if minuto_max < 119:
			print("FALLA: el alargue de '%s' llego solo hasta el minuto %d." % [d, minuto_max])
			fallos += 1
			continue
		print("OK: '%s' deja %d fotogramas de alargue y llega al minuto %d." % [
			d, en_alargue, minuto_max])
	return fallos


func _test_la_tanda_se_patea_en_la_cancha(casos: Dictionary) -> int:
	print("\n=== La tanda se patea en la cancha, penal por penal ===")
	if not casos.has("penales"):
		print("FALLA: no hay cruce definido por penales para revisar.")
		return 1
	var r: Dictionary = casos["penales"]
	var con_tanda := 0
	var remates := 0
	for f in r["fotogramas"]:
		if f.get("tanda", null) != null:
			con_tanda += 1
		for ev in f.get("eventos", []):
			if str(ev.get("tipo", "")) == "penal_tanda":
				remates += 1
	var pateados: int = r["penales"]["tandas"].size()
	if con_tanda == 0:
		print("FALLA: la tanda no dejo un solo fotograma.")
		return 1
	if remates != pateados:
		print("FALLA: se patearon %d penales pero en los fotogramas hay %d remates." % [
			pateados, remates])
		return 1
	print("OK: %d penales pateados, %d remates en los fotogramas, %d fotogramas de tanda." % [
		pateados, remates, con_tanda])
	return 0


## Un penal de la tanda no es un gol del partido: los 120' terminaron
## empatados y el marcador y el reloj se quedan ahi.
func _test_la_tanda_no_toca_el_marcador(casos: Dictionary) -> int:
	print("\n=== Los penales de la tanda no tocan el marcador ni el reloj ===")
	if not casos.has("penales"):
		print("FALLA: no hay cruce definido por penales para revisar.")
		return 1
	var r: Dictionary = casos["penales"]
	if int(r["goles_local"]) != int(r["goles_visitante"]):
		print("FALLA: se definio por penales pero el partido quedo %d-%d." % [
			int(r["goles_local"]), int(r["goles_visitante"])])
		return 1
	var pen: Dictionary = r["penales"]
	if int(pen["goles_local"]) == int(pen["goles_visitante"]):
		print("FALLA: la tanda quedo empatada %d-%d." % [
			int(pen["goles_local"]), int(pen["goles_visitante"])])
		return 1
	for f in r["fotogramas"]:
		if f.get("tanda", null) == null:
			continue
		if int(f["minuto"]) > 120:
			print("FALLA: el reloj sigue corriendo en la tanda, marca %d'." % int(f["minuto"]))
			return 1
		var movido: bool = int(f["goles"]["home"]) != int(r["goles_local"])
		movido = movido or int(f["goles"]["away"]) != int(r["goles_visitante"])
		if movido:
			print("FALLA: el marcador del partido se movio durante la tanda.")
			return 1
	print("OK: el partido queda %d-%d, la tanda %d-%d y el reloj no pasa de 120'." % [
		int(r["goles_local"]), int(r["goles_visitante"]),
		int(pen["goles_local"]), int(pen["goles_visitante"])])
	return 0


## Lo que se ve tiene que ser lo que paso. Si un penal se quedara sin
## resolver dentro de su tope de ticks, el contador de la pantalla
## quedaria abajo del resultado real y el jugador veria una tanda que no
## cierra con el resultado que le anuncian.
func _test_el_marcador_de_la_tanda_coincide(casos: Dictionary) -> int:
	print("\n=== El marcador que se ve en la tanda es el resultado real ===")
	if not casos.has("penales"):
		print("FALLA: no hay cruce definido por penales para revisar.")
		return 1
	var r: Dictionary = casos["penales"]
	var ultimo = null
	for f in r["fotogramas"]:
		if f.get("tanda", null) != null:
			ultimo = f["tanda"]
	if ultimo == null:
		print("FALLA: ningun fotograma trae el marcador de la tanda.")
		return 1
	var pen: Dictionary = r["penales"]
	var difiere: bool = int(ultimo["home"]) != int(pen["goles_local"])
	difiere = difiere or int(ultimo["away"]) != int(pen["goles_visitante"])
	if difiere:
		print("FALLA: en pantalla la tanda termina %d-%d y el resultado dice %d-%d." % [
			int(ultimo["home"]), int(ultimo["away"]),
			int(pen["goles_local"]), int(pen["goles_visitante"])])
		return 1
	print("OK: pantalla y resultado dicen lo mismo, %d-%d." % [
		int(ultimo["home"]), int(ultimo["away"])])
	return 0


## El alargue es de la eliminacion directa, no del motor: un partido de
## liga empatado sigue terminando empatado a los 90.
func _test_en_liga_el_empate_sigue_siendo_empate() -> int:
	print("\n=== En liga un empate termina a los 90' ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var empates := 0
	for i in range(20):
		var equipos := _armar_cruce(rng, i)
		var r := MotorEspacial.simular(equipos[0], equipos[1], rng, false)
		if str(r["definicion"]) != "90 minutos":
			print("FALLA: un partido de liga se definio en '%s'." % str(r["definicion"]))
			return 1
		if not r["penales"].is_empty():
			print("FALLA: un partido de liga pateo penales.")
			return 1
		if int(r["goles_local"]) == int(r["goles_visitante"]):
			empates += 1
	if empates == 0:
		print("FALLA: en 20 partidos de liga no hubo ni un empate: el test no midio nada.")
		return 1
	print("OK: 20 partidos de liga, %d empates, ninguno con alargue ni penales." % empates)
	return 0


## PARIDAD: la tanda la resuelve Penales para los dos motores, y el motor
## espacial solo la patea. Mirarla en la cancha no puede cambiar ni un
## remate — si lo cambiara, el jugador definiria sus tandas con otras
## chances que la IA. Medido: el duelo de penal del motor espacial
## convierte el 96,8% y el de Penales el 84,2%
## (tests/_diag_conversion_penales.gd), asi que quien decide importa.
func _test_mirar_la_tanda_no_la_cambia() -> int:
	print("\n=== Mirar la tanda no cambia ni un penal ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var equipos := _armar_cruce(rng, 0)

	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = SEED
	var a_ciegas := Penales.definir(equipos[0], equipos[1], rng_a)

	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = SEED
	var mirados := []
	var mirada := Penales.definir(equipos[0], equipos[1], rng_b,
		func(pateador: Dictionary, _arquero: Dictionary, _es_local: bool, gol: bool) -> void:
			mirados.append({"id": int(pateador["id"]), "gol": gol}))

	var difiere: bool = int(a_ciegas["goles_local"]) != int(mirada["goles_local"])
	difiere = difiere or int(a_ciegas["goles_visitante"]) != int(mirada["goles_visitante"])
	if difiere:
		print("FALLA: la misma tanda da %d-%d sin mirarla y %d-%d mirandola." % [
			int(a_ciegas["goles_local"]), int(a_ciegas["goles_visitante"]),
			int(mirada["goles_local"]), int(mirada["goles_visitante"])])
		return 1
	if mirados.size() != a_ciegas["tandas"].size():
		print("FALLA: se patearon %d penales y se miraron %d." % [
			a_ciegas["tandas"].size(), mirados.size()])
		return 1
	for i in range(mirados.size()):
		var esperado: Dictionary = a_ciegas["tandas"][i]
		var mal: bool = int(mirados[i]["id"]) != int(esperado["jugador_id"])
		mal = mal or bool(mirados[i]["gol"]) != bool(esperado["gol"])
		if mal:
			print("FALLA: el penal %d no coincide entre mirar y no mirar." % (i + 1))
			return 1
	print("OK: %d penales, mismo pateador y mismo resultado en los dos casos (%d-%d)." % [
		mirados.size(), int(mirada["goles_local"]), int(mirada["goles_visitante"])])
	return 0
