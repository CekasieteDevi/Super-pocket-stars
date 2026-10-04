class_name PartidoVistoV2
extends RefCounted

## Etapa 6 del Motor V2 (docs/motor_v2.md): lo que la vista lee de un partido
## con reglas (CanchitaV2Nativa). Tiene los mismos métodos que VistaV2 usa
## para dibujar la canchita y les suma dos cosas:
## - Los que se van (get_afuera) siguen dibujándose, caminando, después de los
##   que juegan: el expulsado y el cambiado salen de la cancha a la vista.
## - En el segundo tiempo los equipos cambian de lado. El motor sigue con el
##   equipo 0 atacando hacia +x; acá la cancha se gira 180° (x, z) -> (-x, -z).

var partido: Object
var _signo := 1.0
## En la tanda los dos equipos patean al mismo arco. El motor no cambia de
## lado (cada uno patea al arco que ataca): la vista gira la cancha según quién
## patea y hace un corte entre un penal y el otro. Sin esto la cámara cruzaba
## la cancha en cada penal.
var _signo_tanda := 1.0
var _cortes_tanda := 0
var _afuera: Array = []
var _cantidad := 0


func _init(c: Object) -> void:
	partido = c


## Lee lo que cambia en el cuadro: el lado y los que se van.
func actualizar() -> void:
	var estado: Dictionary = partido.get_estado()
	_signo = -1.0 if int(estado["lado"]) == 1 else 1.0
	if str(estado["periodo"]) == "tanda":
		# Se gira cuando se arma el penal, no mientras la pelota va al arco.
		if str(estado["parada"]) == "penal":
			var del_que_patea := 1.0 if int(estado["saca"]) == 0 else -1.0
			if del_que_patea != _signo_tanda:
				_signo_tanda = del_que_patea
				_cortes_tanda += 1
		_signo = _signo_tanda
	_afuera = partido.get_afuera()
	_cantidad = partido.cantidad()


func cantidad_total() -> int:
	return _cantidad + _afuera.size()


## Equipo, arquero e id de cada uno (los que se van al final), para armar la vista.
func equipos() -> PackedInt32Array:
	var r: PackedInt32Array = partido.get_equipos()
	for a in _afuera:
		r.append(int(a["equipo"]))
	return r


func arqueros() -> PackedInt32Array:
	var r: PackedInt32Array = partido.get_arqueros()
	for a in _afuera:
		r.append(0)
	return r


func ids() -> PackedInt32Array:
	var r: PackedInt32Array = partido.get_ids()
	for a in _afuera:
		r.append(int(a["id"]))
	return r


func _girar(v: Vector2) -> Vector2:
	return v * _signo


func _girar3(v: Vector3) -> Vector3:
	return Vector3(v.x * _signo, v.y, v.z * _signo)


func _rumbo(r: float) -> float:
	return r if _signo > 0.0 else wrapf(r + PI, -PI, PI)


func _posiciones(nuevas: PackedVector2Array) -> PackedVector2Array:
	var r := PackedVector2Array()
	for p in nuevas:
		r.append(_girar(p))
	for a in _afuera:
		r.append(_girar(a["pos"]))
	return r


func get_pos() -> PackedVector2Array:
	return _posiciones(partido.get_pos())


func get_pos_previa() -> PackedVector2Array:
	return _posiciones(partido.get_pos_previa())


func get_rumbo() -> PackedFloat32Array:
	var r := PackedFloat32Array()
	for x in partido.get_rumbo():
		r.append(_rumbo(x))
	for a in _afuera:
		r.append(_rumbo(float(a["rumbo"])))
	return r


func get_rapidez() -> PackedFloat32Array:
	var r: PackedFloat32Array = partido.get_rapidez()
	for a in _afuera:
		r.append(float(a["rapidez"]))
	return r


## Adónde mirar mientras alguien sale o entra por un cambio (metros de la
## cancha, ya girado), o null si no hay nadie. Primero el que sale y todavía
## está adentro (el que más lejos está de su raya); cuando salieron todos, el
## que entra y todavía no pisó la cancha. El saque espera a los dos: mirando
## la pelota se veía a todos parados sin saber por qué (tercera revisión
## visual de la etapa 7). El expulsado no cuenta: lo sigue el que muestra la
## tarjeta.
func foco_de_cambio() -> Variant:
	var mejor = null
	var falta := 0.0
	for a in _afuera:
		if bool(a.get("expulsado", false)):
			continue
		var p: Vector2 = a["pos"]
		var adentro := ProyeccionPartido.MEDIO_ANCHO - absf(p.y)
		if adentro > falta:
			falta = adentro
			mejor = _girar(p)
	if mejor != null:
		return mejor
	var entrando: PackedInt32Array = partido.get_estado().get("entrando", PackedInt32Array())
	if entrando.is_empty():
		return null
	var pos: PackedVector2Array = partido.get_pos()
	return _girar(pos[entrando[0]]) if entrando[0] < pos.size() else null


