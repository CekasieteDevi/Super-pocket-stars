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

**Qué no entra todavía:** remate y arquero (etapa 5), gambeta (faltan clips de regate), pelota parada y jugadas preparadas de pelota parada (etapa 6), `_opciones_orientadas` (en el V2 el cuerpo gira de verdad y el pase de costado ya es más impreciso).

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

- **Cuándo:** la opción `tiro` del motor espacial, con los mismos pesos (`tiro.base + tiro.geometria × factor_geometria`, habilitada por el rango de tiro). También de primera: el receptor en zona de tiro (`primera_geometria`) le pega de pie, de volea o de cabeza según la altura a la que le llega. Así los centros terminan en cabezazos.
- **Adónde:** `elegir_remate` prueba 15 puntos del arco (pegado al palo, a 1,35 m del palo y al medio; raso, a media altura y arriba) con cada golpe. El planeador (`valor_remate`) le da a cada uno la chance de ir adentro por la chance de que el arquero no llegue, con el mismo error y el mismo arquero que después juegan. Elige con softmax de temperatura baja.
- **Golpes:** colocado, fuerte, con efecto (45 rad/s de comba hacia el medio del arco), globo (sale a 40° y `apuntar` busca la rapidez) y cabeza. El raso sale por el piso: apuntado a 0,2 m de alto la patada salía en globo.
- **Error:** desvío del ángulo `error_rad` × (1 − 0,8 × tiro/100), por el golpe, hasta 1,5 con un rival encima, × (1 + de costado a adonde mira), por el pie malo, la volea y la pelota que llega rápida de primera. Los atributos van relativos al nivel del partido, como la puntería del motor espacial.

**El arquero:**

- **Lee la trayectoria:** si la pelota va a cruzar su línea entre los palos, después de su reacción (reflejos: 0,35 a 0,12 s) piensa en cada paso hasta tirarse. Esperando su turno y la reacción de los demás planeaba 0,27 s tarde.
- **Elige el clip:** el primer punto de su área al que llega una mano a tiempo, con Agarrar, Atajar_Abajo, Atajar_Arriba o las estiradas (baja y alta, a cada lado). Ataja parado solo si se corre hasta 1 m (la regla de la vista 3D actual). Se acomoda por debajo de `rapidez_para_girar`, así sigue mirando la pelota. Si nada llega, se tira igual.
- **Con qué toca:** parado, la mano (tolerancia de 0,25 a 0,5 m según estirada). En la estirada, el brazo entero, del hombro a la mano: con la mano sola, las pelotas que pasaban a 0,5-0,9 m del cuerpo no las tocaba nadie. Parado en su área, el cuerpo con los brazos abiertos (0,45 m de radio, 1,6 m de alto) también la frena.
- **Qué hace con la pelota:** la agarra, la da en rebote o la roza. La calidad sale de la pasada más cercana de la pelota a la mano, no del primer paso que entra en la tolerancia: con eso, la pelota rápida siempre entraba por el borde y todo era un roce. La que agarra la lleva en las manos 1,5 s (la vista dibuja `Arquero_Sostiene`) y la suelta para jugarla con el pie. El rebote sale hacia la cancha y al costado, y lo juega el que llega.
- **Sin remate encima:** sobre la bisectriz pelota-arco, 0,15 m adelante de la línea por cada metro de la pelota (entre 0,8 y 3 m). En el mano a mano achica (los pesos del motor espacial). Sale a una pelota suelta de su área solo si le gana al rival más rápido por `ventaja_base` + `ventaja_por_metro`: si no, salía a buscar la pelota que el delantero tenía en el área y le pateaban con él corriendo.

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
4. La biblioteca sale en `motor_v2/bin/`. `SConstruct` compila `src/*.cpp` y `src/cerebro/*.cpp`. Después de agregar clases nuevas, ejecutá `<godot> --path . --headless --editor --quit` para que Godot las registre.

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
