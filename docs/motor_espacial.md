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

---

## 13. Cómo se resuelve una intercepción

Antes era **puramente geométrica y determinista**: si un rival entraba en
el radio de la trayectoria, la pelota era suya, sin tirar un solo dado. Un
marcador con `quite` 95 interceptaba exactamente igual que uno con 20 — el
único atributo que contaba era el `pases` del que la pegó. Ahora la
geometría decide **quién tiene la chance y qué tan buena es**, y un duelo
decide **si la corta**.

### Quién puede interceptar

Todos los rivales, no un jugador designado. En cada tick de vuelo se mide
la distancia perpendicular de cada rival al **segmento que recorrió la
pelota ese tick** (no al punto final: con pasos de ~4,5m, mirar solo el
punto final dejaría pasar la pelota a través de un defensor). El más
cercano dentro del radio es el que tiene la chance.

Excepción: el rival que está a menos de 4m del punto de origen del pase no
intercepta. Es el que estaba marcando al pasador y queda dentro del
corredor apenas sale la pelota; su oportunidad de robarla es el quite, no
esto. Sin esa excepción interceptaba el 96,5% de los pases.

### El duelo

No existe un atributo "intercepción" en el GDD — los defensivos son
`quite` y `barrida`, y los mentales `vision` e `inteligencia`. Se usa el
mismo compuesto con que el GDD pondera a un DFC (`quite 18, fuerza 14,
inteligencia 14`): **`quite` × 0,6 + `inteligencia` × 0,4**, o sea marca
más lectura de juego. Contra eso va el `pases` del que la tocó, con los
bloques A/B/C/D de siempre (§8.5), así que personalidad, habilidades,
clima y todo lo demás entran igual que en cualquier otro duelo.

Dos factores modulan la lectura del defensor:

| Factor | Efecto |
| --- | --- |
| **Centralidad** — qué tan metido está en la trayectoria | ×0,45 en el borde del radio, ×1,0 justo en el camino |
| **Distancia ya recorrida** por la pelota | ×0,70 en un toque corto, ×1,30 pasados 30m |

El segundo es pedido explícito: un toque corto y seco no se corta, pero un
pase largo cruzando la cancha le da al rival tiempo de sobra para medirlo.

### Nota: habilidades relacionadas

- **Profeta** (habilidad de campo atada a `quite`) ahora sí sirve para
  cortar pases, porque el duelo pasa por el bloque D.
- **Interceptor** es una habilidad de ARQUERO, atada a `reflejos` — es
  salir a cortar, no leer un pase en el medio.

### Pendiente: altura de la pelota

Hoy la pelota es 2D: no hay coordenada `z`. Cuando se implementen los
centros hay que agregarla, porque un centro que pasa cinco metros por
encima de un defensor no lo puede interceptar nadie, y con el modelo
actual sí lo haría. Es el requisito que habilita centros de verdad.

---

## 14. Qué pasa después de un quite

Un quite se resuelve **como en el fútbol**: o se la saca y se la queda en
los pies, o falla y el otro sigue con la pelota. No hay estados
intermedios.

### El loop y por qué NO se arregla con pelotas divididas

La primera versión entregaba la pelota al que ganaba el quite y ahí mismo
volvían a disputarla, tick tras tick, en el mismo metro cuadrado: un
partido de prueba terminó **340-0**. El parche fue mandar la pelota a
rebotar unos metros tras cada quite ganado — y era un parche, no fútbol:
si le sacás la pelota a alguien, te la quedás.

Lo que evita el loop de verdad es que **perder el duelo se pague**:

| Quién | Qué le pasa |
| --- | --- |
| El que pierde la pelota | queda fuera de la disputa `ticks_penalizacion_duelo` (26 ticks ≈ 6,5 s de juego) |
| El que va al quite y falla | lo mismo: quedó pasado |
| El que gana el quite | se lleva la pelota, sin penalización |

Mientras está penalizado, un jugador **ni intenta quitar ni sale a
perseguir la pelota** — está mal parado, rehaciéndose. Sin esa segunda
parte volvería corriendo detrás del que lo pasó y el loop seguiría igual.

Además, el que acaba de ganar la pelota tiene `ticks_gracia_posesion` (6
ticks ≈ 1,5 s) sin que se la puedan disputar, para acomodarla. Sin esa
gracia, apenas uno la recuperaba ya lo estaba atacando el siguiente rival:
salían 118 quites por partido en vez de ~50.

### Habilidad nueva: Recuperación

Habilidad de campo atada a `quite` (`data/habilidades.json`). No empuja
ningún duelo: **acorta el cooldown** de quedar fuera de la jugada, así que
el jugador se rehace y vuelve mientras el resto todavía está mal parado.

| Nivel | Multiplicador del cooldown |
| --- | --- |
| Bronce | ×0,75 |
| Plata | ×0,55 |
| Oro | ×0,35 |

### Pendiente

**Rebotes en un quite ganado**: hoy el quite es binario, se la lleva o no.
La idea de que a veces la toque pero quede dividida para cualquiera es una
mecánica aparte, todavía sin implementar.

---

## 15. Desde dónde patea cada jugador

El atributo `tiro` no entraba en la DECISIÓN de rematar, solo en el
resultado: un jugador de media 20 evaluaba pegarle desde 25 metros
exactamente igual que un crack, y después la erraba. Medido, el 23% de
los remates de un plantel de media 27 salían desde más de 20 metros.

Ahora `tiro` define el **alcance**: hasta dónde le da para patear
(`rango_tiro_malo` 16,5m → `rango_tiro_bueno` 34m, en
`data/utility_pesos.json`). Más lejos de su alcance, la utilidad de
rematar se le cae a cero y el jugador prefiere seguir metiéndose o
pasarla — que es lo que hace un jugador limitado en la vida real.

### Medido (60 partidos por nivel)

| Media de plantel | Remates | Distancia media | Desde +20m |
| --- | --- | --- | --- |
| 27 | 7,9 | 13,0 m | **15%** |
| 39 | 9,7 | 13,8 m | 17% |
| 50 | 11,4 | 14,7 m | 23% |
| 62 | 12,6 | 17,0 m | **33%** |

Un plantel flojo la busca de cerca; uno bueno se anima de media distancia.

### Nota sobre la paridad entre motores

Con equipos naturales —los que genera el juego— la paridad se mantiene:
**3,08 goles contra 3,17** del abstracto. Pero si se fuerza a los dos
equipos a un potencial uniforme (`potencial_objetivo`), el espacial queda
sistemáticamente por debajo: 1,95 contra 2,95 con potencial 40.

No es un error de calibración: es que **al motor espacial le importa la
composición del plantel y al abstracto no**. Un equipo natural tiene
algunas figuras que se llevan los remates; uno de potencial uniforme no
tiene a nadie que se destaque, y este motor lo castiga porque cada acción
la ejecuta un jugador concreto, mientras que el abstracto samplea del
pool. Es una consecuencia deseable de simular jugador por jugador — pero
conviene tenerla presente al medir: **la comparación válida es con equipos
naturales**, no con potenciales forzados.

---

## 16. Saque del medio y salida del arquero

### Saque del medio: todos en su mitad

Las posiciones base de los de arriba están en campo rival (EXT en x=8, DC
en x=14) — correctas durante el juego, **no para un saque**. Al reiniciar
desde el medio se usaban tal cual, así que se veían tres rivales parados
adentro de tu campo antes de que la pelota se moviera, en contra de la
regla. Ahora `_reiniciar_desde_medio` repliega a todos a su propia mitad.

### A quién se la da el arquero: no está cableado

No tiene lógica especial para elegir destinatario — es un poseedor más y
decide con la misma utilidad que cualquiera. Medido sobre 290 salidas, de
las que llegan a un compañero: MC 38%, DFC 33%, LAT 25%, MCO 3%, EXT 1%.
O sea que el destinatario más frecuente es un volante central, aunque
entre los dos tipos de defensor se llevan el 58%.

### Saque de arco

Ya existe como jugada propia. Cuando la pelota sale por la línea de fondo
(remate afuera, al palo, o pase que se va), se cobra saque de arco: los
rivales salen del área grande como manda la regla, se emite un evento
`saque_arco` y el arquero pone la pelota en juego.

Lo ejecuta con **sus** atributos, que hasta entonces no los leía nadie:

| Distancia del saque | Atributo |
| --- | --- |
| Hasta 28 m (salida jugada) | `pies` |
| Más de 28 m (pelotazo) | `golpe` |

Ese atributo define la velocidad de la pelota, el alcance, y —lo que
importa— entra como valor del pasador en el duelo de intercepción. De ahí
que la probabilidad de que el saque llegue a un compañero dependa del
arquero, medido con `tests/_diag_arquero.gd`:

| `pies`/`golpe` del arquero | Saques completados |
| --- | --- |
| 20 | 53% |
| 45 | 65% |
| 70 | 69% |
| 95 | 67% |

Se aplana arriba porque un arquero mejor también intenta salidas más
largas y arriesgadas, que es un rendimiento decreciente razonable.

