extends SceneTree

const SEED := 9600
const Resumen := preload("res://tests/resumen_ocasiones.gd")
var fallos := 0


func _init() -> void:
	var registros := [_remate(1, 0.0, "gol"), _remate(2, 0.1999, "bloqueado"),
		_remate(3, 0.2, "afuera"), _remate(4, 1.0, "gol")]
	registros[0]["resultado"] = "atajada"
	registros.append(registros[0].duplicate(true))
	var forzado := _remate(5, 0.9, "gol")
	forzado["ejecucion"] = {"forzado_laboratorio": true}
	registros.append(forzado)
	registros.append({"remate_id": 6, "resultado": "gol"})
	registros.append(_remate(7, NAN, "gol"))
	var pendiente := _remate(8, 0.6, "gol")
	pendiente.erase("resultado_observado")
	registros.append(pendiente)
	var partidos := [{"remates": registros}, {"remates": [_remate(1, 0.0, "afuera")]}]
	var original := var_to_bytes(partidos)
	var resumen := Resumen.resumir(partidos)
	var filas: Array = resumen["filas"]
	_comprobar(filas.size() == 3, "bordes 0, 0.2 y 1 quedan en sus intervalos; vacíos omitidos")
	_comprobar(filas[0]["intentos"] == 3 and filas[0]["goles"] == 1
		and filas[0]["bloqueados"] == 1 and is_equal_approx(filas[0]["conversion"], 1.0 / 3.0),
		"denominador incluye bloqueos y permite mismo ID en partidos distintos")
	_comprobar(filas[1]["desde"] == 0.2 and filas[2]["incluye_hasta"], "límites inferiores inclusivos y último extremo cerrado")
	_comprobar(resumen["excluidos"] == {"forzados": 1, "sin_contexto": 1, "duplicados": 1, "invalidos": 1, "sin_resultado": 1}, "exclusiones explícitas; no se cuentan goles sin evento final")
	_comprobar(var_to_bytes(partidos) == original, "agregar no modifica los registros originales")
	var particiones := true
	for fila in filas:
		for dimension in ["por_presion", "por_arquero"]:
			var intentos := 0
			var goles := 0
			for grupo in fila[dimension].values():
				intentos += grupo["intentos"]
				goles += grupo["goles"]
			particiones = particiones and intentos == fila["intentos"] and goles == fila["goles"]
	_comprobar(particiones, "subgrupos conservan intentos y goles")
	_comprobar(Resumen.resumir([])["filas"].is_empty(), "sin datos no aparece conversión ficticia")
	var tipos := Resumen.resumir([{"remates": [_remate(1, 0.5, "gol", "cabezazo"), _remate(2, 0.5, "afuera", "tiros_libres")]}])
	_comprobar(tipos["filas"].size() == 2, "cabezazos y libres no se mezclan")
	var estratos := [_remate(1, 0.5, "gol"), _remate(2, 0.5, "afuera"), _remate(3, 0.5, "palo")]
	estratos[0]["ocasion"]["presion"] = 0.0
	estratos[1]["ocasion"]["presion"] = 0.33
	estratos[2]["ocasion"]["presion"] = 0.66
	estratos[0]["ocasion"]["arco_desprotegido"] = true
	estratos[2]["ocasion"].erase("arco_desprotegido")
	var estratificado: Dictionary = Resumen.resumir([{"remates": estratos}])["filas"][0]
	_comprobar(estratificado["por_presion"].size() == 3
		and estratificado["por_presion"]["[0.33,0.66)"]["intentos"] == 1,
		"presión respeta extremos entre intervalos")
	_comprobar(estratificado["por_arquero"].size() == 3
		and estratificado["por_arquero"]["desprotegido"]["goles"] == 1,
		"arquero alcanzable, desprotegido y dato ausente permanecen separados")
	print("FALLOS=%d" % fallos)
	quit(1 if fallos else 0)


func _remate(id: int, geometria: float, resultado: String, tipo: String = "tiro") -> Dictionary:
	return {"remate_id": id, "atributo": tipo, "resultado": resultado, "resultado_observado": resultado,
		"ocasion": {"geometria_comun": geometria, "presion": 0.4, "arco_desprotegido": false}}


func _comprobar(condicion: bool, mensaje: String) -> void:
	print(("OK: " if condicion else "FALLA: ") + mensaje)
	if not condicion: fallos += 1
