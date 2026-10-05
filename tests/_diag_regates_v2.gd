extends SceneTree

## BUG-012 (docs/bugs_pendientes.md): los regates del Motor V2. Juega partidos
## con reglas y sin vista y cuenta, por partido: cuántas veces el poseedor
## decide encarar, cuántos gestos de regate arrancan, cuántos amagues se come
## el rival, cuántos terminan con la pelota en el equipo del que encaró, y lo
## que el regate puede mover (quites, faltas, remates y goles). No es un
## test: mide.
##
##   <godot> --path . --headless --script tests/_diag_regates_v2.gd -- partidos=60 a=4 b=4 semilla=97000
##
## `fisica=seccion.clave:valor,...` pisa data/fisica_v2.json en memoria. Con
## `fisica=cerebro.regate_factor:0` nadie encara: es la medida de antes.

const SEED := 97000
const ESTILOS := [["Tiki taka", "Juego directo"], ["Presión alta", "Contragolpe"]]
## Minutos de verdad que puede durar un partido (dura unos 5): pasado esto
## quedó colgado.
const PASOS_TOPE := 60 * 60 * 20


func _init() -> void:
	var partidos := 60
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
			"fisica": _pisar(FisicaV2.datos(), p[1])
	var k := {}
	var decide := 0.0
	var decisiones := 0.0
	var relatados := {}
	for n in partidos:
		var e: Array = ESTILOS[n % ESTILOS.size()]
		var c: Object = CerebroV2.armar_partido(semilla + n, e[0], e[1], a, b, true)
		var pasos := 0
		while str(c.get_estado()["periodo"]) != "terminado" and pasos < PASOS_TOPE:
			c.simular(600)
			pasos += 600
		var cuenta: Dictionary = c.contadores()
		for clave in cuenta:
			if typeof(cuenta[clave]) == TYPE_INT or typeof(cuenta[clave]) == TYPE_FLOAT:
				k[clave] = float(k.get(clave, 0.0)) + float(cuenta[clave])
		var cerebro: Dictionary = c.contadores_cerebro()
		decide += float(cerebro.get("regate", 0))
		for tipo in ["conducir", "pase", "pase_hueco", "pase_largo", "centro", "pared", "despeje", "remate", "regate"]:
			decisiones += float(cerebro.get(tipo, 0))
		for ev in c.eventos():
			if str(ev["tipo"]) == "regate":
				var cual := int(ev["detalle"])
				relatados[cual] = int(relatados.get(cual, 0)) + 1
	var f := func(clave: String) -> float: return float(k.get(clave, 0.0)) / float(partidos)
	var intentos := maxf(float(k.get("regates", 0.0)), 1.0)
	print("[regates] D%d/D%d, %d partidos, semilla %d. Por partido." % [a + 1, b + 1, partidos, semilla])
	print("[regates] Decide encarar %.2f veces (%.2f%% de las decisiones); gestos de regate %.2f; el rival se come el amague %.2f (%.0f%%); la pelota sigue en su equipo %.2f (%.0f%% de los gestos)" % [
		decide / partidos, 100.0 * decide / maxf(decisiones, 1.0), f.call("regates"), f.call("regates_amague"),
		100.0 * float(k.get("regates_amague", 0.0)) / intentos, f.call("regates_ganados"),
		100.0 * float(k.get("regates_ganados", 0.0)) / intentos])
	print("[regates] Por regate (relatados): elástica %.2f, croqueta %.2f" % [
		float(relatados.get(0, 0)) / partidos, float(relatados.get(1, 0)) / partidos])
	print("[regates] Quites %.2f (al que conduce %.2f, al que controla %.2f); entradas %.2f; faltas %.2f; gestos que no llegan a la pelota %.2f" % [
		f.call("quites"), f.call("quites_conduccion"), f.call("quites_control"), f.call("entradas"),
		f.call("faltas_0") + f.call("faltas_1"), f.call("fallos")])
	print("[regates] Goles %.2f; remates %.2f; pases %.2f (completos %.2f); la pelota sale conduciendo %.2f veces" % [
		f.call("goles_0") + f.call("goles_1"), f.call("remates"), f.call("pases"), f.call("completados"),
		f.call("salidas_conduce")])
	quit()


func _pisar(datos: Dictionary, texto: String) -> void:
	for par in texto.split(","):
		var kv := par.split(":")
		var clave := kv[0].split(".")
		datos[clave[0]][clave[1]] = float(kv[1])
		print("FISICA %s = %s" % [kv[0], kv[1]])
