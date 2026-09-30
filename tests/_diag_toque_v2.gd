extends SceneTree

## Medición de la etapa 3 del Motor V2 (docs/motor_v2.md): rondo 4 vs 2 y
## partidito 5 vs 5 sin vista, con varias semillas. Imprime los contadores de
## CanchitaV2Nativa sumados y las tasas que importan.
##   <godot> --path . --headless --script tests/_diag_toque_v2.gd -- segundos=300 semillas=5

const SEED := 20261001


func _init() -> void:
	var segundos := 300.0
	var semillas := 5
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("segundos="):
			segundos = float(arg.get_slice("=", 1))
		if arg.begins_with("semillas="):
			semillas = int(arg.get_slice("=", 1))
	for modo in [0, 1]:
		var suma := {}
		var dura := 0.0
		var peores := {"espera_max": 0.0, "corte_mas_lejos_m": 0.0, "peor_salto_cuerpo_m": 0.0}
		for s in semillas:
			var c := CanchitaV2.armar(modo, SEED + s)
			dura += c.simular(int(segundos * 60.0))
			var k: Dictionary = c.contadores()
			for clave in k:
				if peores.has(clave):
					peores[clave] = maxf(peores[clave], float(k[clave]))
				else:
					suma[clave] = float(suma.get(clave, 0.0)) + float(k[clave])
		var pasos := segundos * 60.0 * semillas
		var minutos := segundos * semillas / 60.0
		print("[diag_toque] %s: %d semillas x %.0f s, %.2f µs/paso" % [["RONDO", "PARTIDITO"][modo], semillas, segundos,
			dura * 1e6 / pasos])
		var pases: float = maxf(suma["pases"], 1.0)
		print("[diag_toque]   pases/min %.1f  completos %.0f%% (de primera %.0f%%)  cortados %.0f%%  afuera %.0f%%  globos %.0f%%" % [
			suma["pases"] / minutos, 100.0 * (suma["completados"] + suma["completados_otro"]) / pases,
			100.0 * suma["de_primera"] / pases, 100.0 * suma["cortes"] / pases, 100.0 * suma["pases_afuera"] / pases,
			100.0 * suma["pases_globo"] / pases])
		print("[diag_toque]   quites/min %.1f  conducciones/min %.1f  recepciones pie/muslo/pecho/cabeza %d/%d/%d/%d  fallos/min %.1f" % [
			suma["quites"] / minutos, suma["conducciones"] / minutos, suma["pie"], suma["muslo"], suma["pecho"],
			suma["cabeza"], suma["fallos"] / minutos])
		print("[diag_toque]   correcciones %d  saltos_pelota %d  frenadas_en_seco %d  corte más lejos %.3f m  espera media %.3f s  máx %.2f s  largas %d  peor salto cuerpo %.3f m" % [
			suma["correcciones"], suma["saltos_pelota"], suma["frenadas_en_seco"], peores["corte_mas_lejos_m"],
			suma["espera_media"] / semillas, peores["espera_max"], suma["esperas_largas"], peores["peor_salto_cuerpo_m"]])
	quit()
