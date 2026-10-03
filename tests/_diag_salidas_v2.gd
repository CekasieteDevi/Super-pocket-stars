extends SceneTree

## Medición: el arquero que sale a una pelota alta de su área (un centro) y
## no la toca (revisión del 2026-10-03: "salió a buscar un centro y le pasó
## por arriba; debería pasar cuando el golero es malo"). Cuenta por partido
## las salidas que no son a un remate, cuántas falla y los goles, para un
## arquero de primera y uno de décima.
##
##   <godot> --path . --headless --script tests/_diag_salidas_v2.gd -- partidos=200 semilla=97000

const SEED := 97000


func _init() -> void:
	var partidos := 200
	var semilla := SEED
	for arg in OS.get_cmdline_user_args():
		var p := arg.split("=", true, 1)
		if p.size() == 2 and p[0] == "partidos":
			partidos = int(p[1])
		elif p.size() == 2 and p[0] == "semilla":
			semilla = int(p[1])
	for division in [0, 9]:
		var suma := {}
		var goles := 0
		for n in partidos:
			var c: Object = CerebroV2.armar_partido(semilla + n, "", "", division, division, true)
			var pasos := 0
			while str(c.get_estado()["periodo"]) != "terminado" and pasos < 60 * 60 * 12:
				c.simular(600)
				pasos += 600
			var k: Dictionary = c.contadores()
			for clave in ["salidas_arquero", "salidas_falladas", "salidas_por_arriba", "salidas_lejos", "atajadas_falladas", "agarres", "estiradas", "paradas"]:
				suma[clave] = float(suma.get(clave, 0.0)) + float(k.get(clave, 0))
			var g: PackedInt32Array = c.get_goles()
			goles += g[0] + g[1]
		var texto := ""
		for clave in suma:
			texto += "%s %.2f  " % [clave, suma[clave] / partidos]
		print("[salidas] D%d: %s goles %.2f" % [division + 1, texto, float(goles) / partidos])
	print("FALLOS=0")
	quit()
