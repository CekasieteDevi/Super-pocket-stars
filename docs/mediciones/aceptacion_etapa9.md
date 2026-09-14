# Etapa 9: aceptacion final — 2026-09-14

Estado: calibracion hecha y medida. Revision visual pendiente.

## Que se midio primero

`tests/_diag_embudo_remates.gd` (nuevo) corre los dos motores con los
mismos planteles. Son seis celdas de divisiones (1/1, 1/4, 5/5, 5/8, 10/10,
10/7), 50 parejas por celda y cada pareja de ida y vuelta: 600 partidos por
motor. Semillas 97000 a 97049, las mismas de `calibracion_final.md`.

El embudo separa tres pasos:

- remates: todo intento con evento final. El espacial cuenta los
  bloqueados; el abstracto no bloquea.
- al arco: el remate que llega al arquero.
- goles de juego: sin penales.

Antes de tocar nada, el embudo mostro tres causas de la brecha:

| celda | remates esp / abs | al arco sobre remates esp / abs | ataja el arquero esp / abs |
| --- | --- | --- | --- |
| 1/1 | 7,28 / 8,35 | 61% / 64% | 63% / 46% |
| 5/5 | 6,18 / 8,50 | 60% / 62% | 53% / 51% |
| 10/10 | 5,98 / 8,18 | 55% / 67% | 47% / 45% |
| 1/4 | 8,42 / 9,05 | 65% / 67% | 35% / 25% |

1. **El arquero de primera atajaba de mas.** La fuerza del remate y la
   cobertura del arquero eran multiplicadores sobre el atributo absoluto.
   `Duel.p_base` mira la diferencia en puntos. El mismo remate lejano le
   sacaba 13 puntos a un 9 de primera (tiro 85) y 6 a uno de decima (tiro
   40). El abstracto ataja lo mismo en las tres divisiones.
2. **El remate medio llegaba debilitado.** El `factor_fuerza` medio de los
   remates que llegan al arquero es 0,90 en las seis celdas. El remate
   medio perdia 4,6 puntos contra el arquero; el abstracto usa el atributo
   entero.
3. **Los partidos parejos generan menos remates**: 6,0 a 7,3 contra 8,2 a
   8,5. En los desparejos la diferencia es chica (7,8 a 8,4 contra 8,8 a
   9,1). Los bloqueos explican parte: 0,5 a 0,7 remates por partido que el
   abstracto no tiene.

La presion no movia la punteria. En la medicion 9.6, los remates de pie
no bloqueados iban al arco 55%, 60% y 59% con presion baja, media y alta.

## Que se cambio

Todo en `core/motor_espacial.gd` y `data/utility_pesos.json`
(`tiro_resolucion`).

- **`puntos_de_contexto`**: la fuerza por distancia, la cobertura del
  arquero y el bloqueo a quemarropa se traducen a puntos al nivel de
  referencia (`MatchEngine.NIVEL_REFERENCIA`, 46). Es la misma idea que
  `relativo_al_nivel`: la ocasion cuesta lo mismo en todas las divisiones.
- **`fuerza_referencia` 0,90**: la fuerza se centra en su media, como la
  cobertura del arquero desde la etapa 6. El remate medio llega al duelo
  con su atributo entero.
- **`castigo_presion` 0,25, `presion_referencia` 0,37**: la presion resta
  punteria al remate de pie. Cuenta a los rivales que NO son el candidato al
  bloqueo (`presion_sin_bloqueador` en la ocasion): ese defensor ya tiene
  su duelo. Se centra en la presion media de esos remates (0,32 a 0,40 en
  las seis celdas), asi que la punteria media no cambia. El cabezazo y el
  tiro libre no la leen.

Se probo y se descarto subir `tiro.geometria` para generar mas remates.
Con 8,5, 10,5 y 12,5 los remates de 1/1 dieron 7,26, 7,53 y 7,46 y los
goles 2,14, 2,05 y 2,05: suben los remates lejanos y baja la conversion.
La utilidad del remate no es la palanca del volumen.

