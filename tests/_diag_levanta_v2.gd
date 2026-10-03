extends SceneTree

## Medición: qué hace el arquero cuando termina de tirarse (revisión del
## 2026-10-03: "cuando le meten gol se para instantáneamente"). Por cada
## estirada que termina, anota si sigue con Arquero_Levanta y en qué
## situación (gol o parada, con la pelota en las manos, o en juego), y cuenta
## los goles, para comparar el balance antes y después.
##
##   <godot> --path . --headless --script tests/_diag_levanta_v2.gd -- partidos=100 a=4 b=4 semilla=97000

const SEED := 97000
const ESTIRADAS := ["Atajar_Volando", "Atajar_Volando_Izq", "Atajar_Volando_Alto", "Atajar_Volando_Alto_Izq"]


func _init() -> void:
	var partidos := 100
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
	var cuenta := {"parada": [0, 0], "en_manos": [0, 0], "en_juego": [0, 0]}
	var goles := 0
	for n in partidos:
		var c: Object = CerebroV2.armar_partido(semilla + n, "", "", a, b, true)
		var antes := {}
		var pasos := 0
		while str(c.get_estado()["periodo"]) != "terminado" and pasos < 60 * 60 * 12:
			c.avanzar()
			pasos += 1
			var arqueros: PackedInt32Array = c.get_arqueros()
			for i in arqueros.size():
				if arqueros[i] != 1:
					continue
				var accion: String = c.get_accion(i)
				var previa: String = antes.get(i, "")
				if previa in ESTIRADAS and accion != previa:
					var donde := "en_juego"
					if str(c.get_estado()["parada"]) != "nada":
						donde = "parada"
					elif int(c.get_en_manos()) == i:
						donde = "en_manos"
					cuenta[donde][0] += 1
					if accion.begins_with("Arquero_Levanta"):
						cuenta[donde][1] += 1
				antes[i] = accion
		var g: PackedInt32Array = c.get_goles()
		goles += g[0] + g[1]
	for donde in cuenta:
		print("[levanta] %-9s %4d estiradas que terminan, %4d se levantan" % [donde, cuenta[donde][0], cuenta[donde][1]])
	print("[levanta] %.2f goles por partido" % (float(goles) / partidos))
	print("FALLOS=0")
	quit()
