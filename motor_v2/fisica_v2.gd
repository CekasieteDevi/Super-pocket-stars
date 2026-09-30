class_name FisicaV2
extends RefCounted

## Parámetros de la física del Motor V2 (docs/motor_v2.md, etapa 1): lee
## data/fisica_v2.json y les aplica el césped y el clima del partido. El
## resultado se le pasa al motor en C++ (PelotaV2Nativa.configurar,
## MundoV2Nativo.configurar_pelota): así se calibra sin recompilar.

const RUTA := "res://data/fisica_v2.json"

static var _datos: Dictionary = {}


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
