extends SceneTree

## BUG-009 (docs/bugs_pendientes.md): el que conduce no sigue corriendo con la
## pelota quieta atrás.
##
## Juega partidos enteros con reglas, sin vista, y cuenta los episodios de
## pelota atrás: el último que la tocó corre alejándose de la pelota, la
## pelota casi no se mueve y su equipo la sigue teniendo.
##
## Correr con: godot --path . --headless --script tests/test_pelota_atras_v2.gd

const SEED := 97000
const PARTIDOS := 8
const ESTILOS := [["Tiki taka", "Juego directo"], ["Presión alta", "Contragolpe"]]
## El episodio: él corre a más de CORRE_MS, la pelota va a menos de QUIETA_MS
## y queda a más de LEJOS_M detrás de él, durante PASOS_MINIMOS o más (0,15 s).
const CORRE_MS := 2.0
const QUIETA_MS := 2.5
const LEJOS_M := 0.9
const PASOS_MINIMOS := 9
## Episodios por partido. En 60 partidos de quinta son 2,72 con el arreglo y
## 8,02 con el arreglo apagado; en los 8 de este test, 3,00 y 8,63.
const TOPE_CON_ARREGLO := 5.0
const PISO_SIN_ARREGLO := 6.5

var fallos := 0


func _init() -> void:
	var con := _medir()
	_ok(con <= TOPE_CON_ARREGLO, "pelota atrás %.2f veces por partido." % con)
	# El test mide algo: con el arreglo apagado los episodios vuelven.
	var toque: Dictionary = FisicaV2.datos()["toque"]
	var inercia: float = toque["conduce_inercia"]
	toque["conduce_inercia"] = 0.0
	var sin := _medir()
	toque["conduce_inercia"] = inercia
	_ok(sin >= PISO_SIN_ARREGLO, "con el arreglo apagado vuelven: %.2f por partido." % sin)
	print("FALLOS=%d" % fallos)
	quit(1 if fallos else 0)


func _ok(condicion: bool, mensaje: String) -> void:
	if condicion:
		print("OK: %s" % mensaje)
	else:
		fallos += 1
		print("FALLA: %s" % mensaje)


## Episodios de pelota atrás por partido, en PARTIDOS partidos de quinta.
func _medir() -> float:
	var episodios := 0
	for n in PARTIDOS:
		var estilos: Array = ESTILOS[n % ESTILOS.size()]
		var c: Object = CerebroV2.armar_partido(SEED + n, estilos[0], estilos[1], 4, 4, true)
		var equipos: PackedInt32Array = c.get_equipos()
		var pasos := 0
		var seguidos := 0
		while str(c.get_estado()["periodo"]) != "terminado" and pasos < 60 * 60 * 20:
			c.simular(1)
			pasos += 1
			if _atras(c, equipos):
				seguidos += 1
				continue
			if seguidos >= PASOS_MINIMOS:
				episodios += 1
			seguidos = 0
	return float(episodios) / PARTIDOS


func _atras(c: Object, equipos: PackedInt32Array) -> bool:
	var i := int(c.get_ultimo_toque())
	if i < 0 or i >= equipos.size():
		return false
	var bola: Vector3 = c.get_pelota_pos()
	var vel_bola: Vector3 = c.get_pelota_vel()
	if bola.y >= 0.5 or Vector2(vel_bola.x, vel_bola.z).length() >= QUIETA_MS:
		return false
	var pos: Vector2 = c.get_pos()[i]
	var vel: Vector2 = (pos - c.get_pos_previa()[i]) * 60.0
	var a_la_bola := Vector2(bola.x, bola.z) - pos
	if vel.length() <= CORRE_MS or a_la_bola.length() <= LEJOS_M or a_la_bola.dot(vel) >= 0.0:
		return false
	return int(c.get_equipo_con_pelota()) == equipos[i] and str(c.get_estado()["parada"]) == "nada"
