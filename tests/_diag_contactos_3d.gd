extends SceneTree

## Medición (no es test): en el partido de muestra 3D, si la pelota dibujada
## toca la parte del cuerpo que corresponde en el instante del golpe, si la
## acompaña en las recepciones y si el desvío no la hace saltar.
## Recorre toda la muestra de a 0.1 tick con el render 3D real.
##   <godot> --headless --path . --script tests/_diag_contactos_3d.gd

const SEMILLA := 20260818
const PASO := 0.1
## Superficie de la pelota a menos de esto del punto de contacto = toca.
const TOCA_M := 0.12
## Salto que el desvío de contacto le puede AGREGAR a la pelota entre dos
## muestras (0.1 tick = 25 ms), sin contar su propio vuelo: el límite de
## VistaCancha3D (16 m/s = 0.4 m) más un margen.
const SALTO_MAX_M := 0.45

var _muestra: MuestraAnimaciones3D
var _t := 0.0
var _pendiente := false
var _datos := {}
var _pelota_previa := Vector3.INF
var _dibujada_previa := Vector3.ZERO
var _idx_medido := -1
var _capturar := false
var _capturadas := {}
var _informado := false
var _conduccion := {}
var _amague_min := INF
## Pelota a más de esto del pie más cercano, en promedio, durante un regate =
## no la lleva. La elástica la saca 0.85 m al costado a propósito (ver
## VistaPartido._trayectoria_regate): el promedio igual tiene que quedar cerca.
const CONDUCE_MEDIA_M := 0.35
var _salto_por_accion := {}


func _initialize() -> void:
	_capturar = "capturar" in OS.get_cmdline_user_args()
	var escena: PackedScene = load("res://match/3d/muestra_animaciones_3d.tscn")
	_muestra = escena.instantiate()
	_muestra.en_loop = false
	root.add_child(_muestra)
	process_frame.connect(_cuadro)


func _cuadro() -> void:
	var rep := _muestra.reproductor
	if rep == null or rep.fotogramas.is_empty():
		return
	rep.pausado = true
	var v3d := rep.vista as VistaCancha3D
	if _pendiente:
		_medir(v3d, rep)
	if _t >= float(rep.fotogramas.size() - 1):
		if not _informado:
			_informar()
			_informado = true
			for a in _capturadas:
				_cola.append([a, _capturadas[a], 35.0, ""])
				# De costado y de atrás: el taco y la chilena se tapan con el cuerpo de frente.
				_cola.append([a, _capturadas[a], 100.0, "_costado"])
				_cola.append([a, _capturadas[a], 160.0, "_atras"])
		if _capturar and _capturar_siguiente():
			return
		quit()
		return
	var idx := int(_t)
	rep.posicion = _t
	rep._mostrar(idx, _t - float(idx))
	rep._seguir_camara(idx, 0.05)
	_pendiente = true
	_t += PASO


## Cuerpos: pares de personas a menos de CUERPOS_MIN_M, en el motor y en el
## dibujo 3D (con la separación de VistaCancha3D).
const CUERPOS_MIN_M := 0.55
var _encimados_motor := 0
var _encimados_3d := 0
## Estiradas que no llegan: lo más cerca que pasa la pelota de guantes o cabeza.
const NO_LLEGA_MIN_M := 0.1
var _no_llega_min := INF


