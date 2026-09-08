extends SceneTree

## ¿Cuan al filo esta test_fin_de_mitad? Cuenta mitades cortadas a medias
## sobre varias tandas de 40 partidos, cambiando la semilla base.

const PARTIDOS := 40
const TANDAS := 12


func _init() -> void:
	var total := 0
	var tandas_con_falla := 0
	for t in range(TANDAS):
		var base := 909 + t * 1000
		var cortadas := 0
		for i in range(PARTIDOS):
			var rng := RandomNumberGenerator.new()
			rng.seed = base + i
			var casa := Team.generar("Casa", rng, 0)
			var visita := Team.generar("Visita", rng, 400)
			var res := MotorEspacial.simular(casa, visita, rng)
			for tipo in res["stats"]["cortadas"]:
				cortadas += int(res["stats"]["cortadas"][tipo])
		total += cortadas
		if cortadas > 0:
			tandas_con_falla += 1
		print("semilla base %5d: %d cortes sucios en %d mitades" % [base, cortadas, PARTIDOS * 2])
	print("TOTAL: %d cortes en %d mitades (%.2f%%); tandas de 40 partidos que fallarian: %d de %d" % [
		total, TANDAS * PARTIDOS * 2, 100.0 * total / float(TANDAS * PARTIDOS * 2),
		tandas_con_falla, TANDAS])
	quit()
