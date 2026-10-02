extends SceneTree

## Etapa 6 del Motor V2 (docs/motor_v2.md): mide partidos de 90 minutos con
## reglas, sin vista. Imprime por partido lo que pasó (reanudaciones, faltas,
## tarjetas, offside, cambios, lesiones, goles) y cuánto esperó cada parada.
##
##   <godot> --path . --headless --script tests/_diag_reglas_v2.gd -- [semilla=N] [partidos=N] [tanda] [minutos=N]
##
## `minutos`: minutos de verdad por tiempo (45 = un partido de 90 minutos de
## verdad, para que aparezca todo). Sin el argumento, el partido del juego: 2
## minutos de verdad por tiempo con el reloj mostrando 0-90 (etapa 7).

const SEED := 20261010


func _init() -> void:
	var semilla := SEED
	var partidos := 1
	var minutos := 0.0
	var tanda := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("semilla="):
			semilla = int(a.split("=")[1])
		elif a.begins_with("partidos="):
			partidos = int(a.split("=")[1])
		elif a.begins_with("minutos="):
			minutos = float(a.split("=")[1])
		elif a == "tanda":
			tanda = true
	var suma := {}
	for n in partidos:
		var c: Object = CerebroV2.armar_partido(semilla + n, "", "", -1, -1, true, tanda)
		if minutos > 0.0:
			var r := FisicaV2.parametros_reglas(tanda)
			r["minutos_tiempo"] = minutos
			r["segundos_tiempo"] = minutos * 60.0
			c.configurar_reglas(r)
			c.empezar(CanchitaV2Nativa.PARTIDO, semilla + n)
		var t0 := Time.get_ticks_msec()
		var pasos := 0
		while str(c.get_estado()["periodo"]) != "terminado" and pasos < 60 * 60 * 150:
			c.simular(600)
			pasos += 600
		var dura := (Time.get_ticks_msec() - t0) / 1000.0
		var k: Dictionary = c.contadores()
		var e: Dictionary = c.get_estado()
		print("[reglas] semilla %d: %d-%d en %.1f min de juego (%.1f s de cpu) %s tanda %s/%s" % [semilla + n,
			k["goles_0"], k["goles_1"], pasos / 3600.0, dura, e["periodo"], e["goles_tanda"], e["pateados_tanda"]])
		for clave in ["paradas_saque_medio", "paradas_lateral", "paradas_saque_arco", "paradas_corner",
				"paradas_tiro_libre", "paradas_penal", "saques_lateral", "espera_media_lateral", "espera_max_lateral",
				"espera_media_corner", "espera_max_corner", "espera_media_tiro_libre", "espera_max_tiro_libre",
				"espera_max_saque_arco", "espera_max_saque_medio", "espera_max_penal", "saques_de_lejos",
				"laterales_lentos", "camina_lateral", "camina_corner", "camina_tiro_libre", "camina_saque_arco",
				"camina_saque_medio", "camina_penal",
				"entradas", "entradas_limpias", "faltas_0", "faltas_1", "faltas_entrada", "faltas_cruce",
				"amarillas_0", "amarillas_1", "rojas_0", "rojas_1", "rojas_directas", "gravedad_media", "gravedad_max", "offsides_cobrados_0", "offsides_cobrados_1",
				"penales", "penales_gol", "lesiones", "cambios_0", "cambios_1", "libres_corto", "libres_centro",
				"libres_directo", "arquero_mano", "arquero_voleo", "arquero_pie", "remates", "correcciones", "saltos_pelota", "peor_salto_cuerpo_m"]:
			suma[clave] = float(suma.get(clave, 0.0)) + float(k.get(clave, 0))
			print("   %s = %s" % [clave, k.get(clave)])
		var tipos := {}
		for ev in c.eventos():
			tipos[ev["tipo"]] = int(tipos.get(ev["tipo"], 0)) + 1
		print("   eventos %s" % [tipos])
	quit()
