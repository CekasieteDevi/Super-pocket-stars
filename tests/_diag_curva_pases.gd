extends SceneTree

## Medición, no test. Solo lectura del guardado: simula en memoria el mismo
## botón Jugar fecha y mide cuánto se aparta de la recta la pelota DIBUJADA
## en cada pase, contra la pelota cruda del motor proyectada igual.
const SEED := 0
const SUBPASOS := 8
const GIRO_MIN := 20.0


func _init() -> void:
	call_deferred("_probar")


func _probar() -> void:
	var lista: Array = []
	var ruta := "res://scratch/diag_curva_pases_fotogramas.bin"
	if "reusar" in OS.get_cmdline_user_args() and FileAccess.file_exists(ruta):
		var leer := FileAccess.open(ruta, FileAccess.READ)
		lista = leer.get_var()
		leer.close()
	else:
		var gs := root.get_node("GameState")
		assert(gs.cargar_partida())
		gs.jugar_siguiente_fecha()
		lista = gs.ultimos_fotogramas
		var archivo := FileAccess.open(ruta, FileAccess.WRITE)
		archivo.store_var(lista)
		archivo.close()
	print("FOTOGRAMAS ", lista.size())
	var vista := VistaPartido.new()
	root.add_child(vista)
	vista.iniciar(lista, Color.RED, Color.BLUE)
	vista.set_process(false)
	# Muestras: [tick, t, dibujada, motor, libre, tiene_accion]
	var muestras: Array = []
	for i in range(lista.size() - 1):
		var corte := bool(lista[i + 1].get("corte", false))
		for s in range(SUBPASOS):
			var t := float(s) / float(SUBPASOS)
			vista._mostrar(i, t)
			var bola := {}
			for ent in vista.vista.entidades:
				if ent["tipo"] == "pelota":
					bola = ent
			var pa: Dictionary = lista[i]["pelota"]
			var pb: Dictionary = lista[i + 1]["pelota"] if not corte else pa
			var motor := _pantalla(_pos(pa).lerp(_pos(pb), t), lerpf(float(pa.get("z", 0.0)), float(pb.get("z", 0.0)), t))
			var dib := Vector2.INF
			if not bola.is_empty():
				dib = _pantalla(bola["pos"], float(bola["z"])) + Vector2(bola.get("offset_px", Vector2.ZERO))
				if bool(bola.get("anclada", false)):
					dib = _pantalla(bola["pos"], 0.0) + Vector2(bola["anclaje_px"])
			var suelo := Vector2.INF if bola.is_empty() else _pantalla(bola["pos"], 0.0)
			muestras.append({"i": i, "t": t, "dib": dib, "motor": motor, "suelo": suelo,
				"z": 0.0 if bola.is_empty() else float(bola["z"]),
				"libre": int(pa.get("poseedor_id", -1)) == -1 or int(pb.get("poseedor_id", -1)) == -1,
				"pase": bool(pa.get("es_pase", false)) or bool(pb.get("es_pase", false)),
				"accion": not lista[i].get("acciones", []).is_empty() or not lista[i + 1].get("acciones", []).is_empty(),
				"corte": corte and s == SUBPASOS - 1})
	_giros(lista, muestras, "dib")
	_giros(lista, muestras, "motor")
	_pases(lista, muestras)
	vista.free()
	quit()


## Giros bruscos de la trayectoria con la pelota suelta. Dentro de un tick
## sin contacto no debería haber ninguno: la pelota va derecho.
func _giros(lista: Array, muestras: Array, campo: String) -> void:
	var dentro := 0
	var borde := 0
	var borde_sin_accion := 0
	var impresos := 0
	for k in range(1, muestras.size() - 1):
		var m: Dictionary = muestras[k]
		if not m["libre"] or muestras[k - 1]["corte"] or m["corte"]:
			continue
		var a: Vector2 = muestras[k - 1][campo]
		var b: Vector2 = m[campo]
		var c: Vector2 = muestras[k + 1][campo]
		if a == Vector2.INF or b == Vector2.INF or c == Vector2.INF:
			continue
		var v1 := b - a
		var v2 := c - b
		if v1.length() < 1.0 or v2.length() < 1.0:
			continue
		var giro := rad_to_deg(absf(v1.angle_to(v2)))
		if giro < GIRO_MIN:
			continue
		if float(m["t"]) == 0.0:
			borde += 1
			if not m["accion"]:
				borde_sin_accion += 1
		else:
			dentro += 1
		if impresos < 25 and campo == "motor" and not m["accion"]:
			impresos += 1
			print("GIRO_%s i=%d t=%.3f min=%.2f giro=%.0f v1=%.1f v2=%.1f pase=%s acciones=%s" % [
				campo, m["i"], m["t"], float(lista[m["i"]]["minuto"]), giro, v1.length(), v2.length(),
				m["pase"], lista[m["i"]].get("acciones", []) + lista[m["i"] + 1].get("acciones", [])])
	print("GIROS_%s dentro_tick=%d borde_tick=%d borde_sin_accion=%d" % [campo, dentro, borde, borde_sin_accion])


