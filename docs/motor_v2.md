# Motor V2 — plan de diseño

2026-09-29. Copia del documento vivo: https://claude.ai/code/artifact/3967a649-0fc0-482b-9580-e520246384d0
(si difieren, manda el documento vivo).

El Motor V2 es un partido que se simula directamente en 3D y en tiempo real: la física de la pelota, el movimiento de los cuerpos y la duración de cada gesto SON la simulación, y la vista solo dibuja. Reemplaza al par actual `motor_espacial.gd` (2D, un tick cada 0,25 s) + `vista_cancha_3d.gd` (capa que interpreta ese guion y lo remienda), y apunta a la fluidez de un CPU vs CPU de FIFA 10 o PES 2009 en un Android de gama media.

## Resumen

**Por qué.** Hoy la animación lee un guion escrito 4 veces por segundo en un plano sin altura. Cada vez que el guion y el cuerpo no coinciden, el 3D tiene que mentir: pases que aceleran o frenan para que el receptor llegue, frames que faltan en un tiro al palo, una pelota que muere tras un pique, centros a un compañero que todavía no está mientras los rivales esperan quietos. Son síntomas de la arquitectura, no bugs sueltos: arreglarlos uno por uno (3D-01 a 3D-10) no cierra la clase.

**Qué cambia.** Tres relojes en vez de uno: la física corre a 60 Hz, el cuerpo avanza con las restricciones de su animación, y la cabeza (la utility AI que ya existe) decide cada 0,1–0,2 s. Una acción no "pasa" en un tick: tiene preparación, frame de contacto y recuperación, y la pelota sale recién en el contacto. Un pase apunta al punto donde el receptor puede llegar a tiempo, así que su velocidad nunca se corrige.

**En qué se escribe.** Todo el motor va en C++ como GDExtension (una biblioteca nativa que Godot carga): mundo, cuerpo, cerebro, reglas y registro. GDScript queda solo para la vista, el HUD, los menús y los bancos de prueba, que leen el estado del motor. Lo decidió la etapa 0: en el teléfono, el mundo solo en GDScript tardaba 25 s por partido y en C++ 1,5 s. Las reglas para escribir ese C++ están en "Cómo se escribe el C++".

**Qué no cambia.** `match_engine.gd` sigue simulando los partidos de las otras divisiones. Atributos, tácticas, estilos, pesos de utility, relatos, estadísticas, modelos y animaciones de Blender se reusan. El modo 2D se abandona.

**Definición de hecho del Motor V2** (no de este documento):

- Un partido de 90 minutos CPU vs CPU sin ninguna corrección de velocidad de pelota, sin teletransportes de jugador (> 0,5 m entre frames) y sin pelota que desaparece.
- La pelota rebota, pica, rueda y pega en los palos con física propia, sin casos especiales en la vista.
- Goles, tiros, posesión, pases y faltas por partido dentro de rangos reales de la liga que se simula.
- 60 fps de dibujo y ≤ 4 ms de simulación por frame en un Android de gama media (referencia: ZTE Z2357N con Unisoc T760 — 4 A76 a 2,2 GHz + 4 A55, Mali-G57, 3,5 GB, 720 × 1612, Android 13 —, un escalón por debajo de un Snapdragon 7-series o equivalente).
- "Simular temporada" sin mirar corre el mismo motor, sin dibujar, en menos de 3 s por partido en ese teléfono.
- Misma semilla = mismo partido, en PC y en Android.

## Cómo lo resuelven FIFA y PES

Los dos resuelven la fluidez igual: la animación no interpreta un resultado ya decidido, sino que la decisión, el cuerpo y la pelota avanzan juntos frame a frame y se corrigen entre sí. Lo público de cada generación:

