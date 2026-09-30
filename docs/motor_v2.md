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
- **Deslizamiento de pies bajo un umbral:** no pasa, y no se arregla desde el código. Los clips de andar están hechos en el lugar: el pie apoyado casi no retrocede (en Correr, el pie bajo hasta avanza). El pie apoyado desliza más o menos lo que avanza el cuerpo. Se probaron largos de ciclo de 0,5 a 3,2 m y ninguno lo baja.

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

**Para hacer en la PC con Blender** (`tools/blender/animaciones_jugador.py`):

1. Rehacé `Caminar`, `Trotar` y `Correr` "en cinta": el pie apoyado retrocede a la velocidad del cuerpo mientras toca el piso. Anotá en el clip cuántos metros avanza el cuerpo por ciclo, así la vista avanza la animación con los metros reales.
2. Agregá clips de arranque, frenada, giro de 90° y de 180°, correr de costado y correr de espaldas.
3. Exportá el GLB y ejecutá `GODOT=<godot> python3 tools/generar_acciones_v2.py`. `test_cuerpo_v2` falla si el JSON no coincide con los GLB.
4. Medí con `laboratorio_cuerpo.tscn -- segundos=60` sin pantalla y mirá el laboratorio con pantalla.
5. Rearmá las bibliotecas de Windows y Android después de cambiar el C++.

### Etapa 3 — Tocar la pelota

- **Qué:** conducción por toques, recepción según la altura de la pelota (pie, muslo, pecho, cabeza), pase al punto de encuentro con tangentes y tiempos de llegada de cada rival, intercepción = el primero que la alcanza.
- **Banco:** un rondo 4 vs 2 y un 5 vs 5 sin arcos, con cerebros sencillos.
- **Pasa si:** cero correcciones de velocidad de la pelota; los pases se cortan solo cuando un defensor llega; ningún receptor frena en seco para esperar.

### Etapa 4 — El cerebro

- **Qué:** se portan a C++ (`motor_v2/cpp/src/cerebro/`) `evaluar_opciones`, `elegir_softmax`, perfiles, ritmo, marcador, desmarques, defensa y jugadas preparadas, devolviendo intenciones. Nuevo: puntaje de puntos de apoyo sobre una grilla (se le puede pasar, puede tirar, distancia al poseedor), línea defensiva y offside en el frame del pase.
- **Pasa si:** 11 vs 11 sin arqueros ni reglas durante 10 minutos con posesiones de varios pases, bloques que se desplazan con la pelota y pases al espacio que salen solos.

### Etapa 5 — Remates y arqueros

- **Qué:** elección de punto y tipo de remate; modelo de error por tiro, pie malo, postura y presión; arquero que predice el cruce, elige parado, estirada o salida y resuelve agarre, rebote o no llega; rebotes jugables. Se reusan las animaciones de arquero que ya existen.
- **Pasa si:** porcentaje de remates al arco y de atajadas por división dentro de los rangos medidos hoy con `tests/_diag_embudo_remates.gd` (el arquero de primera ataja cerca del 63%).

### Etapa 6 — Reglas y pelota parada

- **Qué:** laterales, saques de arco, córners, faltas por contacto, tarjetas, offside, penales y tanda, cambios, lesiones, entretiempo con cambio de lado. Se reusa la lógica de ubicación de `_ubicar_para_el_balon_parado`, barrera y ejecutor.
- **Pasa si:** un partido de 90 minutos completo sin intervención, con todas las reanudaciones, y sin ningún corte de cámara por un jugador que camina 17 ticks hasta la línea.

### Etapa 7 — Calibración

- **Qué:** 200 partidos por división sin vista. Se ajustan `utility_pesos.json` y el modelo de error hasta que goles, remates, posesión, pases, faltas y tarjetas caigan en los rangos del motor actual (sección 11 de `docs/motor_espacial.md`) y el mejor equipo gane lo que tiene que ganar.
- **Pasa si:** el reporte por división queda dentro de rangos en dos semillas distintas.

### Etapa 8 — Integración y corte

- **Qué:** el juego usa el V2 para los partidos del usuario, mirados o simulados; relato, estadísticas, HUD y minimapa leen sus eventos. Se borran el modo 2D, `vista_partido.gd`, `coreografia_partido.gd`, los `_preparar_*` y el motor espacial. Prueba larga en el teléfono (temperatura, batería, memoria).
- **Pasa si:** se cumple la definición de hecho del Resumen.

