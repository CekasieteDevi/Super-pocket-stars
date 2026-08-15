class_name PixelArt
extends RefCounted

## Sprites pixel-art generados por código (Fase de pulido visual) — no hay
## herramienta de generación de imágenes disponible en este entorno, así
## que en vez de archivos .png de un asset pack se arman texturas chicas
## (grilla de pocos píxeles) a mano acá y se dibujan con filtro NEAREST
## para que se vean en bloques, estilo 8/16-bit. Sirve como base: si más
## adelante aparece un asset pack real, estas funciones son el punto único
## a reemplazar sin tocar Cancha/Pelota.

const SKIN := Color(0.94, 0.76, 0.6)
const PELO := Color(0.25, 0.15, 0.08)
const SHORT := Color(0.12, 0.12, 0.15)
const BOTIN := Color(0.05, 0.05, 0.05)
const TRANSPARENTE := Color(0, 0, 0, 0)

## 8x14 — chibi de espaldas visto desde arriba/atrás, suficiente para
## distinguir equipo por color de camiseta a la escala de la cancha.
const _JUGADOR_FILAS := [
	"..HHHH..",
	".HSSSSH.",
	".SSSSSS.",
	".SSSSSS.",
	"..JJJJ..",
	".JJJJJJ.",
	".JJJJJJ.",
	".JJJJJJ.",
	".JJJJJJ.",
	"..DDDD..",
	"..DDDD..",
	"..D..D..",
	".BB..BB.",
	"........",
]

## 8x8 — pelota con un par de píxeles negros de "textura" en el medio.
const _PELOTA_FILAS := [
	"..WWWW..",
	".WWWWWW.",
	"WWWWWWWW",
	"WWWBBWWW",
	"WWWBBWWW",
	"WWWWWWWW",
	".WWWWWW.",
	"..WWWW..",
]


static func jugador_textura(color_camiseta: Color) -> ImageTexture:
	var paleta := {
		".": TRANSPARENTE,
		"H": PELO,
		"S": SKIN,
		"J": color_camiseta,
		"D": SHORT,
		"B": BOTIN,
	}
	return _construir(_JUGADOR_FILAS, paleta)


static func pelota_textura() -> ImageTexture:
	var paleta := {
		".": TRANSPARENTE,
		"W": Color.WHITE,
		"B": Color(0.05, 0.05, 0.05),
	}
	return _construir(_PELOTA_FILAS, paleta)


static func _construir(filas: Array, paleta: Dictionary) -> ImageTexture:
	var alto := filas.size()
	var ancho: int = filas[0].length()
	var img := Image.create(ancho, alto, false, Image.FORMAT_RGBA8)
	for y in range(alto):
		var fila: String = filas[y]
		for x in range(ancho):
			img.set_pixel(x, y, paleta[fila[x]])
	return ImageTexture.create_from_image(img)
