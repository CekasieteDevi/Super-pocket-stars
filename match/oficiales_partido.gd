class_name OficialesPartido
extends RefCounted

## Capa visual de los cuatro oficiales de campo. No decide infracciones:
## representa las decisiones ya tomadas por MotorEspacial y mantiene a cada
## oficial donde corresponde a su función real.

const ARBITRO := "arbitro"
const ASISTENTE_DERECHO := "asistente_derecho"
const ASISTENTE_IZQUIERDO := "asistente_izquierdo"
const CUARTO_ARBITRO := "cuarto_arbitro"

const COLOR_CAMISETA := Color("18c4cf")
const COLOR_PANTALON := Color("171a20")
const COLOR_PELO := Color("382014")
const PEINADO := 2  # rapado: silueta limpia, distinta de la mayoría del plantel

const DISTANCIA_ARBITRO_M := 8.0
const DESPLAZAMIENTO_LATERAL_M := 6.0
const MARGEN_ASISTENTE_M := 1.7
const MARGEN_CUARTO_M := 4.0
const TICKS_SENAL := 8
const PASO_MAX_ARBITRO_M := 2.0
const PASO_MAX_ASISTENTE_M := 2.4


## Calcula una vez las recorridas, limitando cada avance a una velocidad
## humana. VistaPartido guarda el resultado; así cambiar la posesión no hace
## que el árbitro se teletransporte de un lado al otro de la pelota.
static func preparar(fotogramas: Array) -> Dictionary:
	var recorridas := {
		ARBITRO: [], ASISTENTE_DERECHO: [], ASISTENTE_IZQUIERDO: [],
	}
	for i in range(fotogramas.size()):
		var actual: Dictionary = fotogramas[i]
		var siguiente: Dictionary = fotogramas[i + 1] if i + 1 < fotogramas.size() else actual
		var incidente := _evento_reciente(fotogramas, i, ["falta", "offside"])
		if incidente.is_empty():
			incidente = _evento_reciente(fotogramas, i, ["tarjeta"])
		var gol := _evento_reciente(fotogramas, i,
			["tiro_puerta", "penal", "rebote_arquero"], true)
		var objetivos := {
			ARBITRO: _objetivo_arbitro(actual, siguiente, incidente),
			ASISTENTE_DERECHO: _posicion_asistente(actual, true, gol, i),
			ASISTENTE_IZQUIERDO: _posicion_asistente(actual, false, gol, i),
		}
		for rol in objetivos:
			var recorrido: Array = recorridas[rol]
			var objetivo: Vector2 = objetivos[rol]
			if recorrido.is_empty():
				recorrido.append(objetivo)
			else:
				var paso := PASO_MAX_ARBITRO_M if rol == ARBITRO else PASO_MAX_ASISTENTE_M
				recorrido.append((recorrido[-1] as Vector2).move_toward(objetivo, paso))
	return recorridas


