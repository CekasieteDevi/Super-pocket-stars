class_name SombrasRedondas
extends MultiMeshInstance3D

## Una mancha oscura en el pasto debajo de cada jugador y de la pelota, en vez
## de la sombra del sol. En el teléfono de referencia la sombra del sol dibuja
## otra vez a los 22 personajes con esqueleto por cada corte y bajaba el
## partido a 43 fps; sin ella son 60 (docs/motor_v2.md, etapa 0). Todas las
## manchas son una sola llamada de dibujo (MultiMesh).
##
## La mancha es una elipse corrida hacia donde cae la sombra del sol de la
## vista (VistaV2._armar_ambiente): así se lee del mismo lado que antes.

const SHADER := preload("res://match/3d/sombra_redonda.gdshader")
## La luz viaja hacia (0.55, -0.75, -0.6): en el piso la sombra cae hacia
## (0.55, -0.6), normalizado.
const HACIA_SOMBRA := Vector2(0.675, -0.737)
## Medidas en metros para el chibi a escala 0.75 (1.7 m): el ancho es el de
## los hombros y el largo sale estirado hacia el lado de la sombra.
const ANCHO_JUGADOR := 0.9
const LARGO_JUGADOR := 1.9
const CORRIDA_JUGADOR := 0.65
## La pelota a 2x (Cancha3D.ESCALA_PELOTA): mancha de 0.5 m en el piso
## que se achica y se aclara al subir.
const ANCHO_PELOTA := 0.5
const PELOTA_ALTURA_DESVANECE := 6.0
## Apenas arriba del pasto para no pelear con él por la profundidad.
const ALTO_SOBRE_PISO := 0.02

var _cantidad := 0


func _init(cantidad: int) -> void:
	_cantidad = cantidad
	var plano := QuadMesh.new()
	plano.size = Vector2.ONE
	plano.orientation = PlaneMesh.FACE_Y
	var material := ShaderMaterial.new()
	material.shader = SHADER
	plano.material = material
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = plano
	multimesh.instance_count = cantidad
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in cantidad:
		ocultar(i)


## La mancha `i` debajo de un jugador parado en `pie` (en el piso).
## `parado` (Jugador3D.parado): 1 parado; tirado en el piso, la mancha queda
## debajo del cuerpo y redonda. Con la mancha estirada hacia el sol, el
## arquero tirado se veía flotando.
func poner_jugador(i: int, pie: Vector3, parado := 1.0) -> void:
	_poner(i, Vector2(pie.x, pie.z) + HACIA_SOMBRA * CORRIDA_JUGADOR * parado, ANCHO_JUGADOR,
		lerpf(ANCHO_JUGADOR * 1.2, LARGO_JUGADOR, parado), 1.0)


## La mancha `i` debajo de la pelota: más chica y más clara cuanto más alta.
func poner_pelota(i: int, centro: Vector3) -> void:
	var alto := clampf(centro.y / PELOTA_ALTURA_DESVANECE, 0.0, 1.0)
	var tam := ANCHO_PELOTA * lerpf(1.0, 0.6, alto)
	_poner(i, Vector2(centro.x, centro.z) + HACIA_SOMBRA * centro.y * 0.8, tam, tam, 1.0 - alto * 0.8)


func ocultar(i: int) -> void:
	multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))


func _poner(i: int, centro: Vector2, ancho: float, largo: float, fuerza: float) -> void:
	# El eje largo (z del plano) apunta hacia donde cae la sombra.
	var z := Vector3(HACIA_SOMBRA.x, 0.0, HACIA_SOMBRA.y)
	var x := Vector3(-z.z, 0.0, z.x)
	var base := Basis(x * ancho, Vector3.UP, z * largo)
	multimesh.set_instance_transform(i, Transform3D(base, Vector3(centro.x, ALTO_SOBRE_PISO, centro.y)))
	multimesh.set_instance_color(i, Color(1.0, 1.0, 1.0, fuerza))
