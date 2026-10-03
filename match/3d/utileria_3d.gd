class_name Utileria3D
extends RefCounted

## Lo que los oficiales llevan en la mano en el partido 3D: la bandera de los
## asistentes, la tarjeta del árbitro y el tablero de cambios del cuarto
## árbitro. Son mallas simples (sin GLB) que la vista pone cada cuadro
## en la mano del modelo, orientadas con el antebrazo.

const AMARILLA := Color("ffd21f")
const ROJA := Color("e0242a")
const TELA_BANDERA_A := Color("ffd21f")
const TELA_BANDERA_B := Color("e0242a")
const PALO := Color("f2f2f2")
const TABLERO := Color("202328")
const MANGO := Color("b8bcc2")
const SALE := Color("ff3a2e")
const ENTRA := Color("3dff5c")

## Medidas en metros del juego (el chibi mide ~1.7 m). Más grandes que las de
## verdad, como la cabeza del chibi: a la distancia de la cámara no se veían.
const LARGO_PALO := 0.62
const TELA := Vector2(0.34, 0.24)
const TARJETA := Vector3(0.13, 0.18, 0.012)
const TABLERO_TAM := Vector3(1.0, 0.48, 0.05)
## Mangos del tablero: de las manos (los brazos del chibi no pasan la
## cabeza) hasta arriba del pelo, que es donde va el tablero.
const LARGO_MANGO := 0.62


static func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


static func _caja(tam: Vector3, color: Color) -> MeshInstance3D:
	var caja := BoxMesh.new()
	caja.size = tam
	caja.material = _material(color)
	var mi := MeshInstance3D.new()
	mi.mesh = caja
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Palo a lo largo de +Y desde el origen (la mano) y la tela arriba, a un
## costado. Tela a cuadros amarillo y rojo, como las de verdad.
static func bandera() -> Node3D:
	var n := Node3D.new()
	var palo := _caja(Vector3(0.018, LARGO_PALO, 0.018), PALO)
	palo.position = Vector3(0.0, LARGO_PALO * 0.5, 0.0)
	n.add_child(palo)
	for i in 2:
		for k in 2:
			var cuadro := _caja(Vector3(TELA.x * 0.5, TELA.y * 0.5, 0.006),
				TELA_BANDERA_A if (i + k) % 2 == 0 else TELA_BANDERA_B)
			cuadro.position = Vector3(0.01 + TELA.x * (0.25 + 0.5 * i), LARGO_PALO - TELA.y * (0.25 + 0.5 * k), 0.0)
			n.add_child(cuadro)
	return n


static func tarjeta() -> MeshInstance3D:
	var t := _caja(TARJETA, AMARILLA)
	return t


static func pintar_tarjeta(t: MeshInstance3D, roja: bool) -> void:
	((t.mesh as BoxMesh).material as StandardMaterial3D).albedo_color = ROJA if roja else AMARILLA


## Tablero luminoso de cambios, como el de la tele: marco gris, pantalla
## negra y los dos números (sale en rojo a la izquierda, entra en verde a la
## derecha) de los DOS lados, así lo ven la cancha y la cámara. El frente es
## +Z. Dos mangos hacia abajo que la vista pone en las manos.
static func tablero() -> Node3D:
	var n := Node3D.new()
	n.add_child(_caja(TABLERO_TAM + Vector3(0.06, 0.06, -0.01), MANGO))
	n.add_child(_caja(TABLERO_TAM, TABLERO))
	for lado in ["MangoL", "MangoR"]:
		var m := _caja(Vector3(0.035, LARGO_MANGO, 0.035), MANGO)
		m.name = lado
		n.add_child(m)
	for cara in 2:
		for i in 2:
			var l := Label3D.new()
			l.name = ("Sale" if i == 0 else "Entra") + str(cara)
			l.modulate = SALE if i == 0 else ENTRA
			l.font_size = 128
			l.pixel_size = 0.0032
			l.outline_size = 0
			l.shaded = false
			# Visto de cada lado, el que sale queda a la izquierda.
			var x := -0.25 if i == 0 else 0.25
			if cara == 0:
				l.position = Vector3(x, 0.0, TABLERO_TAM.z * 0.5 + 0.002)
			else:
				l.position = Vector3(-x, 0.0, -TABLERO_TAM.z * 0.5 - 0.002)
				l.rotation.y = PI
			n.add_child(l)
	return n


## Los mangos bajan del borde del tablero hasta cada mano (en X del tablero).
static func mangos_tablero(t: Node3D, x_izquierda: float, x_derecha: float) -> void:
	var y := -TABLERO_TAM.y * 0.5 - LARGO_MANGO * 0.5
	(t.get_node("MangoL") as Node3D).position = Vector3(x_izquierda, y, 0.0)
	(t.get_node("MangoR") as Node3D).position = Vector3(x_derecha, y, 0.0)


static func numeros_tablero(t: Node3D, sale: int, entra: int) -> void:
	for cara in 2:
		(t.get_node("Sale%d" % cara) as Label3D).text = str(sale)
		(t.get_node("Entra%d" % cara) as Label3D).text = str(entra)


## Base con Y a lo largo de `eje` (el antebrazo) y el resto perpendicular.
static func base_a_lo_largo(eje: Vector3, referencia: Vector3) -> Basis:
	var y := eje.normalized()
	var x := referencia.cross(y)
	if x.length() < 0.01:
		x = Vector3.RIGHT.cross(y)
	x = x.normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)