**Trampa que costó encontrar**: al principio la tasa no dependía del
arquero (71/71/64/76, puro ruido). El atributo correcto se usaba para la
velocidad y el radio de intercepción, pero el DUELO de intercepción seguía
leyendo `pases` — un número que en un arquero no significa nada. Si se
agregan más ejecutores con atributos propios (un especialista en tiros
libres, por ejemplo), hay que acordarse de que el atributo viaja en la
pelota (`attr_pasador`), no se re-deduce en el duelo.

### Todavía pendiente

**Laterales y córners**: hoy una pelota que sale por los costados no
existe como jugada; se resuelve dándosela al arquero. Y un remate que se
va al fondo debería ser córner si la tocó un defensor.

---

## 17. Córners y laterales

Hasta acá **la pelota nunca salía de la cancha**: los pases apuntan a un
jugador y los jugadores están siempre adentro, así que no había de dónde
sacar un lateral ni un córner. Primero hubo que crear las formas de que
salga, y recién después los reinicios tienen sentido.

### Cómo sale la pelota

| Fuente | Qué pasa |
| --- | --- |
| Quite | 10% de las disputas termina con la pelota desviada afuera |
| Remate bloqueado | un defensor cerca y en la línea del remate lo tapa; 45% de esos bloqueos sale afuera |
| Remate al palo | rebota y sale |
| Atajada | el arquero no siempre la retiene: si falla el roll de `agarre`, la manotea al córner |
| Remate desviado | se va al fondo (saque de arco, ya existía) |

### Qué se cobra

Igual que el reglamento, según por dónde salió y **quién la tocó último**:

- por el costado → **lateral** para el que no la tocó, desde ese punto
- por el fondo, tocada por el que defiende ese arco → **córner**
- por el fondo, tocada por el que ataca → **saque de arco**

En el córner la pelota va al banderín, la ejecuta el atacante más cercano,
y los dos equipos se meten al área — que es lo que hace peligroso un
córner. Después el ejecutor decide con la utilidad de siempre.

### Medido

| | Por partido |
| --- | --- |
| Córners | 3,95 |
| Laterales | 2,9 |

Son pocos comparados con un partido real (~10 córners y ~40 laterales),
pero el partido dura 4 minutos, no 90: la referencia no es el conteo real
sino que aparezcan lo suficiente para verse sin frenar el juego. Los
laterales son tiempo muerto, así que conviene que sean pocos.

### El bloqueo es un duelo, no una probabilidad fija

Meterse en la línea del remate da la OPORTUNIDAD; que el bloqueo salga o
no lo decide un duelo, igual que todo lo demás en el motor:

- **Ataca**: el `tiro` del que patea.
- **Defiende**: `barrida` × 0,6 + `agilidad` × 0,4. No hay atributo
  "bloqueo" en el GDD; esos dos son los que describen el gesto (tirarse a
  taparla y reaccionar a tiempo).
- **Distancia**: de lejos el defensor tiene tiempo de leer el remate y
  meter el cuerpo; a quemarropa le pasa por al lado antes de reaccionar
  (×0,45 pegado al arco, ×1,0 pasados 22 metros).
- Con los bloques A/B/C/D de siempre, así que personalidad y habilidades
  entran igual que en cualquier duelo.

Medido (`tests/_diag_bloqueo.gd`), % de remates bloqueados:

| | defensa 30 | defensa 55 | defensa 85 |
| --- | --- | --- | --- |
| **tiro 30** | 22% | 42% | 57% |
| **tiro 60** | 2% | 15% | 36% |
| **tiro 90** | **0%** | 2% | 11% |

Un delantero de élite no es tapado casi nunca por un defensa flojo, que es
exactamente lo que se buscaba.

### Después del bloqueo

La pelota no queda siempre en el mismo lado:

| Destino | Chance |
| --- | --- |
| Sale (córner o lateral) | 35% |
| La controla el que bloqueó | 30% |
| Rebote suelto a cualquier lado, la pelea el que llegue | 35% |

### Nota histórica sobre el bloqueo determinista

La primera versión bloqueaba SIEMPRE que hubiera un defensor en la línea y
se comía el **63% de los remates** (en un partido real se bloquea ~25%):
los goles se derrumbaron a 0,90 por partido. La segunda lo hizo una
probabilidad fija del 40%, que arreglaba el número pero dejaba a un
defensa de 32 tapándole el remate a un delantero de 90 igual de seguido
que a uno de 30. El duelo resuelve las dos cosas a la vez.

Paridad con el motor abstracto después del cambio: **3,42 contra 3,58**,
medida sobre 120 partidos.

### Todavía pendiente

Un córner se ejecuta como un pase normal, no como un centro: el centro
necesita altura de pelota (`z`), que sigue sin existir.

---

## 18. Pase al hueco

Primera de las jugadas que faltaban del diseño original. No va a los pies:
va al **espacio por delante** del compañero, que sale a buscarlo. Rompe la
línea rival, pero la pelota viaja más y por una zona más disputada.

### Quién lo ve

Es la única acción con un **umbral de atributo**: si el jugador no llega a
`vision` 45, la opción **ni le aparece** en la lista. Es lo que separa a un
armador de alguien que solo la toca al de al lado.

Por encima del umbral la visión sigue pesando: cuanta más tiene, más lo
intenta. Con el umbral solo, un jugador de visión 90 tiraba exactamente
los mismos huecos que uno de 46, lo cual no tenía sentido.

Medido (`tests/_diag_hueco.gd`), por partido:

| `vision` del equipo | Pases al hueco | Pases normales | Goles |
| --- | --- | --- | --- |
| 25 | **0** | 67,3 | 3,08 |
| 45 | 29,9 | 39,7 | 3,28 |
| 65 | 30,5 | 37,5 | 3,40 |
| 90 | **32,1** | 36,7 | 3,72 |

### Dónde cae

El punto se calcula por delante del receptor, hacia el arco rival, y el
largo escala con la **velocidad del que lo va a buscar** (6m para un lento,
15m para un rápido): a un delantero veloz se lo podés tirar más largo.

### Efecto medido

- Se elige en ~18% de las decisiones.
- Aparecen pases donde **el rival llega antes** (55 por cada 20 partidos,
  antes 0): es exactamente el riesgo de tirar al espacio en vez de a los
  pies.
- El acierto de pase de los equipos buenos **baja** (de 83% a ~75%), porque
  usan más el hueco. Es correcto: un equipo que juega incisivo completa
  menos pases que uno que la toca de costado.

Paridad con el motor abstracto: **3,69 contra 3,58**.

### Todavía faltan

Gambeta, pase largo y pared. Y el centro, que sigue bloqueado por la
altura de pelota.

---

## 19. Gambeta

Segunda jugada del diseño original. La diferencia con conducir es quién
toma la iniciativa: conducir es llevarla y ver qué pasa (si un rival se
acerca, el motor dispara un quite y vos te defendés); **gambetear es
ELEGIR ir contra un rival puntual**.

### Cómo se resuelve

Duelo `control`×0,7 + `agilidad`×0,3 del que encara, contra `quite`×0,7 +
`agilidad`×0,3 del que marca, con los bloques A/B/C/D — así las
habilidades de `control` (Bailarín, Cohete) empujan solas, sin cablearlas.

- **Si gana**: queda más allá del defensor **y el defensor se come el
  cooldown de "quedó pasado"** que ya existía para el quite. Eso es
  exactamente lo que hace una gambeta real: sacarte un hombre de encima
  por unos segundos.
- **Si pierde**: el defensor se lleva la pelota y el cooldown lo come él.
- La gambeta **reemplaza el quite automático** de ese tick: es el mismo
  duelo por la misma pelota, visto desde el otro lado.

### Quién encara: hace falta saber

Igual que el pase al hueco pide `vision`, la gambeta pide **`control` 50**:
por debajo de eso la opción ni aparece. Y la utilidad no mira lo bueno que
sos en abstracto sino **si a ESE lo podés pasar** (la diferencia entre tu
`control` y su `quite`).

Medido (`tests/_diag_gambeta.gd`) — ganadas, y entre paréntesis intentos
por partido:

| | quite 30 | quite 55 | quite 85 |
| --- | --- | --- | --- |
| **control 30** | 0% (0,0) | 0% (0,0) | 0% (0,0) |
| **control 60** | 95% (6,6) | 56% (1,9) | 7% (1,1) |
| **control 90** | 96% (**21,2**) | 97% (14,0) | 63% (4,5) |

Un `control` 90 encara 21 veces al mismo defensor que un `control` 60
encara 6, y los dos bajan la frecuencia contra un rival difícil.

### Dos trampas de MEDICIÓN que costaron caro

1. **El evento `"gambeta"` no significa gambeta.** Un quite perdido emite
   un evento de tipo `"gambeta"` con resultado `"pierde"` (herencia del
   motor abstracto, ver `MatchEngine`). Contando eventos, los tackles
   perdidos se mezclaban con las gambetas falladas y parecía que un
   jugador de `control` 30 encaraba 30 veces por partido perdiéndolas
   todas. **Para medir gambetas hay que usar `stats.gambetas`, no los
   eventos.**
2. **El contador tiene que ser por equipo.** La primera versión sumaba los
   dos, así que un equipo al que se le fijaba `control` 30 igual mostraba
   ~2 gambetas por partido: eran las del rival.

