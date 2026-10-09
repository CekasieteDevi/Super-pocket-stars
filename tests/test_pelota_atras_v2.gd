extends SceneTree

## BUG-009 (docs/bugs_pendientes.md): el que conduce no sigue corriendo con la
## pelota quieta atrás.
## BUG-018: el que llega corriendo y la controla no la pasa de largo.
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
## Episodios por partido, contando los rebotes en un rival y las barridas. En
## 200 partidos de quinta, semilla 97000: 3,21 antes de BUG-018 y 0,87
## después. En los 8 de este test, 0,63, y 11,00 con el arreglo de BUG-009
## apagado.
const TOPE_CON_ARREGLO := 2.0
const PISO_SIN_ARREGLO := 6.5
## BUG-018: los episodios que salen de un toque de control (TipoToque del
## motor), en primera, donde corren más. En 200 partidos son 0,07 por partido
## con el arreglo y 1,09 con el arreglo apagado (1,60 antes de BUG-018); en los
## 24 de este test, 0,00 y 1,04.
const TOQUE_CONTROL := 3
const PRIMERA := 0
const QUINTA := 4
const PARTIDOS_CONTROL := 24
const TOPE_CONTROL := 0.3
const PISO_CONTROL_SIN_ARREGLO := 0.7

var fallos := 0


func _init() -> void:
	var con := _medir(QUINTA, PARTIDOS)
	_ok(con <= TOPE_CON_ARREGLO, "pelota atrás %.2f veces por partido." % con)
	# El test mide algo: con el arreglo apagado los episodios vuelven.
	var toque: Dictionary = FisicaV2.datos()["toque"]
	var inercia: float = toque["conduce_inercia"]
	toque["conduce_inercia"] = 0.0
	var sin := _medir(QUINTA, PARTIDOS)
	toque["conduce_inercia"] = inercia
	_ok(sin >= PISO_SIN_ARREGLO, "con el arreglo apagado vuelven: %.2f por partido." % sin)
	con = _medir(PRIMERA, PARTIDOS_CONTROL, TOQUE_CONTROL)
	_ok(con <= TOPE_CONTROL, "pelota atrás después de un control %.2f veces por partido." % con)
	inercia = toque["control_inercia"]
	toque["control_inercia"] = 0.0
	sin = _medir(PRIMERA, PARTIDOS_CONTROL, TOQUE_CONTROL)
	toque["control_inercia"] = inercia
	_ok(sin >= PISO_CONTROL_SIN_ARREGLO, "con el arreglo del control apagado vuelven: %.2f por partido." % sin)
	print("FALLOS=%d" % fallos)
	quit(1 if fallos else 0)


func _ok(condicion: bool, mensaje: String) -> void:
	if condicion:
		print("OK: %s" % mensaje)
	else:
		fallos += 1
		print("FALLA: %s" % mensaje)


## Episodios de pelota atrás por partido, en `partidos` partidos de esa
## división. Con `tipo`, solo los que empiezan después de ese toque.
func _medir(division: int, partidos: int, tipo := -1) -> float:
	var episodios := 0
	for n in partidos:
		var estilos: Array = ESTILOS[n % ESTILOS.size()]
		var c: Object = CerebroV2.armar_partido(SEED + n, estilos[0], estilos[1], division, division, true)
		var equipos: PackedInt32Array = c.get_equipos()
		var pasos := 0
		var seguidos := 0
		var cuenta := false
		while str(c.get_estado()["periodo"]) != "terminado" and pasos < 60 * 60 * 20:
			c.simular(1)
			pasos += 1
			if _atras(c, equipos):
				if seguidos == 0:
					cuenta = tipo < 0 or int(c.get_ultimo_tipo()) == tipo
				seguidos += 1
				continue
			if seguidos >= PASOS_MINIMOS and cuenta:
				episodios += 1
			seguidos = 0
	return float(episodios) / partidos


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
