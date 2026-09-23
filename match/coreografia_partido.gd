class_name CoreografiaPartido
extends RefCounted

## Solo reproduccion: une los vuelos con el cuadro de contacto del sprite.
## No toca fotogramas, tiempos de gol, decisiones ni azar del motor.
## Perfil: anticipacion (ticks), fase del impacto y punto del sprite (px).
const PERFILES := {
	"patea": [1.0, 0.75, Vector2(22, -16)],
	"taco": [0.7, 0.50, Vector2(-13, -2)],
	"volea": [1.0, 0.375, Vector2(18, -18)],
	"chilena": [1.5, 0.35, Vector2(-7, -43)],
	"cabecea": [1.0, 0.55, Vector2(5, -51)],
	"palomita": [1.2, 0.375, Vector2(12, -29)],
	"saque_arco": [1.0, 0.50, Vector2(27, -19)],
	"lateral_manos": [0.5, 0.25, Vector2(0, -42)],
	"pecho": [0.6, 0.0, Vector2(7, -25)],
	"control_pie": [0.5, 0.0, Vector2(12, -13)],
	"agarra": [0.5, 0.0, Vector2(7, -25)],
}
const RECEPCIONES := ["pecho", "control_pie", "agarra"]
## Golpes con el pie desde el piso. La pelota sale de donde estaba y sigue
## la recta del motor: no se la lleva al punto del sprite. Con el punto del
## sprite (22 px al costado y 0,86 m de alto) cada pase raso doblaba de
## costado y flotaba. Medido en el guardado ECA-Umbrella: la mediana de los
## pases se apartaba 26,7 px de la recta dibujada; el motor, 5,5 px.
const PIE := ["patea", "taco", "saque_arco"]
const AEREAS := ["chilena", "volea", "cabecea", "palomita"]
const PX_ALTURA := CamaraPartido.PX_POR_METRO_BASE * ProyeccionPartido.ESCALA_Z

var contactos: Dictionary = {}
var _lista: Array = []
var _nodos: Dictionary = {}
var _por_tick: Dictionary = {}
var _duraciones: Dictionary = {}


func configurar(lista: Array, duraciones: Dictionary) -> void:
	_lista = lista
	_duraciones = duraciones
	contactos.clear()
	_nodos.clear()
	_por_tick.clear()
	var ultimo_contacto := -1
	for i in range(lista.size()):
		var f: Dictionary = lista[i]
		var elegido := {}
		var mejor_distancia := INF
		for accion in f.get("acciones", []):
			var nombre := str(accion["accion"])
			if not PERFILES.has(nombre):
				continue
			var clave := int(accion["clave"])
			var j := _jugador(i, clave)
			if j.is_empty():
				continue
			var pos := _pos(j)
			var pel: Dictionary = f["pelota"]
			var anterior: Dictionary = lista[maxi(0, i - 1)]["pelota"]
			if nombre in RECEPCIONES and int(pel.get("poseedor_id", -1)) != clave:
				continue
			var distancia := minf(pos.distance_to(_pos(pel)), pos.distance_to(_pos(anterior)))
			if int(anterior.get("poseedor_id", -1)) == clave or int(pel.get("poseedor_id", -1)) == clave:
				distancia = 0.0
			# No asociar al balon un gesto de otro jugador lejos de la jugada.
			if distancia > 8.0 or distancia > mejor_distancia:
				continue
			mejor_distancia = distancia
			var perfil: Array = PERFILES[nombre]
			# El motor graba el tick del pase con la pelota ya 4-5 m afuera y
			# con el pateador corrido. En el tick anterior la tenía en los
			# pies: ahí va el golpe, y el vuelo queda como lo grabó el motor.
			var golpe := float(i)
			var origen := pos
			if nombre in PIE and i - 1 > ultimo_contacto and not _hay_corte(i - 1, i) \
				and int(anterior.get("poseedor_id", -1)) == clave:
				golpe = float(i - 1)
				origen = _pos(anterior)
			elif nombre in PIE:
				origen = _origen_vuelo(i, pos)
			var desde := maxf(0.0, golpe - float(perfil[0]))
			desde = maxf(desde, float(ultimo_contacto) + 0.01)
			for k in range(int(floor(desde)) + 1, int(golpe) + 1):
				if _hay_corte(k - 1, k):
					desde = float(k)
			var direccion := _direccion_salida(i, origen, j, nombre)
			elegido = {"clave": clave, "accion": nombre, "desde": i, "golpe": golpe,
				"inicio": desde, "impacto": float(perfil[1]),
				"fin": golpe + float(duraciones.get(nombre, 2)) * (1.0 - float(perfil[1])),
				"direccion": direccion, "pos": pos, "origen": origen}
		if elegido.is_empty():
			continue
		contactos[i] = elegido
		ultimo_contacto = i
	_limitar_gestos()
	# Cada contacto es un nodo compartido por el vuelo entrante y saliente.
	# No se arrastra el balon de vuelta cuando el remate ya esta en el aire.
	for i in contactos:
		var c: Dictionary = contactos[i]
		if str(c["accion"]) in PIE:
			# Golpe en el tick anterior: esa muestra ya es la pelota en los
			# pies. Si no la tenía (toque de primera), el vuelo arranca en el
			# piso, sobre la recta que sigue después.
			if float(c["golpe"]) >= float(i):
				_nodos[i] = {"pos": c["origen"], "z": 0.0, "offset_px": Vector2.ZERO, "corregida": true}
		else:
			_nodos[i] = _nodo_contacto(c, float(c["impacto"]), c["pos"])
		for k in range(int(floor(float(c["inicio"]))), mini(lista.size(), ceili(float(c["fin"])) + 1)):
			if not _por_tick.has(k):
				_por_tick[k] = []
			_por_tick[k].append(i)
		if str(c["accion"]) not in RECEPCIONES:
			continue
		# El control baja la pelota desde el contacto hasta el apoyo; las
		# manos la retienen. Otro toque o cambio de dueno termina el control.
		for k in range(int(i) + 1, mini(lista.size(), ceili(float(c["fin"])) + 1)):
			if contactos.has(k) or _hay_corte(k - 1, k) \
				or int(lista[k]["pelota"].get("poseedor_id", -1)) != int(c["clave"]):
				break
			var j := _jugador(k, int(c["clave"]))
			if j.is_empty():
				break
			_nodos[k] = _nodo_contacto(c, fase(c, float(k)), _pos(j))
	_preparar_laterales()
	_conectar_vuelos()