Las dos me llevaron a conclusiones equivocadas sobre el comportamiento del
motor antes de mirar los números bien.

### Nota sobre el sesgo estructural del softmax

Hay **una sola** opción de gambeta pero **una de pase por cada compañero
alcanzable** (5-8). En un softmax, ocho opciones de puntaje medio pesan
juntas más que una sola de puntaje alto, así que la gambeta necesita pesos
altos para aparecer. Si alguna vez hay que subir o bajar su frecuencia,
esa es la palanca real — o agrupar los pases para que compitan como una
categoría.

Paridad con el motor abstracto: **3,65 contra 3,58**.

---

## 20. Pelotazo (pase largo)

Tercera jugada del diseño original, y la que existe para un motivo
concreto: **darle un repertorio propio al equipo malo**.

Medido antes de agregarla, el reparto de decisiones de un plantel de media
27 era **92,4% conducir o pasar** — gambeta 0%, pase al hueco 0,5%. No
porque el motor estuviera mal, sino porque las jugadas ricas están detrás
de umbrales de atributo (`control` 50 para gambeta, `vision` 45 para el
hueco) que un equipo de división 10 no alcanza.

El pelotazo no es una jugada *mejor*, es una **distinta**: la que hace un
equipo que no puede salir jugando.

### Cómo funciona

- **Alcance por `fuerza`**, no por técnica (42m a 72m): la pierna, no el
  pie. Por eso un equipo limitado igual lo tiene disponible.
- **Se elige** cuando hay presión encima y estás metido en tu campo — o
  sea, cuando salir jugando no es opción.
- **Solo hacia adelante**: si el compañero lejano está más atrás que vos,
  la opción no aparece.
- **Su baja efectividad sale sola del motor**, sin reglas nuevas: una
  pelota que viaja mucho es más fácil de leer (`lectura_pase_largo` en el
  duelo de intercepción, ×1,30 pasados 30 metros).

### Efecto medido

| Media plantel | conducir | pase | **pelotazo** | gambeta | hueco | tiro |
| --- | --- | --- | --- | --- | --- | --- |
| 27 | 23,3% | 56,7% | **13,3%** | 0,0% | 0,5% | 6,2% |
| 39 | 20,0% | 51,6% | 11,4% | 1,0% | 7,4% | 8,5% |
| 50 | 17,4% | 41,9% | 9,9% | 2,3% | 20,2% | 8,4% |
| 62 | 15,4% | 34,9% | 10,4% | 2,6% | 26,5% | 10,1% |

El equipo de media 27 pasó de 92,4% a 80% en conducir+pase. Lo usa más que
el de media 62 (13,3% contra 10,4%), aunque la diferencia es moderada: la
distingue más el hueco (0,5% contra 26,5%) que el pelotazo.

### Recalibración que hizo falta

El pelotazo baja la efectividad general (es de baja probabilidad, como
debe ser), así que hubo que subir el apetito de remate para recuperar la
paridad. Y bajó los duelos cuerpo a cuerpo de ~48 a 33 por partido —
menos quites significa **menos tarjetas y menos desgaste**, que rompía la
paridad de suspensiones con el resto de la liga. Se compensó con
`chequeos_tarjeta_por_quite` y `multiplicador_desgaste`.

Es un patrón que ya apareció varias veces: **cualquier cambio que mueva
cuántos duelos hay por partido mueve también tarjetas, lesiones y
cambios**, porque están calibrados sobre esa cantidad.

Paridad final: **3,51 contra 3,58**. Por partido: 3,6 amarillas, 6,3
cambios.

### Todavía falta

La pared. Y el centro, bloqueado por la altura de pelota.

---

## 21. Pared

Última jugada del diseño original. Se la da al compañero y **sale
corriendo a recibirla del otro lado** del que lo marca. Está modelada como
lo que es: **dos pases encadenados con una carrera en el medio**, o sea
dos oportunidades de que se la corten.

### La habilita `pases`, y ese mismo atributo la agranda

| `pases` | Paredes/partido | Muro a | Carrera |
| --- | --- | --- | --- |
| 25 | **0** | — | — |
| 40 | 2,2 | 10,4 m | 8,6 m |
| 60 | 2,3 | 12,6 m | 10,4 m |
| 90 | **3,4** | 15,9 m | 13,1 m |

Con esto queda un atributo por jugada creativa: gambeta → `control`,
pase al hueco → `vision`, pared → `pases`.

### Bug que casi se cuela: la pared exigía saber gambetear

Las dos jugadas necesitan saber quién te está tapando el camino, y esa
consulta estaba escrita adentro del umbral de gambeta. La pared terminaba
pidiendo `control` 50 sin que nadie lo hubiera decidido — **justo al
revés** de lo que debe ser, porque la pared es el recurso del que NO puede
pasarlo por sí solo.

### Otro arreglo: una entrada, una tarjeta

`CHANCE_AMARILLA` está calibrado sobre los ~180 duelos del motor abstracto
y este resuelve muchos menos, así que se tira varias veces por disputa
para igualar la tasa por partido. Pero encadenadas sin corte, **el mismo
jugador podía sacar dos amarillas en la misma entrada y quedar expulsado
en el acto** — 1,10 rojas por partido contra las ~0,4 del abstracto. Ahora
se corta en la primera tarjeta.

Quedó: 3,4 amarillas y 0,45 rojas por partido, contra ~3,6 y ~0,4 del
motor abstracto.

### Estado del repertorio

Con la pared quedan implementadas **las cinco jugadas** del diseño
original: conducir, gambeta, pase, pase al hueco, pelotazo y pared, más el
remate. Falta solo el **centro**, que sigue bloqueado por la altura de
pelota (`z`).

Paridad con el motor abstracto: **3,57 contra 3,58**.

---

## 22. Centros y altura de pelota

Esto estuvo bloqueado varias secciones: **la pelota era 2D**, así que un
centro por encima de todos habría sido interceptable por cualquiera
parado abajo.

### La altura

Cada pase lleva ahora una `altura_max`, y la `z` sale de una parábola
simple según cuánto lleva recorrido. Los pases rasos llevan `altura_max`
0, así que **para todo lo que ya funcionaba no cambia nada** — es
aditivo. Por encima de `z_inalcanzable` (2,5m) el chequeo de intercepción
se saltea: los de abajo no la alcanzan.

La `z` viaja en el fotograma, así que la animación puede mostrarla cuando
la UI lo soporte (hoy dibuja en 2D y la ignora).

### El centro

Se ofrece si el jugador está **abierto y adelantado**, sabe pegarle
(`centros` ≥ 40) y hay un compañero **dentro del área**. Vuela a 6 metros
de altura, o sea que no se corta en el camino: **se define al caer**.

### El duelo aéreo

Ataca `cabezazo`×0,6 + `salto`×0,4. Defiende `salto`×0,5 +
`cabezazo`×0,3 + `fuerza`×0,2. Y antes que ellos, **el arquero puede salir
a descolgarla** con `achique` si cae en su zona.

Medido (`tests/_diag_centro.gd`), duelos ganados por el atacante:

| | def 30 | def 60 | def 90 |
| --- | --- | --- | --- |
| **ata 30** | 43% | 0% | 4% |
| **ata 60** | 98% | 63% | 15% |
| **ata 90** | 97% | 97% | 73% |

**Sesgo conocido**: con atributos iguales el atacante gana ~73%, no 50%.
Es porque el atacante se mide como `tecnico` y el defensor como `fisico`,
y el castigo por energía baja es mucho mayor en los físicos (0,35 contra
0,15 en `Duel.ENERGIA_K`). O sea que **un defensor cansado salta mucho
peor**. Es defendible como realismo, pero conviene saberlo: los centros
favorecen al que ataca, sobre todo tarde en el partido.

### Cuatro atributos que no leía nadie

`centros`, `cabezazo`, `salto` y `achique` existían en el GDD desde
siempre y ningún motor los usaba. Ahora los cuatro deciden algo.

### Frecuencia

2,5% de las decisiones, unos 2,3 centros por partido. Parece poco contra
los ~15 de un partido real, pero en proporción da igual: 15 centros sobre
~1000 pases reales es también ~1,5%.

Paridad con el motor abstracto: **3,70 contra 3,58**.

### Lo que la altura desbloquea a futuro

Ahora que existe `z`, quedan al alcance el córner como centro de verdad
(hoy se ejecuta como pase raso), el cabezazo al arco como remate propio
(hoy el que gana el duelo aéreo simplemente se queda la pelota), y los
despejes largos por arriba.

---

## 23. Lo que desbloqueó la altura

Tres cosas que estaban esperando la coordenada `z`.

### El córner ahora es un centro de verdad

Antes se ejecutaba como pase raso y por eso rendía tan poco. Ahora el
ejecutor la cuelga al área buscando al compañero de mejor `cabezazo` +
`salto` que esté adentro, y se define en el duelo aéreo.

### Cabezazo al arco

