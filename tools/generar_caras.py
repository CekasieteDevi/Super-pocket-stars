"""
Genera el atlas de caras de los jugadores 3D: assets/3d/caras.png.

Uso:  python tools/generar_caras.py [--calibracion] [--muestra ruta.png]

El atlas tiene una fila por cara (CARAS) y una columna por gesto (GESTOS).
Cada celda cubre el rectángulo de la cara del chibi visto de frente
(X0..X1, Y0..Y1, en metros de la malla del GLB): Jugador3D proyecta ese
rectángulo sobre la piel de la cabeza (UV2). Lo que no se dibuja queda
transparente y se ve la piel.

Estilo: el de la cara que traía el modelo de Blender (ojos en arco y boca
abierta): líneas marrón casi negro de punta redonda, colores planos, sin
degradados. El marrón y el rojo de la boca son los de los materiales Ojos,
Boca y Lengua del GLB.

Medidas (metros de la malla, medidas con scratch/_diag_cara_malla.gd y la
grilla de --calibracion): los ojos del modelo iban en x = ±0.11..0.29,
y = 1.47..1.54; la boca en y = 1.24..1.39; el mentón en 1.18; las puntas del
flequillo bajan hasta 1.62. Las cejas van debajo de las puntas.
"""
import sys
from PIL import Image, ImageDraw, ImageChops, ImageFont

X0, X1 = -0.4, 0.4
Y0, Y1 = 1.15, 1.75
ANCHO_CELDA, ALTO_CELDA = 256, 192
SUPER = 4  # se dibuja 4 veces más grande y se achica: bordes suaves

GESTOS = ["normal", "feliz", "dolor", "triste", "parpadeo"]

# Colores de los materiales del GLB (Ojos, Boca, Lengua, Cachetes).
LINEA = (0x3a, 0x20, 0x16, 255)
BOCA = (0x8a, 0x1a, 0x22, 255)
LENGUA = (0xf0, 0x7a, 0x86, 255)
CACHETE = (0xf5, 0x8e, 0x8c)
BLANCO = (0xff, 0xfb, 0xf4, 255)
BRILLO = (0xff, 0xff, 0xff, 255)
LAGRIMA = (0x7c, 0xc8, 0xf4, 255)
CURITA = (0xf2, 0xc8, 0x8e, 255)
CURITA_PUNTO = (0xd9, 0xa4, 0x6a, 255)
CICATRIZ = (0xc4, 0x78, 0x66, 255)
PECA = (0xc2, 0x7a, 0x52, 255)
OJERA = (0x9a, 0x5e, 0x58, 110)

IRIS = {
    "marron": (0x6b, 0x3e, 0x22, 255),
    "oscuro": (0x3a, 0x22, 0x18, 255),
    "miel": (0x9a, 0x6a, 0x22, 255),
    "verde": (0x3f, 0x7a, 0x3c, 255),
    "celeste": (0x3a, 0x74, 0xb8, 255),
    "gris": (0x5d, 0x6f, 0x7e, 255),
}

# Ojos, y del centro y de las cejas en reposo.
OJO_Y = 1.47
CEJA_Y = 1.575
BOCA_Y = 1.3
# Las formas de abajo se dibujan en su tamaño "de libro" y después se agrandan
# alrededor de su centro. En el chibi, a 1:1, los ojos quedaban la mitad de
# anchos que los del modelo (0.18 m) y de lejos no se leía ningún gesto.
ESCALA_OJOS = 1.3
ESCALA_CEJAS = 1.15
ESCALA_BOCA = 1.25

