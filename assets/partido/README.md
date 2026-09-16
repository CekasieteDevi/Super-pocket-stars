# Sprites del partido

Estado actual: once peinados y 836 cuadros, con volea, control con el pie y
taco propios. Fuentes, indices, prompts y pruebas en [VARIEDAD.md](VARIEDAD.md).
Las secciones siguientes conservan el historial de las primeras cuatro hojas.

`jugadores.png`: hoja RGBA de 48 cuadros adaptada de las tres referencias de
`inspiracion artistica`. Preparada con la herramienta integrada imagegen.
`vista_previa.png`: contacto de los cuadros consumidos por el juego sobre césped.

Prompts utilizados:

1. Crear una hoja de ocho columnas y seis filas siguiendo las proporciones,
   pelo, uniforme y contornos de las referencias. Sin pelota, números, suelo
   ni sombras. Filas: ocho carreras, ocho remates, ocho carreras de espalda;
   quieto/frente/espalda/barrida/bloqueo/caída/suelo/recuperación;
   cabezazo/volea/chilena; arquero y festejos. Fondo transparente.
2. Quitar únicamente el damero gris y blanco del primer resultado, conservando
   personajes, posiciones y colores; entregar transparencia alfa real.

La herramienta offline recorta según límites medidos y normaliza escala y pivote a
64 px. `AtlasJugadores` recolorea uniformes y pelo. Los dorsales se estampan después
del espejo. Los originales permanecen intactos en la carpeta de inspiración.

Carrera por distancia recorrida; acciones por tiempo interpolado desde el evento.
Las vistas laterales se espejan. La espalda tiene una secuencia propia;
no hay ocho vistas únicas de cada acción.
Las acciones especiales tienen entre tres y seis pasos, con cuadros sostenidos.

Validación: `tests/test_atlas_jugadores.gd` y `tests/test_reproduccion_atlas.gd`.
Regenerar vista previa: `tests/_diag_atlas_artistico.gd`.

## Recepciones, laterales y peinados

Cuatro siluetas estables por jugador: puntas, afro, rapado y pelo atado. Cada una
tiene sus 48 cuadros de partido y 16 cuadros nuevos (ocho de pecho y ocho de lateral):
256 cuadros en total. `jugadores_{afro,rapado,atado}.png` y
`recepcion_lateral{,_afro,_rapado,_atado}.png` son las hojas adicionales.

Generadas con imagegen integrado. Prompts adicionales: preservar poses, celdas,
uniforme y proporciones de la hoja base cambiando sólo el pelo a afro marrón,
rapado marrón o cola de caballo marrón; para recepción/lateral, ocho fases de
amortiguar con el pecho y ocho de lanzamiento con ambas manos sobre la cabeza,
sin pelota dibujada. Variantes con idénticas poses y fondo magenta para croma.
La preparación offline convierte RGB a RGBA, separa fondo exterior, elimina
croma y conserva el componente principal. El juego carga los cuadros ya listos.

El lateral reutiliza el tiempo de preparación del reinicio: pelota en manos,
lanzamiento y trayectoria desde dos metros. El pecho se emite al controlar un
balón alto; remates y cabezazos tienen prioridad. Se limpia la altura tras recibir
para que un pase raso posterior no herede la parábola del balón anterior.

Canchas: paletas cálidas, briznas en grupos de píxeles, borde de césped,
carteles, banderines y arcos con contorno. Pelota procedural de 16 px, doce fases
de giro, paneles oscuros y luz en cuatro tonos, renderizada separada del jugador.

Prueba adicional: `tests/test_pecho_lateral.gd`.

## Rendimiento

`preparados/{puntas,afro,rapado,atado}.png` contiene cuatro atlas RGBA de
512 × 704. Regenerar al modificar fuentes:

```
godot --headless --path . --script tools/preparar_atlas_partido.gd
godot --headless --path . --editor --quit
```

Mantener `process/fix_alpha_border=false` en sus archivos `.import` para
conservar exactamente los píxeles del compositor original. Las fuentes grandes
se usan únicamente en la herramienta, no durante un partido.

Antes de reproducir se preparan sólo las apariencias y acciones presentes en la
grabación, incluidos suplentes, dorsales y ambos espejos. La caché expulsa la
textura menos recientemente usada en lugar de vaciarse entera. El desgaste del
césped usa una malla estática por calidad de cancha y una sola orden de dibujo.

Medición local headless de 256 cuadros: preparación en frío de 7465 a 67 ms;
p95 por textura de 61.62 a 0.22 ms. No es una medición de FPS de la GPU.
En una reproducción completa de 999 fotogramas: preparación inicial 333 ms,
1572 texturas y ninguna textura nueva durante el partido.

`tests/_diag_rendimiento_atlas.gd` compara los 256 hashes RGBA con la referencia
anterior a la optimización. `tests/test_reproduccion_atlas.gd` comprueba que no
se creen texturas al reproducir; `tests/test_desgaste_cache.gd` verifica la
geometría y reutilización de las tres canchas.
