extends SceneTree

## Faltas, amarillas y rojas por partido, en los dos motores.
##
## Referencia del futbol real: ~22 faltas, ~3,7 amarillas y 0,25 rojas
## por partido entre los dos equipos. Una roja cada 4 partidos.

const SEED := 6600
const PARTIDOS := 60


func _init() -> void:
	print("motor    | faltas | amarillas | rojas | 2a amarilla | partidos con roja")
	_medir_espacial()
	_medir_abstracto()
	print("\nreal     |  22.0  |    3.7    | 0.25  |             |  1 de cada 4")
	quit()


func _equipos(i: int) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = SEED + i
	return [Team.generar("A", r, 0), Team.generar("B", r, 400)]


func _contar(eventos: Array, cuenta: Dictionary) -> bool:
	var hubo_roja := false
	for ev in eventos:
		var tipo := str(ev.get("tipo", ""))
		if tipo == "falta":
			cuenta["faltas"] += 1
		elif tipo == "tarjeta":
			var res := str(ev.get("resultado", ""))
			if res.begins_with("roja"):
				cuenta["rojas"] += 1
				hubo_roja = true
				if res == "roja_doble_amarilla":
					cuenta["dobles"] += 1
			else:
				cuenta["amarillas"] += 1
	return hubo_roja


func _mostrar(nombre: String, cuenta: Dictionary, con_roja: int) -> void:
	print("%-8s | %6.1f | %9.2f | %5.2f | %11.2f | %.0f%%" % [
		nombre,
		float(cuenta["faltas"]) / PARTIDOS,
		float(cuenta["amarillas"]) / PARTIDOS,
		float(cuenta["rojas"]) / PARTIDOS,
		float(cuenta["dobles"]) / PARTIDOS,
		100.0 * con_roja / PARTIDOS])


func _medir_espacial() -> void:
	var cuenta := {"faltas": 0, "amarillas": 0, "rojas": 0, "dobles": 0}
	var con_roja := 0
	for i in range(PARTIDOS):
		var eq := _equipos(i)
		var r2 := RandomNumberGenerator.new()
		r2.seed = SEED + i
		var res := MotorEspacial.simular(eq[0], eq[1], r2, false)
		if _contar(res["eventos"], cuenta):
			con_roja += 1
	_mostrar("espacial", cuenta, con_roja)


func _medir_abstracto() -> void:
	var cuenta := {"faltas": 0, "amarillas": 0, "rojas": 0, "dobles": 0}
	var con_roja := 0
	for i in range(PARTIDOS):
		var eq := _equipos(i)
		var r2 := RandomNumberGenerator.new()
		r2.seed = SEED + i
		var res := MatchEngine.simular(eq[0], eq[1], r2, false)
		if _contar(res["eventos"], cuenta):
			con_roja += 1
	_mostrar("abstracto", cuenta, con_roja)
