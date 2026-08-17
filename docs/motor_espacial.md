# Motor espacial de partido — documento de diseño

Estado: **en producción**. `Liga.jugar_fecha` resuelve el partido del
jugador con `MotorEspacial` y la pantalla de partido animado dibuja sus
fotogramas. Ver §10 (resultados del MVP) y §11 (con qué equipos está
calibrado y por qué el número a vigilar es la paridad con
`match_engine.gd`, no el realismo).

Un partido dura **960 ticks = 4 minutos reales** (2 por tiempo) y el reloj
marca 0-90 como ficción: ver el comentario de `TICKS_POR_MITAD` en
`core/motor_espacial.gd` para por qué no hay alternativa si se quiere ver
el partido completo con movimiento creíble.

Alcance: reemplazar cómo se resuelve el partido que el jugador humano
efectivamente juega (liga propia + el que sigue en pantalla), por una
simulación con coordenadas reales y jugadores que deciden qué hacer con la
pelota, en vez de la cadena de duelos abstractos por zona que hay hoy. Las
demás ligas de la pirámide siguen resolviéndose como hasta ahora — no se
tocan.

## Decisiones tomadas

| # | Decisión | Elegido |
| --- | --- | --- |
| 1 | Estructura de estado | **`Dictionary` puro** (consistente con el resto del core) |
| 2 | `TICK_SEG` de arranque | **0.25s** — el extremo fluido, se ajusta si medir da mal |
| 3 | Softmax en el MVP | **Sí, desde el MVP** (no determinístico) |
| 4 | Log | **Separado**: `eventos` (compatible) + `fotogramas` (nuevo) |
| 5 | Convivencia de motores | **Permanente, no transición** — ver abajo |

### Sobre la decisión 5 — los dos motores conviven para siempre

`match_engine.gd` **no es código heredado a reemplazar**: es el motor
definitivo para todos los partidos que el jugador no juega (las otras 9
divisiones, cada fecha, todas las temporadas). Funciona bien, es rápido y
está calibrado — no se toca ni se deprecia.

El motor espacial es **solo** para los partidos del club del jugador. Y
todos ellos, incluso los que se saltean con "simular toda la temporada" sin
mirar la animación: un solo motor para tus partidos significa que las
estadísticas, objetivos y fans salen siempre del mismo cálculo, mires o no
mires. Cuando no se anima, simplemente no se generan los `fotogramas`
(§6) — las decisiones y el resultado son idénticos.

Consecuencia de diseño: **la profundidad de simulación es deliberadamente
asimétrica**. Tu partido se simula jugador por jugador; los de los demás,
con una cadena de duelos por zona. Es intencional, no una deuda técnica.

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

Con `TICK_SEG = 0.25s` (decisión 2 — el extremo fluido del rango pedido):
90 minutos = 5400s de juego → **21.600 ticks por partido**, contra los
~180 "duelos" que resuelve el motor abstracto hoy: un salto de ~120× en
cantidad de ticks.

Nota sobre la elección: 0.25s duplica el costo respecto de los 0.4s que
estimaba el borrador de este documento. Es la decisión correcta para que
se vea fluido, pero **es la variable con más impacto en rendimiento de
todo el diseño** y la primera palanca a mover si medir da mal.

La diferencia clave: en el motor viejo, CADA tick hacía un
`Duel.resolver` completo. Acá, el trabajo por tick se divide en:

- **21 jugadores sin pelota**: barato (suma de vectores), como exige la
  restricción de rendimiento.
- **El poseedor**: como casi todos los ticks tienen poseedor (la pelota
  está "en vuelo" solo 2-5 ticks por pase/tiro a esta resolución), la
  evaluación de utilidad (8-12 opciones × unos pocos términos cada una) +
  el softmax se ejecutan en **la gran mayoría de los 21.600 ticks**, no
  ocasionalmente. Esto es más trabajo por partido que hoy, no menos,
  aunque cada operación individual sea barata.

