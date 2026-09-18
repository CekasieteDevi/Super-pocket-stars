# Regates: sprites integrados en el partido

Cinco hojas fuente: `ruleta.png`, `bicicleta.png`, `croqueta.png`, `elastica.png`
y `globito.png`. Las hojas historicas tienen seis fases, tres columnas y dos filas; croqueta tiene doce fases, cuatro columnas y tres filas, en
orden de lectura.

Jugador base con pelo en puntas. Pelota separada, igual que en el partido.
Cada hoja se reproduce como una animacion de seis cuadros, salvo croqueta que usa doce. El jugador base se
tine al color del equipo al cargarlo; la pelota se renderiza separada y sigue
una trayectoria especifica por tecnica.

Las hojas historicas son de 3x2 celdas de 64 px; croqueta es de 4x3. Conservan el contorno, escala, paleta y
transparencia del atlas `assets/partido/preparados/puntas.png`.

## Fases dibujadas

- `croqueta`: apoyo, transferencia lateral de un pie al otro, cuerpo cubriendo
  la pelota y salida lateral.
- `bicicleta`: amague alternado alrededor de la pelota, ultimo apoyo y salida
  con el exterior.
- `globito`: punta bajo la pelota, elevacion sobre el rival, giro y carrera
  para recuperar.
- `elastica`: exterior hacia fuera y retorno inmediato con el interior del
  mismo pie.
- `ruleta`: pisada, arrastre, giro de 360 grados, cambio de pie y escape.

La pelota no esta pintada dentro de estas hojas: la vista la mueve durante la
secuencia para que siga cada contacto.
