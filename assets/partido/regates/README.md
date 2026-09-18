# Regates: sprites integrados en el partido

Cinco hojas fuente: `ruleta.png`, `bicicleta.png`, `croqueta.png`, `elastica.png`
y `globito.png`. Croqueta, bicicleta, globito y ruleta tienen doce cuadros en
4x3. Elastica tiene seis cuadros en 3x2. Los cuadros van en orden de
lectura. La cantidad de cada hoja esta en `SpritesPartido.CUADROS_REGATE`.

Jugador base con pelo en puntas. Pelota separada, igual que en el partido.
El jugador base se
tine al color del equipo al cargarlo; la pelota se renderiza separada y sigue
una trayectoria especifica por tecnica.

Las celdas son de 64 px. Conservan el contorno, escala, paleta y
transparencia del atlas `assets/partido/preparados/puntas.png`.

## Fases dibujadas

- `croqueta`: apoyo, transferencia lateral de un pie al otro, cuerpo cubriendo
  la pelota y salida lateral.
- `bicicleta`: dos cuadros de carrera, dos amagues sobre la pelota y tres
  cuadros de salida con el exterior. La hoja se arma con celdas del atlas
  `preparados/puntas.png`: 0, 2, 12, 13, 14, 15, 13, 14, 15, 4, 6 y 0.
  Todas son de perfil y de la misma escala. La hoja anterior mezclaba
  poses de frente y de perfil, y el jugador giraba a cada cuadro.
- `globito`: cuatro cuadros de carrera, la punta debajo de la pelota, el
  levantamiento y cinco cuadros de carrera para buscarla. Celdas de
  `preparados/puntas.png`: 0, 2, 4, 12, 13, 14, 15, 1, 3, 5, 7 y 1. La
  hoja anterior tenia un solo cuadro dibujado.
- `elastica`: exterior hacia fuera y retorno inmediato con el interior del
  mismo pie.
- `ruleta`: dos cuadros de entrada, giro completo (perfil, espaldas, el otro
  perfil, frente, tres cuartos) y salida. Celdas de `preparados/puntas.png`:
  0, 2, 12, 16, 25, 12 espejado, 0 espejado, 24, 32, 12, 4 y 6. La hoja
  anterior miraba siempre para el mismo lado.

La pelota no esta pintada dentro de estas hojas: la vista la mueve durante la
secuencia para que siga cada contacto.
