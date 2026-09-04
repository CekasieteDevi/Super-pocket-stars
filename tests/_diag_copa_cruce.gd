extends SceneTree

## Medicion, no test: el cruce de copa del jugador pasa a jugarse con el
## motor espacial (antes iba con el abstracto). Se mide el MISMO cruce con
## los dos motores, con el mundo recien creado en cada corrida para que la
## fatiga acumulada no ensucie el numero.

const SEED := 5150
const GUION := preload("res://game/game_state.gd")
const CORRIDAS := 20


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	for motor in ["espacial", "abstracto"]:
		var goles_mios := 0
		var goles_suyos := 0
		var peor := 0
		for i in range(CORRIDAS):
			var gs = GUION.new()
			gs.partida_nueva(SEED)
			var mio: Team = gs.equipo_jugador
			var cruce: Array = gs.copa_nacional.cruce_de(mio)
			if cruce.is_empty():
				print("El jugador no entro al cuadro de la Copa Nacional.")
				quit()
				return
			var home: Team = cruce[0]
			var away: Team = cruce[1]
			Alineacion.arreglar(home)
			Alineacion.arreglar(away)
			rng.seed = SEED + i
			var r: Dictionary
			if motor == "espacial":
				r = MotorEspacial.simular(home, away, rng, false)
			else:
				r = MatchEngine.simular(home, away, rng, false)
			var mios: int = r["goles_local"] if home == mio else r["goles_visitante"]
			var suyos: int = r["goles_visitante"] if home == mio else r["goles_local"]
			goles_mios += mios
			goles_suyos += suyos
			peor = maxi(peor, suyos - mios)
			gs.free()
		print("%s: promedio %.2f-%.2f en contra, peor goleada %d." % [
			motor, float(goles_mios) / CORRIDAS, float(goles_suyos) / CORRIDAS, peor])
	quit()