**Herramientas que acompañan todas las etapas:** un detector nuevo que mide sobre el mundo (no sobre la vista) `SALTO_PELOTA`, `ENCIMADOS` (cápsulas superpuestas), `PATINA` (pie que desliza), `ESPERA` (jugador quieto con la pelota viniendo a él) y ms por frame; y una grabación por semilla que se puede reproducir y rebobinar para ver cualquier minuto.

**Dónde se hace cada etapa:** 0 (teléfono por adb) y 2 (Blender) en la PC del usuario; 1, 3, 4, 5, 6 y 7 se pueden hacer en la nube (Claude Cloud) con Godot sin pantalla; la revisión visual de cada etapa, en la PC.

## Cómo se escribe el C++

Reglas para todas las etapas. Salen de lo que midió la etapa 0.

- **Todo el motor en C++.** Mundo, cuerpo, cerebro, reglas y registro van en `motor_v2/cpp/src/`. GDScript solo lee el estado (posiciones, acciones, eventos) para dibujar y contar. Nada de lógica del partido en GDScript.
- **Paso fijo de 1/60 s** para mundo y cuerpo; el cerebro piensa cada 6 pasos, escalonado. Nada depende de los fps.
- **Sin matemática del sistema.** Solo `std::sqrt` (IEEE 754 la redondea igual en todos lados). Seno, coseno y arcotangente salen de `matematica_fija.h`. Si hace falta otra (exp, pow, log), se escribe ahí con +, −, ×, ÷ y raíz. Sin esto, el mismo partido termina distinto en la PC y en Android.
- **`-ffp-contract=off`** en todo lo que no compila MSVC (Android y Linux): sin eso clang junta a*b + c en una FMA que redondea distinto. Ya está en `SConstruct`.
- **Un solo generador al azar,** el PCG32 propio de `MundoV2Nativo` (no el `RandomNumberGenerator` de Godot), consumido siempre en el mismo orden.
- **Estado en `double`,** en arreglos planos. Nada de iterar contenedores sin orden fijo (`unordered_map`) en algo que cambia el partido.
- **Parámetros en `data/fisica_v2.json`:** GDScript lee el JSON y se lo pasa al motor al crearlo. Así se calibran sin recompilar.
- **Nombres, comentarios y mensajes en español,** con las mismas reglas de `CLAUDE.md` (el comentario dice por qué y contra qué se midió).
- **Cada etapa tiene su verificación:** un test `tests/test_*.gd` que corre el motor sin vista y compara números (con `FALLOS=n`), y la huella del estado con la misma semilla.

### Cómo se arma la extensión

1. Instalá scons: `python -m pip install scons`.
2. Cloná godot-cpp v10 fuera del repo: `git clone --depth 1 https://github.com/godotengine/godot-cpp` (en la PC está en `D:/dev-tools/godot-cpp`). Poné su ruta en la variable `GODOT_CPP`.
3. Desde `motor_v2/cpp`, ejecutá `python -m SCons api_version=4.7 target=template_release platform=<windows|linux|android>` (Android además `arch=arm64 ANDROID_HOME=... ndk_version=28.2.13676358`).
4. La biblioteca sale en `motor_v2/bin/`. Después de agregar clases nuevas, ejecutá `<godot> --path . --headless --editor --quit` para que Godot las registre.

### Trabajar en la nube

La sesión en la nube es Linux y no tiene pantalla, teléfono ni Blender.

1. Bajá Godot 4.7.2 para Linux: `https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip`.
2. Armá la extensión con `platform=linux` (pasos de arriba). `motor_v2/bin/motor_v2.gdextension` ya tiene la entrada de Linux.
3. Corré los tests sin pantalla: `<godot> --path . --headless --script tests/<archivo>.gd`, y la regresión con `GODOT=<godot> bash tests/correr_regresion.sh <n>`.
4. No se puede: armar la biblioteca de Windows ni la de Android, probar en el teléfono ni mirar cómo se ve. Si cambia el C++, las de `motor_v2/bin/` quedan viejas: anotalo en el commit ("falta rearmar Windows y Android") y se rearman en la PC.
5. Commit y push a `graficos-3d` como siempre (changelog y regresión antes del commit).

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
