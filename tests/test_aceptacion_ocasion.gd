extends SceneTree

## Etapa 9, aceptacion: en contextos controlados el angulo abierto mejora la
## ocasion, la presion la reduce, el arquero fuera de posicion deja mas arco,
## y la misma ocasion cuesta lo mismo en primera que en decima.

const SEED := 9901
const MUESTRAS := 1500

var fallos := 0


func _init() -> void:
	for local in [true, false]:
		_test_el_angulo_abierto_mejora(local)
		_test_la_presion_reduce_la_punteria(local)
		_test_el_bloqueador_no_cobra_dos_veces(local)
		_test_el_arquero_corrido_deja_arco(local)
		_test_la_ocasion_cuesta_lo_mismo_en_cada_division(local)
	print("FALLOS=%d" % fallos)
	quit(1 if fallos else 0)


func _ok(condicion: bool, mensaje: String) -> void:
	print(("OK: " if condicion else "FALLA: ") + mensaje)
	if not condicion:
		fallos += 1


func _lado(local: bool) -> String:
	return "local" if local else "visita"


## Todos los atributos de los dos planteles en `nivel`, los 22 lejos, el
## arquero rival en su arco y el rematador a `distancia` de frente.
func _escena(local: bool, distancia: float, nivel: float) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var casa := Team.generar("Casa", rng, 0)
	var visita := Team.generar("Visita", rng, 400)
	for equipo in [casa, visita]:
		for jugador in equipo.jugadores:
			for atributo in jugador["atributos"]:
				jugador["atributos"][atributo] = nivel
			# El nivel del partido sale de la media guardada, no de los
			# atributos: sin esto un plantel entero en 85 juega contra el nivel
			# con que se genero y la escena deja de ser "primera".
			jugador["media"] = nivel
		equipo.reset_partido()
	casa.local = true
	visita.local = false
	casa.clima_partido = ""
	visita.clima_partido = ""
	casa.arbitro_partido = Arbitro.generar(rng)
	visita.arbitro_partido = casa.arbitro_partido
	var estado := MotorEspacial.crear_estado(casa, visita, rng)
	MotorEspacial._reiniciar_desde_medio(estado, local, 1)
	var atacante: Dictionary = (casa if local else visita).jugadores.back()
	var clave := MotorEspacial.clave_de(atacante["id"], local)
	for id in estado["jugadores"]:
		estado["jugadores"][id]["pos"] = Vector2(0.0, 30.0)
	var arquero := MotorEspacial._clave_arquero(estado, not local)
	var arco := MotorEspacial.arco_rival(local)
	var sentido := 1.0 if local else -1.0
	estado["jugadores"][arquero]["pos"] = arco - Vector2(sentido * 1.0, 0.0)
	var poseedor: Dictionary = estado["jugadores"][clave]
	poseedor["pos"] = arco - Vector2(sentido * distancia, 0.0)
	estado["pelota"]["pos"] = poseedor["pos"]
	estado["pelota"]["poseedor_id"] = clave
	return {"estado": estado, "poseedor": poseedor, "jugador": atacante, "casa": casa,
		"visita": visita, "arquero": arquero, "sentido": sentido}


## Resuelve el mismo remate MUESTRAS veces con semillas distintas.
func _medir(escena: Dictionary) -> Dictionary:
	var plantilla: Dictionary = escena["estado"]
	var puerta := 0
	var goles := 0
	for indice in range(MUESTRAS):
		escena["casa"].reset_partido()
		escena["visita"].reset_partido()
		var estado := plantilla.duplicate(true)
		estado["rng"].seed = SEED + indice
		var poseedor: Dictionary = estado["jugadores"][escena["poseedor"]["clave"]]
		MotorEspacial._resolver_tiro(estado, poseedor, escena["jugador"])
		var tipo := str(estado["pelota"].get("remate", {}).get("tipo", ""))
		if tipo in ["gol", "atajada"]:
			puerta += 1
		if tipo == "gol":
			goles += 1
	return {"puerta": float(puerta) / MUESTRAS, "goles": float(goles) / MUESTRAS,
		"conversion_arco": float(goles) / maxf(float(puerta), 1.0)}


func _test_el_angulo_abierto_mejora(local: bool) -> void:
	var escena := _escena(local, 16.0, 60.0)
	var estado: Dictionary = escena["estado"]
	var desde: Vector2 = escena["poseedor"]["pos"]
	var frontal := MotorEspacial.describir_ocasion(estado, desde, local)
	var cerrado := MotorEspacial.describir_ocasion(estado, desde + Vector2(0.0, 13.0), local)
	var p_frontal: float = MotorEspacial.modelo_destino_remate(frontal["geometria_comun"],
		frontal["geometria_comun"], 60.0, "tiro", 0.37)["probabilidad_modelo_porteria_sin_bloqueo"]
	var p_cerrado: float = MotorEspacial.modelo_destino_remate(cerrado["geometria_comun"],
		cerrado["geometria_comun"], 60.0, "tiro", 0.37)["probabilidad_modelo_porteria_sin_bloqueo"]
	_ok(frontal["angulo_radianes"] > cerrado["angulo_radianes"] and p_frontal > p_cerrado,
		"(%s) de frente a 16 m va al arco %.2f; corrido 13 m hacia la banda, %.2f" % [_lado(local), p_frontal, p_cerrado])


