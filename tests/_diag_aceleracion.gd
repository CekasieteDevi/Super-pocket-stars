extends SceneTree

## Prueba que `aceleracion` haga algo medible. Dos planteles IDENTICOS
## salvo por ese atributo, uno contra el otro, y se cuenta quien gana.
## Se alternan de local para que la ventaja de localia no ensucie.

const N := 300


func _init() -> void:
	var gf := 0.0
	var gc := 0.0
	var ganados := 0
	var perdidos := 0
	for i in range(N):
		var rng := RandomNumberGenerator.new()
		rng.seed = 3300 + i
		var explosivo := Team.generar("Explosivo", rng, 60)
		rng.seed = 3300 + i
		var lento := Team.generar("Lento", rng, 60)
		for j in explosivo.todos_los_jugadores():
			j["atributos"]["aceleracion"] = 90
		for j in lento.todos_los_jugadores():
			j["atributos"]["aceleracion"] = 20

		var rng2 := RandomNumberGenerator.new()
		rng2.seed = 3300 + i
		var como_local: bool = i % 2 == 0
		var r: Dictionary = MotorEspacial.simular(explosivo, lento, rng2, false) if como_local \
			else MotorEspacial.simular(lento, explosivo, rng2, false)
		var mios: int = r["goles_local"] if como_local else r["goles_visitante"]
		var suyos: int = r["goles_visitante"] if como_local else r["goles_local"]
		gf += mios
		gc += suyos
		if mios > suyos: ganados += 1
		elif suyos > mios: perdidos += 1

	print("=== aceleracion 90 vs aceleracion 20, mismo plantel en todo lo demas (%d partidos) ===" % N)
	print("  goles: %.2f a favor, %.2f en contra" % [gf / N, gc / N])
	print("  partidos: %d ganados, %d perdidos, %d empatados" % [ganados, perdidos, N - ganados - perdidos])
	quit()
