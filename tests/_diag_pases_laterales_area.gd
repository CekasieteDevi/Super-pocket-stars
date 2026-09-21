extends SceneTree

const PARTIDOS := 100
const SEMILLA := 18420

func _init() -> void:
	var total := {}
	for i in range(PARTIDOS):
		var rng := RandomNumberGenerator.new()
		rng.seed = SEMILLA + i
		var casa := Team.generar("Casa", rng, 0)
		var visita := Team.generar("Visita", rng, 400)
		var partido_rng := RandomNumberGenerator.new()
		partido_rng.seed = SEMILLA + 10000 + i
		var resultado := MotorEspacial.simular(casa, visita, partido_rng)
		var muestra: Dictionary = resultado["stats"].get("pases_laterales_area", {})
		for clave in muestra:
			total[clave] = int(total.get(clave, 0)) + int(muestra[clave])
	print("PARTIDOS=%d" % PARTIDOS)
	print("PASES_LATERALES_QUE_CRUZAN_AREA=%d (%.2f por partido)" % [
		int(total.get("intentos", 0)), float(total.get("intentos", 0)) / PARTIDOS])
	print("  completados=%d (%.2f por partido)" % [
		int(total.get("completados", 0)), float(total.get("completados", 0)) / PARTIDOS])
	print("  interceptados=%d (%.2f por partido)" % [
		int(total.get("interceptados", 0)), float(total.get("interceptados", 0)) / PARTIDOS])
	print("  rival_recibe=%d (%.2f por partido)" % [
		int(total.get("rival_recibe", 0)), float(total.get("rival_recibe", 0)) / PARTIDOS])
	quit()
