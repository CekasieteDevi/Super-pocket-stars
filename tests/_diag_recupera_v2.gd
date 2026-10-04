extends SceneTree

## Etapa 7b del Motor V2 (docs/motor_v2.md): dónde recupera la pelota el local
## con cada estilo de Estilos.LISTA, contra un visitante de "Juego directo".
## Las alturas son metros desde su línea de fondo. No es un test: mide.
##
##   <godot> --path . --headless --script tests/_diag_recupera_v2.gd -- partidos=60 division=4 semilla=97000

const SEED := 97000
const RIVAL := "Juego directo"
const MEDIO_LARGO_M := 52.5
## Cada cuántos pasos se mira quién tiene la pelota (0,1 s).
const CADA_PASOS := 6
## El último tercio: a más de esto de su línea de fondo.
const ULTIMO_TERCIO_M := 70.0


func _init() -> void:
	var partidos := 60
	var division := 4
	var semilla := SEED
	for arg in OS.get_cmdline_user_args():
		var p := arg.split("=", true, 1)
		if p.size() != 2:
			continue
		match p[0]:
			"partidos": partidos = maxi(1, int(p[1]))
			"division": division = int(p[1])
			"semilla": semilla = int(p[1])
	print("[recupera] D%d, %d partidos por estilo, semilla %d. El local con cada estilo contra %s. Por partido, del local." % [
		division + 1, partidos, semilla, RIVAL])
	print("[recupera] %-14s %7s %8s %8s %8s %9s %7s %8s %8s" % ["estilo", "recup.", "altura m", "campo r.", "ult.ter.",
		"rival seg", "quites", "altura m", "poses."])
	for estilo in Estilos.LISTA:
		var k := {"n": 0.0, "altura": 0.0, "campo_rival": 0.0, "ultimo_tercio": 0.0, "rival_pasos": 0.0, "tramos": 0.0,
			"quites": 0.0, "quites_altura": 0.0, "posesion": 0.0}
		for i in partidos:
			var c: Object = CerebroV2.armar_partido(semilla + i, estilo, RIVAL, division, division, true)
			# El equipo 0 ataca siempre hacia +x en el motor.
			var previo := -1
			var desde := 0
			var pasos := 0
			while str(c.get_estado()["periodo"]) != "terminado" and pasos < 60 * 60 * 20:
				c.simular(CADA_PASOS)
				pasos += CADA_PASOS
				if str(c.get_estado()["parada"]) != "nada":
					# La pelota que se repone no es una recuperación.
					previo = -1
					desde = 0
					continue
				var equipo := int(c.get_equipo_con_pelota())
				if previo == 0 and equipo == 1:
					desde = pasos
				elif previo == 1 and equipo == 0:
					var x: float = c.get_pelota_pos().x + MEDIO_LARGO_M
					k["n"] += 1.0
					k["altura"] += x
					if x > MEDIO_LARGO_M:
						k["campo_rival"] += 1.0
					if x > ULTIMO_TERCIO_M:
						k["ultimo_tercio"] += 1.0
					if desde > 0:
						k["rival_pasos"] += pasos - desde
						k["tramos"] += 1.0
				previo = equipo
			for e in c.eventos():
				if str(e["tipo"]) == "quite" and int(e["equipo"]) == 0:
					k["quites"] += 1.0
					k["quites_altura"] += float(e["pos"].x) + MEDIO_LARGO_M
			var cuenta: Dictionary = c.contadores()
			k["posesion"] += 100.0 * float(cuenta["posesion_0"]) / maxf(float(cuenta["posesion_0"]) + float(cuenta["posesion_1"]), 1.0)
		var n := maxf(k["n"], 1.0)
		print("[recupera] %-14s %7.1f %8.1f %7.0f%% %7.0f%% %9.2f %7.1f %8.1f %7.1f%%" % [estilo, k["n"] / partidos,
			k["altura"] / n, 100.0 * k["campo_rival"] / n, 100.0 * k["ultimo_tercio"] / n,
			k["rival_pasos"] / maxf(k["tramos"], 1.0) / 60.0, k["quites"] / partidos,
			k["quites_altura"] / maxf(k["quites"], 1.0), k["posesion"] / partidos])
	print("[recupera] recup.: veces que la pelota pasa del rival al local con el juego andando. campo r.: en campo rival. ult.ter.: a más de 70 m de su fondo. rival seg: lo que la tuvo el rival antes de perderla. quites: al que la tenía dominada.")
	quit()
