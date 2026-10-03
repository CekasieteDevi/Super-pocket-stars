extends SceneTree

## Medición: qué pasa con las pelotas que se reciben por arriba (revisión del
## 2026-10-03: "parece que cabecean cuando la quieren bajar de pecho", "hacen
## centros y la pierden cuando la controlan o les rebotan"). Por cada control
## (los contadores de recepciones de CanchitaV2Nativa) anota con qué parte fue,
## a qué altura venía la pelota, si fue en el área rival, y quién la toca
## después: el mismo, un compañero, un rival o nadie (sale). También cuenta
## los cabezazos al arco y su rapidez de salida.
##
##   <godot> --path . --headless --script tests/_diag_aereos_v2.gd -- partidos=40 a=4 b=4 semilla=97000

const SEED := 97000
const PARTES := ["pie", "muslo", "pecho", "cabeza"]
## Hasta cuándo se sigue un control para ver quién la toca después.
const SEGUIR_PASOS := 240
const AREA_LARGO_M := 16.5
const AREA_MEDIO_ANCHO_M := 20.16
const MEDIO_LARGO_M := 52.5


func _init() -> void:
	var partidos := 40
	var a := 4
	var b := 4
	var semilla := SEED
	for arg in OS.get_cmdline_user_args():
		var p := arg.split("=", true, 1)
		if p.size() != 2:
			continue
		match p[0]:
			"partidos": partidos = maxi(1, int(p[1]))
			"a": a = int(p[1])
			"b": b = int(p[1])
			"semilla": semilla = int(p[1])
	# parte -> {n, mismo, companero, rival, nadie, alto (suma), en_area}
	var por_parte := {}
	for parte in PARTES:
		por_parte[parte] = {"n": 0, "mismo": 0, "companero": 0, "rival": 0, "nadie": 0, "alto": 0.0, "en_area": 0,
			"en_area_pierde": 0}
	var alturas := {}
	var cabezazos := {"n": 0, "rapidez": 0.0, "gol": 0}
	for n in partidos:
		var c: Object = CerebroV2.armar_partido(semilla + n, "", "", a, b, true)
		var previo: Dictionary = c.contadores()
		var siguiendo := []
		var pasos := 0
		var remates_vistos := 0
		while str(c.get_estado()["periodo"]) != "terminado" and pasos < 60 * 60 * 12:
			var bola_antes: Vector3 = c.get_pelota_pos()
			c.avanzar()
			pasos += 1
			var k: Dictionary = c.contadores()
			var ult := int(c.get_ultimo_toque())
			var equipos: PackedInt32Array = c.get_equipos()
			for parte in PARTES:
				if int(k[parte]) > int(previo[parte]) and ult >= 0:
					var pos: Vector2 = c.get_pos()[ult]
					# El motor tiene al equipo 0 atacando siempre hacia +x.
					var ataca := 1.0 if int(equipos[ult]) == 0 else -1.0
					var en_area := absf(pos.x * ataca - (MEDIO_LARGO_M - AREA_LARGO_M * 0.5)) <= AREA_LARGO_M * 0.5 \
						and absf(pos.y) <= AREA_MEDIO_ANCHO_M
					var d: Dictionary = por_parte[parte]
					d["n"] += 1
					d["alto"] += bola_antes.y
					if en_area:
						d["en_area"] += 1
					var franja := "%s %.1f" % [parte, snappedf(bola_antes.y, 0.1)]
					alturas[franja] = int(alturas.get(franja, 0)) + 1
					siguiendo.append({"quien": ult, "equipo": int(equipos[ult]), "parte": parte, "desde": pasos,
						"en_area": en_area})
			previo = k
			# Quién la toca después de cada control seguido.
			var quedan := []
			for s in siguiendo:
				var parada := str(c.get_estado()["parada"])
				var res := ""
				if ult >= 0 and ult != int(s["quien"]):
					res = "companero" if int(equipos[ult]) == int(s["equipo"]) else "rival"
				elif parada != "" and parada != "nada":
					res = "nadie"
				elif ult == int(s["quien"]) and pasos - int(s["desde"]) > 30 and int(c.get_poseedor()) == ult:
					res = "mismo"
				elif pasos - int(s["desde"]) > SEGUIR_PASOS:
					res = "mismo" if int(c.get_poseedor()) == int(s["quien"]) else "nadie"
				if res == "":
					quedan.append(s)
					continue
				var d: Dictionary = por_parte[s["parte"]]
				d[res] += 1
				if s["en_area"] and res in ["rival", "nadie"]:
					d["en_area_pierde"] += 1
			siguiendo = quedan
		for r in c.registro_remates():
			if int(r.get("golpe", -1)) == 4:
				cabezazos["n"] += 1
				cabezazos["rapidez"] += float(r.get("rapidez", 0.0))
				if int(r.get("resultado", -1)) == 0:
					cabezazos["gol"] += 1
	print("[aereos] %d partidos D%d/D%d" % [partidos, a + 1, b + 1])
	for parte in PARTES:
		var d: Dictionary = por_parte[parte]
		var n := maxi(int(d["n"]), 1)
		print("[aereos] %-6s %5d controles (%.1f por partido), alto medio %.2f m; después: el mismo %2.0f%%, compañero %2.0f%%, rival %2.0f%%, nadie %2.0f%%; en el área rival %d, pierde %d" % [
			parte, d["n"], float(d["n"]) / partidos, d["alto"] / n, 100.0 * d["mismo"] / n, 100.0 * d["companero"] / n,
			100.0 * d["rival"] / n, 100.0 * d["nadie"] / n, d["en_area"], d["en_area_pierde"]])
	var claves := alturas.keys()
	claves.sort()
	var linea := ""
	for f in claves:
		linea += "%s: %d  " % [f, alturas[f]]
	print("[aereos] alturas: ", linea)
	if int(cabezazos["n"]) > 0:
		print("[aereos] cabezazos al arco: %.2f por partido, salen a %.1f m/s, goles %d" % [float(cabezazos["n"]) / partidos,
			cabezazos["rapidez"] / cabezazos["n"], cabezazos["gol"]])
	print("FALLOS=0")
	quit()
