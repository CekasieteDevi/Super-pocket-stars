extends SceneTree

## En PARTIDOS REALES: cuando se cobra un corner, a que distancia del
## banderin esta el que lo va a tirar, y si llega antes de patearlo.
##
## Medirlo en un estado armado a mano no sirve: montado justo despues del
## saque del medio, todos estan en su propia mitad y las distancias al
## banderin rival son irreales. Un corner de verdad pasa despues de un
## ataque, con medio equipo ya arriba.

const SEED := 4242
const PARTIDOS := 12


func _init() -> void:
	var al_cobrar := []
	var al_patear := []
	for i in range(PARTIDOS):
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + i
		var casa := Team.generar("Casa", rng, 0)
		var visita := Team.generar("Visita", rng, 400)
		casa.reset_partido()
		visita.reset_partido()
		casa.local = true
		visita.local = false
		casa.clima_partido = Clima.generar(rng)
		visita.clima_partido = casa.clima_partido
		casa.arbitro_partido = Arbitro.generar(rng)
		visita.arbitro_partido = casa.arbitro_partido
		var estado := MotorEspacial.crear_estado(casa, visita, rng)
		MotorEspacial._reiniciar_desde_medio(estado, true, 1)

		var siguiendo := false
		var esquina := Vector2.ZERO
		var ejecutor := -1
		for t in range(MotorEspacial.TICKS_POR_MITAD):
			var bp: Dictionary = estado.get("balon_parado", {})
			var es_corner: bool = str(bp.get("tipo", "")) == "corner"
			if es_corner and not siguiendo:
				siguiendo = true
				esquina = bp["pos"]
				ejecutor = int(bp["ejecutor"])
				if estado["jugadores"].has(ejecutor):
					al_cobrar.append(esquina.distance_to(
						estado["jugadores"][ejecutor]["pos"]))
			# El ultimo tick antes de ejecutarlo.
			if siguiendo and es_corner and int(estado.get("detenido", 0)) == 1:
				if estado["jugadores"].has(ejecutor):
					al_patear.append(esquina.distance_to(
						estado["jugadores"][ejecutor]["pos"]))
				siguiendo = false
			MotorEspacial._tick(estado, false)

	print("%d corners seguidos en %d medios tiempos." % [al_patear.size(), PARTIDOS])
	print("  distancia del ejecutor al banderin AL COBRARSE:  %.1f m" % _media(al_cobrar))
	print("  distancia AL MOMENTO DE PATEARLO:                %.1f m" % _media(al_patear))
	var llegaron := 0
	for d in al_patear:
		if float(d) <= 2.5:
			llegaron += 1
	print("  llego caminando al banderin en %d de %d (%.0f%%)" % [
		llegaron, al_patear.size(), 100.0 * llegaron / maxf(al_patear.size(), 1)])
	print("\nEl corner dura %d ticks (%.1f s), %d de ellos congelados." % [
		int(MotorEspacial.TICKS_DETENIDO["corner"]) + MotorEspacial.TICKS_CONGELADO_CORNER,
		(int(MotorEspacial.TICKS_DETENIDO["corner"]) + MotorEspacial.TICKS_CONGELADO_CORNER)
			* MotorEspacial.TICK_SEG,
		MotorEspacial.TICKS_CONGELADO_CORNER])
	quit()


func _media(v: Array) -> float:
	if v.is_empty():
		return 0.0
	var s := 0.0
	for x in v:
		s += float(x)
	return s / v.size()