func _medir(v3d: VistaCancha3D, rep: VistaPartido) -> void:
	var pelota: Vector3 = v3d._pelota.global_position
	var crudos := []
	for ent in v3d.entidades:
		if str(ent.get("tipo", "")) in ["jugador", "oficial"]:
			crudos.append(ent["pos"])
	var dibujados := []
	for m in v3d._personas.values():
		if m.visible:
			dibujados.append(Vector2(m.global_position.x, m.global_position.z))
	for lista_p in [crudos, dibujados]:
		var n := 0
		for a in lista_p.size():
			for b in range(a + 1, lista_p.size()):
				if (lista_p[a] as Vector2).distance_to(lista_p[b]) < CUERPOS_MIN_M:
					n += 1
		if lista_p == crudos:
			_encimados_motor += n
		else:
			_encimados_3d += n
	# El cuadro medido es el que se mostró en la vuelta anterior (_t ya avanzó).
	# Mismo redondeo que VistaCancha3D (int de la posición de reproducción).
	var idx_mostrado := mini(int(rep.posicion), rep.fotogramas.size() - 1)
	var reubica := idx_mostrado != _idx_medido and VistaPartido._es_reubicacion(rep.fotogramas[idx_mostrado])
	_idx_medido = idx_mostrado
	# Salto = lo que el desvío agrega Y la pelota dibujada también se mueve.
	# Con la pelota agarrada el desvío cambia (la del motor se mueve) pero la
	# dibujada queda quieta en las manos: eso no es un salto.
	var salto := 0.0
	if _pelota_previa != Vector3.INF:
		salto = minf(v3d._correccion.distance_to(_pelota_previa), pelota.distance_to(_dibujada_previa))
	_pelota_previa = v3d._correccion
	_dibujada_previa = pelota
	var radio := VistaCancha3D.RADIO_PELOTA * VistaCancha3D.ESCALA_PELOTA
	# Conducción (regates y amague): la pelota va con los pies toda la acción.
	for pie in v3d._pies:
		var a := str(pie["accion"])
		if not (MotorEspacial.es_accion_regate(a) or a == "amague_centro"):
			continue
		var m: Jugador3D = pie["modelo"]
		var dpie := minf(m.ancla("Pie_R").distance_to(pelota), m.ancla("Pie_L").distance_to(pelota)) - radio
		var dcuerpo := Vector2(pelota.x, pelota.z).distance_to(pie["pos"])
		if a == "amague_centro":
			_amague_min = minf(_amague_min, dcuerpo)
		# Solo la pelota del que conduce (no otro con la misma acción lejos).
		if dcuerpo > 3.0:
			continue
		# El globito la levanta por arriba del rival a propósito: no cuenta el vuelo.
		if a == "regate_globito" and pelota.y > radio + 0.3:
			continue
		if _capturar and not _capturadas.has(a) and absf(float(pie["fase"]) - 0.5) < 0.05:
			_capturadas[a] = {"t": rep.posicion, "modelo": m}
		if not _conduccion.has(a):
			_conduccion[a] = {"suma": 0.0, "n": 0, "max": 0.0}
		_conduccion[a]["suma"] += dpie
		_conduccion[a]["n"] += 1
		_conduccion[a]["max"] = maxf(_conduccion[a]["max"], dpie)
	for pie in v3d._pies:
		var g: Dictionary = pie["gesto"]
		if g.is_empty():
			continue
		var accion := str(g["accion"])
		var modelo: Jugador3D = pie["modelo"]
		var nombre := str(VistaCancha3D.CONTACTO_3D[accion][0])
		var p: Vector3 = (modelo.ancla("Mano_L") + modelo.ancla("Mano_R")) * 0.5 if nombre == "manos" else modelo.ancla(nombre)
		var d := p.distance_to(pelota) - radio
		# Estirada que no llega (la pelota del motor no se desvía): lo que se
		# mide es que NO la toque, ni con los guantes ni con la cabeza.
		# Estirada que termina en agarre: la pelota la lleva la atajada (recta
		# a las manos, ver VistaCancha3D._pelota_de_la_atajada); se mide en agarra.
		if accion == MotorEspacial.ACCION_VUELA and not v3d._atajada.is_empty() \
				and int(v3d._atajada["arquero"]) == int(g["clave"]):
			continue
		if bool(g.get("sin_toque", false)):
			var cabeza := modelo.ancla("Frente").distance_to(pelota) - radio
			_no_llega_min = minf(_no_llega_min, minf(d, cabeza))
			continue
		var llave := "%s#%d#%d" % [accion, int(g["clave"]), int(g.get("desde", 0))]
		if not _datos.has(llave):
			_datos[llave] = {"accion": accion, "dt_min": INF, "d_golpe": INF, "suma": 0.0, "n": 0, "salto": 0.0}
		var r: Dictionary = _datos[llave]
		var dt := float(g["dt"])
		if absf(dt) < absf(r["dt_min"]):
			r["dt_min"] = dt
			r["d_golpe"] = d
			r["t"] = rep.posicion
		if _capturar and absf(dt) < 0.06 and d <= TOCA_M and not _capturadas.has(accion):
			_capturadas[accion] = {"t": rep.posicion, "modelo": modelo}
		# Recepción: se mide el tramo en que la pelota va pegada al cuerpo
		# (amortigua); después se acomoda adelante para conducir.
		var fc := float(g["fase_contacto"])
		var avance := (float(pie["fase"]) - fc) / maxf(1.0 - fc, 0.001)
		if accion in VistaCancha3D.RECEPCION_3D and dt >= 0.0 and avance < 0.35:
			r["suma"] += d
			r["n"] += 1
		if absf(dt) < 2.5 and not reubica:
			if salto > SALTO_MAX_M:
				var ent_p: Dictionary = {}
				for e in v3d.entidades:
					if str(e.get("tipo", "")) == "pelota":
						ent_p = e
				print("  SALTO %s t=%.2f dt=%.2f salto=%.2f anclada=%s z=%.2f corr=%s pelota=%s" % [accion, _t - PASO, dt, salto,
					str(ent_p.get("anclada", false)), float(ent_p.get("z", 0.0)), str(v3d._correccion), str(pelota)])
			r["salto"] = maxf(r["salto"], salto)
	# Tiro bloqueado armado en 3D: el golpe es cuando la pelota llega a la
	# pierna del defensor (BLOQUEO_VIAJE_TICKS después del remate).
	if not v3d._bloqueo.is_empty() and v3d._pierna_bloqueo != Vector3.INF:
		var b: Dictionary = v3d._bloqueo
		var llave_b := "bloquea#%d#%d" % [int(b["bloqueador"]), int(b["desde"])]
		if not _datos.has(llave_b):
			_datos[llave_b] = {"accion": "bloquea", "dt_min": INF, "d_golpe": INF, "suma": 0.0, "n": 0, "salto": 0.0}
		var rb: Dictionary = _datos[llave_b]
		var dt_b := v3d._tiempo_reproduccion - (float(b["golpe"]) + VistaCancha3D.BLOQUEO_VIAJE_TICKS)
		if absf(dt_b) < absf(rb["dt_min"]):
			rb["dt_min"] = dt_b
			rb["d_golpe"] = v3d._pierna_bloqueo.distance_to(pelota) - radio
		if absf(dt_b) < 2.5 and not reubica:
			rb["salto"] = maxf(rb["salto"], salto)