El que ganaba el duelo aéreo simplemente **se quedaba la pelota** — por
eso un centro ganado casi nunca terminaba en gol. Ahora, si lo gana
dentro del área, cabecea: `_resolver_tiro` acepta un atributo alternativo
y el remate se resuelve con `cabezazo` en vez de `tiro`. Un cabezazo
tampoco se bloquea con el cuerpo (viene por arriba y ya se disputó en el
aire).

Circuito completo medido, por partido:

| | |
| --- | --- |
| Centros intentados | 3,45 |
| Caen al área | 3,1 |
| Los gana el atacante | 1,65 |
| Terminan en cabezazo al arco | **1,0** |
| Los descuelga el arquero | 0,35 |

### Despeje

Metido en tu campo y con gente encima: reventarla arriba y lejos. A
diferencia del pelotazo **no busca a nadie** — es sacarla de la zona de
peligro, y por eso no pide ningún atributo técnico (el alcance sale de
`fuerza`). Va alta a propósito, así que no se corta en el camino: se
disputa donde cae.

Medido: 3,0 despejes por partido, 3,5% de las decisiones.

### Nota de método

En la calibración final bajé la conversión y los goles **subieron**. Eso
no es un efecto, es ruido: con 120 partidos la banda de varianza es del
orden de ±0,2 goles, más grande que un ajuste chico. Hay que mover el
parámetro de forma decisiva y aceptar el resultado, en vez de perseguir
diferencias que están dentro del ruido — es el mismo error que ya había
cometido antes con una muestra de 20.

Paridad con el motor abstracto: **3,61 contra 3,58**.

---

## 24. Faltas, tiros libres y penales

Había tarjetas pero **ninguna infracción que cortara el juego**: se
amonestaba sin que se viera una falta. Ahora las tarjetas cuelgan de las
faltas, que es como debió ser desde el principio.

### Cómo se cobra

Un quite fallado es la situación típica (llegó tarde), y un quite ganado
también puede serlo con menor probabilidad. Si hay falta: se corta el
juego, se chequea tarjeta y se reanuda con tiro libre — o **penal** si fue
adentro del área.

El tiro libre lo patea el de mejor `tiros_libres` si está a tiro de arco
(otro atributo del GDD que no leía nadie); si no, se pone en juego y sigue
el partido. El penal lo patea el de mejor `tiro`, con una ventaja grande
sobre el arquero e incluyendo el bonus de personalidad que ya existía en
`Penales.gd` (Pícaro, Clutch, Frágil mental).

### Medido, por partido

| | |
| --- | --- |
| Faltas | 9,7 |
| Penales | 0,30 |
| Tiros libres directos | 0,5 |
| Amarillas | 3,3 |
| Rojas | 0,35 |

### Dos ajustes que la medición obligó a hacer

**Recalibrar las tarjetas de cero.** Antes colgaban de cada quite (~35 por
partido) y ahora de las faltas (~9), así que la tasa se derrumbó a 1,3
amarillas. Cada falta tiene que ser mucho más probable de ser amonestada
para llegar a la misma tasa POR PARTIDO, que es lo que importa para las
suspensiones.

**La falta no puede premiar dos veces.** La primera versión, además de
devolver la pelota, dejaba al infractor con el cooldown de "quedó pasado"
y alejaba a los rivales 9,15m en TODAS las faltas. Entre las dos cosas, un
plantel de media 27 saltaba de 1,57 a 2,83 goles por partido: **la
diferencia entre equipos buenos y malos se aplanaba**, que es justo lo que
no se quería. Ahora no hay cooldown por falta y la barrera solo se arma en
los tiros libres que se patean al arco; en una falta lejana el juego se
reanuda y las líneas se reacomodan solas.

### Efecto que queda, y es inherente

Aun corregido, las faltas achatan un poco la curva por calidad (media 27
pasó de 1,57 a 2,57 goles). Es inherente: una falta **devuelve la posesión
al que atacaba**, y eso beneficia sobre todo al equipo que la perdía todo
el tiempo. Es realista, pero conviene tenerlo presente porque va en contra
de la progresión buscada.

Paridad con el motor abstracto: **3,74 contra 3,58**.

---

## 25. Offside como infracción

Existía solo como comportamiento: nadie se adelantaba al último defensor,
así que no había nada que cobrar. Ahora se cobra, y lo que lo hace posible
es que **los delanteros puedan equivocarse**.

### De dónde salen los offsides

La posición se juzga **en el momento del pase**, no cuando la recibe: se
marca al lanzar y se cobra al llegar. La línea ya incluye la posición de
la pelota, así que estar más allá significa estar por delante del último
defensor Y de la pelota.

Pero para que eso ocurra alguna vez, los atacantes tienen que fallar el
desmarque. El offset respecto de la línea depende de `inteligencia`: el
que la mide bien se queda ~1,5m detrás, el que no la calcula se pasa
varios metros y queda habilitando.

| `inteligencia` del equipo | Offsides/partido |
| --- | --- |
| 25 | 1,1 |
| 50 | 0,4 |
| 75 | 0,9 |
| 95 | **0,1** |

Los extremos muestran el efecto con claridad; los valores del medio son
ruidosos con 20 partidos de muestra, así que no hay que leerlos como una
curva fina.

### El detalle que costó encontrar

La primera versión no producía **ni un solo offside**. El margen de error
que había agregado no servía de nada porque los delanteros apuntaban
deliberadamente a *un metro por detrás* de la línea (`linea - 1.0`, puesto
cuando se implementó que subieran al hombro del último defensor). Ese
offset fijo era el que impedía la infracción: mientras estuviera ahí, por
más margen que se agregara nadie se iba nunca. Convertirlo en función de
`inteligencia` fue lo que la habilitó.

Paridad con el motor abstracto: **3,60 contra 3,58**.

### Estado del motor

Con esto queda cubierto todo lo que el documento de diseño listaba como
pendiente del motor: las seis jugadas, centros y altura de pelota,
córners, laterales, saques de arco, faltas, tiros libres, penales y
offside.

## 26. Acciones físicas para la animación

La vista tenía los sprites de patear, barrida y arquero volando, pero no
podía dispararlos. El motor exponía el `evento` del tick y el evento trae
`jugador_posicion` — el ROL, `"DC"` o `"ARQ"` — así que no había forma de
saber a **cuál** de los 22 animar. Y aunque hubiera traído la clave,
tampoco alcanzaba: los eventos son semánticos y su timing no es el del
gesto. Un pase se registra como evento cuando **llega** (o cuando lo
cortan), varios ticks después de la patada; animar ahí sería patear en el
momento equivocado.

Por eso las acciones van por un canal aparte, no colgadas del evento:

```gdscript
"acciones": [{"clave": 100007, "accion": "patea"}]
```

Un array por fotograma, casi siempre vacío o de un elemento. Se registra
en el momento del gesto (`_lanzar_pase`, `_despejar`, `_resolver_tiro`,
`_intentar_robo`, `_resolver_gambeta`, `_cobrar_penal`) con `_accion()`,
que hace `return` inmediato si el partido se simula sin fotogramas: el
resto de la liga no paga nada. Verificado que el resultado es idéntico
con y sin fotogramas.

Un partido medido: 79 patadas, 34 barridas, 4 vuelos del arquero sobre
960 fotogramas, repartidos entre 26 jugadores distintos.

**Duración.** El motor registra la acción en UN tick, pero un tick son
250 ms y mostrar la pose un solo fotograma queda como un parpadeo. La
vista la sostiene: 2 ticks patear, 3 la barrida, 4 el arquero tendido.
Se resuelve mirando hacia atrás (`_acciones_activas`) en vez de guardar
estado, así funciona igual reproduciendo, pausando o saltando a cualquier
punto de la línea de tiempo.

**Los cuerpos tendidos no se componen.** El resto de los sprites salen de
pegar un cuerpo (dirección) a un juego de piernas (pose). La barrida no:
pegarle piernas abiertas a un torso parado daba un tipo de pie con las
patas al costado, y encima flotando sobre su sombra, porque las filas
vacías del sprite quedaban abajo y el sprite se apoya por el borde
inferior. Barrida y arquero volando son sprites enteros, horizontales, y
con dos orientaciones alcanza: tirado en el piso lo único que se lee es
hacia qué lado se fue. El ancho de dibujo se deriva del ancho del sprite
en vez de ser fijo, así esos dos —que son más anchos que altos— salen con
píxeles del mismo tamaño que los demás y no aplastados.

## 27. El estadio (etapa 6 de la vista)

Todo el decorado se dibuja como **polígonos proyectados con textura y
UV**, no como sprites pegados en pantalla: `draw_colored_polygon` con los
cuatro vértices pasados por `sim_a_pantalla` y los UV derivados del
tamaño REAL en metros del panel. Consecuencia: la proyección inclina el
estadio sola, un tile conserva su escala lo use donde lo use, y el día
que cambien las constantes de `ProyeccionPartido` se mueve todo junto.
Cuesta cuatro llamadas de dibujo por tribuna, no una por ladrillo.

