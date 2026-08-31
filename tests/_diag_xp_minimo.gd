extends SceneTree

## Quien es el jugador que menos XP suma, y cuanto jugo. Si es un
## suplente que entro al minuto 80, el 0.13 es correcto y el que estaba
## mal era el umbral del test.

func _init() -> void:
	for i in range(12):
		var r1 := RandomNumberGenerator.new()
		r1.seed = 100 + i
		var a := Team.generar("A", r1)
		var b := Team.generar("B", r1)
		var r2 := RandomNumberGenerator.new()
		r2.seed = 100 + i
		var esp := MotorEspacial.simular(a, b, r2, false)
		var xp: Dictionary = esp["xp"]["home"]
		var peor := 99.0
		var quien := {}
		for j in a.jugadores:
			var d = xp.get(j["id"], null)
			if d == null:
				print("  partido %d: %s %s (%s) SIN entrada de xp" % [
					i, j["nombre"], j["apellido"], j["posicion"]])
				continue
			var s := 0.0
			for at in d:
				s += float(d[at])
			if s < peor:
				peor = s
				quien = j
		if peor > 0.45:
			continue
		# Cuantos minutos jugo, sacado del log de cambios.
		var minutos := "los 90"
		for linea in esp["log"]:
			if str(linea).find(str(quien["apellido"])) != -1:
				minutos = str(linea)
		print("partido %d: peor %.2f -> %s %s (%s) | %s" % [
			i, peor, quien["nombre"], quien["apellido"], quien["posicion"], minutos])
	quit()
