extends SceneTree

## Etapa 7 del Motor V2 (docs/motor_v2.md): en un partido desparejo, cuánto
## aprieta, quita y hace falta cada equipo. Mismos planteles que
## tests/_diag_calibracion_v2.gd, ida y vuelta. No es un test: mide.
##
##   <godot> --path . --headless --script tests/_diag_desparejo_v2.gd -- parejas=50 semilla=97000

const SEED := 97000
const MEDIO_LARGO_M := 52.5
## Cada cuántos pasos se mira la cancha (0,1 s).
const CADA_PASOS := 6
## Aprieta: tiene un hombre a menos de toque.presion_m del que lleva la pelota.
const PRESION_M := 3.0
## El parejo de quinta, de referencia, y los tres de tres divisiones de
## diferencia de tests/_diag_calibracion_v2.gd (0 = primera).
const ESCENARIOS := [[4, 4], [0, 3], [4, 7], [9, 6]]
const ESTILOS := [["Tiki taka", "Juego directo"], ["Presión alta", "Contragolpe"]]


func _init() -> void:
	var parejas := 50
	var semilla := SEED
	for arg in OS.get_cmdline_user_args():
		var p := arg.split("=", true, 1)
		if p.size() != 2:
			continue
		match p[0]:
			"parejas": parejas = maxi(1, int(p[1]))
			"semilla": semilla = int(p[1])
	print("[desparejo] %d partidos por escenario, semilla %d. Por partido, de cada equipo." % [parejas * 2, semilla])
	print("[desparejo] %-14s %7s %7s %7s %8s %8s %9s %9s %8s" % ["equipo", "poses.", "faltas", "quites", "recup.", "altura m",
		"rival seg", "aprieta %", "dist. m"])
	for esc in ESCENARIOS:
		# Índice 0: el equipo A; 1: el B.
		var k := []
		for lado in 2:
			k.append({"posesion": 0.0, "faltas": 0.0, "quites": 0.0, "recup": 0.0, "altura": 0.0, "rival_pasos": 0.0,
				"tramos": 0.0, "aprieta": 0.0, "muestras": 0.0, "dist": 0.0})
		for indice in parejas:
			for vuelta in [false, true]:
				# Cada corrida arma los planteles de nuevo: el partido muta al Team.
				var generador := RandomNumberGenerator.new()
				generador.seed = semilla + indice
				var a := Team.generar("A", generador, 0, NivelDivision.potencial(esc[0]), "Uruguay", NivelDivision.realizacion(esc[0]))
				var b := Team.generar("B", generador, 400, NivelDivision.potencial(esc[1]), "Uruguay", NivelDivision.realizacion(esc[1]))
				a.estilo = ESTILOS[indice % ESTILOS.size()][0]
				b.estilo = ESTILOS[indice % ESTILOS.size()][1]
				var c: Object = CerebroV2.armar(b if vuelta else a, a if vuelta else b, semilla + indice, true)
				# de_lado[lado del motor] = índice en k.
				var de_lado := [1, 0] if vuelta else [0, 1]
				var previo := -1
				var desde := 0
				var pasos := 0
				while str(c.get_estado()["periodo"]) != "terminado" and pasos < 60 * 60 * 20:
					c.simular(CADA_PASOS)
					pasos += CADA_PASOS
					if str(c.get_estado()["parada"]) != "nada":
						previo = -1
						desde = 0
						continue
					var equipo := int(c.get_equipo_con_pelota())
					var poseedor := int(c.get_poseedor())
					if poseedor >= 0:
						# El que defiende: a cuánto tiene a su hombre más cercano del que la lleva.
						var pos: PackedVector2Array = c.get_pos()
						var equipos: PackedInt32Array = c.get_equipos()
						var con := int(equipos[poseedor])
						var cerca := 1e9
						for i in pos.size():
							if int(equipos[i]) != con:
								cerca = minf(cerca, pos[i].distance_to(pos[poseedor]))
						var d: Dictionary = k[de_lado[1 - con]]
						d["muestras"] += 1.0
						d["dist"] += cerca
						if cerca < PRESION_M:
							d["aprieta"] += 1.0
					if previo >= 0 and equipo >= 0 and equipo != previo:
						# La recupera `equipo`. Altura desde su línea de fondo: el
						# lado 0 del motor ataca hacia +x.
						var x: float = c.get_pelota_pos().x
						var r: Dictionary = k[de_lado[equipo]]
						r["recup"] += 1.0
						r["altura"] += (x if equipo == 0 else -x) + MEDIO_LARGO_M
						if desde > 0:
							r["rival_pasos"] += pasos - desde
							r["tramos"] += 1.0
						desde = pasos
					if equipo >= 0:
						previo = equipo
				for e in c.eventos():
					if str(e["tipo"]) == "quite":
						k[de_lado[int(e["equipo"])]]["quites"] += 1.0
				var cuenta: Dictionary = c.contadores()
				var total := maxf(float(cuenta["posesion_0"]) + float(cuenta["posesion_1"]), 1.0)
				for lado in 2:
					k[de_lado[lado]]["posesion"] += 100.0 * float(cuenta["posesion_%d" % lado]) / total
					k[de_lado[lado]]["faltas"] += float(cuenta["faltas_%d" % lado])
		var n := float(parejas * 2)
		for lado in 2:
			var d: Dictionary = k[lado]
			print("[desparejo] %-14s %6.1f%% %7.2f %7.2f %8.1f %8.1f %9.2f %8.0f%% %8.1f" % [
				"D%d (con D%d)" % [esc[lado] + 1, esc[1 - lado] + 1], d["posesion"] / n, d["faltas"] / n, d["quites"] / n,
				d["recup"] / n, d["altura"] / maxf(d["recup"], 1.0), d["rival_pasos"] / maxf(d["tramos"], 1.0) / 60.0,
				100.0 * d["aprieta"] / maxf(d["muestras"], 1.0), d["dist"] / maxf(d["muestras"], 1.0)])
	print("[desparejo] recup.: veces que le saca la pelota al rival con el juego andando, y a cuántos metros de su fondo. rival seg: lo que la tuvo el rival antes. aprieta: parte del tiempo en que el rival la tiene dominada y hay un hombre suyo a menos de 3 m. dist.: a cuánto está ese hombre de media.")
	quit()
