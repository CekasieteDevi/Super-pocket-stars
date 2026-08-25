extends SceneTree

## Cuantas lesiones NUEVAS ocurren de verdad. El diagnostico viejo sumaba
## yo.lesiones.size() por fecha, que es "jugadores-fecha lesionados", no
## lesiones. Aca se cuentan transiciones sano -> lesionado.

const TEMPORADAS := 3
const DIVISION := 4


func _init() -> void:
	print("=== %d temporadas, division %d, liga entera ===" % [TEMPORADAS, DIVISION])
	print("riesgo base %.5f" % Lesiones.RIESGO_BASE)
	print("carga         | lesiones/eq/temp | dias perdidos | %% plantel afuera | graves/temp | goles | 0-3 | convoca")
	for nivel in CargaEntrenamiento.NIVELES:
		var r := _correr(nivel)
		print("%-13s | %16.2f | %13.1f | %15.1f%% | %11.2f | %5.2f | %4.2f | %.2f" % [
			CargaEntrenamiento.ETIQUETAS[nivel], r["nuevas"], r["dias"], r["fuera"] * 100.0,
			r["graves"], r["goles"], r["sin_plantel"], r["convocatorias"]])
	quit()


func _correr(nivel: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4321
	var piramide := Piramide.generar(rng)
	var liga: Liga = piramide.divisiones[DIVISION]
	var yo: Team = liga.equipos[0]
	for e in liga.equipos:
		e.carga_entrenamiento = nivel
	_gf_previo = 0
	for e in liga.equipos:
		e.generar_camada(rng, Instalaciones.cantidad_camada(e))

	var activas := {}      # equipo -> {id: true}
	var nuevas := 0
	var graves := 0
	var dias := 0
	var muestras := 0
	var suma_fuera := 0.0
	var goles := 0
	var partidos := 0
	var sin_plantel := 0
	var convocatorias := 0
	for e in liga.equipos:
		activas[e.nombre] = {}

	for t in range(TEMPORADAS):
		for fecha in range(liga.fixture.size()):
			liga.noticias.clear()
			liga.jugar_fecha(fecha, rng, yo)
			for n in liga.noticias:
				if n.contains("no pudo presentar"):
					sin_plantel += 1
				elif n.contains("sube de la cantera"):
					convocatorias += 1
			goles += _goles_de(liga)
			partidos += liga.fixture[fecha].size()
			for e in liga.equipos:
				var prev: Dictionary = activas[e.nombre]
				for id in e.lesiones:
					if not prev.has(id):
						nuevas += 1
						var d := int(e.lesiones[id]["dias_restantes"])
						dias += d
						if d >= 30:
							graves += 1
				var ahora := {}
				for id in e.lesiones:
					ahora[id] = true
				activas[e.nombre] = ahora
				suma_fuera += float(e.lesiones.size()) / float(max(1, e.todos_los_jugadores().size()))
				muestras += 1
			if (fecha + 1) % 4 == 0:
				liga.avanzar_dias(3)
				liga.avanzar_dias(4)
			else:
				liga.avanzar_dias(7)
		for e in liga.equipos:
			e.liberar_veteranos_de_cantera()
			e.generar_camada(rng, Instalaciones.cantidad_camada(e))
			e.reiniciar_carga()

	var equipos := float(liga.equipos.size())
	var norm := equipos * float(TEMPORADAS)
	return {
		"nuevas": float(nuevas) / norm,
		"dias": float(dias) / norm,
		"graves": float(graves) / norm,
		"fuera": suma_fuera / float(max(1, muestras)),
		"goles": float(goles) / float(max(1, partidos)),
		"convocatorias": float(convocatorias) / (float(liga.equipos.size()) * float(TEMPORADAS)),
		"sin_plantel": float(sin_plantel) / (float(liga.equipos.size()) * float(TEMPORADAS)),
	}


## Goles de la fecha: la tabla acumula GF de todos, asi que se mide el
## delta contra el total anterior.
var _gf_previo := 0

func _goles_de(liga: Liga) -> int:
	var total := 0
	for nombre in liga.tabla:
		total += int(liga.tabla[nombre]["gf"])
	var d := total - _gf_previo
	_gf_previo = total
	return d