static func entidades(fotogramas: Array, idx: int, t: float,
		recorridas: Dictionary = {}) -> Array:
	if fotogramas.is_empty() or idx < 0 or idx >= fotogramas.size():
		return []
	var a: Dictionary = fotogramas[idx]
	var b: Dictionary = fotogramas[idx + 1] if idx + 1 < fotogramas.size() else a
	var incidente := _evento_reciente(fotogramas, idx, ["falta", "offside"])
	if incidente.is_empty():
		incidente = _evento_reciente(fotogramas, idx, ["tarjeta"])
	var tarjeta := _evento_reciente(fotogramas, idx, ["tarjeta"])
	var silbato := _evento_reciente(fotogramas, idx, ["falta", "offside"])
	var salida := _evento_reciente(fotogramas, idx, ["offside", "lateral", "corner", "saque_arco"])
	var gol := _evento_reciente(fotogramas, idx, ["tiro_puerta", "penal", "rebote_arquero"], true)

	var pos_arbitro_a := _posicion_preparada(recorridas, ARBITRO, idx,
		_objetivo_arbitro(a, b, incidente))
	var pos_arbitro_b := _posicion_preparada(recorridas, ARBITRO, idx + 1,
		_objetivo_arbitro(b, b, incidente))
	var avance_arbitro := pos_arbitro_b - pos_arbitro_a
	var pos_arbitro := pos_arbitro_a.lerp(pos_arbitro_b, t)
	var senal_arbitro := ""
	var fase_tarjeta := 1.0
	if not tarjeta.is_empty():
		var resultado := str((tarjeta["evento"] as Dictionary).get("resultado", "amarilla"))
		senal_arbitro = "tarjeta_roja" if resultado != "amarilla" else "tarjeta_amarilla"
		fase_tarjeta = clampf((float(idx - int(tarjeta["indice"])) + t) / 2.0, 0.0, 1.0)
	elif not silbato.is_empty():
		senal_arbitro = "silbato"

	var arbitro := _entidad(ARBITRO, pos_arbitro, avance_arbitro, idx, t, senal_arbitro)
	arbitro["fase_senal"] = fase_tarjeta
	if senal_arbitro.begins_with("tarjeta_"):
		# Tres cuadros PNG: saca la tarjeta y estira un solo brazo hacia arriba.
		# La tarjeta acompaña esa misma fase en VistaCancha.
		arbitro["accion"] = "tarjeta"
		arbitro["fase_animacion"] = fase_tarjeta
	var entidades_oficiales: Array = [arbitro]

	var pos_der_a := _posicion_preparada(recorridas, ASISTENTE_DERECHO, idx,
		_posicion_asistente(a, true, gol, idx))
	var pos_der_b := _posicion_preparada(recorridas, ASISTENTE_DERECHO, idx + 1,
		_posicion_asistente(b, true, gol, idx + 1))
	var pos_izq_a := _posicion_preparada(recorridas, ASISTENTE_IZQUIERDO, idx,
		_posicion_asistente(a, false, gol, idx))
	var pos_izq_b := _posicion_preparada(recorridas, ASISTENTE_IZQUIERDO, idx + 1,
		_posicion_asistente(b, false, gol, idx + 1))
	var senal_der := _senal_asistente(salida, a, true)
	var senal_izq := _senal_asistente(salida, a, false)
	entidades_oficiales.append(_entidad(ASISTENTE_DERECHO,
		pos_der_a.lerp(pos_der_b, t), pos_der_b - pos_der_a, idx, t, senal_der))
	entidades_oficiales.append(_entidad(ASISTENTE_IZQUIERDO,
		pos_izq_a.lerp(pos_izq_b, t), pos_izq_b - pos_izq_a, idx, t, senal_izq))

	var cuarto := _entidad(CUARTO_ARBITRO,
		Vector2(0.0, ProyeccionPartido.MEDIO_ANCHO + MARGEN_CUARTO_M),
		Vector2.ZERO, idx, t, "")
	var cambios: Array = a.get("cambios", [])
	if cambios.is_empty():
		cambios = b.get("cambios", [])
	if not cambios.is_empty():
		var cambio: Dictionary = cambios[0]
		cuarto["senal"] = "tablero"
		cuarto["numero_sale"] = int(cambio.get("numero_sale", 0))
		cuarto["numero_entra"] = int(cambio.get("numero_entra", 0))
	entidades_oficiales.append(cuarto)
	return entidades_oficiales


static func _posicion_preparada(recorridas: Dictionary, rol: String, idx: int,
		alternativa: Vector2) -> Vector2:
	var recorrido: Array = recorridas.get(rol, [])
	if idx >= 0 and idx < recorrido.size():
		return recorrido[idx]
	if idx >= recorrido.size() and not recorrido.is_empty():
		return recorrido[-1]
	return alternativa


static func _entidad(rol: String, pos: Vector2, avance: Vector2,
		idx: int, t: float, senal: String) -> Dictionary:
	var corriendo := avance.length() > 0.12
	return {
		"tipo": "oficial", "rol_oficial": rol, "pos": pos, "z": 0.0,
		"color": COLOR_CAMISETA, "color_short": COLOR_PANTALON,
		"color_pelo": COLOR_PELO, "pelo": PEINADO, "numero": 0,
		"arquero": false, "accion": "",
		"pose": SpritesPartido.CORRE_A if corriendo else SpritesPartido.QUIETO,
		"direccion": _direccion(avance),
		"fase_animacion": (float(idx) + t) * 2.4,
		"senal": senal,
	}