func _limitar_gestos() -> void:
	# Una nueva accion del mismo jugador termina la anterior. No permitir
	# que reaparezca una chilena vieja al acabar un toque posterior corto.
	for indice in contactos:
		var c: Dictionary = contactos[indice]
		for k in range(int(indice) + 1, mini(_lista.size(), ceili(float(c["fin"])) + 1)):
			if _hay_corte(k - 1, k):
				c["fin"] = minf(float(c["fin"]), float(k))
				break
			var interrumpido := false
			for accion in _lista[k].get("acciones", []):
				if int(accion["clave"]) != int(c["clave"]):
					continue
				var siguiente: Dictionary = contactos.get(k, {})
				var limite := float(k)
				if not siguiente.is_empty() and int(siguiente["clave"]) == int(c["clave"]):
					limite = float(siguiente["inicio"])
				c["fin"] = minf(float(c["fin"]), limite)
				interrumpido = true
				break
			if interrumpido:
				break


func _preparar_laterales() -> void:
	var manos := [Vector2(1, -23), Vector2(8, -29), Vector2(0, -48), Vector2(0, -42)]
	for i in range(_lista.size()):
		var lateral: Dictionary = _lista[i].get("lateral_preparacion", {})
		if lateral.is_empty() or int(lateral.get("restante", 99)) > 3 or contactos.has(i):
			continue
		var j := _jugador(i, int(lateral.get("clave", -1)))
		if j.is_empty():
			continue
		var progreso := clampf((3.0 - float(lateral["restante"])) / 3.0, 0.0, 0.999)
		var offset: Vector2 = manos[mini(3, int(progreso * 4.0))]
		var direccion := ProyeccionPartido.direccion_pantalla(Vector2(0, -signf(float(j["y"]))))
		if SpritesPartido.direccion_desde(direccion) in [5, 6, 7]:
			offset.x *= -1.0
		_nodos[i] = {"pos": _pos(j), "z": -offset.y / PX_ALTURA,
			"offset_px": Vector2(offset.x, 0), "corregida": true}


