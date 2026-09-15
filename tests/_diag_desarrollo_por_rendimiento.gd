extends SceneTree

## §7.1: la curva de un mismo jugador según cuánto juega y cuánto rinde.
## Es la calibración de Progresion.TASA_CRECIMIENTO y compañía. Cada
## escenario repite el mismo rendimiento todas las temporadas.

const SEED := 1234
const N := 150
const TEMPORADAS := 10

## [nombre, potencial, media inicial, rendimiento por temporada]
const ESCENARIOS := [
	["GOAT DC 40 goles", 96, 50, {"partidos": 36.0, "goles": 40.0, "asistencias": 6.0, "a_favor": 60.0, "en_contra": 40.0}],
	["GOAT DC titular normal", 96, 50, {"partidos": 34.0, "goles": 16.0, "asistencias": 5.0, "a_favor": 45.0, "en_contra": 45.0}],
	["GOAT DC titular flojo", 96, 50, {"partidos": 34.0, "goles": 5.0, "asistencias": 2.0, "a_favor": 35.0, "en_contra": 55.0}],
	["GOAT DC suplente", 96, 50, {"partidos": 8.0, "goles": 3.0, "asistencias": 1.0, "a_favor": 10.0, "en_contra": 10.0}],
	["GOAT DC no juega", 96, 50, {}],
	["Del monton DC titular normal", 65, 40, {"partidos": 34.0, "goles": 16.0, "asistencias": 5.0, "a_favor": 45.0, "en_contra": 45.0}],
	["Del monton DFC titular, valla solida", 65, 40, {"partidos": 34.0, "goles": 0.0, "asistencias": 0.0, "a_favor": 45.0, "en_contra": 25.0}],
]


func _init() -> void:
	for esc in ESCENARIOS:
		var pot: int = esc[1]
		var puesto := "DFC" if "DFC" in str(esc[0]) else "DC"
		var suma := []
		suma.resize(TEMPORADAS + 1)
		suma.fill(0.0)
		for i in range(N):
			var rng := RandomNumberGenerator.new()
			rng.seed = SEED + i
			var j := PlayerGenerator.generate(i, rng, puesto, pot)
			j["potencial"] = pot
			j["genetica_tier"] = Genetics.tier_de(pot)
			j["potenciales"] = PlayerGenerator.techos_por_atributo(pot, rng)
			j["edad"] = 16
			j["personalidad"] = []
			var m0: float = PlayerGenerator.compute_media(j["atributos"], puesto)
			for a in j["atributos"]:
				j["atributos"][a] = clampf(round(float(j["atributos"][a]) * float(esc[2]) / m0), 1, 99)
			j["media"] = PlayerGenerator.compute_media(j["atributos"], puesto)
			suma[0] += j["media"]
			for t in range(1, TEMPORADAS + 1):
				var rend: Dictionary = esc[3]
				j["rendimiento"] = rend.duplicate()
				j["xp_uso"] = MatchEngine_perfil(puesto, float(rend.get("partidos", 0.0)))
				Progresion.aplicar_temporada(j, rng)
				suma[t] += j["media"]
		var linea := "%-38s" % esc[0]
		for t in range(TEMPORADAS + 1):
			linea += " %d:%.0f" % [16 + t, suma[t] / N]
		print(linea)
	quit()


## El uso que deja una temporada del motor abstracto: el perfil del puesto
## por los partidos jugados.
func MatchEngine_perfil(puesto: String, partidos: float) -> Dictionary:
	var perfil: Dictionary = PlayerGenerator.get_weights()[puesto]
	var suma := 0.0
	for a in perfil:
		suma += float(perfil[a])
	var uso := {}
	for a in perfil:
		uso[a] = float(perfil[a]) / suma * partidos
	return uso