**Los arcos tienen profundidad de verdad y entran al Y-sort en dos
pedazos.** La red, el techo, el lateral lejano y el poste de atrás van
con la profundidad del poste lejano; el lateral cercano, el poste de acá
y el travesaño, con la del cercano. Así una pelota que entra al arco
queda por delante de la red pero por detrás del palo cercano, un arquero
parado en la línea tapa la red, y una pelota que se va desviada pasa por
detrás de toda la estructura. Un arco dibujado de una sola pieza no
puede hacer las tres cosas.

**La textura de la cancha sale de `calidad_cancha`**, el mismo número
−8..+3 del GDD que ya castiga `pases` y `control` en el duelo
(`EstadoCancha.modificador`). `VistaCancha.estado_desde_calidad` lo parte
en potrero / regular / híbrido, y cada uno trae su propia aspereza de
pasto: el potrero es tierra irregular, el híbrido verde parejo. Si la
cancha complica el juego, ahora se ve que lo complica.

### Tres trampas de la proyección oblicua

**La tribuna tiene que ser mucho más alta que profunda.** La proyección
aplasta la profundidad a 0,52 y estira la altura a 0,85. Una tribuna de
20 m de fondo y 14 de alto sube 262 px por altura pero baja 229 px por
fondo: neta, una franja de 30 px arriba de todo. Con 14 de fondo y 22 de
alto queda una tribuna. Por lo mismo, la tribuna de ESTE lado no puede
levantarse: está entre la cámara y la cancha, y si sube más de lo que
avanza se acuesta sobre el campo y tapa el partido. Va baja, y funciona
como borde inferior del cuadro.

**Una brizna de pasto no puede medir un tile de alto.** El césped es una
textura tileada cada 3 m con variación sutil. Darle a cada columna un
tono propio parece razonable mirando el tile suelto, pero al repetirlo
las columnas se empalman entre tiles y la cancha sale rayada de punta a
punta. Las briznas van de tres píxeles.

**El público a escala de píxel es estática de TV.** Con celdas de 0,27 m
la tribuna se veía como ruido de televisor, y con colores saturados,
como confeti. Cada hincha ocupa medio metro (unos 5-10 px en pantalla),
la paleta es chica y apagada, y las tribunas van tinteadas hacia abajo
—las laterales y la cercana más que la de enfrente— para que el público
no tire más contraste que los jugadores y el ojo se quede en la pelota.

**El margen de cámara pasó de 2 a 12 metros.** Estaba en 2 porque
asomarse fuera de la línea de cal mostraba un vacío negro. Ahora que hay
pista, muro y tribunas, dejar ver 12 m es lo que pone al partido adentro
de un estadio. Con el zoom de juego la tribuna de enfrente aparece
cuando la jugada se va contra esa banda y las cabeceras cuando se juega
en un área: en el mediocampo la cancha ocupa la pantalla entera, que es
lo que hace una cámara que sigue la pelota de cerca.

## 28. Relato, tarjetas y festejo (etapa 7 de la vista)

Sin chispas en los duelos: estaba en el pedido original pero se sacó a
propósito. El feedback del duelo lo da el relato.

**El motor tuvo que emitir dos cosas nuevas.** Primero, `"clave"` en los
eventos que se narran (remate, gol, penal, falta, offside, córner,
lateral, saque de arco): sin eso el relato decía "Remata DC" en vez de
"Remata DC Ferreira", porque el evento traía el rol y no el jugador. Las
tarjetas salen de `MatchEngine`, que es compartido con el motor
abstracto y no sabe de claves espaciales, así que ahí se agregó
`jugador_id` y la vista lo traduce cruzando con el nombre del equipo.

Segundo, el fotograma ahora trae **todos** los eventos del tick
(`"eventos"`) y no solo el último. Una entrada fuerte emite la tarjeta y
después la falta; quedarse con el último hacía desaparecer las tarjetas
del relato. `"evento"` sigue existiendo con el último, porque lo consume
la vista vieja.

**No se narra todo.** El motor emite un evento por pase completado y por
quite: narrarlos sería un teletipo a cuatro líneas por segundo.
`RelatoPartido.importancia` filtra, y de paso decide cuánto se sostiene
cada línea. Medido: 20 líneas por partido, una cada 48 fotogramas —unos
12 segundos de reproducción a x1—, todas con apellido real, ninguna
cayendo al rol.

**Los tiempos del relato van en segundos REALES, no en ticks.** Son
tiempo de lectura, no tiempo de partido: a x16 el partido vuela pero el
ojo no. Por lo mismo, en pausa no corre nada, ni el relato — si alguien
para el partido es justamente para leer.

**El festejo congela la reproducción**, la única pausa automática que
tiene el partido, y dura `2,2 / velocidad` segundos: a x16 es un
instante y no le arruina el apuro a nadie. Saltar al resultado no narra
ni festeja: adelanta el índice de narración sin pasar por él.

**El fotograma que se congela es el ANTERIOR al del gol.** El motor
manda a todos al círculo central en el mismo tick en que valida el gol,
así que congelar el fotograma del gol muestra el saque del medio, no la
jugada. Uno atrás todavía tiene al delantero con la pelota en el área.
Como contrapartida el marcador de ese fotograma todavía va 0-0, así que
durante el festejo el tanteador se toma del fotograma del gol — si no,
el cartel dice "¡GOL!" arriba de un 0-0.

**El festejo es UNA señal para tres cosas**: el cartel del HUD, la
apertura de cámara y el salto de la tribuna leen el mismo valor 0..1. Si
cada uno llevara su propio reloj se desincronizarían. Las tarjetas se
guardan por clave y no por posición, así el cartelito acompaña al que la
vio mientras camina, y se dibujan al final sin Y-sort: son información,
y taparlas con un jugador que pasa por delante sería perderlas.

## 29. La vista nueva enchufada

`ui/main.gd` abre `VistaPartido` en vez de `PartidoVisual`. Dos cosas que
hubo que resolver:

**GameState guarda el resultado con los NOMBRES de los equipos**, pero la
vista necesita los `Team`: las claves de los fotogramas se resuelven a
apellidos con el plantel, y la textura de la cancha sale de la
`calidad_cancha` del local. Se buscan por nombre en la liga del jugador,
que es donde se jugó el partido. Alternativa descartada: meter la tabla
de apellidos en `resultado_seguido` desde `Liga` — el core no tiene por
qué saber que alguien va a mostrar apellidos.

**Godot sigue llamando `_process` en un nodo invisible.** Sin un
`is_visible_in_tree()` al principio, el partido se seguía jugando de
fondo mientras el usuario está en otra pantalla, y al volver ya estaba
terminado.

El panel perdió su barra de "< Volver": la vista trae su botón Menú
arriba a la derecha y la pantalla es toda cancha, que es el punto.

Se borraron `ui/partido_visual.gd`, `ui/cancha.gd` y `ui/pixel_art.gd`,
que quedaron sin usar. La única referencia que sobrevivía era un
comentario en `sprites_partido.gd`.

## 30. Los tres rasgos que el motor espacial desbloqueó

De los ~30 rasgos de personalidad quedaban 5 sin conectar por falta de
un sistema donde engancharlos. El motor espacial dio ese sistema para
tres. Siguen sin conectar **Adaptable** (no hay penalización de "fuera de
posición" que cancelar) y **Madrugador** (no hay noción de calendario
denso ni de días entre partidos).

### Enfocado — no se va en offside

Corrige **dos cosas distintas**, y hace falta que sean dos:

1. **Dónde se para.** El margen de error al medir el desmarque se
   multiplica por 0,2.
2. **Cuándo arranca.** Al juzgar la infracción se le dan 1,6 m de gracia.

Con solo lo primero el rasgo casi no se notaba: 0,86 → 0,79 offsides por
partido, un 8%. La razón es que el offside no lo causa solo el mal
posicionamiento — la línea defensiva SE MUEVE, y un delantero puede
quedar pasado sin haberse movido él. Contra la trampa del offside,
pararse mejor no alcanza.

La tolerancia no es hacer trampa con el reglamento. El motor juzga la
posición en el tick del pase, o sea con 0,25 s de grano, y un desmarque
bien cronometrado es exactamente lo que pasa DENTRO de ese cuarto de
segundo: arranca habilitado y para cuando la pelota sale ya está pasando.
Esa sincronización es lo que el rasgo describe y es lo único que la
resolución del tick no puede representar sola.

Medido, 300 partidos: **0,74 → 0,37 offsides por partido** (la mitad),
goles 2,00 → 2,03 (sin cambios). Es un rasgo de no perder la pelota, no
de convertir más.

### Metódico — juega al libro

Baja la temperatura del softmax: menos temperatura = elige más seguido la
opción de mayor utilidad en vez de probar cosas. Va sobre el valor ya
calculado y no sobre la base, así también le come parte del nerviosismo
por presión, que es justamente lo que se supone que hace ser metódico.

**Hubo que calibrarlo con cuidado y el motivo es interesante.** Con
factor 0,6 el rasgo valía **+0,43 goles por partido** — un 25% más, un
disparate para un rasgo común (~8% del pool). Eso no es un bug del rasgo:
es que la temperatura existe para dar variedad y, con la función de
utilidad ya afinada, explorar es un costo neto. Cualquier cosa que
reduzca la exploración es un buff. La sensibilidad además es muy alta:
0,85 → +0,00, 0,80 → +0,11, 0,75 → +0,34. Quedó en **0,80**: un rasgo de
estilo con un plus chico, no de poder. Se ve en la mezcla de decisiones
(conducir +1,8 pts, pase −2,2, tiro +0,8).