## Resultado: brecha con el abstracto

Mismo embudo, 600 partidos por motor. IC95 por bootstrap de 5000
remuestras de parejas completas de ida y vuelta.

| celda | goles antes | goles despues | abstracto | brecha antes | brecha despues | IC95 despues − abstracto |
| --- | --- | --- | --- | --- | --- | --- |
| 1/1 | 1,78 | 2,57 | 2,89 | −38,4% | −11,1% | [−0,81; +0,16] |
| 1/4 | 3,65 | 4,35 | 4,52 | −19,2% | −3,8% | [−0,62; +0,28] |
| 5/5 | 1,84 | 2,26 | 2,61 | −29,5% | −13,4% | [−0,75; +0,05] |
| 5/8 | 3,36 | 3,63 | 4,06 | −17,2% | −10,6% | [−0,84; −0,02] |
| 10/10 | 1,92 | 2,15 | 3,02 | −36,4% | −28,8% | [−1,19; −0,55] |
| 10/7 | 3,54 | 3,78 | 4,20 | −15,7% | −10,0% | [−0,88; +0,05] |

Cinco celdas quedan debajo del 15%. En cuatro el intervalo incluye cero.
**Decima pareja sigue en −28,8%**, y la causa es el volumen: 5,89 remates
contra 8,18. La conversion al arco ya esta a la par o arriba en todas las
celdas (1/1: 56% contra 54%; 10/10: 59% contra 55%).

La "antes" de esta tabla ya incluye las etapas 3 y 5, por eso difiere de
`calibracion_final.md` (1/1: 1,58 alli, 1,78 aca).

## Los goles del favorito

El pendiente decia "ver por que el favorito hace 4-5 goles". El abstracto
hace lo mismo con los mismos planteles: 4,52 en 1/4, 4,06 en 5/8 y 4,20 en
10/7. El espacial queda por debajo (4,35, 3,63 y 3,78). No es un defecto
del espacial: es la escala de la diferencia de nivel que ya tiene el
motor contra el que esta calibrada la liga.

## Que remates cambiaron las etapas 3 y 4

Mismo embudo, 600 partidos, mismas semillas. Cada etapa se apago en memoria
con sus pesos (`pesos=` del diagnostico): la 3 sin toque largo, con demora
igual a la cadencia y sin cono de giro; la 4 con `ritmo.tope` 0,
`pausa_conduccion` 1 y `devolucion_castigo` 0. No reproducen el motor
anterior exacto: la tirada del control y el giro siguen corriendo.

| por partido | todo | sin etapa 3 | sin etapa 4 |
| --- | --- | --- | --- |
| goles | 3,12 | 2,99 | 3,11 |
| remates | 7,25 | 7,15 | 7,71 |
| bloqueados | 0,60 | 0,66 | 0,54 |
| pie a menos de 11 m | 0,57 (44%) | 0,57 (36%) | 0,64 (34%) |
| pie 11-18 m | 1,80 (40%) | 1,73 (41%) | 1,90 (38%) |
| pie 18-25 m | 2,68 (36%) | 2,69 (34%) | 2,84 (35%) |
| pie a 25 m o mas | 0,57 (34%) | 0,52 (29%) | 0,66 (33%) |
| cabezazos | 1,46 | 1,51 | 1,52 |

Entre parentesis, la conversion del tramo.

- **Etapa 4**: saca 0,46 remates por partido (−6%) repartidos en todos los
  tramos. El que mas pierde es el de 25 m o mas (−14%). Los goles no se
  mueven (3,11 contra 3,12). Se confirma lo que anotaba la etapa: se
  perdieron remates que no convertian.
- **Etapa 3**: no cambia cuantos remates hay. Baja los bloqueos 9% y sube
  la conversion de cerca (36% a 44%): llegan mejor perfilados. Los goles
  suben 4%.