func _test_la_presion_reduce_la_punteria(local: bool) -> void:
	var libre := _medir(_escena(local, 18.0, 60.0))
	var escena := _escena(local, 18.0, 60.0)
	var estado: Dictionary = escena["estado"]
	var sentido: float = escena["sentido"]
	# Dos rivales pegados al costado y detras: presionan pero no estan en la
	# linea del remate, asi que no bloquean.
	var puestos := 0
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if bool(e["equipo_local"]) == local or str(e["rol"]) == "ARQ" or puestos >= 2:
			continue
		e["pos"] = escena["poseedor"]["pos"] + Vector2(-sentido * 0.5, 1.6 if puestos == 0 else -1.6)
		puestos += 1
	var ocasion := MotorEspacial.describir_ocasion(estado, escena["poseedor"]["pos"], local)
	var marcado := _medir(escena)
	_ok(not ocasion["obstruida"] and float(ocasion["presion_sin_bloqueador"]) > 0.6
			and marcado["puerta"] < libre["puerta"] - 0.08,
		"(%s) a 18 m sin nadie va al arco %.3f; con dos encima (presion %.2f, sin bloqueo) %.3f" % [
			_lado(local), libre["puerta"], float(ocasion["presion_sin_bloqueador"]), marcado["puerta"]])
	var neutro: float = MotorEspacial.modelo_destino_remate(0.4, 0.4, 60.0, "tiro", 0.37)["probabilidad_modelo_porteria_sin_bloqueo"]
	var sin_dato: float = MotorEspacial.modelo_destino_remate(0.4, 0.4, 60.0, "tiro")["probabilidad_modelo_porteria_sin_bloqueo"]
	var cabeza_libre: float = MotorEspacial.modelo_destino_remate(0.4, 0.4, 60.0, "cabezazo", 0.0)["probabilidad_modelo_porteria_sin_bloqueo"]
	var cabeza_marcada: float = MotorEspacial.modelo_destino_remate(0.4, 0.4, 60.0, "cabezazo", 1.0)["probabilidad_modelo_porteria_sin_bloqueo"]
	_ok(is_equal_approx(neutro, sin_dato) and is_equal_approx(cabeza_libre, cabeza_marcada),
		"(%s) la presion media no mueve la punteria y el cabezazo no la lee" % _lado(local))


func _test_el_bloqueador_no_cobra_dos_veces(local: bool) -> void:
	var escena := _escena(local, 18.0, 60.0)
	var estado: Dictionary = escena["estado"]
	var sentido: float = escena["sentido"]
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if bool(e["equipo_local"]) != local and str(e["rol"]) != "ARQ":
			e["pos"] = escena["poseedor"]["pos"] + Vector2(sentido * 2.0, 0.0)
			break
	var ocasion := MotorEspacial.describir_ocasion(estado, escena["poseedor"]["pos"], local)
	_ok(ocasion["obstruida"] and float(ocasion["presion"]) > 0.3 and float(ocasion["presion_sin_bloqueador"]) == 0.0,
		"(%s) el que se cruza en la linea presiona %.2f, pero la punteria lee %.2f: ya tiene su duelo de bloqueo" % [
			_lado(local), float(ocasion["presion"]), float(ocasion["presion_sin_bloqueador"])])


func _test_el_arquero_corrido_deja_arco(local: bool) -> void:
	var centrado := _medir(_escena(local, 14.0, 60.0))
	var escena := _escena(local, 14.0, 60.0)
	var estado: Dictionary = escena["estado"]
	var arco := MotorEspacial.arco_rival(local)
	estado["jugadores"][escena["arquero"]]["pos"] = arco - Vector2(escena["sentido"] * 1.0, 2.8)
	var corrido := _medir(escena)
	_ok(corrido["conversion_arco"] > centrado["conversion_arco"] + 0.05,
		"(%s) a 14 m convierte %.3f de los remates al arco con el arquero centrado y %.3f con el arquero corrido 2,8 m" % [
			_lado(local), centrado["conversion_arco"], corrido["conversion_arco"]])


## El duelo mira la diferencia en puntos. Con los dos planteles enteros en 40
## o en 85, la misma ocasion lejana tiene que convertir lo mismo: antes de la
## etapa la fuerza y la cobertura eran multiplicadores y primera atajaba mas.
func _test_la_ocasion_cuesta_lo_mismo_en_cada_division(local: bool) -> void:
	var bajo := _medir(_escena(local, 27.0, 40.0))
	var alto := _medir(_escena(local, 27.0, 85.0))
	_ok(absf(bajo["conversion_arco"] - alto["conversion_arco"]) < 0.04 and absf(bajo["puerta"] - alto["puerta"]) < 0.02,
		"(%s) a 27 m, todo en 40: al arco %.3f y convierte %.3f; todo en 85: %.3f y %.3f" % [
			_lado(local), bajo["puerta"], bajo["conversion_arco"], alto["puerta"], alto["conversion_arco"]])