### Pie preferido — le cuesta el lado malo

Tiene **dos mitades y las dos hacen falta**:

1. **Sesgo de decisión**: la utilidad de jugar hacia su lado malo baja
   proporcionalmente a cuánto cruza (hasta −0,25).
2. **Penalización de ejecución**: si igual la juega, sale peor — el pase
   más lento y más fácil de leer, el remate con menos atributo efectivo
   (×0,80 en el cruce total).

Con solo la primera mitad el rasgo **no costaba nada**: medido, esquivar
el lado malo hasta le mejoraba el rendimiento (+0,07 goles). Y un rasgo
negativo que no se paga no es un rasgo. Es la excepción a la regla de
§4.1 —"las personalidades son sesgos de decisión, no porcentajes
sueltos"— y tiene que serlo: el sesgo modela que la EVITA, pero lo que
hace negativo al rasgo es que cuando no le queda otra, la pega peor.

Medido, 300 partidos: **2,00 → 1,85 goles por partido**.

El lado bueno se mide contra el eje transversal de la cancha orientado al
ataque, que es la única referencia estable que hay: el motor no modela
hacia dónde mira el cuerpo. Una consecuencia linda y gratis: un diestro
abierto por la izquierda tiene el arco hacia su derecha, o sea del lado
bueno — el rasgo castiga la posición incómoda, no la banda, que es como
funciona de verdad.

**El pie sale del id del jugador**, no de un campo: no existe `pie` en el
jugador y derivarlo del id lo hace estable entre partidos y entre
guardados (un zurdo lo es siempre), sin migración de saves. Uno de cada
cuatro, que es la proporción real. `Personalidad.pie_preferido` lee un
campo `pie` si algún día existe, así que reemplazarlo es cambiar una
función.

### Sobre medir esto

El efecto que se busca y la banda de ruido tienen el mismo tamaño. Con
120 partidos la banda es ~±0,2 goles y con 300 baja a ~±0,13, así que
todo lo de arriba está medido a 300. Y ojo con una trampa: **cambiar el
motor mueve también el brazo de control**, porque los planteles generados
naturalmente ya traen ~3,5% de jugadores con Pie preferido, y en una
simulación caótica alcanza con que uno pegue un pase más lento para que
el partido entero diverja. El control no es un valor fijo entre corridas.

## 31. El tiempo muerto: remate en vuelo y balón parado

Dos cosas que el motor resolvía en CERO tiempo y por eso no se veían
nunca: el remate y la falta. El partido pasaba de "remata" a "sacan del
medio" en 0,25 s, y una falta se cobraba y se reanudaba en el mismo tick
— no había interrupción, los jugadores aparecían ya acomodados y recién
ahí salía el tiro libre.

### El remate ahora vuela

El resultado se sigue decidiendo igual (los mismos duelos, las mismas
tiradas, en `_resolver_tiro`), pero **aplicarlo se posterga**: la pelota
sale hacia un punto del arco a 26 m/s y el gol, la atajada, el palo o el
afuera ocurren cuando LLEGA, unos 3 ticks después. Un remate en vuelo no
se intercepta ni se va afuera por el camino: ya está resuelto, lo único
que falta es que llegue.

Adónde apunta depende del resultado ya decidido: el gol a ±3 m del
centro, la atajada a ±3,4 (donde el arquero llega, por eso vuela), el
palo justo al poste, y el afuera a 4,5-9 m del centro y por arriba. El
arquero se tira **mientras la pelota viaja**, no cuando ya entró.

**Y el gol no saca del medio en el mismo tick.** La pelota se queda en la
red y los 22 vuelven CAMINANDO a su mitad durante 10 ticks. Sin eso la
pelota nunca llegaba a verse adentro del arco. De paso simplificó la
vista: el festejo ahora congela el fotograma DEL gol (que ya tiene la
pelota en la red, a los 22 donde estaban y el marcador actualizado) en
vez del anterior, y desapareció el parche que le pasaba el marcador por
separado.

### El balón parado para el juego

`_detener_juego` deja la pelota quieta en el punto, le da a cada uno una
**marca** y para el juego N ticks (8 la falta, 10 el córner y el gol).
Durante esos ticks el paso 0 de `_tick` hace un tick reducido: los
jugadores TROTAN hacia su marca (45% de su velocidad) y nada más. Al
terminar se ejecuta la jugada.

**Qué clase de tiro libre es lo decide dónde fue la falta, y eso decide
quién sube:**

| Dónde | Qué se juega | Quién se mueve |
|---|---|---|
| A tiro de arco | Remate con `tiros_libres` | Barrera a 9,15 m, el resto a su casillero |
| Zona rival, a menos de 38 m | Centro al área | Suben los de arriba del que ataca y baja TODA la defensa rival |
| Lejos | Se pone en juego corto | Cada uno a su casillero |

El reparto del centro es literalmente el mismo del córner, porque es la
misma jugada. Y el ejecutor se elige por atributo: `tiros_libres` en el
directo, `centros` en el que se cuelga, el más cercano en el corto.

El córner pasó a usar el mismo mecanismo: antes los dos equipos aparecían
de golpe adentro del área y la pelota salía en el mismo tick.

### Lo que costó, y cómo se recuperó

El tiempo muerto son ~15% de los ticks del partido (unos 8 por falta ×9,
10 por córner ×2, 10 por gol ×3, 3 por remate ×9). Medido a 200 partidos,
antes → después:

| | Antes | Después | Final |
|---|---|---|---|
| Goles | 3,27 | 2,85 | 3,03 |
| Tiros | 9,9 | 8,5 | 9,6 |
| Pases | 41,6 | 34,0 | 33,1 |

Los pases bajan y **eso es el costo aceptado**: hay menos partido jugado
por partido. Los goles no podían bajar, porque la referencia es la
PARIDAD con `match_engine.gd` —la economía, los objetivos y los fans
están calibrados contra él— y el abstracto da 3,26. Se recuperaron
subiendo la disposición a rematar (`tiro.geometria` 5,3 → 6,9) en vez de
la conversión: con menos tiempo en juego, los equipos definen antes. Se
eligió ese lado porque mantiene intacto el porcentaje de conversión y
mueve la mediana de distancia de remate apenas (17,8 → 18,5 m), mientras
que tocar `porteria_base` habría hecho quedar mal a todos los arqueros.

Paridad final contra el motor abstracto, 200 partidos: goles 3,03 vs
3,26, amarillas 3,38 vs 3,17, rojas 0,66 vs 0,61. (Ojo con medir esto con
el demo de 20 partidos: ahí las amarillas daban 3,0 y parecían rotas.)

## 32. Dos bugs que destapó el vuelo del remate

### El arquero no se movía: la pelota le aparecía en las manos

El remate volaba a un punto del arco elegido con un `randf()` suelto, y
el arquero se quedaba clavado en su posición. Cuando la atajaba, la
pelota llegaba a la línea y en el tick siguiente se teletransportaba a
sus manos.

La causa de fondo es que el destino del remate y la reacción del arquero
se decidían por separado. Ahora **el alcance del arquero decide adónde va
la pelota**: se calcula cuánto puede desplazarse mientras el remate viaja
(su velocidad × los ticks de vuelo, más 2 m de estirada) y con eso

- una **atajada** va a un punto que él alcanza, y él sale a cruzarse en
  la trayectoria; los dos llegan al mismo lugar al mismo tiempo, sin
  teletransporte. Además termina 0,8 m DELANTE de la línea, que es donde
  están las manos, no adentro del arco;
- un **gol** va a un punto fuera de su alcance (y si tiene el arco entero
  cubierto, se la metieron igual y se elige libre). El arquero se tira
  igual y no llega, que es exactamente lo que se quiere ver.

### Los jugadores retrocedían antes de saber si era gol

El posicionamiento leía `poseedor_id != -1 and equipo == pos_local` para
saber si tu equipo tiene la pelota. Con la pelota EN EL AIRE no hay
poseedor, así que durante cada vuelo **los dos equipos se replegaban como
si la hubieran perdido**. En un pase de 2-3 ticks no se notaba; con el
remate volando quedó a la vista: pateaban al arco y arrancaban a
retroceder antes de que la pelota llegara.

Se corrigió leyendo `equipo_con_pelota`, que ya existía tres líneas más
arriba y ya contemplaba el caso del vuelo (cae en `pelota.pasador_local`).
El bug estaba en usar una condición distinta y peor para lo mismo.

Y el tick que PARA el juego (gol, falta, córner) ya no mueve a nadie más:
si no, el arquero que se acaba de tirar se levantaba y trotaba a su
posición en el mismo fotograma en que la pelota entraba.

### Lo que movió en el balance

El equipo que ataca ahora se queda adelantado durante los vuelos en vez
de replegarse, así que los pases son más largos y más disputados: los
completados bajan de 33 a 29 por partido y la intercepción sube de 23% a
26%. Los goles no se movieron (3,00, contra 3,26 del abstracto).

