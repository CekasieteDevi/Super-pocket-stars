extends SceneTree

## Mismos planteles y semillas por estilo. Mide decisiones y movimientos
## reales, no los pesos que se pretende que produzcan esas decisiones.
const SEED := 64120
const PARTIDOS := 12
const ESTILOS := ["Tiki taka", "Contragolpe", "Presión alta"]

func _init() -> void:
	for division in [9, 0]:
		for estilo in ESTILOS:
			var total := {"posesion": 0.0, "vivos": 0.0, "pases": 0.0,
				"largos": 0.0, "atras": 0.0, "huecos": 0.0, "paredes": 0.0,
				"conduccion_m": 0.0, "linea": 0.0, "defendiendo": 0.0,
				"ancho": 0.0, "robos_altos": 0.0, "goles": 0.0}
			for i in range(PARTIDOS):
				_medir(division, estilo, i, total)
			print("D%d %-12s posesion=%.1f%% pases=%.1f largos=%.1f atras=%.1f%% huecos=%.1f paredes=%.1f conduccion=%.1fm linea=%.1fm ancho=%.1fm robos_altos=%.1f goles_totales=%.2f" % [
				division + 1, estilo, 100.0 * total.posesion / maxf(total.vivos, 1),
				total.pases / PARTIDOS, total.largos / PARTIDOS,
				100.0 * total.atras / maxf(total.pases, 1), total.huecos / PARTIDOS,
				total.paredes / PARTIDOS, total.conduccion_m / PARTIDOS,
				total.linea / maxf(total.defendiendo, 1), total.ancho / maxf(total.posesion, 1),
				total.robos_altos / PARTIDOS, total.goles / PARTIDOS])
	quit()

func _medir(division: int, estilo: String, indice: int, total: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + indice
	var a := Team.generar("A", rng, 0, NivelDivision.potencial(division), "Uruguay", NivelDivision.realizacion(division))
	var b := Team.generar("B", rng, 400, NivelDivision.potencial(division), "Uruguay", NivelDivision.realizacion(division))
	a.estilo = estilo
	b.estilo = "Juego directo"
	a.reset_partido()
	b.reset_partido()
	a.local = true
	b.local = false
	a.clima_partido = "normal"
	b.clima_partido = a.clima_partido
	a.arbitro_partido = Arbitro.generar(rng)
	b.arbitro_partido = a.arbitro_partido
	var s := MotorEspacial.crear_estado(a, b, rng)
	var ultimo_local := true
	for mitad in range(2):
		MotorEspacial._reiniciar_desde_medio(s, mitad == 0, mitad + 1)
		for t in range(MotorEspacial.TICKS_POR_MITAD):
			var id_antes: int = s.pelota.poseedor_id
			var pos_antes: Vector2 = s.pelota.pos
			var era_local: bool = id_antes != -1 and s.jugadores.has(id_antes) and s.jugadores[id_antes].equipo_local
			var decisiones_antes: Dictionary = s.decisiones.duplicate()
			MotorEspacial._tick(s, false)
			if int(s.get("detenido", 0)) > 0:
				continue
			var id: int = s.pelota.poseedor_id
			if era_local:
				if id == id_antes:
					total.conduccion_m += pos_antes.distance_to(s.pelota.pos)
				for tipo in s.decisiones:
					if int(s.decisiones[tipo]) == int(decisiones_antes.get(tipo, 0)):
						continue
					if tipo in ["pase", "pase_largo", "pase_hueco", "pared", "cambio_frente", "pase_atras"]:
						total.pases += 1
						var destino: Vector2 = s.pelota.get("destino_pos", pos_antes)
						if destino.x < pos_antes.x - 2.0:
							total.atras += 1
						if destino.distance_to(pos_antes) >= 28.0:
							total.largos += 1
					if tipo == "pase_hueco": total.huecos += 1
					if tipo == "pared": total.paredes += 1
			if id == -1 or not s.jugadores.has(id):
				continue
			var local: bool = s.jugadores[id].equipo_local
			total.vivos += 1
			if local:
				total.posesion += 1
				if not ultimo_local and s.pelota.pos.x > 0:
					total.robos_altos += 1
				var inferior := INF
				var superior := -INF
				for e in s.jugadores.values():
					if e.equipo_local and e.rol != "ARQ":
						inferior = minf(inferior, e.pos.y)
						superior = maxf(superior, e.pos.y)
				total.ancho += superior - inferior
			else:
				for e in s.jugadores.values():
					if e.equipo_local and e.rol == "DFC":
						total.linea += e.pos.x + MotorEspacial.MEDIO_LARGO
						total.defendiendo += 1
			ultimo_local = local
	total.goles += a.goles + b.goles
