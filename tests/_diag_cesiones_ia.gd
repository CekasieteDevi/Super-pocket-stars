extends SceneTree

## Medicion, no test: cuantas cesiones hacen entre ellos los clubes de la
## IA en una ventana de pases, de quien a quien, y si el cedido juega.
##
## Antes de Cesiones.ronda_ia no habia ninguna: la IA no se prestaba
## jugadores entre ella.
##
## Uso:
##   <godot> --path . --headless --script tests/_diag_cesiones_ia.gd

const SEED := 8282
const DIAS_VENTANA := 90
const CORRIDAS := 5
const DIVISION_PROPIA := 6


func _init() -> void:
	var inicio := Time.get_ticks_msec()
	var total := 0
	var titulares := 0
	var desde_cantera := 0
	var por_salto := {}
	var por_division_dueno := {}
	var suma_edad := 0.0
	var suma_ventaja := 0.0
	var suma_fee_pct := 0.0
	var duenos := {}
	var reservas_jovenes := 0
	for corrida in range(CORRIDAS):
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + corrida
		var piramide := Piramide.generar(rng)
		var gs = load("res://game/game_state.gd").new()
		gs.piramide = piramide
		gs.rng = rng
		gs.temporada_actual = 1
		gs.division_jugador = DIVISION_PROPIA
		gs.equipo_jugador = piramide.divisiones[DIVISION_PROPIA].equipos[0]
		gs._sembrar_presupuestos()
		for liga in piramide.divisiones:
			for e in liga.equipos:
				for j in e.banco + e.reservas + e.cantera:
					if int(j.get("edad", 99)) <= Cesiones.EDAD_MAX_CEDIBLE_IA:
						reservas_jovenes += 1
		for dia in range(DIAS_VENTANA):
			var hechas := Cesiones.ronda_ia(piramide, rng, 1, gs.equipo_jugador, 1.0 + dia / 365.0)
			for h in hechas:
				var dueno: Team = h["dueno"]
				var pide: Team = h["pide"]
				var j: Dictionary = h["jugador"]
				total += 1
				duenos[dueno.nombre] = true
				var d_dueno := _division(piramide, dueno)
				var salto := _division(piramide, pide) - d_dueno
				por_salto[salto] = int(por_salto.get(salto, 0)) + 1
				por_division_dueno[d_dueno + 1] = int(por_division_dueno.get(d_dueno + 1, 0)) + 1
				suma_edad += float(j["edad"])
				suma_ventaja += float(j["media"]) - pide.media_equipo()
				var valor := ValorJugador.calcular(j, 50.0, 1)
				if valor > 0.0:
					suma_fee_pct += float(h["fee"]) / valor
				if bool(dueno.prestados_afuera[int(j["id"])]["desde_cantera"]):
					desde_cantera += 1
				for t in pide.jugadores:
					if int(t["id"]) == int(j["id"]):
						titulares += 1
						break
		gs.free()

	var n := float(CORRIDAS)
	print("## Cesiones entre clubes de la IA - semilla %d, %d corridas de %d dias" % [SEED, CORRIDAS, DIAS_VENTANA])
	print("  banco, reservas y cantera de hasta %d años en la piramide: %.0f" % [Cesiones.EDAD_MAX_CEDIBLE_IA, reservas_jovenes / n])
	print("  cesiones por ventana: %.1f" % (total / n))
	print("  clubes que ceden por ventana: %.1f" % (duenos.size() / n))
	if total == 0:
		quit()
		return
	var t := float(total)
	print("  entran de titular al club que pide: %.0f%%" % (100.0 * titulares / t))
	print("  salen de la cantera: %.0f%%" % (100.0 * desde_cantera / t))
	print("  edad media: %.1f" % (suma_edad / t))
	print("  media del cedido - media del que pide: %+.1f (al ceder, ya con el cedido adentro)" % (suma_ventaja / t))
	print("  fee medio: %.1f%% del valor" % (100.0 * suma_fee_pct / t))
	print("  por division del dueño: %s" % [por_division_dueno])
	print("  por divisiones de diferencia (pide - dueño): %s" % [por_salto])
	print("ms totales: %d" % (Time.get_ticks_msec() - inicio))
	quit()


func _division(piramide, equipo: Team) -> int:
	for d in range(piramide.divisiones.size()):
		if piramide.divisiones[d].equipos.has(equipo):
			return d
	return -1