## Por pase: máxima distancia (px a zoom base) de la pelota a la recta
## entre la salida y la llegada.
func _pases(lista: Array, muestras: Array) -> void:
	var desvios_dib: Array = []
	var desvios_motor: Array = []
	var peores: Array = []
	var rasos: Array = []
	var k := 0
	while k < muestras.size():
		if not muestras[k]["pase"] or not muestras[k]["libre"]:
			k += 1
			continue
		var inicio := k
		while k < muestras.size() and muestras[k]["pase"] and muestras[k]["libre"] and not muestras[k]["corte"]:
			k += 1
		if k == inicio:
			k += 1
			continue
		var fin := k - 1
		if fin - inicio < SUBPASOS:
			continue
		var d_suelo := _desvio(muestras, inicio, fin, "suelo")
		var z_max := 0.0
		for q in range(inicio, fin + 1):
			z_max = maxf(z_max, float(muestras[q]["z"]))
		var d_dib := _desvio(muestras, inicio, fin, "dib")
		var d_mot := _desvio(muestras, inicio, fin, "motor")
		desvios_dib.append(d_dib)
		desvios_motor.append(d_mot)
		peores.append([d_dib, d_mot, muestras[inicio]["i"], muestras[fin]["i"], d_suelo, z_max])
		if z_max < 0.1:
			rasos.append(d_dib)
	desvios_dib.sort()
	desvios_motor.sort()
	peores.sort_custom(func(x, y): return x[0] > y[0])
	print("PASES n=%d desvio_dib p50=%.1f p90=%.1f max=%.1f | desvio_motor p50=%.1f p90=%.1f max=%.1f" % [
		desvios_dib.size(), _pct(desvios_dib, 0.5), _pct(desvios_dib, 0.9), _pct(desvios_dib, 1.0),
		_pct(desvios_motor, 0.5), _pct(desvios_motor, 0.9), _pct(desvios_motor, 1.0)])
	rasos.sort()
	print("PASES_RASOS n=%d desvio_dib p50=%.1f p90=%.1f max=%.1f" % [rasos.size(), _pct(rasos, 0.5), _pct(rasos, 0.9), _pct(rasos, 1.0)])
	for p in peores.slice(0, 12):
		print("PEOR_PASE dib=%.1f motor=%.1f suelo=%.1f z_max=%.2f ticks=%d-%d min=%.2f" % [p[0], p[1], p[4], p[5], p[2], p[3], float(lista[p[2]]["minuto"])])
	peores.sort_custom(func(x, y): return x[4] > y[4])
	for p in peores.slice(0, 8):
		print("PEOR_SUELO suelo=%.1f dib=%.1f z_max=%.2f ticks=%d-%d min=%.2f" % [p[4], p[0], p[5], p[2], p[3], float(lista[p[2]]["minuto"])])


static func _desvio(muestras: Array, inicio: int, fin: int, campo: String) -> float:
	var a: Vector2 = muestras[inicio][campo]
	var b: Vector2 = muestras[fin][campo]
	var peor := 0.0
	for k in range(inicio, fin + 1):
		var p: Vector2 = muestras[k][campo]
		if p == Vector2.INF or a == Vector2.INF or b == Vector2.INF:
			continue
		peor = maxf(peor, _dist_segmento(p, a, b))
	return peor


static func _dist_segmento(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	if ab.length_squared() < 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _pct(v: Array, q: float) -> float:
	if v.is_empty():
		return 0.0
	return float(v[mini(v.size() - 1, int(q * float(v.size() - 1)))])


static func _pantalla(p: Vector2, z: float) -> Vector2:
	return ProyeccionPartido.sim_a_pantalla(p.x, p.y, z, Vector2.ZERO, CamaraPartido.PX_POR_METRO_BASE, Vector2.ZERO)


static func _pos(d: Dictionary) -> Vector2:
	return Vector2(float(d["x"]), float(d["y"]))
