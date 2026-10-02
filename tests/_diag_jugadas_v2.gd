extends SceneTree

## Medición de las jugadas preparadas en el Motor V2 (docs/motor_v2.md,
## etapa 8). Los mismos partidos dos veces: el local sin jugadas y el local
## sabiendo `jugada` (con Jugadas.USO en 1 para que salga siempre). Cuenta las
## veces que sale, qué pasa después y la diferencia de gol.
## Con `paradas=N` mide solo las de pelota parada: fuerza N córners y N tiros
## libres de frente (CanchitaV2Nativa.forzar_parada) sin la jugada y con ella.
## Argumentos (después de `--`): `partidos=N` (60), `division=N` (2),
## `paradas=N` (0).

const SEED := 20261401
const VENTANA_PASOS := 600


func _init() -> void:
	var partidos := 60
	var division := 2
	var paradas := 0
	for arg in OS.get_cmdline_user_args():
		var p := arg.split("=", true, 1)
		if p.size() == 2 and p[0] == "partidos":
			partidos = int(p[1])
		if p.size() == 2 and p[0] == "division":
			division = int(p[1])
		if p.size() == 2 and p[0] == "paradas":
			paradas = int(p[1])
	for id in Jugadas.USO:
		Jugadas.USO[id] = 1.0
	if paradas > 0:
		for caso in [["corner", ""], ["corner", Jugadas.CORNER_CORTO], ["corner", Jugadas.CORNER_BLOQUE],
				["tiro_libre", ""], ["tiro_libre", Jugadas.AMAGUE]]:
			var r := _paradas(caso[0], caso[1], paradas, division)
			print("%s %s: %d sacadas, goles %.1f%%, remates %.2f por saque, en contra %.1f%%" % [caso[0],
				caso[1] if caso[1] != "" else "sin jugada", r["n"], r["gol"], r["remates"], r["contra"]])
		quit()
		return
	var base := _serie("", partidos, division)
	print("sin jugadas: dif %.2f, offsides del rival %.2f, quites %.1f, goles de córner %.1f%% (%d córners), goles de tiro libre directo %.1f%% (%d)" % [
		base["dif"], base["offsides_rival"], base["quites"], base["gol_corner"], base["corners"], base["gol_directo"], base["directos"]])
	for jugada in [Jugadas.CORNER_CORTO, Jugadas.CORNER_BLOQUE, Jugadas.AMAGUE, Jugadas.DEFENSA_ADELANTADA,
			Jugadas.CONTRAPRESION]:
		var r := _serie(jugada, partidos, division)
		print("%s: sale %.2f por partido; dif %.2f (%+.2f); offsides del rival %.2f; quites %.1f; goles de córner %.1f%%; de tiro libre directo %.1f%%; remata el socio %d de %d" % [
			jugada, r["sale"], r["dif"], r["dif"] - base["dif"], r["offsides_rival"], r["quites"], r["gol_corner"],
			r["gol_directo"], r["remata_socio"], r["con_socio"]])
	quit()


## Fuerza `n` pelotas paradas del local y cuenta qué sale en los 10 s
## siguientes al saque.
func _paradas(tipo: String, jugada: String, n: int, division: int) -> Dictionary:
	var hechas := 0
	var goles := 0
	var contra := 0
	var remates := 0
	for k in n:
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + k
		var home: Team = Team.generar("Local", rng, 0, NivelDivision.potencial(division), "Uruguay",
			NivelDivision.realizacion(division))
		var away: Team = Team.generar("Visitante", rng, 1000, NivelDivision.potencial(division), "Uruguay",
			NivelDivision.realizacion(division))
		home.jugadas_aprendidas.clear()
		away.jugadas_aprendidas.clear()
		if jugada != "":
			home.jugadas_aprendidas.append(jugada)
		home.reset_partido()
		away.reset_partido()
		var c: Object = CerebroV2.armar(home, away, SEED + k, true)
		c.simular(60 * 8)
		var lado := 1.0 if k % 2 == 0 else -1.0
		var en := Vector2(ProyeccionPartido.MEDIO_LARGO, lado * ProyeccionPartido.MEDIO_ANCHO) if tipo == "corner" 			else Vector2(ProyeccionPartido.MEDIO_LARGO - 20.0 - float(k % 5), lado * float(k % 7))
		if not c.forzar_parada(tipo, 0, en):
			continue
		var saques_antes := (c.eventos() as Array).filter(func(v): return v["tipo"] == "saque").size()
		var sacado := false
		for paso in 60 * 25:
			c.avanzar()
			if (c.eventos() as Array).filter(func(v): return v["tipo"] == "saque").size() > saques_antes:
				sacado = true
				break
		if not sacado:
			continue
		var k0: Dictionary = c.contadores()
		c.simular(600)
		var k1: Dictionary = c.contadores()
		hechas += 1
		goles += int(k1["goles_0"]) - int(k0["goles_0"])
		contra += int(k1["goles_1"]) - int(k0["goles_1"])
		remates += int(k1["remates_0"]) - int(k0["remates_0"])
	return {"n": hechas, "gol": 100.0 * goles / maxf(hechas, 1), "contra": 100.0 * contra / maxf(hechas, 1),
		"remates": float(remates) / maxf(hechas, 1)}