## Remate lejano (BUG-007)

`tests/_diag_remates.gd`, 100 partidos por division, antes y despues:

| | antes | despues |
| --- | --- | --- |
| remates de 25 m o mas con tiro 70-99 | 66 | 74 |
| su conversion | 16,7% | 16,2% |
| remates de mas de 25 m (D10 / D5 / D1) | 10% / 8% / 10% | 11% / 8% / 11% |

El abuso no vuelve. La conversion por calidad geometrica del remate de pie
ahora crece con la calidad: 20%, 25%, 28%, 34% y 38% por intervalo. Antes
caia en el ultimo (11%).

## Realismo, contra la copia "antes"

`tests/_diag_realismo.gd`, 168 partidos, semilla 77100. La copia "antes"
reproduce la tabla de la etapa 3 (2,911 goles).

| metrica | antes | despues | cambio |
| --- | --- | --- | --- |
| goles | 2,911 | 3,244 | +11,5% |
| tiros | 7,91 | 7,76 | −1,9% |
| controlada_pct | 56,9 | 57,0 | +0,1 pts |
| perdidas | 19,88 | 19,22 | −3,3% |
| recuperaciones_altas | 7,80 | 7,21 | −7,6% |
| resistencia_final_pct | 88,7 | 88,8 | +0,1 pts |

Los 168 partidos dan el mismo resultado con y sin fotogramas.

## Verificaciones

`tests/test_aceptacion_ocasion.gd` (nuevo), `FALLOS=0`, para los dos lados:

- De frente a 16 m va al arco 0,75; corrido 13 m hacia la banda, 0,60.
- A 18 m sin nadie va al arco 0,817; con dos rivales encima que no bloquean
  (presion 0,61), 0,663. La presion media no mueve la punteria y el
  cabezazo no la lee.
- El defensor en la linea del remate presiona 0,43, pero la punteria lee
  0,00: ya tiene su duelo de bloqueo.
- A 14 m convierte 0,535 de los remates al arco con el arquero centrado y
  0,604 con el arquero corrido 2,8 m.
- A 27 m, con los dos planteles enteros en 40 o en 85: 0,600 al arco y
  0,444 de conversion en los dos.

`tests/test_tiro_lejano.gd`: la prueba de punteria neutraliza la presion.
La escena no tiene a nadie cerca; con la presion centrada, presion cero
sumaba punteria en todas las distancias y el tope de 0,85 aplastaba la
diferencia de cerca. La distancia se sigue probando sola.

Regresion completa: `ARCHIVOS_CON_FALLAS=0 de 125 en 388s con 8 en paralelo`. No se hizo commit.

## Pendiente

- **Revision visual: no hecha.**
- **Decima pareja genera 28% menos remates que el abstracto.** Es de
  generacion de juego (etapas 1, 2 y 4), no de la calidad de la ocasion.
- **La conversion al arco quedo algo arriba del abstracto en 5/5** (57,5%
  contra 49,3%). `fuerza_referencia` es una media de las seis celdas.
- Los cabezazos subieron de conversion (de 26-36% a 40-50% por intervalo)
  porque tambien usan `factor_fuerza`. No se separo.
- Las recuperaciones altas bajan 7,6% en el diagnostico de realismo. Puede
  ser el efecto de mas goles (mas saques del medio) o ruido; no se
  investigo.

## Reproducir

```bash
<godot> --path . --headless --script tests/_diag_embudo_remates.gd -- parejas=50 celda=0 salida=user://embudo_0
<godot> --path . --headless --script tests/test_aceptacion_ocasion.gd
```

Datos: [aceptacion_etapa9/](aceptacion_etapa9/) (`embudo_antes_*`,
`embudo_despues_*`, `embudo_sin3_*`, `embudo_sin4_*`, realismo y remates).
