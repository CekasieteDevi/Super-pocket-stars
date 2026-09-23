extends SceneTree

## Posición y señales de los cuatro oficiales. Se prueba con fotogramas
## mínimos para no depender del azar de un partido completo.


func _init() -> void:
	_test_cuatro_oficiales_y_diagonal_del_arbitro()
	_test_arbitro_no_se_teletransporta()
	_test_asistentes_siguen_penultimo_defensor_o_pelota()
	_test_bandera_de_offside()
	_test_tarjeta_la_muestra_el_arbitro()
	_test_cuarto_arbitro_muestra_cambio()
	quit()


func _fotograma(pelota_x: float = 10.0) -> Dictionary:
	var jugadores: Array = []
	var xs_local := [-50.0, -40.0, -28.0, -18.0, -8.0, 0.0, 8.0, 18.0, 28.0, 38.0, 45.0]
	var xs_visita := [50.0, 40.0, 30.0, 20.0, 10.0, 0.0, -10.0, -20.0, -30.0, -40.0, -48.0]
	for i in range(11):
		jugadores.append({"id": 100 + i, "x": xs_local[i], "y": float(i - 5), "equipo_local": true})
		jugadores.append({"id": 200 + i, "x": xs_visita[i], "y": float(5 - i), "equipo_local": false})
	return {
		"jugadores": jugadores,
		"pelota": {"x": pelota_x, "y": 0.0, "poseedor_id": 105},
		"eventos": [], "cambios": [],
	}


func _por_rol(entidades: Array, rol: String) -> Dictionary:
	for entidad in entidades:
		if str(entidad.get("rol_oficial", "")) == rol:
			return entidad
	return {}


func _test_cuatro_oficiales_y_diagonal_del_arbitro() -> void:
	var entidades := OficialesPartido.entidades([_fotograma()], 0, 0.0)
	assert(entidades.size() == 4)
	var arbitro := _por_rol(entidades, OficialesPartido.ARBITRO)
	assert(not arbitro.is_empty())
	# Poseedor local: el árbitro queda ocho metros detrás y seis al costado.
	assert((arbitro["pos"] as Vector2).is_equal_approx(Vector2(2.0, 6.0)))
	assert(arbitro["color"] == OficialesPartido.COLOR_CAMISETA)
	print("OK: árbitro, dos asistentes y cuarto árbitro usan el atlas del partido.")


func _test_arbitro_no_se_teletransporta() -> void:
	var primero := _fotograma(10.0)
	var segundo := _fotograma(-40.0)
	segundo["pelota"]["poseedor_id"] = 205
	var recorridas := OficialesPartido.preparar([primero, segundo])
	var posiciones: Array = recorridas[OficialesPartido.ARBITRO]
	assert((posiciones[0] as Vector2).distance_to(posiciones[1])
		<= OficialesPartido.PASO_MAX_ARBITRO_M + 0.001)
	print("OK: cambio brusco de posesión no teletransporta al árbitro.")


func _test_asistentes_siguen_penultimo_defensor_o_pelota() -> void:
	var entidades := OficialesPartido.entidades([_fotograma()], 0, 0.0)
	var derecho := _por_rol(entidades, OficialesPartido.ASISTENTE_DERECHO)
	var izquierdo := _por_rol(entidades, OficialesPartido.ASISTENTE_IZQUIERDO)
	assert(is_equal_approx(float(derecho["pos"].x), 40.0))
	assert(is_equal_approx(float(izquierdo["pos"].x), -40.0))
	assert(float(derecho["pos"].y) < -ProyeccionPartido.MEDIO_ANCHO)
	assert(float(izquierdo["pos"].y) > ProyeccionPartido.MEDIO_ANCHO)
	var con_pelota_adelantada := OficialesPartido.entidades([_fotograma(45.0)], 0, 0.0)
	assert(is_equal_approx(float(_por_rol(con_pelota_adelantada,
		OficialesPartido.ASISTENTE_DERECHO)["pos"].x), 45.0))
	print("OK: asistentes alineados con penúltimo defensor o pelota.")


func _test_bandera_de_offside() -> void:
	var offside := _fotograma(44.0)
	offside["eventos"] = [{"tipo": "offside", "clave": 110, "resultado": "offside"}]
	var despues := _fotograma(44.0)
	var entidades := OficialesPartido.entidades([offside, despues], 1, 0.0)
	assert(_por_rol(entidades, OficialesPartido.ASISTENTE_DERECHO)["senal"] == "bandera_arriba")
	assert(_por_rol(entidades, OficialesPartido.ASISTENTE_IZQUIERDO)["senal"] == "bandera_baja")
	assert(_por_rol(entidades, OficialesPartido.ARBITRO)["senal"] == "silbato")
	print("OK: offside conserva bandera y silbato durante una señal visible.")


func _test_tarjeta_la_muestra_el_arbitro() -> void:
	var tarjeta := _fotograma()
	tarjeta["eventos"] = [{"tipo": "tarjeta", "clave": 107, "resultado": "amarilla"}]
	var despues := _fotograma()
	var inicio := _por_rol(OficialesPartido.entidades([tarjeta, despues], 0, 0.0),
		OficialesPartido.ARBITRO)
	var subida := _por_rol(OficialesPartido.entidades([tarjeta, despues], 1, 0.0),
		OficialesPartido.ARBITRO)
	assert(inicio["senal"] == "tarjeta_amarilla")
	assert(float(inicio["fase_senal"]) < float(subida["fase_senal"]))
	assert(inicio["accion"] == "lateral_prepara")
	assert(float(inicio["fase_animacion"]) < float(subida["fase_animacion"]))
	print("OK: el árbitro anima brazos y tarjeta; no se asigna al jugador.")


func _test_cuarto_arbitro_muestra_cambio() -> void:
	var cambio := _fotograma()
	cambio["cambios"] = [{"saliente_clave": 104, "entrante_clave": 111,
		"numero_sale": 8, "numero_entra": 19, "equipo_local": true}]
	var cuarto := _por_rol(OficialesPartido.entidades([cambio], 0, 0.0),
		OficialesPartido.CUARTO_ARBITRO)
	assert(cuarto["senal"] == "tablero")
	assert(cuarto["numero_sale"] == 8)
	assert(cuarto["numero_entra"] == 19)
	assert(float(cuarto["pos"].y) > ProyeccionPartido.MEDIO_ANCHO)
	print("OK: cuarto árbitro muestra dorsales y espera fuera de la cancha.")