## La tarjeta que el árbitro está yendo a mostrar o mostrando ({} si no hay):
## dura `tarjeta_seg` desde que se cobra (reglas.tarjeta_seg).
func tarjeta_en_curso(tarjeta_seg: float) -> Dictionary:
	var tarjeta := get_tarjeta()
	if tarjeta.is_empty() or float(get_paso() - int(tarjeta["paso"])) / 60.0 >= tarjeta_seg:
		return {}
	return tarjeta


## Adónde mira la cámara en vez de la pelota (metros, ya girado), o null:
## - Mientras el árbitro muestra una tarjeta, donde fue la falta.
## - El expulsado, hasta el corte al saque.
## - En un cambio, el que sale y después el que entra (foco_de_cambio).
func foco(tarjeta_seg: float) -> Variant:
	var tarjeta := tarjeta_en_curso(tarjeta_seg)
	if not tarjeta.is_empty():
		return tarjeta["pos"]
	# El festejo del gol: la cámara va con el que lo hizo.
	var festeja := int(partido.get_estado().get("festeja", -1))
	if festeja >= 0:
		var en: PackedVector2Array = partido.get_pos()
		if festeja < en.size():
			return _girar(en[festeja])
	var eventos: Array = partido.eventos()
	for k in range(eventos.size() - 1, -1, -1):
		var e: Dictionary = eventos[k]
		if e["tipo"] != "roja":
			continue
		if get_corte() < int(e["paso"]):
			var i := ids().rfind(int(e["jugador"]))
			if i >= _cantidad:
				return get_pos()[i]
		break
	return foco_de_cambio()


func _de_afuera(i: int) -> bool:
	return i >= _cantidad


## El que se va camina; el lesionado primero termina de caer.
func get_accion(i: int) -> String:
	return str(_afuera[i - _cantidad].get("accion", "")) if _de_afuera(i) else partido.get_accion(i)


func get_tiempo_accion(i: int) -> float:
	return float(_afuera[i - _cantidad].get("tiempo_accion", 0.0)) if _de_afuera(i) else partido.get_tiempo_accion(i)


## Si el gesto en curso llega a la pelota. Con una biblioteca vieja del motor
## (sin get_alcanza) dice que sí, como antes.
func get_alcanza(i: int) -> bool:
	if _de_afuera(i) or not partido.has_method("get_alcanza"):
		return true
	return partido.get_alcanza(i)


func get_rapidez_buscada(i: int) -> float:
	return float(_afuera[i - _cantidad]["rapidez"]) if _de_afuera(i) else partido.get_rapidez_buscada(i)


func get_metros_para_parar(i: int) -> float:
	return -1.0 if _de_afuera(i) else partido.get_metros_para_parar(i)


func get_giro_pendiente(i: int) -> float:
	return 0.0 if _de_afuera(i) else partido.get_giro_pendiente(i)


func get_rumbo_buscado(i: int) -> float:
	return _rumbo(float(_afuera[i - _cantidad]["rumbo"])) if _de_afuera(i) else _rumbo(partido.get_rumbo_buscado(i))


func get_en_manos() -> int:
	return partido.get_en_manos()


func get_paso() -> int:
	return int(partido.get_estado()["paso"])


## Paso del último corte al saque después de una tarjeta (-1 si no hubo).
func get_corte() -> int:
	# El giro de la tanda también es un corte (otro número cada vez).
	return int(partido.get_estado()["corte"]) + _cortes_tanda * 10000000


## La última tarjeta para el árbitro (ArbitroV2): {paso, roja, pos}, con el
## lugar del jugador ya girado; {} si no hubo.
func get_tarjeta() -> Dictionary:
	var eventos: Array = partido.eventos()
	for k in range(eventos.size() - 1, -1, -1):
		var e: Dictionary = eventos[k]
		if e["tipo"] == "amarilla" or e["tipo"] == "roja":
			# Donde está ahora el que la recibe (frena unos metros después de
			# la falta y espera ahí); si ya no está, donde fue.
			var i := ids().rfind(int(e["jugador"]))
			var pos: Vector2 = get_pos()[i] if i >= 0 else _girar(e["pos"])
			return {"paso": int(e["paso"]), "roja": e["tipo"] == "roja", "pos": pos}
	return {}


## La parada en curso para el árbitro: {tipo, punto, ataca}, con el punto ya
## girado. `ataca`: hacia dónde ataca en la pantalla el que saca (+1 o -1 en x).
func get_parada() -> Dictionary:
	var e: Dictionary = partido.get_estado()
	var ataca := (1.0 if int(e.get("saca", 0)) == 0 else -1.0) * _signo
	return {"tipo": str(e["parada"]), "punto": _girar(e["punto"]), "ataca": ataca}


func get_lateral_en_manos() -> int:
	return partido.get_lateral_en_manos()


func get_pelota_pos() -> Vector3:
	return _girar3(partido.get_pelota_pos())


func get_pelota_previa() -> Vector3:
	return _girar3(partido.get_pelota_previa())


func get_pelota_giro() -> Vector3:
	return _girar3(partido.get_pelota_giro())
