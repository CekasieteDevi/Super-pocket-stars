# Notas de desarrollo

## Sprites de palomita

- `assets/partido/palomita_frames.png` es independiente. No mezclarlo con `jugadores.png`.
- No cambiar `AtlasJugadores.TOTAL_CUADROS` para agregar la palomita.
- Las cuatro poses usan celdas de 64 x 64 y una escala común.
- No escalar cada pose por separado. La animación crece o encoge entre cuadros.
- Regenerar con `tools/preparar_palomita_frames.ps1`.
- El script separa poses por alfa, centra cada pose y mantiene el pivote inferior.
- `sprites_partido.gd` recolorea solo azul fuerte y blanco.
- El negro es contorno. Debe quedar intacto.
- `color_short` transparente usa `SpritesPartido.SHORT`.
- Después de modificar PNG, reimportar con Godot headless para evitar caché vieja.