func _serie(jugada: String, partidos: int, division: int) -> Dictionary:
	var dif := 0.0
	var sale := 0
	var offsides := 0
	var quites := 0
	var corners := 0
	var gol_corner := 0
	var directos := 0
	var gol_directo := 0
	var con_socio := 0
	var remata_socio := 0
	for n in partidos:
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + n
		var home: Team = Team.generar("Local", rng, 0, NivelDivision.potencial(division), "Uruguay",
			NivelDivision.realizacion(division))
		var away: Team = Team.generar("Visitante", rng, 1000, NivelDivision.potencial(division), "Uruguay",
			NivelDivision.realizacion(division))
		home.jugadas_aprendidas.clear()
		away.jugadas_aprendidas.clear()
		if jugada != "":
			home.jugadas_aprendidas.append(jugada)
		home.reset_partido()
		away.reset_partido()
		var c: Object = CerebroV2.armar(home, away, SEED + n, true)
		var pasos := 0
		while str(c.get_estado()["periodo"]) != "terminado" and pasos < MotorV2.PASOS_TOPE:
			c.simular(600)
			pasos += 600
		var goles: PackedInt32Array = c.get_goles()
		dif += goles[0] - goles[1]
		var eventos: Array = c.eventos()
		var remates: Array = c.registro_remates()
		for k in eventos.size():
			var ev: Dictionary = eventos[k]
			var tipo := str(ev["tipo"])
			if tipo == "jugada" and int(ev["equipo"]) == 0:
				sale += 1
				if int(ev["otro"]) >= 0:
					con_socio += 1
					for r in remates:
						if int(r["pateador_id"]) == int(ev["otro"]) and int(r["paso"]) >= int(ev["paso"]) \
								and int(r["paso"]) <= int(ev["paso"]) + 180:
							remata_socio += 1
							break
			elif tipo == "offside" and int(ev["equipo"]) == 1:
				offsides += 1
			elif tipo == "quite" and int(ev["equipo"]) == 0:
				quites += 1
			elif tipo == "saque" and int(ev["equipo"]) == 0 and int(ev["detalle"]) in [4, 5]:
				var corner := int(ev["detalle"]) == 4
				var directo := not corner and _es_directo(ev)
				if not corner and not directo:
					continue
				var gol := false
				for q in range(k + 1, eventos.size()):
					var sig: Dictionary = eventos[q]
					if int(sig["paso"]) > int(ev["paso"]) + VENTANA_PASOS or str(sig["tipo"]) == "saque":
						break
					if str(sig["tipo"]) == "gol" and int(sig["equipo"]) == 0:
						gol = true
				if corner:
					corners += 1
					gol_corner += 1 if gol else 0
				else:
					directos += 1
					gol_directo += 1 if gol else 0
	var p := float(partidos)
	return {"dif": dif / p, "sale": sale / p, "offsides_rival": offsides / p, "quites": quites / p,
		"corners": corners, "gol_corner": 100.0 * gol_corner / maxf(corners, 1), "directos": directos,
		"gol_directo": 100.0 * gol_directo / maxf(directos, 1), "con_socio": con_socio, "remata_socio": remata_socio}


## El tiro libre cerca del arco rival (el local ataca hacia +x en el primer
## tiempo; el motor no gira): a menos de 30 m del fondo.
func _es_directo(ev: Dictionary) -> bool:
	return ProyeccionPartido.MEDIO_LARGO - (ev["pos"] as Vector2).x < 30.0
