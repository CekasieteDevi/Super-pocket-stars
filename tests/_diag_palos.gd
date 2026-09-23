extends SceneTree

## Palos por partido en los dos motores, con los MISMOS planteles y las
## mismas semillas. Mide cuántos remates pegan en el palo, cuántos goles
## entran después de pegar en el palo, y cuánto mueve eso los goles y los
## córners. Referencia del fútbol real: 0,5 a 0,8 palos por partido.

const SEED := 4400
const PARTIDOS := 60


func _contar(eventos: Array) -> Dictionary:
	var c := {"palos": 0, "travesanos": 0, "goles_palo": 0, "tras_palo": 0, "corners": 0}
	for e in eventos:
		var tipo := str(e.get("tipo", ""))
		var res := str(e.get("resultado", ""))
		if tipo == "tiro" and res == "palo":
			c["palos"] += 1
			if bool(e.get("travesano", false)):
				c["travesanos"] += 1
		if res == "gol" and bool(e.get("palo", false)):
			c["goles_palo"] += 1
		if res == "gol" and bool(e.get("tras_palo", false)):
			c["tras_palo"] += 1
		if tipo == "corner":
			c["corners"] += 1
	return c


func _init() -> void:
	print("div | motor     | goles | palos | travesaños | goles de palo | goles tras palo | córners")
	for division in [9, 4, 0]:
		var tot := {"espacial": {}, "abstracto": {}}
		for motor in tot:
			tot[motor] = {"goles": 0, "palos": 0, "travesanos": 0, "goles_palo": 0, "tras_palo": 0, "corners": 0}
		for i in range(PARTIDOS):
			for motor in tot:
				var r1 := RandomNumberGenerator.new()
				r1.seed = SEED + i
				var a := Team.generar("A", r1, 0, NivelDivision.potencial(division),
					"Uruguay", NivelDivision.realizacion(division))
				var b := Team.generar("B", r1, 400, NivelDivision.potencial(division),
					"Uruguay", NivelDivision.realizacion(division))
				var r2 := RandomNumberGenerator.new()
				r2.seed = SEED + i
				var res: Dictionary
				if motor == "espacial":
					res = MotorEspacial.simular(a, b, r2, false)
				else:
					res = MatchEngine.simular(a, b, r2)
				var t: Dictionary = tot[motor]
				t["goles"] += int(res["goles_local"]) + int(res["goles_visitante"])
				var c := _contar(res.get("eventos", []))
				for k in c:
					t[k] += c[k]
		for motor in tot:
			var t: Dictionary = tot[motor]
			print("%3d | %-9s | %5.2f | %5.2f | %10.2f | %13.2f | %15.2f | %7.2f" % [division + 1, motor,
				float(t["goles"]) / PARTIDOS, float(t["palos"]) / PARTIDOS,
				float(t["travesanos"]) / PARTIDOS, float(t["goles_palo"]) / PARTIDOS, float(t["tras_palo"]) / PARTIDOS,
				float(t["corners"]) / PARTIDOS])
	quit()
