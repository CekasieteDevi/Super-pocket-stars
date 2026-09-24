extends SceneTree

## Regresiones del relato: la técnica real manda sobre adornos incompatibles
## y un tiro libre directo nunca muestra asistencia.


func _init() -> void:
	var nombres := {1: "DC Pérez", 2: "MC Gómez"}
	var cabezazo := {
		"tipo": "tiro_puerta", "resultado": "gol", "clave": 1,
		"equipo": "Casa", "tecnica": "cabecea", "con_efecto": true,
	}
	var texto_cabeza := RelatoPartido.linea(cabezazo, nombres)
	assert(texto_cabeza.contains("de cabeza"))
	assert(not texto_cabeza.contains("CON EFECTO"))

	var volea := {
		"tipo": "tiro_puerta", "resultado": "gol", "clave": 1,
		"equipo": "Casa", "tecnica": "volea", "con_efecto": true,
	}
	var texto_volea := RelatoPartido.linea(volea, nombres)
	assert(texto_volea == "¡GOL de volea de DC Pérez! Casa")
	volea["resultado"] = "atajado"
	assert(RelatoPartido.linea(volea, nombres) == "Remata de volea DC Pérez y ataja el arquero")
	var comun := {
		"tipo": "tiro_puerta", "resultado": "gol", "clave": 1,
		"equipo": "Casa", "con_efecto": true,
	}
	assert(RelatoPartido.linea(comun, nombres) == "¡GOL CON EFECTO de DC Pérez! Casa")

	var libre := {
		"tipo": "tiro_puerta", "resultado": "gol", "clave": 1,
		"asistencia_clave": 2, "tiro_libre": true, "equipo": "Casa",
	}
	var texto_libre := RelatoPartido.linea(libre, nombres)
	assert(not texto_libre.contains("asistencia"))
	print("OK: cabezazo sin efecto narrado y tiro libre directo sin asistencia.")
	quit()