Las TARJETAS sí: menos quites por partido (28,6 → 23,5) las dejó en 2,90
amarillas contra 3,17 del motor abstracto, o sea el equipo del jugador
juntaba menos suspensiones que el resto de la liga. Se compensó subiendo
`chequeos_tarjeta_por_quite` de 26 a 29 y quedaron en 3,25 vs 3,17,
rojas 0,61 vs 0,61. Es la enésima vez que pasa lo mismo: **cualquier
cambio en cuántos duelos hay por partido mueve las tarjetas**, porque
están calibradas sobre ese número.

## 33. El arquero no podía pararse en el arco

Su base estaba en x = −48 (4,5 m por delante de la línea) y, peor, el
posicionamiento le aplicaba `LIMITE_X` como a cualquier jugador de campo.
Ese límite existe para que defensores y delanteros no se planten adentro
del área chica, y son 9 metros antes de la línea de fondo — o sea que
**el arquero no podía retroceder más allá de 9 metros de su propio arco.
La posición "parado en el arco" literalmente no existía**, y como su base
ya estaba adelantada, terminaba viviendo en el área grande. Un remate le
entraba con el arquero dos metros por delante del arco, mirando.

Ahora tiene su propio corral: `ARQUERO_X_MIN` (51,8, casi la línea) y
`ARQUERO_X_MAX` (36, el borde del área). Entre esos dos se mueve con la
misma `ATRACCION_X` de siempre, que es lo que le da el comportamiento
correcto solo. Medido en un partido:

| Dónde está la pelota | X medio del arquero | Más adelantado |
|---|---|---|
| En su propio tercio | −51,7 | −50,5 |
| En el mediocampo | −50,3 | −47,5 |
| En el tercio rival | −47,1 | −42,6 |

Achica cuando el juego está lejos y vuelve a la línea cuando la pelota se
le viene encima, sin salir nunca del área. Balance sin cambios: goles
3,10 vs 3,26 del abstracto, amarillas 3,29 vs 3,17.

**Y ahora se distingue.** Con los 22 de dos colores no había forma de
saber cuál de los del fondo era el arquero. `ColoresClub.arqueros()`
elige de una paleta RESERVADA (verde flúor, negro, rosa, turquesa) que no
comparte ningún color con la de campo, y busca uno que no se parezca ni a
las dos camisetas ni al otro arquero. Se eligió una paleta aparte en vez
de calcular un tinte desde el color del club porque con cuatro colores
reservados siempre hay alguno libre, y así no hay que preocuparse de que
un tono calculado caiga cerca de algo que ya está en cancha.

De paso, un bug de HUD: la columna de velocidades se centraba leyendo
`_columna.size.y`, que el VBox no reporta hasta que corre el layout. Con
el valor viejo quedaba mal centrada y el botón "Saltar" terminaba abajo
de todo, pisando el cartel del poseedor y medio fuera de pantalla. Ahora
el alto se calcula de la cantidad de botones.

## 34. Aceleración: nadie sale a velocidad punta

Hasta acá `velocidad` decidía todo el movimiento y **`aceleracion` no la
leía nadie** — solo pesaba en la media del jugador vía
`position_weights.json`. Y el movimiento era instantáneo: un jugador
parado pasaba a su velocidad punta en el primer tick.

Ahora cada entidad lleva una **velocidad escalar actual** (`rapidez`) que
sube `aceleracion` m/s² por segundo hasta su tope. `aceleracion` se
interpola entre 2,4 y 5,2 m/s², que es el rango real de un futbolista.

| velocidad / aceleración | Punta | Tiempo hasta punta | Cubre en 2 s |
|---|---|---|---|
| 20 / 20 | 4,7 m/s | 1,75 s | 5,7 m |
| 20 / 90 | 4,7 m/s | 1,00 s | **7,2 m** |
| 90 / 20 | 8,6 m/s | 3,00 s | 5,9 m |
| 90 / 90 | 8,6 m/s | 2,00 s | **9,7 m** |

Lo interesante es la comparación del medio: **en los primeros dos
segundos, un lento explosivo (20/90) cubre más terreno que un rápido
pesado (90/20)**. Ese es exactamente el trade-off que se quería, y es
donde se define un mano a mano.

**Girar también cuesta.** A 8 m/s no se cambia de sentido sin frenar: la
velocidad se multiplica por cuánto se parece el rumbo nuevo al viejo, con
piso en 0,35. Un cambio chico de rumbo casi no paga (el coseno vale ~1),
pero darse vuelta del todo deja al jugador casi parado — y ahí la
aceleración vuelve a decidir cuánto tarda en relanzarse.

**Verificado que el atributo hace algo**: dos planteles idénticos salvo
`aceleracion` (90 contra 20), 300 partidos alternando localía → 1,92
goles a favor contra 1,52, y 140 partidos ganados contra 91.

### Lo que movió

Defender se volvió más caro (cuesta arrancar y cuesta girar), así que los
atacantes llegan más cerca: la mediana de remate bajó de 18,5 a 15,8 m y
los goles se fueron a 3,51 contra los 3,26 del motor abstracto. Se
devolvió parte de la disposición a rematar que se había subido por el
tiempo muerto (`tiro.geometria` 6,9 → 6,2) y quedó en **3,34 goles vs
3,26, amarillas 3,17 vs 3,17**. Rendimiento: 62 → 68 ms por partido.

También se corrigió el alcance del arquero en el remate, que estimaba con
la velocidad punta: con rampa eso le daba un alcance que no tiene. Ahora
usa `_alcance_en`, que integra la rampa desde su velocidad actual.

## 35. Que las interrupciones se VEAN

Tres cosas que seguían pasando en cero tiempo o en el lugar equivocado.

### El arquero se tiraba adentro del arco

El remate le pasaba al arquero el destino CRUDO de la pelota como punto
al que ir, y para un gol ese destino está 1,2 m adentro de la red. O sea
que el arquero se metía al arco tratando de tapar. Ahora se le arma su
propio destino: **toma el costado al que va la pelota, pero su X se queda
en la línea**. Se tira sobre la línea, que es lo que hace un arquero.
Medido en 10 partidos: nunca pasa la línea de fondo (lo más adentro que
llega es 0,70 m por delante).

### La pelota no se veía irse afuera

`_pelota_fuera` cobraba el saque en el mismo tick en que decidía que
salía, así que el lateral aparecía cobrado sin que nunca se viera salir
la pelota. Ahora es en dos fases, igual que el remate: la pelota **vuela
hasta 3 metros más allá de la línea** —frenarla justo sobre la cal no se
lee como que salió— y el saque se cobra recién cuando cruza. Medido: la
pelota viaja 6 fotogramas (1,5 s) antes de que se cobre el lateral.

Y el lateral y el saque de arco pasaron a ser interrupciones con pausa,
como ya lo eran la falta y el córner. El saque de arco además deja de
teletransportar rivales fuera del área: ahora se les cambia la marca y
**salen caminando** durante la pausa.

### Los delanteros se pegaban al arquero

`_perseguidores` mandaba a los dos rivales más cercanos directamente a la
pelota, siempre. Con la pelota en las manos del arquero adentro de su
área eso son dos delanteros encima suyo, que no pasa nunca en una cancha.
Ahora, en esa situación puntual, el que sale a presionar **se planta en el
borde del área** en vez de entrar. Medido: el rival más cercano queda a
7,9 m de media (el mínimo de 0,7 es la cola: un delantero que ya estaba
ahí porque acababa de rematar).

### Y un beat de quietud

Toda interrupción arranca con un 40% de sus ticks en que **nadie se
mueve**. Suena el silbato y el juego se corta en seco; recién después la
gente se acomoda. Sin eso, el momento en que para el juego no se leía —
la jugada seguía fluyendo hacia otro lado y parecía que nunca hubo
interrupción. En el saque del medio, además, la marca de cada jugador se
resetea a donde quedó parado: si arrastrara la del balón parado anterior,
los 22 arrancarían caminando hacia la última falta en vez de esperar la
pelota.

### Balance

Más tiempo muerto otra vez. Goles 3,18 contra 3,26 del abstracto, y las
amarillas volvieron a caer con los quites (`chequeos_tarjeta_por_quite`
29 → 31, quedan 3,26 vs 3,17). Es la tercera vez que hay que ajustar ese
número por lo mismo, y va a pasar de nuevo cada vez que cambie cuánto
tiempo la pelota está en juego.

## 36. Las tarjetas se calibran solas (hasta donde se puede)

`chequeos_tarjeta_por_quite` era una constante que hubo que recalibrar a
mano TRES veces seguidas — con el tiempo muerto del balón parado, con la
aceleración y con la presión al arquero — porque cada uno de esos cambios
movía cuántas infracciones hay por partido, y las tarjetas están
calibradas sobre ese número.

Ahora el presupuesto de tiradas **se acumula con el tiempo** y cada
infracción se lleva lo acumulado desde la anterior. El total esperado es
`tiradas_por_partido` sin importar cuántas infracciones haya: si hay
menos, cada una carga con más presupuesto. En términos de fútbol también
se sostiene — en un partido cortado, cada falta pesa más.

