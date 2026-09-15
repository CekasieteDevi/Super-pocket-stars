extends SceneTree

const SEED := 9001
var fallos := 0


func _init() -> void:
	for local in [true, false]:
		var arco := MotorEspacial.arco_rival(local)
		var sentido := 1.0 if local else -1.0
		var desde := arco - Vector2(16.0 * sentido, 0.0)
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED
		var estado := {"rng": rng, "jugadores": {
			1: {"equipo_local": not local, "rol": "ARQ", "pos": arco},
			2: {"equipo_local": not local, "rol": "DFC", "pos": Vector2.ZERO}}}
		var original: Dictionary = estado["jugadores"].duplicate(true)
		var azar := rng.state
		var frontal := MotorEspacial.describir_ocasion(estado, desde, local)
		var debil := MotorEspacial.modelo_destino_remate(frontal["geometria_comun"], 0.3, 20.0)
		var fuerte := MotorEspacial.modelo_destino_remate(frontal["geometria_comun"], 0.8, 90.0)
		_comprobar(fuerte["probabilidad_modelo_porteria_sin_bloqueo"] > debil["probabilidad_modelo_porteria_sin_bloqueo"], "misma ocasión distingue técnica sin modificar contexto")
		_comprobar(frontal == MotorEspacial.describir_ocasion(estado, desde, local), "evaluar habilidad no modifica la ocasión")
		var lateral := MotorEspacial.describir_ocasion(estado, desde + Vector2(0, 20), local)
		_comprobar(frontal["angulo_radianes"] > lateral["angulo_radianes"], "frontal abre el ángulo entre postes")
		_comprobar(is_equal_approx(frontal["distancia"], 16.0), "distancia en metros en ambos sentidos")
		_comprobar(estado["jugadores"] == original and rng.state == azar, "consulta no modifica jugadores ni azar")
		estado["jugadores"][2]["pos"] = desde + Vector2(sentido, 0)
		var marcada := MotorEspacial.describir_ocasion(estado, desde, local)
		_comprobar(marcada["presion"] > frontal["presion"] and marcada["obstruida"], "defensor cercano registra presión y bloqueo")
		_comprobar(marcada["bloqueador"] == MotorEspacial._bloqueador_de_tiro(estado, desde, local), "obstrucción usa la resolución vigente")
		for tipo in ["cabezazo", "penal"]:
			var especial := MotorEspacial.describir_ocasion(estado, desde, local, tipo)
			_comprobar(not especial["obstruida"] and especial["tipo"] == tipo, "ruta especial conserva su tipo y excluye bloqueo corporal")
		estado["jugadores"][1]["pos"] = Vector2.ZERO
		_comprobar(frontal["posicion_arquero"]["x"] == arco.x, "instantánea no cambia al moverse el arquero")
		estado["jugadores"].erase(1)
		_comprobar(MotorEspacial.describir_ocasion(estado, desde, local)["posicion_arquero"] == null, "arco sin arquero no inventa posición")
		var en_poste := MotorEspacial.describir_ocasion(estado, arco + Vector2(0, MotorEspacial.ARCO_MEDIO_ANCHO), local)
		_comprobar(is_finite(en_poste["angulo_radianes"]), "posición en el poste no produce valores inválidos")
	var iguales := true
	var remates := 0
	for division in [0, 4, 9]:
		for indice in range(10):
			var normal := _partido(division, SEED + indice, false)
			var observado := _partido(division, SEED + indice, true)
			for remate in observado["stats"]["registro_remates"]:
				iguales = iguales and remate.has("ocasion") and remate.has("ejecucion")
				var probabilidad: float = remate["ejecucion"]["probabilidad_modelo_porteria_sin_bloqueo"]
				iguales = iguales and probabilidad >= 0.0 and probabilidad <= 1.0
				remates += 1
			_quitar_mediciones(normal)
			_quitar_mediciones(observado)
			iguales = iguales and normal == observado
	_comprobar(iguales and remates > 0, "30 pares conservan eventos, estadísticas, XP y RNG; %d ocasiones registradas" % remates)
	print("FALLOS=%d" % fallos)
	quit(1 if fallos else 0)


## Lo que SOLO existe con el diagnostico prendido: el registro de remates y
## los contadores de medir_opciones_colectivas. Compararlos es comparar si
## se midio, no si el partido cambio.
static func _quitar_mediciones(resultado: Dictionary) -> void:
	for clave in ["registro_remates", "jugadas_colectivas", "metros_conduccion", "muestra_pase_atras"]:
		resultado["stats"].erase(clave)


func _comprobar(condicion: bool, mensaje: String) -> void:
	print(("OK: " if condicion else "FALLA: ") + mensaje)
	if not condicion: fallos += 1


func _partido(division: int, semilla: int, diagnostico: bool) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var a := Team.generar("A", rng, 0, NivelDivision.potencial(division), "Uruguay", NivelDivision.realizacion(division))
	var b := Team.generar("B", rng, 400, NivelDivision.potencial(division), "Uruguay", NivelDivision.realizacion(division))
	rng.seed = semilla
	var resultado := MotorEspacial.simular(a, b, rng, false, false, diagnostico)
	resultado["azar_final"] = rng.state
	return resultado
