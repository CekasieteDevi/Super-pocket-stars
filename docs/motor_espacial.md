# Motor espacial de partido — documento de diseño

Estado: **propuesta, sin implementar**. No hay código de este motor en el repo
todavía — este documento es lo que hay que aprobar antes de escribir la
primera línea.

Alcance: reemplazar cómo se resuelve el partido que el jugador humano
efectivamente juega (liga propia + el que sigue en pantalla), por una
simulación con coordenadas reales y jugadores que deciden qué hacer con la
pelota, en vez de la cadena de duelos abstractos por zona que hay hoy. Las
demás ligas de la pirámide siguen resolviéndose como hasta ahora — no se
tocan.

---

## 0. Referencia de sensación buscada

Pocket League Story 2 (Kairosoft), no Football Manager. La prioridad es que
la animación se vea viva y legible — cámara, presentación, comentario por
evento — por encima de la profundidad táctica de la simulación. El utility
AI existe para que el movimiento tenga sentido, no para que el motor "juegue
bien al fútbol" con precisión de simulador serio.

---

## 1. Qué se reusa y qué se tira

### Se reusa tal cual

- **`core/duel.gd` completo** (`Duel.resolver`, `atributo_efectivo`,
  `p_base`, bloques con tope A±15/B±15/C±15/D±12, neto ±25). Es una función
  pura de dos "efectivos" + dos diccionarios de bloques → probabilidad. No
  le importa si el duelo salió de un tick abstracto o de un jugador con
  coordenadas reales — se sigue usando para cualquier enfrentamiento
  puntual: intento de robo bajo presión, intercepción de un pase, tiro vs
  arquero.
- **`MatchEngine._bloques_equipo`** y todo lo que alimenta (Estilos, DT,
  Clima, EstadoCancha, Arbitro, Publico, Rivalidad, Objetivos-en-riesgo,
  Personalidad, Habilidades) — sigue siendo la capa de **calidad de
  ejecución** de una acción ya elegida. Lo que cambia es CUÁNDO se llama:
  antes se llamaba una vez por tick de zona: ahora se llama en el momento
  del duelo puntual (robo, intercepción, tiro), no en la decisión de qué
  intentar.
- **`_chequear_lesion`, `_chequear_tarjeta`, `_procesar_cambios*`** — se
  reusan sin tocar la lógica interna, solo cambia desde dónde se llaman
  (ya no hay "zona build/final", hay ticks continuos — se llaman en los
  mismos puntos temporales de siempre: cada duelo de robo/tackle para
  tarjetas y lesión, cada ventana de entretiempo/60'/75' para cambios).
- **`Team`** (Dictionary de jugadores, `en_cancha`, `banco`,
  `resistencia_pct`, `desgastar`, `arquero()`) — sin cambios. El motor
  espacial no reemplaza a Team, solo LEE de él y llama `desgastar`/
  `lesionar`/`sustituir` igual que hoy.
- **Atributos de jugador ya generados pero sin usar**: `velocidad`,
  `aceleracion`, `agilidad`, `salto`, `fuerza`, `vitalidad`, `centros`,
  `volea`, `cabezazo`, `tiros_libres`, `efecto`, `vision`, `inteligencia`
  (`data/attribute_groups.json`) — **ya existen en cada jugador generado**,
  el motor abstracto nunca los leyó. El motor espacial es lo que
  finalmente les da uso: velocidad/aceleración mueven al jugador,
  vision/inteligencia bajan la temperatura del softmax (mejor criterio),
  centros habilita el centro al área, cabezazo entra en el duelo de tiro
  cuando el gol viene de un centro.
- **El shape de salida** `{"goles_local", "goles_visitante", "log",
  "goles_log", "eventos"}` — se mantiene como el contrato hacia
  `Liga`/`GameState`/`EstadisticasPartido`/`Objetivos`/`Fans`/`Rivalidad`.
  Ninguno de esos sistemas necesita enterarse de que el partido ahora tiene
  coordenadas.