func _conectar_vuelos() -> void:
	# Conservar el arco original y corregir sus alturas de salida/llegada.
	# Si hay dos toques aereos seguidos, ambas correcciones se suman:
	# el rebote sale del primer contacto y termina en el segundo.
	for indice in contactos:
		var i := int(indice)
		# El golpe con el pie ya sale del piso por la recta del motor.
		if str(contactos[i]["accion"]) in PIE:
			continue
		var delta := float(_nodos[i]["z"]) - float(_lista[i]["pelota"].get("z", 0.0))
		var inicio := i
		while inicio > 0 and i - inicio < 32:
			if _hay_corte(inicio - 1, inicio):
				break
			inicio -= 1
			if contactos.has(inicio) or not _en_vuelo(inicio):
				break
		for k in range(inicio + 1, i):
			if not _en_vuelo(k) or contactos.has(k):
				continue
			_agregar_altura(k, delta * float(k - inicio) / float(i - inicio))
		if str(contactos[i]["accion"]) in RECEPCIONES:
			continue
		var fin := i
		while fin + 1 < _lista.size() and fin - i < 32:
			if _hay_corte(fin, fin + 1):
				break
			fin += 1
			if contactos.has(fin) or not _en_vuelo(fin):
				break
		for k in range(i + 1, fin):
			if not _en_vuelo(k) or contactos.has(k):
				continue
			_agregar_altura(k, delta * (1.0 - float(k - i) / float(fin - i)))


func _agregar_altura(idx: int, altura: float) -> void:
	var nodo := _nodo(idx).duplicate()
	nodo["z"] = maxf(0.0, float(nodo["z"]) + altura)
	nodo["corregida"] = true
	_nodos[idx] = nodo


func _en_vuelo(idx: int) -> bool:
	var p: Dictionary = _lista[idx]["pelota"]
	return int(p.get("poseedor_id", -1)) == -1 and (bool(p.get("es_pase", false)) \
		or bool(p.get("es_remate", false)) or float(p.get("z", 0.0)) > 0.05)


func gestos(tiempo: float, activas: Dictionary) -> Dictionary:
	var resultado := activas.duplicate()
	# Retirar la cola antigua: ahora el armado ocurre ANTES del toque.
	for clave in activas:
		var anterior: Dictionary = activas[clave]
		var c: Dictionary = contactos.get(int(anterior["desde"]), {})
		if not c.is_empty() and int(c["clave"]) == int(clave) \
			and str(c["accion"]) == str(anterior["accion"]) and tiempo >= float(c["fin"]):
			resultado.erase(clave)
	for indice in _por_tick.get(int(floor(tiempo)), []):
		var c: Dictionary = contactos[indice]
		if tiempo < float(c["inicio"]) or tiempo >= float(c["fin"]):
			continue
		var anterior: Dictionary = resultado.get(c["clave"], {})
		# Un contacto viejo no puede reemplazar un regate que todavía está
		# corriendo. Esto también corrige replays generados antes del bloqueo
		# del segundo duelo en el motor.
		if not anterior.is_empty() and MotorEspacial.es_accion_regate(str(anterior.get("accion", ""))):
			var fin_regate := float(anterior["desde"]) + float(_duraciones.get(str(anterior["accion"]), 1))
			if tiempo < fin_regate:
				continue
		if not anterior.is_empty() and int(anterior["desde"]) > int(c["desde"]) \
			and float(anterior["desde"]) <= tiempo:
			continue
		resultado[c["clave"]] = {"accion": c["accion"], "desde": c["desde"],
			"fase": fase(c, tiempo), "direccion_contacto": c["direccion"], "coreografiada": true}
	return resultado


static func fase(c: Dictionary, tiempo: float) -> float:
	var impacto := float(c["impacto"])
	var golpe := float(c.get("golpe", c["desde"]))
	if tiempo < golpe:
		return impacto * clampf((tiempo - float(c["inicio"])) / maxf(0.001, golpe - float(c["inicio"])), 0.0, 1.0)
	return lerpf(impacto, 1.0, clampf((tiempo - golpe) / maxf(0.001, float(c["fin"]) - golpe), 0.0, 1.0))


func pelota(idx: int, t: float) -> Dictionary:
	var siguiente := mini(idx + 1, _lista.size() - 1)
	var a := _nodo(idx)
	var b := _nodo(siguiente)
	if _hay_corte(idx, siguiente):
		return a
	return {"pos": (a["pos"] as Vector2).lerp(b["pos"], t),
		"z": lerpf(float(a["z"]), float(b["z"]), t),
		"offset_px": (a["offset_px"] as Vector2).lerp(b["offset_px"], t),
		"corregida": bool(a["corregida"]) or bool(b["corregida"])}


func _nodo(idx: int) -> Dictionary:
	if _nodos.has(idx):
		return _nodos[idx]
	var p: Dictionary = _lista[idx]["pelota"]
	return {"pos": _pos(p), "z": float(p.get("z", 0.0)),
		"offset_px": Vector2.ZERO, "corregida": false}


