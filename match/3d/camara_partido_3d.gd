class_name CamaraPartido3D
extends CamaraPartido

## La misma cámara del partido (seguimiento, anticipación y zoom), con el
## límite de bordes recalculado para lo que ve la vista 3D.
##
## CamaraPartido frena el centro para no mostrar fuera de la cancha. Lo
## calcula con el ancho visible del 2D (~73 m a 22 px/m), así que el centro
## no pasaba de x = ±28 m y la cámara nunca llegaba al arco. En 3D se ve
## ACERCAMIENTO veces menos cancha y el límite se corre en consecuencia.

## Cuántas veces menos cancha muestra el 3D a lo ancho que el 2D. Con 1.0
## los chibis quedaban de ~20 px y solo se veían las cabezas.
const ACERCAMIENTO := 2.2


func metros_visibles_3d(tamano_pantalla: Vector2) -> Vector2:
	var ancho := maxf(tamano_pantalla.x, 1.0) / maxf(px_por_metro, 1.0) / ACERCAMIENTO
	# La profundidad visible sale del alto de pantalla y de la inclinación de
	# la cámara: mirando a 38° un metro de pantalla cubre 1/sin(38°) de piso.
	var alto := ancho * tamano_pantalla.y / maxf(tamano_pantalla.x, 1.0) \
		/ sin(deg_to_rad(VistaCancha3D.ELEVACION_CAMARA))
	return Vector2(ancho, alto)


## Con la cámara baja la profundidad visible es enorme hacia el fondo y corta
## hacia adelante: el centro no se puede limitar por la mitad de lo visible.
## Se deja seguir la pelota a lo ancho hasta este margen de la línea.
const MARGEN_LATERAL_M := 6.0


func _clampear(tamano_pantalla: Vector2) -> void:
	var visible := metros_visibles_3d(tamano_pantalla)
	var limite_x: float = ProyeccionPartido.MEDIO_LARGO + MARGEN_M - visible.x * 0.5
	var limite_y: float = ProyeccionPartido.MEDIO_ANCHO - MARGEN_LATERAL_M
	centro.x = clampf(centro.x, -limite_x, limite_x) if limite_x > 0.0 else 0.0
	centro.y = clampf(centro.y, -limite_y, limite_y) if limite_y > 0.0 else 0.0


## El minimapa dibuja este recuadro: tiene que mostrar lo que ve el 3D.
func encuadre_metros(tamano_pantalla: Vector2) -> Rect2:
	var visible := metros_visibles_3d(tamano_pantalla)
	return Rect2(centro - visible * 0.5, visible)