Estimación a mano (sin medir todavía): del orden de 20-30M operaciones
float simples por partido simulado sin renderizar. Es plausible que ronde
2-6 segundos por partido en un celular gama media, pero **es una
estimación, no una medición** — con la decisión ya tomada de que TODOS los
partidos del jugador (incluso los salteados con "simular toda la
temporada") corren el motor completo, una temporada de 30-40 fechas
podría tardar del orden de 1-4 minutos en el peor caso. Si eso pasa, hay
que actuar: nadie espera 4 minutos para saltear una temporada.

Palancas de emergencia si medir da mal, en orden de preferencia y sin
cambiar de arquitectura:
1. **No generar `fotogramas` para partidos que no se van a animar** —
   mismo RNG, mismas decisiones, mismo resultado; se ahorra toda la
   allocación de 22 Vector2 por tick (~475.000 Vector2 por partido). Esta
   es gratis y hay que hacerla igual, dé bien o mal la medición.
2. **Subir `TICK_SEG`** a 0.3-0.5s. Cada escalón recorta proporcional:
   0.5s es la mitad del trabajo de 0.25s. El costo es fluidez de la
   animación, así que se sube solo lo mínimo necesario.
3. **Cachear la evaluación de utilidad entre ticks consecutivos** cuando
   el contexto casi no cambió (mismo poseedor, presión parecida,
   rivales sin moverse mucho) — reevaluar cada 2-3 ticks en vez de todos.
4. **Recortar cuántas opciones se evalúan** por tick si el perfil muestra
   que ahí está el costo (ej. no considerar los 10 pases posibles, solo
   los 4 mejor ubicados).

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
  arco si hay espacio), pasar (a un compañero concreto, elegido por
  progreso/seguridad entre los visibles), tirar (si está dentro de un
  radio del área, geometría real de distancia/ángulo).
- **Softmax con temperatura desde el MVP** (decisión 3): la elección entre
  esas 3 acciones ya pasa por `P(acción) = exp(u/T) / Σ exp(u/T)`, con `T`
  modulada por `vision`/`inteligencia`/presión (§4.2). Implica que si algo
  se ve raro en el MVP hay que distinguir dos causas posibles — geometría/
  arquitectura mal, o `T` mal calibrada — así que el harness de debug tiene
  que **mostrar las utilidades y la `T` de cada decisión** desde el primer
  día, no solo el resultado. Sin eso, el MVP no es diagnosticable.
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

## 8. Riesgos

### Riesgos

1. **Rendimiento no medido**: la estimación de §6 es cálculo a mano. Puede
   que 21.600+ ticks con utility y softmax en casi todos sea lento en
   GDScript puro para "simular toda la temporada" en un celular gama media.
   Es el riesgo número uno y lo agrava la decisión 2 (0.25s duplica los
   ticks frente a 0.4s). Mitigación: medir con el MVP antes de construir
   nada encima; hay 4 palancas de emergencia (§6) sin cambiar arquitectura.
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
   espacial. Y como los partidos del jugador pasan a resolverse con OTRO
   motor que los del resto de la pirámide (decisión 5), hay que vigilar
   que los dos produzcan números comparables: si el motor espacial da 4.5
   goles por partido y el abstracto 2.8, el jugador tendría una liga con
   estadísticas distintas a las demás sin ninguna razón de diseño.
   Mitigación: re-correr los diagnósticos de balance contra el nuevo motor
   y **compararlos explícitamente contra los del abstracto** antes de
   engancharlo al juego real.
4. **Alcance real es grande**: el sistema completo (8 acciones, softmax,
   desmarque, offside, JSON tuneable) es varias sesiones de trabajo, no
   una. El MVP recorta deliberadamente para validar la sensación antes de
   comprometerse a todo lo demás.
5. **Complejidad por tick**: si desmarque/presión/offside se escriben sin
   cuidado (cada jugador comparando contra los 21 restantes cada tick), el
   costo sube rápido — hay que vigilar esto desde el MVP, no después.
6. **Softmax mal calibrado en el MVP** (consecuencia de la decisión 3): si
   el MVP se ve raro, la causa puede ser la arquitectura O la temperatura,
   y son dos problemas muy distintos. Mitigación obligatoria: el harness
   de debug muestra utilidades y `T` por decisión desde el primer día
   (§7), para poder separar las dos causas mirando números en vez de
   adivinando.

---

## 9. Qué NO decide todavía este documento

Deliberadamente fuera de alcance hasta después del MVP: las 5 opciones de
utilidad que faltan (gambetear/pase al hueco/pase largo/pared/centro más
allá del recorte del MVP), desmarque real, offside, JSON de balance
completo, reinicio de jugadas (lateral/córner/saque de arco animados en
vez de instantáneos), y la decisión de si Copa/internacional alguna vez
usan este motor (hoy ni siquiera se animan, quedan fuera).

