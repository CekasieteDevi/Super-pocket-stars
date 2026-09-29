"""
Genera el atlas de cifras del dorsal de los jugadores 3D: assets/3d/numeros.png.

Uso:  python tools/generar_numeros.py [--muestra ruta.png]

Diez celdas en fila, del 0 al 9. Cada cifra va blanca sobre transparente:
el color lo pone personaje.gdshader (el mismo del número del 2D, blanco o
negro según la camiseta). La celda es media del rectángulo del dorsal
(Jugador3D.RECT_NUMERO): dos cifras ocupan el rectángulo entero.

Fuente: Archivo (ui/fuentes, la de los números del juego) en peso ExtraBold
y lo más angosta, como los números de camiseta.
"""
import sys
from PIL import Image, ImageDraw, ImageFont

ANCHO_CELDA, ALTO_CELDA = 128, 256
SUPER = 4  # se dibuja 4 veces más grande y se achica: bordes suaves
FUENTE = "ui/fuentes/Archivo.ttf"
PESO, ANCHO_FUENTE = 800, 62
# Lo que ocupa la cifra en la celda (el resto es margen: sin él, en el mipmap
# se mezclaban las cifras vecinas).
ALTO_CIFRA = 0.86
ANCHO_MAX = 0.8


def fuente(tam):
    f = ImageFont.truetype(FUENTE, tam)
    f.set_variation_by_axes([PESO, ANCHO_FUENTE])
    return f


def celda(cifra):
    w, h = ANCHO_CELDA * SUPER, ALTO_CELDA * SUPER
    img = Image.new("RGBA", (w, h), (255, 255, 255, 0))
    # Tamaño de fuente para que la cifra (sin márgenes de la fuente) mida
    # ALTO_CIFRA de la celda; si queda ancha, se achica.
    tam = 400
    x0, y0, x1, y1 = fuente(tam).getbbox(cifra)
    escala = min(h * ALTO_CIFRA / (y1 - y0), w * ANCHO_MAX / (x1 - x0))
    tam = int(tam * escala)
    f = fuente(tam)
    x0, y0, x1, y1 = f.getbbox(cifra)
    d = ImageDraw.Draw(img)
    d.text(((w - (x1 - x0)) / 2 - x0, (h - (y1 - y0)) / 2 - y0), cifra, font=f, fill=(255, 255, 255, 255))
    return img.resize((ANCHO_CELDA, ALTO_CELDA), Image.LANCZOS)


def main():
    atlas = Image.new("RGBA", (ANCHO_CELDA * 10, ALTO_CELDA), (255, 255, 255, 0))
    for n in range(10):
        atlas.paste(celda(str(n)), (n * ANCHO_CELDA, 0))
    atlas.save("assets/3d/numeros.png")
    print("assets/3d/numeros.png", atlas.size)
    if "--muestra" in sys.argv:
        ruta = sys.argv[sys.argv.index("--muestra") + 1]
        fondo = Image.new("RGBA", atlas.size, (200, 30, 40, 255))
        fondo.alpha_composite(atlas)
        fondo.save(ruta)
        print(ruta)


if __name__ == "__main__":
    main()
