extends SceneTree

## El laboratorio de animaciones: que cada situacion genere fotogramas de
## verdad y que se vea lo que promete.

const SEED := 2024


func _init() -> void:
	var fallas := 0
	for s in Laboratorio.SITUACIONES:
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED
		var casa := Team.generar("Casa", rng, 0)
		var visita := Team.generar("Visita", rng, 400)
		var r := Laboratorio.generar(str(s["clave"]), casa, visita, rng)
		var fotogramas: Array = r["fotogramas"]
		var tipos := {}
		for e in r["eventos"]:
			tipos[str(e.get("tipo", ""))] = int(tipos.get(str(e.get("tipo", "")), 0)) + 1
		if fotogramas.size() < Laboratorio.TICKS:
			print("FALLA: %s genero solo %d fotogramas." % [s["clave"], fotogramas.size()])
			fallas += 1
			continue
		# Que los 22 (o 21 tras la roja) esten y que la pelota exista.
		var ultimo: Dictionary = fotogramas[fotogramas.size() - 1]
		if ultimo["jugadores"].size() < 20:
			print("FALLA: %s termina con %d jugadores en cancha." % [
				s["clave"], ultimo["jugadores"].size()])
			fallas += 1
			continue
		print("OK: %-12s %d fotogramas, %d en cancha al final, eventos %s" % [
			s["clave"], fotogramas.size(), ultimo["jugadores"].size(), tipos])
	fallas += _test_no_toca_al_equipo()
	print("FALLOS=%d" % fallas)
	quit()


## El motor lesiona y suspende de verdad: _chequear_lesion escribe en
## lesiones y una roja suma una fecha a suspendidos, y reset_partido() no
## limpia ninguna de las dos. Mirar una animacion no puede romperte un
## titular, asi que se juega con copias — esto lo comprueba.
func _test_no_toca_al_equipo() -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var casa := Team.generar("Casa", rng, 0)
	var visita := Team.generar("Visita", rng, 400)
	var fallas := 0
	for s in Laboratorio.SITUACIONES:
		var copia_casa := Team.cargar(casa.guardar())
		var copia_visita := Team.cargar(visita.guardar())
		var r2 := RandomNumberGenerator.new()
		r2.seed = SEED
		Laboratorio.generar(str(s["clave"]), copia_casa, copia_visita, r2)
		for e in [casa, visita]:
			if not e.lesiones.is_empty() or not e.suspendidos.is_empty() 					or not e.expulsados_partido.is_empty() or e.goles != 0:
				print("FALLA: reproducir \"%s\" toco al equipo de verdad (%d lesiones, %d suspendidos, %d goles)." % [
					s["clave"], e.lesiones.size(), e.suspendidos.size(), e.goles])
				fallas += 1
	if fallas == 0:
		print("OK: reproducir las %d jugadas no deja lesiones, suspensiones ni goles en los equipos reales." % [
			Laboratorio.SITUACIONES.size()])
	return fallas
