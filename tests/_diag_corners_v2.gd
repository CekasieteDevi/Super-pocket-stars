extends SceneTree

## Etapa 7 del Motor V2 (docs/motor_v2.md): qué pasa con cada córner. Fuerza un
## córner por partido (CanchitaV2Nativa.forzar_parada) y mira quién toca
## primero el centro, con qué parte y a qué altura. No es un test: mide.
##
##   <godot> --path . --headless --script tests/_diag_corners_v2.gd -- corners=200 semilla=97000
##
## `fisica=seccion.clave:valor,...` pisa data/fisica_v2.json en memoria.

const SEED := 97000
## TOQUE_* y Parte de motor_v2/cpp/src/canchita.h.
const TOQUES := {1: "pase", 3: "control", 4: "remate", 6: "entrada"}
const GOLPES := ["colocado", "fuerte", "efecto", "globo", "cabeza"]
const PARTES := ["pie", "muslo", "pecho", "cabeza"]
const RESULTADOS := ["el que lo espera", "otro compañero", "el que lo patea", "un rival", "nadie", "el arquero"]


func _init() -> void:
	var corners := 200
	var semilla := SEED
	for arg in OS.get_cmdline_user_args():
		var p := arg.split("=", true, 1)
		if p.size() != 2:
			continue
		match p[0]:
			"corners": corners = maxi(1, int(p[1]))
			"semilla": semilla = int(p[1])
			"fisica": _pisar(FisicaV2.datos(), p[1])
	var cuenta := {}
	var hechos := 0
	var error := 0.0
	var cabezazos := 0
	var goles := 0
	var del_que_ataca := 0
	var gestos := {}
	var por_golpe := {}
	for n in corners:
		var c: Object = CerebroV2.armar_partido(semilla + n, "", "", 4, 4, true)
		c.simular(60 * 8)
		var lado := 1.0 if n % 2 == 0 else -1.0
		if not c.forzar_parada("corner", 0, Vector2(52.2, lado * 33.7)):
			continue
		var pases_antes: int = c.registro_pases().size()
		var remates_antes: int = c.registro_remates().size()
		var k0: Dictionary = c.contadores()
		# Hasta que el centro termina (o 25 s).
		var centro := {}
		for paso in 60 * 25:
			c.avanzar()
			var reg: Array = c.registro_pases()
			if reg.size() > pases_antes:
				var r: Dictionary = reg[pases_antes]
				if int(r["tipo"]) == 5 and int(r["resultado"]) >= 0:
					centro = r
					break
				if int(r["tipo"]) != 5:
					break
		if centro.is_empty():
			continue
		# Dos segundos más: el remate que sale de ese centro.
		c.simular(120)
		var k1: Dictionary = c.contadores()
		hechos += 1
		error += float(centro["error_m"])
		cabezazos += int(k1["remates_cabeza"]) - int(k0["remates_cabeza"])
		goles += int(k1["goles_0"]) - int(k0["goles_0"])
		# Los remates que salen del córner: con qué golpe, de dónde y si son gol.
		var remates: Array = c.registro_remates()
		for q in range(remates_antes, remates.size()):
			var r: Dictionary = remates[q]
			if int(r["equipo"]) != 0:
				continue
			var golpe: String = GOLPES[clampi(int(r["golpe"]), 0, GOLPES.size() - 1)]
			if not por_golpe.has(golpe):
				por_golpe[golpe] = {"n": 0.0, "gol": 0.0, "metros": 0.0, "marca": 0.0, "ocupado": 0.0, "arquero": 0.0}
			por_golpe[golpe]["n"] += 1.0
			por_golpe[golpe]["metros"] += Vector2(52.5 - float(r["desde"].x), float(r["desde"].y)).length()
			por_golpe[golpe]["marca"] += float(r["presion_m"])
			if bool(r["arquero_ocupado"]):
				por_golpe[golpe]["ocupado"] += 1.0
			# A cuánto del medio de su arco está el arquero cuando sale el remate.
			por_golpe[golpe]["arquero"] += Vector2(52.5 - float(r["arquero"].x), float(r["arquero"].y)).length()
			if int(r["resultado"]) == 0:
				por_golpe[golpe]["gol"] += 1.0
		for g in ["gestos_cabeza", "fallos_cabeza", "fallos_lejos_cabeza", "fallos_altura_cabeza", "gestos_pecho",
				"gestos_pie", "rebotes_cuerpo", "salidas"]:
			gestos[g] = int(gestos.get(g, 0)) + int(k1[g]) - int(k0[g])
		var res := int(centro["resultado"])
		if res <= 1:
			del_que_ataca += 1
		var clave: String = RESULTADOS[res]
		if int(centro["toque_fin"]) >= 0:
			clave += ", %s de %s" % [TOQUES.get(int(centro["toque_fin"]), "?"), PARTES[clampi(int(centro["parte_fin"]), 0, 3)]]
		cuenta[clave] = int(cuenta.get(clave, 0)) + 1
	print("[corners] %d córners, semilla %d: lo toca primero el que ataca %.0f%%; cabezazos al arco %.0f%%; goles %.1f%%; la pelota termina a %.1f m del punto pedido" % [
		hechos, semilla, 100.0 * del_que_ataca / maxf(hechos, 1.0), 100.0 * cabezazos / maxf(hechos, 1.0),
		100.0 * goles / maxf(hechos, 1.0), error / maxf(hechos, 1.0)])
	print("[corners] por córner (hasta 2 s después del primer toque): gestos de cabeza %.2f (erran %.2f: lejos %.2f, a otra altura %.2f), de pecho %.2f, de pie %.2f; rebotes en un cuerpo %.2f; la pelota sale %.2f" % [
		gestos["gestos_cabeza"] / float(hechos), gestos["fallos_cabeza"] / float(hechos), gestos["fallos_lejos_cabeza"] / float(hechos),
		gestos["fallos_altura_cabeza"] / float(hechos), gestos["gestos_pecho"] / float(hechos), gestos["gestos_pie"] / float(hechos),
		gestos["rebotes_cuerpo"] / float(hechos), gestos["salidas"] / float(hechos)])
	for golpe in por_golpe:
		var p: Dictionary = por_golpe[golpe]
		print("[corners] remates de %s: %.0f%% de los córners, gol el %.0f%%, desde %.1f m del arco, con el rival más cerca a %.1f m; el arquero en un gesto el %.0f%% y a %.1f m del medio de su arco" % [
			golpe, 100.0 * p["n"] / maxf(hechos, 1.0), 100.0 * p["gol"] / p["n"], p["metros"] / p["n"], p["marca"] / p["n"],
			100.0 * p["ocupado"] / p["n"], p["arquero"] / p["n"]])
	var claves := cuenta.keys()
	claves.sort_custom(func(x, y): return cuenta[x] > cuenta[y])
	for clave in claves:
		print("[corners]   %4.0f%%  %s" % [100.0 * cuenta[clave] / maxf(hechos, 1.0), clave])
	quit()


func _pisar(datos: Dictionary, texto: String) -> void:
	for par in texto.split(","):
		var kv := par.split(":")
		var clave := kv[0].split(".")
		datos[clave[0]][clave[1]] = float(kv[1])
		print("FISICA %s = %s" % [kv[0], kv[1]])
