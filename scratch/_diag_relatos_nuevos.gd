extends SceneTree
## Cuenta eventos por tipo/resultado y muestra lo que narraría el relato.
##   -- division=1 semilla=5 [lineas]
func _initialize() -> void:
	var division := -1
	var ver := false
	var rng := RandomNumberGenerator.new()
	rng.seed = PrototipoVista.SEMILLA
	for a in OS.get_cmdline_user_args():
		if a.begins_with("division="): division = int(a.trim_prefix("division=")) - 1
		if a.begins_with("semilla="): rng.seed = int(a.trim_prefix("semilla="))
		if a == "lineas": ver = true
	var local := Team.generar("Atlético Prueba", rng, 0, NivelDivision.potencial(division), "Uruguay", NivelDivision.realizacion(division))
	var visita := Team.generar("Deportivo Banco", rng, 1000, NivelDivision.potencial(division), "Uruguay", NivelDivision.realizacion(division))
	var r := MotorEspacial.simular(local, visita, rng, true)
	var nombres := VistaPartido.construir_nombres(local, visita)
	var cuenta := {}
	var fs: Array = r["fotogramas"]
	var lineas := 0
	for i in fs.size():
		for ev in fs[i].get("eventos", []):
			var k := "%s/%s" % [ev.get("tipo", ""), ev.get("resultado", "")]
			cuenta[k] = int(cuenta.get(k, 0)) + 1
		var mejor = null
		var peso := 0
		for ev in fs[i].get("eventos", []):
			var p := RelatoPartido.importancia(ev)
			if p > peso:
				peso = p
				mejor = ev
		if mejor == null: continue
		var e: Dictionary = mejor
		if not e.has("clave") and e.has("jugador_id"):
			e = e.duplicate()
			e["clave"] = MotorEspacial.clave_de(int(e["jugador_id"]), str(e.get("equipo", "")) == local.nombre)
		var texto := RelatoPartido.linea(e, nombres)
		if texto == "": continue
		lineas += 1
		if ver: print("t%d m%d [%d] %s" % [i, int(fs[i]["minuto"]), peso, texto])
	var ks := cuenta.keys(); ks.sort()
	for k in ks: print("%-32s %d" % [k, cuenta[k]])
	print("LINEAS ", lineas)
	quit()
