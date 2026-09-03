extends SceneTree

## Un expulsado se va de la cancha EN EL ACTO.
##
## La limpieza de expulsados corre cada 20 ticks (5 segundos de juego) y
## una roja puede caer en cualquiera de ellos, asi que el expulsado seguia
## corriendo y disputando la pelota hasta la limpieza siguiente: medido,
## 11 de 14 seguian jugando 2,4 segundos de promedio y hasta 3,5. Se ve,
## porque el partido del jugador se dibuja.
##
## Se busca la roja en los fotogramas y se cuenta cuantos ticks despues el
## expulsado sigue apareciendo entre los que estan en cancha.

const SEED := 5150
const PARTIDOS := 25


func _init() -> void:
	var rojas := 0
	var siguio := 0
	var ticks_total := 0
	var peor := 0
	var quedaron_mal := 0

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
			var es_local: bool = str(ev["equipo"]) == casa.nombre
			var clave := MotorEspacial.clave_de(int(ev["jugador_id"]), es_local)
			# El tick de la roja: el primer fotograma cuyo minuto ya paso
			# el del evento.
			var desde := -1
			for f in range(fotogramas.size()):
				if int(fotogramas[f]["minuto"]) >= int(ev["minuto"]):
					desde = f
					break
			if desde < 0:
				continue
			var ticks := 0
			for f in range(desde, fotogramas.size()):
				var esta := false
				for j in fotogramas[f]["jugadores"]:
					if int(j["id"]) == clave:
						esta = true
						break
				if not esta:
					break
				ticks += 1
			if ticks > 0:
				siguio += 1
				ticks_total += ticks
				peor = maxi(peor, ticks)
			# Y al final del partido, ¿seguia en cancha?
			if not fotogramas.is_empty():
				for j in fotogramas[fotogramas.size() - 1]["jugadores"]:
					if int(j["id"]) == clave:
						quedaron_mal += 1
						break

	var fallas := 0
	if rojas < 5:
		print("FALLA: solo %d rojas en %d partidos, la muestra no alcanza para probar nada." % [
			rojas, PARTIDOS])
		fallas += 1
	elif siguio == 0:
		print("OK: los %d expulsados salieron de la cancha en el acto." % rojas)
	else:
		print("FALLA: %d de %d expulsados siguieron jugando (promedio %.1f ticks, peor %d = %.1f s)." % [
			siguio, rojas, float(ticks_total) / siguio, peor, peor * MotorEspacial.TICK_SEG])
		fallas += 1
	if quedaron_mal == 0:
		print("OK: ninguno seguia en cancha al final del partido.")
	else:
		print("FALLA: %d de %d seguian en cancha al final." % [quedaron_mal, rojas])
		fallas += 1
	print("FALLOS=%d" % fallas)
	quit()
