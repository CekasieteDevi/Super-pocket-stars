# Peinados y tribunas

Once peinados: puntas, afro, rapado, atado, mohicano, rastas, degrade alto,
vincha con pelo largo, rodete, raya al costado y trenzas pegadas al cuero cabelludo.
La ultima ampliacion agrega cinco peinados (320 cuadros base), tres secuencias
propias para los once estilos y dos secuencias del arquero. Total: 924 cuadros,
84 por estilo.
Asignacion estable por ID, dorsales y recoloreado.

Fuentes: `jugadores_mohicano.png` y `jugadores_rastas.png`.
Las cinco fuentes nuevas son `jugadores_{degrade,vincha,rodete,raya,trenzas}.png`.
Consumo: once hojas `preparados/{peinado}.png`, 512 x 704 RGBA, celdas de 64 px.
Indices 76 a 79: arquero ataja y asegura la pelota. Indices 80 a 83: saque de
arco, con armado, impacto y seguimiento.
Preparacion reproducible: `tools/preparar_atlas_partido.gd`.
Vista comparativa: `vista_previa_peinados.png`; cada fila es un peinado.
`vista_previa_acciones.png`: cuatro fases de volea, control con el pie y taco,
en ese orden. Filas con el mismo orden de peinados.

## Animaciones

- Volea: indices 64-67; armado, impacto horizontal, seguimiento y recuperacion.
  Sustituye el clip que reutilizaba cuadros de cabezazo y volea.
- Control con el pie: 68-71; elevar, amortiguar, bajar y apoyar. Se emite para
  recepciones de vuelo bajo (altura maxima entre 0,35 y 1,4 m), sin remate ni
  arquero. Las recepciones altas mantienen el pecho. La pelota sigue el pie
  mientras el receptor conserva la posesion; despues se libera el anclaje.
- Taco: 72-75; preparacion, flexion, contacto posterior y recuperacion. Se
  elige para pases de campo de hasta 8 m hacia atras respecto al cuerpo;
  no para pelotazos. Conserva la orientacion corporal al reproducir.
- Arquero agarra: 76-79; manos hacia la pelota, cierre, control y posesion.
  La pelota real se ancla a las manos y evita dibujarse dos veces en los cuadros
  finales.
- Saque de arco: 80-83; apoyo, armado, contacto y seguimiento. El motor lo
  emite cuando el arquero despeja.

Las condiciones solo emiten datos visuales. No cambian duelos, trayectorias,
atributos ni estado del RNG. Las texturas se preparan antes del partido.

Fuentes de movimientos: `acciones_{volea,control_pie,taco}.png` contienen
cuatro columnas y diez filas; `acciones_trenzas.png` contiene las tres
secuencias del ultimo peinado. `acciones_arquero_{agarra,saque_arco}.png`
son tiras RGBA de cuatro cuadros. La preparacion detecta bandas de filas,
convierte RGB a RGBA si hace falta y elimina el fondo exterior. Usa una
escala comun dentro de cada secuencia para conservar flexiones y apoyos.

## Prompts de la ampliacion (imagegen integrado)

Referencia de estilo y poses: `preparados/puntas.png`, primeros 64 cuadros.
Para cada peinado: editar SOLO el cabello en los 64 personajes, mantener
grilla 8 x 8, poses, caras, uniforme azul, shorts blancos, contornos negros,
escala y apoyo. Cabello marron, pixel art, fondo RGBA transparente, sin
pelota, sombras, texto ni grilla. Variantes pedidas, una llamada por variante:

1. High flat-top curly fade, tall flat-topped curls and closely shaved sides.
2. Straight loose shoulder-length hair, clearly visible white headband.
3. Slicked-back hair, round high topknot/man bun, shaved temples, no ponytail.
4. Neat low side part, smooth sideways comb-over, short tapered sides.
5. Tight cornrow braids, visible scalp lines, two short braids at the nape.

Para movimientos: referencia SOLO de estilo, cuatro fases por fila, peinados
en el orden del atlas, mismos uniformes y proporciones, margenes entre celdas,
sin pelota dibujada, fondo RGBA transparente. Una llamada por movimiento:

1. Side volley: plant left foot and wind up right leg; extend right boot at
   waist height toward screen right; follow through; lower leg and recover.
2. Foot trap: lift right knee; cup instep to cushion descending ball; gently
   lower receiving foot; grounded ready stance, supporting left foot planted.
3. Backheel: face right and lean forward; bend right knee swinging heel left;
   extend heel behind at shin height; recover. Backward pass, not forward kick.

La hoja de volea se pidio con once filas pero devolvio diez. Se completo el
peinado trenzas con otra llamada: grilla 4 x 3 con volea, control y taco,
las mismas cuatro fases y trenzas marrones pegadas al cuero cabelludo.

Generados con herramienta integrada imagegen, tomando `preparados/puntas.png`
como referencia. Prompts: editar solamente el cabello de los 64 jugadores a
mohicano marron con laterales rapados / rastas marrones hasta el cuello;
preservar poses, caras, uniforme azul, shorts blancos, contornos, ocho filas
y ocho columnas, fondo RGBA transparente, sin texto ni grilla. Normalizacion
offline por celda, componente principal, escala y apoyo del original.

Publico procedural: cuatro siluetas (sentado, brazos elevados, bufanda,
camiseta rayada), cabello, tonos de piel, asientos y escalones. Escaleras
y barandas proyectadas separan sectores de tribuna principal y cabeceras.
La textura conserva semilla fija y cache; no usa el RNG de simulacion.

Verificacion: `test_atlas_jugadores.gd`, `test_reproduccion_atlas.gd`,
`test_animaciones_pie.gd`, `test_pecho_lateral.gd` y `_diag_variedad_visual.gd`.
Este ultimo regenera las vistas previas.