| Juego | Qué introdujo | Qué tomamos |
| --- | --- | --- |
| [FIFA 10](https://www.gamesradar.com/e3-09-everything-you-need-to-know-about-fifa-10/) (2009) | Gambeta en 360° en vez de 8 direcciones; *animation warping*: estirar y torcer una animación capturada en tiempo real para que el pie llegue a la pelota; "collision sharing" en la pelea por la pelota | Warping de pie/mano al punto de contacto, en vez de mover la pelota hacia el pie |
| [PES 2009](https://en.wikipedia.org/wiki/Pro_Evolution_Soccer_2009) (2008) | Teamvision: táctica que cambia según la situación y movimiento sin pelota hacia espacios; resistencia del aire en la trayectoria; fricción según el estado del césped | Juego sin pelota por puntaje de espacios; pelota con arrastre y rozamiento propios |
| [FIFA 12](https://news.ea.com/press-releases/press-releases-details/2011/EA-Sports-Revolutionizes-FIFA-Soccer-12-with-New-Player-Impact-Engine/default.aspx) (2011) | Player Impact Engine: choques calculados con masa, velocidad y ángulo en cada punto de contacto, en vez de animaciones de choque prearmadas | Choques simples por cápsulas con masa; nada de ragdoll (muy caro en Android) |
| [FIFA 22](https://gdcvault.com/play/1027746/Animation-Summit-FIFA-22-s) (2021) | HyperMotion: captura de un 11 vs 11 completo y *motion matching*: en cada frame se busca en una base de poses la que mejor sigue la trayectoria deseada | Fuera de alcance (necesita mocap masivo); sí tomamos la idea de elegir clip según trayectoria |

**La IA de decisión** es la parte menos distinta a lo que ya tenemos. La referencia abierta más usada es Simple Soccer, del libro de Mat Buckland ([código](https://github.com/wangchen/Programming-Game-AI-by-Example-src/blob/master/Buckland_Chapter4-SimpleSoccer/SoccerTeam.cpp)). Tres ideas de ahí faltan hoy en nuestro motor:

1. **Pase seguro por tiempos:** se proyecta a cada rival sobre la línea del pase; si con su velocidad máxima llega a esa línea antes que la pelota, el pase no es seguro.
2. **Pase al espacio por tangentes:** el pase no va al receptor sino a uno de tres puntos, su posición o las dos tangentes al círculo que puede cubrir mientras viaja la pelota. Así el pase se adelanta al receptor sin corregir la velocidad.
3. **Punto de apoyo:** una grilla de puntos en campo rival puntuados por "se le puede pasar desde la pelota", "se puede tirar desde ahí" y "distancia justa al poseedor"; el mejor apoyo corre al mejor punto.

**La pelota** en los dos juegos es un cuerpo físico con gravedad, arrastre del aire, efecto Magnus (la comba) y pique con pérdida parcial de energía. Valores de partida, aproximados de la literatura de balística de pelota ([análisis de trayectorias](https://www.researchgate.net/publication/228375759_Soccer_ball_lift_coefficients_via_trajectory_analysis)): 0,43 kg, radio 0,11 m, coeficiente de arrastre cerca de 0,25 a velocidad de tiro y más alto a baja velocidad, coeficiente de sustentación proporcional al giro. Se calibran a ojo contra video, no se copian.

**En Godot 4** hay piezas listas: `AnimationTree` con root motion, y un plugin de motion matching en C++ ([godot-motion-matching](https://github.com/GuilhermeGSousa/godot-motion-matching), Godot 4.4, MIT). El plugin no declara soporte Android, así que el plan no depende de él.

## Diagnóstico del motor actual

La causa raíz es una sola: **el motor adjudica el resultado primero y después mueve la pelota para que coincida**. `_dirigir_pelota_a` (`core/motor_espacial.gd:6998`) lo dice en su comentario: le manda la pelota "a quien el motor YA decidió que se la queda". Lo mismo pasa con los remates: `modelo_destino_remate` (línea 5122) sortea portería, palo o afuera antes de que la pelota salga. La física no decide nada; solo tapa el hueco entre dos decisiones.

A eso se suman tres limitaciones de forma:

- **Un tick cada 0,25 s** (`TICK_SEG`, línea 30): un remate a 30 m/s recorre 7,5 m entre dos fotos.
- **Plano 2D con una altura dibujada**: la pelota tiene `pos` 2D, `z` y `altura_max` para una parábola, pero no velocidad vertical, ni giro, ni pique. Al ganarla alguien, `_dirigir_pelota_a` le pone altura 0 y la hace rodar.
- **Sin duración de gestos**: patear, controlar o cabecear pasan dentro de un tick. El cuerpo no tiene preparación ni recuperación que respetar.

El 3D hoy son unas 4.200 líneas en `vista_cancha_3d.gd`, y buena parte son reescrituras del guion para que no se note. Cada síntoma tiene su causa y su parche:

| Síntoma visible | Causa en el motor | Parche actual del 3D |
| --- | --- | --- |
| Pase que acelera o frena según llegue el receptor | El receptor ya está elegido; la pelota se redirige a él cada tick | `_tiempo_del_centro` adelanta el recorrido del receptor; la pelota se desvía a 16 m/s como máximo |
| Tiro al palo sin frames | El remate va al palo por el piso hasta la línea y queda quieto | `_preparar_palos` inventa el choque y la salida (3D-03) |
| Pelota muerta tras un pique | `FRENADO_PELOTA_SUELTA` la frena 0,35 por tick al caer | `_preparar_piques` redibuja el vuelo con piques (3D-10) |
| Centro a un compañero que no está; rivales quietos | El centro cae, rueda hasta el ya elegido y recién ahí hay control; nadie más puede disputarla | `_preparar_centros` lo cambia por pecho en el aire (3D-09) |
| Rival que "gana un duelo" sin haber llegado | El duelo se resuelve por distancia en un tick, no por contacto | Arreglado en el motor para ese caso (3D-02) |
| Tiro bloqueado raro | Remate y bloqueo en el mismo tick, defensor pegado | `_bloqueos` arma la jugada al revés (Tiro bloqueado, LEEME) |
| Receptor que frena en seco y tarda 1 s | El control es un estado del tick | `_recepciones` promedia ±1,8 tick |

Cada parche arregla una clase de jugada y deja las demás. Mientras el motor adjudique y la vista interprete, cada jugada nueva ("más jugadas", pendiente en `BUGS_1.1.00.md`) va a traer su propio parche.

## Arquitectura del Motor V2

La regla que ordena todo: **nadie adjudica un resultado; se sortea la ejecución y el resultado sale del mundo**. El que patea elige un pase, al patear se le suma un error según atributos y presión, y quién se queda la pelota lo decide la física: el primer cuerpo que llega a tocarla.

```
 Cerebro · 10 Hz ──intenciones──▶ Cuerpo · 60 Hz ──toques en la ventana de contacto──▶ Mundo · 60 Hz
    ▲                                                                                  │  │
    └──────────────────────────────── lee el mundo ◀───────────────────────────────────┘  │
                                                                                          ├─eventos─▶ Reglas ─▶ Registro
                                                                                          └─estado──▶ Vista (cada frame)
```

El cerebro pide, el cuerpo ejecuta y el mundo decide quién toca la pelota; reglas, registro y vista solo leen lo que pasó.

**Seis capas, cada una con su reloj:**

1. **Mundo (60 Hz fijo).** Integrador propio, no el servidor de física de Godot (no es determinista entre plataformas). Pelota con posición y velocidad 3D, giro, gravedad, arrastre, Magnus, pique con restitución y rozamiento, palos como cilindros, travesaño, red y líneas. Jugadores como cápsulas cinemáticas con masa para empujes. Un paso = 1/60 s; la pelota rápida hace subpasos para no atravesar un pie.
2. **Cuerpo (60 Hz, con el mundo).** Locomoción con aceleración, frenada y giro máximo según velocidad y atributos (lo que hoy es `_mover_hacia`). Cada gesto es una acción con fases: preparación → ventana de contacto → recuperación. Las duraciones salen de los clips de Blender, no de constantes a mano.
3. **Cerebro (10 Hz, escalonado).** La utility AI actual: cada jugador piensa en su turno (22 jugadores repartidos en 6 frames), el poseedor además cuando su acción queda libre. Elige intenciones ("pase a 7 al punto P", "desmarque a Q", "presionar a 9"), nunca resultados.
4. **Reglas (eventos del mundo).** Pelota que cruza una línea, contacto de cápsulas en una entrada, posición adelantada tomada en el frame del contacto del pase. Reusan `arbitro.gd`, tarjetas, cambios y lesiones.
5. **Registro.** Eventos para estadísticas y relato (el formato actual de `eventos`), más una grabación compacta a 10 Hz para repeticiones. Ya no hay "fotogramas" que interpretar.
6. **Vista (frecuencia de pantalla).** Dibuja interpolando entre los dos últimos pasos del mundo. Reproduce la acción y la fase que el cuerpo dice; la velocidad de las piernas sigue a la velocidad real. Solo puede tocar huesos (llevar el pie a la pelota en los últimos 0,15 s): **nunca mueve la pelota ni a un jugador**.

**Cómo se resuelven las jugadas que hoy se parchean:**

- **Pase:** el cerebro calcula el punto de encuentro (tangentes de Simple Soccer + tiempos de llegada de cada rival). El pie le da a la pelota una velocidad fija más el error. El receptor corre a ese punto; si un rival llega antes, la toca él. La pelota nunca se corrige.
- **Conducción:** la pelota no está pegada al pie. Cada toque es un pequeño pase hacia adelante (más largo si hay espacio, más corto con mejor control); entre toques está suelta y se puede robar.
- **Remate:** el cerebro elige un punto del arco y el tipo de golpe (colocado, fuerte, con efecto, globo). El error depende de tiro, pie malo, postura y presión. Gol, palo, afuera o atajada salen del vuelo.
- **Arquero:** calcula por dónde cruza la pelota y cuándo, elige estirada, parado o salida, y su mano tiene una ventana de contacto. Agarra, da rebote o no llega según la calidad del contacto y sus atributos.
- **Duelos:** una entrada es una acción con ventana; si el pie toca primero la pelota, la desvía; si toca primero la cápsula del rival, es falta con gravedad por velocidad y ángulo. Forcejeo = empuje entre cápsulas pesado por fuerza.
- **Centro:** va a una zona, no a un jugador. Atacantes y defensores corren a ella y el primero que la alcanza (cabeza, pecho o pie según la altura) la juega.

**Determinismo:** todo el azar sale de un único generador con semilla, consumido en el mismo orden en PC y Android. El paso de tiempo es fijo y no depende de los fps.

## Qué se reusa, qué se adapta y qué se tira

Se reusa casi todo lo que define al jugador y al club; se reescribe lo que mueve cuerpos y pelota. El Motor V2 vive en una carpeta nueva (`motor_v2/`, el C++ en `motor_v2/cpp/src/`) y convive con `motor_espacial.gd` hasta la etapa 8, así el juego sigue andando mientras se construye.

"Se reusa" en la tabla quiere decir que se reusa la lógica y los números. Lo que corre durante el partido (modificadores, utilidades, árbitro, cansancio) se porta a C++. Los datos del club y de los jugadores los arma GDScript como hoy y se le pasan al motor al empezar el partido. Estadísticas y relato siguen en GDScript y leen los eventos que devuelve el motor.

| Pieza | Qué es hoy | Destino en V2 |
| --- | --- | --- |
| `core/match_engine.gd` | Motor abstracto de los partidos que no juega el usuario | **Se reusa tal cual** |
| `core/duel.gd`, `estilos.gd`, `roles.gd`, `formaciones.gd`, `habilidades.gd`, `personalidad.gd`, `quimica.gd` | Atributos, modificadores, estilos, puestos, quién patea qué | **Se reusa**; los modificadores pasan a pesar el error de ejecución y las utilidades en vez de la probabilidad de un duelo |
| `core/cansancio.gd`, `lesiones.gd`, `arbitro.gd`, `clima.gd`, `estado_cancha.gd` | Energía, lesiones, tarjetas, clima, césped | **Se reusa**; el clima y el césped entran como rozamiento y pique de la pelota |
| `core/jugadas.gd`, `penales.gd` | Jugadas preparadas y tanda | **Se reusa** la lógica; las jugadas pasan a ser planes del cerebro |
| `data/utility_pesos.json` | Pesos de la utility AI | **Se reusa** como punto de partida; se recalibra en la etapa 7 |
| `core/motor_espacial.gd` — cerebro | `evaluar_opciones`, `elegir_softmax`, `temperatura`, perfiles, ritmo, marcador, `_buscar_apoyo`, `_planificar_desmarques`, `_planificar_defensa`, arqueros, balón parado | **Se porta a C++** (`motor_v2/cpp/src/cerebro/`): lee el mundo nuevo y devuelve intenciones |
| `core/motor_espacial.gd` — resolución | `_avanzar_pelota`, `_dirigir_pelota_a`, `_entregar_rodando`, `_completar_dirigida`, `_gana_intercepcion`, `modelo_destino_remate`, `_resolver_rebote` | **Se tira**: lo reemplazan el mundo y el cuerpo |
| `core/motor_espacial.gd` — `_mover_hacia` y parámetros `fisica` | Aceleración, frenada, giro | **Se adapta** como locomoción del cuerpo a 60 Hz |
| `core/estadisticas_partido.gd`, `match/relato_partido.gd` | Estadísticas y relato desde `eventos` | **Se reusan**: el V2 emite el mismo formato de eventos |
| `match/hud_partido.gd`, `minimapa.gd` | Marcador, controles, minimapa | **Se reusan** |
| `match/3d/jugador_3d.gd`, `materiales_3d.gd`, shaders, `utileria_3d.gd`, caras, peinados, dorsales | El personaje y su look | **Se reusan**; `Jugador3D` suma lectura de acción + fase y el ajuste de pie |
| Blender: `tools/blender/animaciones_jugador.py`, `golero_chibi.blend`, `peinados.py` | Modelos y clips de jugador y arquero | **Se reusan**; se agregan marcas de frame de contacto y clips de locomoción |
| `match/3d/vista_cancha_3d.gd` | 4.200 líneas: estadio, cámara y parches al guion | **Se parte**: estadio, cámara y oficiales se mudan a la vista nueva; los `_preparar_*` se tiran |
| `match/vista_partido.gd`, `coreografia_partido.gd` | Traducen fotogramas a entidades | **Se tiran** |
| `match/vista_cancha.gd`, `sprites_partido.gd`, `atlas_jugadores.gd`, `proyeccion.gd`, `camara_partido.gd` | Dibujo 2D | **Se tiran** junto con el modo 2D (Opciones > Simulación desaparece) |
| Tests (163 de regresión) | Sobre el motor espacial | Los de reglas, estadísticas y relato se reusan; los de fotogramas se reemplazan por los de la etapa 1 en adelante |

## Etapas de construcción

Nueve etapas, cada una con algo que se puede mirar y un criterio para pasar a la siguiente. La etapa 0 es una compuerta: decide si el mundo y el cuerpo se escriben en GDScript o en C++ antes de escribir nada grande.

### Etapa 0 — Prueba de rendimiento

- **Qué:** un `motor_v2/mundo.gd` mínimo con 22 cápsulas y una pelota a 60 Hz, cerebros falsos que corren a puntos al azar, 90 minutos. Con vista (22 `Jugador3D` actuales) y sin vista.
- **Dónde se mide:** PC y el Android de referencia, con el export actual.
- **Pasa si:** ≤ 4 ms de simulación por frame con vista y ≤ 3 s por partido sin vista en el teléfono, con margen para el cerebro (que hoy cuesta 0,34 s por partido en la PC a 4 Hz).
- **Si no pasa:** mundo y cuerpo se escriben como GDExtension en C++ y el cerebro queda en GDScript. Se decide acá, no a mitad de camino.

#### Resultado (2026-09-29): no pasa sin vista → mundo y cuerpo en C++

Banco: `motor_v2/banco_etapa0.tscn` (`mundo.gd`, `cerebro_falso.gd`, `vista_v2.gd`). Semilla 20260929. En el teléfono corre como app aparte (`uy.cekasiete.bancov2`, "Banco V2"): se exporta con `run/main_scene` apuntando al banco y los argumentos en `command_line/extra_args` (las plantillas oficiales no aceptan una escena por línea de comando), y después se restauran `project.godot` y `export_presets.cfg`. Resultados en logcat con el prefijo `[banco_v2]`.

| Medida | GDScript, PC (Ryzen 7 9700X) | GDScript, teléfono (T760) | C++, PC | C++, teléfono | Presupuesto |
| --- | --- | --- | --- | --- | --- |
| Partido de 90 min sin vista, en hilo (mundo + cerebro falso) | 5,9 s | 24,9–26,0 s | 0,60 s | **1,52 s** | ≤ 3 s |
| Por paso | 18,2 µs | 76,7 µs | 1,84 µs | 4,69 µs | — |
| Simulación por cuadro con vista (p95) | 0,07 ms | 0,83 ms | 0,01 ms | 0,08 ms | ≤ 4 ms |
| Vista (código GDScript) por cuadro, prom. | 0,27 ms | 1,9–2,1 ms | 0,35 ms | 2,3 ms | — |
| Misma semilla, misma huella PC ↔ Android | sí | sí | sí (con matemática propia) | sí | igual |

- **Decisión:** el mundo y el cuerpo se escriben como GDExtension en C++. En GDScript el mundo solo, sin cuerpo de verdad ni cerebro, ya cuesta 8 veces el presupuesto del partido sin vista. El mismo mundo y el mismo cerebro falso en C++ (`motor_v2/cpp`, clase `MundoV2Nativo`, banco con `-- nativo`) tardan 1,5 s en el teléfono: 16 veces menos. Llamar a C++ paso por paso desde GDScript suma solo 0,23 µs por paso.
- **La extensión:** godot-cpp v10 con `api_version=4.7`, fuera del repo en `D:/dev-tools/godot-cpp`; cómo se arma, en `motor_v2/cpp/SConstruct`. Las bibliotecas van en `motor_v2/bin/` (Windows x86_64 y Android arm64, siempre `template_release`). `motor_v2/cpp/.gdignore` evita que Godot quiera importar los `.obj` del compilador como mallas.
- **Determinismo en C++:** con `std::sin`, `std::cos` y `std::atan2` el mismo partido terminaba distinto en la PC y en el teléfono (8 goles contra 18). Hacen falta dos cosas: `-ffp-contract=off` en Android (clang junta a*b + c en una sola instrucción FMA que redondea distinto) y trigonometría propia (`motor_v2/cpp/src/matematica_fija.h`, solo con +, −, ×, ÷ y raíz; error 8e-16). Con las dos, la huella es la misma. La trigonometría propia cuesta: el paso pasó de 3,3 a 4,7 µs en el teléfono. Regla para las etapas siguientes: el mundo y el cuerpo no llaman a ninguna función matemática del sistema salvo `sqrt`.
- **El cerebro tampoco entra en GDScript a 10 Hz:** hoy cuesta 0,34 s por partido en la PC a 4 Hz; a 10 Hz serían ~0,85 s, y el teléfono es 4,3 veces más lento que esta PC (76,7 contra 18,2 µs por paso). Son ~3,7 s por partido solo de cerebro. Ver la decisión abierta nueva.
- **Determinismo en GDScript:** la huella del estado después de 90 minutos es la misma en la PC y en Android, aunque usa `sin`, `cos` y `atan2` del motor. Probablemente porque las posiciones se guardan en float de 32 bits y ese redondeo tapa la diferencia del último bit; no es una garantía.
- **Dibujo, no simulación:** con vista el teléfono dibuja a 43 fps. Lo que pesa son las sombras del sol (4 cortes, 197 llamadas de dibujo): sin sombras, 60 fps clavados con 47 llamadas; con 2 cortes o 1 corte, 52 fps. Sin MSAA sube a 48 fps y la escala 3D de 0,75 no cambia nada (no es el llenado de píxeles). La vista actual del juego usa las mismas sombras.
- **Grilla de choques:** con 22 cuerpos, en GDScript la grilla de 5 m costaba más que mirar los 231 pares con descarte por eje (12,9 contra 7,5 µs por paso en la PC). En C++ se vuelve a medir.

### Etapa 1 — La pelota

- **Qué:** la pelota en C++ (`motor_v2/cpp/src/pelota.h/.cpp`, a partir de la de `mundo_v2_nativo.cpp`): gravedad, arrastre, Magnus, giro que decae, pique con restitución y rozamiento que convierte deslizamiento en rodada, rodada con frenado, choque con palos, travesaño y red. Parámetros en `data/fisica_v2.json`; césped y clima los modifican.
- **Banco:** escena `laboratorio_pelota.tscn` que dispara tiros, centros, globos, rebotes en el palo y saques de arco con la cámara actual.
- **Pasa si:** el saque de arco pica 2 o 3 veces y rueda; un tiro con efecto se curva de forma visible; un tiro al palo rebota sin casos especiales; la pelota nunca avanza en un paso más de lo que da su velocidad (detector `SALTO_PELOTA` = 0 por construcción).

#### Resultado (2026-09-30): pasa

Hecha en la nube (Linux, sin pantalla). Test: `tests/test_pelota_v2.gd`.

- **Código:** `motor_v2/cpp/src/pelota.h/.cpp` (`motor_v2::Pelota`, sin Godot) y `pelota_v2_nativa.h/.cpp` (`PelotaV2Nativa`, para el laboratorio y los tests). `MundoV2Nativo` usa la misma pelota; su choque con los cuerpos sigue siendo el de la etapa 0 hasta la etapa 3. Los parámetros van en `data/fisica_v2.json`; `motor_v2/fisica_v2.gd` (`FisicaV2.parametros(calidad_cancha, clima, direccion_viento)`) les aplica el césped y el clima.
- **Cómo choca:** en cada subpaso se busca el primer choque por barrido (piso, palos y travesaño como cilindros, red como planos de fondo, costados y techo), la pelota avanza justo hasta el punto de contacto y sale con la velocidad nueva. Nunca se corrige de lugar, así que `SALTO_PELOTA` = 0 sale de la construcción y no de un tope.
- **Pique y rodada:** esfera hueca (inercia 2/3 m r²). El pique devuelve la vertical con restitución y el rozamiento de Coulomb cambia deslizamiento por giro; apoyada, desliza hasta rodar y rodando la frenan el pasto y el aire. Por debajo de 1,8 m/s de caída ya no pica: rueda.
- **Banco:** `motor_v2/laboratorio_pelota.tscn`, con los disparos de `motor_v2/disparos_pelota.gd` y la cámara del partido (`VistaV2` con `con_jugadores = false`). Con `--headless` imprime lo que mide cada disparo con el prefijo `[lab_pelota]`. Argumentos: `disparo=N`, `cancha=N`, `clima=Lluvia|Viento`.

| Disparo | Qué pasa | Criterio |
| --- | --- | --- |
| Saque de arco (30 m/s a 32°) | Cae a 51 m, sube 10,5 m, pica 3 veces, rueda 9 m y se para | 2 o 3 piques y rueda |
| Tiro con efecto (55 rad/s de giro) | Se curva 4,5 m y entra; sin giro, la misma patada pasa 3 m afuera | curva visible |
| Tiro al palo (rasante) | Pega en la cara de afuera del palo y sale desviado | rebota sin casos especiales |
| Tiro al travesaño | Pega y vuelve a la cancha picando | rebota sin casos especiales |
| Remate a la red | Pega en la red de fondo y queda muerto adentro del arco | — |
| Centro y globo | El centro se cierra 1,9 m; el globo sube 10,4 m y cae adentro | — |
| Todos | `SALTO_PELOTA` = 0 (exceso 0,0 m); la misma patada da la misma huella | = 0 |

- **Césped y clima:** un pase rasante a 12 m/s rueda 27,5 m; en la peor cancha (−8) 24,6 m y en la mejor (+3) 28,9 m; con lluvia 30,1 m. Con viento de 6 m/s el globo pica 6 m más lejos a favor y 7 m más cerca en contra.
- **Costo:** en la misma máquina de la nube, el paso del banco de la etapa 0 (`-- nativo solo_sin_vista`) pasó de 3,65 a 3,80 µs (+4%) con la pelota nueva. El partido sin vista sigue en 1,26 s.
- **Hecho en la PC (2026-09-30):** bibliotecas de Windows y Android rearmadas; `test_pelota_v2` da 0 fallas en la PC. El partido del banco de la etapa 0 con la pelota nueva da la misma huella en la PC y en el teléfono (7802884780403246726) y tarda 1,61 s en el teléfono (0,63 s en la PC).
- **Revisión visual (2026-09-30):** el usuario miró el laboratorio en la PC y le gustó cómo se ve. La etapa 1 pasa. La calibración fina contra video queda para la etapa 7.

### Etapa 2 — El cuerpo

- **Qué:** locomoción (aceleración, frenada, giro según velocidad, atributos y cansancio, a partir de `_mover_hacia`) y la máquina de acciones: preparación → ventana de contacto → recuperación.
- **Blender:** `animaciones_jugador.py` exporta junto al GLB un `acciones_v2.json` por clip: duración, frame de contacto, hueso que toca (`Pie_R`, `Frente`, `Pecho`, `Mano_L/R`), alcance y velocidad de salida típica. Se suman clips de locomoción (arranque, frenada, giro de 90° y 180°, correr de costado y de espaldas).
- **Vista:** `Jugador3D` lee acción + fase; las piernas siguen la velocidad real; el pie se lleva a la pelota en los últimos 0,15 s (el *warping* de FIFA 10, solo en huesos).
- **Pasa si:** `muestra_animaciones_3d.tscn` corre manejada por acciones; deslizamiento de pies bajo un umbral medido; nadie gira 180° en el lugar corriendo a velocidad máxima.
- **En la nube (decisión del usuario, 2026-09-30):** la etapa 2 se hace en la nube salvo lo que pide Blender. Los `.blend` no están en el repo, así que ahí no se pueden hacer clips nuevos. Qué sí:
  - Locomoción y máquina de acciones en C++ (`motor_v2/cpp/src/cuerpo.h/.cpp`), con su test sin pantalla.
  - `data/acciones_v2.json` armado desde lo que ya hay: `contacto`, `hueso` y `ticks` de cada clip salen de las definiciones de `tools/blender/animaciones_jugador.py`, y la duración real de cada animación se lee de `assets/3d/jugador.glb` y `golero.glb` con Godot sin pantalla. Un script en `tools/` lo genera, así se rehace igual cuando cambien los clips.
  - Mientras falten los clips de arranque, frenada, giro y correr de costado o de espaldas, la vista usa `Correr`, `Trotar`, `Caminar` y `Respirar`. La lista de clips que faltan queda anotada acá para hacerlos en la PC con Blender.
  - La prueba de deslizamiento de pies se mide sin pantalla (posición del hueso del pie contra el piso). La revisión visual de `muestra_animaciones_3d.tscn` queda para la PC.

#### Resultado (2026-09-30): el cuerpo pasa sin vista; los pies patinan hasta tener clips nuevos

Hecha en la nube. Test: `tests/test_cuerpo_v2.gd`.

- **Código:**
  - `motor_v2/cpp/src/cuerpo.h/.cpp` (`motor_v2::Cuerpo`, sin Godot) y `cuerpos_v2_nativos.h/.cpp` (`CuerposV2Nativos`, para el banco y los tests).
  - `MundoV2Nativo` mueve a sus 22 jugadores con el mismo cuerpo.
  - `FisicaV2` suma `parametros_cuerpo()`, `clips()` y `fisico_de(atributos, energia)`.
- **Locomoción:** es `_mover_hacia` a 60 Hz con los mismos números de `data/utility_pesos.json` (fisica, control y esfuerzo). Tiene dos cambios, para que ningún paso mueva a nadie más de lo que da su velocidad:
  - La rapidez baja como mucho `frenada` por segundo.
  - Al pasar por el objetivo sin frenar, sigue con su velocidad en vez de clavarse.
  - Además, la energía del partido (`Cansancio.factor_stats`) baja la punta y la aceleración. El motor actual solo la aplica a los duelos.
- **Acciones:** fases preparación → ventana de contacto → recuperación. La ventana dura `ventana_contacto_seg` (0,1 s, en `data/fisica_v2.json`) y va centrada en el cuadro de contacto del clip. No se puede empezar un gesto hasta que termina el anterior. Un gesto con `mueve = false` (cabecear, barrerse, atajar) no deja acelerar ni girar: el cuerpo frena con su frenada.
- **`data/acciones_v2.json`:** lo genera `tools/generar_acciones_v2.py` (Python lee las definiciones de Blender con `ast`; `tools/medir_clips_v2.gd` mide los GLB con Godot sin pantalla). Tiene 60 clips con su duración real; 17 con contacto, ancla y punto de contacto medido en el cuadro del golpe. El contacto sale de `CONTACTO_3D` de la vista cuando está (ya verificado) y si no de Blender. Faltan velocidades de salida típicas: llegan en la etapa 3, cuando el pie toque la pelota.
- **Vista:** `VistaV2.dibujar_cuerpos` pone a cada `Jugador3D` en su acción y su segundo; sin acción, anda según su velocidad real.
- **Banco:** `motor_v2/laboratorio_cuerpo.tscn`. Tiene 22 cuerpos: 12 hacen todos los gestos de su modelo, 5 pican de punta a punta con media vuelta, 3 trotan y caminan, y 2 patean y controlan corriendo. Un toque cambia de grupo. Con `--headless` imprime con `[lab_cuerpo]`.
- **Detector PATINA:** `motor_v2/detector_patina.gd` (`DetectorPatinaV2`). Mide sobre los `Jugador3D` cuánto desliza en el mundo el pie apoyado (a menos de 1,5 cm del punto más bajo).

| Medida (test y laboratorio, 60 s) | Resultado |
| --- | --- |
| Arranque | El rápido (90) llega al 90% de su punta en 1,13 s; con la misma punta, aceleración 90 hace 3,46 m en el primer segundo contra 2,54 m con 30 |
| Frenar | Llega a 20 m parado, sin pasarse |
| Saltos | Ningún paso mueve a nadie más que su velocidad (exceso 3e-6 m, redondeo de float) |
| Media vuelta a 8,6 m/s | Frena hasta 0,04 m/s y tarda 1,83 s en correr al revés; nadie gira 180° en el lugar |
| Giro de 90° a la punta | La carrera gira como mucho `giro_acel`/v; sigue 3,3 m hacia adelante antes de doblar |
| Reserva y energía | Un minuto de pique deja la punta en 7,34 de 8,64 m/s (piso 0,85); con energía 0,2 corre a 5,62 m/s |
| Gestos | Los 52 clips que no son de andar duran lo del clip y abren el contacto en su cuadro; en 60 s se terminaron 516 |
| Costo | El paso del banco de la etapa 0 bajó de 4,3 a 2,9 µs en la misma máquina de la nube (la locomoción nueva usa vectores en vez de seno y coseno) |

**Pasa si, uno por uno:**

- **Nadie gira 180° en el lugar corriendo a velocidad máxima:** pasa.
- **`muestra_animaciones_3d.tscn` manejada por acciones:** no se hizo. Esa escena repite jugadas reales del motor actual, y el V2 recién las va a poder jugar desde la etapa 3. Mientras tanto, `laboratorio_cuerpo.tscn` muestra todos los clips manejados por el cuerpo. Decisión abierta: pasar la muestra al V2 en la etapa 6 o dejar el laboratorio como prueba de la etapa 2.
- **Deslizamiento de pies bajo un umbral:** no pasaba (ver el resultado de los clips en cinta, más abajo). Los clips de andar estaban hechos en el lugar: el pie apoyado casi no retrocede (en Correr, el pie bajo hasta avanza). El pie apoyado desliza más o menos lo que avanza el cuerpo. Se probaron largos de ciclo de 0,5 a 3,2 m y ninguno lo baja.

| Clip | Pie apoyado | Cuerpo |
| --- | --- | --- |
| Correr | 7,48 m/s | 6,88 m/s |
| Trotar | 3,23 m/s | 3,54 m/s |
| Caminar | 1,43 m/s | 1,59 m/s |
| Respirar (parado) | 0,05 m/s | 0,02 m/s |

- **Umbral propuesto:** el pie apoyado desliza menos del 15% de lo que avanza el cuerpo. Se mide con `laboratorio_cuerpo.tscn -- segundos=60` sin pantalla.
- **Ajuste del pie a la pelota** (los últimos 0,15 s): queda para la etapa 3, porque necesita una pelota a la que llevar el pie.
- **Hecho en la PC (2026-09-30):** bibliotecas de Windows y Android rearmadas; `test_cuerpo_v2` y `test_pelota_v2` dan 0 fallas en la PC. El banco de la etapa 0 con el cuerpo nuevo da la misma huella en la PC y en el teléfono (7270582477375384744) y tarda 1,25 s en el teléfono (0,43 s en la PC).
- **Revisión visual (2026-09-30):** el usuario miró `laboratorio_cuerpo.tscn` en la PC y le gustó cómo se ve. La etapa 2 pasa, salvo el patinaje de pies, que espera los clips nuevos de Blender.

#### Resultado (2026-09-30): clips en cinta hechos en Blender; los pies ya no patinan al andar derecho

Hecho en la PC con Blender 5.2 sin pantalla (`blender -b`). `exportar_juego3d.py` ahora exporta también sin pantalla, y el GLB sale igual byte a byte que desde la ventana.

- **Cómo se arman:** `animaciones_jugador.py`, sección "locomoción en cinta". Cada tobillo tiene un lugar en la cancha y la pierna se resuelve con IK (cinemática inversa: se busca el ángulo de cada articulación para llegar a un punto). El pie apoyado queda plano y fijo en la cancha mientras el cuerpo avanza. El clip saca la traslación del cuerpo: queda en el lugar y el pie apoyado retrocede a la velocidad del cuerpo.
- **Clips (jugador y golero):**
  - Loops: `Correr` (2,2 m por ciclo), `Trotar` (1,3 m), `Caminar` (0,62 m), `Correr_Costado_Izq/Der` y `Correr_Espaldas` (1 m).
  - Una vez: `Arranque` (de parado a Correr en 2 m), `Frenada` (de Correr a parado en 1,1 m), `Giro_90_Izq/Der` y `Giro_180_Izq/Der` (en el lugar, un pie pivotea sobre la punta).
  - Todos los loops arrancan con el derecho pasando por debajo en la fase 0 y lo tienen en el medio del apoyo en la 0,5, como el `Correr` de antes.
  - Van a 24 cuadros por ciclo (los loops de 1 s y Arranque y Frenada de 1,5 s). La vista los avanza por metros y la duración no importa. Con 12 cuadros el apoyo de Correr duraba 2 cuadros y el pie se hundía 1,2 cm entre uno y otro.
- **Metros por cuadro:** Blender escribe `tools/blender/avance_locomocion.json` al armarlos. `generar_acciones_v2.py` lo pasa a `data/acciones_v2.json` como `metros`, `avance_m` (metros en cada cuadro), `direccion` y `giro`. `test_cuerpo_v2` controla el avance y que `VistaCancha3D` use los mismos metros.
- **Vista:**
  - `VistaV2` avanza cada loop con sus `metros`.
  - Por debajo de `rapidez_para_girar` el cuerpo mira la jugada. Si anda de costado o para atrás, la vista usa `Correr_Costado_*` o `Correr_Espaldas` y gira el modelo hasta 45° para que el clip vaya justo hacia donde va el cuerpo.
  - Entre dos loops cambia recién en la fase 0 o 0,5: ahí el pie apoyado está debajo del cuerpo en los dos clips.
- **Detector PATINA:** el suelo ahora es el de cada clip. Con uno solo para todos, una barrida o una caída lo bajaba 4 cm y en Correr el pie apoyado dejaba de contar. Lo que patina mientras un clip se funde con otro va aparte, en `(fundido)`.

| Clip | Pie apoyado antes | Pie apoyado ahora | Cuerpo |
| --- | --- | --- | --- |
| Correr | 7,48 m/s | 0,43 m/s (6%) | 6,82 m/s |
| Trotar | 3,23 m/s | 0,17 m/s (5%) | 3,59 m/s |
| Caminar | 1,43 m/s | 0,16 m/s (9%) | 1,74 m/s |
| Correr_Costado_Izq / Der | — | 0,49 / 0,26 m/s (22% / 14%) | 2,24 / 1,91 m/s |
| Correr_Espaldas | — | 0,57 m/s (32%) | 1,76 m/s |
| (fundido) | — | 1,29 m/s | — |

Medido con `laboratorio_cuerpo.tscn -- segundos=60` sin pantalla. En Blender, `medir_cinta()` da menos del 3,5% en todos los clips.

**Pasa si, uno por uno:**

- **Deslizamiento de pies bajo un umbral (15%):** pasa en Correr, Trotar y Caminar.
- **De costado y de espaldas:** no pasan en el laboratorio. Sin el modelo girando patinan del 5 al 11%. El resto sale de las medias vueltas de los piques: la marcha barre 180° a poca velocidad y el modelo gira con el pie apoyado.
- **Fundidos:** el cambio de clip todavía arrastra el pie (1,29 m/s mientras dura).

#### Resultado (2026-09-30): la vista usa Arranque, Frenada y los giros

Test: `tests/test_vista_cinta_v2.gd`.

- **Qué busca el cuerpo:** `Cuerpo` (C++) suma tres lecturas que no cambian nada: `rapidez_buscada` (la punta hacia el objetivo), `metros_para_parar` (hasta el objetivo si llega frenando; -1 si lo pasa) y `giro_pendiente` (lo que le falta girar). `CuerposV2Nativos` las expone con `get_`. `_girar` usa la misma cuenta: el banco de la etapa 0 da la misma huella (7270582477375384744). Bibliotecas de Windows y Android rearmadas.
- **Cuándo usa cada clip (`VistaV2._empezar_una_vez`):**
  - Giro: quieto y le faltan 60° o más. Desde 135°, `Giro_180_*`; si no, `Giro_90_*`.
  - Arranque: sale de parado, hacia adelante, buscando al menos la rapidez de Correr (`ANDAR_TROTA_HASTA_MS`). El que sale caminando o trotando no se tira como un velocista.
  - Frenada: ya frenando y le quedan a lo sumo los metros del clip (1,1 m). Si quedan menos, el clip empieza más adelante.
- **Cómo avanzan:** con lo que hace el cuerpo, no con el reloj. Arranque va con los metros recorridos y sigue con Correr en `fase_final`. Frenada va con los metros que le faltan al cuerpo para parar: sumando v·dt el clip terminaba 6 cm antes de que el cuerpo parara. El final, con el cuerpo quieto, va con el reloj. Los giros van con lo que giró el cuerpo (`giro_por_cuadro`), con el modelo quieto en el rumbo del principio.
- **Sin fundido en los giros:** empiezan y terminan en la pose de Respirar, pero con el modelo girado. Fundiendo, el giro se sumaba dos veces y el pie barría 0,36 m en un cuadro.

| Test (un jugador: media vuelta, pique de 25 m y frena) | Pie apoyado |
| --- | --- |
| Giro_180 | 0,21 m en toda la vuelta (girando sin clip, cada pie barre unos 0,35 m) |
| Arranque | 2% de lo que avanza |
| Correr | 4% |
| Frenada | 3% |

En `laboratorio_cuerpo.tscn`, 17 a 19 ahora paran, miran a otro lado y salen (19 pica). En 60 s: Arranque 0,07 m/s de pie contra 1,94 del cuerpo y Frenada 0,05 contra 2,47.

#### Resultado (2026-09-30): la media vuelta corriendo

- **Qué hace el cuerpo:** con el objetivo atrás frena en línea recta (`giro_acel`, 12 m/s²), pasa por 0 y sale al revés. Por debajo de 2 m/s no gira, así que la vista mostraba `Correr_Espaldas` y el modelo girando.
- **Clip nuevo `Media_Vuelta_Izq/Der`** (Blender, en cinta, 1,75 s): frena en 1 m con dos apoyos largos, gira 180° en dos pasos casi parado (un pie pivotea sobre la punta) y sale corriendo al revés. El cuerpo va y vuelve: el JSON trae `recorrido_m` (metros recorridos, que no bajan), `metros_frenado`, `fase_inicial` y `fase_final`. Espejar cambia de pie: las fases corren medio ciclo.
- **C++:** `Cuerpo::rumbo_buscado` (hacia dónde queda el objetivo), expuesto como `get_rumbo_buscado`. Bibliotecas de Windows y Android rearmadas.
- **Vista:**
  - Corriendo con el objetivo a 150° o más de la carrera, cuando le falta 1 m o menos para parar, entra en el pie con que empieza el clip (Correr pasa por su `fase_inicial`).
  - Avanza con los metros recorridos: hasta parar salen de la rapidez (v²/2·giro_acel) y después suma lo que anda al revés.
  - Sale a Correr en `fase_final`, sin fundido, y anda hacia adelante aunque el rumbo del cuerpo todavía esté girando.
  - Frenada deja el lugar al giro si el cuerpo ya parado tiene que girar: juntando los pies con el modelo girando, el pie patinaba 0,48 m/s.

| Laboratorio, 60 s | Pie apoyado | Cuerpo |
| --- | --- | --- |
| Media_Vuelta_Izq / Der | 0,26 / 0,28 m/s (14% / 16%) | 1,89 / 1,78 m/s |
| Correr_Espaldas (antes 0,57 m/s, 32%) | 0,07 m/s (5%) | 1,49 m/s |
| Correr_Costado_Izq (antes 22%) | 0,13 m/s (9%) | 1,51 m/s |
| Frenada | 0,10 m/s (5%) | 1,89 m/s |

En `test_vista_cinta_v2`, un pique a 8,1 m/s que vuelve: Correr, Media_Vuelta, Correr, sin pasar de espaldas ni de costado, y el pie apoyado desliza el 12% de lo que recorre el cuerpo.

**Qué falta:**

1. La media vuelta entra recién cuando Correr pasa por el pie del clip: a veces ya se comió parte de la frenada y queda en el borde del 15%.
2. Los fundidos entre loops todavía arrastran el pie (1,2 m/s mientras duran).
3. Revisión visual del partido 3D actual (`VistaCancha3D` también usa los clips nuevos, pero no los de una vez).

- **Revisión visual (2026-09-30):** el usuario miró `laboratorio_cuerpo.tscn` en la PC con los clips nuevos y se ve bien.

### Etapa 3 — Tocar la pelota

- **Qué:** conducción por toques, recepción según la altura de la pelota (pie, muslo, pecho, cabeza), pase al punto de encuentro con tangentes y tiempos de llegada de cada rival, intercepción = el primero que la alcanza.
- **Banco:** un rondo 4 vs 2 y un 5 vs 5 sin arcos, con cerebros sencillos.
- **Pasa si:** cero correcciones de velocidad de la pelota; los pases se cortan solo cuando un defensor llega; ningún receptor frena en seco para esperar.

#### Resultado (2026-09-30): pasa sin vista; falta la revisión visual

Hecha en la nube. Test: `tests/test_toque_v2.gd`. Medición: `tests/_diag_toque_v2.gd` (varias semillas).

- **Código:**
  - `motor_v2/cpp/src/toque.h/.cpp`: lo que comparten todos los que tocan la pelota. Punto de contacto de un clip, parte del cuerpo según la altura, tiempo de llegada de un cuerpo a un punto, trayectoria prevista y perfiles de pase.
  - `motor_v2/cpp/src/canchita.h/.cpp` (`motor_v2::Canchita`, sin Godot): el banco. Pelota, cuerpos, cerebros sencillos, reglas del rondo y del partidito, y los detectores.
  - `canchita_v2_nativa.h/.cpp` (`CanchitaV2Nativa`): lo mismo para GDScript. `motor_v2/canchita_v2.gd` (`CanchitaV2.armar`) la arma igual para el laboratorio, el test y la medición.
  - `azar.h`: el PCG32 de `MundoV2Nativo`, suelto, con una normal que solo suma (Irwin-Hall).
  - Parámetros en `data/fisica_v2.json`, sección `toque`; `FisicaV2.parametros_toque()` y `FisicaV2.jugador_de()` (físico más pases y control).
- **Nadie adjudica:** el que patea elige el punto y la rapidez; al patear se suma un error según pases, presión y cuánto patea de costado. Quién la toca lo decide el mundo: el primero cuyo punto de contacto, con la ventana del gesto abierta, pasa por el tramo que recorrió la pelota en ese paso. La pelota solo cambia por la física, por un toque o por un rebote contra las piernas. Un detector cuenta cualquier otro cambio (`correcciones`).
- **Todos planean con la misma física:** al tocarse la pelota se adelanta una copia 5 s (`Trayectoria`). La predicción coincide con la pelota paso por paso mientras nadie la toca (diferencia 0,0 m). Los demás la leen recién después de `reaccion_seg` (0,2 s). El receptor del pase no espera: el que patea le avisa y sale al punto (Simple Soccer). Esperando la reacción, arrancaba 0,3 s tarde y los pases al espacio se le iban.
- **Pase al punto de encuentro:** a los pies o a las dos tangentes del círculo que el receptor cubre trotando mientras viaja la pelota (hasta 2,5 m). La rapidez es la más baja que llega todavía a `llegada_pase_ms` (7 m/s), con perfiles de la misma pelota sin viento. Para cada punto se prueba cada rival con su tiempo de llegada a cada tramo; el pase va al mejor margen. Si no hay pase raso seguro, un globo que pasa por arriba de la cabeza.
- **Recepción según la altura:** pie (`Control_Corriendo`), muslo, pecho (`Pecho`) y cabeza (`Cabecear`). El clip sale de la altura de la pelota en su cuadro de contacto, y el toque solo vale con la pelota en la franja de esa parte. **No hay clip de muslo:** usa `Pecho` hasta que se haga `Control_Muslo` en Blender. Con un rival encima, el receptor la manda de primera si tiene un pase que le gana a todos.
- **Conducción por toques:** cada toque es un pase corto hacia adelante con `Control_Corriendo`. El largo sale de lo que corre en ese momento: más largo con espacio (hasta 1,8 m), más corto con un rival cerca y con mejor control. Entre toques la pelota está suelta: en el test se separa del pie de 0,02 a 2,6 m.
- **Intercepción:** cualquiera que llegue primero, de cualquier equipo. Si dos tienen la ventana abierta en el mismo paso, gana el primero y las otras ventanas se cierran (sin esto, en el partidito había quites de ida y vuelta en 0,02 s). El defensor va a una pelota controlada solo si llega 0,1 s antes que el que la tiene; si no, se para a 1,5 m y contiene.
- **Gatillo:** el cuerpo arranca el gesto cuando, en lo que tarda en llegar a su cuadro de contacto, el punto que toca va a quedar a `gatillo_m` de la pelota, o cuando es el mejor momento y queda a `tolerancia_m`. El toque vale hasta `tolerancia_m` (0,3 m) en el piso.
- **Vista:** `VistaV2.dibujar_canchita` dibuja la pelota con su giro y los cuerpos con su acción. **Ajuste de pie:** en los últimos 0,15 s antes del contacto el modelo gira hacia la pelota (lo que el motor le deja estirar, `giro_alcance_rad`) y `Jugador3D.llevar_pie` dobla muslo y pierna (IK de dos huesos) hasta el borde de la pelota. Solo toca huesos. `Jugador3D.ancla_de_pose` da el ancla con la pose de este momento: `ancla()` cae en la posición del `BoneAttachment3D`, que se mueve recién al final del cuadro.
- **Banco:** `motor_v2/laboratorio_toque.tscn`. Con pantalla, un toque pasa del rondo al partidito. Con `--headless` simula cada juego (`segundos=N`), mide el patinaje y el hueco entre el pie y la pelota en cada toque, e imprime con `[lab_toque]`.

**Cambio en el cuerpo (etapa 2):** el detector `frenadas_en_seco` encontró 477 en 5 minutos de rondo. El cuerpo se clavaba al llegar frenando (hasta de 3,8 m/s a 0 en un paso). Dos causas:

- La rampa de frenada era la continua (v² = 2·a·d): llegaba al punto a casi 1 m/s. Ahora es la de a pasos (v²/2a + v·dt/2 = d) y llega a menos de `frenada`·dt.
- Si el cerebro le acerca el objetivo, llega rápido. Ahora no se clava: lo pasa frenando y vuelve. `Cuerpo::caida_maxima` (el mayor cambio de rapidez en un paso, `giro_acel`·dt) lo usan el cuerpo y el detector.

El banco de la etapa 0 cambió de huella: 7270582477375384744 antes (PC, teléfono y Linux) y 8207067039817050138 ahora (Linux). `test_cuerpo_v2` sigue en 0 fallas.

| Medido (5 semillas × 5 min, sin vista) | Rondo 4 vs 2 | Partidito 5 vs 5 |
| --- | --- | --- |
| Correcciones de la pelota / SALTO_PELOTA | 0 / 0 | 0 / 0 |
| Corte más lejos (pie del defensor a la pelota) | 0,30 m | 0,30 m |
| Frenadas en seco | 0 | 0 |
| Espera del receptor quieto con el pase viniendo | media 0,05 s, máx 0,47 s | media 0,03 s, máx 0,47 s |
| Pases por minuto / completos | 44,8 / 87% | 37,8 / 77% |
| Cortados / afuera | 5% / 7% | 21% / 3% |
| De primera | 16% | 45% |
| Quites por minuto | 1,3 | 12,9 |
| Recepciones pie / muslo / pecho / cabeza | 852 / 5 / 6 / 0 | 827 / 2 / 2 / 0 |
| Peor exceso de paso de un cuerpo (choques entre cuerpos) | 0,05 m | 0,05 m |
| Costo por paso | 3,2 µs | 7,6 µs |

| Laboratorio con vista (120 s) | Rondo | Partidito |
| --- | --- | --- |
| Hueco pie-pelota dibujados en el toque, con el ajuste de pie | mediana 0,00 m, 90% 0,07 m | mediana 0,00 m, 90% 0,11 m |
| Hueco sin el ajuste (antes de agregarlo) | mediana 0,32 m, 90% 0,54 m | mediana 0,37 m, 90% 0,57 m |

**Pasa si, uno por uno:**

- **Cero correcciones de velocidad de la pelota:** pasa, por construcción y medido.
- **Los pases se cortan solo cuando un defensor llega:** pasa. Todo corte es un toque o un rebote del defensor, con su pie a 0,3 m o menos de la pelota.
- **Ningún receptor frena en seco para esperar:** pasa. Cero frenadas en seco, y el receptor espera quieto 0,03 a 0,05 s de media.

**Qué falta:**

1. En los juegos casi no hay recepciones altas: el receptor sale a buscar el globo y lo toma después del pique. El test las prueba con pelotas lanzadas (las cuatro partes aparecen).
2. Clip `Control_Muslo` en Blender.
3. El partidito es caótico (12,9 quites por minuto): los cerebros son del banco. Los de verdad son la etapa 4.
4. Los gestos (patear, controlar) no están hechos en cinta: el detector de patinaje no los mide. En la canchita Frenada patina 0,6 a 1,6 m/s y Caminar 0,9 a 1,2 m/s, más que en el laboratorio del cuerpo, porque el cerebro cambia de objetivo a 10 Hz.

### Etapa 4 — El cerebro

- **Qué:** se portan a C++ (`motor_v2/cpp/src/cerebro/`) `evaluar_opciones`, `elegir_softmax`, perfiles, ritmo, marcador, desmarques, defensa y jugadas preparadas, devolviendo intenciones. Nuevo: puntaje de puntos de apoyo sobre una grilla (se le puede pasar, puede tirar, distancia al poseedor), línea defensiva y offside en el frame del pase.
- **Pasa si:** 11 vs 11 sin arqueros ni reglas durante 10 minutos con posesiones de varios pases, bloques que se desplazan con la pelota y pases al espacio que salen solos.

#### Resultado (2026-09-30): pasa

- **Revisión visual (2026-09-30):** el usuario miró `laboratorio_cerebro.tscn` en la PC y se ve bien. Bibliotecas de Windows y Android rearmadas.

Hecha en la nube. Test: `tests/test_cerebro_v2.gd`. Medición: `tests/_diag_cerebro_v2.gd` (varias semillas).

- **Código:**
  - `motor_v2/cpp/src/cerebro/cerebro.h/.cpp` (`motor_v2::Cerebro`, sin Godot). Lee una foto del partido (`Mundo`) y devuelve intenciones: la decisión del poseedor (`Decision`) y adónde va cada uno sin la pelota (`Objetivo`). Nunca mueve la pelota ni a un jugador.
  - `canchita.h/.cpp`: modo `PARTIDO`, 11 contra 11 en la cancha entera. El mundo es el de la etapa 3: la canchita arma la foto, le pregunta al cerebro y ejecuta con el toque de siempre.
  - `cerebro_v2_nativo.h/.cpp`: lee los pesos, el plan de cada club y la ficha de cada jugador. `CanchitaV2Nativa` suma `configurar_cerebro`, `configurar_plan`, `contadores_cerebro`, `ultima_decision` y lecturas para la vista (papeles, objetivos, desmarques, líneas).
  - `motor_v2/cerebro_v2.gd` (`CerebroV2.armar_partido`): arma el partido con dos `Team.generar`, sus formaciones (`Formaciones.slots`) y sus estilos. GDScript solo junta datos que ya existían.
  - `matematica_fija.h` suma `exponencial` y `logaritmo` (softmax y `log` de `_ponderar_plan`), solo con +, −, ×, ÷ y bits del double.
  - `SConstruct` compila también `src/cerebro/*.cpp`.
- **Pesos:** los de `data/utility_pesos.json`, los mismos del motor actual (conducir, pase, pase_hueco, pase_largo, pared, centro, despeje, temperatura, presión, ritmo, marcador, perfil, sin_pelota, defensa). Lo nuevo va en `data/fisica_v2.json`, sección `cerebro`. `test_cerebro_v2` falla si el C++ y los JSON se separan.
- **Unidades:** el motor espacial contaba en ticks de 0,25 s. Los relojes pasan a segundos (plan 1 s, ritmo 1,5 s, transición 6 s, desmarque de 1 a 3 s). Lo que el JSON trae en ticks se pasa con `TICK_ESPACIAL_SEG`.

**Qué se portó** (con el nombre de GDScript):

- Poseedor: `evaluar_opciones` (conducir, despeje, pase, pase atrás al área, pase al hueco, pase a la corrida preparada, centro, pelotazo, pared con tercer hombre y pared de ida y vuelta), `_ponderar_plan`, `_premiar_descarga_util`, `_aplicar_pie_preferido`, `_solo_frente_al_arco`, acorralado y arquero encerrado, `temperatura` y `elegir_softmax`. La decisión vale lo que la cadencia (`cadencia_de_decision`).
- Sin pelota: `_ancla_de_rol`, `_objetivo_sin_pelota`, `_buscar_apoyo` y los desmarques (apoyo, ruptura, arrastre, llegada; el 9 que baja y el que ocupa su hueco, la diagonal del extremo, el lateral que dobla, el cambio de frente).
- Defensa: `_planificar_defensa` (presionante, cobertura y cierre) con `_intensidad_de_presion`.
- Ritmo (circulación, aceleración, transición), marcador (urgencia), perfiles (`_construir_perfil`) y las jugadas de juego abierto: Paredes y Contragolpe.

**Qué es nuevo:**

- **Grilla de apoyo (Simple Soccer):** 12 × 8 casillas puntuadas desde la pelota por pase seguro por tiempos, `factor_geometria` y distancia justa. Las 3 mejores entran como candidatas de apoyo en los desmarques.
- **Línea defensiva:** sin la pelota, centrales y laterales se paran a la media de sus anclas.
- **Offside en el cuadro del pase:** `Cerebro::en_offside` mira la foto del momento en que sale la pelota. Se cuenta; cobrarlo es la etapa 6.
- **El cerebro planea con la física del mundo:** la canchita es un `Planeador`. Mientras el poseedor decide, el cerebro le pregunta el margen de cada pase (a los pies, al punto y globo) con el mismo cálculo con que después sale la pelota.

**El regate (BUG-012 de `docs/bugs_pendientes.md`, 2026-10-05):** la opción `gambeta` del motor espacial entra como `DEC_REGATE`. El cerebro elige a quién encarar y por dónde sale la pelota (`Cerebro::_salida_de_regate`). La canchita hace el toque con el clip del regate y sortea si el rival se come el amague (`Canchita::_amagar`). Nadie adjudica la pelota: el rival que se lo come sigue de largo 0,8 s y el que no, la puede sacar. En 60 partidos de quinta salen 7,2 regates por partido y el 45% deja la pelota en su equipo.

**Qué no entra todavía:** remate y arquero (etapa 5), pelota parada y jugadas preparadas de pelota parada (etapa 6), `_opciones_orientadas` (en el V2 el cuerpo gira de verdad y el pase de costado ya es más impreciso).

**Banco sin reglas:** la pelota que sale vuelve con un lateral, un córner o un saque de arco. Si un equipo controla la pelota en el área rival es una llegada y el otro saca del arco. Los once de cada equipo son los de la formación; el arquero juega con los pies (no ataja).

**Lo que cambió al medir** (todo en `tests/_diag_cerebro_v2.gd`, semilla 20261002, 4 minutos):

| Cambio | Por qué |
| --- | --- |
| Pasar antes de la cadencia con un rival a menos de 4 m | El motor espacial aguantaba la cadencia con la pelota pegada al pie y el robo era un duelo. Acá la pelota va suelta entre toques: 16 quites por minuto. |
| Riesgo del pase por su física (`Planeador`) | Con `riesgo_linea` solo se cortaba el 47% de los pases. |
| `castigo_corte` en globos | El pelotazo y el centro no tenían término de seguridad: eran la mitad de los pases y se cortaba el 50%. Con castigo en todos los pases el poseedor conducía el 74% de las veces. |
| `entrada_ventaja_seg` 0,1 → 0,5 | El que presiona se tiraba apenas llegaba 0,1 s antes: la mayoría de los quites eran tras un control. Las entradas de verdad (con ventana y falta) son de la etapa 6. |
| El que conduce aleja la pelota del rival | Como el control orientado. Sin esto la pelota iba hacia el que presionaba. |
| Pase al espacio: si el receptor llega antes, va el pase normal; el receptor pica a fondo | Salían pases a 16 m/s a 10 m que el receptor no alcanzaba. |
| `_alcance` de a 3 puntos en el partido | Con 22 jugadores era el 45% del costo del paso. |

| Medido (10 min, sin vista) | 20261002 | 20261003 | 20261004 |
| --- | --- | --- | --- |
| Posesiones / con 3+ pases / con 5+ / máximo | 98 / 10 / 3 / 6 | 86 / 10 / 1 / 5 | 98 / 8 / 2 / 6 |
| Pases por minuto / completos | 12,0 / 54% | 12,0 / 64% | 12,8 / 58% |
| Globos | 40% | 48% | 46% |
| Pases al espacio (llegan) | 22 (7) | 23 (14) | 12 (3) |
| Quites por minuto | 4,4 | 3,0 | 4,1 |
| Bloques: correlación con la pelota a lo largo (x) | 0,93 / 0,94 | 0,94 / 0,95 | 0,87 / 0,91 |
| A lo ancho (z) | 0,92 / 0,84 | 0,87 / 0,90 | 0,89 / 0,85 |
| Línea de atrás del que defiende | ±2,7 m | ±2,6 m | ±2,8 m |
| Correcciones de la pelota / SALTO_PELOTA / frenadas en seco | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 0 / 0 |
| Costo por paso | 9,5 µs | 8,6 µs | 9,0 µs |

- **Contra el motor espacial:** el mismo cruce en el motor actual (semilla 20261002) decide conducir el 51% de las veces y completa unos 10 pases por minuto de juego. El cerebro portado da la misma mezcla (48-52% conducir, 12 pases por minuto). Lo que el V2 no alcanza todavía es el porcentaje de pases completos: el motor espacial pierde el 15% por intercepción; el V2, del 32 al 42%.
- **Cuánto cuesta el cerebro:** el 14% del paso (planificar, decidir y los objetivos). El resto es el mundo de la etapa 3 con 22 cuerpos.
- **Laboratorio:** `motor_v2/laboratorio_cerebro.tscn`. Con pantalla muestra lo que cuenta el motor y la última decisión del poseedor con sus mejores opciones; un toque arma otro partido. Con `--headless` imprime con `[lab_cerebro]` (0,82 ms por paso con la vista en la nube).

**Pasa si, uno por uno:**

- **Posesiones de varios pases:** pasa. De 8 a 10 posesiones de 3 pases o más cada 10 minutos, y de 5 o más en las tres semillas.
- **Bloques que se desplazan con la pelota:** pasa. El centro de cada equipo sigue a la pelota con correlación de 0,87 a 0,95 a lo largo y 0,84 a 0,92 a lo ancho, y la línea de atrás se para junta (±2,7 m).
- **Pases al espacio que salen solos:** pasa. De 12 a 23 cada 10 minutos, al hueco o a la corrida preparada, y llegan de 3 a 14.

**Qué falta:**

1. Pases completos (54-64%): el motor espacial calibró sus pesos con otra intercepción. Es la calibración de la etapa 7. Los quites tras un control (el receptor tarda ~0,8 s en volver a tocarla) también.
2. Costo: 9 µs por paso en la nube son ~2,9 s por partido sin vista; en el teléfono (1,3 veces la nube en la etapa 0) serían ~3,8 s, por encima de los 3 s. Casi todo es el mundo de la etapa 3 con 22 cuerpos (`_alcance`, gatillos), no el cerebro.
3. Las corridas preparadas casi no reciben el pase (1 o 2 cada 10 minutos): los pases al espacio salen sobre todo al hueco por delante del receptor.
4. Patinaje en el partido: Frenada 1,24 m/s y los fundidos 2,24 m/s, más que en el laboratorio del cuerpo, porque el cerebro cambia de objetivo a 10 Hz.

### Etapa 5 — Remates y arqueros

- **Qué:** elección de punto y tipo de remate; modelo de error por tiro, pie malo, postura y presión; arquero que predice el cruce, elige parado, estirada o salida y resuelve agarre, rebote o no llega; rebotes jugables. Se reusan las animaciones de arquero que ya existen.
- **Pasa si:** porcentaje de remates al arco y de atajadas por división dentro de los rangos medidos hoy con `tests/_diag_embudo_remates.gd` (el arquero de primera ataja cerca del 63%).

#### Resultado (2026-09-30): pasa en las divisiones parejas

- **Revisión visual (2026-09-30):** el usuario miró los dos laboratorios en la PC.
  - `laboratorio_remate.tscn`: se ve muy bien. El remate, la comba, el globo, la estirada y el rebote se leen claros.
  - `laboratorio_cerebro.tscn`: hay pases correctos, corridas y goles, pero el juego parece al azar. Hay mucho pelotazo a cualquier lado, autopases, centros sin nadie en el área y una defensa que no se coordina. Coincide con lo medido en la etapa 4: del 40 al 48% de los pases son globos y se pierde del 32 al 42% (el motor espacial pierde el 15%). El usuario decidió seguir con la etapa 6 y dejar esto para la calibración de la etapa 7.
  - El laboratorio de remates tiraba `move_child` al arrancar: la etiqueta se movía antes de entrar al árbol. Ahora entra antes del primer remate.

Hecha en la PC. Test: `tests/test_remate_v2.gd`. Mediciones: `tests/_diag_remates_v2.gd` (el embudo por división) y `tests/_diag_arquero_v2.gd` (remates sueltos contra el arquero).

- **Código:**
  - `motor_v2/cpp/src/remate.h/.cpp`: `apuntar` (la patada que llega al punto pedido), `cruce_con_plano` y los parámetros del remate y del arquero.
  - `canchita.h/.cpp`: el remate, el arquero, el gol y el saque del medio. Modo nuevo `ARCO` (como `PRUEBA` pero en la cancha entera, con `rematar()`) para los tests y el laboratorio.
  - `cerebro/cerebro.h/.cpp`: la opción `DEC_REMATE` en `_evaluar` y `Cerebro::elegir_remate`. El `Planeador` suma `valor_remate`.
  - `CanchitaV2Nativa`: `configurar_remate`, `rematar`, `apuntar_prueba`, `registro_remates` y lecturas del arquero y de los goles. `FisicaV2` suma `parametros_remate()` y `parametros_arquero()`.
  - `data/fisica_v2.json` suma las secciones `remate` y `arquero`. El achique, la ventaja para salir y la regla parado/estirada salen de lo que ya existía: `data/utility_pesos.json` ("arquero") y `VistaCancha3D.PARADA_TRAVESIA_M`.
  - `tools/medir_clips_v2.gd` mide el contacto de las atajadas que faltaban (estirada a la izquierda, estirada alta, arriba y abajo): `data/acciones_v2.json` pasa de 17 a 22 clips con contacto.
- **Nadie adjudica:** el que remata elige punto y golpe. `apuntar` busca con la física de la pelota (sin viento, sin arco) la patada que cruza por ese punto. Al patear se suma el error. Gol, palo, afuera o atajada salen del vuelo y de la mano del arquero.

**El remate:**

- **Cuándo:** la opción `tiro` del motor espacial, con los mismos pesos (`tiro.base + tiro.geometria × factor_geometria`, habilitada por el rango de tiro). También de primera: el receptor en zona de tiro (`primera_geometria`) le pega de pie, de volea o de cabeza según la altura a la que le llega. Así los centros terminan en cabezazos. El que la recibe de espaldas al arco, adentro del área grande y con más tiro que cabezazo, le pega de chilena (`Canchita::_de_chilena`, BUG-013 de `docs/bugs_pendientes.md`).
- **Adónde:** `elegir_remate` prueba 15 puntos del arco (pegado al palo, a 1,35 m del palo y al medio; raso, a media altura y arriba) con cada golpe. El planeador (`valor_remate`) le da a cada uno la chance de ir adentro por la chance de que el arquero no llegue, con el mismo error y el mismo arquero que después juegan. Elige con softmax de temperatura baja.
- **Golpes:** colocado, fuerte, con efecto (45 rad/s de comba hacia el medio del arco), globo (sale a 40° y `apuntar` busca la rapidez) y cabeza. El raso sale por el piso: apuntado a 0,2 m de alto la patada salía en globo.
- **Error:** desvío del ángulo `error_rad` × (1 − 0,8 × tiro/100), por el golpe, hasta 1,5 con un rival encima, × (1 + de costado a adonde mira), por el pie malo, la volea y la pelota que llega rápida de primera. Los atributos van relativos al nivel del partido, como la puntería del motor espacial.

**El arquero:**

- **Lee la trayectoria:** si la pelota va a cruzar su línea entre los palos, después de su reacción (reflejos: 0,35 a 0,12 s) piensa en cada paso hasta tirarse. Esperando su turno y la reacción de los demás planeaba 0,27 s tarde.
- **Elige el clip:** el primer punto de su área al que llega una mano a tiempo, con Agarrar, Atajar_Abajo, Atajar_Arriba o las estiradas (baja y alta, a cada lado). Ataja parado solo si se corre hasta 1 m (la regla de la vista 3D actual). Se acomoda por debajo de `rapidez_para_girar`, así sigue mirando la pelota. Si nada llega, se tira igual.
- **Con qué toca:** parado, la mano (tolerancia de 0,25 a 0,5 m según estirada). En la estirada, el brazo entero, del hombro a la mano: con la mano sola, las pelotas que pasaban a 0,5-0,9 m del cuerpo no las tocaba nadie. Parado en su área, el cuerpo con los brazos abiertos (0,45 m de radio, 1,6 m de alto) también la frena.
- **Qué hace con la pelota:** la agarra, la da en rebote o la roza. La calidad sale de la pasada más cercana de la pelota a la mano, no del primer paso que entra en la tolerancia: con eso, la pelota rápida siempre entraba por el borde y todo era un roce. La que agarra la lleva en las manos 1,5 s (la vista dibuja `Arquero_Sostiene`) y la suelta para jugarla con el pie. El rebote sale hacia la cancha y al costado, y lo juega el que llega.
- **Sin remate encima:** sobre la bisectriz pelota-arco, 0,15 m adelante de la línea por cada metro de la pelota (entre 0,8 y 3 m). En el mano a mano achica (los pesos del motor espacial). Sale a una pelota suelta de su área solo si le gana al rival más rápido por `ventaja_base` + `ventaja_por_metro`: si no, salía a buscar la pelota que el delantero tenía en el área y le pateaban con él corriendo. Sale a los pies del rival que lleva la pelota en su área a menos de `achique_margen_pelota` (4 m) de él y se tira con `Atajar_Abajo` (BUG-014 de `docs/bugs_pendientes.md`). Al rival que se aleja del medio del arco no lo sigue: vuelve a su lugar.

**El gol:** la pelota entera pasa la línea entre los palos y abajo del travesaño. Después de 3 s de festejo (todos vuelven a su mitad caminando) se saca del medio. La llegada de la etapa 4 ya no termina la jugada: se cuenta una por posesión.

| Medido (`_diag_remates_v2`, 16 partidos de 45 min por pareja) | Al arco | Atajadas | Motor actual: al arco / atajadas | Abstracto |
| --- | --- | --- | --- | --- |
| D1/D1 | 61,7% | 53,2% | 53,0% / 55,4% | 61,3% / 47,8% |
| D5/D5 | 61,8% | 53,3% | 49,8% / 38,2% | 57,7% / 46,0% |
| D10/D10 | 66,0% | 51,1% | 56,4% / 45,6% | 64,8% / 46,8% |
| D1/D4 | 59,7% | 58,7% | 64,4% / 28,1% | 61,9% / 26,9% |
| D5/D8 | 61,3% | 54,5% | 56,2% / 26,2% | 63,2% / 27,5% |
| D10/D7 | 66,1% | 53,5% | 57,8% / 27,7% | 68,7% / 27,4% |

El motor actual y el abstracto salen de `_diag_embudo_remates.gd` (40 partidos por pareja: 20 planteles de ida y vuelta, semilla 97000). Al arco = gol + atajado sobre todos los remates (los bloqueados incluidos); atajadas sobre los remates al arco.

| Remate suelto contra el arquero (`_diag_arquero_v2`, tiro y arquero 70, colocado, 20 por punto) | Gol | Atajado |
| --- | --- | --- |
| Desde 11 m | 48% | 48% |
| Desde 16 m | 32% | 60% |
| Desde 22 m | 2% | 80% |
| Desde 28 m | 1% | 83% |
| Al medio / a 1,5 m / a 2,3 m / a 3,2 m del medio | 1% / 10% / 35% / 38% | 95% / 83% / 55% / 38% |

**Calibración:** con la reacción y la mano de arriba, el error del remate (`error_rad`) pasó de 0,07 a 0,12: con 0,07 iba al arco el 72% de los remates. Cambiar la reacción (0,25-0,06 o 0,4-0,15 s) o la mano (0,2-0,45 m) movió las atajadas menos que el ruido de 16 partidos (±3 puntos): el arquero pesa por dónde se para y cómo tapa, no por esos números.

**Pasa si, uno por uno:**

- **Al arco por división:** pasa. 62 a 66% en las parejas, dentro del 50-69% del motor actual y del abstracto.
- **Atajadas por división:** pasa en las parejas: 51 a 53%, dentro del 38-55%. **No pasa en las desparejas:** el arquero del equipo débil ataja 54-59%, contra 26-28% de los dos motores. En el V2 el equipo fuerte todavía no domina (D1 contra D4: 14,6 a 11,9 goles por partido); es la calibración de la etapa 7 ("el mejor equipo gane lo que tiene que ganar").
- **Sin correcciones:** 0 correcciones y `SALTO_PELOTA` = 0 en todos los partidos, también con la pelota en las manos (no es de la física mientras el arquero la lleva).

**Qué falta:**

1. **Volumen:** 60 a 95 remates y 21 a 28 goles por partido (el motor actual: 7 y 2,4). Sin offside, sin faltas y con 70 a 110 llegadas por partido, el V2 llega demasiado. Es la etapa 6 y la 7.
2. **Cabezazos:** 1,4 a 3,3 por partido y casi ningún gol (el motor actual: 0,9 y 40% de gol). Salen a 9-14 m/s y el arquero los agarra.
3. **Costo:** 5,9 µs por paso en esta PC: unos 1,9 s por partido sin vista. En el teléfono serían unos 5 s (2,6 veces la PC en la etapa 1), por encima de los 3 s del presupuesto, como ya pasaba en la etapa 4. `apuntar` corre solo al patear.
4. **Teléfono:** bibliotecas de Windows y Android rearmadas; la de Linux quedó vieja. Falta comparar la huella del partido V2 en la PC y en el teléfono (hasta ahora solo el banco de la etapa 0).
5. **Juego al azar en el partido:** ver la revisión visual. Pelotazos, autopases, centros sin nadie y defensa sin coordinar. Es la etapa 7.
6. **Clips:** no hay volea de costado ni cabezazo en carrera; el saque del arquero con la mano y el voleo quedan para la etapa 6.

### Etapa 6 — Reglas y pelota parada

- **Qué:** laterales, saques de arco, córners, faltas por contacto, tarjetas, offside, penales y tanda, cambios, lesiones, entretiempo con cambio de lado. Se reusa la lógica de ubicación de `_ubicar_para_el_balon_parado`, barrera y ejecutor.
- **Pasa si:** un partido de 90 minutos completo sin intervención, con todas las reanudaciones, y sin ningún corte de cámara por un jugador que camina 17 ticks hasta la línea.

#### Resultado (2026-10-01): pasa sin vista; la revisión visual encuentra fallas de juego

- **Revisión visual (2026-10-01):** el usuario miró `laboratorio_reglas.tscn` en la PC. Bibliotecas de Windows y Android rearmadas. `test_reglas_v2` da en Windows la huella 7809787842291322285. El usuario ve esto:
  - **Lateral:** las manos no agarran la pelota. La pelota queda a 1 m de la cabeza del que saca.
  - **Saque de arco:** el arquero se la pasa a los laterales y la pelota se les va siempre al lateral.
  - **Controles:** la pelota se les escapa en casi todos los controles. Después del control le queda a otro jugador.
  - **Control de pecho:** la pelota se va lejos antes de que el jugador vuelva a correr, y la pierde.
  - **Recepción:** al recibir un pase la pelota se mete un momento entre las piernas y el jugador no puede correr rápido.
  - **Frenada:** los jugadores resbalan como en hielo. No frenan a tiempo para controlar.
  - **Pelota suelta lejos:** dos jugadores pelean entre ellos lejos de la pelota. Otro jugador llega y se la lleva.
  - **Ataque por la banda:** nadie sube al área cuando un compañero avanza por la banda.
  - **Remates:** nadie le pega al arco.
  - **Pases y centros:** muchos son pelotazos a cualquier lado. Nadie cabecea.
  - **Conducción:** el jugador patea la pelota adelante y corre detrás de ella. El cerebro no tiene una decisión de "adelantar la pelota": es la conducción por toques a máxima velocidad.
  - **Sin revisar:** el usuario no vio goles, córners, tiros libres, penales, faltas, tarjetas, cambios ni segundo tiempo. El juego es tan al azar que en lo que miró no pasó nada de eso. El laboratorio sin pantalla da lo mismo en los primeros 10 minutos de su semilla: 0 goles, 6 laterales y 1 falta. Para revisar esas reanudaciones hay que apurar a x16 o armar un laboratorio que las fuerce.
  - Pelotazos, centros sin nadie y defensa sin coordinar ya estaban anotados en la revisión de la etapa 5. Controles, frenada, recepción y lateral son nuevos.
- **Segunda revisión visual (2026-10-01), con las reanudaciones forzadas:** en un partido normal el usuario no llegaba a ver las reanudaciones. Se arman dos laboratorios que las fuerzan y se arregla lo que el usuario ve en ellos.
  - **Laboratorios:** `motor_v2/laboratorio_reanudaciones.tscn` fuerza 11 escenas seguidas (córner, tiro libre con barrera, penal, falta con amarilla, con roja, con lesión y cambio, lateral, entretiempo, y córner, tiro libre y penal del visitante en el segundo tiempo). "N" pasa a la siguiente. `motor_v2/laboratorio_roja.tscn` muestra solo la roja y la repite. Los dos usan `laboratorio_reglas.gd` (`guion` y `solo`). Con `capturas=<carpeta>` el laboratorio guarda una imagen cada 0,5 s: así se revisó cada arreglo.
  - **Cómo se fuerzan:** `Canchita::forzar_parada`, `forzar_falta` y `forzar_fin_de_tiempo` (C++). Cortan el juego con las mismas funciones del partido (`_parar`, `_falta`, `_fin_de_tiempo`). El partido nunca las llama. La falta forzada espera un cruce de verdad: el que lleva la pelota con un rival a la distancia de la entrada.
  - **Lateral (arreglado):** el motor ponía la pelota a 2,1 m de alto y las manos del modelo llegan a 0,99 m. Ahora el motor la lleva donde las manos la sueltan (el punto de contacto del clip `Lateral`: 0,71 m de alto y 0,43 m adelante) y la vista la dibuja entre las manos mientras suben.
  - **Tarjetas (nuevo):** el usuario no veía la falta ni la tarjeta, y el juego seguía mientras el expulsado salía. El orden que pidió el usuario, y que quedó:
    1. Falta. El que la recibe cae y todos se quedan donde están.
    2. El árbitro (`motor_v2/arbitro_v2.gd`, capa visual como `OficialesPartido`) llega en 2 s como mucho, se para a 1,1 m del jugador de frente a la cámara y muestra la tarjeta (`Tarjeta_Completa`). El motor espera `tarjeta_seg` (4,5 s).
    3. Con roja, el expulsado sale corriendo (4,9 m/s) hacia el vestuario: el medio de la banda de la cámara.
    4. Cuando cruza la línea (con amarilla, enseguida), la jugada se corta al saque: cada uno aparece en su lugar y se saca a los 0,75 s. Es lo que hace `VistaCancha3D._cortar_despues_de_tarjeta`.
  - **El corte es un teletransporte a propósito.** Es el único del partido junto con el entretiempo. El detector de teletransportes no lo cuenta (el peor paso de un cuerpo sigue en 0,07 m).
  - **El que se va:** salía de espaldas porque seguía mirando la jugada; ahora mira adonde va. El cambiado sale al trote y el lesionado al paso, por la banda más cercana. El saque espera a que crucen la línea.
  - **Laboratorio:** la cámara se queda con el jugador mientras el árbitro muestra la tarjeta y se acerca (`VistaV2.acercamiento`); después sigue al que sale. Al armar la vista de nuevo (alguien entra o se va) la pantalla quedaba gris un cuadro: la vista vieja ahora tapa a la nueva hasta que dibuja.
  - **Test:** la prueba de expulsiones de `test_reglas_v2` subía `roja_por_falta` y esperaba que salieran rojas: daba de 0 a 8 según la semilla. Ahora fuerza dos rojas y una lesión, y controla que el saque espere al que se va.
  - **Huella:** el arreglo del lateral cambia el partido. `test_reglas_v2` da 4235184708021746737 en Windows (antes 7809787842291322285).
  - **Visto por el usuario:** la roja y el resto del guion se ven bien.
- **Tercera revisión visual (2026-10-01): cómo se juega.** El usuario miró partidos enteros en `laboratorio_reglas.tscn` y marcó lo que se veía mal. Cada arreglo se midió antes y después con la misma semilla: `tests/_diag_sensaciones_v2.gd` (4 partidos de 15 min, semilla 20261010) y `tests/_diag_reglas_v2.gd` (6 partidos de 20 + 20 min).

  | Lo que vio el usuario | Antes | Después |
  | --- | --- | --- |
  | Después de un control la pelota la toca un rival o sale | 18% | 10% |
  | Rapidez del que controla sin rivales a 6 m (1,5 s siguientes) | 2,7 m/s | 5,1 m/s |
  | Segundos con la pose de Frenada (22 jugadores, 120 s) | 284 s | 16 s |
  | Pie que patina en Frenada | 1,2 m/s | 0,44 m/s |
  | Del momento en que levanta el lateral al saque | 0,58 s | 1,5 s |
  | Controles de cabeza en 120 min / cabezazos al arco | 25 / 2 | 85 / 6 |

  - **Control ("la pelota tiene manteca"):** el control salía siempre a `control_ms` (1,5 m/s) y el que llegaba a 5 m/s la pasaba de largo. Ahora sale para quedarle `toque_corto_m` adelante a lo que corre (`Canchita::_tocar`), y más corta si hay un rival adelante (`_espacio_adelante`: el rival de adelante cuenta desde el doble de lejos que el de atrás). La conducción usa el mismo espacio y `toque_largo_m` baja de 1,8 a 1,4.
  - **"Juegan en hielo":** el que se acomodaba sin la pelota picaba a fondo para moverse 2 o 3 m y frenaba de golpe, una y otra vez. Ahora el que tiene su lugar a menos de 5 m llega frenando con `frenada_suave` (2,5 m/s², `Cuerpo::suave`). Con todos frenando suave había 40% más de goles: por eso es solo de cerca. En la vista, la Frenada empieza solo si el cuerpo está frenando de verdad y se suelta si el clip queda quieto.
  - **Pelota larga que nadie toma:** el más cercano la seguía al trote, a 3 m, 5 s sin alcanzarla. Ahora va a fondo si la pelota se aleja y el encuentro queda a más de 1,2 s.
  - **Predicción de la pelota (bug del motor):** la predicción llega a 5 s. Si nadie tocaba la pelota en ese tiempo, todos iban al último punto previsto y le pegaban al aire a 7 m: el partido quedaba trabado. Ahora se rehace cuando le queda 1 s.
  - **No pateaban hasta tener un rival encima:** durante la cadencia del control (0,5 a 2,25 s) el cerebro solo dejaba conducir, salvo con un rival a 4 m. Ahora el tiro claro (`Cerebro::TIRO_CLARO`, el `factor_geometria` de `remate.primera_geometria`) se patea siempre, y con un tiro claro el que conduce vuelve a decidir cada 0,5 s.
  - **Centros a nadie:** el centro vale 5 a 8 de utilidad (5,5 por la intención de centro del plan) y el riesgo le restaba 1. Ahora lo multiplica (`castigo_centro`). No se centra a menos de 11 m del arco, y el centro al punto genérico del área pide que el compañero llegue.
  - **Pase atrás hacia el arco propio:** no se da si la línea del pase cruza el arco.
  - **El que pasa no va a buscar su pase** durante 2,5 s si va hacia un compañero.
  - **Pelota por arriba:** Pecho y Cabecear no dejaban moverse hasta terminar (0,75 y 0,5 s). Ahora el gesto sigue pero el cuerpo queda suelto (`Cuerpo::suelto`) después del toque o del error. `cabeza_hasta` pasa de 1,3 a 1,8 m: cabecean saltando, y la vista lleva la frente a la pelota (`VistaV2._ajustar_cuerpo`).
  - **Lateral:** con la pelota en las manos espera `lateral_espera_seg` (1,5 s). El rebote en el cuerpo cuenta como último toque para saber quién saca (y el remate que rebota en un defensor es córner).
  - **Faltas:** el clip Caer se levanta solo y el jugador estaba 0,25 s en el piso. Ahora el clip se detiene en el piso (`Cuerpo::sosten_en`) y `caido_seg` pasa de 1,25 a 2,5.
  - **Entradas:** con la pelota más cerca del pie bajaron de 75 a 32 cada 40 minutos. `entrada_prob` pasa de 0,2 a 0,6: quedan 51, con 23 limpias y 12 faltas (antes 29 y 14,5).
  - **Árbitro:** mueve las piernas al correr (quedaba quieto en los cuadros en que el partido no avanzaba) y en una pelota parada se corre de la jugada (en el penal, al borde del área).
  - **Arquero:** la pelota agarrada se dibuja entre sus manos, y la vista lo estira para que las manos lleguen a la pelota que el motor da por atajada.
  - **Tests:** `test_cerebro_v2` miraba el plan de defensa viejo justo después de un cambio de posesión (pasaba por la semilla). Las huellas de `test_reglas_v2`, `test_remate_v2` y `test_cerebro_v2` cambian; `test_reglas_v2` da 8365591512941735158 en Windows.
  - **El balance cambió:** 14,2 goles y 52 remates cada 40 minutos (antes 8,8 y 31). El ataque ya no pierde la pelota sola. Es lo primero de la etapa 7.
  - **Sin arreglar (lo vio el usuario):** defiende uno solo y el resto vuelve a su zona; los delanteros no presionan la salida; siguen los pelotazos (33% de los pases); en los córners gana casi siempre el que defiende (8 de 10) y el 23% de los cabezazos erra. Falta que el usuario confirme en pantalla el árbitro, las atajadas y los cabezazos.

Hecha en la nube. Test: `tests/test_reglas_v2.gd`. Medición: `tests/_diag_reglas_v2.gd` (varias semillas). Laboratorio: `motor_v2/laboratorio_reglas.tscn`.

- **Código:**
  - `motor_v2/cpp/src/reglas.h`: los parámetros (`ParametrosReglas`), lo de cada jugador que leen las reglas (`FichaReglas`), los tipos de parada y los eventos.
  - `motor_v2/cpp/src/canchita_reglas.cpp`: la parte de `Canchita` que hace las reglas (la misma clase que `canchita.cpp`, en otro archivo). Se activan con `configurar_reglas`: sin reglas el PARTIDO sigue con las reanudaciones del banco y los tests de las etapas 4 y 5 dan las mismas huellas.
  - `canchita.cpp`: los enganches (pensar, gatillo, toques, rebotes, salidas, gol) y la entrada (`TOQUE_ENTRADA`).
  - `cerebro.h/.cpp`: `quitar` y `cambiar` (el que se va y el que entra; los planes vuelven a cero).
  - `CanchitaV2Nativa`: `configurar_reglas`, `configurar_reglas_equipo`, `agregar_suplente`, `reglas_de_fabrica`, `eventos`, `get_ids`, `get_energias`, `get_afuera` y `get_estado`. `FisicaV2` suma `parametros_reglas`, `reglas_del_club` y `reglas_de`. `CerebroV2.armar_partido(..., reglas, tanda)` arma el partido con el banco.
  - `data/fisica_v2.json`, sección `reglas`. Lo que ya existía sale de donde estaba: el tiro libre de `data/utility_pesos.json`, las medidas y el ejecutor del motor espacial, las franjas y el desgaste de `Cansancio`, las tarjetas de `MatchEngine` y `Arbitro`, los cambios de `Team`.
  - `motor_v2/partido_visto_v2.gd` (`PartidoVistoV2`): lo que lee la vista. Suma a los que salen y gira la cancha en el segundo tiempo. `VistaV2.ids` le pone su cara al que entra.
- **Nadie adjudica:** la falta sale del contacto: el pie de la entrada llega a las piernas del rival antes que a la pelota. El offside sale de la foto del pase. Gol, palo o atajada del penal salen del vuelo. Lo único que se sortea es lo que no es físico: la tarjeta, la lesión y el lado que elige el arquero en el penal.

**El reloj:** dos tiempos de 45 minutos con agregado (un minuto, más 30 s por gol, cambio y lesión y 15 s por tarjeta, hasta 5 minutos). El tiempo se cierra con la pelota lejos de un área o a los 30 s del final. En el entretiempo cada uno recupera parte de la energía (`MotorEspacial._recuperar_entretiempo`), entran los cambios y los equipos cambian de lado. El motor sigue con el equipo 0 atacando hacia +x: la vista gira la cancha 180° (`lado`) y el viento da la vuelta. Con `tanda`, el empate se define por penales.

**Las reanudaciones:** el juego se corta, la pelota que salió se repone en su lugar a 1 s y el ejecutor llega corriendo a su lugar. Nadie se teletransporta, salvo en el corte después de una tarjeta (ver la segunda revisión visual). Se saca cuando pasó la pausa mínima y los que tienen marca llegaron a 2 m de ella, o al tope pase lo que pase (`pausa_seg` y `espera_max_seg`). Mientras dura la parada nadie toca la pelota y los rivales respetan la distancia (9,15 m; 2 m en el lateral; afuera del área en el saque de arco).

- **Ejecutor** (`MotorEspacial._elegir_ejecutor`): el arquero en el saque de arco; el de más centros en el córner y en el tiro libre que se cuelga; el de más tiros libres en el directo; el de más tiro en el penal. Los tres, de los que están a 22 m. En el lateral y en el tiro libre corto, el que antes llega.
- **Lateral:** con las dos manos desde arriba de la cabeza (`Lateral_Prepara` y `Lateral`), en una parábola a un compañero libre entre 4 y 22 m. Sale desde la línea: con las manos afuera, la pelota que se soltaba contaba como otro lateral (297 seguidos en un partido).
- **Córner y tiro libre:** el tipo de tiro libre es el de `MotorEspacial.tipo_de_falta` (al arco, colgado o corto). Al área suben los de más amenaza aérea según el estilo (`Estilos.suben_al_corner`; dos menos en un centro de tiro libre, cuatro menos en un directo). Uno queda atrás y los demás esperan el rebote al borde del área. Cada defensor toma a uno, del lado del arco; los que sobran cuidan los palos y el punto penal. En el directo, barrera de 2 a 5 a 9,15 m (`MotorEspacial._tamano_barrera`).
- **El que saca con el pie** es el poseedor de una pelota quieta: el penal y el directo van al arco (`elegir_remate`), el córner y el centro de tiro libre a la cabeza del que más amenaza, el resto pide al cerebro un pase (un saque se juega, no se conduce).
- **El arquero con la pelota en las manos** (lo pendiente de la etapa 5): a un compañero libre con la mano (`Arquero_Lanza`); si no hay y lo apuran, de voleo (`Arquero_Voleo`); si no, la suelta y la juega con el pie.

**Offside:** en el cuadro del pase o del remate quedan anotados los compañeros adelantados (`Cerebro::en_offside`). Si uno de ellos juega la pelota antes de que la toque otro, es offside y tiro libre indirecto donde estaba. Un rebote o una atajada no lo habilitan. Del lateral, del saque de arco y del córner no hay offside.

**Faltas y tarjetas:** el defensor que contiene la pelota del rival a 2 m o menos se tira (`Barrida`) con una chance por cada vez que piensa según quite y barrida; ya amonestado, con el 40%. Si su pie pasa a 0,35 m del medio de un rival antes de tocar la pelota, es falta. En un cruce de dos piernas en la pelota, el que pierde puede pegarle al otro. La gravedad sale de la rapidez del que entra y de si entra de atrás. La tarjeta es la tirada de `MatchEngine._chequear_tarjeta` con la falta de verdad: 0,18 amarillas por falta (lo del fútbol real) por la gravedad, roja directa con la razón de `MatchEngine`, dos amarillas roja. El expulsado sale caminando y el equipo sigue con diez. Con menos de siete se suspende. La falta en el área es penal. **Punto de contacto de la entrada:** el de `Barrida` está a 0,37 m (la tibia); con su alto la entrada no tocaba ninguna pelota, así que la entrada usa la franja del pie.

**Penales:** todos afuera del área y a 9,15 m, el arquero en la línea. El arquero no espera a leer la patada: elige lado y se tira en la patada, y adivina con chance 0,55. Esperando su reacción no llegaba a ninguno (11 de 11 adentro). En la tanda patean de a uno, alternados, cada equipo en el arco que atacó; los demás miran desde el círculo central.

**Lesiones, energía y cambios:** la energía baja con el desgaste de `Cansancio` cobrado según cuánto corre cada uno; la franja baja punta y aceleración. El que recibe una falta se puede lesionar (`Lesiones.evaluar_riesgo` por el cansancio y la gravedad): queda en el piso y sale en la parada siguiente. Los cambios entran en las paradas largas (saque de arco, tiro libre, saque del medio) y en el entretiempo: sale el lesionado y, desde el minuto 55, el que bajó del umbral del club (`MatchEngine._procesar_cambios_equipo`); entra el de más media del banco en su puesto, frente al banco, y el saque espera a que pise la cancha. El que sale camina hasta el lateral.

| Medido (`_diag_reglas_v2`, 10 partidos de 90 min, semilla 20261010) | Media por partido | Mínimo-máximo |
| --- | --- | --- |
| Minutos jugados (con el agregado) | 99,3 | 96,0-100,7 |
| Saques del medio / laterales / saques de arco / córners / tiros libres / penales | 20,7 / 31,5 / 24,3 / 5,8 / 34,0 / 0,9 | |
| Lateral: del corte al saque | 1,9 s | máximo 5,6 s |
| Laterales de más de 4,25 s (17 ticks), todos con el ejecutor corriendo | 1,4 | 0-4 |
| Veces que el ejecutor del lateral camina hacia la línea (medio segundo seguido) | 0 | 0 |
| Saques con el ejecutor lejos de la pelota | 0 | 0 |
| Entradas / limpias / faltas de entrada / faltas de cruce | 137 / 52 / 26,8 / 1,3 | |
| Faltas | 28,1 | 21-36 |
| Amarillas / rojas (directas) | 4,8 / 0,5 (0,1) | 3-8 / 0-2 |
| Offside cobrados | 6,8 | 1-20 |
| Penales (convertidos) | 0,9 (0,6) | 0-2 |
| Lesiones / cambios | 0,7 / 6,4 | 0-2 / 1-10 |
| Tiros libres cortos / colgados / directos | 23,5 / 9,4 / 1,1 | |
| Saques del arquero con la mano | 15,0 | 7-25 |
| Goles | 18,7 | 7-29 |
| Correcciones de la pelota / SALTO_PELOTA / peor paso de un cuerpo | 0 / 0 / 0,07 m | máximo 0,16 m |
| Costo del partido sin vista (en la nube) | 2,5 s | 2,2-3,9 s |

| Penales (tandas de 8 partidos cortos empatados) | Medido | Fútbol real |
| --- | --- | --- |
| Adentro | 77% (54 de 70) | 75-78% |

- **Laboratorio:** con pantalla muestra el reloj, el marcador, la parada en curso y lo último que pasó; las flechas apuran hasta x16 para llegar al segundo tiempo y "R" arma otro partido. Con `--headless` simula `segundos=N` con la vista dibujando e imprime con `[lab_reglas]` (0,35 ms por paso con la vista en la nube; cruza el entretiempo y arma la vista de nuevo en cada cambio).

**Pasa si, uno por uno:**

- **Un partido de 90 minutos completo sin intervención:** pasa. Los tres partidos del test y los diez de la medición terminan solos, con dos tiempos y su agregado. La tanda termina con un ganador.
- **Con todas las reanudaciones:** pasa. Saque del medio, lateral, saque de arco, córner, tiro libre (corto, colgado y directo) y penal aparecen y se sacan todos.
- **Sin ningún corte de cámara por un jugador que camina hasta la línea:** pasa. El ejecutor del lateral nunca camina: llega corriendo y en 1,9 s de media. Hay 1,4 laterales por partido que tardan más de los 17 ticks (4,25 s) del motor espacial, siempre con el ejecutor corriendo 20 a 30 m: se ven enteros, no hay nada que cortar. Nadie aparece encima de la pelota y nadie salta más de 0,16 m entre pasos.

**Qué falta:**

1. **Calibración (etapa 7):** goles (18,7 por partido), offside (6,8 de media y hasta 20 en un partido), penales (0,9 por partido, el real 0,3), amarillas (4,8) y rojas (0,5, casi todas por doble amarilla: el que presiona junta las faltas). Las lesiones y los cambios son del orden del motor espacial.
2. **El córner y el tiro libre esperan casi siempre el tope (8 s):** los que van al área no llegan a 2 m de su marca. Se ve a los que llegan corriendo al área; se puede bajar el tope o la exigencia si en la revisión visual se hace largo.
3. **Ventaja y bote a tierra:** el árbitro cobra toda falta (no da ventaja) y no hay bote a tierra: la lesión sale solo de una falta, y el lesionado se va en la parada siguiente.
4. **Tanda en dos arcos:** cada equipo patea en el arco que atacó (el motor tiene a cada equipo atacando siempre el mismo arco).
5. **El voleo del arquero casi no sale:** los rivales se alejan mientras tiene la pelota en las manos y casi siempre hay un compañero libre para la mano.
6. **Vista:** el árbitro está y muestra las tarjetas. Faltan los asistentes, el cuarto árbitro con el tablero del cambio y las repeticiones. La integración con relato, estadísticas, HUD y minimapa (que leen `eventos`) es la etapa 8.
7. **Bibliotecas:** Windows y Android rearmadas con los arreglos de la tercera revisión visual. **Falta rearmar la de Linux** en la nube y comparar la huella de `test_reglas_v2` (8365591512941735158 en Windows) con la de Linux y la del teléfono.
8. **Fallas de la revisión visual que siguen:** ver "Sin arreglar" en la tercera revisión visual. La defensa (más de uno defendiendo y presión de los delanteros) es un rediseño del plan heredado del motor espacial y conviene hacerlo antes de calibrar.
9. **Las mediciones de arriba son anteriores a la segunda y la tercera revisión visual:** goles, remates, entradas, faltas y tiempos de parada cambiaron. La etapa 7 empieza midiendo de nuevo.

### Etapa 7 — Calibración

- **Qué:** 200 partidos por división sin vista. Se ajustan `utility_pesos.json` y el modelo de error hasta que goles, remates, posesión, pases, faltas y tarjetas caigan en los rangos del motor actual (sección 11 de `docs/motor_espacial.md`) y el mejor equipo gane lo que tiene que ganar.
- **Pasa si:** el reporte por división queda dentro de rangos en dos semillas distintas.

#### Resultado (2026-10-01): pasa por división en dos semillas; el cruce de tres divisiones queda corto

Hecha en la PC. Medición: `tests/_diag_calibracion_v2.gd` (el reporte). Tests: `tests/test_reglas_v2.gd` y `tests/test_remate_v2.gd`.

**Decisión del usuario (2026-10-01): el partido dura 4 minutos de verdad.**

- El motor espacial juega 2 minutos de verdad por tiempo y el reloj muestra 0-90 (`MotorEspacial.SEGUNDOS_POR_MITAD`). El V2 jugaba 45 minutos de verdad por tiempo.
- Con 90 minutos de verdad el V2 daba 35 goles, 115 remates y 1.146 pases por partido. Los mismos 4 minutos del motor espacial dan 1,6 goles, 5 remates y 51 pases (el motor espacial: 1,5, 7 y 45).
- El V2 ahora dura lo mismo. `FisicaV2.parametros_reglas()` pasa `segundos_tiempo` (120) y `minutos_tiempo` (45) desde las constantes del motor espacial: una sola fuente.
- **Reloj mostrado:** `Canchita::minuto()` (0 a 90 y el agregado). `get_estado()["minuto"]` y cada evento (`minuto`) lo traen. La urgencia del marcador, los cambios desde el minuto 55 y el desgaste por minuto usan ese reloj.
- **El reloj corre solo con la pelota en juego.** En una pelota parada espera (`_pasos_parados`). Así una tarjeta de 4,5 s no se come 100 segundos del reloj mostrado. Un partido dura de verdad 5,3 minutos de media y 6,4 el más largo (300 partidos).
- **Adición:** los `adicion_*_seg` son segundos del reloj mostrado (60 s son 2,7 s de verdad).
- **Cierre:** un tiempo cumplido sigue como mucho `cierre_max_seg` (22,5 s, los `TICKS_DE_DESCUENTO` del motor espacial) si la jugada no está tranquila.
- **Costo:** 0,21 s por partido sin vista en la PC, con 16 procesos a la vez (el de 90 minutos, 3,5 s). En el teléfono no se midió: con las 2,6 veces de la etapa 1 son unos 0,6 s, dentro del presupuesto de 3 s.

**Dos bugs que tapaba el reloj.** Con el reloj corriendo siempre, un saque que no salía terminaba igual a los 45 minutos y el partido quedaba vacío. Con el reloj parado en las paradas, el partido no termina: así aparecieron.

- **Saque inicial:** el delantero de punta arrancaba 0,6 m adentro de la mitad rival, cruzado con el del otro equipo. Los dos se empujaban de frente y el saque no salía (5 de 60 partidos). Ahora arrancan en el lugar de cualquier saque del medio (`_ubicar_saque_del_medio`).
- **Saque del medio:** sacaba el que antes llegaba. Con un volante más rápido que el de punta, el volante chocaba de atrás con el de punta y no llegaba (8 de 300 partidos desparejos). Ahora saca el más cercano. Además, pasado el tope se elige a otro ejecutor, no al mismo.
- El reporte cuenta los partidos colgados (más de 20 minutos de verdad): 0 en 6.400.

**Qué se compara.** Los mismos planteles y la misma semilla en los dos motores, ida y vuelta. 16 parejas: las 10 divisiones parejas, 3 de divisiones vecinas (el caso de una liga) y 3 con tres divisiones de diferencia (un cruce de copa). El rango de cada cosa va alrededor del motor espacial:

| Cosa | Rango |
| --- | --- |
| Goles, remates, pases completos | ± 20% |
| Pases intentados (sin los despejes), faltas | ± 25% |
| Amarillas | ± 30% (o 0,3) |
| Rojas | ± 0,08 |
| Posesión de A | ± 5 puntos |
| Puntos de A (solo divisiones distintas) | ± 0,3 |
| Diferencia de gol de A (solo divisiones distintas) | ± 20% (o 0,4) |

Remates al arco, offside y penales se muestran y no cuentan: la etapa pide goles, remates, posesión, pases, faltas y tarjetas. Con 200 partidos el error de la media de los goles es 0,1 (5%).

**Qué se ajustó**, de a una cosa, midiendo antes y después con la misma semilla. El porqué de cada número está en `data/fisica_v2.json` (`_notas`).

| Qué | Antes | Ahora | Motor espacial | Cómo |
| --- | --- | --- | --- | --- |
| Primera le gana a cuarta | 56% | 90% | 98% | `nivel.rapidez_por_punto` y `rapidez_tope` |
| Quinta le gana a sexta | — | 66% | 64% | lo mismo |
| Goles en D1 / D5 / D10 | 2,11 / 1,45 / 1,18 | 2,26 / 2,00 / 1,56 | 2,31 / 2,26 / 1,65 | remates más fuertes, arquero que reacciona más tarde y con reflejos absolutos |
| Remates en D1 / D5 / D10 | 7,0 / 5,5 / 4,4 | 7,7 / 6,1 / 4,8 | 8,2 / 7,3 / 5,1 | `cerebro.tiro_factor` 1,8 y `remate.primera_geometria` 0,2 |
| Remates que van al arco | 68% | 60% | 56% | `remate.error_rad` 0,15 |
| Faltas en D1 / D5 / D10 | 0,78 / 0,87 / 0,94 | 1,95 / 2,43 / 2,64 | 2,24 / 2,44 / 3,13 | entradas desde 3,6 m, nunca de atrás, y el torpe hace más faltas |
| Amarillas en D1 / D5 / D10 | 0,22 / 0,22 / 0,23 | 0,91 / 1,15 / 1,25 | 0,95 / 1,00 / 1,36 | `amarilla_por_falta` 0,46 y la gravedad contra la punta del que entra |
| Faltas del favorito / del otro (D5 contra D8) | 3,3 / 0,3 | 2,7 entre los dos | 2,5 entre los dos | `entrada_sobrado`: el más rápido no se tira |

- **Lo que hace ganar al mejor es la rapidez.** Se probó cada palanca en primera contra cuarta. Estirar el error de pase y de control cuatro veces: gana el 60% (antes 54%). Estirar el remate y el arquero tres veces: 59%. Darle 18% más de punta al mejor y 18% menos al otro: 93%.
- **La ventaja es del equipo, con tope de 20%.** Por jugador y sin tope, en un partido parejo el mejor corría a 11,4 m/s y el peor a 3,4.
- **Código nuevo en C++:** `segundos_tiempo`, `cierre_max_seg`, `entrada_de_atras`, `entrada_sobrado`, `entrada_en_area`, `falta_torpeza` y `gravedad_a_fondo` (`reglas.h`); `tiro_factor` (`cerebro.h`); el contador `pases_despeje`. `gravedad_rapidez_ms` se va.

**Semilla 97000, 200 partidos por división (V2 / motor espacial):**

| División | Goles | Remates | Posesión de A | Pases | Completos | Faltas | Amarillas | Rojas | Veredicto |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| D1 | 2,26 / 2,31 | 7,66 / 8,15 | 50,8% / 49,0% | 49,7 / 45,8 | 33,8 / 36,8 | 1,95 / 2,24 | 0,91 / 0,95 | 0,04 / 0,04 | pasa |
| D2 | 2,03 / 2,21 | 7,15 / 7,91 | 50,3% / 48,5% | 50,6 / 45,9 | 33,8 / 36,7 | 2,15 / 2,23 | 1,00 / 1,06 | 0,05 / 0,07 | pasa |
| D3 | 2,10 / 2,22 | 6,79 / 7,63 | 51,2% / 49,0% | 52,1 / 46,1 | 34,6 / 36,6 | 2,23 / 2,29 | 1,00 / 1,01 | 0,07 / 0,10 | pasa |
| D4 | 2,02 / 2,13 | 6,44 / 7,46 | 50,9% / 49,6% | 52,6 / 46,0 | 35,4 / 36,5 | 2,20 / 2,31 | 1,05 / 1,01 | 0,07 / 0,07 | pasa |
| D5 | 2,00 / 2,26 | 6,08 / 7,29 | 51,0% / 49,4% | 53,7 / 46,2 | 36,0 / 36,9 | 2,43 / 2,44 | 1,15 / 1,00 | 0,04 / 0,06 | pasa |
| D6 | 1,70 / 1,75 | 5,62 / 6,76 | 50,5% / 49,5% | 51,3 / 46,3 | 34,6 / 36,3 | 2,32 / 2,65 | 1,09 / 1,14 | 0,06 / 0,07 | pasa |
| D7 | 1,89 / 1,92 | 5,72 / 6,22 | 51,2% / 50,2% | 50,7 / 45,6 | 34,8 / 36,3 | 2,58 / 2,63 | 1,16 / 1,14 | 0,09 / 0,10 | pasa |
| D8 | 1,59 / 1,72 | 5,08 / 6,12 | 51,5% / 49,7% | 47,8 / 44,5 | 32,9 / 35,3 | 2,45 / 2,69 | 1,16 / 1,19 | 0,07 / 0,07 | pasa |
| D9 | 1,53 / 1,78 | 4,79 / 5,34 | 51,6% / 50,2% | 47,1 / 43,9 | 33,3 / 34,5 | 2,54 / 3,02 | 1,21 / 1,26 | 0,08 / 0,09 | pasa |
| D10 | 1,56 / 1,65 | 4,79 / 5,12 | 50,9% / 49,8% | 44,6 / 42,6 | 31,1 / 33,6 | 2,64 / 3,13 | 1,25 / 1,36 | 0,09 / 0,10 | pasa |

| Pareja | Goles | Gana A | Puntos de A | Diferencia de gol de A | Posesión de A | Faltas | Veredicto |
| --- | --- | --- | --- | --- | --- | --- | --- |
| D1/D2 | 2,35 / 2,48 | 54% / 59% | 1,88 / 2,00 | 0,70 / 1,00 | 51,5% / 51,9% | 2,33 / 2,25 | pasa |
| D5/D6 | 2,17 / 2,33 | 66% / 64% | 2,23 / 2,14 | 1,22 / 1,25 | 53,0% / 52,3% | 2,52 / 2,50 | pasa |
| D10/D9 | 1,91 / 1,89 | 4% / 15% | 0,39 / 0,70 | -1,24 / -1,08 | 48,0% / 46,6% | 2,67 / 3,10 | no pasa (puntos_a) |
| D1/D4 | 3,04 / 4,12 | 90% / 98% | 2,78 / 2,96 | 2,56 / 3,82 | 52,9% / 59,1% | 2,25 / 2,20 | no pasa (goles, posesion_a, dif_a) |
| D5/D8 | 2,94 / 3,38 | 93% / 93% | 2,85 / 2,84 | 2,54 / 3,15 | 54,0% / 56,7% | 2,67 / 2,46 | no pasa (amarillas) |
| D10/D7 | 3,38 / 3,07 | 0% / 1% | 0,02 / 0,10 | -3,17 / -2,87 | 45,1% / 42,3% | 2,56 / 2,68 | pasa |

**Semilla 20261001, 200 partidos por división (V2 / motor espacial):**

| División | Goles | Remates | Posesión de A | Pases | Completos | Faltas | Amarillas | Rojas | Veredicto |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| D1 | 2,36 / 2,31 | 7,92 / 8,34 | 51,0% / 49,4% | 49,5 / 45,7 | 33,9 / 36,9 | 2,02 / 1,89 | 0,94 / 0,85 | 0,04 / 0,01 | pasa |
| D2 | 2,29 / 2,34 | 7,39 / 8,09 | 50,8% / 49,5% | 51,7 / 45,9 | 35,0 / 36,6 | 2,27 / 2,12 | 1,14 / 0,91 | 0,05 / 0,08 | pasa |
| D3 | 2,24 / 2,13 | 6,96 / 7,92 | 50,9% / 49,6% | 52,5 / 45,9 | 35,1 / 36,7 | 2,23 / 2,15 | 0,98 / 0,96 | 0,04 / 0,06 | pasa |
| D4 | 1,98 / 2,06 | 6,42 / 7,42 | 50,6% / 48,5% | 52,1 / 46,3 | 34,9 / 36,5 | 2,19 / 2,33 | 1,18 / 1,14 | 0,06 / 0,06 | pasa |
| D5 | 2,00 / 2,21 | 6,17 / 7,34 | 51,0% / 49,4% | 52,8 / 46,5 | 35,5 / 36,5 | 2,40 / 2,40 | 1,21 / 1,09 | 0,08 / 0,05 | pasa |
| D6 | 1,89 / 1,95 | 6,21 / 6,92 | 51,4% / 50,3% | 52,0 / 46,4 | 35,1 / 36,6 | 2,53 / 2,44 | 1,18 / 1,09 | 0,06 / 0,06 | pasa |
| D7 | 1,83 / 1,75 | 5,72 / 6,36 | 50,3% / 49,0% | 51,5 / 45,6 | 34,8 / 36,0 | 2,69 / 2,67 | 1,22 / 1,23 | 0,06 / 0,08 | pasa |
| D8 | 1,69 / 1,63 | 5,45 / 5,92 | 50,6% / 49,7% | 48,2 / 44,6 | 33,2 / 35,2 | 2,50 / 2,74 | 1,25 / 1,25 | 0,07 / 0,07 | pasa |
| D9 | 1,73 / 1,63 | 5,26 / 5,43 | 51,7% / 50,3% | 46,8 / 43,5 | 32,8 / 34,5 | 2,94 / 2,98 | 1,39 / 1,35 | 0,09 / 0,10 | pasa |
| D10 | 1,45 / 1,55 | 4,75 / 5,03 | 51,1% / 49,1% | 44,9 / 41,9 | 31,9 / 33,2 | 2,54 / 3,13 | 1,03 / 1,43 | 0,04 / 0,12 | pasa |

| Pareja | Goles | Gana A | Puntos de A | Diferencia de gol de A | Posesión de A | Faltas | Veredicto |
| --- | --- | --- | --- | --- | --- | --- | --- |
| D1/D2 | 2,25 / 2,56 | 63% / 65% | 2,10 / 2,14 | 0,98 / 1,10 | 51,6% / 52,1% | 2,09 / 2,01 | pasa |
| D5/D6 | 2,19 / 2,25 | 69% / 65% | 2,29 / 2,13 | 1,25 / 1,08 | 52,6% / 53,1% | 2,48 / 2,44 | pasa |
| D10/D9 | 1,95 / 1,78 | 8% / 14% | 0,46 / 0,67 | -1,16 / -0,95 | 48,0% / 46,7% | 2,73 / 2,96 | pasa |
| D1/D4 | 3,00 / 4,16 | 90% / 96% | 2,78 / 2,90 | 2,40 / 3,94 | 52,4% / 59,1% | 2,39 / 2,19 | no pasa (goles, posesion_a, dif_a) |
| D5/D8 | 3,09 / 3,58 | 93% / 94% | 2,85 / 2,87 | 2,77 / 3,34 | 54,3% / 58,0% | 2,43 / 2,31 | pasa |
| D10/D7 | 3,56 / 3,19 | 0% / 2% | 0,04 / 0,14 | -3,32 / -2,94 | 45,9% / 42,5% | 2,51 / 2,70 | pasa |

**Pasa si, uno por uno:**

- **El reporte por división queda dentro de rangos en dos semillas distintas:** pasa. Las 10 divisiones, en las semillas 97000 y 20261001.
- **El mejor equipo gana lo que tiene que ganar, en una liga:** pasa. Divisiones vecinas: 5 de 6 dentro de rango. En D10 contra D9 de la semilla 97000 el favorito suma de más (0,39 puntos para el otro contra 0,70; el rango es 0,3).
- **El mejor equipo gana lo que tiene que ganar, con tres divisiones de diferencia:** pasa en D5/D8 y D10/D7 (3 de 4; en una, las amarillas quedan 0,36 arriba). **No pasa en D1/D4:** el favorito gana el 90% (98%) por 2,5 goles (3,8), con 53% de posesión (59%). Es el tope de 20% de rapidez: con la ventaja por jugador y sin tope ganaba el 98% por 3,2 goles, con jugadores a 12 m/s.
- **Sin correcciones:** 0 correcciones, `SALTO_PELOTA` = 0 y 0 partidos colgados en 6.400 partidos.

**Qué falta:**

1. **Pases que se pierden:** el V2 completa el 67% de los pases (el motor espacial, el 80%). Los rivales cortan unos 20 pases por partido. Las palancas del planeador (`riesgo_margen_seguro`, `castigo_corte`), el pase más firme y la reacción más lenta no lo mueven. Es la defensa heredada del motor espacial: lo que vio el usuario en la etapa 6 ("juego al azar", pelotazos) sigue.
2. **Globos:** del 30 al 37% de los pases. No se midieron contra el motor espacial.
3. **D1 contra D4:** ver arriba. Decisión abierta: subir el tope de rapidez, o buscar otra palanca que no sea la rapidez.
4. **Offside:** 0,06 a 0,21 por partido en parejos (el motor espacial: 0,05 a 0,14) y 0,25 a 0,36 en los desparejos (0,11 a 0,17). El favorito, más rápido, queda adelantado.
5. **Bibliotecas:** Windows y Android rearmadas. **Falta rearmar la de Linux.** `test_reglas_v2` da en Windows la huella 4552426272061715690 (cambia: reloj, saque del medio y valores nuevos). Falta compararla con la del teléfono.
6. **Revisión visual:** el usuario no miró todavía el partido de 4 minutos en `laboratorio_reglas.tscn`. Remates más fuertes, entradas desde más lejos y la ventaja de rapidez cambian cómo se ve.
7. **`Cerebro::TIRO_CLARO`** sigue en 0,3 y `remate.primera_geometria` pasó a 0,2: ya no son el mismo número.

#### Resultado (2026-10-01): revisión visual del partido de 4 minutos

El usuario miró `laboratorio_reglas.tscn` y marcó siete fallas. Medición nueva: `tests/_diag_pases_v2.gd` (cómo termina cada pase, por tipo). Los números son de 200 partidos de quinta, semilla 97000, salvo que diga otra cosa. **Las tablas, el "pasa si" y el "qué falta" del resultado de arriba quedaron viejos: valen los de acá.**

**Herramientas nuevas:**

- **`CanchitaV2Nativa.registro_pases()`:** cada pase del partido. Trae quién lo da, a quién, el tipo (la decisión del cerebro), el margen que le dio el planeador al patear y cómo termina: lo toca el receptor, otro compañero, el mismo, un rival, el arquero o nadie.
- **Contadores de gestos:** `gestos_<parte>` y `fallos_<parte>` (pie, muslo, pecho, cabeza), y de los que erran, cuántos quedaron lejos en el piso o a otra altura.
- **`laboratorio_reglas.tscn`:** `cada=N` y `dura=N` cambian cada cuánto captura y hasta cuándo. Con `cada=0.1` se ve un gesto cuadro por cuadro.

| Lo que vio el usuario | Qué era | Antes | Después |
| --- | --- | --- | --- |
| Pases a la nada; el que la da va a buscar su pase | El cerebro elegía pases que el planeador ya veía cortados | 14,6 pases al hueco por partido, 46% cortados | 0,56 por partido, 22% cortados |
| Lo mismo | — | Llega a un compañero el 61% de los pases | 72% (el pase a los pies, 87%) |
| La pasan de taco para atrás | El que patea va derecho a la pelota y la manda adonde sea | 43% de los pases de espaldas a adonde mira | 20% |
| Sacan del medio antes de que todos estén en su lado | El saque esperaba 6 s como mucho | — | Espera a que cada uno cruce la mitad (11 a 14 s después del gol) |
| El que la pierde cerca se vuelve a su puesto | Solo presionaba uno, el del plan de defensa | — | También va el que llega a la pelota en menos de 1 s |
| El lateral sale de la panza | Al terminar `Lateral_Prepara` los brazos bajaban; y llegaba de espaldas a la cancha | — | Gira hacia la cancha, levanta la pelota y la sostiene hasta lanzarla |
| El juez se mete en el medio en las faltas | Se paraba hacia el medio de la cancha, en la línea del pase | — | Detrás de la pelota y al costado, hacia la banda de enfrente |
| No cabecean los centros, le erran | Ver "Qué falta" | El que lo espera lo toca el 14% | 13%: sin arreglar |

**Pases:**

- **El dato:** el margen del planeador predice bien. Con margen negativo (un rival llega antes) se cortaba el 57% de los pases al hueco; con más de 0,5 s, el 8%. El cerebro elegía igual 11 de cada 14,6 con margen negativo: la seguridad era un término más de la utilidad.
- **`cerebro.riesgo_maximo` (0,8):** el pase, el pase al hueco, la pared y el globo con más riesgo que eso no se ofrecen.
- **El margen mira también el punto de llegada (`Canchita::_margen_destino`):** en el pase al espacio y en el globo cuenta el rival que llega al punto antes que el receptor, no solo el que corta el camino de la pelota.
- **`cerebro.pase_seguro_extra` (3):** con el tope solo, los pases bajaban de 56 a 36 por partido (el motor espacial: 46). El que no tenía pase seguro conducía. Con el premio al pase seguro son 41.
- **`cerebro.castigo_espaldas` (3):** el pase de espaldas a adonde mira pierde utilidad.
- **Los despejes no cuentan como pases** en el reporte de calibración (`pases_despeje`): el motor espacial no los cuenta.

**Saque del medio:**

- Espera a que cada uno esté en su mitad, hasta 30 s. El reloj espera en las paradas: no cuesta tiempo de juego.
- **Bug de esta misma etapa:** pasado el tope se elegía a otro ejecutor aunque el primero ya estuviera en su lugar esperando a los demás. El que dejaba de sacar se quedaba sin lugar y se iba a atacar. Ahora se cambia solo si no llegó, y se vuelven a marcar los lugares.

**Presión (`cerebro.contrapresion_seg`, 1 s):** `Canchita::_segundo`. Con dos presionando las faltas subían a 3,3-3,8 por partido: `entrada_dist_m` baja de 3,6 a 2,8 y `entrada_en_area` de 0,5 a 0,35.

**Lateral:**

- `Cuerpo::sosten_en` detiene `Lateral_Prepara` con la pelota arriba hasta el saque (el clip dura 0,75 s y la espera 1,5 s).
- Levanta la pelota cuando ya gira hacia la cancha (a 0,5 rad), o a los 2 s de llegar.
- Con la pelota en las manos saca desde donde quedó: el que llegaba rápido frenaba 1,7 m más allá, dejaba de "haber llegado" y el lateral no salía.

**Recalibración.** Con estos cambios subieron los goles y bajaron los pases. Se ajustó: reacción del arquero 0,44-0,21 s (era 0,5-0,25) y `nivel.rapidez_tope` 0,25 (era 0,2).

**Semilla 97000, 200 partidos por división (V2 / motor espacial):**

| División | Goles | Remates | Posesión de A | Pases | Completos | Faltas | Amarillas | Rojas | Veredicto |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| D1 | 2,14 / 2,31 | 7,43 / 8,15 | 49,7% / 49,0% | 37,6 / 45,8 | 32,9 / 36,8 | 1,72 / 2,24 | 0,70 / 0,95 | 0,01 / 0,04 | pasa |
| D2 | 2,31 / 2,21 | 7,51 / 7,91 | 49,8% / 48,5% | 39,1 / 45,9 | 33,7 / 36,7 | 2,22 / 2,23 | 1,01 / 1,06 | 0,05 / 0,07 | pasa |
| D3 | 2,19 / 2,22 | 7,26 / 7,63 | 50,3% / 49,0% | 40,2 / 46,1 | 33,7 / 36,6 | 2,04 / 2,29 | 0,94 / 1,01 | 0,03 / 0,10 | pasa |
| D4 | 2,15 / 2,13 | 6,59 / 7,46 | 51,0% / 49,6% | 41,2 / 46,0 | 33,9 / 36,5 | 2,23 / 2,31 | 0,94 / 1,01 | 0,06 / 0,07 | pasa |
| D5 | 2,04 / 2,26 | 6,55 / 7,29 | 50,6% / 49,4% | 40,8 / 46,2 | 33,5 / 36,9 | 2,36 / 2,44 | 1,03 / 1,00 | 0,04 / 0,06 | pasa |
| D6 | 1,92 / 1,75 | 6,33 / 6,76 | 50,4% / 49,5% | 41,3 / 46,3 | 33,5 / 36,3 | 2,46 / 2,65 | 1,14 / 1,14 | 0,06 / 0,07 | pasa |
| D7 | 1,99 / 1,92 | 6,32 / 6,22 | 50,9% / 50,2% | 42,1 / 45,6 | 34,0 / 36,3 | 2,56 / 2,63 | 1,19 / 1,14 | 0,06 / 0,10 | pasa |
| D8 | 1,78 / 1,72 | 5,55 / 6,12 | 50,7% / 49,7% | 42,0 / 44,5 | 34,0 / 35,3 | 2,61 / 2,69 | 1,16 / 1,19 | 0,08 / 0,07 | pasa |
| D9 | 1,71 / 1,78 | 5,11 / 5,34 | 51,0% / 50,2% | 41,5 / 43,9 | 33,3 / 34,5 | 2,81 / 3,02 | 1,17 / 1,26 | 0,05 / 0,09 | pasa |
| D10 | 1,67 / 1,65 | 5,12 / 5,12 | 51,0% / 49,8% | 41,1 / 42,6 | 32,4 / 33,6 | 2,75 / 3,13 | 1,19 / 1,36 | 0,06 / 0,10 | pasa |

| Pareja | Goles | Gana A | Puntos de A | Diferencia de gol de A | Posesión de A | Faltas | Veredicto |
| --- | --- | --- | --- | --- | --- | --- | --- |
| D1/D2 | 2,26 / 2,48 | 53% / 59% | 1,87 / 2,00 | 0,72 / 1,00 | 51,5% / 51,9% | 2,17 / 2,25 | pasa |
| D5/D6 | 2,02 / 2,33 | 61% / 64% | 2,07 / 2,14 | 0,85 / 1,25 | 52,4% / 52,3% | 2,54 / 2,50 | pasa |
| D10/D9 | 1,82 / 1,89 | 12% / 15% | 0,61 / 0,70 | -0,88 / -1,08 | 48,2% / 46,6% | 2,65 / 3,10 | pasa |
| D1/D4 | 2,59 / 4,12 | 84% / 98% | 2,66 / 2,96 | 1,99 / 3,82 | 54,3% / 59,1% | 1,96 / 2,20 | no pasa (goles, remates, dif_a) |
| D5/D8 | 2,89 / 3,38 | 91% / 93% | 2,81 / 2,84 | 2,66 / 3,15 | 57,3% / 56,7% | 2,25 / 2,46 | pasa |
| D10/D7 | 2,77 / 3,07 | 1% / 1% | 0,12 / 0,10 | -2,54 / -2,87 | 42,2% / 42,3% | 2,45 / 2,68 | pasa |

**Semilla 20261001, 200 partidos por división (V2 / motor espacial):**

| División | Goles | Remates | Posesión de A | Pases | Completos | Faltas | Amarillas | Rojas | Veredicto |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| D1 | 2,40 / 2,31 | 8,28 / 8,34 | 50,2% / 49,4% | 37,5 / 45,7 | 33,3 / 36,9 | 2,10 / 1,89 | 0,91 / 0,85 | 0,04 / 0,01 | pasa |
| D2 | 2,13 / 2,34 | 7,33 / 8,09 | 49,4% / 49,5% | 38,1 / 45,9 | 33,0 / 36,6 | 1,94 / 2,12 | 0,85 / 0,91 | 0,05 / 0,08 | pasa |
| D3 | 2,10 / 2,13 | 7,13 / 7,92 | 50,0% / 49,6% | 40,1 / 45,9 | 33,4 / 36,7 | 2,08 / 2,15 | 0,86 / 0,96 | 0,04 / 0,06 | pasa |
| D4 | 1,98 / 2,06 | 6,83 / 7,42 | 50,5% / 48,5% | 40,3 / 46,3 | 33,3 / 36,5 | 2,42 / 2,33 | 0,98 / 1,14 | 0,07 / 0,06 | pasa |
| D5 | 1,95 / 2,21 | 6,56 / 7,34 | 51,3% / 49,4% | 41,5 / 46,5 | 33,8 / 36,5 | 2,50 / 2,40 | 1,14 / 1,09 | 0,05 / 0,05 | pasa |
| D6 | 2,09 / 1,95 | 6,47 / 6,92 | 50,9% / 50,3% | 41,7 / 46,4 | 33,7 / 36,6 | 2,77 / 2,44 | 1,28 / 1,09 | 0,08 / 0,06 | pasa |
| D7 | 1,84 / 1,75 | 5,84 / 6,36 | 50,4% / 49,0% | 41,9 / 45,6 | 33,9 / 36,0 | 2,59 / 2,67 | 1,13 / 1,23 | 0,07 / 0,08 | pasa |
| D8 | 1,85 / 1,63 | 5,88 / 5,92 | 50,9% / 49,7% | 42,0 / 44,6 | 33,9 / 35,2 | 2,95 / 2,74 | 1,28 / 1,25 | 0,07 / 0,07 | pasa |
| D9 | 1,62 / 1,63 | 5,04 / 5,43 | 51,5% / 50,3% | 41,6 / 43,5 | 33,7 / 34,5 | 2,81 / 2,98 | 1,21 / 1,35 | 0,05 / 0,10 | pasa |
| D10 | 1,57 / 1,55 | 4,75 / 5,03 | 51,4% / 49,1% | 41,9 / 41,9 | 33,1 / 33,2 | 2,92 / 3,13 | 1,44 / 1,43 | 0,04 / 0,12 | pasa |

| Pareja | Goles | Gana A | Puntos de A | Diferencia de gol de A | Posesión de A | Faltas | Veredicto |
| --- | --- | --- | --- | --- | --- | --- | --- |
| D1/D2 | 2,13 / 2,56 | 56% / 65% | 1,95 / 2,14 | 0,73 / 1,10 | 51,6% / 52,1% | 2,23 / 2,01 | pasa |
| D5/D6 | 2,15 / 2,25 | 61% / 65% | 2,06 / 2,13 | 0,91 / 1,08 | 52,9% / 53,1% | 2,59 / 2,44 | pasa |
| D10/D9 | 1,75 / 1,78 | 10% / 14% | 0,59 / 0,67 | -0,94 / -0,95 | 48,6% / 46,7% | 2,89 / 2,96 | pasa |
| D1/D4 | 2,77 / 4,16 | 86% / 96% | 2,71 / 2,90 | 2,29 / 3,94 | 54,0% / 59,1% | 2,00 / 2,19 | no pasa (goles, posesion_a, dif_a) |
| D5/D8 | 3,06 / 3,58 | 94% / 94% | 2,88 / 2,87 | 2,71 / 3,34 | 57,4% / 58,0% | 2,10 / 2,31 | pasa |
| D10/D7 | 2,90 / 3,19 | 1% / 2% | 0,12 / 0,14 | -2,60 / -2,94 | 43,0% / 42,5% | 2,34 / 2,70 | pasa |

**Pasa si, uno por uno:**

- **El reporte por división queda dentro de rangos en dos semillas distintas:** pasa. Las 10 divisiones, en las semillas 97000 y 20261001.
- **El mejor equipo gana lo que tiene que ganar:** pasa en las divisiones vecinas (6 de 6) y con tres divisiones de diferencia en D5/D8 y D10/D7 (4 de 4). **No pasa en D1/D4:** el favorito gana el 84 a 86% (96 a 98%) por 2,0 a 2,3 goles (3,8 a 3,9), con 54% de posesión (59%).
- **Sin correcciones:** 0 correcciones, `SALTO_PELOTA` = 0 y 0 partidos colgados en 6.400 partidos.

**Qué falta:**

1. **Centros y cabezazos:** el que espera el centro lo toca el 13% de las veces; un rival, el 46%; rebota en un cuerpo o se va, el 25%. Salen 0,23 cabezazos al arco por partido y 0,01 goles de cabeza (el motor espacial: 0,9 y 0,36). El 16% de los gestos de cabeza erra, a 0,9 m de la pelota: casi todos son el que pierde el salto. Se probó que el centro llegue a la altura de la cabeza y que caiga 1,5 m antes del que lo espera: no cambió nada y se deshizo. Los defensores se paran del lado del arco de cada atacante y llegan antes. Falta que el atacante ataque la pelota.
2. **D1 contra D4:** el pase seguro le deja la pelota más tiempo al equipo débil y la diferencia bajó de 2,5 a 2,0-2,3 goles. Decisión abierta: otra palanca además de la rapidez.
3. **El pasador y su pase:** el que da el pase no va a buscarlo durante 2,5 s (`DESCANSO_PASE_PROPIO`). Con el 87% de los pases a los pies llegando, se ve menos; no se tocó.
4. **Rival pegado al que saca el lateral:** en las capturas un rival queda a menos de 2 m. No se tocó.
5. **Pelotazos:** un tercio de los pases son globos (largos, centros y despejes). Los despejes son 5,9 por partido (el motor espacial: 2 a 4).
6. **Bibliotecas:** Windows y Android rearmadas. **Falta rearmar la de Linux** y comparar la huella de `test_reglas_v2` (3043848228211673396 en Windows) con la del teléfono.
7. **Revisión visual:** el usuario tiene que mirar de nuevo. El lateral y el árbitro se revisaron en capturas; el saque del medio, la presión y los pases, solo con números.

#### Resultado (2026-10-01): segunda revisión visual, conducción, remates y cabezazos

El usuario miró otra vez `laboratorio_reglas.tscn` y marcó seis fallas. Mediciones nuevas: `tests/_diag_juego_v2.gd` (por qué sale la pelota, la conducción, la gente en el área, la altura de los remates) y `tests/_diag_corners_v2.gd` (200 córners forzados: quién toca primero el centro y cómo). Los números son de 200 partidos de quinta, semilla 97000. **Las tablas, el "pasa si" y el "qué falta" del resultado de arriba quedaron viejos: valen los de acá.**

| Lo que vio el usuario | Qué era | Antes | Después |
| --- | --- | --- | --- |
| No cabecean | El gesto de cabecear arrancaba tarde | En 200 córners toca primero el que ataca el 11%; cabezazo al arco en el 5% | 53% y 40% |
| Lo mismo, en el partido | — | 0,23 cabezazos al arco por partido | 1,24 (0,11 goles) |
| Adelantan la pelota y la corren a fondo | El toque que cambia de dirección salía como si ya corriera para ese lado | Pelota a más de 2,5 m del que la lleva el 15% del tiempo | 4,5% |
| Corren por la banda y se les va | Lo mismo, más el toque largo | Sale de la cancha conduciendo 1,95 veces por partido; pelota a 1,51 m de media | 0,69 veces; 0,90 m |
| La tiran afuera en los pases | El pelotazo y el centro caían donde nadie los jugaba | Sale de un pase 1,32 veces por partido | 0,60 |
| Se la dan al rival | El pelotazo no se podía bajar de cabeza ni de pecho | Llega a un compañero el 72% de los pases | 78% (el pase a los pies, 87%; el pelotazo, 87%, antes 57%) |
| Los tiros son siempre rastreros | El que remata elegía casi siempre el punto más seguro | 74% rasos, 24% a media altura, 3% altos | 48%, 35% y 17% |
| No va nadie al área | Solo dos podían correr al frente a la vez | 0,87 compañeros en el área; ninguno el 50% del tiempo | 1,28; ninguno el 42%: mejora poco |

**Cabezazos (lo que más cambió):**

- **El bug:** `Canchita::_gatillo` elegía con qué parte tocar mirando la pelota 8 pasos adelante (0,13 s). El contacto de `Cabecear` es a 0,29 s. El gesto arrancaba cuando la pelota estaba por entrar a la franja de la cabeza y al contacto ya había bajado al pecho o al pie. En 200 córners arrancaban 0,4 gestos de cabeza por córner y la pelota rebotaba 1,4 veces en un cuerpo.
- **El arreglo:** cada parte se prueba con la pelota en el cuadro de contacto de su propio clip, de arriba para abajo. Vale para todo lo que llega por arriba: el pelotazo ahora se baja de cabeza o de pecho.
- **Centro tendido (`cerebro.centro_elevacion_rad` 0,3 y `centro_alto_m` 1,3):** un perfil de vuelo propio (`Perfiles::CENTRO`). El córner con el globo de 34° subía a 7-9 m y caía casi vertical. Si tendido no llega, va el globo.
- **Saltan todos (`cerebro.centro_al_que_llega`):** al centro va todo el que lo puede cabecear moviéndose 3 m como mucho, de los dos equipos. Antes iba uno por equipo.
- **Saltan dos por equipo (BUG-011 de `docs/bugs_pendientes.md`, 2026-10-05):** va el que llega primero y un compañero más, el que lo tiene más a tiro (`Canchita::_analizar`). Saltando todos quedaban tres o más compañeros encimados en el 36% de los córners; ahora en el 10%. Los cabezazos al arco no cambian (40% → 38% de los córners).
- **Dos que saltan no se hacen falta:** el cruce cuenta como falta solo con la pierna.
- **Gestos de cabeza:** 17 por partido (antes 4); erra el 10% (antes 15-19%).

**Conducción:**

- **El toque según lo que corre hacia ese lado** (`Canchita::_decidir_partido`): la rapidez del toque usaba la rapidez del jugador sin mirar para dónde. El que cambiaba de dirección mandaba la pelota a 7 m/s hacia el lado nuevo, frenaba de 6,5 a 4,3 m/s en 0,2 s para dar la vuelta y picaba a buscarla. Pasaba 169 veces en 20 partidos.
- **El próximo toque posible** (`_alcance`, `no_antes`): el que conduce apunta al punto donde puede volver a tocarla (cuando termina el gesto y llega el contacto del siguiente), no a la pelota recién tocada.
- **`toque.toque_largo_m` 0,8 y `toque_corto_m` 0,5** (eran 1,4 y 0,8).

**Remates:** `cerebro.remate_temperatura` 0,15 (era 0,05) y `remate.error_vertical` 0,4 (era 0,6). También se reparten más los golpes: colocado 2,4 por partido, fuerte 1,5, con efecto 1,35, globo 0,9.

**Área:** `cerebro.llegada_area_extra` (2). Con la pelota por la banda (a más de 16 m del eje) en el último tercio, el 9, los extremos y los volantes van al área aunque esté llena, desde 38 m, y el cupo de corridas sube de 2 a 4.

**Recalibración.** Estos arreglos emparejaron a los equipos: con el pase seguro y la pelota pegada al pie, la rapidez dejó de alcanzar (primera le ganaba a cuarta el 67% aun en el tope) y décima completaba tantos pases como primera.

- **`nivel.tecnica_por_punto` (6):** los puntos de media que el equipo le saca al nivel del partido, por 6, se suman a pases y control. `nivel.rapidez_por_punto` sube a 0,05.
- **Error técnico:** `toque.error_pase_rad` 0,16 (era 0,1), `error_control_rad` 0,65 y `error_control_ms` 2,4 (eran 0,4 y 1,5).
- **Faltas:** `entrada_dist_m` 2,0, `falta_radio_m` 0,42 y `falta_torpeza` 1,5. Con la pelota pegada al pie las entradas se duplicaron.
- **Remates:** `cerebro.tiro_factor` 1,2 y `remate.primera_geometria` 0,25. Los cabezazos suman 1,2 remates por partido.

**Semilla 97000, 200 partidos por división (V2 / motor espacial):**

| División | Goles | Remates | Posesión de A | Pases | Completos | Faltas | Amarillas | Rojas | Veredicto |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| D1 | 2,17 / 2,31 | 8,34 / 8,15 | 49,6% / 49,0% | 41,5 / 45,8 | 38,5 / 36,8 | 2,21 / 2,24 | 0,94 / 0,95 | 0,07 / 0,04 | pasa |
| D2 | 2,25 / 2,21 | 7,89 / 7,91 | 49,9% / 48,5% | 43,5 / 45,9 | 39,9 / 36,7 | 2,19 / 2,23 | 0,94 / 1,06 | 0,03 / 0,07 | pasa |
| D3 | 2,06 / 2,22 | 7,90 / 7,63 | 49,9% / 49,0% | 44,6 / 46,1 | 40,1 / 36,6 | 2,29 / 2,29 | 0,95 / 1,01 | 0,07 / 0,10 | pasa |
| D4 | 2,07 / 2,13 | 7,63 / 7,46 | 49,6% / 49,6% | 45,7 / 46,0 | 40,7 / 36,5 | 2,36 / 2,31 | 1,05 / 1,01 | 0,06 / 0,07 | pasa |
| D5 | 2,06 / 2,26 | 7,42 / 7,29 | 49,9% / 49,4% | 46,6 / 46,2 | 41,2 / 36,9 | 2,42 / 2,44 | 1,00 / 1,00 | 0,07 / 0,06 | pasa |
| D6 | 1,93 / 1,75 | 7,03 / 6,76 | 49,7% / 49,5% | 46,8 / 46,3 | 41,1 / 36,3 | 2,32 / 2,65 | 1,08 / 1,14 | 0,04 / 0,07 | pasa |
| D7 | 1,94 / 1,92 | 6,78 / 6,22 | 50,2% / 50,2% | 47,3 / 45,6 | 40,4 / 36,3 | 2,61 / 2,63 | 1,16 / 1,14 | 0,04 / 0,10 | pasa |
| D8 | 1,90 / 1,72 | 6,57 / 6,12 | 51,1% / 49,7% | 46,9 / 44,5 | 40,2 / 35,3 | 2,43 / 2,69 | 1,09 / 1,19 | 0,07 / 0,07 | pasa |
| D9 | 1,87 / 1,78 | 6,34 / 5,34 | 50,2% / 50,2% | 46,5 / 43,9 | 38,3 / 34,5 | 2,48 / 3,02 | 1,09 / 1,26 | 0,04 / 0,09 | pasa |
| D10 | 1,75 / 1,65 | 5,61 / 5,12 | 49,9% / 49,8% | 46,5 / 42,6 | 37,9 / 33,6 | 2,45 / 3,13 | 1,07 / 1,36 | 0,05 / 0,10 | pasa |

| Pareja | Goles | Gana A | Puntos de A | Diferencia de gol de A | Posesión de A | Faltas | Veredicto |
| --- | --- | --- | --- | --- | --- | --- | --- |
| D1/D2 | 2,00 / 2,48 | 50% / 59% | 1,80 / 2,00 | 0,56 / 1,00 | 51,8% / 51,9% | 2,23 / 2,25 | no pasa (dif_a) |
| D5/D6 | 1,93 / 2,33 | 67% / 64% | 2,23 / 2,14 | 1,03 / 1,25 | 53,8% / 52,3% | 2,31 / 2,50 | pasa |
| D10/D9 | 1,91 / 1,89 | 6% / 15% | 0,47 / 0,70 | -1,15 / -1,08 | 45,6% / 46,6% | 2,47 / 3,10 | pasa |
| D1/D4 | 2,84 / 4,12 | 88% / 98% | 2,70 / 2,96 | 2,23 / 3,82 | 55,5% / 59,1% | 1,79 / 2,20 | no pasa (goles, dif_a) |
| D5/D8 | 2,94 / 3,38 | 96% / 93% | 2,90 / 2,84 | 2,75 / 3,15 | 58,8% / 56,7% | 1,77 / 2,46 | no pasa (pases_completos, faltas) |
| D10/D7 | 3,10 / 3,07 | 0% / 1% | 0,03 / 0,10 | -2,96 / -2,87 | 39,9% / 42,3% | 1,77 / 2,68 | no pasa (remates, pases_completos, faltas, amarillas) |

**Semilla 20261001, 200 partidos por división (V2 / motor espacial):**

| División | Goles | Remates | Posesión de A | Pases | Completos | Faltas | Amarillas | Rojas | Veredicto |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| D1 | 2,04 / 2,31 | 7,89 / 8,34 | 50,2% / 49,4% | 41,4 / 45,7 | 38,9 / 36,9 | 2,15 / 1,89 | 0,89 / 0,85 | 0,04 / 0,01 | pasa |
| D2 | 2,19 / 2,34 | 7,95 / 8,09 | 49,7% / 49,5% | 43,2 / 45,9 | 39,7 / 36,6 | 2,28 / 2,12 | 1,10 / 0,91 | 0,06 / 0,08 | pasa |
| D3 | 2,13 / 2,13 | 7,77 / 7,92 | 49,4% / 49,6% | 44,7 / 45,9 | 40,4 / 36,7 | 2,37 / 2,15 | 0,93 / 0,96 | 0,06 / 0,06 | pasa |
| D4 | 1,87 / 2,06 | 7,67 / 7,42 | 49,2% / 48,5% | 46,0 / 46,3 | 40,8 / 36,5 | 2,38 / 2,33 | 1,11 / 1,14 | 0,04 / 0,06 | pasa |
| D5 | 2,00 / 2,21 | 7,42 / 7,34 | 50,2% / 49,4% | 45,6 / 46,5 | 40,2 / 36,5 | 2,55 / 2,40 | 1,11 / 1,09 | 0,06 / 0,05 | pasa |
| D6 | 2,13 / 1,95 | 7,26 / 6,92 | 50,5% / 50,3% | 47,4 / 46,4 | 41,3 / 36,6 | 2,57 / 2,44 | 1,17 / 1,09 | 0,09 / 0,06 | pasa |
| D7 | 1,91 / 1,75 | 6,82 / 6,36 | 50,8% / 49,0% | 47,7 / 45,6 | 40,6 / 36,0 | 2,65 / 2,67 | 1,26 / 1,23 | 0,04 / 0,08 | pasa |
| D8 | 1,79 / 1,63 | 6,57 / 5,92 | 50,5% / 49,7% | 47,3 / 44,6 | 40,0 / 35,2 | 2,62 / 2,74 | 1,18 / 1,25 | 0,04 / 0,07 | pasa |
| D9 | 1,83 / 1,63 | 6,04 / 5,43 | 51,4% / 50,3% | 47,7 / 43,5 | 39,5 / 34,5 | 2,59 / 2,98 | 1,13 / 1,35 | 0,07 / 0,10 | pasa |
| D10 | 1,75 / 1,55 | 5,67 / 5,03 | 50,2% / 49,1% | 46,9 / 41,9 | 38,2 / 33,2 | 2,94 / 3,13 | 1,35 / 1,43 | 0,07 / 0,12 | pasa |

| Pareja | Goles | Gana A | Puntos de A | Diferencia de gol de A | Posesión de A | Faltas | Veredicto |
| --- | --- | --- | --- | --- | --- | --- | --- |
| D1/D2 | 2,15 / 2,56 | 61% / 65% | 2,04 / 2,14 | 0,77 / 1,10 | 51,1% / 52,1% | 2,20 / 2,01 | pasa |
| D5/D6 | 2,07 / 2,25 | 67% / 65% | 2,25 / 2,13 | 1,16 / 1,08 | 53,6% / 53,1% | 2,25 / 2,44 | pasa |
| D10/D9 | 2,06 / 1,78 | 7% / 14% | 0,46 / 0,67 | -1,21 / -0,95 | 46,6% / 46,7% | 2,34 / 2,96 | pasa |
| D1/D4 | 2,56 / 4,16 | 82% / 96% | 2,63 / 2,90 | 2,07 / 3,94 | 56,3% / 59,1% | 1,80 / 2,19 | no pasa (goles, dif_a) |
| D5/D8 | 3,18 / 3,58 | 96% / 94% | 2,90 / 2,87 | 2,90 / 3,34 | 59,1% / 58,0% | 1,90 / 2,31 | no pasa (pases_completos) |
| D10/D7 | 3,20 / 3,19 | 0% / 2% | 0,02 / 0,14 | -3,11 / -2,94 | 40,7% / 42,5% | 1,78 / 2,70 | no pasa (remates, pases_completos, faltas, amarillas) |

**Pasa si, uno por uno:**

- **El reporte por división queda dentro de rangos en dos semillas distintas:** pasa. Las 10 divisiones, en las semillas 97000 y 20261001.
- **El mejor equipo gana lo que tiene que ganar, en una liga:** pasa en 5 de 6 parejas de divisiones vecinas. En D1/D2 de la semilla 97000 la diferencia de gol queda en 0,56 contra 1,00 (el rango es 0,4).
- **Con tres divisiones de diferencia:** el favorito gana lo que tiene que ganar en D5/D8 y D10/D7 (93 a 100% contra 93 a 99%), pero esas parejas quedan fuera de rango en pases completos (+25%), faltas (-28%) y, en D10/D7, remates. **No pasa en D1/D4:** gana el 82 a 88% (96 a 98%) por 2,1 a 2,2 goles (3,8 a 3,9).
- **Sin correcciones:** 0 correcciones, `SALTO_PELOTA` = 0 y 0 partidos colgados en 6.400 partidos.

**Qué falta:**

1. **El área en los ataques por la banda:** 1,28 compañeros contra 4,1 rivales, y ninguno el 42% del tiempo. La línea del offside deja a los que llegan en el borde y la corrida dura 3 s como mucho. Subir el cupo a 6 no cambió nada.
2. **Goles de córner:** 8,5% de los córners terminan en gol (en el fútbol real, 3%). Hay 0,8 córners por partido: pesa poco, pero se va a ver.
3. **Partidos de tres divisiones de diferencia:** ver arriba. `entrada_sobrado` le baja las entradas al favorito y el otro no llega a la pelota: quedan pocas faltas.
4. **Pelota afuera después de un control:** 1,25 veces por partido (subió con el error de control más grande).
5. **Bibliotecas:** Windows, Android y Linux rearmadas. La de Linux se armó en la PC con Zig (ver "Cómo se arma la extensión") y **no se probó**: en la PC no hay un Linux donde cargarla. Falta correr `test_reglas_v2` en la nube y en el teléfono y comparar la huella con la de Windows (2608213419897894886).
6. **Revisión visual:** el usuario tiene que mirar de nuevo. Todo lo de esta vuelta se verificó con números; en pantalla no se miró nada.

#### Resultado (2026-10-02): tercera revisión visual, decisiones, barridas y cambios

El usuario miró otra vez `laboratorio_reglas.tscn` y marcó seis cosas. Dos mediciones nuevas: `tests/_diag_traza_v2.gd` (escribe, jugada por jugada, qué decide el que tiene la pelota cerca del arco y con qué opciones) y `tests/_diag_estilos_v2.gd` (los mismos planteles con cada estilo). `tests/_diag_juego_v2.gd` mide además cuánto se aleja la pelota después de cada toque, qué se decide con el arco a tiro y qué pasa con cada barrida. Los números son de quinta, semilla 97000. **Las tablas, el "pasa si" y el "qué falta" del resultado de arriba quedaron viejos: valen los de acá.**

| Lo que vio el usuario | Qué era | Antes | Después |
| --- | --- | --- | --- |
| Adelantan la pelota y la corren a fondo | El toque que cambia de dirección salía a 5 m/s contra lo que él corría | Pelota a más de 2,5 m del que la lleva el 4,4% del tiempo; a más de 2 m después del 9% de los toques | 0,6%; 3% |
| Corren por la banda y se les va | Decidía cada 1,5 s y corría 10 m entre una decisión y otra; el control cerca de la raya salía con su error | Sale de la cancha conduciendo 0,73 veces por partido; de un control, 1,18 | 0,12 y 0,47 |
| No patean con vía libre | La geometría del remate da cero con más de 56 grados: el que entraba al área en diagonal seguía hasta la línea de fondo | 3,3 decisiones por partido en el área sin rivales delante | 4,0; con el arco a tiro patea el 70 a 92% |
| Las barridas no sacan la pelota | El que la llevaba quedaba parado al lado de la pelota suelta | De 2,4 barridas limpias, se la queda el equipo del que barre 1 de cada 4 | De 4,7, 2 de cada 3 |
| El cambio no se ve | La cámara seguía 4 s al que sale; el lesionado tardaba hasta 11 s en cruzar la cancha | — | La cámara lo sigue hasta la raya y después al que entra |
| No hay identidad de juego | Ver "Identidad de juego" | Tiki taka 26 pases, Contragolpe 21 | 27 y 18 |

**La traza encontró tres cosas que los contadores no mostraban:**

- **Decide cada 1,5 s.** La conducción valía hasta la cadencia del control (0,5 a 2,25 s). A 6,5 m/s son 10 m sin mirar: el que iba por la banda llegaba a la línea de fondo con una sola opción (conducir). `cerebro.conduce_decide_seg` (0,6).
- **El remate no estaba entre las opciones.** `factor_angulo` da cero cuando la distancia al eje pasa una vez y media la distancia a la línea de fondo. A 3 m del fondo y 7 m del eje ve 28 grados de arco, y no podía patear.
- **Los carriles lo sacan hacia la banda.** De los tres carriles de conducción gana el más libre, que es el de afuera: el defensor lo lleva a la raya.

**Conducción:**

- **La rapidez del toque con signo** (`Canchita::_decidir_partido`, `toque.conduce_gana_seg` 0,15): cuenta lo que corre hacia donde manda la pelota, con signo. El que va para el otro lado primero tiene que frenar: la media vuelta deja la pelota casi quieta. Antes sumaba medio segundo de aceleración y los toques que giraban 110 a 140 grados salían a 5 m/s.
- **La pelota acompaña al cuerpo** (`toque.conduce_inercia` 1, BUG-009 de `docs/bugs_pendientes.md`): el toque suma lo que el cuerpo sigue corriendo para otro lado hasta el toque siguiente. Reemplaza a `toque.frena_giro_*`. `reglas.entrada_prob` pasa a 0,75.
- **La punta es la del jugador** (`nivel.punta_tope` 0,05, BUG-010): el nivel del equipo cambia la punta a lo sumo ±5%. Antes llegaba a ±42% en tercera: 12,0 m/s contra 6,3 m/s con dos jugadores de velocidad 99. `nivel.rapidez_tope` pasa a 0,09 (solo aceleración) y `nivel.tecnica_por_punto` a 9.
- **Probado y descartado:** que el toque no gire más de 70 grados. La pelota no se alejaba, pero salía de la cancha 1,07 veces por partido conduciendo y los quites al que conduce bajaban de 6,8 a 2,4.
- **El control mira la raya** (`toque.control_raya_m` 1,5): el punto adonde la manda, 4 m adelante, se trae adentro de la cancha.
- **Espera a los compañeros** (`cerebro.conduce_espera` 0,6, `Cerebro::ritmo_de_conduccion`): el que se adelantó a su equipo baja el ritmo. A fondo: de contra, encarando o con un rival a menos de 2,5 m. Pesa poco: con un marcador cerca va casi siempre a fondo.

**Remates:**

- **Encara** (`cerebro.via_libre_m` 22, `Cerebro::encara`): sin rivales de campo en el triángulo que va de él a los dos palos, a menos de 22 m del arco, conduce derecho al arco y a fondo, y no se la da al que no queda mejor parado. Sin presión sigue (`conducir_libre_extra` 2,5); con un rival encima patea.
- **El arco que ve de cerca** (`cerebro.tiro_de_cerca`, `Cerebro::geometria_de_cerca`): a menos de 18 m cuenta el ángulo entre los dos palos (de 13 a 45 grados).
- **Probado y descartado:** la chance de gol del planeador (`valor_remate`) como utilidad del remate. Sirve para comparar puntos del arco, pero de lejos da 0,2 a 0,7 (el globo por arriba del arquero) y pateaban desde 35 m.
- `valor_remate` estira el error de lado con el ángulo: desde el costado el remate valía lo mismo que de frente.

**Barridas:**

- **El que la llevaba cae** (`reglas.entrada_tumba` 0,8): la entrada que saca la pelota tumba al que la llevaba, sin falta.
- **La pierna llega más lejos** (`reglas.entrada_alcance_m` 0,45; el control llega a 0,3). Las barridas que no tocan nada bajan del 23% al 14%.
- **Se tira más el torpe** (`reglas.entrada_por_quite` -0,5): con el bueno tirándose más, primera hacía 3,1 faltas y décima 2,1 (el motor espacial: 2,2 y 3,1).
- Por partido: 8,5 barridas; 4,7 sacan la pelota, 2,6 son falta y 1,2 no tocan nada. `entrada_prob` 0,65, `entrada_sobrado` 0 y `amarilla_por_falta` 0,56.

**Cambios:** `PartidoVistoV2.foco_de_cambio` da adónde mirar: el que sale hasta que cruza la raya y después el que entra. El que sale corre (`FACTOR_SALIR` 0,7) y el lesionado trota (0,5). Revisado en capturas con `solo=lesión`.

**Identidad de juego.** El plan no tiene una etapa para esto. Los estilos (`Estilos.PLANES`) ya llegan al cerebro y se miden con `tests/_diag_estilos_v2.gd`:

| Estilo | Pases | Largo del pase | Pelotazos | Bloque sin pelota | Goles a favor y en contra |
| --- | --- | --- | --- | --- | --- |
| Tiki taka | 26,5 | 13,5 m | 1,0 | 39,4 m | 0,89 y 1,06 |
| Contragolpe | 17,9 | 18,7 m | 3,9 | 36,6 m | 1,12 y 1,00 |
| Juego directo | 18,4 | 17,8 m | 3,1 | 39,0 m | 1,04 y 1,08 |
| Presión alta | 24,2 | 15,6 m | 2,7 | 43,3 m | 1,08 y 1,21 |
| Defensivo | 18,8 | 16,5 m | 2,5 | 35,3 m | 1,14 y 1,05 |
| Físico | 19,9 | 17,5 m | 3,4 | 39,3 m | 1,08 y 1,04 |

`cerebro.estilo_fuerza` (1,5) multiplica lo que el plan se aparta del estilo medio. Mueve poco: la posesión queda en 50% para los seis y el Tiki taka pierde contra el Juego directo. Una identidad de verdad (posesión, altura y momento de la presión, ritmo) pide una etapa propia antes de la etapa 8.

**Recalibración.** Los arreglos movieron todo: más pases (se decide más seguido), mejores remates y barridas que sacan la pelota.

- **Pases:** `cerebro.pase_seguro_extra` 0,4 (era 3). Con 3, el pase seguro valía 3,7 y conducir 1,2: el que tenía el camino libre la tocaba al costado.
- **Remates:** `cerebro.tiro_factor` 0,75.
- **Un punto de media pesa según el nivel** (`nivel.referencia` 55 y `nivel.exponente` 1,5, `FisicaV2.peso_del_nivel`). Con el mismo peso en todas las divisiones, primera le sacaba 0,4 goles a segunda (el motor espacial: 1,0) y novena le sacaba 1,6 a décima (1,0). La física del V2 usa los atributos absolutos y el motor espacial los relativos al nivel del partido.

V2 / motor espacial, 200 partidos por pareja. Los puntos y la diferencia de A no se miran en las divisiones parejas.

Semilla 97000:

| Partido | Goles | Remates | Pases completos | Faltas | Amarillas | Puntos de A | Diferencia de A | Fuera de rango |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| D1/D1 | 2,16 / 2,31 | 9,31 / 8,15 | 38,23 / 36,76 | 2,03 / 2,24 | 0,89 / 0,95 | 1,11 / 1,39 | -0,37 / -0,09 | — |
| D2/D2 | 2,23 / 2,21 | 9,09 / 7,91 | 38,50 / 36,72 | 2,35 / 2,23 | 0,96 / 1,06 | 0,94 / 1,20 | -0,52 / -0,17 | — |
| D3/D3 | 2,14 / 2,22 | 8,97 / 7,63 | 39,85 / 36,65 | 2,27 / 2,29 | 1,01 / 1,01 | 1,10 / 1,32 | -0,38 / -0,14 | rojas |
| D4/D4 | 1,94 / 2,13 | 8,29 / 7,46 | 40,04 / 36,49 | 2,38 / 2,31 | 1,03 / 1,01 | 1,00 / 1,36 | -0,45 / -0,07 | — |
| D5/D5 | 2,00 / 2,26 | 8,21 / 7,29 | 39,88 / 36,87 | 2,68 / 2,44 | 1,20 / 1,00 | 1,20 / 1,27 | -0,21 / -0,10 | — |
| D6/D6 | 2,05 / 1,75 | 7,82 / 6,76 | 38,99 / 36,33 | 2,47 / 2,65 | 1,16 / 1,14 | 1,11 / 1,36 | -0,28 / -0,03 | — |
| D7/D7 | 1,75 / 1,92 | 7,61 / 6,22 | 38,60 / 36,26 | 2,75 / 2,63 | 1,26 / 1,14 | 1,08 / 1,21 | -0,39 / -0,20 | remate |
| D8/D8 | 1,87 / 1,72 | 7,39 / 6,12 | 37,41 / 35,31 | 2,66 / 2,69 | 1,06 / 1,19 | 1,11 / 1,32 | -0,30 / -0,09 | remate |
| D9/D9 | 1,65 / 1,78 | 6,50 / 5,34 | 37,25 / 34,50 | 2,75 / 3,02 | 1,22 / 1,26 | 1,20 / 1,28 | -0,11 / -0,01 | remate, offsid |
| D10/D10 | 1,63 / 1,65 | 6,21 / 5,12 | 36,11 / 33,63 | 2,91 / 3,13 | 1,32 / 1,36 | 1,13 / 1,31 | -0,23 / -0,04 | remate, offsid |
| D1/D4 | 3,71 / 4,12 | 10,80 / 8,74 | 45,97 / 36,91 | 1,60 / 2,20 | 0,68 / 0,98 | 2,96 / 2,96 | 3,63 / 3,82 | remate, pases_, faltas, offsid |
| D5/D8 | 3,04 / 3,38 | 9,40 / 7,96 | 45,48 / 36,58 | 2,48 / 2,46 | 1,12 / 1,01 | 2,87 / 2,84 | 2,78 / 3,15 | pases_, offsid |
| D10/D7 | 2,83 / 3,07 | 9,36 / 7,21 | 35,45 / 34,46 | 2,58 / 2,68 | 1,15 / 1,20 | 0,11 / 0,10 | -2,59 / -2,87 | remate, offsid |
| D1/D2 | 2,21 / 2,48 | 8,55 / 8,07 | 42,01 / 36,37 | 1,98 / 2,25 | 0,90 / 0,93 | 2,23 / 2,00 | 1,22 / 1,00 | — |
| D5/D6 | 2,08 / 2,33 | 8,20 / 7,05 | 42,72 / 37,09 | 2,50 / 2,50 | 1,25 / 1,16 | 2,19 / 2,14 | 1,13 / 1,25 | — |
| D10/D9 | 1,85 / 1,89 | 7,00 / 5,57 | 35,17 / 34,02 | 2,60 / 3,10 | 1,15 / 1,45 | 0,52 / 0,70 | -1,10 / -1,08 | remate, offsid |

Semilla 20261001:

| Partido | Goles | Remates | Pases completos | Faltas | Amarillas | Puntos de A | Diferencia de A | Fuera de rango |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| D1/D1 | 2,10 / 2,31 | 9,36 / 8,34 | 38,35 / 36,87 | 2,10 / 1,89 | 0,85 / 0,85 | 1,17 / 1,19 | -0,26 / -0,38 | — |
| D2/D2 | 2,13 / 2,34 | 8,97 / 8,09 | 39,10 / 36,58 | 2,37 / 2,12 | 0,95 / 0,91 | 1,15 / 1,38 | -0,38 / -0,12 | — |
| D3/D3 | 1,98 / 2,13 | 8,73 / 7,92 | 39,23 / 36,74 | 2,52 / 2,15 | 1,09 / 0,96 | 1,06 / 1,48 | -0,40 / 0,16 | — |
| D4/D4 | 1,99 / 2,06 | 8,48 / 7,42 | 39,17 / 36,45 | 2,48 / 2,33 | 1,13 / 1,14 | 1,13 / 1,27 | -0,26 / -0,16 | — |
| D5/D5 | 2,09 / 2,21 | 8,36 / 7,34 | 39,70 / 36,55 | 2,54 / 2,40 | 1,20 / 1,09 | 0,98 / 1,40 | -0,51 / -0,19 | — |
| D6/D6 | 2,00 / 1,95 | 8,16 / 6,92 | 39,66 / 36,59 | 2,69 / 2,44 | 1,18 / 1,09 | 1,01 / 1,35 | -0,35 / -0,01 | penale |
| D7/D7 | 1,80 / 1,75 | 7,38 / 6,36 | 38,23 / 36,03 | 2,70 / 2,67 | 1,27 / 1,23 | 1,07 / 1,27 | -0,34 / -0,01 | — |
| D8/D8 | 1,69 / 1,63 | 6,88 / 5,92 | 38,58 / 35,17 | 2,86 / 2,74 | 1,26 / 1,25 | 1,14 / 1,32 | -0,12 / -0,04 | — |
| D9/D9 | 1,72 / 1,63 | 6,52 / 5,43 | 37,35 / 34,54 | 3,01 / 2,98 | 1,31 / 1,35 | 1,10 / 1,33 | -0,19 / -0,01 | remate, offsid |
| D10/D10 | 1,49 / 1,55 | 6,04 / 5,03 | 35,98 / 33,19 | 2,66 / 3,13 | 1,22 / 1,43 | 1,02 / 1,33 | -0,32 / -0,03 | remate |
| D1/D4 | 3,79 / 4,16 | 10,86 / 8,73 | 45,97 / 36,91 | 1,67 / 2,19 | 0,77 / 1,04 | 3,00 / 2,90 | 3,67 / 3,94 | remate, pases_, offsid |
| D5/D8 | 3,02 / 3,58 | 9,46 / 8,05 | 44,60 / 36,81 | 2,44 / 2,31 | 1,08 / 0,94 | 2,90 / 2,87 | 2,77 / 3,34 | pases_, offsid |
| D10/D7 | 3,10 / 3,19 | 9,35 / 7,34 | 35,16 / 34,05 | 2,53 / 2,70 | 1,08 / 1,25 | 0,10 / 0,14 | -2,83 / -2,94 | remate, al_arc, offsid |
| D1/D2 | 2,15 / 2,56 | 8,65 / 8,23 | 42,23 / 36,27 | 1,90 / 2,01 | 0,81 / 0,89 | 2,35 / 2,14 | 1,30 / 1,10 | — |
| D5/D6 | 2,29 / 2,25 | 8,07 / 7,32 | 42,76 / 36,91 | 2,61 / 2,44 | 1,25 / 1,10 | 2,38 / 2,13 | 1,37 / 1,08 | — |
| D10/D9 | 2,00 / 1,78 | 7,07 / 5,48 | 35,84 / 34,31 | 2,79 / 2,96 | 1,19 / 1,25 | 0,59 / 0,67 | -1,22 / -0,95 | remate, offsid, penale |

**Pasa si, uno por uno:**

- **El reporte por división queda dentro de rangos en dos semillas distintas:** goles, pases, faltas, tarjetas y posesión, sí, en las diez divisiones. **Los remates no, de séptima para abajo:** 20 a 26% arriba (el rango es 20%). Los offsides pasan el piso en novena y décima (0,3 contra 0,1).
- **El mejor equipo gana lo que tiene que ganar:** pasa en las seis parejas desparejas y en las dos semillas (puntos y diferencia de gol). Antes no pasaba en D1/D4.
- **Con tres divisiones de diferencia** quedan fuera de rango los pases completos (+24%) y los remates.
- **Sin correcciones:** 0 correcciones, `SALTO_PELOTA` = 0 y 0 partidos colgados en 6.400 partidos.

**Qué falta:**

1. **Identidad de juego:** ver arriba. El Tiki taka quedó débil.
2. **El área en los ataques por la banda:** 0,87 compañeros contra 3,5 rivales, y ninguno el 54% del tiempo. Los volantes quedan 20 a 30 m detrás de la pelota (las anclas del motor espacial) y el que corre la banda muchas veces es el 9.
3. **Remates de séptima para abajo:** ver arriba.
4. **Goles de córner:** 8,5% de los córners terminan en gol (en el fútbol real, 3%).
5. **Bibliotecas:** Windows, Android y Linux rearmadas. La de Linux **no se probó** (ver el resultado anterior).
6. **Revisión visual:** el usuario tiene que mirar de nuevo. De esta vuelta solo el cambio se miró en capturas.

#### Resultado (2026-10-02): el área, los remates de abajo y los córners

Tres de las cosas que quedaban abiertas en el resultado de arriba. Números de quinta, semilla 97000. **Las tablas, el "pasa si" y el "qué falta" del resultado de arriba quedaron viejos: valen los de acá** (la identidad de juego tiene su etapa, la 7b).

| Qué | Qué era | Antes | Después |
| --- | --- | --- | --- |
| El área vacía en los ataques por la banda | La llegada guardaba el destino ya recortado por el offside y se caía si el área estaba llena de rivales | Con la pelota a menos de 10 m del fondo: 2,0 compañeros en el área, ninguno el 17% | 2,25; ninguno el 8% |
| Lo mismo, a 20-10 m del fondo | — | 0,95; ninguno el 46% | 1,13; ninguno el 36% |
| Remates de séptima para abajo | Tiros de muy lejos (con el arco a más de 25 m) | 20 a 26% arriba del motor espacial | 3 a 12% arriba: en rango |
| Goles de córner | El cabezazo marcado y el remate de primera en el área llena entraban demasiado | 8,5% de los córners | 4,0% (1.000 córners; en el fútbol real, 3%) |

**El área:**

- **La medición engañaba.** `tests/_diag_juego_v2.gd` contaba desde los 30 m del fondo. Ahí la línea del offside está fuera del área y nadie puede estar adentro: es normal. Ahora mide por tramo (30-20 m, 20-10 y menos de 10) y en cada centro: cuando sale un centro hay 3,3 compañeros en el área, y ninguno el 1% de las veces.
- **El destino deseado** (`PlanDesmarque.deseo_x`, `Cerebro::_desmarque_sigue_vivo`): la llegada guarda adónde quiere ir antes de recortar por el offside. La línea baja con la pelota y el que llega sigue hasta adentro. Antes se quedaba en el borde.
- **No se cae por el área llena:** el desmarque moría si en el destino había mucha presión. La llegada al área no.
- **Dura mientras la pelota siga por la banda** en el último tercio (antes 3 s como mucho).
- **Espera** (`Cerebro::ritmo_de_conduccion`): el que va por la banda sin nadie para el centro baja el ritmo, sea cual sea el estilo.
- **Probado y descartado:** más llegadas a la vez (4 de más en vez de 2) y desde más lejos (45 m en vez de 38): no cambia nada. La llegada persistente sin el destino deseado empeoraba (1,55 compañeros con la pelota a menos de 10 m).
- Con la pelota a 20-10 m del fondo el área sigue vacía el 36% del tiempo: la línea del offside deja a los que llegan en el borde. El que lleva la pelota por la banda es el 9 el 31% de las veces.

**Remates:** `cerebro.tiro_desde` (0,15): con menos geometría que esa el remate no se ofrece. Con la mínima del motor espacial (0,03) salían 1,6 remates por partido con el arco a más de 25 m, casi sin gol.

**Córners** (`tests/_diag_corners_v2.gd` dice ahora de qué remates salen los goles):

- `remate.cabeza_marcado` (3): el cabezazo con un rival encima sale peor. Los cabezazos del córner (desde 11 m, con el rival a 1 m) entraban el 14%; ahora el 3%.
- `remate.primera_marcado` (2): lo mismo para el remate de pie de primera.
- **Probado y descartado:** que el arquero salga a cortar el centro (el centro cae a 8 m o más del arco: no llega a ninguno), pararlo en el medio del arco y correr al que marca hacia el lado de la pelota. Ninguno movió nada.

V2 / motor espacial, 200 partidos por pareja, con todo lo de este resultado y lo de la etapa 7b. Los puntos y la diferencia de A no se miran en las divisiones parejas.

Semilla 97000:

| Partido | Goles | Remates | Pases completos | Faltas | Amarillas | Puntos de A | Diferencia de A | Fuera de rango |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| D1/D1 | 2,17 / 2,31 | 8,39 / 8,15 | 37,62 / 36,76 | 2,11 / 2,24 | 0,85 / 0,95 | 1,24 / 1,39 | -0,14 / -0,09 | — |
| D2/D2 | 2,25 / 2,21 | 8,10 / 7,91 | 38,05 / 36,72 | 2,27 / 2,23 | 0,89 / 1,06 | 1,24 / 1,20 | -0,22 / -0,17 | — |
| D3/D3 | 2,28 / 2,22 | 7,88 / 7,63 | 38,53 / 36,65 | 2,67 / 2,29 | 1,01 / 1,01 | 1,20 / 1,32 | -0,12 / -0,14 | — |
| D4/D4 | 2,22 / 2,13 | 7,83 / 7,46 | 39,13 / 36,49 | 2,81 / 2,31 | 1,02 / 1,01 | 1,08 / 1,36 | -0,35 / -0,07 | — |
| D5/D5 | 1,99 / 2,26 | 7,11 / 7,29 | 39,20 / 36,87 | 2,74 / 2,44 | 1,05 / 1,00 | 1,31 / 1,27 | -0,07 / -0,10 | — |
| D6/D6 | 2,17 / 1,75 | 7,14 / 6,76 | 38,81 / 36,33 | 2,77 / 2,65 | 1,13 / 1,14 | 1,33 / 1,36 | -0,01 / -0,03 | goles |
| D7/D7 | 2,02 / 1,92 | 6,57 / 6,22 | 38,70 / 36,26 | 2,75 / 2,63 | 1,11 / 1,14 | 1,27 / 1,21 | -0,05 / -0,20 | — |
| D8/D8 | 1,93 / 1,72 | 6,45 / 6,12 | 37,97 / 35,31 | 2,69 / 2,69 | 0,96 / 1,19 | 1,36 / 1,32 | 0,07 / -0,09 | — |
| D9/D9 | 1,73 / 1,78 | 5,79 / 5,34 | 36,59 / 34,50 | 2,82 / 3,02 | 0,97 / 1,26 | 1,33 / 1,28 | 0,03 / -0,01 | — |
| D10/D10 | 1,67 / 1,65 | 5,71 / 5,12 | 35,92 / 33,63 | 2,67 / 3,13 | 1,01 / 1,36 | 1,41 / 1,31 | 0,10 / -0,04 | offsid |
| D1/D4 | 3,90 / 4,12 | 10,97 / 8,74 | 47,17 / 36,91 | 1,44 / 2,20 | 0,46 / 0,98 | 2,97 / 2,96 | 3,83 / 3,82 | remate, pases_, faltas, amaril, offsid |
| D5/D8 | 3,15 / 3,38 | 9,84 / 7,96 | 45,91 / 36,58 | 2,31 / 2,46 | 0,84 / 1,01 | 2,90 / 2,84 | 2,92 / 3,15 | remate, pases_, offsid |
| D10/D7 | 2,86 / 3,07 | 8,09 / 7,21 | 35,17 / 34,46 | 2,94 / 2,68 | 1,07 / 1,20 | 0,13 / 0,10 | -2,46 / -2,87 | offsid |
| D1/D2 | 2,21 / 2,48 | 8,00 / 8,07 | 40,80 / 36,37 | 2,42 / 2,25 | 0,93 / 0,93 | 2,14 / 2,00 | 1,02 / 1,00 | — |
| D5/D6 | 2,12 / 2,33 | 7,43 / 7,05 | 41,67 / 37,09 | 2,63 / 2,50 | 1,12 / 1,16 | 2,31 / 2,14 | 1,38 / 1,25 | — |
| D10/D9 | 1,83 / 1,89 | 5,86 / 5,57 | 34,76 / 34,02 | 2,84 / 3,10 | 1,14 / 1,45 | 0,72 / 0,70 | -0,75 / -1,08 | offsid |

Semilla 20261001:

| Partido | Goles | Remates | Pases completos | Faltas | Amarillas | Puntos de A | Diferencia de A | Fuera de rango |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| D1/D1 | 2,26 / 2,31 | 8,18 / 8,34 | 37,81 / 36,87 | 2,17 / 1,89 | 0,81 / 0,85 | 1,15 / 1,19 | -0,29 / -0,38 | — |
| D2/D2 | 2,36 / 2,34 | 8,51 / 8,09 | 37,95 / 36,58 | 2,41 / 2,12 | 1,06 / 0,91 | 1,23 / 1,38 | -0,23 / -0,12 | — |
| D3/D3 | 2,38 / 2,13 | 8,21 / 7,92 | 38,23 / 36,74 | 2,57 / 2,15 | 0,95 / 0,96 | 1,17 / 1,48 | -0,38 / 0,16 | — |
| D4/D4 | 2,25 / 2,06 | 7,95 / 7,42 | 39,39 / 36,45 | 2,88 / 2,33 | 1,14 / 1,14 | 1,22 / 1,27 | -0,26 / -0,16 | — |
| D5/D5 | 2,15 / 2,21 | 7,56 / 7,34 | 38,54 / 36,55 | 2,96 / 2,40 | 1,12 / 1,09 | 1,43 / 1,40 | 0,03 / -0,19 | — |
| D6/D6 | 1,90 / 1,95 | 6,98 / 6,92 | 38,56 / 36,59 | 2,88 / 2,44 | 1,04 / 1,09 | 1,37 / 1,35 | -0,01 / -0,01 | — |
| D7/D7 | 1,86 / 1,75 | 6,32 / 6,36 | 38,10 / 36,03 | 2,77 / 2,67 | 1,23 / 1,23 | 1,35 / 1,27 | 0,06 / -0,01 | — |
| D8/D8 | 1,92 / 1,63 | 6,50 / 5,92 | 37,83 / 35,17 | 2,85 / 2,74 | 1,11 / 1,25 | 1,57 / 1,32 | 0,27 / -0,04 | offsid |
| D9/D9 | 1,66 / 1,63 | 5,62 / 5,43 | 36,92 / 34,54 | 2,92 / 2,98 | 1,15 / 1,35 | 1,51 / 1,33 | 0,18 / -0,01 | offsid |
| D10/D10 | 1,57 / 1,55 | 5,63 / 5,03 | 36,07 / 33,19 | 2,68 / 3,13 | 1,13 / 1,43 | 1,55 / 1,33 | 0,26 / -0,03 | penale |
| D1/D4 | 4,01 / 4,16 | 11,18 / 8,73 | 45,84 / 36,91 | 1,29 / 2,19 | 0,40 / 1,04 | 2,96 / 2,90 | 3,95 / 3,94 | remate, pases_, faltas, amaril, offsid |
| D5/D8 | 3,04 / 3,58 | 9,16 / 8,05 | 45,49 / 36,81 | 2,42 / 2,31 | 0,94 / 0,94 | 2,87 / 2,87 | 2,77 / 3,34 | pases_, offsid |
| D10/D7 | 2,83 / 3,19 | 8,06 / 7,34 | 35,15 / 34,05 | 2,63 / 2,70 | 1,01 / 1,25 | 0,14 / 0,14 | -2,38 / -2,94 | offsid |
| D1/D2 | 2,27 / 2,56 | 7,75 / 8,23 | 42,13 / 36,27 | 2,15 / 2,01 | 0,75 / 0,89 | 2,19 / 2,14 | 1,13 / 1,10 | — |
| D5/D6 | 2,35 / 2,25 | 7,84 / 7,32 | 41,59 / 36,91 | 2,61 / 2,44 | 1,13 / 1,10 | 2,37 / 2,13 | 1,41 / 1,08 | offsid |
| D10/D9 | 1,87 / 1,78 | 6,06 / 5,48 | 35,14 / 34,31 | 2,84 / 2,96 | 1,10 / 1,25 | 0,82 / 0,67 | -0,66 / -0,95 | offsid |

**Pasa si, uno por uno:**

- **El reporte por división queda dentro de rangos en dos semillas distintas:** pasa en las diez divisiones: goles, remates, pases, faltas, tarjetas y posesión. Quedan sueltos un offside (0,3 contra 0,1; el piso es 0,2) y un gol de más en sexta en una semilla.
- **El mejor equipo gana lo que tiene que ganar:** pasa en las seis parejas desparejas y en las dos semillas.
- **Con tres divisiones de diferencia** quedan fuera de rango los pases completos (+25%), los remates en D1/D4 (+26%) y las faltas y amarillas en D1/D4.
- **Sin correcciones:** 0 correcciones, `SALTO_PELOTA` = 0 y 0 partidos colgados en 6.400 partidos.

**Qué falta:**

1. **Partidos de tres divisiones de diferencia:** ver arriba. El que es mucho peor no llega a presionar ni a hacer falta.
2. **Offsides:** 0,25 a 0,3 por partido en las divisiones parejas y 0,6 con tres divisiones de diferencia (el motor espacial: 0,1).
3. **Posesión por estilo:** ver la etapa 7b.
4. **Bibliotecas:** Windows, Android y Linux rearmadas. `test_reglas_v2` da en Windows la huella 5962262427658054405. La de Linux se arma en la PC con Zig y **falta cargarla en un Linux** (en la PC no hay) y comparar la huella; lo mismo en el teléfono.
5. **Revisión visual:** el usuario tiene que mirar de nuevo.

### Etapa 7b — Identidad de juego

- **Qué:** que el estilo del club (`Estilos`, seis estilos) se vea en la cancha y que ninguno pierda por sistema. Medición: `tests/_diag_estilos_v2.gd` (cada estilo contra el Juego directo, y `todos=1`: todos contra todos, de local y de visitante).
- **Pasa si:** en el todos contra todos ningún estilo saca ni pierde más de 0,15 goles por partido; y el estilo se distingue en pases, largo del pase, pelotazos y altura del bloque.

#### Resultado (2026-10-02): pasa; la posesión no separa a los estilos

Quinta división, semilla 97000. Todos contra todos, 40 partidos por cruce (400 por estilo):

| Estilo | Puntos | Goles a favor | En contra | Diferencia | Antes | Posesión | Remates | Pases |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Tiki taka | 1,27 | 1,01 | 1,04 | -0,03 | -0,24 | 50,6% | 3,63 | 27,2 |
| Contragolpe | 1,47 | 1,10 | 0,98 | +0,12 | +0,16 | 49,2% | 3,75 | 17,7 |
| Juego directo | 1,41 | 1,08 | 1,03 | +0,05 | +0,20 | 50,3% | 3,93 | 18,8 |
| Presión alta | 1,35 | 1,11 | 1,12 | -0,01 | -0,11 | 50,7% | 3,77 | 25,6 |
| Defensivo | 1,33 | 0,99 | 1,00 | -0,01 | -0,17 | 48,9% | 3,43 | 18,5 |
| Físico | 1,32 | 1,06 | 1,18 | -0,12 | +0,15 | 50,3% | 4,00 | 19,3 |

Cada estilo de local contra el Juego directo, 100 partidos:

| Estilo | Pases | Llegan | Largo del pase | Pelotazos | Centros | Bloque sin pelota | Goles a favor y en contra |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Tiki taka | 25,9 | 84% | 13,8 m | 0,9 | 1,6 | 39,7 m | 1,07 y 1,05 |
| Contragolpe | 17,2 | 80% | 19,0 m | 3,8 | 2,2 | 36,5 m | 1,11 y 1,09 |
| Juego directo | 17,7 | 78% | 18,3 m | 3,0 | 2,8 | 39,2 m | 1,01 y 1,01 |
| Presión alta | 24,0 | 82% | 15,2 m | 2,1 | 2,2 | 41,9 m | 1,15 y 1,22 |
| Defensivo | 18,1 | 81% | 17,0 m | 2,8 | 2,0 | 35,0 m | 1,03 y 0,97 |
| Físico | 19,4 | 79% | 17,6 m | 2,9 | 2,7 | 39,4 m | 0,98 y 1,13 |

**Por qué perdía el Tiki taka** (`tests/_diag_traza_v2.gd` con `resumen=1`: qué decide un equipo según la zona):

- **Se quedaba tocando en su campo.** Tomaba 43 decisiones por partido a más de 60 m del fondo rival y 15 a menos de 25 m; el Juego directo, 36 y 34. El pase para atrás, que es el más seguro, cobraba todo el premio del estilo.
- **Perdía la pelota igual que los demás:** cada seis pases. La posesión no le alcanzaba para defenderse.

**Qué se hizo** (todo en `data/fisica_v2.json`, "cerebro"; cuenta lo que el plan se aparta del estilo medio, por `estilo_fuerza`):

- `estilo_pase_seguro` (3) y `estilo_riesgo` (0,3): el equipo de toque valora más el pase seguro y no da el arriesgado; el vertical, al revés.
- `estilo_atras` (0,6): el pase para atrás lleva solo parte del premio del estilo.
- `estilo_hueco` (1): el pase al hueco es también del equipo de toque (el último pase), no solo del vertical.
- `estilo_precision` (0,7, `Cerebro::error_de_estilo`): el equipo de toque falla menos el pase raso y el control; el vertical, más. Es lo que lo balancea: con 0,4 el Tiki taka quedaba en -0,24 y con 0,7 en +0,09.
- Cerca del arco el premio al toque se apaga: no le gana al remate.

**Probado y descartado:** que el equipo de toque conduzca menos (`estilo_conduce`) o suelte la pelota cuando lo aprietan. Cuanto más tocaba, peor le iba: -0,47 y -0,69 goles por partido.

**Qué falta:**

1. **La posesión no separa a los estilos:** 49 a 51% para los seis. El equipo de toque da 27 pases y el vertical 18, pero los dos tienen la pelota el mismo tiempo: el de toque la pasa y el vertical la conduce. Para que el Tiki taka llegue a 55-60% tiene que perder menos la pelota (hoy 84% de pases llegan) o recuperarla antes.
2. **Presión:** el bloque de la Presión alta está 7 m más arriba que el del Defensivo, pero no se midió dónde recupera la pelota cada uno.
3. **Revisión visual:** falta mirar un partido de cada estilo.

### Etapa 8 — Integración y corte

- **Qué:** el juego usa el V2 para los partidos del usuario, mirados o simulados; relato, estadísticas, HUD y minimapa leen sus eventos. Se borran el modo 2D, `vista_partido.gd`, `coreografia_partido.gd`, los `_preparar_*` y el motor espacial. Prueba larga en el teléfono (temperatura, batería, memoria).
- **Pasa si:** se cumple la definición de hecho del Resumen.

#### Resultado (2026-10-02): el juego usa el V2 y pasa la prueba del teléfono; falta el corte

**Qué se hizo:**

- **El puente** (`motor_v2/motor_v2.gd`, `MotorV2.simular`): juega el partido entero sin vista y devuelve lo mismo que `MotorEspacial.simular`: marcador, goleadores con su asistencia, registro, eventos para el relato y las estadísticas, experiencia, y los equipos (`Team`) con las tarjetas, las suspensiones, las lesiones, los cambios y la energía del partido. `Liga.jugar_fecha` y `Copa.jugar_partido` lo llaman para el partido del usuario.
- **La receta** (`CerebroV2.receta` y `armar_de_receta`): todo lo que hace falta para armar el partido, como datos. El V2 no deja fotogramas: la pantalla arma el mismo partido con la receta y lo juega de nuevo. La receta viaja en el lugar de los fotogramas (`MotorV2.receta_de`), así no hubo que tocar la liga, las copas ni `GameState`.
- **La pantalla** (`motor_v2/vista_partido_v2.gd`, `VistaPartidoV2`): juega la receta en vivo y la dibuja con `VistaV2`. Reusa el marcador y los controles (`HudPartido`), el minimapa y el relato. Los eventos traen el paso del motor en que pasaron y se cuentan cuando el partido llega a ese paso. Cada club sale con sus colores, sus números y el pelo de cada jugador.
- **El alargue:** el cruce empatado juega dos tiempos de 15 minutos (`ALARGUE_1` y `ALARGUE_2` en `reglas.h`) y, si sigue empatado, la tanda. Antes el V2 iba directo a los penales.
- **En el motor (C++):** el evento del gol trae al que asistió; el gol que entra hasta 3 s después de un remate es del que remató aunque se desvíe; los registros de pases y remates llevan el id del jugador; `energias_por_id` da la energía con la que terminó cada uno, también el que salió.
- **Laboratorio y banco:** `motor_v2/laboratorio_partido.tscn` (el partido como lo ve el juego, sin entrar a una partida) y `motor_v2/banco_etapa8.tscn` (la prueba del teléfono).
- **Test:** `tests/test_motor_v2_puente.gd`: goleadores que cierran con el marcador, expulsados y suspensiones, cambios, energía, eventos que el relato y las estadísticas leen, la receta que repite el partido y los empates de copa que se definen.

**La prueba en el teléfono** (ZTE Z2357N, `banco_etapa8`, tres partidos seguidos en tiempo real):

| Medida | Resultado | Presupuesto |
| --- | --- | --- |
| Partido sin vista | 0,38 s de media, 0,40 el peor (en la PC, 0,11 s) | 3 s |
| Misma semilla, mismo partido | Huella 2972481124117576335 en la PC y en el teléfono | Igual |
| Simulación por cuadro | 0,02 ms (un paso de 20 µs por cuadro) | 4 ms |
| Dibujo | 59,3 fps de media en 984 s; la peor muestra de 30 s, 53,6 | 60 fps |
| Primer medio minuto y último | 57,3 y 60,0 fps: no baja con el calor | No baja |
| Cuadros lentos (más de 33 ms) | 138 en 984 s; el peor, 148 ms | — |
| Memoria | 153 MB al empezar, 194 MB desde el segundo partido | — |
| Batería y temperatura | Del 58 al 54% y de 24,0 a 28,5 °C en 16 minutos | — |

- Con la sombra del sol prendida para el estadio daba 42 fps y 236 llamadas de dibujo. `VistaPartidoV2` la apaga, como la vista actual del juego: 110 llamadas.
- Los cuadros lentos son los cambios: la vista se arma de nuevo cuando alguien entra o sale.

**En la PC:** un partido sin vista tarda 180 ms con el V2 y 998 ms con el motor espacial (con la regresión corriendo al lado). La regresión completa pasa: 0 fallas de 176.

**Pasa si, uno por uno** (la definición de hecho del Resumen):

- **Sin correcciones ni teletransportes:** pasa (etapa 7: 0 correcciones y `SALTO_PELOTA` = 0 en 6.400 partidos).
- **La pelota con física propia:** pasa (etapa 1).
- **Goles, tiros, posesión, pases y faltas en rango:** pasa en las diez divisiones (etapa 7).
- **60 fps y 4 ms de simulación por cuadro en el teléfono:** pasa (59,3 fps y 0,02 ms).
- **Simular sin mirar en menos de 3 s por partido:** pasa (0,38 s).
- **Misma semilla, mismo partido en PC y Android:** pasa.

**Qué falta:**

1. **El corte:** hecho (2026-10-02). Se borraron el motor espacial (`core/motor_espacial.gd`), el laboratorio de animaciones de la interfaz (`core/laboratorio.gd`), el modo 2D y la vista que reproducía fotogramas (`match/vista_partido.gd`, `vista_cancha.gd`, `coreografia_partido.gd`, `sprites_partido.gd`, `oficiales_partido.gd`, `camara_partido.gd`, `texturas_estadio.gd`, `match/3d/vista_cancha_3d.gd` y sus prototipos y galerías), la opción Simulación (3D / 2D) de Opciones, 62 tests y 90 mediciones que los probaban.
   - Lo que el V2 tomaba de ahí quedó en `core/base_partido.gd` (`BasePartido`: medidas, duración, pesos de `data/utility_pesos.json`, rapidez y giro de cada jugador, `clave_de`) y en `match/3d/cancha_3d.gd` (`Cancha3D`: modelos, cámara, clip de andar). El pelo y el número, en `AtlasJugadores`; los nombres y los tiempos del relato, en `RelatoPartido`; el nivel del estadio, en `EstadoCancha.nivel_estadio`.
   - La calibración compara contra lo que daba el motor espacial con las semillas 97000 y 20261001, guardado en `docs/mediciones/calibracion_v2/` antes de borrarlo.
   - `scratch/` tiene `.gdignore`: sus scripts usaban el motor viejo y Godot ya no los lee.
   - Arreglado al pasar los tests: el puente buscaba a los jugadores solo por id y, con ids repetidos entre los dos clubes (los tests arman los dos desde 0), anotaba goles y experiencia al equipo equivocado. Ahora busca por equipo e id.
   - Queda con el nombre viejo: el resultado sigue llevando la receta en la clave `fotogramas` (`MotorV2.receta_de`), para no tocar la liga, las copas ni el guardado.
1. **La tanda de penales:** hecho (2026-10-02). La tanda del V2 convertía el 69% (uno de cada cinco penales afuera o al palo) y la del motor abstracto, el 83%: `reglas.penal_error` = 0,55 la deja en 81%. Cada equipo pateaba al arco que ataca: ahora `PartidoVistoV2` gira la cancha según quién patea, con un corte entre penales. El evento del penal trae al que pateó (antes, -1).
2. **La experiencia por lo que hizo cada uno:** hecho (2026-10-02). `MotorV2._experiencia` reparte como `MotorEspacial.xp_normalizada`: el 55% por lo que hizo (pases, pelotazos, centros, remates, cabezazos, quites, barridas, controles perdidos y atajadas) y el 45% por el puesto, por los minutos jugados. El total sigue siendo un punto por partido entero.
3. **El relato:** hecho (2026-10-02). El motor anota el quite al que tenía la pelota dominada (`EV_QUITE`, 12 por partido) y el pase lleva su minuto. El puente arma el evento del centro (quién lo gana, quién lo despeja o si lo descuelga el arquero) con el registro de pases.
4. **La pantalla:** hecho (2026-10-02).
   - **Estadio:** `VistaV2.poner_estadio` saca del modelo las tribunas, las torres o los carteles según el nivel de la cancha del local (`VistaCancha.nivel_estadio_desde_calidad`) y seca el pasto. El potrero queda sin nada alrededor.
   - **Festejo:** el que hizo el gol y los tres compañeros más cercanos corren al banderín y festejan (`reglas.festejo_seg` = 7 s); después hay un corte al saque del medio, como después de una tarjeta. Medido en 19 goles (`tests/_diag_festejo_v2.gd`): 18 llegan y festejan 1,8 s; la parada dura 8,8 s.
   - **Cambios:** `VistaV2.recomponer` arma solo el modelo del que entra. Antes armaba la vista entera (148 ms en el teléfono). Medido en el teléfono después del corte (`banco_etapa8`, que ahora anota qué pasa en cada cuadro lento): ningún cuadro lento coincide con un cambio. Tres partidos: 59,7 fps de media (antes 59,3), la peor muestra de 30 s 58,4 (antes 53,6), 64 cuadros lentos en 973 s (antes 138). El peor (132 a 145 ms) es el armado de la vista al empezar cada partido; los demás (35 a 90 ms) vienen en rachas sin ningún evento del motor. Misma huella en la PC y en el teléfono (4051476120597568516).
5. **Jugadas preparadas** (`core/jugadas.gd`): hecho (2026-10-02). Las siete salen del V2. Test: `tests/test_jugadas_v2.gd`. Medición: `tests/_diag_jugadas_v2.gd`.
   - **Córner corto:** el compañero más cercano de los que esperan afuera del área se para a 7 m del banderín. El que saca se la toca y él centra apenas la controla.
   - **Córner en bloque:** suben al menos cuatro, se juntan en el segundo palo y arrancan juntos cuando el que saca va a la pelota. El centro va adonde llegan.
   - **Amague de tiro libre:** el de más tiro se para a 4 m de la pelota, del lado del medio. El que saca se la toca y él le pega de primera, con el error de una pelota quieta.
   - **Defensa adelantada:** la línea defensiva se para 1,5 m más arriba (`PlanEquipo.paso_defensa`).
   - **Presión tras pérdida:** mientras el rival sale de la recuperación, el segundo hombre va a la pelota desde un 35% más lejos (`PlanEquipo.contrapresion`).
   - El saque espera 4 s más cuando hay jugada. Si el socio no llegó a su lugar, se saca normal.
   - El motor anota `EV_JUGADA` y el puente lo pasa al relato.

   | Medida (el local sabe la jugada, el rival no) | Sin jugada | Con jugada |
   | --- | --- | --- |
   | Goles en los 10 s después de 400 córners forzados | 11,5% | Corto 13,0%; en bloque 14,8% |
   | Goles en los 10 s después de 400 tiros libres de frente forzados | 11,5% | Amague 16,3% |
   | Offsides del rival por partido (400 partidos, división 3) | 0,10 | Defensa adelantada 0,13 |
   | Quites por partido y diferencia de gol (400 partidos) | 6,9 y +0,02 | Presión tras pérdida 7,2 y +0,06 |

   - Las de córner salen poco: hay 0,3 córners por equipo por partido. Su valor está en verse, como en el motor espacial.
   - La calibración (`tests/_diag_calibracion_v2.gd`) arma clubes sin jugadas: no cambia.
6. **Los modificadores de equipo:** hecho (2026-10-02). El V2 no aplicaba los bloques A a D de `MatchEngine._bloques_equipo` (localía, forma del día, armonía, racha, familiaridad táctica, choque de estilos, clima, cancha, público, rasgos): el local sacaba −0,06 goles por partido y el motor espacial, +0,49. Ahora `MatchEngine.modificador_de_equipo` los promedia por equipo y `CerebroV2.receta` los suma a los puntos de media (`nivel.puntos_por_modificador` = 0,5 de `data/fisica_v2.json`). Medición: `tests/_diag_localia_v2.gd`.

   | Diferencia de gol del local | Motor espacial | V2 |
   | --- | --- | --- |
   | Primera (300 y 600 partidos) | +0,55 | +0,56 |
   | Quinta (400 y 1.000) | +0,49 | +0,55 |
   | Décima (300 y 600) | +0,47 | +0,42 |
   | Quinta, armonía +5 contra −5 | +1,36 | +1,56 |
   | Quinta, armonía −5 contra +5 | −0,42 | −0,38 |

   - Entran una sola vez, al armar el partido, y por equipo. Lo que el motor espacial aplicaba por duelo (la química de a pares, el rasgo del DT según el marcador y el minuto, el capitán) queda promediado.
7. **Los pateadores que elige el club y el penal:** hecho (2026-10-02). El V2 no leía Equipo > Roles: el córner, el tiro libre y el penal los sacaba siempre el mejor de los que estaban cerca. Ahora el elegido saca si está en la cancha (`FichaReglas.designado`; el penal, esté donde esté; lo demás, hasta 80 m, como en el motor espacial). El penal se patea con el tiro que dan los rasgos (`Personalidad.bonus_penal`) y el ejercicio de penales. Test: `tests/test_jugadas_v2.gd`.
8. **La biblioteca de Linux:** descartada (2026-10-02). El juego sale para Android y se desarrolla en Windows; la nube ya no se usa. Se sacaron la biblioteca, su entrada en `motor_v2.gdextension` y `motor_v2/cpp/zig`.
9. **Revisión visual** en una partida de verdad: un partido de liga y uno de copa.

#### Resultado (2026-10-03): revisión en el teléfono

El usuario miró partidos en el teléfono (APK) y marcó ocho cosas. Cada arreglo se midió antes y después con la misma semilla.

| Lo que vio el usuario | Qué era | Antes | Después |
| --- | --- | --- | --- |
| Arrastran los pies al moverse | Los gestos corriendo (el toque de la conducción, el remate, el pecho) están hechos en el lugar; los fundidos partían de una pose congelada; el arquero se deslizaba en guardia hasta 1,6 m/s | Toque de la conducción: 100 m patinados por partido; pecho 32 m; guardia del arquero 296 m | 9 m, 3 m y 66 m |
| Control de pelota, estadísticas | El usuario decide ver las estadísticas cuando esté el juego completo | — | — |
| Cabezazos con poca fuerza | `remate.cabeza_*_ms` 9-14 m/s | Córner con gol 3,1%; entra el 2% de los cabezazos | 13-20 m/s: 3,8% y 4% |
| Tirones en remates, córners y tiros libres | La placa movía los 33.155 vértices de la malla de cada jugador (ver abajo) | 36 a 41 cuadros de más de 33 ms por partido | 0 |
| Voleas: centros que se pierden al controlarlos | El centro se jugaba de primera solo desde `primera_geometria` | 1,69 remates de primera con la pelota en el aire por partido | `primera_geometria_centro` 0,15: 1,91 |
| El arquero se para de golpe después del gol | La estirada deja la cadera 1,3 m al costado y el cuerpo no se movió | Tirado a parado en un cuadro | `Arquero_Levanta` con la pelota fuera de juego o en las manos |
| Cabecean cuando la quieren bajar de pecho | La cabeza del chibi empieza a 0,87 m; el control de una pelota a esa altura era de cabeza | ~200 controles de cabeza debajo de 1,3 m en 40 partidos | ~30; van de pecho con un salto (`toque.pecho_control_hasta` 1,3 m) |
| El arquero sale y el centro le pasa por arriba | Se tiraba "a tiempo" aunque no llegara, a cualquier distancia | Primera: 0,40 salidas falladas por partido; décima: 0,30 | 0,28 y 0,20; el de poco achique calcula mal (`salida_error_*`) |

- **Fundido con el clip viejo andando** (`Jugador3D.poner`): el clip viejo sigue a su ritmo mientras se funde. Trotar a Correr patinaba 51 m por partido; ahora 24.
- **Piernas de la carrera** (`Jugador3D.piernas_de`, `VistaV2._piernas_de_carrera`): debajo de un gesto que se hace corriendo, la cadera y las piernas van con el clip de andar en cinta; la pierna que toca va con el gesto cerca del contacto.
- **Goles sin autor:** el pase o el centro que entra directo es gol del que lo dio. Quedan los goles en contra de verdad: 6 de 659 en 300 partidos. `test_estadisticas_liga` los acepta (pasaba por la semilla).
- **`test_jugadas_v2`** sigue hasta 40 partidos para ver la defensa adelantada: en 10 no salía una de cada cuatro semillas.

**Los tirones (arreglado, 2026-10-03).** En la PC no aparecen: el motor tarda 2,5 ms en el peor paso y la vista 2,9 ms en el peor cuadro (`tests/_diag_pasos_lentos_v2.gd`, `tests/_diag_cuadros_lentos_v2.gd`, `tests/_diag_dibujo_v2.gd`). Medido en el teléfono con `banco_etapa8` (un partido, `fps=60`, semilla 20261108):

| Medida | Antes | Con media resolución y sin MSAA | Con las mallas compactas |
| --- | --- | --- | --- |
| Cuadros de más de 33 ms | 36 a 41 | 13 | 0 |
| Peor cuadro | 83 ms | 100 ms | 25 ms |
| Código de la pantalla por cuadro (motor) | 3,98 ms (0,1 a 0,5) | 3,82 ms | 3,63 ms |

- **Dónde se iba el tiempo.** En los tirones el código de la pantalla tarda 3 a 7 ms: el resto es espera. `simpleperf` con `--trace-offcpu` muestra al hilo principal bloqueado en `BufferQueueProducer::waitForFreeSlotThenRelock` (dentro de `glDrawArrays` del driver Mali) en 39 de 41 tirones: la placa no terminaba los cuadros y la pantalla no devolvía un buffer libre. Caían en rachas de medio segundo con todos los jugadores en cuadro cerca de un arco: remates, córners y tiros libres.
- **La causa.** La malla del GLB trae los diez peinados y la cara modelada: 33.155 vértices. Cada jugador dibuja 4.900 a 10.000, pero la placa mueve con el esqueleto todos los vértices de la malla en cada cuadro: 760 mil con 23 personajes.
- **El arreglo.** `Jugador3D._compactar` arma la malla de cada peinado solo con los vértices que usa (unos 175 mil por cuadro en total). Se ve igual. `tests/test_peinados_3d.gd` lo controla.
- **Cómo se mide de nuevo.** El banco se exporta como app aparte (`uy.cekasiete.bancov2`) con `run/main_scene` en `banco_etapa8.tscn` y los argumentos en `command_line/extra_args`. Argumentos nuevos: `fps=N`, `escala=N`, `msaa=N` y `sin=hud,minimapa,manchas,estadio,jugadores`. Cada cuadro lento anota el código de la pantalla, el motor, el dibujo en la CPU, la pelota y los triángulos.

#### Resultado (2026-10-03): pie clavado, arquero que se levanta en juego y mallas más rápidas

Cinco pendientes de la revisión del teléfono. Hecho en la PC y medido en el teléfono (ZTE Z2357N) con `banco_etapa8`.

**1 y 2. El pie apoyado queda clavado en la cancha.** Derecho, los clips en cinta ya dejan quieto el pie apoyado. Se movía por tres causas: el modelo gira con el pie apoyado lejos del centro, la marcha cambia de dirección y los fundidos mezclan dos pasos.

- **Pie clavado** (`Jugador3D.clavar_pies`): el pie apoyado queda en el punto de la cancha donde pisó y la pierna se dobla para llegar (IK de dos huesos, `_doblar_pierna`). La cadera baja hasta 5 cm si la pierna no alcanza. Si el pie queda a más de 10 cm de donde lo pone el clip, da un paso corto (0,12 s, levanta 4 cm).
- **Cuándo un pie está apoyado** (`Jugador3D._apoyo_de`): sale de las pistas del clip. Apoyado es el pie que casi no se mueve contra el piso de la cinta (`avance_m`). Por la altura sola no se puede: en Caminar el pie en el aire sube 2 a 3 cm, menos que el pie de Trotar cuando despega.
- **El modelo mira según el clip que muestra** (`VistaV2._rumbo_mostrado`): el clip de costado sigue hasta medio ciclo después de que cambia el sentido de la marcha. Con el modelo ya girando hacia adelante, las piernas andaban cruzadas (10° a 13° de desvío medio; ahora 1°).
- **El giro de 90° va atado al fundido** (`VistaV2._giro_al_cambiar`): de costado a adelante el modelo gira lo mismo que pesa el clip nuevo.
- **`Correr_Costado_Der` va medio ciclo corrido** (`Jugador3D.arranca_con_el_otro_pie`): es el espejo de `_Izq` y arranca con el otro pie. Al pasar a Trotar se fundían dos pasos con el pie cambiado.
- **Solo en cámara:** la vista clava los pies de los que la cámara muestra (`VistaV2._en_camara`). Costo en la PC: el código de la pantalla pasa de 0,55 a 0,71 ms por cuadro (`tests/_diag_cuadros_lentos_v2.gd`).
- **Costo en el teléfono** (un partido, `fps=60`, semilla 20261108): el código de la pantalla pasa de 3,73 ms por cuadro (`clavados=0`) a 4,25 y 4,27 ms (dos corridas). En los dos casos da 60,0 fps y 0 cuadros de más de 33 ms.
- **Detector PATINA:** el suelo de cada clip arranca en el del clip (`Jugador3D.suelo_de`). Antes, hasta ver el clip entero contaba como apoyado el pie que iba por el aire.

Un partido de quinta, semilla 20261201 (`tests/_diag_patina_partido_v2.gd`; `clavados=0` mide sin el pie clavado):

| Pie apoyado | Antes | Después |
| --- | --- | --- |
| Correr_Costado_Izq / Der | 50% / 41% de lo que avanza el cuerpo | 5% / 4% |
| Correr_Espaldas | 44% | 3% |
| Caminar | 33% | 13% |
| Trotar / Correr | 10% / 7% | 2% / 2% |
| Media_Vuelta_Izq / Der | 40% / 38% | 7% / 7% |
| Fundidos, todos | 2.035 m | 223 m |
| De costado a Trotar (498 cambios) | 336 m (0,67 m por cambio) | 61 m (0,12 m) |

En `laboratorio_cuerpo.tscn -- segundos=60` sin pantalla: de costado 1% y 2%, de espaldas 1%, Caminar 8% y los fundidos 0,48 m/s (antes 1,2). Pasan el umbral del 15%. Test: `tests/test_vista_cinta_v2.gd` (de costado a adelante y caminando con cambios de rumbo).

**3. El arquero que da rebote se levanta.** Con la pelota en juego el motor lo para enseguida para que llegue al rebote (`Canchita::_levantarse`). El modelo pasaba de tirado, con la cadera 1,3 m al costado, a parado en 0,15 s. Ahora la vista le hace el final de `Arquero_Levanta` en 0,5 s (`VistaV2.LEVANTA_RAPIDA_SEG`). El modelo se queda donde cayó y alcanza al cuerpo al apoyar el pie. El motor no cambia: los goles son los mismos y no hay que rearmar las bibliotecas. Test: `tests/test_vista_cinta_v2.gd`.

**4. La salida del arquero a los centros tiene test.** `tests/test_arquero_salidas_v2.gd`: un arquero solo y un centro que cae al área chica, diez semillas por caso. Al centro a la altura de las manos (1,2 y 1,8 m) salen el de achique 100 y el de achique 0 y lo tocan. Al que pasa por arriba (2,7 y 3,1 m) el de achique 100 no sale y al de achique 0 le pasa por arriba las diez veces.

**5. Las mallas de la cara y los peinados.** El primer partido arma la malla de cada peinado que aparece. `Jugador3D._preparar` arma una sola vez lo que comparten todos (el cuerpo sin la cara modelada) y cada peinado solo suma su pelo. Antes cada peinado recorría la malla entera. Las mallas son las mismas, triángulo por triángulo.

| En la PC (`tests/_diag_mallas_3d.gd`) | Antes | Después |
| --- | --- | --- |
| Armar la pantalla del primer partido | 183 ms | 88 ms |
| De eso, las mallas (10 peinados y el arquero) | 160 ms | 53 ms |
| Armar la pantalla del segundo partido | 23 ms | 23 ms |

| En el teléfono (`banco_etapa8`, `partidos=2 velocidad=16`) | Antes | Después |
| --- | --- | --- |
| Armar la pantalla del primer partido | 951 ms | 405 a 437 ms (tres corridas) |
| De eso, las mallas | sin dato (unos 780 ms: la diferencia) | 255 a 259 ms |
| Armar la pantalla del segundo partido | 70 ms | 66 ms |

El banco anota la medida en la línea "armar la pantalla del partido".

**Qué falta:**

1. Revisión visual de esta vuelta en el teléfono.
2. `Giro_90_Izq/Der` con el cuerpo andando (0,2 a 0,3 m/s) todavía desliza: 35 m por partido. Hecho: ver el resultado que sigue.
3. `Trotar -> Frenada` entra sin esperar el pie del clip: 17 m por partido. Hecho: ver el resultado que sigue.

#### Resultado (2026-10-03): giros, frenada, gestos corriendo y tres clips nuevos

Hecho en la PC. Los cambios 1 a 3 son de la vista: el motor no cambia y no hay que rearmar las bibliotecas. Medido con `tests/_diag_patina_partido_v2.gd`, un partido de quinta, semilla 20261201.

**1. `Giro_90` con el cuerpo andando.** La causa no era el giro: era su primer cuadro. El giro entraba sin fundido desde el clip de andar. Los pies saltaban 12 a 17 cm, del paso a la pose parada del giro. Eran 29 de los 35 m. Ahora la entrada funde como cualquier cambio de clip (`VistaV2._empezar_una_vez`). La salida sigue sin fundido: ahí el modelo gira de golpe lo que giró la cadera del clip.

**2. `Trotar -> Frenada`.** El que frena pasa de Correr a Trotar a 4 m/s y la Frenada entra a 3,6 m/s. La Frenada entraba en medio de ese fundido 302 de 396 veces. `Jugador3D.poner` fundía entonces desde una pose congelada y el pie apoyado viajaba con el cuerpo: 15,6 de los 17,3 m. Ahora la Frenada espera a que termine el fundido en curso (0,15 s como mucho).

**3. Gestos corriendo.** El detector medía otra cosa. Contaba como apoyado el pie que va a la pelota y el pie del que salta a cabecear. El pie de apoyo no contaba: el suelo del gesto queda 4 cm debajo del suelo de Correr.

- **Detector PATINA** (`DetectorPatinaV2`): debajo de un gesto, cada pie usa el suelo de su clip de andar (`Jugador3D.suelo_del_pie`). El pie que va a la pelota no cuenta (`Jugador3D.pie_en_la_pelota`). El alto se mide desde la cancha, no desde el modelo.
- **Pie de apoyo clavado debajo del gesto** (`Jugador3D.clavar_pies`): usa el apoyo del clip de andar que lleva las piernas (`_anim_piernas`). La pierna que toca se clava recién cuando vuelve a ser de la carrera.
- **El giro hacia la pelota va antes de clavar** (`VistaV2._girar_al_toque`): girando después, el pie ya clavado giraba con el modelo.
- **La pierna que tocó vuelve desde la pose del contacto y por el aire** (`Jugador3D.piernas_de`): el gesto, hecho en el lugar, apoyaba ese pie en el piso mientras el cuerpo corría.
- **Ajuste de pie** (`Jugador3D.llevar_pie`): la segunda vuelta llevaba el pie entero a la pelota con cualquier peso. El pie quedaba pegado a la pelota toda la ventana y volvía de golpe, 30 a 55 cm en un cuadro. Ahora el peso vale en las dos vueltas.

| Metros patinados por partido | Antes | Después |
| --- | --- | --- |
| `Giro_90_Izq` + `Giro_90_Der` | 34,6 | 0,5 (más 5 en sus fundidos) |
| Fundido `Trotar -> Frenada` | 17,3 | 3,2 |
| `Control_Corriendo`, detector viejo (medía el pie de la pelota) | 8,3 | — |
| `Control_Corriendo`, pie de apoyo | 51,4 (43% de lo que avanza el cuerpo) | 4,9 (6%) |
| `Patear_Corriendo`, pie de apoyo | 12,5 (51%) | 2,2 (12%) |
| `Pecho` | 1,2 | 0,7 |
| `Cabecear` (el detector viejo contaba 7,4 m del que salta) | 0,2 | 0,1 |
| Fundidos, todos | 223 | 203 |

Costo: el código de la pantalla pasa de 0,71 a 0,74 ms por cuadro en la PC (`tests/_diag_cuadros_lentos_v2.gd`).

**4. Clips nuevos de Blender.** `tools/blender/animaciones_jugador.py`, armados sin pantalla en `jugador_chibi.blend` y `golero_chibi.blend`. Los clips viejos salen iguales: `data/acciones_v2.json` solo suma líneas.

- **`Control_Muslo`** (0,75 s, toca a los 0,19 s): sube el muslo derecho, baja con la pelota y la deja caer al pie. Punto nuevo del modelo: `Muslo_R`, la cara de adelante del muslo. `toque.clip_recepcion` lo usa para el muslo en lugar de `Pecho`. `Pecho` toca en su primer cuadro: el gesto arrancaba cuando la pelota ya había pegado. Este cambio sí mueve el motor: ver la tabla.
- **`Volea_Costado`** y **`Cabecear_Corriendo`**: variantes que elige la vista (`VistaV2.VARIANTES`, `_clip_mostrado`). Duran lo mismo y tocan en el mismo segundo que `Volea` y `Cabecear`. El motor no sabe de ellas: el partido es el mismo. La vista muestra el cabezazo en carrera si el que cabecea llega a 1,8 m/s o más (2 a 9 veces por partido en 8 partidos). Muestra la volea de costado si la pelota le cruza o el arco le queda al costado, a 50° o más de adonde mira (5 de 10 voleas en 16 partidos).

| 200 partidos de quinta, semilla 97000 (`tests/_diag_aereos_v2.gd`) | Muslo con `Pecho` | Muslo con `Control_Muslo` |
| --- | --- | --- |
| Controles de muslo por partido | 3,1 | 4,8 |
| Controles de pecho por partido | 5,9 | 4,5 |
| El que controla de muslo se queda con la pelota | 93% | 95% |
| Goles por partido | 2,20 | 2,21 |
| Remates por partido | 7,75 | 7,58 |

Hay más controles de muslo porque el gatillo mira la pelota en el cuadro de contacto de cada clip: la que hoy está a la altura del pecho, 0,19 s después está a la del muslo.

Test: `tests/test_vista_cinta_v2.gd` suma seis casos. Cada uno falla si se saca su arreglo (probado con el giro, la frenada y el pie clavado).

**Qué falta:**

1. Revisión visual en el teléfono: no se pudo verificar. En la PC se miraron hojas de cuadros con render real de los cuatro casos y de los tres clips.
2. `Volea_Costado` es solo de pierna derecha, como `Volea`.
3. El cabezazo en carrera es una variante de la vista: el cuerpo del motor frena igual que con `Cabecear`. Un cabezazo que no frene es un cambio del motor (C++).
4. Los fundidos de costado a `Trotar` siguen siendo lo que más patina: 73 m por partido (39 desde `Correr_Costado_Der` y 34 desde `_Izq`, en 533 cambios).

#### Resultado (2026-10-03): revisión de los pendientes de juego y calibración

Los ocho pendientes de "Qué falta" de las etapas 7, 7b y 8, medidos de nuevo. Quinta división, semilla 97000, salvo donde dice otra cosa. Tres se arreglaron; el motor cambia y las bibliotecas de Windows y Android están rearmadas (`test_reglas_v2`: huella 369205416129417478 en Windows).

| Pendiente | Lo que decía | Medido antes | Después |
| --- | --- | --- | --- |
| Rival pegado al que saca el lateral | A menos de 2 m en las capturas | A 1,88 m del punto de la raya; a menos de 1,9 m en el 41% de los laterales y a menos de 1,5 m en el 13% | 2,10 m; 5% y 1% |
| Offsides | 0,25 a 0,3 (el motor espacial: 0,1) | 0,12 a 0,34 en las divisiones parejas; 0,54 a 0,63 con tres de diferencia | 0,08 a 0,21; 0,32 a 0,40 |
| Despejes | 5,9 por partido (el motor espacial: 2 a 4) | 7,35; el 45% va al rival | 3,80 (de quinta a décima 3,3 a 4,0; de primera a cuarta 4,4 a 5,7) |
| Globos | Un tercio de los pases | 36% (pelotazos, centros y despejes) | 27% |
| Pelota afuera después de un control | 1,25 por partido | 0,57: ya había bajado | 0,22 |
| Posesión por estilo | 49 a 51% | 49,0 a 50,6% | 49,5 a 51,0%: sigue |
| El área en los ataques por la banda | 0,87 compañeros contra 3,5 rivales | 1,07 contra 3,28; ninguno el 48% del tiempo | 0,96 contra 3,21; ninguno el 51%: sigue |
| El pasador no busca su pase | 2,5 s (`DESCANSO_PASE_PROPIO`) | 2,2 a 2,9 pases por partido viajan más de 2,5 s (el 5 a 6%); 1,0 a 1,4 de esos se pierden | No se tocó |

**Qué se hizo:**

- **Lateral** (`Canchita::_ubicar`). El que marca al que saca va a la pelota. La pelota está en las manos, a 0,2 m del punto y a veces afuera de la raya. El lado hacia el que se alejaba cambiaba con ese 0,2 m: cruzaba por el punto y el recorte a la cancha lo dejaba en la raya. Ahora el que ya está cerca se aleja derecho desde donde está parado. Medición: `tests/_diag_lateral_v2.gd`.
- **Offsides.** `fisica.offside_margen_torpe` de `data/utility_pesos.json` baja de 5,5 a 1,0: el delantero de poca inteligencia se pasa de la línea 1 m, no 5,5. Los goles no cambian.
- **Despejes.** `fisica.presion_despeje` sube de 0,45 a 0,6: el apretado en su campo revienta la pelota la mitad de las veces. Con 0,75 son 2,5 por partido.
- **Faltas.** Con menos despejes el apretado se queda con la pelota y le entran más: las faltas subían a 2,87 en tercera y 3,22 en sexta (el motor espacial: 2,29 y 2,65). `reglas.entrada_prob` baja de 0,55 a 0,5.

**Presión: dónde recupera la pelota cada estilo** (`tests/_diag_recupera_v2.gd`, 60 partidos, el local con cada estilo contra el Juego directo). La altura es en metros desde su línea de fondo.

| Estilo | Recuperaciones | Altura | En campo rival | El rival la tiene | Quites | Posesión |
| --- | --- | --- | --- | --- | --- | --- |
| Tiki taka | 12,2 | 41,0 m | 35% | 5,8 s | 6,3 | 50,4% |
| Contragolpe | 11,4 | 38,3 m | 32% | 6,5 s | 6,1 | 49,5% |
| Juego directo | 11,8 | 38,5 m | 32% | 6,4 s | 5,8 | 49,4% |
| Presión alta | 13,7 | 44,6 m | 39% | 5,4 s | 7,1 | 50,6% |
| Defensivo | 12,1 | 39,9 m | 33% | 6,3 s | 6,6 | 50,3% |
| Físico | 11,9 | 36,6 m | 28% | 6,4 s | 6,6 | 49,0% |

La Presión alta recupera 6 m más arriba que el Contragolpe, dos veces más por partido y un segundo antes. No le alcanza para tener más la pelota.

**Tres divisiones de diferencia** (`tests/_diag_desparejo_v2.gd`, 100 partidos por pareja). "Aprieta": parte del tiempo en que el rival tiene la pelota dominada y hay un hombre suyo a menos de 3 m.

| Equipo | Posesión | Faltas | Quites | Recupera a | Aprieta | Su hombre más cercano |
| --- | --- | --- | --- | --- | --- | --- |
| D5 contra D5 (los dos) | 49,8 y 50,2% | 1,14 y 1,33 | 6,5 y 6,0 | 38,9 y 45,1 m | 40 y 54% | 4,1 y 3,5 m |
| D1 contra D4 | 59,3% | 0,94 | 10,1 | 61,6 m | 70% | 3,0 m |
| D4 contra D1 | 40,7% | 0,74 | 6,2 | 27,0 m | 25% | 5,4 m |
| D5 contra D8 | 56,6% | 1,29 | 8,8 | 58,5 m | 72% | 3,1 m |
| D8 contra D5 | 43,4% | 1,02 | 6,0 | 29,2 m | 30% | 4,8 m |
| D7 contra D10 | 55,0% | 1,56 | 6,7 | 53,9 m | 71% | 3,1 m |
| D10 contra D7 | 45,0% | 1,25 | 5,3 | 30,9 m | 31% | 4,9 m |

El peor aprieta la mitad que en un partido parejo y recupera 10 m más atrás. Faltas hace menos solo el D4 contra el D1; ahí también el D1 hace pocas.

**Calibración** (`tests/_diag_calibracion_v2.gd`, 200 partidos por escenario, semillas 97000 y 20261001), antes y después de esta vuelta:

- **Divisiones parejas:** 17 de 20 pasan. Quedan afuera por goles sexta en la semilla 97000 (2,33 contra 1,75) y octava y novena en la otra (1,97 y 1,99 contra 1,63). Antes: sexta fallaba igual en la 97000 (2,13); en la 20261001 se midieron solo sexta, octava, novena y décima, y fallaban octava por goles (2,04) y décima por amarillas y rojas. Con 600 partidos por división (semilla 500000) los goles de octava a décima dan 1,94, 1,99 y 1,76 antes y 1,99, 1,99 y 1,83 después: no cambian.
- **D1/D4:** 4 de 10 afuera, igual que antes: remates +23 a 30%, pases completos +28 a 31%, faltas 1,62 contra 2,20 y amarillas 0,56 a 0,68 contra 1,0.
- **D5/D8:** los pases completos, +29%. **D10/D7:** pasa.
- **Divisiones vecinas:** D1/D2 queda afuera en los puntos y en la diferencia de gol (0,42 a 0,46 contra 1,0 a 1,1) y D5/D6 en una semilla (0,77 contra 1,25). En esos escenarios el equipo A juega siempre con el Tiki taka o la Presión alta contra el Juego directo o el Contragolpe, que les ganan por la tabla de `Estilos.MATRIZ`. En los parejos el A pierde por 0,2 a 0,8 goles (de primera a sexta, 0,5 a 0,8) y con el motor espacial perdía por 0,1.

**Todos contra todos por estilo** (40 partidos por cruce): Tiki taka -0,16, Contragolpe +0,12, Juego directo +0,03, Presión alta -0,23, Defensivo +0,23, Físico +0,01. La etapa 7b pedía ±0,15 y medía -0,03 a +0,12. Esa medida es de antes de los modificadores de equipo de la etapa 8, que suman el choque de estilos de `Estilos.MATRIZ`: el Tiki taka y la Presión alta son los que más cruces pierden en la tabla. El error de cada número es 0,08.

**Qué falta:**

1. **El choque de estilos pesa más que en el motor espacial:** ver arriba. Hecho: la tabla se sacó (ver el resultado que sigue).
2. **Posesión por estilo:** 49,5 a 51,0%. La presión ya se ve en dónde se recupera; falta que el equipo de toque pierda menos la pelota.
3. **El área en los ataques por la banda:** 0,96 compañeros contra 3,21 rivales.
4. **D1/D4:** el peor no llega a apretar. Es la diferencia de rapidez que hace ganar al favorito: la decisión abierta de "Primera contra cuarta".
5. **Offsides con tres divisiones de diferencia:** 0,32 a 0,40 contra 0,11 a 0,17.
6. **Despejes de primera a cuarta:** 4,4 a 5,7.
7. **Goles de sexta para abajo:** en el borde de arriba del rango.
8. **El pasador y su pase:** no se tocó. Afecta a 1 pase por partido.
9. **El teléfono:** falta comparar la huella de `test_reglas_v2` y mirar un partido.

#### Resultado (2026-10-03): ningún estilo le gana a otro por tabla

Decisión del usuario: la ventaja de un estilo sobre otro sale de cómo juega cada uno en la cancha, no de puntos de más. Ejemplo que dio: la defensa adelantada contra el contragolpe queda mal parada porque, si falla el offside, el rival queda solo frente al arquero.

**Qué se hizo:** se borraron `Estilos.MATRIZ`, `Estilos.BONUS`, `Estilos.BONUS_CONTRA_PRESION` y `Estilos.modificador`, y su suma en el bloque C de `MatchEngine._bloques_equipo`. Sale de los dos motores: del V2, que la recibía por `MatchEngine.modificador_de_equipo`, y de `MatchEngine`, que simula los partidos de los demás clubes. El motor en C++ no cambia: no hay que rearmar las bibliotecas. `tests/test_estilos.gd` ya no prueba la tabla.

**Todos contra todos** (`tests/_diag_estilos_v2.gd` con `todos=1`, quinta, 40 partidos por cruce). Diferencia de gol por partido:

| Estilo | Con la tabla (97000) | Sin la tabla (97000) | Sin la tabla (20261001) |
| --- | --- | --- | --- |
| Tiki taka | -0,16 | +0,04 | -0,13 |
| Contragolpe | +0,12 | +0,14 | +0,01 |
| Juego directo | +0,03 | +0,01 | +0,04 |
| Presión alta | -0,23 | -0,17 | -0,13 |
| Defensivo | +0,23 | +0,01 | +0,06 |
| Físico | +0,01 | -0,02 | +0,14 |

**Qué estilo le gana a cuál por cómo juega.** La medición imprime ahora el cuadro de cruces (80 partidos por cruce; el error de cada número es 0,17). Se repiten en las dos semillas:

- El Contragolpe le gana a la Presión alta: +0,19 y +0,25.
- El Defensivo le gana a la Presión alta: +0,16 y +0,31.
- El Físico le gana a la Presión alta: +0,30 y +0,21.

Los demás cruces cambian de signo de una semilla a la otra: no se distinguen del ruido.

**Calibración** (200 partidos por escenario, las dos semillas):

- **Divisiones vecinas:** D1/D2 y D5/D6 pasan en las dos semillas (diferencia de gol 1,12 a 1,29 contra 1,0 a 1,25). Antes fallaban en tres de cuatro. D10/D9 queda afuera en una semilla (-0,67 contra -1,08).
- **Divisiones parejas:** 18 de 20 pasan. El equipo A pierde ahora por 0,3 a gana por 0,3 (antes perdía por 0,2 a 0,8). Quedan afuera octava y décima en la semilla 20261001, por goles (2,05 y 1,93 contra 1,63 y 1,55).
- **Tres divisiones de diferencia:** D1/D4 sigue con 4 de 10 afuera. D5/D8 suma los remates (+21 a 23%) a los pases completos.

La regresión completa pasa: 0 fallas de 117.

**Qué falta:**

1. **La Presión alta pierde contra casi todos:** -0,13 a -0,17. Recupera más arriba (ver el resultado anterior) pero no saca ventaja de eso y deja la espalda libre.
2. **Los demás cruces no se distinguen:** para que el estilo decida más, cada plan tiene que cambiar más lo que hace el equipo (`Estilos.PLANES`, `cerebro.estilo_*`).
3. **`MatchEngine`:** no lee el estilo. Sin la tabla, en los partidos de los demás clubes el estilo ya no cambia el resultado; solo queda la familiaridad táctica al cambiarlo.

#### Resultado (2026-10-04): identidad por estilo, Presión alta y Contragolpe

Pedido del usuario: el estilo dice qué intenta el equipo y los atributos, qué tan bien le sale. Ejemplos que dio: los defensores buenos de la Presión alta dejan al rival en offside y los malos no; el Contragolpe se mete atrás y sale con pases largos, y si es malo no los sabe dar.

**Medición nueva:** `tests/_diag_identidad_v2.gd`. Cada estilo juega con un plantel bueno y uno malo contra el mismo rival. Opciones: `solo=defensores|volantes|delanteros`, `atributo=<nombre>` (cambia solo ese atributo y deja la media), `rival_estilo=<n>`, `estilos=<n,n>`.

**Antes de tocar** (planteles de 65 contra un Juego directo de 65, 120 partidos por fila):

- Los atributos ya pesaban. Plantel de 95 contra plantel de 35: pases que llegan 85 a 88% contra 64 a 81%; pelotazos que llegan 80 a 86% contra 52 a 63%; recupera a 62 a 64 m de su fondo contra 25 a 34 m.
- La identidad se veía en los pases (Tiki taka 28 por partido de 14 m; Contragolpe 19 de 19 m) y en el primer pase al recuperar (Contragolpe: 49% largo o al hueco; Tiki taka: 77% corto).
- No se veía en lo demás. Los seis estilos recuperaban a 40 a 42 m de su fondo, 4 veces por partido en campo rival, y perdían la pelota antes de 6 s el 45 a 48% de las veces. La posesión era 49 a 51%.
- El offside dependía solo del delantero: la Presión alta con defensores de 95 de inteligencia cobraba 0,06 por partido y con defensores de 35, 0,09.
- Todas las corridas terminaban en la línea del offside (`Cerebro::_destino_legal`): había 3 pases a la espalda por partido.

**Qué se hizo** (C++; los números en `data/fisica_v2.json`, "cerebro", con su nota en `_notas.identidad`):

- **El pique a la espalda** (`Estilos.PIQUE_A_LA_ESPALDA`: Contragolpe 1 y Juego directo 0,7; `PlanEquipo::pique`). El delantero cerca de la línea pica `pique_m` (10 m) detrás de ella si hay espacio hasta el arco. Espera al filo `pique_espera_seg` × 2 × su inteligencia y después cruza: llega lanzado, o queda en offside si el pase tarda. El que tiene la pelota le tira el globo (`pique_bono`, `pique_riesgo`).
- **La trampa del offside** (`Cerebro::_trampa_m`, `trampa_m` 3 m). La juega el equipo de línea adelantada: la Presión alta o la jugada "defensa adelantada". Sale de la inteligencia de centrales y laterales: con 50 de media no hay trampa. Se cuenta en la foto del pase: el paso al frente de verdad no entra en el gesto del pase (0,3 s: el defensor avanza 0,2 m).
- **La presión en campo rival** de la Presión alta: tres más tapan las salidas de la pelota (`presion_alta_cierres`) y el segundo hombre sale desde el doble de lejos (`presion_alta_segundo`).
- **Sin reglas por el nombre del rival.** La salida rápida del Contragolpe valía solo contra la Presión alta, y la Presión alta no cerraba contra el Contragolpe. Ahora valen contra cualquiera.
- **Probado y descartado:** dejar al 9 del Contragolpe arriba sin la pelota. No cambió nada: al recuperar ya había 2,2 compañeros delante de la pelota.

**Después** (mismos partidos):

| Estilo | Posesión | Pases y largo | Pelotazos | Bloque | Offsides que cobra | El rival la tiene | Remates del rival solo |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Tiki taka | 53,2% | 30,2 de 14,0 m | 2,4 | 40,4 m | 0,24 | 5,6 s | 1,54 |
| Contragolpe | 49,2% | 19,3 de 20,6 m | 7,8 | 36,9 m | 0,11 | 6,4 s | 1,98 |
| Juego directo | 49,9% | 21,3 de 19,4 m | 7,6 | 39,4 m | 0,21 | 6,2 s | 1,76 |
| Presión alta | 55,9% | 30,1 de 15,0 m | 3,9 | 45,8 m | 0,96 | 5,2 s | 1,10 |
| Defensivo | 50,8% | 21,3 de 16,9 m | 5,5 | 35,8 m | 0,02 | 6,1 s | 2,26 |
| Físico | 51,2% | 21,5 de 17,8 m | 5,8 | 39,3 m | 0,20 | 5,9 s | 1,61 |

**La trampa depende de los defensores** (Presión alta contra Contragolpe, 80 partidos por fila; cambia solo la inteligencia de centrales y laterales):

| Inteligencia de los defensores | Offsides que cobra | Goles en contra | Remates del rival solo |
| --- | --- | --- | --- |
| 95 | 1,41 | 1,02 | 1,19 |
| 35 | 0,56 | 1,15 | 1,36 |

Contra el Juego directo (60 partidos): 1,43 y 0,50 offsides; 0,93 y 1,30 goles en contra.

**La escala.** El Barcelona de 2024-25 dejó al rival en offside unas 7 veces por partido, con unos 10 remates del rival: 0,7 offsides por remate. Acá el rival remata 3,6 veces (el partido dura 4 minutos de verdad): 1,4 offsides son 0,4 por remate. Antes eran 0,02.

**Todos contra todos** (40 partidos por cruce, semillas 97000 y 20261001): Tiki taka +0,05 y -0,19; Contragolpe +0,01 y +0,07; Juego directo +0,08 y +0,04; Presión alta -0,10 y -0,12; Defensivo -0,03 y +0,02; Físico -0,01 y +0,18. La posesión separa por primera vez: Presión alta 53,4%, Tiki taka 51 a 52%, Juego directo 48,3%, Contragolpe 47,2%.

**Calibración** (200 partidos por escenario, las dos semillas):

- **Goles, remates, pases, faltas y tarjetas:** como antes. Quedan afuera por goles sexta en una semilla y octava en la otra, y décima por remates en una.
- **La posesión queda afuera en 9 de 20 parejos** (54 a 56% contra 49%). En esos escenarios el equipo A juega siempre con el Tiki taka o la Presión alta contra el Juego directo o el Contragolpe. El motor espacial no separaba la posesión por estilo: ese rango ya no sirve para los parejos. Por lo mismo quedan afuera D10/D7 (49 a 50% contra 42%) y D10/D9 en una semilla.
- **Offsides:** 0,4 a 0,7 por partido en los parejos y 1,3 a 1,4 en D10/D7 (el motor espacial: 0,05 a 0,17).
- **Pases completos:** suben a 40 a 42 (36,6); D1/D2 queda afuera (+22%).

La regresión completa pasa: 0 fallas de 117. Bibliotecas de Windows y Android rearmadas (`test_reglas_v2`: huella 6236477683712598190 en Windows).

**Qué falta:**

1. **La escala de los offsides:** 0,4 por remate del rival contra 0,7 del Barcelona. Subir `trampa_m` más de 3 m deja en offside al que está 3 m habilitado.
2. **El robo arriba no rinde más:** la Presión alta remata 1,2 veces por partido en los 8 s después de recuperar en campo rival, igual que los demás.
3. **El Contragolpe no hace más contras que los demás** contra un rival que no sube (0,42 remates en los 12 s después de recuperar en su campo). Contra la Presión alta, 0,5 a 0,7.
4. **Los otros cuatro estilos:** falta medir y marcar su identidad (Tiki taka, Juego directo, Defensivo, Físico).
5. **El rango de posesión de la calibración:** hay que medirlo con los dos equipos del mismo estilo, o sacarlo.
6. **El teléfono:** falta comparar la huella y mirar un partido.

**Herramientas que acompañan todas las etapas:** un detector nuevo que mide sobre el mundo (no sobre la vista) `SALTO_PELOTA`, `ENCIMADOS` (cápsulas superpuestas), `PATINA` (pie que desliza), `ESPERA` (jugador quieto con la pelota viniendo a él) y ms por frame; y una grabación por semilla que se puede reproducir y rebobinar para ver cualquier minuto.

**Dónde se hace cada etapa:** todas en la PC del usuario. Las etapas 1 y 3 a 6 se hicieron en la nube (Linux); desde el 2026-10-02 la nube no se usa y no hay biblioteca de Linux.

## Cómo se escribe el C++

Reglas para todas las etapas. Salen de lo que midió la etapa 0.

- **Todo el motor en C++.** Mundo, cuerpo, cerebro, reglas y registro van en `motor_v2/cpp/src/`. GDScript solo lee el estado (posiciones, acciones, eventos) para dibujar y contar. Nada de lógica del partido en GDScript.
- **Paso fijo de 1/60 s** para mundo y cuerpo; el cerebro piensa cada 6 pasos, escalonado. Nada depende de los fps.
- **Sin matemática del sistema.** Solo `std::sqrt` (IEEE 754 la redondea igual en todos lados). Seno, coseno y arcotangente salen de `matematica_fija.h`. Si hace falta otra (exp, pow, log), se escribe ahí con +, −, ×, ÷ y raíz. Sin esto, el mismo partido termina distinto en la PC y en Android.
- **`-ffp-contract=off`** en todo lo que no compila MSVC (Android): sin eso clang junta a*b + c en una FMA que redondea distinto. Ya está en `SConstruct`.
- **Un solo generador al azar,** el PCG32 propio de `MundoV2Nativo` (no el `RandomNumberGenerator` de Godot), consumido siempre en el mismo orden.
- **Estado en `double`,** en arreglos planos. Nada de iterar contenedores sin orden fijo (`unordered_map`) en algo que cambia el partido.
- **Parámetros en `data/fisica_v2.json`:** GDScript lee el JSON y se lo pasa al motor al crearlo. Así se calibran sin recompilar.
- **Nombres, comentarios y mensajes en español,** con las mismas reglas de `CLAUDE.md` (el comentario dice por qué y contra qué se midió).
- **Cada etapa tiene su verificación:** un test `tests/test_*.gd` que corre el motor sin vista y compara números (con `FALLOS=n`), y la huella del estado con la misma semilla.

### Cómo se arma la extensión

1. Instalá scons: `python -m pip install scons`.
2. Cloná godot-cpp v10 fuera del repo: `git clone --depth 1 https://github.com/godotengine/godot-cpp` (en la PC está en `D:/dev-tools/godot-cpp`). Poné su ruta en la variable `GODOT_CPP`.
3. Desde `motor_v2/cpp`, ejecutá `python -m SCons api_version=4.7 target=template_release platform=<windows|android>` (Android además `arch=arm64 ANDROID_HOME=... ndk_version=28.2.13676358`).
4. La biblioteca sale en `motor_v2/bin/`. `SConstruct` compila `src/*.cpp` y `src/cerebro/*.cpp`. Después de agregar clases nuevas, ejecutá `<godot> --path . --headless --editor --quit` para que Godot las registre.

## Presupuesto para Android

A 60 fps un frame dura 16,6 ms, y el objetivo es que la simulación use como máximo 4 ms: el resto es para dibujar 22 personajes con esqueleto, el estadio y el HUD. Si un teléfono no llega, se dibuja a 30 fps y el mundo sigue a 60 Hz (dos pasos por frame): el partido es el mismo, solo se ve menos fluido.

| Parte | Frecuencia | Cómo se abarata |
| --- | --- | --- |
| Mundo: pelota + 22 cápsulas | 60 Hz | Integrador propio sin servidor de física; choques solo entre cápsulas cercanas (grilla de 5 m); subpasos solo para la pelota rápida |
| Cuerpo: locomoción y acciones | 60 Hz | Aritmética simple por jugador; las duraciones vienen precalculadas del JSON de clips |
| Cerebro | 10 Hz, escalonado (unos 4 jugadores por frame) | Grilla de apoyo gruesa (unos 12 × 8 puntos); solo 3 o 4 candidatos a recibir evalúan todo; intercepción en fórmula cerrada por rival |
| Animación | Pantalla | Los jugadores lejos de la cámara actualizan el esqueleto cada 2 frames; la malla única por personaje ya bajó las llamadas de dibujo de 1.119 a 264 |
| Sin vista ("simular temporada") | Tan rápido como se pueda | Mismo mundo y cerebro, sin animación ni grabación; en un hilo aparte como hoy (`main.gd`, `_en_segundo_plano`) |

**Memoria.** Grabar los 90 minutos a 10 Hz de 23 cuerpos son más de un millón de muestras: demasiado para un teléfono. Se guarda un búfer circular de los últimos 60 s (para la repetición inmediata) y se congelan los tramos de goles y jugadas destacadas; el partido entero se reconstruye desde la semilla si hace falta.

**Calor y batería.** Un partido animado dura varios minutos a pleno. La etapa 8 incluye una prueba de 3 partidos seguidos en el teléfono de referencia midiendo fps al final; si baja, la opción de 30 fps pasa a ser la de fábrica.

**Determinismo.** Verificado en la etapa 0: con las reglas de "Cómo se escribe el C++" la misma semilla da el mismo partido en la PC y en Android (misma huella después de 90 minutos). Cada etapa vuelve a comparar la huella en los dos.

## Riesgos y decisiones abiertas

El riesgo más grande era el rendimiento de GDScript en el teléfono; la etapa 0 lo cerró pasando el motor a C++. El segundo es que la calibración lleve más que la construcción: cuando el resultado sale de la física, un cambio chico en el rozamiento mueve los goles por partido.

| Riesgo | Qué pasa si ocurre | Mitigación |
| --- | --- | --- |
| GDScript no llega a 4 ms por frame en Android | Partido trabado o batería que se va | Compuerta de la etapa 0; mundo y cuerpo en C++ (GDExtension) |
| Calibración inestable | Goles o posesión fuera de rango al tocar cualquier parámetro | Etapa 7 con 200 partidos por división y reporte automático; cambios de a un parámetro |
| Faltan animaciones | Gestos que se repiten o no calzan (cabezazo en carrera, control de muslo) | Lista de clips por etapa; el ajuste de pie tapa diferencias chicas; proporciones chibi = alcances propios, no los de un humano |
| Etapas intermedias "tontas" | Durante semanas el V2 juega peor que el motor actual | El juego sigue con el motor actual hasta la etapa 8; el V2 se prueba en su propia escena |
| Determinismo entre PC y Android | Un bug visto en el teléfono no se reproduce en la PC | Verificación en la etapa 0; `sin`, `cos` y `atan2` son las sospechosas; tests por estadísticas |
| Alcance que crece (motion matching, ragdoll, choques FIFA 12) | El proyecto no termina | Fuera de este plan; se evalúan después de la etapa 8 |

**Decisiones abiertas:**

- [x] Teléfono de referencia para medir: ZTE Z2357N (Unisoc T760), conectado por adb.
- [x] GDScript o C++ para mundo y cuerpo: C++ (GDExtension). La etapa 0 midió 25 s por partido sin vista en el teléfono con GDScript y 1,5 s con C++.
- [x] El cerebro también va en C++: en GDScript a 10 Hz costaría ~3,7 s por partido en el teléfono (estimado en la etapa 0). Decisión del usuario: todo el motor en C++.
- [x] Sombras en el teléfono: sin sombra del sol, con una mancha bajo cada jugador y la pelota (`match/3d/sombras_redondas.gd`, una sola llamada de dibujo). En el teléfono: 59,5 fps, contra 39,5 con el sol. Dejar el sol solo para el estadio no alcanza: 41,5 fps con 4 cortes y 51 con 1. Ya está en la vista del juego actual (0.7.60).
- [x] Cuánto dura un partido del V2: 4 minutos de verdad (2 por tiempo) con el reloj mostrando 0-90, como el motor espacial. Decisión del usuario en la etapa 7.
- [ ] Primera contra cuarta: el favorito gana el 90% por 2,5 goles y el motor espacial el 98% por 3,8. ¿Se sube el tope de rapidez (20%) o se busca otra palanca? Ver la etapa 7.
- [ ] Si el V2 sin vista resulta lento, ¿los partidos del usuario que se simulan sin mirar pueden ir por `match_engine.gd`? Contradice la decisión 5 del motor espacial ("un solo motor para tus partidos").
- [ ] Repeticiones de goles: ¿entran en la etapa 8 o después?
- [ ] Cámara: ¿se mantiene la actual o se pasa a una de transmisión (lateral alta, como FIFA 10)?

## Fuentes

- [FIFA 10, lo que mostró EA en E3 2009 (GamesRadar)](https://www.gamesradar.com/e3-09-everything-you-need-to-know-about-fifa-10/)
- [Pro Evolution Soccer 2009 (Wikipedia)](https://en.wikipedia.org/wiki/Pro_Evolution_Soccer_2009)
- [FIFA 12 Player Impact Engine (EA)](https://news.ea.com/press-releases/press-releases-details/2011/EA-Sports-Revolutionizes-FIFA-Soccer-12-with-New-Player-Impact-Engine/default.aspx)
- [FIFA 22 HyperMotion, GDC 2022](https://gdcvault.com/play/1027746/Animation-Summit-FIFA-22-s)
- [Simple Soccer, código de Programming Game AI by Example](https://github.com/wangchen/Programming-Game-AI-by-Example-src/blob/master/Buckland_Chapter4-SimpleSoccer/SoccerTeam.cpp)
- [Coeficientes de sustentación de la pelota por análisis de trayectorias](https://www.researchgate.net/publication/228375759_Soccer_ball_lift_coefficients_via_trajectory_analysis)
- [godot-motion-matching](https://github.com/GuilhermeGSousa/godot-motion-matching)