## Con `-- capturar` (y ventana, no headless): al terminar de medir vuelve a
## cada golpe, pone la cámara a 4 m del jugador, en diagonal de frente, y
## guarda el render real en scratch/contactos/<accion>.png.
var _cola: Array = []
var _paso_captura := 0


func _capturar_siguiente() -> bool:
	var rep := _muestra.reproductor
	var v3d := rep.vista as VistaCancha3D
	if _cola.is_empty():
		return false
	var item: Array = _cola[0]
	var accion: String = item[0]
	var info: Dictionary = item[1]
	var angulo: float = item[2] if item.size() > 2 else 35.0
	var sufijo: String = item[3] if item.size() > 3 else ""
	# Salto de reproducción en cada paso: el jugador termina de girar hacia su
	# rumbo en estos cuadros y la pelota se vuelve a calcular con la pose final
	# (si no, el desvío queda congelado con la orientación del primer cuadro).
	v3d._posicion_previa = -100.0
	if _paso_captura == 0:
		rep.posicion = float(info["t"])
		var idx := int(rep.posicion)
		rep._mostrar(idx, rep.posicion - float(idx))
	elif _paso_captura == 1:
		var m: Jugador3D = info["modelo"]
		var frente := Vector3(sin(m.rotation.y), 0.0, cos(m.rotation.y))
		var ojo := m.global_position + frente.rotated(Vector3.UP, deg_to_rad(angulo)) * 4.0 + Vector3(0, 1.7, 0)
		var t := Transform3D.IDENTITY.translated(ojo)
		v3d.camara_forzada = t.looking_at(m.global_position + Vector3(0, 0.8, 0), Vector3.UP)
		# El reproductor tiene que volver a mostrar el mismo instante.
		var idx := int(rep.posicion)
		rep._mostrar(idx, rep.posicion - float(idx))
		if sufijo == "":
			print("  ALTURAS %s: Pie_R %.2f  Pie_L %.2f  Frente %.2f  pelota %.2f  cuerpo %.2f" % [accion,
				m.ancla("Pie_R").y, m.ancla("Pie_L").y, m.ancla("Frente").y, v3d._pelota.global_position.y, m.global_position.y])
	elif _paso_captura < 8:
		var idx := int(rep.posicion)
		rep._mostrar(idx, rep.posicion - float(idx))
	elif _paso_captura >= 8:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scratch/contactos"))
		root.get_texture().get_image().save_png("res://scratch/contactos/%s%s.png" % [accion, sufijo])
		_cola.pop_front()
		_paso_captura = -1
	_paso_captura += 1
	return true