static func salto(accion: String, progreso: float) -> float:
	if accion not in AEREAS:
		return 0.0
	var impacto := float(PERFILES[accion][1])
	var subida := clampf(progreso / maxf(impacto, 0.001), 0.0, 1.0)
	if progreso <= impacto:
		return sin(subida * PI * 0.5) * 0.65
	return cos(clampf((progreso - impacto) / (1.0 - impacto), 0.0, 1.0) * PI * 0.5) * 0.65


static func _nodo_contacto(c: Dictionary, progreso: float, pos: Vector2) -> Dictionary:
	var accion := str(c["accion"])
	var offset: Vector2 = PERFILES[accion][2]
	var pantalla := ProyeccionPartido.direccion_pantalla(c["direccion"])
	# El anclaje debe usar el mismo espejo que el atlas, tambien cuando
	# la direccion se redondea a arriba/abajo. Chilena invierte el cuerpo.
	var izquierda := pantalla.x < 0.0 if accion == "chilena" else \
		SpritesPartido.direccion_desde(pantalla) in [5, 6, 7]
	if izquierda:
		offset.x *= -1.0
	if accion == "pecho":
		offset = offset.lerp(Vector2(signf(offset.x) * 5.0, -2.0), progreso)
	elif accion == "control_pie":
		offset = offset.lerp(Vector2(signf(offset.x) * 5.0, 0.0), progreso)
	elif accion == "agarra":
		offset.y = lerpf(-25.0, -19.0, progreso)
	return {"pos": pos, "z": -offset.y / PX_ALTURA + salto(accion, progreso),
		"offset_px": Vector2(offset.x, 0), "corregida": true}


func _direccion_salida(idx: int, pos: Vector2, j: Dictionary, accion: String) -> Vector2:
	var orientacion := Vector2(float(j.get("ox", 1.0)), float(j.get("oy", 0.0)))
	if accion in RECEPCIONES or accion == "taco":
		return orientacion
	# La muestra posterior al toque ya contiene su destino (incluso rosca
	# y tanda girada). Medir una sola vez: no girar siguiendo al balon.
	for k in range(idx, mini(_lista.size(), idx + 2)):
		if k > idx and (_hay_corte(idx, k) or not _lista[k].get("acciones", []).is_empty()):
			break
		var delta := _pos(_lista[k]["pelota"]) - pos
		if delta.length_squared() > 0.04:
			return delta.normalized()
	if accion in AEREAS:
		return (MotorEspacial.arco_rival(bool(j["equipo_local"])) - pos).normalized()
	return orientacion


## Toque de primera: la muestra del golpe ya viaja. Se vuelve un paso atrás
## por la misma recta. Si la pelota no sigue en vuelo, o el punto cae lejos
## del pateador, queda en sus pies.
func _origen_vuelo(idx: int, pie: Vector2) -> Vector2:
	var siguiente := idx + 1
	if siguiente >= _lista.size() or _hay_corte(idx, siguiente) \
		or not _lista[siguiente].get("acciones", []).is_empty() \
		or int(_lista[siguiente]["pelota"].get("poseedor_id", -1)) != -1:
		return pie
	var ahora := _pos(_lista[idx]["pelota"])
	var paso := _pos(_lista[siguiente]["pelota"]) - ahora
	if paso.length() < 0.05:
		return pie
	var origen := ahora - paso
	return origen if origen.distance_to(pie) <= 2.0 else pie


func _hay_corte(a: int, b: int) -> bool:
	if a == b:
		return false
	var fa: Dictionary = _lista[a]
	var fb: Dictionary = _lista[b]
	# En partidos nuevos `corte` puede ser solo el silbato. Ese instante
	# conserva la trayectoria hasta el contacto; `reubicacion` es el salto.
	var salto: bool = bool(fb.get("reubicacion", fb.get("corte", false)))
	return salto or int(fa.get("periodo", 1)) != int(fb.get("periodo", 1)) \
		or bool(fa["pelota"].get("saliendo", false)) != bool(fb["pelota"].get("saliendo", false)) \
		or _pos(fa["pelota"]).distance_to(_pos(fb["pelota"])) > 12.0


func _jugador(idx: int, clave: int) -> Dictionary:
	for j in _lista[idx]["jugadores"]:
		if int(j["id"]) == clave:
			return j
	return {}


static func _pos(dato: Dictionary) -> Vector2:
	return Vector2(float(dato["x"]), float(dato["y"]))
