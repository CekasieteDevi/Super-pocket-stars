extends SceneTree

## La energia que se muestra entre fecha y fecha tiene que ser con la que
## el jugador va a EMPEZAR el proximo partido.
##
## Habia dos variables: `resistencia`, que es la energia dentro de un
## partido y queda congelada con el valor del pitazo final hasta el
## reset_partido() siguiente, y `fatiga_acumulada`, que es la que recupera
## 5,5% por dia y la que de verdad se usa al arrancar. La UI mostraba la
## primera: un delantero que termino al 65% se veia al 65% toda la semana
## aunque el lunes ya estuviera al 100%.

const SEED := 2255


func _init() -> void:
	_test_muestra_la_del_proximo_partido()
	_test_al_arrancar_el_partido_son_la_misma()
	quit()


func _test_muestra_la_del_proximo_partido() -> void:
	print("=== Entre fechas se muestra la energia recuperada ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var piramide := Piramide.generar(rng)
	var liga: Liga = piramide.divisiones[9]
	var mio: Team = liga.equipos[0]
	liga.jugar_fecha(0, rng, mio)
	for l in piramide.divisiones:
		l.avanzar_dias(7)

	var recuperados := 0
	var peor_congelada := 1.0
	for j in mio.todos_los_jugadores():
		var id: int = j["id"]
		if mio.energia_proximo_partido(id) != mio.fatiga_acumulada.get(id, 1.0):
			print("FALLA: energia_proximo_partido no es la fatiga acumulada.")
			return
		if mio.energia_proximo_partido(id) > mio.resistencia_pct(id) + 0.01:
			recuperados += 1
			peor_congelada = minf(peor_congelada, mio.resistencia_pct(id))

	# Si nadie recupero, el test no esta probando nada.
	if recuperados == 0:
		print("FALLA: despues de 7 dias no recupero nadie; el test no mide nada.")
		return
	print("OK: %d jugadores recuperaron; el peor se veia al %.0f%% y arranca al %.0f%%." % [
		recuperados, peor_congelada * 100.0,
		mio.energia_proximo_partido(mio.jugadores[0]["id"]) * 100.0])


func _test_al_arrancar_el_partido_son_la_misma() -> void:
	print("\n=== Al arrancar el partido las dos coinciden ===")
	# reset_partido() copia la fatiga acumulada a la resistencia: si no
	# coincidieran, la energia mostrada seria una promesa que el motor no
	# cumple.
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 1
	var piramide := Piramide.generar(rng)
	var mio: Team = piramide.divisiones[9].equipos[0]
	piramide.divisiones[9].jugar_fecha(0, rng, mio)
	for l in piramide.divisiones:
		l.avanzar_dias(7)
	var prometido := {}
	for j in mio.todos_los_jugadores():
		prometido[j["id"]] = mio.energia_proximo_partido(j["id"])

	mio.reset_partido()
	for id in prometido:
		if absf(mio.resistencia_pct(id) - float(prometido[id])) > 0.001:
			print("FALLA: se prometio %.3f y el partido arranco con %.3f." % [
				float(prometido[id]), mio.resistencia_pct(id)])
			return
	print("OK: los %d jugadores arrancan exactamente con lo que decia la pantalla." % prometido.size())