# Las 20 caras. ojos/cejas/boca son la forma de cada una; sep es la x del
# centro de cada ojo; tam agranda o achica los ojos; cachete es el alfa del
# rubor (0 = sin rubor); extras son marcas propias que se ven en todos los
# gestos. triste: "frunce" (boca para abajo), "tiembla" (ondulada) o "abierta".
CARAS = [
    dict(nombre="clasico", ojos="redondos", cejas="finas", boca="sonrisa", sep=0.19, cachete=0.4,
         iris="oscuro", extras=[], triste="frunce"),
    dict(nombre="picaro", ojos="almendrados", cejas="arqueadas", boca="mueca", sep=0.19, cachete=0.25,
         iris="miel", extras=["lunar_boca"], triste="tiembla"),
    dict(nombre="guerrero", ojos="serios", cejas="angulosas", boca="recta", sep=0.19, cachete=0.0,
         iris="oscuro", extras=["cicatriz"], triste="frunce", lagrima=False),
    dict(nombre="dormilon", ojos="dormilones", cejas="finas", boca="o", sep=0.19, cachete=0.3,
         iris="marron", extras=["ojeras"], triste="abierta"),
    dict(nombre="pecoso", ojos="grandes", cejas="cortas", boca="abierta", sep=0.19, cachete=0.35,
         iris="verde", extras=["pecas"], triste="tiembla"),
    dict(nombre="timido", ojos="puntos", cejas="finas_altas", boca="chica", sep=0.18, cachete=0.55,
         iris="oscuro", extras=[], triste="tiembla"),
    dict(nombre="brillante", ojos="brillantes", cejas="arqueadas", boca="colmillo", sep=0.19, cachete=0.35,
         iris="celeste", extras=[], triste="abierta"),
    dict(nombre="gato", ojos="rasgados", cejas="cortas", boca="gato", sep=0.195, cachete=0.3,
         iris="miel", extras=[], triste="frunce"),
    dict(nombre="veterano", ojos="serios", cejas="pobladas", boca="recta", sep=0.19, cachete=0.0,
         iris="gris", extras=["hoyuelo", "arrugas"], triste="frunce", lagrima=False),
    dict(nombre="galan", ojos="almendrados", cejas="gruesas", boca="confiada", sep=0.19, cachete=0.2,
         iris="celeste", extras=["nariz"], triste="frunce"),
    dict(nombre="nervioso", ojos="grandes_chicos", cejas="finas_altas", boca="nerviosa", sep=0.19, cachete=0.3,
         iris="marron", extras=["sudor"], triste="tiembla"),
    dict(nombre="rudo", ojos="rasgados", cejas="angulosas_gruesas", boca="enojada", sep=0.195, cachete=0.0,
         iris="oscuro", extras=["curita_nariz"], triste="frunce", lagrima=False),
    dict(nombre="alegre", ojos="finos", cejas="cortas", boca="abierta_grande", sep=0.18, cachete=0.45,
         iris="oscuro", extras=[], triste="abierta"),
    dict(nombre="concentrado", ojos="redondos_chicos", cejas="rectas_bajas", boca="recta_chica", sep=0.18,
         cachete=0.0, iris="oscuro", extras=["nariz"], triste="frunce"),
    dict(nombre="travieso", ojos="brillantes", cejas="asimetricas", boca="lengua", sep=0.19, cachete=0.4,
         iris="verde", extras=["pecas_pocas"], triste="tiembla"),
    dict(nombre="sereno", ojos="dormilones", cejas="finas", boca="sonrisa", sep=0.19, cachete=0.25,
         iris="celeste", extras=["lunar_ojo"], triste="frunce"),
    dict(nombre="crack", ojos="grandes", cejas="angulosas", boca="colmillo", sep=0.19, cachete=0.25,
         iris="miel", extras=["curita_cachete"], triste="abierta"),
    dict(nombre="grandote", ojos="puntos_grandes", cejas="pobladas", boca="dientes", sep=0.2, cachete=0.3,
         iris="oscuro", extras=["nariz"], triste="frunce"),
    dict(nombre="zorro", ojos="almendrados_finos", cejas="finas_angulosas", boca="mueca", sep=0.19,
         cachete=0.15, iris="verde", extras=["pecas_pocas"], triste="tiembla"),
    dict(nombre="bonachon", ojos="redondos", cejas="arqueadas", boca="gato", sep=0.19, cachete=0.55,
         iris="oscuro", extras=["nariz"], triste="abierta"),
]


def px(x, y):
    """Metros de la malla -> píxel de la celda grande (antes de achicar)."""
    return ((x - X0) / (X1 - X0) * ANCHO_CELDA * SUPER, (Y1 - y) / (Y1 - Y0) * ALTO_CELDA * SUPER)


def m(v):
    """Metros -> píxeles grandes (para anchos de línea y radios)."""
    return v / (X1 - X0) * ANCHO_CELDA * SUPER


def bezier(a, c, b, pasos=24):
    return [((1 - t) ** 2 * a[0] + 2 * (1 - t) * t * c[0] + t * t * b[0],
             (1 - t) ** 2 * a[1] + 2 * (1 - t) * t * c[1] + t * t * b[1])
            for t in (i / pasos for i in range(pasos + 1))]


def elipse_puntos(cx, cy, rx, ry, pasos=48):
    import math
    return [(cx + rx * math.cos(2 * math.pi * i / pasos), cy + ry * math.sin(2 * math.pi * i / pasos))
            for i in range(pasos)]


