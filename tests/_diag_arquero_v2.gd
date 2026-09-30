extends SceneTree

## Medición de la etapa 5 del Motor V2 (docs/motor_v2.md): remates sueltos en
## el modo ARCO contra un arquero solo, a una grilla de puntos del arco desde
## varias distancias. Imprime qué clip eligió el arquero, si tocó la pelota y
## cómo terminó cada uno. No es un test: mide.
##   <godot> --path . --headless --script tests/_diag_arquero_v2.gd -- golpe=0 atributo=70 repeticiones=20

const SEED := 20261005


func _init() -> void:
	var golpe := 0
	var atributo := 70.0
	var repeticiones := 20
	var arquero := 70.0
	for arg in OS.get_cmdline_user_args():
		var partes := arg.split("=", true, 1)
		if partes.size() != 2:
			continue
		match partes[0]:
			"golpe": golpe = int(partes[1])
			"atributo": atributo = float(partes[1])
			"arquero": arquero = float(partes[1])
			"repeticiones": repeticiones = int(partes[1])
	var nombres := ["gol", "atajado", "palo", "bloqueado", "afuera", "otro"]
	for distancia in [11.0, 16.0, 22.0, 28.0]:
		for lateral in [0.0, 1.5, 2.3, 3.2]:
			for alto in [0.2, 1.0, 1.9]:
				var cuenta := {}
				var clips := {}
				for r in repeticiones:
					var res := remate(SEED + r, distancia, lateral, alto, golpe, atributo, arquero)
					cuenta[nombres[res["resultado"]]] = int(cuenta.get(nombres[res["resultado"]], 0)) + 1
					clips[res["clip"]] = int(clips.get(res["clip"], 0)) + 1
				print("[diag_arquero] d %4.0f lat %.1f alto %.1f: %s  clips %s" % [distancia, lateral, alto, cuenta, clips])
	quit()


## Un remate: el 0 patea desde (52,5 - distancia, 0) al punto (alto, lateral)
## del arco de +x, que defiende el arquero (1) parado en su línea.
static func remate(semilla: int, distancia: float, lateral: float, alto: float, golpe: int, atributo: float,
		arquero: float) -> Dictionary:
	var c: Object = ClassDB.instantiate("CanchitaV2Nativa")
	c.configurar(FisicaV2.parametros(), FisicaV2.parametros_cuerpo(), FisicaV2.clips(), FisicaV2.parametros_toque())
	c.configurar_remate(FisicaV2.parametros_remate(), FisicaV2.parametros_arquero())
	var a := {"velocidad": 70.0, "aceleracion": 70.0, "agilidad": 70.0, "pases": 70.0, "control": 70.0,
		"tiro": atributo, "golpe": atributo, "cabezazo": atributo}
	c.agregar(0, FisicaV2.jugador_de(a).merged(a))
	var g := {"velocidad": 60.0, "aceleracion": 60.0, "agilidad": 60.0, "reflejos": arquero, "estirada": arquero,
		"agarre": arquero, "achique": arquero, "arquero": true}
	c.agregar(1, FisicaV2.jugador_de(g).merged(g))
	c.empezar(CanchitaV2Nativa.ARCO, semilla)
	var x := 52.5 - distancia
	c.poner_jugador(0, Vector2(x - 0.6, 0.0), PI * 0.5)
	c.poner_jugador(1, Vector2(51.7, 0.0), -PI * 0.5)
	c.rematar(0, golpe, alto, lateral)
	c.lanzar(Vector3(x, 0.11, 0.0), Vector3.ZERO, Vector3.ZERO, 0)
	var clip := ""
	for paso in 240:
		c.avanzar()
		var accion: String = c.get_accion(1)
		if accion != "" and clip == "":
			clip = accion
		if c.get_ultimo_resultado() >= 0:
			break
	var fin := int(c.get_ultimo_resultado())
	return {"resultado": fin if fin >= 0 else 5, "clip": clip}
