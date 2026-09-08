extends SceneTree

## Cuanto se convierte un penal de tanda por cada camino. Es la pregunta
## de paridad: el cruce del jugador patea la tanda en la cancha y el de la
## IA la resuelve a ciegas, asi que los dos tienen que dar el mismo numero
## o el jugador define por penales con otras chances.
##
## Este diagnostico es el que decidio que la tanda la resuelva Penales
## para los dos motores. Con el motor espacial resolviendo su propio
## remate (el duelo de _ejecutar_penal, con ventaja_penal en 45) daba
## 96,8% contra el 84,2% del abstracto: 12,6 puntos de diferencia. Ahora
## los dos salen del mismo duelo y la diferencia que queda es ruido de
## muestreo.

const SEED := 771
const TANDAS := 400


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var equipos := []
	for i in range(20):
		var t := Team.generar("Equipo %d" % i, rng, i * 100)
		Alineacion.arreglar(t)
		equipos.append(t)

	# ABSTRACTO: la tanda tal como la juegan los cruces de la IA.
	var pateados := 0
	var convertidos := 0
	for i in range(TANDAS):
		var casa: Team = equipos[i % equipos.size()]
		var visita: Team = equipos[(i + 7) % equipos.size()]
		var r := Penales.definir(casa, visita, rng)
		for t in r["tandas"]:
			pateados += 1
			if bool(t["gol"]):
				convertidos += 1
	print("abstracto (Penales.definir): %d penales, %.1f%% convertidos" % [
		pateados, 100.0 * convertidos / pateados])

	# ESPACIAL: el mismo remate que ve el jugador, resuelto por
	# _ejecutar_penal. Se mide armando un penal en un estado de partido.
	var pat_e := 0
	var conv_e := 0
	for i in range(TANDAS):
		var casa: Team = equipos[i % equipos.size()]
		var visita: Team = equipos[(i + 7) % equipos.size()]
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
		var r := MotorEspacial._tanda_de_penales(estado, false)
		for t in r["tandas"]:
			pat_e += 1
			if bool(t["gol"]):
				conv_e += 1
	print("espacial (tanda en la cancha): %d penales, %.1f%% convertidos" % [
		pat_e, 100.0 * conv_e / pat_e])
	quit()