**Primer intento, descartado**: proyectar los quites del partido en curso
(`quites × ticks_totales / tick`). Al principio del partido esa
proyección es puro ruido —con un quite en el tick 10 proyecta un partido
de 96— y como arranca sobreestimando, sale sesgada para abajo: daba 2,90
amarillas contra las 3,26 de la constante. Acumular por tiempo no tiene
ese problema porque no proyecta nada: mide lo que ya pasó.

### Hasta dónde llega la corrección

Se midió forzando el `ticks_gracia_posesion` para mover las infracciones
a propósito, 150 partidos por punto:

| Faltas/partido | Amarillas |
|---|---|
| 11,3 | 4,07 |
| 6,7 (el valor real) | 3,28 |
| 4,0 | 2,53 |
| 3,1 | 2,29 |

O sea que **no es invariante del todo**, y no puede serlo: una falta no
puede dar más de una tarjeta, así que con 3 faltas por partido el techo
son 3 amarillas por más presupuesto que se acumule. Subir el tope de
tiradas de 90 a 250 casi no cambió nada (2,29 → 2,42) justamente por eso:
con ~90 tiradas la chance de amonestar ya es del 85% y lo que satura es
el modelo, no el tope.

Lo que sí hace es amortiguar: una caída del 54% en las faltas se traduce
en una del 30% en las tarjetas en vez de ser proporcional. Para las
derivas que aparecen en la práctica (±30%) alcanza para no tener que
tocar nada.

Paridad final contra el motor abstracto, 200 partidos: goles 3,24 vs
3,26, amarillas 3,28 vs 3,17, rojas 0,52 vs 0,61.

## 37. Medir la paridad en la liga de verdad

Toda la calibración de este motor se hizo contra `Team.generar` suelto, y
está bien para comparar cambio contra cambio. Pero no reproduce los
planteles que arma la pirámide ni el reparto de niveles de una liga real,
así que no contesta la pregunta que importa: **jugando de verdad, ¿mis
partidos tienen más goles que los del resto de la liga?** Si los tuvieran,
la economía, los objetivos y los fans quedarían mal calibrados solo para
el jugador, que es el único cuyos partidos usa este motor.

`tests/_diag_paridad_liga.gd` juega temporadas completas de la pirámide
real en tres divisiones distintas y compara los partidos del equipo
seguido (MotorEspacial) contra el resto de la liga (MatchEngine), sacando
los goles del resto de la tabla:

| División | Mis partidos | Resto de la liga |
|---|---|---|
| 10 | 3,05 | 3,48 |
| 5 | 3,41 | 3,01 |
| 1 | 3,00 | 3,15 |

Sin sesgo sistemático: 3,15 contra 3,21 en promedio, y el signo cambia
según la división. La dispersión por división es esperable — de mis
partidos hay ~150 por punto y del resto diez veces más.

**Y una advertencia para no volver a asustarse**: tres partidos sueltos
no dicen nada. Tres pruebas de humo seguidas dieron 4, 9 y 8 goles con
una media real de 3,2. La cola de esta distribución es larga.

## 38. Por qué las interrupciones seguían sin leerse

Tres cosas medidas después de que el usuario dijera que seguía sin ver
nada de esto.

### La pelota cruzaba la línea y volvía en el fotograma siguiente

La salida SÍ estaba implementada, pero duraba **un solo fotograma**: la
pelota viaja ~2,75 m por tick y el margen fuera de la línea era 3 m, así
que cruzaba y al tick siguiente ya estaba puesta para el lateral. 0,25
segundos.

Ahora `_detener_juego` **no mueve la pelota al punto del saque**: la deja
donde quedó —afuera de la cancha, en las manos del arquero, donde fue la
falta— durante toda la parte quieta, y recién la acomoda cuando los
jugadores empiezan a caminar. Medido: la pelota cruza la línea y se queda
afuera 5 fotogramas (1,25 s) con los 22 congelados, después vuelve al
punto del lateral y se ejecuta.

### El córner salía por adentro del arco

La atajada manoteada llamaba a `_desviar_afuera` con el CENTRO DEL ARCO
como origen, y desde ahí la salida más cercana es su propia línea de
fondo: la pelota viajaba tres metros hacia atrás, metiéndose en la red.
Se veía quedar en las manos del arquero y de golpe había un córner que
nunca se vio salir. Ahora `_manotear_al_corner` la manda **por al lado
del palo** (4,7 a 8,7 m del centro del arco), que es el gesto real.

### El saque del medio amontonaba cuatro jugadores en el círculo

Las posiciones base de los de arriba (EXT en x=8, DC en x=14) están en
campo rival, y el saque del medio las CLAMPEABA a x=±1. Como el DC y el
MCO comparten y=0, terminaban tres o cuatro jugadores encima de la
pelota, entrando en duelo apenas arrancaba el partido.

Ahora la formación se **comprime** dentro de la propia mitad (×0,775
sobre la profundidad medida desde el arco propio) en vez de aplastarse
contra la línea, y todos menos el que saca quedan fuera del círculo
central — que además es la regla. La foto queda como la de un saque de
verdad: arquero en su arco, línea de fondo a −39, mediocampo a −23, los
de arriba sobre el círculo y UNO solo con la pelota.

Ojo con el signo: no se puede usar `base.x < 0` para saber de qué lado va
cada uno, porque la base del delantero está en campo rival y el signo
miente. Se mide la profundidad desde el arco propio.

### Y la quietud, más larga

`FRACCION_QUIETOS` pasó de 0,4 a 0,6 y las interrupciones se alargaron
(falta 8 → 12 ticks, córner 10 → 13, lateral 5 → 7, saque de arco 6 → 8).
Una falta ahora son 3 segundos, de los cuales **1,75 con los 22
absolutamente inmóviles**. Verificado contando jugadores que se movieron
entre fotogramas: 0 de 22 durante siete fotogramas seguidos.

Balance tras todo esto: goles 3,23 vs 3,26 del abstracto, amarillas 3,29
vs 3,17. **No hizo falta tocar nada**: las faltas bajaron de 6,7 a 6,3 y
el presupuesto de tarjetas por tiempo (§36) absorbió el cambio solo, que
era exactamente para lo que se hizo.

## 39. El arquero no es un jugador de campo, y el corte en seco

### El arquero salía a jugar

Se lo vio salir de un saque de arco a **jugar una pared con un
defensor**, perderla y comerse el gol. El motor lo trataba como a
cualquier otro: nada lo distinguía en `evaluar_opciones`.

Ahora el arquero no conduce, no encara y no juega paredes: saca. Y hubo
que arreglarlo en DOS lugares, porque sacarle "conducir" de las opciones
no alcanzaba — `_decidir_y_ejecutar` tiene un atajo por el que el
poseedor conduce en todos los ticks en los que NO evalúa (evaluar 4 veces
por segundo desbordaba las tiradas de remate), y ese atajo lo hacía
avanzar igual. Con las dos mitades, el arquero se queda con la pelota
hasta que decide qué hacer. Si se queda sin opciones, la revienta, que es
lo que hace cualquier arquero sin salida — antes ese caso no existía
porque conducir siempre estaba disponible.

**Costó 0,46 goles por partido** (3,23 → 2,77): eran goles que salían de
regalos del arquero y no deberían haber existido nunca.

### El corte en seco

La falta y el saque del medio ahora **frenan el partido de golpe**: los
jugadores se plantan en su marca, la pantalla da un parpadeo negro y todo
queda absolutamente inmóvil 12 ticks (3 segundos) antes de que se juegue
la pelota. El parpadeo es presentación pura —la frenada ya existía en el
motor— pero sin ese golpe visual el ojo no registra el corte: solo ve que
todo se quedó quieto, que es lo que el usuario venía reportando tres
veces seguidas.

El corte además **tapa el reacomodo**: los jugadores se teletransportan a
sus marcas durante el parpadeo en vez de caminar. El resto de los
reinicios (lateral, córner, saque de arco) siguen con la gente
acomodándose caminando, que ahí sí se ve bien y no necesita corte.

`_detener_juego` toma un flag `corte`; el motor marca el fotograma con
`"corte": true` y la vista dispara el parpadeo desde ahí. Se marca en el
fotograma y no se deduce del evento porque la falta y el saque del medio
lo disparan por caminos distintos.

Verificado contando movimiento entre fotogramas: 22 jugadores se mueven
en el fotograma del parpadeo (el salto a las marcas, que queda tapado) y
**0 de 22 durante los 12 siguientes**.

### Balance

Al recuperar los goles que se llevó el arreglo del arquero, `tiro.geometria`
dejó de servir: de 7,0 a 7,6 subió los tiros de 8,7 a 8,9 y los goles no
se movieron (2,98 las dos veces). Estaba saturado. Se usó
`tiro_resolucion.porteria_base` (0,425 → 0,50), que es el otro lado del
mismo problema: no cuántas veces rematan sino cuántas van al arco.

Paridad final: goles 3,27 vs 3,26, amarillas 3,19 vs 3,17. Y en la liga
real (§37): división 10, 3,32 vs 3,39; división 5, 3,55 vs 3,04;
división 1, 3,13 vs 3,09.
