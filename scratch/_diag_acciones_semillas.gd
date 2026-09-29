extends SceneTree

## Medición: qué acciones aparecen en partidos de distintas semillas y en qué
## fotograma. Sirve para armar un partido de muestra con todas las animaciones.

const SEMILLA := 20260818
const BUSCADAS := ["patea", "cabecea", "volea", "chilena", "palomita", "pecho", "control_pie",
	"taco", "amague_centro", "regate_croqueta", "regate_bicicleta", "regate_ruleta",
	"regate_globito", "regate_elastica", "barrida", "bloquea", "cae", "lesionado",
	"lateral_manos", "festeja", "vuela", "agarra", "saque_arco"]


func _initialize() -> void:
	var cubiertas := {}
	for n in 40:
		var rng := RandomNumberGenerator.new()
		rng.seed = SEMILLA + n
		var local := Team.generar("Atlético Prueba", rng)
		var visita := Team.generar("Deportivo Banco", rng, 1000)
		var r := MotorEspacial.simular(local, visita, rng, true)
		var vistas := {}
		var fotos: Array = r["fotogramas"]
		for i in fotos.size():
			for a in fotos[i].get("acciones", []):
				var nombre := str(a["accion"])
				if nombre in BUSCADAS and not vistas.has(nombre):
					vistas[nombre] = i
		for nombre in vistas:
			if not cubiertas.has(nombre):
				cubiertas[nombre] = [n, vistas[nombre]]
		print("semilla +%d: %d acciones distintas, faltan %s" % [n, vistas.size(),
			str(BUSCADAS.filter(func(x): return not vistas.has(x)))])
		if cubiertas.size() == BUSCADAS.size():
			break
	print("CUBIERTAS ", cubiertas)
	print("SIN_VER ", BUSCADAS.filter(func(x): return not cubiertas.has(x)))
	quit()
