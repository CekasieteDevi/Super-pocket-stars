extends SceneTree

## Medición del festejo en el banderín (docs/motor_v2.md, etapa 8): en cada
## gol, a cuánto del banderín termina el que lo hizo, cuántos pasos festeja
## (clip Festejar) y cuánto dura la parada hasta el saque del medio.

const SEED := 20261301
const PARTIDOS := 10


func _init() -> void:
	var goles := 0
	var llegan := 0
	var suma_dist := 0.0
	var suma_festeja := 0.0
	var suma_parada := 0.0
	for n in PARTIDOS:
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + n
		var home: Team = Team.generar("Local", rng, 0)
		var away: Team = Team.generar("Visitante", rng, 1000)
		home.reset_partido()
		away.reset_partido()
		var c: Object = CerebroV2.armar(home, away, SEED + n, true)
		var festejando := false
		var desde := 0
		var pasos_clip := 0
		var dist := 0.0
		var pasos := 0
		while str(c.get_estado()["periodo"]) != "terminado" and pasos < MotorV2.PASOS_TOPE:
			c.avanzar()
			pasos += 1
			var estado: Dictionary = c.get_estado()
			var f := int(estado.get("festeja", -1))
			if f >= 0:
				if not festejando:
					festejando = true
					desde = pasos
					pasos_clip = 0
				var p: Vector2 = c.get_pos()[f]
				dist = Vector2(ProyeccionPartido.MEDIO_LARGO - absf(p.x), ProyeccionPartido.MEDIO_ANCHO - absf(p.y)).length()
				if c.get_accion(f) == "Festejar":
					pasos_clip += 1
			elif festejando and str(estado["parada"]) != "saque_medio":
				festejando = false
				goles += 1
				suma_dist += dist
				suma_festeja += pasos_clip / 60.0
				suma_parada += (pasos - desde) / 60.0
				if pasos_clip > 0:
					llegan += 1
	print("goles con festejo %d; llegan al banderín y festejan %d; al final a %.1f m del banderín; festejan %.1f s; la parada dura %.1f s" % [
		goles, llegan, suma_dist / maxf(goles, 1), suma_festeja / maxf(goles, 1), suma_parada / maxf(goles, 1)])
	quit()