- **Rasgos de Personalidad ya conectados como modificador pp** (Ansioso,
  Lento de arranque, Se apaga, Clutch, Frágil mental, Impuntual,
  Protagonista, Dependiente) — siguen siendo modificadores de **calidad de
  ejecución** en el duelo puntual, sin cambios.

### Se tira / se reemplaza

- **El bucle `_jugar_periodo` y su máquina de estados "build"/"final"**,
  junto con `AVANCE_REQUERIDO` y `_elegir()` (sampleo random de "quién
  participa este tick") — todo esto asume que no hay coordenadas ni
  continuidad de quién tiene la pelota. Lo reemplaza el loop de tick nuevo
  (sección 3).
- **`_resolver_destino`** — hoy el destino del tiro (afuera/palo/porteria)
  sale SOLO del atributo `tiro`. Se reemplaza por una versión que suma
  distancia y ángulo reales al arco (la categorías de salida se mantienen
  iguales, así `EstadisticasPartido`/goleador log no cambian).
- **Todo lo agregado en las últimas 3 sesiones a `ui/cancha.gd` y
  `ui/partido_visual.gd`**: `FORMACION_SLOTS` con empuje aproximado,
  `Cancha.fijar_posesion`/`punto_en`/`_render_local`/`_render_visitante`,
  `ZONA_X_POR_TIPO` en `PartidoVisual`. Esto era una aproximación visual
  honesta dado que el motor no tenía coordenadas — con el motor espacial,
  **la animación pasa a LEER `x`/`y` reales de cada fotograma**, no a
  inventarlas. Se tira toda esa capa de "adivinar dónde está cada uno".
  Lo único que sobrevive de esas sesiones es **`ui/pixel_art.gd`** (los
  sprites en sí) — el render sigue dibujando esos mismos sprites, solo que
  en la posición que el motor diga, no en una calculada por bloque/empuje.

### Zona gris — se reusa como INSUMO, no como mecanismo

- **`Estilos.retroceso_sin_pelota`** (agregado esta sesión para el empuje
  visual) — la idea sobrevive pero cambia de capa: hoy es un número que
  mueve un dibujo, en el motor espacial pasa a ser el peso real de
  "atracción a la pelota" del jugador sin marca (sección 4), así que
  Presión alta/Defensivo/etc. **afectan jugabilidad de verdad**, no solo
  estética.
- **`Personalidad.modificador_partido`** — se separa en dos familias (ver
  sección 4): los rasgos que hoy suman/restan puntos porcentuales a un
  duelo (Ansioso, Clutch, Frágil mental, Impuntual, Protagonista,
  Dependiente) siguen ahí sin tocar; los que el GDD ya describe como
  "favorece" (Egoísta: "favorece su propio tiro por sobre el pase del
  equipo"; Creador: bonus en pases) pasan a ser **sesgos de la utilidad**
  como pidió el encargo — Egoísta ya no suma pp al tiro, sube el peso de
  ELEGIR tirar.

---

## 2. Estructuras de datos

Todo `Dictionary`/`RefCounted`, cero `Node` — el core sigue siendo
simulable sin árbol de escena, tal como exige la restricción dura.

```gdscript
# Un jugador EN CANCHA durante el partido espacial. NO reemplaza al
# Dictionary de jugador de Team (atributos, personalidades, id, etc.) — lo
# referencia por id y le agrega el estado de posición que Team no tiene.
EstadoJugador := {
    "jugador_id": int,
    "equipo_local": bool,
    "rol": String,          # posición asignada (copia de jugador["posicion"])
    "pos": Vector2,          # metros, cancha 105x68, origen en el centro
    "vel": Vector2,          # m/s actual
    "objetivo": Vector2,     # punto de steering para este tick
}

EstadoPelota := {
    "pos": Vector2,           # metros
    "vel": Vector2,           # m/s, para el vuelo de pases/tiros/rebotes
    "poseedor_id": int,       # -1 si está suelta/en el aire
    "en_vuelo": bool,         # true entre el pase/tiro y que alguien la controla
}

# El "mundo" de un tick — vive y muere con un partido, se descarta al
# terminar (no persiste en Team ni en GameState).
EstadoPartido := {
    "home": Team, "away": Team,
    "jugadores": Dictionary,   # jugador_id (int) -> EstadoJugador
    "pelota": EstadoPelota,
    "minuto": float,
    "tick": int,
    "rng": RandomNumberGenerator,   # PROPIO de este partido — ver riesgos §6
    "log": Array,               # texto, igual que hoy (con_log)
    "goles_log": Array,         # igual que hoy
    "eventos": Array,           # semántico, MISMO formato que hoy
    "fotogramas": Array,        # nuevo — snapshot por tick, ver §5
}
```

Cancha: 105×68 metros (medida FIFA estándar), origen `(0,0)` en el centro,
eje X hacia el arco del equipo visitante (el local ataca +X). Esto es
puramente interno al motor — la UI convierte a screen-space al leer los
fotogramas, igual que cualquier proyección de cámara.

---

## 3. Loop del tick

`TICK_SEG` (0.25–0.5s de juego simulado por tick, ver §6 para cuál arrancar)
por tick:

1. **Reloj**: `minuto += TICK_SEG / 60.0`.
2. **Si la pelota está en vuelo** (pase/centro/tiro en camino, no en el
   instante): avanzar `pelota.pos` según `pelota.vel`; chequear si algún
   jugador (del equipo que la envía, si es un pase válido; cualquiera, si
   quedó suelta) entra en su radio de control → pasa a poseída, `en_vuelo
   = false`. Si nadie la controla y sale del campo → evento de saque
   (lateral/córner/saque de arco/offside), reposicionamiento instantáneo
   (el MVP no anima la jugada de reinicio, solo coloca y sigue).
3. **Si hay poseedor** (el 99% de los ticks):
   1. Calcular **presión** sobre el poseedor (§4.3).
   2. Armar la lista de acciones candidatas válidas ahora (conducir,
      gambetear, pase corto ×N compañeros visibles, pase al hueco, pase
      largo, pared, centro, tirar, aguantar — MVP solo tiene 3, ver §7).
   3. Puntuar cada una con la función de utilidad (§4.1).
   4. Elegir vía softmax con temperatura (§4.2).
   5. Ejecutar: mover al poseedor (conducir/gambetear), o lanzar la
      pelota en vuelo hacia el objetivo (pase/centro/tiro) con un duelo
      puntual de por medio si corresponde (intercepción, tackle, tiro vs
      arquero — reusa `Duel.resolver` + `_bloques_equipo`).
   6. Loggear evento semántico (mismo formato de hoy) si la acción es de
      las que hoy generan evento (pase, gambeta, tiro, tarjeta, gol).
4. **Los 21 sin pelota**: steering barato, sin utilidad (§4.4) — suma de
   vectores y clamp de velocidad máxima según `velocidad`/`aceleracion`
   del jugador.
5. **Ventanas de siempre**: en los minutos de cambio de siempre
   (entretiempo, 60', 75') llamar `_procesar_cambios` sin tocarlo.
6. **Push del fotograma** (§5) a `fotogramas`.
7. Fin de los 90' (+ alargue si corresponde, mismo criterio que hoy) →
   devolver el mismo shape de resultado de siempre + `fotogramas`.

---

## 4. Decisión del poseedor

### 4.1 Función de utilidad

Cada acción candidata se puntúa con una suma pesada de términos
normalizados 0..1, con los pesos en JSON externo
(`data/utility_pesos.json`, tuneable sin recompilar):

```
utilidad(accion) = Σ peso_termino × termino(contexto, accion)
```

Términos genéricos (cada acción usa el subconjunto que le aplica):

- **progreso**: cuánto acerca la pelota al arco rival si sale bien
  (Δx hacia el arco ÷ largo de cancha).
- **riesgo**: probabilidad estimada de perder la pelota — sale de
  `Duel.p_base` contra el marcador más cercano a la línea de la acción,
  más la presión actual.
- **valor_destino** (pases/centro): qué tan buena es la posición del
  receptor — espacio libre alrededor, ángulo hacia el arco, y **si está
  en offside → utilidad 0 directo**, ni se considera.
- **seguridad** (conducir/aguantar): inverso de la presión actual.
- **geometría** (tiro): función de distancia + ángulo al arco (§4.5), no
  solo el atributo.

Pesos base por acción (ejemplo, viven en JSON):

| Acción | Términos dominantes | Requiere |
| --- | --- | --- |
| Conducir | seguridad, progreso | — |
| Gambetear | progreso, riesgo | `control` del jugador |
| Pase corto | valor_destino, riesgo bajo | — |
| Pase al hueco | progreso alto, riesgo alto | **`vision`/`inteligencia` por encima de un umbral — si no llega, ni entra en la lista de opciones** |
| Pase largo / centro | valor_destino en el área | `centros` o `pases` alto |
| Pared | progreso inmediato | compañero bien ubicado cerca |
| Tirar | geometría, `tiro` | dentro de un radio razonable del arco |
| Aguantar | — (última opción, evita forzar riesgo cuando todo lo demás es malo) | — |

### Sesgos de personalidad/habilidad (multiplican el PESO, no el resultado)

Esto es el cambio de fondo que pidió el encargo: hoy Personalidad suma
puntos porcentuales a un duelo ya elegido; acá sube o baja la
**probabilidad de que esa acción se considere/elija**, antes de que exista
ningún duelo.

- **Egoísta**: `peso(tirar) ×= 1.4` cerca del área (el GDD literalmente
  dice "favorece su propio tiro por sobre el pase del equipo" — esto es
  eso, hecho realidad en vez de aproximado).
- **Creador**: `peso(pase al hueco) ×= 1.3`.
- **Nunca rendirse**: sigue en bloque D para el duelo de robo (sin
  cambios) — no es un sesgo de decisión, es calidad de ejecución.
- **Pie preferido** (rasgo pendiente desde hace 2 sesiones, sin sistema de
  origen hasta ahora): penaliza pases/tiros cuyo ángulo hacia el objetivo
  cruza fuerte hacia el lado del pie no preferido.
- **Rasgos que YA tenían bloque D** (Ansioso, Lento de arranque, Se apaga,
  Clutch, Frágil mental, Impuntual, Protagonista, Dependiente) — se
  quedan ahí, afectando el duelo puntual una vez que la acción ya se
  eligió. No todos los rasgos se mueven a sesgo de decisión, solo los que
  el GDD ya describía en términos de "elige"/"favorece".

### 4.2 Softmax con temperatura

```
P(acción_i) = exp(utilidad_i / T) / Σⱼ exp(utilidad_j / T)
```

`T` baja → casi determinístico (elige siempre la mejor). `T` alta → más
errático — esto ES el error humano que pidió el encargo, no un bug.

```
T = clamp(T_BASE
        - k_vision × (vision/100)
        - k_inteligencia × (inteligencia/100)
        + k_presion × presión_normalizada,
        T_MIN, T_MAX)
```

Un jugador con visión/inteligencia altas decide mejor (T baja) incluso sin
presión; bajo presión alta, cualquiera empeora (T sube). `T_BASE`,
`k_vision`, `k_inteligencia`, `k_presion`, `T_MIN`, `T_MAX` van en el JSON
de balance.

### 4.3 Presión

```
presión(poseedor) = Σ sobre rivales cercanos de
    max(0, 1 - distancia/RADIO_PRESION) × factor_frente
```

`factor_frente` pesa más a un marcador que está entre el poseedor y su
arco (marca "de frente") que a uno que quedó atrás. `RADIO_PRESION` ronda
los 5-8 metros — tuneable en JSON. La presión alimenta: la temperatura del
softmax (§4.2), el término `riesgo` de conducir/gambetear, y el bloque
C/D del duelo puntual si un rival efectivamente intenta el robo.

### 4.4 Movimiento sin pelota (barato, sin utilidad)

Para los 21 jugadores que no tienen la pelota, nada de softmax — solo
vectores:

```
objetivo = base_formacion(rol, línea_del_equipo)
         + atracción_a_pelota(rol) × Estilos.retroceso_sin_pelota(estilo)
         + desmarque(si soy candidato lógico a recibir el próximo pase)
         − separación(compañeros muy cerca)
```

- `base_formacion`: igual concepto que `Cancha.FORMACION_SLOTS` de hoy,
  pero en metros reales de cancha en vez de 0..1 de pantalla.
- `línea_del_equipo`: dónde está la línea defensiva/media/ofensiva del
  equipo, calculada de la posición X real de la pelota — el "empuje" que
  hoy es una aproximación visual pasa a ser geometría real.
- `atracción_a_pelota`: vector hacia la pelota, escalado por
  `Estilos.retroceso_sin_pelota` (Presión alta empuja de verdad a buscarla,
  no solo visualmente).
- `desmarque`: heurística barata (alejarse del marcador más cercano +
  hacia el arco rival), no utilidad completa.

Costo por tick: 21 sumas de vectores + clamp de velocidad — nada de
`Duel.resolver` ni softmax para estos jugadores, tal como exige la
restricción de rendimiento.

### 4.5 Offside y línea defensiva

La línea del equipo que defiende es la posición X del DFC más adelantado
(coordenada real, no aproximación). Un delantero que recibe un pase estando
más adelantado que esa línea Y más adelantado que la pelota en el momento
del pase → offside, saque de meta. Es una regla de validación sobre
coordenadas reales, no necesita un bloque nuevo del duelo — y de paso
conecta el rasgo **Enfocado** (pendiente desde hace 2 sesiones: "no hay
offside modelado" dejaba de aplicar el modificador correspondiente).

### 4.6 Tiro: geometría real

```
factor_geometria = f(distancia_al_arco, ángulo_al_arco)
```

Reemplaza a `_resolver_destino` (hoy solo mira el atributo `tiro`). Las
categorías de salida (`afuera`/`palo`/`porteria`) se mantienen para no
romper el log/estadísticas — lo que cambia es que la probabilidad de cada
una ahora depende de dónde está parado el jugador, no solo de su atributo.
Un remate desde 30 metros con ángulo cerrado tiene que ser peor que uno de
frente al área chica aunque el atributo `tiro` sea el mismo — hoy eso no
existe.

---

## 5. Formato del log de tick (fotograma)

```gdscript
{
    "tick": int,
    "minuto": float,
    "pelota": {"x": float, "y": float, "poseedor_id": int},
    "jugadores": [
        {"id": int, "x": float, "y": float, "equipo_local": bool, "rol": String},
        # ... 22 entradas
    ],
    "evento": Dictionary,  # null la mayoría de los ticks; mismo shape que
                            # el "eventos" de hoy cuando SÍ pasa algo
                            # loggeable (agrega tipos nuevos: "conduce",
                            # "pase_completo", "pase_intercepted", "centro",
                            # "offside", además de los que ya existen)
}
```

Un array de `fotogramas` (uno por tick) separado del array `eventos`
semántico de siempre — **no se mezclan**:

- **`eventos`** (compatible con hoy): lo que consumen
  `EstadisticasPartido`, `Objetivos`, `Fans`, `Noticias`, el log de texto.
  Ninguno de esos sistemas se entera de que ahora hay coordenadas.
- **`fotogramas`** (nuevo): lo único que consume la animación
  (`PartidoVisual`/`Cancha` nuevos, que dejan de inventar posiciones y
  pasan a leerlas). También sirve para un modo debug que muestre el
  desglose de utilidades evaluadas y la `T` usada en cada decisión, sin
  tener que instrumentar nada ad-hoc.
- `EstadisticasPartido` puede además mejorar de verdad: posesión real
  contando ticks con poseedor de cada lado, en vez de la aproximación
  actual.

---

## 6. Presupuesto de rendimiento (estimado, no medido)

Con `TICK_SEG = 0.4s` (punto medio del rango pedido): 90 minutos = 5400s
de juego → **13.500 ticks por partido**, contra los ~180 "duelos" que
resuelve el motor abstracto hoy — un salto de ~75× en cantidad de ticks.

La diferencia clave: en el motor viejo, CADA tick hacía un
`Duel.resolver` completo. Acá, el trabajo por tick se divide en:

- **21 jugadores sin pelota**: barato (suma de vectores), como exige la
  restricción de rendimiento.
- **El poseedor**: como casi todos los ticks tienen poseedor (la pelota
  está "en vuelo" solo 1-3 ticks por pase/tiro), la evaluación de
  utilidad (8-12 opciones × unos pocos términos cada una) se ejecuta en
  **la gran mayoría de los 13.500 ticks**, no ocasionalmente. Esto es más
  trabajo por partido que hoy, no menos, aunque cada operación individual
  sea barata.

Estimación a mano (sin medir todavía): del orden de 10-15M operaciones
float simples por partido simulado sin renderizar. Es plausible que ronde
1-3 segundos por partido en un celular gama media, pero **es una
estimación, no una medición** — con la decisión ya tomada de que TODOS los
partidos del jugador (incluso los salteados con "simular toda la
temporada") corren el motor completo, 30-40 fechas podrían tardar
30-120 segundos en el peor caso.

Palanca de emergencia si medir da mal, sin cambiar de arquitectura:
- Subir `TICK_SEG` a 0.5-0.6s (menos ticks).
- No generar `fotogramas` para partidos que no se van a animar (mismo RNG,
  mismas decisiones, se ahorra la allocación de Vector2 por tick — el
  resultado no cambia, solo se descarta el detalle visual).
- Recortar cuántas opciones de utilidad se evalúan por tick si el perfil
  muestra que ahí está el costo.

**Esto se mide recién con el MVP** (§7) — todo lo de esta sección es
cálculo de servilleta, no un compromiso de rendimiento.

---

## 7. MVP propuesto

Objetivo: validar "¿esto se ve como un partido?" antes de construir el
resto (utility completo de 8 acciones, desmarque, offside, JSON tuneable
fino).

**Escena de prueba aislada** — no toca `GameState`/`Liga`/`ui/main.gd`
todavía. Nada del juego real cambia mientras esto se valida.

Recorte del MVP:

- `core/motor_espacial.gd` nuevo (no se toca `match_engine.gd` — las
  otras ligas siguen igual).
- `EstadoJugador`/`EstadoPelota`/`EstadoPartido` tal como en §2.
- Loop de tick con **3 acciones para el poseedor**: conducir (hacia el
  arco si hay espacio), pasar (a un compañero concreto — elegido por una
  utilidad simple: mejor combinación de progreso/seguridad entre los
  visibles, **sin softmax todavía**, la mejor opción gana directo — ver
  decisión #3 en §8), tirar (si está dentro de un radio del área,
  geometría real de distancia/ángulo).
- Movimiento sin pelota: solo atracción a la pelota + posición base de
  formación — sin desmarque ni offside todavía.
- Sin cambios/lesiones/tarjetas en el MVP (ya existen, se enganchan
  después sin rediseño).
- `tests/_demo_motor_espacial.gd`: arma dos equipos con `Team.generar`,
  corre el motor, imprime estadísticas básicas (goles, ticks, tiempo de
  cómputo real medido con `Time.get_ticks_msec()` — acá es donde se mide
  de verdad el presupuesto de §6).
- Harness visual temporal (mismo patrón `ScreenshotHarness` usado toda la
  sesión): dibuja los 22 puntos + pelota leyendo directo los fotogramas,
  SIN la lógica de `Cancha` actual — para juzgar a ojo si "parece un
  partido" antes de invertir en el resto.

Criterio de aprobación del MVP: mirar la animación resultante. Si "se ve
como un partido" (los jugadores convergen hacia la pelota de forma
razonable, el que la tiene avanza/pasa/tira con sentido visible), se sigue
con el resto del utility AI. Si no, se ajusta el MVP antes de construir
nada más encima.

---

## 8. Riesgos y decisiones pendientes

### Riesgos

1. **Rendimiento no medido**: la estimación de §6 es cálculo a mano. Puede
   que 13.500+ ticks con utility en casi todos sea lento en GDScript puro
   para "simular toda la temporada" en un celular gama media. Mitigación:
   medir con el MVP; hay palancas de emergencia sin cambiar arquitectura.
2. **RNG-shift multiplicado**: con miles de ticks en vez de cientos, un
   solo cambio futuro (agregar una opción de utilidad, por ejemplo) corre
   TODO el resto de los números aleatorios de esa partida — el mismo
   problema que ya golpeó varias veces esta sesión en el motor viejo, pero
   mucho más frecuente acá. Mitigación: el `rng` de `EstadoPartido` tiene
   que ser propio de ESE partido (semilla derivada, pero un
   `RandomNumberGenerator` separado del `rng` global de la liga), para que
   un cambio en el motor espacial no corra los resultados de los demás
   partidos de la temporada que siguen en el motor abstracto.
3. **Balance de cero**: meses de calibración del motor de duelos (goles/
   partido, tarjetas, lesiones — todo lo que sostiene Fans/Economía/
   Objetivos) no tienen por qué seguir sirviendo el día 1 del motor
   espacial. Mitigación: el motor viejo queda intacto para todo lo demás
   (ya es requisito duro); hay que re-correr los diagnósticos de balance
   contra el nuevo motor antes de que reemplace al viejo en el partido del
   jugador.
4. **Alcance real es grande**: el sistema completo (8 acciones, softmax,
   desmarque, offside, JSON tuneable) es varias sesiones de trabajo, no
   una. El MVP recorta deliberadamente para validar la sensación antes de
   comprometerse a todo lo demás.
5. **Complejidad por tick**: si desmarque/presión/offside se escriben sin
   cuidado (cada jugador comparando contra los 21 restantes cada tick), el
   costo sube rápido — hay que vigilar esto desde el MVP, no después.

### Decisiones que necesito que tomes

1. **`Dictionary` puro vs `RefCounted` tipado** para
   `EstadoJugador`/`EstadoPelota`. Recomiendo `Dictionary`, por
   consistencia con el resto del core (100% Dictionary hoy) — la
   sensibilidad de rendimiento está más en la CANTIDAD de ticks que en el
   overhead de acceso a campos.
2. **`TICK_SEG` de arranque**: ¿0.4s (punto medio, mi recomendación para
   el MVP) o preferís empezar directo en un extremo (0.5s más barato /
   0.25s más fluido) y ajustar después de medir?
3. **¿Softmax con temperatura entra en el MVP, o el MVP elige siempre la
   mejor opción (determinístico)?** Recomiendo MVP determinístico —
   softmax mal calibrado puede hacer que el MVP "se vea tonto" y mezcle un
   problema de calibración con uno de arquitectura justo cuando estás
   evaluando si la arquitectura sirve.
4. **¿`eventos` y `fotogramas` como arrays separados** (mi recomendación,
   §5) **o una sola estructura enriquecida**? Separarlos mantiene a
   Estadísticas/Objetivos/Fans/Noticias completamente ajenos al cambio.
5. **Convivencia a largo plazo**: ¿el motor espacial y `match_engine.gd`
   conviven indefinidamente (uno para el partido seguido del jugador, otro
   para el resto de la pirámide), o es una etapa de transición hacia
   reemplazar todo eventualmente? No cambia el MVP, pero cambia cómo se
   documenta la arquitectura de acá en adelante.

---

## 9. Qué NO decide todavía este documento

Deliberadamente fuera de alcance hasta después del MVP: las 5 opciones de
utilidad que faltan (gambetear/pase al hueco/pase largo/pared/centro más
allá del recorte del MVP), desmarque real, offside, JSON de balance
completo, reinicio de jugadas (lateral/córner/saque de arco animados en
vez de instantáneos), y la decisión de si Copa/internacional alguna vez
usan este motor (hoy ni siquiera se animan, quedan fuera).
