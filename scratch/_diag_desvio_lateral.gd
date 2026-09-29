extends SceneTree
## 3D-11: quite que manda la pelota afuera. Mismas semillas con el arreglo
## (desvio_lo_toca_el_defensor 1) y sin él (0): goles, córners y laterales
## por partido, y a quién le toca el saque después del desvío.
##   -- partidos=40 division=1
const SEED := 4400
func _initialize() -> void:
	var partidos := 40
	var division := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("partidos="): partidos = int(a.trim_prefix("partidos="))
		if a.begins_with("division="): division = int(a.trim_prefix("division=")) - 1
	for valor in [0, 1]:
		MotorEspacial.pesos()["fisica"]["desvio_lo_toca_el_defensor"] = valor
		var goles := 0
		var corners := 0
		var laterales := 0
		var desvios := 0
		var saca_el_que_tenia := 0
		for i in partidos:
			var rng := RandomNumberGenerator.new()
			rng.seed = SEED + i
			var local := Team.generar("A", rng, 0, NivelDivision.potencial(division), "Uruguay", NivelDivision.realizacion(division))
			var visita := Team.generar("B", rng, 1000, NivelDivision.potencial(division), "Uruguay", NivelDivision.realizacion(division))
			var r := MotorEspacial.simular(local, visita, rng, true)
			goles += int(r["goles_local"]) + int(r["goles_visitante"])
			var fs: Array = r["fotogramas"]
			for k in range(1, fs.size()):
				for e in fs[k].get("eventos", []):
					var t := str(e.get("tipo", ""))
					if t == "corner": corners += 1
					if t == "lateral": laterales += 1
				# Barrida y la pelota sale: quién tenía la pelota antes.
				var barrida := false
				for a in fs[k].get("acciones", []):
					if str(a["accion"]) == MotorEspacial.ACCION_BARRIDA: barrida = true
				if not barrida or not bool(fs[k]["pelota"].get("saliendo", false)): continue
				desvios += 1
				var tenia := int(fs[k - 1]["pelota"].get("poseedor_id", -1))
				var local_tenia := tenia >= 0 and tenia < 1000
				for q in range(k + 1, mini(fs.size(), k + 40)):
					var saca := int(fs[q]["pelota"].get("poseedor_id", -1))
					if saca != -1:
						if (saca < 1000) == local_tenia: saca_el_que_tenia += 1
						break
		print("desvio_lo_toca_el_defensor=%d | goles %.2f corners %.2f laterales %.2f por partido | desvios afuera %d, saca el que la tenia %d" % [
			valor, float(goles) / partidos, float(corners) / partidos, float(laterales) / partidos, desvios, saca_el_que_tenia])
	quit()