---

## 10. Resultados del MVP (medidos, no estimados)

### Rendimiento — mejor de lo estimado

| Medición | Estimado en §6 | Real |
| --- | --- | --- |
| Un partido, sin animar | 2-6 s | **~1,5 s** |
| Temporada de 38 fechas | 1-4 min | **~57 s** |
| Un partido generando fotogramas | — | ~2,2 s (21.600 fotogramas) |

El riesgo #1 del documento (rendimiento) **queda descartado**: hay margen
de sobra, incluso con la decisión de 0.25s por tick. No hizo falta ninguna
de las 4 palancas de emergencia de §6.

### Lo que quedó validado

- Coordenadas reales, movimiento por tick, y la animación **leyendo**
  posiciones del motor en vez de inventarlas (verificado con capturas en
  4 instantes distintos de un partido: los equipos toman formas distintas
  y plausibles, no un amontonamiento).
- Utility AI + softmax con temperatura funcionando: el pase apunta a un
  compañero concreto y el tiro depende de distancia y ángulo reales.
- Pases: ~874 por partido con **77% de acierto** — números de partido real.
- Posesión ~50/50, sin sesgo estructural.
- Distancia de remate: mediana 14-18m, realista.

### Lo que NO quedó validado — el balance

| Métrica | Partido real | MVP |
| --- | --- | --- |
| Goles por partido | ~2,8 | **~8** |
| Remates por partido | ~25 | **~51** |

Además la varianza entre partidos es enorme (aparecen resultados tipo
4-28). El riesgo #3 del documento ("balance de cero") **se confirmó y
sigue abierto**: el motor produce fútbol reconocible pero no calibrado.

### Bugs de fondo que encontró la implementación

Vale la pena dejarlos anotados porque ninguno era obvio desde el diseño, y
todos se encontraron **midiendo**, no leyendo el código:

1. **Claves de jugador colisionando entre equipos**: los ids de jugador son
   únicos dentro de un club pero no entre clubes, así que indexar el
   estado por id hacía que un equipo pisara literalmente al otro (quedaban
   18 jugadores, todos del visitante). De ahí `OFFSET_VISITANTE`.
2. **Pases que pasaban de largo**: con la pelota a 18 m/s y ticks de
   0.25s, avanza 4,5m por tick contra un radio de control de 1,6m — la
   pelota saltaba por encima del receptor y se iba del campo. Un pase
   necesita un punto de destino, no una dirección.
3. **El que marca interceptaba todo**: el rival que presiona está a ~2m
   del pasador, o sea automáticamente dentro del corredor de intercepción
   apenas sale la pelota. Interceptaba el **96,5%** de los pases. Su
   chance de robar es el quite, no la intercepción.
4. **Ping-pong de posesión**: sin cooldown, un defensor a 2m disputa la
   pelota 4 veces por segundo — 9.026 quites por partido (real: ~40) y
   5.000 cambios de posesión. El cooldown tiene que ser de la disputa, no
   de cada defensor.
5. **Sin offside, los delanteros acampan en el arco**: la mediana de
   remate se iba a 2,5m. El offside como INFRACCIÓN sigue fuera de
   alcance, pero la conducta de mantenerse habilitado no es opcional.
6. **Replegar a los 11 mata el juego**: meter a todo el equipo detrás de
   la pelota hace que ningún pase hacia adelante se complete. Los de
   arriba tienen que quedar como salida.
7. **Decidir cada tick no es decidir**: reconsiderar 4 veces por segundo
   acumulaba cientos de tiradas de "tirar" por posesión. Hay que separar
   la cadencia de decisión del tick de simulación.

### Próximo paso propuesto

Una pasada de calibración dedicada, con el diagnóstico ya instrumentado
(`tests/_demo_motor_espacial.gd` mide goles, remates, distancia de
remate, pases intentados/interceptados/completados, quites y reparto de
decisiones). Todas las palancas están en `data/utility_pesos.json`, así
que es trabajo de tuneo sin recompilar. Recién con el balance en rango
tiene sentido engancharlo a `GameState`/`Liga`/UI.

---

## 11. ¿Con qué equipos está calibrado? (medido)

Pregunta legítima, porque una calibración hecha sobre un solo nivel de
plantel puede romperse en el resto. Se mide con
`tests/_diag_niveles.gd`.

