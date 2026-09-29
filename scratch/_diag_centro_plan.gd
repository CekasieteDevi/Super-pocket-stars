extends SceneTree
## Plan de los centros de 3D-09 (VistaCancha3D._preparar_centros) sin dibujar:
##   -- division=1 semilla=N [viejo]
## Por centro: desde, toma, junta, control y la velocidad del receptor en el
## motor y con el adelanto (m/s), tramo por tramo.
func _initialize() -> void:
	var division := -1
	var rng := RandomNumberGenerator.new()
	rng.seed = PrototipoVista.SEMILLA
	for a in OS.get_cmdline_user_args():
		if a.begins_with("division="): division = int(a.trim_prefix("division=")) - 1
		if a.begins_with("semilla="): rng.seed = int(a.trim_prefix("semilla="))
		if a == "viejo":
			MotorEspacial.pesos()["fisica"]["un_corte_por_vuelo"] = 0
			MotorEspacial.pesos()["fisica"]["cambio_por_abajo"] = 0
			MotorEspacial.pesos()["fisica"]["arquero_tendido_ticks"] = 0
	var local: Team
	var visita: Team
	if division >= 0:
		local = Team.generar("Atlético Prueba", rng, 0, NivelDivision.potencial(division), "Uruguay", NivelDivision.realizacion(division))
		visita = Team.generar("Deportivo Banco", rng, 1000, NivelDivision.potencial(division), "Uruguay", NivelDivision.realizacion(division))
	else:
		local = Team.generar("Atlético Prueba", rng)
		visita = Team.generar("Deportivo Banco", rng, 1000)
	var r := MotorEspacial.simular(local, visita, rng, true)
	var fs: Array = r["fotogramas"]
	var v := VistaCancha3D.new()
	v._preparar_centros(fs)
	for c in v._centros:
		print("CENTRO c%d desde %.2f toma %.2f junta %.2f control %d arranca %.2f vuelve %.2f" % [int(c["clave"]),
			float(c["desde"]), float(c["toma"]), float(c["junta"]), int(c["control"]), float(c["arranca"]), float(c["vuelve"])])
		var t := float(c["arranca"]) - 1.0
		var linea := "   "
		while t < float(c["vuelve"]) + 1.0:
			var m := VistaCancha3D._motor_de(fs, int(c["clave"]), t).distance_to(VistaCancha3D._motor_de(fs, int(c["clave"]), t + 0.25)) / 0.25 / MotorEspacial.TICK_SEG
			var tau0 := VistaCancha3D._tiempo_del_centro(c, t)
			var tau1 := VistaCancha3D._tiempo_del_centro(c, t + 0.25)
			var d := VistaCancha3D._motor_de(fs, int(c["clave"]), tau0).distance_to(VistaCancha3D._motor_de(fs, int(c["clave"]), tau1)) / 0.25 / MotorEspacial.TICK_SEG
			linea += " %.2f:%.1f/%.1f" % [t, m, d]
			t += 0.25
		print(linea)
	v.free()
	quit()
