extends SceneTree

## Medición de la etapa 5 del Motor V2 (docs/motor_v2.md): el embudo de
## remates por división, con los mismos cortes que
## tests/_diag_embudo_remates.gd (al arco = gol + atajado; atajadas sobre los
## remates al arco). Partidos de 11 contra 11 con arqueros y sin las reglas de
## la etapa 6, sin vista.
##   <godot> --path . --headless --script tests/_diag_remates_v2.gd -- partidos=4 minutos=90 celda=0
##
## `celda`: la pareja de divisiones de ESCENARIOS (-1 = todas).

const SEED := 97000
## Las mismas parejas que _diag_embudo_remates.gd (división 0 = primera).
const ESCENARIOS := [[0, 0], [0, 3], [4, 4], [4, 7], [9, 9], [9, 6]]
const ESTILOS := [["Tiki taka", "Juego directo"], ["Presion alta", "Contragolpe"]]


func _init() -> void:
	var partidos := 4
	var minutos := 90.0
	var celda := -1
	for arg in OS.get_cmdline_user_args():
		var partes := arg.split("=", true, 1)
		if partes.size() != 2:
			continue
		match partes[0]:
			"partidos": partidos = maxi(1, int(partes[1]))
			"minutos": minutos = float(partes[1])
			"celda": celda = int(partes[1])
	for i in ESCENARIOS.size():
		if celda >= 0 and i != celda:
			continue
		var esc: Array = ESCENARIOS[i]
		var suma := {}
		var dura := 0.0
		for n in partidos:
			var estilos: Array = ESTILOS[n % ESTILOS.size()]
			var c := CerebroV2.armar_partido(SEED + n, estilos[0], estilos[1], esc[0], esc[1])
			dura += c.simular(int(minutos * 60.0 * 60.0))
			var k: Dictionary = c.contadores()
			for clave in k:
				suma[clave] = float(suma.get(clave, 0.0)) + float(k[clave])
		imprimir(esc, suma, partidos, minutos, dura)
	quit()


## Por partido de 90 minutos, para comparar con el embudo del motor actual.
static func imprimir(esc: Array, s: Dictionary, partidos: int, minutos: float, dura: float) -> void:
	var escala := 90.0 / minutos / float(partidos)
	var f := func(clave: String) -> float: return float(s.get(clave, 0.0)) * escala
	var remates: float = f.call("remates")
	var goles: float = f.call("remates_gol")
	var atajados: float = f.call("remates_atajado")
	var al_arco := goles + atajados
	print("[diag_remates] == D%d/D%d, %d partidos de %.0f min (%.2f µs/paso) ==" % [esc[0] + 1, esc[1] + 1, partidos,
		minutos, dura * 1e6 / (minutos * 3600.0 * partidos)])
	print("[diag_remates]   por partido: goles %.2f (%.2f-%.2f)  remates %.2f (%.2f-%.2f)  al arco %.2f" % [
		f.call("goles_0") + f.call("goles_1"), f.call("goles_0"), f.call("goles_1"), remates, f.call("remates_0"),
		f.call("remates_1"), al_arco])
	print("[diag_remates]   al arco %.1f%%  atajadas %.1f%%  goles/remate %.1f%%  goles/al arco %.1f%%" % [
		100.0 * al_arco / maxf(remates, 0.001), 100.0 * atajados / maxf(al_arco, 0.001),
		100.0 * goles / maxf(remates, 0.001), 100.0 * goles / maxf(al_arco, 0.001)])
	print("[diag_remates]   bloqueados %.2f  afuera %.2f  palo %.2f  otro %.2f  | cabeza %.2f (goles %.2f)  de primera %.2f  tras rebote %.2f (goles %.2f)  dist media %.1f m" % [
		f.call("remates_bloqueado"), f.call("remates_afuera"), f.call("remates_palo"), f.call("remates_otro"),
		f.call("remates_cabeza"), f.call("goles_cabeza"), f.call("remates_primera"), f.call("remates_tras_rebote"),
		f.call("goles_tras_rebote"), float(s.get("distancia_remates", 0.0)) / maxf(float(s.get("remates", 0.0)), 1.0)])
	print("[diag_remates]   golpes: colocado %.2f fuerte %.2f efecto %.2f globo %.2f cabeza %.2f" % [
		f.call("golpe_colocado"), f.call("golpe_fuerte"), f.call("golpe_efecto"), f.call("golpe_globo"),
		f.call("golpe_cabeza")])
	print("[diag_remates]   arquero: agarres %.2f rebotes %.2f roces %.2f  estiradas %.2f paradas %.2f  salidas %.2f  falladas %.2f" % [
		f.call("agarres"), f.call("rebotes_arquero"), f.call("roces_arquero"), f.call("estiradas"), f.call("paradas"),
		f.call("salidas_arquero"), f.call("atajadas_falladas")])
	print("[diag_remates]   pases %.0f (completos %.0f%%)  llegadas %.1f  córners %.1f  correcciones %d  saltos_pelota %d" % [
		f.call("pases"), 100.0 * (f.call("completados") + f.call("completados_otro")) / maxf(f.call("pases"), 1.0),
		f.call("llegadas_0") + f.call("llegadas_1"), f.call("corners"), int(s.get("correcciones", 0.0)),
		int(s.get("saltos_pelota", 0.0))])
