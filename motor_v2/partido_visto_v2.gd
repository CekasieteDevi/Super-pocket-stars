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
var _afuera: Array = []
var _cantidad := 0


func _init(c: Object) -> void:
	partido = c


## Lee lo que cambia en el cuadro: el lado y los que se van.
func actualizar() -> void:
	_signo = -1.0 if int(partido.get_estado()["lado"]) == 1 else 1.0
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


func _de_afuera(i: int) -> bool:
	return i >= _cantidad


## El que se va camina; el lesionado primero termina de caer.
func get_accion(i: int) -> String:
	return str(_afuera[i - _cantidad].get("accion", "")) if _de_afuera(i) else partido.get_accion(i)


func get_tiempo_accion(i: int) -> float:
	return float(_afuera[i - _cantidad].get("tiempo_accion", 0.0)) if _de_afuera(i) else partido.get_tiempo_accion(i)


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


func get_pelota_pos() -> Vector3:
	return _girar3(partido.get_pelota_pos())


func get_pelota_previa() -> Vector3:
	return _girar3(partido.get_pelota_previa())


func get_pelota_giro() -> Vector3:
	return _girar3(partido.get_pelota_giro())