Los equipos del demo son exactamente los que arma `Liga.inicializar` para
**cualquier** división (usa el mismo `Team.generar` sin forzar nivel):
media de plantel **47,0** de promedio, entre 37,6 y 52,5.

### Goles según el nivel de los dos equipos

| Media de plantel | Goles/partido | Remates |
| --- | --- | --- |
| 27 | 1,70 | 6,3 |
| 39 | 1,75 | 8,1 |
| 50 | 2,40 | 9,7 |
| 62 | 2,60 | 10,8 |

Sube con la calidad, que es lo esperable, y sin saltos raros.

### Equipos desparejos

| Enfrentamiento | Resultado promedio |
| --- | --- |
| media 35 vs 51 | 0,25 - 3,05 |
| media 31 vs 58 | 0,20 - 4,95 |

Una diferencia grande de plantel produce goleadas. Es coherente con la
decisión de diseño ya tomada de que quedarse quieto se paga caro, pero
conviene tenerlo presente: los cruces entre divisiones (copa nacional)
van a dar resultados abultados.

### Lo importante: espacial vs abstracto

Los partidos del jugador los resuelve el motor espacial y los del resto de
la pirámide el abstracto. Si dan escalas de goles distintas, la liga del
jugador queda descalibrada respecto del mundo: sus delanteros no compiten
en la tabla de goleadores y su diferencia de gol tiene otra escala que la
de sus rivales.

Medido con los MISMOS equipos y la MISMA semilla, el espacial daba **2,48
goles contra 3,17 del abstracto** (78%). Se corrigió subiendo remates y
conversión hasta **3,08 vs 3,17**, que es paridad dentro del ruido.

Ese es el número que hay que vigilar si en el futuro se toca
`data/utility_pesos.json`: no "¿da 2,8 goles como el fútbol real?" sino
**"¿da lo mismo que `match_engine.gd`?"**, porque es contra ese motor que
están calibrados la economía, los objetivos y los fans.

---

## 12. El partido cambia de aspecto según el nivel del plantel

Objetivo pedido: que en división 10 se vea lento y trabado, y que a
medida que el club sube y los jugadores mejoran, se vea más rápido y
asociado — pasar de un partido de barrio a un Madrid-Barça.

Antes, varias cosas eran **iguales para todos** por más que cambiaran los
atributos: la pelota viajaba a 18 m/s la pegara quien la pegara, todos
controlaban en el mismo tiempo, cualquiera podía tirar un pase de 45
metros, y la intercepción era pura geometría — un gran pasador completaba
exactamente los mismos pases que uno malo. Ahora todo eso sale de los
atributos (los pares min/max viven en `data/utility_pesos.json`):

| Qué | Atributo | Jugador malo | Jugador de élite |
| --- | --- | --- | --- |
| Velocidad al correr | `velocidad` | 3,6 m/s | 9,2 m/s |
| Fuerza del pase | `pases` | 11 m/s | 24 m/s |
| Alcance del pase | `pases` | 26 m | 46 m |
| Tiempo para acomodarla | `control` | 9 ticks | 2 ticks |
| Qué tan interceptable es su pase | `pases` | ×1,45 | ×0,42 |
| Criterio al decidir (temperatura) | `vision`, `inteligencia` | errático | consistente |

### Resultado medido (`tests/_diag_niveles.gd`)

| Media de plantel | Goles | Remates | Pases |
| --- | --- | --- | --- |
| 27 | 2,65 | 8,9 | 36 |
| 39 | 2,90 | 10,9 | 44 |
| 50 | ~3,0 | 13,6 | 52 |
| 62 | 3,70 | 13,1 | 54 |

Un plantel de élite juega **50% más pases** y genera bastante más peligro
que uno de división 10, con el mismo motor y el mismo tiempo de partido.

### Efecto secundario a vigilar

La curva de calidad del motor espacial quedó **más empinada** que la del
abstracto: con potencial 40 da 2,45 goles contra 2,80 del abstracto, y con
potencial 70 da 3,75 contra 3,55. Es deliberado (es justamente lo que se
pedía), pero significa que la paridad entre motores es exacta en el medio
de la tabla y se afloja en los extremos. Con equipos naturales —el caso
real— queda en 3,33 contra 3,17, que sigue siendo cerca.
