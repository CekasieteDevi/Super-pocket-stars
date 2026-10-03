extends SceneTree

## Motor V2: el arquero que se tira queda en el piso, 1,3 m al costado de su
## lugar (la cadera del clip). Con la pelota fuera de juego (gol, afuera) o en
## sus manos se levanta con Arquero_Levanta; con la pelota suelta en juego se
## para enseguida, para llegar al rebote (Canchita::_levantarse). Antes pasaba
## de tirado a parado en un cuadro.

const SEED := 97000
const PARTIDOS := 30
const ESTIRADAS := ["Atajar_Volando", "Atajar_Volando_Izq", "Atajar_Volando_Alto", "Atajar_Volando_Alto_Izq"]

var fallos := 0


func _init() -> void:
	var cuenta := {"parada": [0, 0], "en_manos": [0, 0], "en_juego": [0, 0]}
	for n in PARTIDOS:
		var c: Object = CerebroV2.armar_partido(SEED + n, "", "", 4, 4, true)
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
				if str(antes.get(i, "")) in ESTIRADAS and accion != antes[i]:
					var donde := "en_juego"
					if str(c.get_estado()["parada"]) != "nada":
						donde = "parada"
					elif int(c.get_en_manos()) == i:
						donde = "en_manos"
					cuenta[donde][0] += 1
					if accion.begins_with("Arquero_Levanta"):
						cuenta[donde][1] += 1
				antes[i] = accion
	var p: Array = cuenta["parada"]
	var m: Array = cuenta["en_manos"]
	var j: Array = cuenta["en_juego"]
	_ok(p[0] > 0 and p[1] >= 0.9 * p[0], "con la pelota fuera de juego se levanta (%d de %d)" % [p[1], p[0]])
	_ok(m[0] == 0 or m[1] == m[0], "con la pelota en las manos se levanta (%d de %d)" % [m[1], m[0]])
	_ok(j[1] == 0, "con la pelota en juego se para enseguida (%d de %d se levantan)" % [j[1], j[0]])
	print("FALLOS=%d" % fallos)
	quit(1 if fallos else 0)


func _ok(condicion: bool, mensaje: String) -> void:
	print(("OK: " if condicion else "FALLA: ") + mensaje)
	if not condicion:
		fallos += 1