class Capa:
    """Una imagen RGBA del tamaño de la celda grande, dibujada en metros."""

    def __init__(self):
        self.img = Image.new("RGBA", (ANCHO_CELDA * SUPER, ALTO_CELDA * SUPER), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    def trazo(self, puntos, ancho, color=LINEA):
        """Línea de punta y uniones redondas por puntos en metros."""
        p = [px(*q) for q in puntos]
        r = m(ancho) / 2
        if len(p) > 1:
            self.d.line(p, fill=color, width=max(1, round(m(ancho))), joint="curve")
        for (x, y) in (p[0], p[-1]) if len(p) > 1 else p:
            self.d.ellipse((x - r, y - r, x + r, y + r), fill=color)

    def curva(self, a, c, b, ancho, color=LINEA):
        self.trazo(bezier(a, c, b), ancho, color)

    def relleno(self, puntos, color):
        self.d.polygon([px(*q) for q in puntos], fill=color)

    def elipse(self, cx, cy, rx, ry, color):
        x0, y0 = px(cx - rx, cy + ry)
        x1, y1 = px(cx + rx, cy - ry)
        self.d.ellipse((x0, y0, x1, y1), fill=color)

    def recortar(self, puntos):
        """Deja solo lo que cae adentro del polígono (en metros)."""
        mascara = Image.new("L", self.img.size, 0)
        ImageDraw.Draw(mascara).polygon([px(*q) for q in puntos], fill=255)
        r, g, b, a = self.img.split()
        self.img = Image.merge("RGBA", (r, g, b, ImageChops.multiply(a, mascara)))
        self.d = ImageDraw.Draw(self.img)

    def escalar(self, cx, cy, s):
        """Agranda todo lo dibujado `s` veces alrededor de (cx, cy) en metros."""
        pcx, pcy = px(cx, cy)
        self.img = self.img.transform(self.img.size, Image.AFFINE,
                                      (1 / s, 0, pcx - pcx / s, 0, 1 / s, pcy - pcy / s),
                                      resample=Image.BICUBIC)
        self.d = ImageDraw.Draw(self.img)
        return self

    def pegar(self, otra):
        self.img.alpha_composite(otra.img)

    def celda(self):
        chica = self.img.convert("RGBa").resize((ANCHO_CELDA, ALTO_CELDA), Image.LANCZOS)
        return chica.convert("RGBA")


# ---------------------------------------------------------------- ojos

def ojo_con_parpado(lz, cx, cy, lado, rx, ry, dibujar, parpado):
    """Dibuja el ojo en una capa aparte y, si hay párpado, corta lo de arriba.
    `parpado` = (alto en el lado de afuera, alto en el de adentro) respecto
    de cy, o None. Devuelve la línea del párpado para trazarla encima."""
    capa = Capa()
    dibujar(capa)
    linea = None
    if parpado is not None:
        afuera, adentro = parpado
        xa, xi = cx + lado * (rx + 0.02), cx - lado * (rx + 0.02)
        linea = [(xa, cy + afuera), (xi, cy + adentro)]
        capa.recortar([linea[0], linea[1], (xi, cy - ry - 0.05), (xa, cy - ry - 0.05)])
    lz.pegar(capa)
    return linea


def iris_con_brillo(c, cx, cy, rx, ry, color, mira_abajo=0.0, brillo=1.0):
    cy -= mira_abajo
    c.elipse(cx, cy, rx, ry, color)
    if color != LINEA:
        c.elipse(cx, cy - ry * 0.05, rx * 0.55, ry * 0.55, LINEA)
    c.elipse(cx - rx * 0.35, cy + ry * 0.38, rx * 0.36 * brillo, ry * 0.3 * brillo, BRILLO)
    c.elipse(cx + rx * 0.35, cy - ry * 0.42, rx * 0.16, ry * 0.12, BRILLO)


def ojo_abierto(lz, cara, cx, cy, lado, estado):
    """estado: normal o triste (párpado caído hacia afuera y mira abajo)."""
    tipo = cara["ojos"]
    iris = IRIS[cara["iris"]]
    triste = estado == "triste"
    abajo = 0.012 if triste else 0.0
    parpado = None
    brillo = 1.25 if triste else 1.0

    if tipo in ("redondos", "redondos_chicos", "puntos", "puntos_grandes", "finos"):
        rx, ry = {"redondos": (0.042, 0.056), "redondos_chicos": (0.032, 0.042),
                  "puntos": (0.022, 0.028), "puntos_grandes": (0.03, 0.036),
                  "finos": (0.013, 0.046)}[tipo]
        if triste:
            parpado = (ry * 0.1, ry * 0.75)

        def dibujar(c):
            c.elipse(cx, cy - abajo, rx, ry, LINEA)
            if tipo in ("redondos", "redondos_chicos"):
                c.elipse(cx - rx * 0.32, cy - abajo + ry * 0.36, rx * 0.36 * brillo, ry * 0.3 * brillo, BRILLO)
                c.elipse(cx + rx * 0.3, cy - abajo - ry * 0.4, rx * 0.15, ry * 0.12, BRILLO)
            elif tipo == "puntos_grandes":
                c.elipse(cx - rx * 0.3, cy - abajo + ry * 0.35, rx * 0.3, ry * 0.26, BRILLO)
        linea = ojo_con_parpado(lz, cx, cy, lado, rx, ry, dibujar, parpado)
        if linea:
            lz.trazo(linea, 0.012)
        return

    if tipo in ("grandes", "grandes_chicos", "brillantes"):
        rx, ry = (0.05, 0.062) if tipo != "brillantes" else (0.05, 0.066)
        irx, iry = {"grandes": (0.032, 0.045), "grandes_chicos": (0.018, 0.024),
                    "brillantes": (0.04, 0.054)}[tipo]
        parpado = (ry * 0.15, ry * 0.8) if triste else None

        def dibujar(c):
            if tipo != "brillantes":
                c.elipse(cx, cy, rx, ry, BLANCO)
                iris_con_brillo(c, cx + lado * -0.004, cy - 0.008, irx, iry, iris, abajo, brillo)
                c.recortar(elipse_puntos(cx, cy, rx, ry))
            else:
                c.elipse(cx, cy, rx, ry, BLANCO)
                c.elipse(cx, cy - 0.006 - abajo, irx, iry, iris)
                c.elipse(cx, cy - 0.006 - abajo + iry * 0.35, irx, iry * 0.55, LINEA)
                c.elipse(cx - irx * 0.35, cy - abajo + iry * 0.3, irx * 0.4 * brillo, iry * 0.32 * brillo, BRILLO)
                c.elipse(cx + irx * 0.4, cy - abajo - iry * 0.45, irx * 0.2, iry * 0.16, BRILLO)
                c.elipse(cx + irx * 0.05, cy - abajo - iry * 0.1, irx * 0.1, iry * 0.08, BRILLO)
                c.recortar(elipse_puntos(cx, cy, rx, ry))
        ojo_con_parpado(lz, cx, cy, lado, rx, ry, dibujar, parpado)
        # Contorno: arriba grueso (las pestañas), abajo fino.
        if parpado:
            lz.trazo([(cx + lado * rx * 1.05, cy + parpado[0]), (cx - lado * rx * 1.05, cy + parpado[1])], 0.016)
        else:
            lz.curva((cx - rx * 1.05, cy + ry * 0.25), (cx, cy + ry * 1.45), (cx + rx * 1.05, cy + ry * 0.25), 0.017)
            if tipo == "brillantes":
                lz.trazo([(cx + lado * rx * 0.95, cy + ry * 0.35), (cx + lado * rx * 1.3, cy + ry * 0.6)], 0.012)
        lz.curva((cx - rx * 0.9, cy - ry * 0.35), (cx, cy - ry * 1.3), (cx + rx * 0.9, cy - ry * 0.35), 0.008)
        return

    if tipo in ("almendrados", "almendrados_finos", "rasgados", "serios", "dormilones"):
        w = {"almendrados": 0.056, "almendrados_finos": 0.058, "rasgados": 0.056,
             "serios": 0.048, "dormilones": 0.052}[tipo]
        arriba = {"almendrados": 0.055, "almendrados_finos": 0.04, "rasgados": 0.034,
                  "serios": 0.05, "dormilones": 0.05}[tipo]
        abajo_ojo = {"almendrados": 0.04, "almendrados_finos": 0.03, "rasgados": 0.03,
                     "serios": 0.048, "dormilones": 0.045}[tipo]
        # La punta de afuera sube (ojo rasgado) o baja (triste).
        sube_afuera = {"almendrados": 0.012, "almendrados_finos": 0.02, "rasgados": 0.024,
                       "serios": 0.0, "dormilones": -0.004}[tipo]
        if triste:
            sube_afuera = -0.01
        afuera = (cx + lado * w, cy + sube_afuera)
        adentro = (cx - lado * w, cy - 0.004)
        sup = bezier(afuera, (cx, cy + arriba * 1.6), adentro)
        inf = bezier(adentro, (cx, cy - abajo_ojo * 1.6), afuera)
        forma = sup + inf[1:-1]
        irx = {"almendrados": 0.03, "almendrados_finos": 0.026, "rasgados": 0.024,
               "serios": 0.03, "dormilones": 0.032}[tipo]
        # Serios: el párpado de arriba es una recta que baja hacia adentro.
        # Dormilones: el párpado tapa la mitad de arriba.
        parpado = None
        if tipo == "serios":
            parpado = (0.034, 0.018)
        elif tipo == "dormilones":
            parpado = (0.008, 0.01)
        if triste:
            parpado = (0.0, 0.03) if tipo != "dormilones" else (-0.004, 0.012)

        def dibujar(c):
            c.relleno(forma, BLANCO)
            iris_con_brillo(c, cx - lado * 0.006, cy - 0.004, irx, irx * 1.2, IRIS[cara["iris"]], abajo, brillo)
            c.recortar(forma)
        linea = ojo_con_parpado(lz, cx, cy, lado, w - 0.02, arriba, dibujar, parpado)
        if linea:
            lz.trazo(linea, 0.018)
        else:
            lz.trazo(sup, 0.018 if tipo != "almendrados_finos" else 0.016)
        lz.trazo(inf, 0.008)
        if tipo in ("almendrados", "almendrados_finos", "rasgados") and not triste:
            # Pestaña de afuera.
            lz.trazo([afuera, (afuera[0] + lado * 0.018, afuera[1] + 0.014)], 0.011)
        return
    raise ValueError(tipo)


def ojo_feliz(lz, cara, cx, cy, lado):
    """^ ^: el arco del ojo del modelo original (y = 1.47..1.54)."""
    w = 0.05 if cara["ojos"] not in ("puntos", "finos", "redondos_chicos") else 0.042
    lz.curva((cx - w, cy - 0.018), (cx, cy + 0.055), (cx + w, cy - 0.018), 0.017)


def ojo_dolor(lz, cara, cx, cy, lado):
    """> <: apretado, con la punta hacia la nariz."""
    w, h = 0.044, 0.03
    fuera = cx + lado * w
    lz.trazo([(fuera, cy + h), (cx - lado * w * 0.7, cy), (fuera, cy - h)], 0.016)


def ojo_cerrado(lz, cara, cx, cy, lado):
    """Parpadeo: una línea curva hacia abajo, del ancho del ojo."""
    w = {"puntos": 0.026, "finos": 0.022, "redondos_chicos": 0.034, "puntos_grandes": 0.032,
         "grandes_chicos": 0.045}.get(cara["ojos"], 0.048)
    cy -= 0.01
    lz.curva((cx - w, cy + 0.004), (cx, cy - 0.022), (cx + w, cy + 0.004), 0.014)
    if cara["ojos"] in ("almendrados", "almendrados_finos", "rasgados", "brillantes"):
        lz.trazo([(cx + lado * w, cy + 0.004), (cx + lado * (w + 0.014), cy + 0.014)], 0.01)


# --------------------------------------------------------------- cejas

CEJAS = {
    # medio largo, grosor, arco, inclinación (+ = la punta de adentro más alta), alto extra
    "finas": (0.048, 0.011, 0.012, 0.0, 0.0),
    "finas_altas": (0.046, 0.011, 0.014, 0.004, 0.01),
    "finas_angulosas": (0.05, 0.012, 0.004, -0.018, 0.0),
    "gruesas": (0.052, 0.02, 0.006, -0.004, 0.0),
    "pobladas": (0.056, 0.026, 0.008, -0.004, -0.002),
    "arqueadas": (0.05, 0.014, 0.024, 0.0, 0.004),
    "angulosas": (0.052, 0.016, 0.0, -0.022, -0.002),
    "angulosas_gruesas": (0.054, 0.022, 0.0, -0.026, -0.004),
    "cortas": (0.03, 0.016, 0.006, 0.0, 0.0),
    "rectas_bajas": (0.05, 0.018, 0.0, -0.006, -0.012),
    "asimetricas": (0.05, 0.014, 0.018, 0.0, 0.0),
}


def ceja(lz, cara, cx, lado, estado, indice_ojo):
    largo, grosor, arco, incl, alto = CEJAS[cara["cejas"]]
    y = CEJA_Y + alto
    if cara["cejas"] == "asimetricas" and lado > 0:
        y += 0.014
        incl -= 0.012
    if estado == "feliz":
        y += 0.01
        arco += 0.008
        incl = max(incl, 0.0) * 0.5
    elif estado == "dolor":
        y -= 0.004
        incl = 0.03
        arco = -0.004
    elif estado == "triste":
        incl = 0.032
        arco = 0.004
    centro = cx - lado * 0.004
    afuera = (centro + lado * largo, y - incl / 2)
    adentro = (centro - lado * largo, y + incl / 2)
    lz.curva(afuera, (centro, y + arco * 2), adentro, grosor)
    if cara["cejas"] == "pobladas":
        # Un segundo trazo corrido le da el borde despeinado.
        lz.curva((afuera[0], afuera[1] + 0.006), (centro, y + arco * 2 + 0.01),
                 (adentro[0] + lado * 0.012, adentro[1] + 0.004), grosor * 0.6)


# ---------------------------------------------------------------- bocas

def boca_d(lz, ancho, arriba, fondo, dientes=False, lengua=True, torcida=0.0):
    """Boca abierta en D, como la del modelo original: recta arriba, redonda abajo."""
    iz, de = (-ancho, arriba - torcida), (ancho, arriba + torcida)
    borde = bezier(iz, (0.0, arriba + 0.012), de) + bezier(de, (0.0, fondo - 0.04), iz)[1:-1]
    capa = Capa()
    capa.relleno(borde, BOCA)
    if lengua:
        capa.elipse(0.0, fondo + 0.004, ancho * 0.55, 0.03, LENGUA)
    if dientes:
        capa.relleno([(-ancho, arriba + 0.02), (ancho, arriba + 0.02), (ancho, arriba - 0.016),
                      (-ancho, arriba - 0.016)], BLANCO)
    capa.recortar(borde)
    lz.pegar(capa)
    lz.trazo(borde + [borde[0]], 0.011)


def boca_normal(lz, cara):
    b = cara["boca"]
    y = BOCA_Y
    if b == "sonrisa":
        lz.curva((-0.05, y + 0.016), (0.0, y - 0.03), (0.05, y + 0.016), 0.012)
    elif b == "abierta":
        boca_d(lz, 0.045, y + 0.018, y - 0.03, lengua=True)
    elif b == "abierta_grande":
        boca_d(lz, 0.058, y + 0.024, y - 0.042, lengua=True)
    elif b == "recta":
        lz.curva((-0.036, y), (0.0, y - 0.004), (0.036, y), 0.012)
    elif b == "recta_chica":
        lz.trazo([(-0.024, y), (0.024, y)], 0.011)
    elif b == "mueca":
        lz.curva((-0.042, y - 0.004), (0.01, y - 0.014), (0.046, y + 0.018), 0.012)
        lz.trazo([(0.046, y + 0.018), (0.056, y + 0.012)], 0.009)
    elif b == "confiada":
        lz.curva((-0.046, y + 0.004), (0.0, y - 0.022), (0.05, y + 0.022), 0.012)
    elif b == "o":
        lz.elipse(0.0, y - 0.004, 0.021, 0.024, LINEA)
        lz.elipse(0.0, y - 0.004, 0.012, 0.015, BOCA)
    elif b == "chica":
        lz.curva((-0.022, y + 0.008), (0.0, y - 0.014), (0.022, y + 0.008), 0.011)
    elif b == "gato":
        lz.trazo(bezier((-0.046, y + 0.014), (-0.024, y - 0.03), (0.0, y + 0.004))
                 + bezier((0.0, y + 0.004), (0.024, y - 0.03), (0.046, y + 0.014))[1:], 0.011)
    elif b == "colmillo":
        lz.curva((-0.05, y + 0.014), (0.0, y - 0.028), (0.05, y + 0.014), 0.012)
        lz.relleno([(0.016, y - 0.004), (0.034, y + 0.0), (0.026, y - 0.026)], BLANCO)
        lz.trazo([(0.016, y - 0.004), (0.026, y - 0.026), (0.034, y + 0.0)], 0.007)
    elif b == "nerviosa":
        lz.trazo([(-0.042, y), (-0.028, y + 0.01), (-0.014, y), (0.0, y + 0.01), (0.014, y),
                  (0.028, y + 0.01), (0.042, y)], 0.01)
    elif b == "enojada":
        lz.curva((-0.04, y - 0.004), (0.0, y + 0.012), (0.04, y - 0.004), 0.013)
    elif b == "lengua":
        lz.curva((-0.046, y + 0.012), (0.0, y - 0.024), (0.046, y + 0.012), 0.012)
        capa = Capa()
        capa.elipse(0.018, y - 0.022, 0.018, 0.02, LENGUA)
        capa.recortar([(-0.1, y - 0.004), (0.1, y - 0.004), (0.1, y - 0.1), (-0.1, y - 0.1)])
        lz.pegar(capa)
        lz.trazo(bezier((0.0, y - 0.006), (0.018, y - 0.06), (0.036, y - 0.006)), 0.009)
    elif b == "dientes":
        forma = [(-0.05, y + 0.014), (0.05, y + 0.014)] + bezier((0.05, y + 0.014), (0.0, y - 0.05),
                                                                  (-0.05, y + 0.014))[1:-1]
        lz.relleno(forma, BLANCO)
        lz.trazo(forma + [forma[0]], 0.011)
        lz.trazo([(-0.04, y - 0.002), (0.04, y - 0.002)], 0.007)
    else:
        raise ValueError(b)


def boca_feliz(lz, cara):
    b = cara["boca"]
    dientes = b in ("dientes", "colmillo", "confiada")
    boca_d(lz, 0.078, BOCA_Y + 0.032, BOCA_Y - 0.052, dientes=dientes, lengua=True)


def boca_dolor(lz, cara, i):
    """Dientes apretados, un poco torcida (cada cara para su lado)."""
    ancho, alto = 0.07, 0.03
    y = BOCA_Y - 0.004
    t = 0.007 if i % 2 == 0 else -0.007
    # Rectángulo de puntas redondas, un poco torcido: se lee de lejos.
    arriba = bezier((-ancho, y + alto * 0.55 - t), (-ancho, y + alto - t), (-ancho * 0.6, y + alto - t * 0.6)) \
        + bezier((ancho * 0.6, y + alto + t * 0.6), (ancho, y + alto + t), (ancho, y + alto * 0.55 + t))
    abajo = bezier((ancho, y - alto * 0.55 + t), (ancho, y - alto + t), (ancho * 0.6, y - alto + t * 0.6)) \
        + bezier((-ancho * 0.6, y - alto - t * 0.6), (-ancho, y - alto - t), (-ancho, y - alto * 0.55 - t))
    forma = arriba + abajo
    lz.relleno(forma, BLANCO)
    lz.trazo([(-ancho, y - t), (ancho, y + t)], 0.008)
    for x in (-ancho / 3, ancho / 3):
        lz.trazo([(x, y + alto * 0.9 + t * x / ancho), (x, y - alto * 0.9 + t * x / ancho)], 0.007)
    lz.trazo(forma + [forma[0]], 0.012)


def boca_triste(lz, cara):
    y = BOCA_Y
    tipo = cara["triste"]
    if tipo == "frunce":
        lz.curva((-0.044, y - 0.016), (0.0, y + 0.03), (0.044, y - 0.016), 0.012)
    elif tipo == "tiembla":
        lz.trazo([(-0.046, y - 0.012), (-0.03, y + 0.002), (-0.015, y - 0.004), (0.0, y + 0.006),
                  (0.015, y - 0.004), (0.03, y + 0.002), (0.046, y - 0.012)], 0.011)
    else:
        # Boca abierta al revés, como un llanto.
        forma = bezier((-0.04, y - 0.018), (0.0, y + 0.05), (0.04, y - 0.018)) \
            + bezier((0.04, y - 0.018), (0.0, y - 0.03), (-0.04, y - 0.018))[1:-1]
        capa = Capa()
        capa.relleno(forma, BOCA)
        capa.elipse(0.0, y - 0.026, 0.024, 0.014, LENGUA)
        capa.recortar(forma)
        lz.pegar(capa)
        lz.trazo(forma + [forma[0]], 0.011)


# --------------------------------------------------------------- extras

def cachetes(lz, alfa, sep):
    if alfa <= 0.0:
        return
    capa = Capa()
    for lado in (-1, 1):
        capa.elipse(lado * (sep + 0.115), 1.365, 0.062, 0.036, CACHETE + (round(255 * alfa),))
    lz.pegar(capa)


def extras(lz, cara, gesto):
    sep = cara["sep"]
    for e in cara["extras"]:
        if e == "pecas" or e == "pecas_pocas":
            puntos = [(0.0, 0.0), (0.03, 0.012), (0.018, -0.02), (0.05, -0.008), (-0.012, -0.03)]
            if e == "pecas_pocas":
                puntos = puntos[:3]
            for lado in (-1, 1):
                for (dx, dy) in puntos:
                    lz.elipse(lado * (sep + 0.085 + dx), 1.365 + dy, 0.0075, 0.0075, PECA)
        elif e == "lunar_boca":
            lz.elipse(0.078, BOCA_Y - 0.03, 0.009, 0.009, LINEA)
        elif e == "lunar_ojo":
            lz.elipse(-(sep + 0.06), OJO_Y - 0.095, 0.0085, 0.0085, LINEA)
        elif e == "cicatriz":
            # Cruza la ceja derecha del que mira.
            a, b = (sep - 0.03, CEJA_Y + 0.03), (sep + 0.02, OJO_Y + 0.03)
            lz.trazo([a, b], 0.011, CICATRIZ)
            for t in (0.3, 0.7):
                x, y = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
                lz.trazo([(x - 0.012, y - 0.008), (x + 0.012, y + 0.008)], 0.006, CICATRIZ)
        elif e == "ojeras":
            for lado in (-1, 1):
                lz.curva((lado * sep - 0.05, OJO_Y - 0.08), (lado * sep, OJO_Y - 0.11),
                         (lado * sep + 0.05, OJO_Y - 0.08), 0.009, OJERA)
        elif e == "arrugas":
            for lado in (-1, 1):
                x = lado * (sep + 0.09)
                lz.trazo([(x, OJO_Y + 0.012), (x + lado * 0.022, OJO_Y + 0.022)], 0.006)
                lz.trazo([(x, OJO_Y - 0.008), (x + lado * 0.024, OJO_Y - 0.014)], 0.006)
        elif e == "hoyuelo":
            # El mentón partido del veterano (una barba de piel se veía como mancha).
            lz.curva((-0.014, 1.232), (0.0, 1.222), (0.014, 1.232), 0.008)
        elif e == "nariz":
            lz.curva((-0.012, 1.425), (0.0, 1.41), (0.014, 1.428), 0.009)
        elif e == "curita_nariz":
            capa = Capa()
            capa.relleno([(-0.07, 1.445), (0.07, 1.425), (0.072, 1.395), (-0.068, 1.415)], CURITA)
            lz.pegar(capa)
            lz.trazo([(-0.07, 1.445), (0.07, 1.425), (0.072, 1.395), (-0.068, 1.415), (-0.07, 1.445)], 0.007)
            for dx in (-0.012, 0.012):
                lz.elipse(dx, 1.42 - dx * 0.14, 0.005, 0.005, CURITA_PUNTO)
        elif e == "curita_cachete":
            x, y = sep + 0.12, 1.35
            forma = [(x - 0.05, y - 0.01), (x + 0.04, y + 0.03), (x + 0.052, y + 0.006), (x - 0.038, y - 0.034)]
            lz.relleno(forma, CURITA)
            lz.trazo(forma + [forma[0]], 0.007)
            lz.elipse(x, y - 0.002, 0.005, 0.005, CURITA_PUNTO)
        elif e == "sudor":
            if gesto != "dolor":
                gota(lz, -(sep + 0.15), 1.56, 0.9)
        else:
            raise ValueError(e)


def gota(lz, x, y, escala=1.0, color=LAGRIMA):
    r = 0.018 * escala
    forma = [(x, y + r * 2.4)] + bezier((x + r, y + r * 0.6), (x + r * 1.1, y - r * 1.1), (x, y - r))[:] \
        + bezier((x, y - r), (x - r * 1.1, y - r * 1.1), (x - r, y + r * 0.6))[1:]
    lz.relleno(forma, color)
    lz.trazo(forma + [forma[0]], 0.006)
    lz.elipse(x - r * 0.3, y, r * 0.25, r * 0.35, BRILLO)


# ---------------------------------------------------------------- caras

def dibujar(i, gesto):
    cara = CARAS[i]
    lz = Capa()
    sep = cara["sep"]
    rubor = cara["cachete"]
    if gesto == "feliz":
        rubor = min(max(rubor + 0.15, 0.3), 0.55)
    elif gesto in ("dolor", "triste"):
        rubor *= 0.5
    cachetes(lz, rubor, sep)
    extras(lz, cara, gesto)
    for indice, lado in enumerate((-1, 1)):
        cx = lado * sep
        capa = Capa()
        ceja(capa, cara, cx, lado, gesto, indice)
        lz.pegar(capa.escalar(cx, CEJA_Y, ESCALA_CEJAS))
        capa = Capa()
        if gesto in ("normal", "triste"):
            ojo_abierto(capa, cara, cx, OJO_Y, lado, gesto)
        elif gesto == "feliz":
            ojo_feliz(capa, cara, cx, OJO_Y, lado)
        elif gesto == "dolor":
            ojo_dolor(capa, cara, cx, OJO_Y, lado)
        else:
            ojo_cerrado(capa, cara, cx, OJO_Y, lado)
        lz.pegar(capa.escalar(cx, OJO_Y, ESCALA_OJOS))
    capa = Capa()
    if gesto in ("normal", "parpadeo"):
        boca_normal(capa, cara)
    elif gesto == "feliz":
        boca_feliz(capa, cara)
    elif gesto == "dolor":
        boca_dolor(capa, cara, i)
    else:
        boca_triste(capa, cara)
    lz.pegar(capa.escalar(0.0, BOCA_Y, ESCALA_BOCA))
    if gesto == "dolor":
        gota(lz, sep + 0.15, 1.58, 1.1)
    elif gesto == "triste" and cara.get("lagrima", True):
        gota(lz, sep + 0.03, OJO_Y - 0.11, 1.0)
    return lz.celda()


def calibracion():
    """Grilla cada 5 cm (cada 10 cm más gruesa) con el centro marcado."""
    lz = Capa()
    x = X0
    while x <= X1 + 1e-6:
        gruesa = abs(round(x * 100) % 10) == 0
        lz.trazo([(x, Y0), (x, Y1)], 0.006 if gruesa else 0.003, (0, 0, 200, 255))
        x += 0.05
    y = Y0
    while y <= Y1 + 1e-6:
        gruesa = abs(round(y * 100) % 10) == 0
        lz.trazo([(X0, y), (X1, y)], 0.006 if gruesa else 0.003, (200, 0, 0, 255))
        y += 0.05
    lz.elipse(0.0, 1.5, 0.015, 0.015, (0, 160, 0, 255))
    lz.elipse(-0.2, 1.5, 0.012, 0.012, (0, 160, 0, 255))
    lz.elipse(0.2, 1.3, 0.012, 0.012, (0, 160, 0, 255))
    return lz.celda()


def muestra(atlas, ruta):
    """Hoja para revisar a ojo: cada celda sobre el color de la piel."""
    piel = (0xf7, 0xc9, 0xa2, 255)
    esc = 1
    hoja = Image.new("RGBA", (atlas.width * esc + 90, atlas.height * esc), piel)
    fondo = Image.new("RGBA", atlas.size, piel)
    fondo.alpha_composite(atlas)
    hoja.paste(fondo, (90, 0))
    d = ImageDraw.Draw(hoja)
    for f, cara in enumerate(CARAS):
        d.text((4, f * ALTO_CELDA + ALTO_CELDA // 2), "%d %s" % (f, cara["nombre"]), fill=(0, 0, 0, 255))
        d.line((0, f * ALTO_CELDA, hoja.width, f * ALTO_CELDA), fill=(200, 160, 130, 255))
    hoja.save(ruta)


def main():
    args = sys.argv[1:]
    salida = "assets/3d/caras.png"
    atlas = Image.new("RGBA", (ANCHO_CELDA * len(GESTOS), ALTO_CELDA * len(CARAS)), (0, 0, 0, 0))
    if "--calibracion" in args:
        celda = calibracion()
        for f in range(len(CARAS)):
            for c in range(len(GESTOS)):
                atlas.paste(celda, (c * ANCHO_CELDA, f * ALTO_CELDA))
    else:
        for f in range(len(CARAS)):
            for c, gesto in enumerate(GESTOS):
                atlas.paste(dibujar(f, gesto), (c * ANCHO_CELDA, f * ALTO_CELDA))
    atlas.save(salida)
    if "--muestra" in args:
        muestra(atlas, args[args.index("--muestra") + 1])


if __name__ == "__main__":
    main()