func _informar() -> void:
	var fallas := 0
	print("CUERPOS  pares a menos de %.2f m (sumados por muestra): motor %d | dibujo 3D %d" % [CUERPOS_MIN_M, _encimados_motor, _encimados_3d])
	if _no_llega_min < INF:
		var ok_nl := _no_llega_min >= NO_LLEGA_MIN_M
		print("NO LLEGA estiradas sin toque %s | la pelota pasa a %.2f m de guantes/cabeza (min %.2f)" % [
			"OK   " if ok_nl else "FALLA", _no_llega_min, NO_LLEGA_MIN_M])
		if not ok_nl:
			fallas += 1
	for r in _datos.values():
		if str(r["accion"]) == "vuela":
			print("  detalle vuela: al golpe %.2f (dt %.2f) en t=%.2f" % [r["d_golpe"], r["dt_min"], float(r.get("t", -1.0))])
		if str(r["accion"]) in ["pecho", "control_pie", "agarra"]:
			print("  detalle %s: al golpe %.2f (dt %.2f) recepcion n=%d media %.2f" % [r["accion"], r["d_golpe"], r["dt_min"], r["n"],
				float(r["suma"]) / maxf(float(r["n"]), 1.0)])
	var por_accion := {}
	for r in _datos.values():
		# Se queda con la instancia que más se acercó al golpe de cada acción.
		var a: String = r["accion"]
		if not por_accion.has(a) or absf(r["dt_min"]) < absf(por_accion[a]["dt_min"]):
			por_accion[a] = r
	for a in VistaCancha3D.CONTACTO_3D.keys():
		if not por_accion.has(a):
			# En la muestra todas las estiradas son goles (no llegan, medido
			# arriba en NO LLEGA) o terminan en agarre (medido en agarra).
			if a == MotorEspacial.ACCION_VUELA and _no_llega_min < INF:
				print("CONTACTO %-14s -     | ninguna estirada de la muestra toca la pelota (ver NO LLEGA y agarra)" % a)
				continue
			print("CONTACTO %-14s SIN DATOS" % a)
			fallas += 1
			continue
		var r: Dictionary = por_accion[a]
		var toca: bool = r["d_golpe"] <= TOCA_M
		var acompana := true
		var media := -1.0
		if int(r["n"]) > 0:
			media = float(r["suma"]) / float(r["n"])
			acompana = media <= TOCA_M + 0.05
		var suave: bool = r["salto"] <= SALTO_MAX_M
		var ok := toca and acompana and suave
		if not ok:
			fallas += 1
		print("CONTACTO %-14s %s | al golpe %.2f m | recepcion %s | salto max %.2f m" % [
			a, "OK   " if ok else "FALLA", r["d_golpe"], ("%.2f m" % media) if media >= 0.0 else "-", r["salto"]])
	print("  amague: pelota a %.2f m del jugador como minimo" % _amague_min)
	for a in ["regate_croqueta", "regate_bicicleta", "regate_ruleta", "regate_globito", "regate_elastica", "amague_centro"]:
		if not _conduccion.has(a):
			print("CONDUCE  %-18s SIN DATOS" % a)
			fallas += 1
			continue
		var c: Dictionary = _conduccion[a]
		var media := float(c["suma"]) / maxf(float(c["n"]), 1.0)
		var ok := media <= CONDUCE_MEDIA_M
		if not ok:
			fallas += 1
		print("CONDUCE  %-18s %s | pelota-pie media %.2f m | max %.2f m | muestras %d" % [a, "OK   " if ok else "FALLA", media, c["max"], c["n"]])
	print("FALLOS=%d" % fallas)
