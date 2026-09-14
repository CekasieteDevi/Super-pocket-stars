# Regates: sprites para futura integracion

Cuatro hojas fuente: `ruleta.png`, `bicicleta.png`, `croqueta.png` y `elastica.png`.
Cada hoja solicita seis fases, tres columnas y dos filas, en orden de lectura.
Jugador base con pelo en puntas. Pelota separada, igual que en el partido.
Recursos visuales de preparacion; aun no conectados a eventos ni al atlas del juego.
Antes de integrarlos: normalizar a celdas de 64 px, fijar pivotes y sincronizar
la trayectoria de la pelota con los contactos de cada pie.

## Generacion

Revision de fondo: eliminar el damero o fondo negro y el halo exterior,
conservar exactamente las seis poses y el uniforme, entregar PNG con alfa real.
Validar el canal alfa del archivo; un damero dibujado no es transparencia.

Herramienta: imagegen integrado. Referencia de estilo: `../acciones_control_pie.png`.
Prompt comun:

Create a production soccer pixel-art sprite sheet for Super Pocket Stars. Reference image is STYLE ONLY: match chibi body proportions, brown spiky hair, blue shirt, white shorts, blue socks, black boots, bold dark outlines. Only ONE player style, spiky hair. Transparent RGBA background, no checkerboard, no text, no grid, no shadows, NO BALL (game renders ball separately). Exactly 6 sequential animation frames arranged in 3 columns and 2 rows, read left to right top to bottom. Identical evenly sized cells, consistent character scale, generous clear margins, full body uncut in every cell. Fixed camera three-quarter side, heading screen right, body may turn as specified. Crisp pixel art matching reference. Distinct readable footwork and arm balance in all 6 frames. Animation: 

### ruleta

Approach facing right; plant right sole on imaginary ball; drag backward turning torso away; back fully facing viewer while transferring to left sole; continue full 360 degree pivot dragging forward with left sole; exit facing right.

### bicicleta

Approach facing right; swing right foot outward across front of imaginary stationary ball without touching; plant right foot outside; swing left foot across ball without touching; plant left foot and push ball right with outside of right foot; accelerate right.

### croqueta

Run diagonally right; left support and inside of right foot touches imaginary ball; right foot pushes ball laterally toward left foot; weight shifts while left inner foot receives; left inner foot pushes forward past opponent; running exit right. No spinning or stepover.

### elastica

Approach right with ball close to right foot; right outside edge pushes imaginary ball outward; same right foot extends outward offering ball; right ankle wraps sharply around ball; same foot inside edge snaps ball inward in opposite direction; explosive exit. Both touches same foot.