## El árbitro trabaja en diagonal, unos metros por detrás de la pelota. En
## una infracción se acerca al punto de la decisión para señalarla o mostrar
## la tarjeta, sin ocupar el mismo píxel que el jugador.
static func _objetivo_arbitro(actual: Dictionary, siguiente: Dictionary,
		incidente: Dictionary) -> Vector2:
	if not incidente.is_empty():
		var punto := _punto_del_evento(actual, incidente["evento"])
		return Vector2(
			clampf(punto.x - 3.5, -ProyeccionPartido.MEDIO_LARGO + 4.0,
				ProyeccionPartido.MEDIO_LARGO - 4.0),
			clampf(punto.y + (-3.5 if punto.y > 0.0 else 3.5),
				-ProyeccionPartido.MEDIO_ANCHO + 4.0, ProyeccionPartido.MEDIO_ANCHO - 4.0))
	var pelota := _pelota(actual)
	var pelota_sig := _pelota(siguiente)
	var rumbo_x := signf(pelota_sig.x - pelota.x)
	var poseedor := int((actual.get("pelota", {}) as Dictionary).get("poseedor_id", -1))
	for jugador in actual.get("jugadores", []):
		if int(jugador["id"]) == poseedor:
			rumbo_x = 1.0 if bool(jugador["equipo_local"]) else -1.0
			break
	if rumbo_x == 0.0:
		rumbo_x = 1.0 if pelota.x >= 0.0 else -1.0
	var lado := -1.0 if pelota.y > 0.0 else 1.0
	return Vector2(
		clampf(pelota.x - rumbo_x * DISTANCIA_ARBITRO_M,
			-ProyeccionPartido.MEDIO_LARGO + 5.0, ProyeccionPartido.MEDIO_LARGO - 5.0),
		clampf(pelota.y + lado * DESPLAZAMIENTO_LATERAL_M,
			-ProyeccionPartido.MEDIO_ANCHO + 5.0, ProyeccionPartido.MEDIO_ANCHO - 5.0))


## Cada asistente ocupa una mitad y se mantiene en línea con el penúltimo
## defensor o con la pelota si esta está más cerca de la línea de meta.
static func _posicion_asistente(fotograma: Dictionary, derecha: bool,
		gol: Dictionary, idx: int) -> Vector2:
	var defensores_x: Array = []
	for jugador in fotograma.get("jugadores", []):
		if bool(jugador["equipo_local"]) == (not derecha):
			defensores_x.append(float(jugador["x"]))
	defensores_x.sort()
	var pelota_x := _pelota(fotograma).x
	var x := pelota_x
	if defensores_x.size() >= 2:
		var penultimo := float(defensores_x[-2] if derecha else defensores_x[1])
		x = maxf(penultimo, pelota_x) if derecha else minf(penultimo, pelota_x)
	x = clampf(x, 0.0, ProyeccionPartido.MEDIO_LARGO) if derecha \
		else clampf(x, -ProyeccionPartido.MEDIO_LARGO, 0.0)
	if not gol.is_empty():
		var edad := maxi(0, idx - int(gol["indice"]))
		x = move_toward(x, 0.0, float(edad) * 4.0)
	var y := -ProyeccionPartido.MEDIO_ANCHO - MARGEN_ASISTENTE_M if derecha \
		else ProyeccionPartido.MEDIO_ANCHO + MARGEN_ASISTENTE_M
	return Vector2(x, y)


static func _senal_asistente(registro: Dictionary, fotograma: Dictionary,
		derecha: bool) -> String:
	if registro.is_empty():
		return "bandera_baja"
	var evento: Dictionary = registro["evento"]
	var punto := _punto_del_evento(fotograma, evento)
	if (punto.x >= 0.0) != derecha:
		return "bandera_baja"
	return "bandera_arriba" if str(evento.get("tipo", "")) == "offside" \
		else "bandera_horizontal"


static func _evento_reciente(fotogramas: Array, idx: int, tipos: Array,
		solo_gol: bool = false) -> Dictionary:
	for i in range(idx, maxi(-1, idx - TICKS_SENAL), -1):
		for evento in fotogramas[i].get("eventos", []):
			if str(evento.get("tipo", "")) not in tipos:
				continue
			if solo_gol and str(evento.get("resultado", "")) != "gol":
				continue
			return {"evento": evento, "indice": i}
	return {}


static func _punto_del_evento(fotograma: Dictionary, evento: Dictionary) -> Vector2:
	var clave := int(evento.get("clave", -1))
	for jugador in fotograma.get("jugadores", []):
		if int(jugador["id"]) == clave:
			return Vector2(float(jugador["x"]), float(jugador["y"]))
	return _pelota(fotograma)


static func _pelota(fotograma: Dictionary) -> Vector2:
	var pelota: Dictionary = fotograma.get("pelota", {})
	return Vector2(float(pelota.get("x", 0.0)), float(pelota.get("y", 0.0)))


static func _direccion(avance: Vector2) -> int:
	if avance.length_squared() < 0.0004:
		return SpritesPartido.ABAJO
	return SpritesPartido.direccion_desde(ProyeccionPartido.direccion_pantalla(avance))
