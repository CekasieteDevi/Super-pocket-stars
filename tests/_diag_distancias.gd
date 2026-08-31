extends SceneTree

## Cuanto miden los pases, los pelotazos y los remates, por division.
##
## La pregunta: un jugador con 40 de pase, ¿de que distancia la pone? Y
## un delantero flojo, ¿desde donde remata? El motor ya guarda dist_pases,
## dist_pelotazos y dist_tiros; aca solo se agregan y se cuentan.

const SEED := 4400
const PARTIDOS := 24


func _init() -> void:
	print("cancha de %.0f m de largo: de area a area son ~%.0f m" % [
		MotorEspacial.LARGO, MotorEspacial.LARGO - 33.0])
	for division in [9, 4, 0]:
		_medir(division)
	quit()


func _medir(division: int) -> void:
	var pases := []
	var pelotazos := []
	var tiros := []
	var muestra_fuerza := []
	var muestra_pases := []
	var goles := 0
	var al_arco := 0
	var cerca := []
	for i in range(PARTIDOS):
		var r1 := RandomNumberGenerator.new()
		r1.seed = SEED + i
		var a := Team.generar("A", r1, 0, NivelDivision.potencial(division),
			"Uruguay", NivelDivision.realizacion(division))
		var b := Team.generar("B", r1, 400, NivelDivision.potencial(division),
			"Uruguay", NivelDivision.realizacion(division))
		if i == 0:
			for j in a.jugadores:
				muestra_fuerza.append(float(j["atributos"]["fuerza"]))
				muestra_pases.append(float(j["atributos"]["pases"]))
		var r2 := RandomNumberGenerator.new()
		r2.seed = SEED + i
		var res := MotorEspacial.simular(a, b, r2, false)
		var st: Dictionary = res["stats"]
		goles += int(res["goles_local"]) + int(res["goles_visitante"])
		for ev in res["eventos"]:
			if str(ev.get("tipo", "")) == "tiro_puerta":
				al_arco += 1
		pases.append_array(st["dist_pases"])
		pelotazos.append_array(st["dist_pelotazos"])
		tiros.append_array(st["dist_tiros"])

	print("\n=== Division %d ===" % division)
	print("  plantel: fuerza %s | pases %s" % [
		_resumen(muestra_fuerza), _resumen(muestra_pases)])
	print("  pases     %s" % _resumen(pases))
	print("  pelotazos %s" % _resumen(pelotazos))
	print("  remates   %s" % _resumen(tiros))
	print("  pases de mas de 40 m: %s   de mas de 55 m: %s" % [
		_pct(pases + pelotazos, 40.0), _pct(pases + pelotazos, 55.0)])
	print("  remates de mas de 20 m: %s   de mas de 25 m: %s" % [
		_pct(tiros, 20.0), _pct(tiros, 25.0)])
	print("  goles %.2f por partido | %.1f remates, %.0f%% al arco, %.1f%% de conversion" % [
		float(goles) / PARTIDOS, float(tiros.size()) / PARTIDOS,
		100.0 * al_arco / maxf(tiros.size(), 1), 100.0 * goles / maxf(tiros.size(), 1)])
	print("  por partido: %.1f pases, %.1f pelotazos, %.1f remates" % [
		float(pases.size()) / PARTIDOS, float(pelotazos.size()) / PARTIDOS,
		float(tiros.size()) / PARTIDOS])


func _pct(valores: Array, umbral: float) -> String:
	if valores.is_empty():
		return "-"
	var n := 0
	for v in valores:
		if float(v) > umbral:
			n += 1
	return "%.1f%% (%d)" % [100.0 * n / valores.size(), n]


func _resumen(valores: Array) -> String:
	if valores.is_empty():
		return "sin datos"
	var copia := valores.duplicate()
	copia.sort()
	var suma := 0.0
	for v in copia:
		suma += float(v)
	return "n=%d media %.1f | p50 %.1f p90 %.1f p99 %.1f max %.1f" % [
		copia.size(), suma / copia.size(),
		float(copia[int(copia.size() * 0.5)]),
		float(copia[int(copia.size() * 0.9)]),
		float(copia[mini(int(copia.size() * 0.99), copia.size() - 1)]),
		float(copia[copia.size() - 1])]
