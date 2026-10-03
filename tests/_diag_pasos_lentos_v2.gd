extends SceneTree

## Medición: cuánto tarda cada paso del motor V2 en un partido real, como lo
## juega la pantalla (VistaPartidoV2). Un paso lento traba el cuadro en que
## cae. Imprime los pasos más lentos con lo que pasaba en ese momento (parada,
## acción del poseedor y de los que tocaron la pelota) y cuántos pasos pasan
## de 1, 2, 4 y 8 ms.
##
## Argumentos (después de `--`): `semilla=N`, `division=N`, `partidos=N`.

const SEED := 20261201
const PREFIJO := "[pasos_lentos]"


func _init() -> void:
	var semilla := SEED
	var division := 4
	var partidos := 3
	for arg in OS.get_cmdline_user_args():
		var p := arg.split("=", true, 1)
		if p.size() != 2:
			continue
		match p[0]:
			"semilla": semilla = int(p[1])
			"division": division = int(p[1])
			"partidos": partidos = int(p[1])
	var umbrales := [1.0, 2.0, 4.0, 8.0]
	var por_umbral := [0, 0, 0, 0]
	var peores: Array = []
	var total_pasos := 0
	var total_us := 0
	for n in partidos:
		var rng := RandomNumberGenerator.new()
		rng.seed = semilla + n
		var local: Team = Team.generar("Atlético Prueba", rng, 0, NivelDivision.potencial(division), "Uruguay",
			NivelDivision.realizacion(division))
		var visitante: Team = Team.generar("Deportivo Banco", rng, 1000, NivelDivision.potencial(division), "Uruguay",
			NivelDivision.realizacion(division))
		var r: Dictionary = MotorV2.simular(local, visitante, rng, true)
		var c: Object = CerebroV2.armar_de_receta(r["receta_v2"])
		var pasos := 0
		while str(c.get_estado()["periodo"]) != "terminado" and pasos < MotorV2.PASOS_TOPE:
			var t0 := Time.get_ticks_usec()
			c.avanzar()
			var us := Time.get_ticks_usec() - t0
			pasos += 1
			total_us += us
			var ms := us / 1000.0
			for k in umbrales.size():
				if ms > umbrales[k]:
					por_umbral[k] += 1
			if ms > 2.0:
				var e: Dictionary = c.get_estado()
				var pos := int(c.get_poseedor())
				var ult := int(c.get_ultimo_toque())
				peores.append({"ms": ms, "partido": n, "paso": pasos, "parada": str(e.get("parada", "")),
					"poseedor": c.get_accion(pos) if pos >= 0 else "-",
					"ultimo": c.get_accion(ult) if ult >= 0 else "-",
					"altura": snappedf(Vector3(c.get_pelota_pos()).y, 0.01),
					"rapidez": snappedf(Vector3(c.get_pelota_vel()).length(), 0.1)})
		total_pasos += pasos
	peores.sort_custom(func(a, b): return a["ms"] > b["ms"])
	print("%s %d partidos, %d pasos, media %.1f us" % [PREFIJO, partidos, total_pasos, float(total_us) / total_pasos])
	for k in umbrales.size():
		print("%s pasos de más de %.0f ms: %d" % [PREFIJO, umbrales[k], por_umbral[k]])
	for i in mini(peores.size(), 40):
		print("%s %s" % [PREFIJO, str(peores[i])])
	print("FALLOS=0")
	quit()
