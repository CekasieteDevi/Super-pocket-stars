class_name FisicaV2
extends RefCounted

## Parámetros de la física del Motor V2 (docs/motor_v2.md): lee
## data/fisica_v2.json y les aplica el césped y el clima del partido (etapa
## 1), y arma los del cuerpo y sus clips (etapa 2). El resultado se le pasa al
## motor en C++ (PelotaV2Nativa, CuerposV2Nativos, MundoV2Nativo): así se
## calibra sin recompilar.

const RUTA := "res://data/fisica_v2.json"
const RUTA_ACCIONES := "res://data/acciones_v2.json"

static var _datos: Dictionary = {}
static var _acciones: Dictionary = {}


static func datos() -> Dictionary:
	if _datos.is_empty():
		var texto := FileAccess.get_file_as_string(RUTA)
		var leido: Variant = JSON.parse_string(texto)
		assert(leido is Dictionary, "No se pudo leer %s" % RUTA)
		_datos = leido
	return _datos


## `calidad_cancha`: la de EstadoCancha del local (-8 a +3, 0 = neutra).
## `clima`: el de Clima ("" o "Normal" = sin cambios). `direccion_viento`:
## hacia dónde sopla, en el plano de la cancha (x a lo largo, y a lo ancho).
static func parametros(calidad_cancha := 0.0, clima := "", direccion_viento := Vector2.RIGHT) -> Dictionary:
	var d := datos()
	var p: Dictionary = (d["pelota"] as Dictionary).duplicate()
	var cesped: Dictionary = d["cesped"]
	p["frenado_rodando"] = float(p["frenado_rodando"]) * (1.0 + float(cesped["frenado_por_punto"]) * calidad_cancha)
	p["restitucion_piso"] = float(p["restitucion_piso"]) + float(cesped["restitucion_por_punto"]) * calidad_cancha
	var por_clima: Dictionary = (d["clima"] as Dictionary).get(clima, {})
	for clave in por_clima:
		if clave == "viento_ms":
			var v := direccion_viento.normalized() * float(por_clima[clave])
			p["viento_x"] = v.x
			p["viento_z"] = v.y
		else:
			p[clave] = float(p[clave]) * float(por_clima[clave])
	return p


## Los de la locomoción y los gestos (CuerposV2Nativos.configurar,
## MundoV2Nativo.configurar_cuerpos). La locomoción usa los números del motor
## actual (MotorEspacial.pesos(): fisica, control y esfuerzo), así los dos
## motores corren igual; de data/fisica_v2.json sale solo lo nuevo.
static func parametros_cuerpo() -> Dictionary:
	var fisica: Dictionary = MotorEspacial.pesos()["fisica"]
	var p := {
		"frenada": float(fisica["frenada"]),
		"giro_acel": float(fisica["giro_acel"]),
		"arranque_extra": float(fisica["arranque_extra"]),
		"rapidez_para_girar": float(MotorEspacial.pesos_control()["rapidez_para_girar"]),
	}
	var esfuerzo := MotorEspacial.pesos_esfuerzo()
	for clave in ["peso_aceleracion", "umbral_sprint", "consumo_sprint", "recuperacion_reserva",
			"reserva_para_frenar", "piso_sprint"]:
		p[clave] = float(esfuerzo[clave])
	p.merge(datos()["cuerpo"])
	return p


## Los clips de data/acciones_v2.json (lo genera tools/generar_acciones_v2.py).
static func clips() -> Dictionary:
	if _acciones.is_empty():
		var leido: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUTA_ACCIONES))
		assert(leido is Dictionary, "No se pudo leer %s" % RUTA_ACCIONES)
		_acciones = leido
	return _acciones["clips"]


## El físico de un jugador para el cuerpo, con las mismas cuentas que el motor
## actual: `atributos` como los de Player (velocidad, aceleracion, agilidad).
## `energia` (0..1, la del partido) baja punta y aceleración con
## Cansancio.factor_stats. El motor actual no la aplica al andar (solo a los
## duelos); el V2 sí, porque la carrera es parte del físico.
static func fisico_de(atributos: Dictionary, energia := 1.0) -> Dictionary:
	var j := {"atributos": atributos}
	return {
		"vel_max": MotorEspacial._vel_max(j),
		"aceleracion": MotorEspacial._aceleracion(j),
		"giro": MotorEspacial._giro_de(j),
		"cansancio": Cansancio.factor_stats(energia),
	}


## Los del toque (etapa 3; CanchitaV2Nativa.configurar): data/fisica_v2.json,
## "toque". Los clips van por nombre y el motor los busca en clips().
static func parametros_toque() -> Dictionary:
	return (datos()["toque"] as Dictionary).duplicate(true)


## El físico de fisico_de más lo que usa el toque (etapa 3): pases y control,
## como los de Player (0..100).
static func jugador_de(atributos: Dictionary, energia := 1.0) -> Dictionary:
	var f := fisico_de(atributos, energia)
	f["pases"] = float(atributos.get("pases", 50.0))
	f["control"] = float(atributos.get("control", 50.0))
	return f
