extends Control

## Preview de identidad de club.
## Cada PNG ya viene recortado, centrado y con margen transparente uniforme.

const ESCUDOS := [
	preload("res://assets/club_creator/escudos_limpios/escudo_00.png"),
	preload("res://assets/club_creator/escudos_limpios/escudo_01.png"),
	preload("res://assets/club_creator/escudos_limpios/escudo_02.png"),
	preload("res://assets/club_creator/escudos_limpios/escudo_03.png"),
	preload("res://assets/club_creator/escudos_limpios/escudo_04.png"),
	preload("res://assets/club_creator/escudos_limpios/escudo_05.png"),
	preload("res://assets/club_creator/escudos_limpios/escudo_06.png"),
	preload("res://assets/club_creator/escudos_limpios/escudo_07.png"),
	preload("res://assets/club_creator/escudos_limpios/escudo_08.png"),
	preload("res://assets/club_creator/escudos_limpios/escudo_09.png"),
]
const LOGOS := [
	preload("res://assets/club_creator/logos_limpios/logo_00.png"),
	preload("res://assets/club_creator/logos_limpios/logo_01.png"),
	preload("res://assets/club_creator/logos_limpios/logo_02.png"),
	preload("res://assets/club_creator/logos_limpios/logo_03.png"),
	preload("res://assets/club_creator/logos_limpios/logo_04.png"),
	preload("res://assets/club_creator/logos_limpios/logo_05.png"),
	preload("res://assets/club_creator/logos_limpios/logo_06.png"),
	preload("res://assets/club_creator/logos_limpios/logo_07.png"),
	preload("res://assets/club_creator/logos_limpios/logo_08.png"),
	preload("res://assets/club_creator/logos_limpios/logo_09.png"),
]
const SHADER_TINTE := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	float brillo = dot(pixel.rgb, vec3(0.299, 0.587, 0.114));
	brillo = mix(0.68, 1.08, brillo);
	COLOR = vec4(tint.rgb * brillo, pixel.a * tint.a);
}
"""

const NOMBRES_ESCUDOS := [
	"Clásico", "Redondo", "Francés", "Inglés", "Italiano",
	"Diamante", "Octogonal", "Heater", "Vesica", "Punta"
]
const NOMBRES_LOGOS := [
	"Estrella", "Pelota", "León", "Águila", "Lobo",
	"Ciervo", "Barco", "Rayo", "Corona", "Montaña"
]

var forma_escudo: int = 0
var forma_logo: int = 0
var color_escudo: Color = Color("#e85b3f")
var color_logo: Color = Color("#f7f1e5")
var _vista_escudo: TextureRect
var _vista_logo: TextureRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vista_escudo = _crear_vista()
	_vista_logo = _crear_vista()
	add_child(_vista_escudo)
	add_child(_vista_logo)
	_actualizar_visual()


func _notification(que: int) -> void:
	if que == NOTIFICATION_RESIZED and is_instance_valid(_vista_escudo):
		_actualizar_layout()


func configurar(nuevo_escudo: int, nuevo_logo: int, nuevo_color_escudo: Color,
		nuevo_color_logo: Color) -> void:
	forma_escudo = clampi(nuevo_escudo, 0, ESCUDOS.size() - 1)
	forma_logo = clampi(nuevo_logo, 0, LOGOS.size() - 1)
	color_escudo = nuevo_color_escudo if nuevo_color_escudo.a > 0.0 else Color("#e85b3f")
	color_logo = nuevo_color_logo if nuevo_color_logo.a > 0.0 else Color("#f7f1e5")
	if is_instance_valid(_vista_escudo):
		_actualizar_visual()


func _crear_vista() -> TextureRect:
	var vista := TextureRect.new()
	vista.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vista.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vista.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var shader := Shader.new()
	shader.code = SHADER_TINTE
	var material := ShaderMaterial.new()
	material.shader = shader
	vista.material = material
	return vista


func _actualizar_visual() -> void:
	_actualizar_textura(_vista_escudo, ESCUDOS[forma_escudo], color_escudo)
	_actualizar_textura(_vista_logo, LOGOS[forma_logo], color_logo)
	_actualizar_layout()


func _actualizar_textura(vista: TextureRect, textura: Texture2D, color: Color) -> void:
	vista.texture = textura
	(vista.material as ShaderMaterial).set_shader_parameter("tint", color)


func _actualizar_layout() -> void:
	if minf(size.x, size.y) < 64.0:
		var margen := minf(size.x, size.y) * 0.04
		_vista_escudo.position = Vector2(margen, margen)
		_vista_escudo.size = size - Vector2.ONE * margen * 2.0
		# En el marcador el escudo ocupa casi todo el icono, pero el logo
		# sigue dentro de una zona segura central.
		var tam_logo := minf(size.x, size.y) * 0.46
		_vista_logo.position = (size - Vector2.ONE * tam_logo) * 0.5
		_vista_logo.size = Vector2.ONE * tam_logo
		return

	var ancho_preview := minf(size.x * 0.52, 180.0)
	var alto_preview := minf(size.y * 0.94, 220.0)
	var centro := size * 0.5
	var area_escudo := Rect2(
		centro.x - ancho_preview * 0.5,
		centro.y - alto_preview * 0.5,
		ancho_preview,
		alto_preview
	)
	_vista_escudo.position = area_escudo.position
	_vista_escudo.size = area_escudo.size

	# Centro exacto del mismo contenedor. Margen amplio para cualquier logo.
	var area_logo := Rect2(
		centro.x - ancho_preview * 0.25,
		centro.y - alto_preview * 0.16,
		ancho_preview * 0.50,
		alto_preview * 0.32
	)
	_vista_logo.position = area_logo.position
	_vista_logo.size = area_logo.size
