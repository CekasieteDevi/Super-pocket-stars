class_name Jugadas
extends RefCounted

## Jugadas preparadas: lo que el plantel ensaya hasta que le sale solo.
##
## Se diferencian del ejercicio táctico (core/entrenamiento.gd) en tres
## cosas:
##
##   SE APRENDEN UNA VEZ. Una jugada tarda semanas en salir y, cuando
##   sale, queda para siempre. El ejercicio da su bonus solo mientras
##   está puesto.
##
##   DE A UNA. El club elige una jugada y hasta terminarla no puede
##   empezar otra. No se abandona a mitad de camino: es lo que hace que
##   elegir pese.
##
##   SE VEN. Cada jugada cambia cómo se para y cómo se mueve el equipo en
##   el MotorEspacial (ver los `_jugada_*` de core/motor_espacial.gd). El
##   MatchEngine no tiene cancha, así que recibe el efecto equivalente en
##   sus duelos (ver EQUIVALENCIA).
##
## Los clubes de la IA no ensayan: saben las jugadas de su categoría. Un
## club de primera sabe varias; uno del ascenso, ninguna (ver
## CANTIDAD_IA). Así el jugador que sube se las encuentra enfrente.

const PAREDES := "paredes"
const DEFENSA_ADELANTADA := "defensa_adelantada"
const AMAGUE := "amague_tiro_libre"
const CORNER_CORTO := "corner_corto"
const CORNER_BLOQUE := "corner_bloque"
const CONTRAGOLPE := "contragolpe"
const CONTRAPRESION := "contrapresion"

## En el orden en que se muestran.
const LISTA := [PAREDES, DEFENSA_ADELANTADA, AMAGUE, CORNER_CORTO,
	CORNER_BLOQUE, CONTRAGOLPE, CONTRAPRESION]

const NOMBRE := {
	PAREDES: "Paredes",
	DEFENSA_ADELANTADA: "Defensa adelantada",
	AMAGUE: "Amague de tiro libre",
	CORNER_CORTO: "Córner corto",
	CORNER_BLOQUE: "Córner en bloque",
	CONTRAGOLPE: "Contragolpe ensayado",
	CONTRAPRESION: "Presión tras pérdida",
}

## Qué hace el equipo en la cancha, dicho en una línea.
const DESCRIPCION := {
	PAREDES: "Tocan y se van: juegan más paredes y el muro la devuelve aunque el carril venga apretado.",
	DEFENSA_ADELANTADA: "La línea da un paso al frente cuando el rival pasa: deja a los delanteros en offside más seguido.",
	AMAGUE: "En el tiro libre el pateador la toca al costado y un compañero le pega de primera. La barrera y el arquero quedan mal parados.",
	CORNER_CORTO: "Un compañero espera cerca del banderín: pase corto y centro desde otro ángulo, con la marca del área desacomodada.",
	CORNER_BLOQUE: "Cuatro o cinco se juntan en el segundo palo y arrancan a la vez al área chica. Dos bloquean a los marcadores para abrirle el pasillo al que cabecea.",
	CONTRAGOLPE: "Apenas recuperan, los de arriba ya saben adónde picar: la salida rápida dura más y llega con más gente.",
	CONTRAPRESION: "Apenas pierden la pelota, los más cercanos van a buscarla: recuperan más en los primeros segundos.",
}

## Cuántas semanas de entrenamiento lleva aprenderla, al ritmo normal.
## La temporada tiene ~52 semanas contando el receso. Con estas cifras
## las siete juntas llevan 126 semanas: casi dos temporadas y media a
## ritmo normal, una y media con el ejercicio "Jugadas armadas". Las de pelota
## parada son las más cortas porque se ensayan con la pelota quieta; las
## que mueven a los once en juego corrido son las más largas.
const SEMANAS := {
	PAREDES: 15.0,
	DEFENSA_ADELANTADA: 21.0,
	AMAGUE: 12.0,
	CORNER_CORTO: 12.0,
	CORNER_BLOQUE: 27.0,
	CONTRAGOLPE: 18.0,
	CONTRAPRESION: 21.0,
}

## El ejercicio táctico "Jugadas armadas" es justamente ensayar esto.
const RITMO_CON_JUGADAS_ARMADAS := 1.5

# ---------------------------------------------------------------------------
# Efecto en el MotorEspacial
# ---------------------------------------------------------------------------

## En qué fracción de las ocasiones se usa una jugada de pelota parada.
## No se usa siempre: el córner corto en todos los córners lo lee
## cualquiera, y un equipo que lo sabe igual cuelga la mayoría al área.
## Es `static var` y no const para que el test la ponga en 1 y vea cada
## jugada en pocos partidos.
static var USO := {
	CORNER_CORTO: 0.35,
	CORNER_BLOQUE: 0.40,
	AMAGUE: 0.40,
}

## Ventaja en el duelo aéreo del centro que sale de la jugada, en puntos
## de atributo del que cabecea. El corto desacomoda la marca: todos
## tuvieron que girar. El bloque saca al marcador del medio.
const VENTAJA_CENTRO := {
	CORNER_CORTO: 8.0,
	CORNER_BLOQUE: 12.0,
}

## Amague: el que le pega sale de un ángulo que la barrera no tapaba y con
## el arquero ya jugado hacia el otro lado. Puntos contra el arquero.
const VENTAJA_AMAGUE := 10.0

## Paredes: cuánto más se la elige y cuánto más apretado puede venir el
## carril de vuelta sin que el muro la aborte (ver pared_riesgo_max).
const UTILIDAD_PARED := 0.15
const CARRIL_PARED := 0.15

## Defensa adelantada: cuántos metros da la línea al frente en el momento
## del pase. Un delantero parado hasta ese margen detrás del último
## defensor queda en offside.
const PASO_DEFENSA := 1.5

## Presión tras pérdida: durante la transición del rival (los segundos
## después de que te la sacan) el radio de quite se agranda y el que va
## suma en el duelo.
const RADIO_CONTRAPRESION := 1.35
const VENTAJA_CONTRAPRESION := 5.0

## Contragolpe: cuánto más dura la transición del que recupera (0,5 = la
## mitad más). Es la ventana en que el equipo sale rápido y conduce hacia
## adelante (ver MotorEspacial._transicion).
const EXTRA_CONTRAGOLPE := 0.5

## Si el rival también sabe la jugada, la lee y la ventaja se achica.
const LECTURA_DEL_RIVAL := 0.5

# ---------------------------------------------------------------------------
# Efecto en el MatchEngine
# ---------------------------------------------------------------------------

## El MatchEngine no tiene córners ni offsides. Cada jugada suma en el
## bloque B de los duelos donde su jugada quedó plegada, con esta
## fracción de BONUS_ABSTRACTO. Las que defienden suman al quite del que
## defiende.
##
## Medido con tests/_diag_jugadas_partido.gd (400 partidos, división 5,
## ruido ~0,1): diferencia de gol por partido, espacial contra abstracto.
## Con todo en 0,3 daba paredes -0,04/+0,05, defensa adelantada
## +0,01/+0,10, contragolpe -0,05/+0,05 y presión tras pérdida
## +0,06/+0,10. Las de pelota parada dan ~0 en los dos: el espacial tiene
## pocos córners y tiros libres (0,1 jugadas de córner por partido), así
## que su valor está en verse, no en el resultado. Paredes y contragolpe
## no mueven el espacial, y por eso acá quedan en 0: darles bonus haría
## que la IA gane con ellas algo que el jugador no gana. Con estos
## valores: defensa adelantada +0,01/+0,02, presión tras pérdida
## +0,06/+0,06, córner en bloque 0,00/0,00.
static var BONUS_ABSTRACTO := 3.0
const EQUIVALENCIA := {
	PAREDES: {"pases": 0.0},
	DEFENSA_ADELANTADA: {"quite": 0.05},
	AMAGUE: {"tiro": 0.05},
	CORNER_CORTO: {"tiro": 0.05},
	CORNER_BLOQUE: {"tiro": 0.05},
	CONTRAGOLPE: {"pases": 0.0},
	CONTRAPRESION: {"quite": 0.2},
}

# ---------------------------------------------------------------------------
# Clubes de la IA
# ---------------------------------------------------------------------------

## Cuántas sabe un club de la IA según su categoría (0 = primera). De la
## quinta para abajo, ninguna.
const CANTIDAD_IA := [4, 3, 2, 1, 1]

## Por dónde empieza cada estilo: lo que le sirve a su manera de jugar.
## Cubre Estilos.LISTA entero.
const PREFERIDAS := {
	"Tiki taka": [PAREDES, CORNER_CORTO, CONTRAPRESION],
	"Contragolpe": [CONTRAGOLPE, AMAGUE, CORNER_CORTO],
	"Juego directo": [CORNER_BLOQUE, CONTRAGOLPE, AMAGUE],
	"Presión alta": [CONTRAPRESION, DEFENSA_ADELANTADA, PAREDES],
	"Defensivo": [CONTRAGOLPE, CORNER_BLOQUE, AMAGUE],
	"Físico": [CORNER_BLOQUE, DEFENSA_ADELANTADA, CONTRAGOLPE],
}


static func existe(id: String) -> bool:
	return LISTA.has(id)


static func sabe(equipo: Team, id: String) -> bool:
	return equipo != null and equipo.jugadas_aprendidas.has(id)


static func semanas_de(id: String) -> float:
	return float(SEMANAS.get(id, 0.0))


## Cuántas semanas de aprendizaje suma una semana de calendario. La carga
## pesa igual que en el crecimiento: entrenar más fuerte es ensayar más.
static func ritmo(equipo: Team) -> float:
	var r := CargaEntrenamiento.factor_crecimiento(equipo.carga_entrenamiento)
	if equipo.ejercicio_tactico == "jugadas_armadas":
		r *= RITMO_CON_JUGADAS_ARMADAS
	return r


## Fracción aprendida de la jugada en curso, de 0 a 1.
static func progreso(equipo: Team) -> float:
	if equipo.jugada_en_curso == "":
		return 0.0
	return clampf(equipo.jugada_semanas / maxf(semanas_de(equipo.jugada_en_curso), 0.01), 0.0, 1.0)


## Semanas de calendario que faltan al ritmo de hoy.
static func semanas_restantes(equipo: Team) -> float:
	if equipo.jugada_en_curso == "":
		return 0.0
	var falta := maxf(semanas_de(equipo.jugada_en_curso) - equipo.jugada_semanas, 0.0)
	return falta / maxf(ritmo(equipo), 0.01)


## Se puede empezar si no hay otra en curso y todavía no se sabe.
static func puede_empezar(equipo: Team, id: String) -> bool:
	return existe(id) and equipo.jugada_en_curso == "" and not sabe(equipo, id)


static func empezar(equipo: Team, id: String) -> bool:
	if not puede_empezar(equipo, id):
		return false
	equipo.jugada_en_curso = id
	equipo.jugada_semanas = 0.0
	return true


## Pasan `dias` de entrenamiento. Devuelve la jugada que se terminó de
## aprender en este tramo, o "" si no terminó ninguna.
static func avanzar(equipo: Team, dias: int) -> String:
	if equipo.jugada_en_curso == "":
		return ""
	equipo.jugada_semanas += float(dias) / 7.0 * ritmo(equipo)
	if equipo.jugada_semanas < semanas_de(equipo.jugada_en_curso):
		return ""
	var terminada := equipo.jugada_en_curso
	equipo.jugadas_aprendidas.append(terminada)
	equipo.jugada_en_curso = ""
	equipo.jugada_semanas = 0.0
	return terminada


## Las jugadas que tiene que saber un club de la IA en esta categoría. No
## saca ninguna: un club que desciende no se olvida de lo que ensayó.
##
## El orden sale del estilo y, para lo que sobra, de un rng sembrado con el
## nombre del club. No usa el rng del juego: sacar números de ahí corre el
## stream compartido y cambia la partida entera (ver Team.generar).
static func completar_ia(equipo: Team, division: int) -> void:
	if division < 0 or division >= CANTIDAD_IA.size():
		return
	var objetivo: int = CANTIDAD_IA[division]
	if equipo.jugadas_aprendidas.size() >= objetivo:
		return
	for id in orden_ia(equipo):
		if equipo.jugadas_aprendidas.size() >= objetivo:
			break
		if not equipo.jugadas_aprendidas.has(id):
			equipo.jugadas_aprendidas.append(id)


static func orden_ia(equipo: Team) -> Array:
	var orden: Array = (PREFERIDAS.get(equipo.estilo, []) as Array).duplicate()
	var resto := []
	for id in LISTA:
		if not orden.has(id):
			resto.append(id)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(equipo.nombre + "/jugadas")
	for i in range(resto.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = resto[i]
		resto[i] = resto[j]
		resto[j] = tmp
	return orden + resto


## Cuánto de la ventaja le queda a `equipo` contra `rival`: toda, o la
## mitad si el rival también la sabe y la ve venir.
static func factor(equipo: Team, rival: Team, id: String) -> float:
	if not sabe(equipo, id):
		return 0.0
	return LECTURA_DEL_RIVAL if sabe(rival, id) else 1.0


## Lo que suma en el bloque B de un duelo del MatchEngine. `atributo` es el
## del que disputa el duelo; las jugadas que defienden entran por el
## `quite` del que defiende, igual que el resto.
static func bonus_abstracto(equipo: Team, rival: Team, atributo: String) -> float:
	var bonus := 0.0
	for id in equipo.jugadas_aprendidas:
		var fraccion := float((EQUIVALENCIA.get(id, {}) as Dictionary).get(atributo, 0.0))
		if fraccion != 0.0:
			bonus += BONUS_ABSTRACTO * fraccion * factor(equipo, rival, id)
	return bonus


## Cuál de las jugadas de córner usa este córner: "" si se cuelga normal.
## Tira el rng SOLO si el club sabe alguna, así el partido de los que no
## saben ninguna sigue igual que antes, tirada por tirada.
static func elegir_corner(equipo: Team, rng: RandomNumberGenerator) -> String:
	var opciones := []
	for id in [CORNER_CORTO, CORNER_BLOQUE]:
		if sabe(equipo, id):
			opciones.append(id)
	if opciones.is_empty():
		return ""
	var id: String = opciones[rng.randi_range(0, opciones.size() - 1)]
	return id if rng.randf() < float(USO[id]) else ""


## Si esta ocasión se usa la jugada `id`. Misma regla del rng.
static func se_usa(equipo: Team, id: String, rng: RandomNumberGenerator) -> bool:
	if not sabe(equipo, id):
		return false
	return rng.randf() < float(USO.get(id, 1.0))


## Para el relato: la línea que se dice cuando sale la jugada.
static func relato(id: String) -> String:
	match id:
		CORNER_CORTO: return "¡Córner corto ensayado!"
		CORNER_BLOQUE: return "¡Córner en bloque! Arrancan todos juntos"
		AMAGUE: return "¡Amague en el tiro libre! La toca al costado"
		DEFENSA_ADELANTADA: return "¡La defensa sale en bloque y lo deja en offside!"
		CONTRAPRESION: return "¡Presión tras pérdida! La recupera enseguida"
		PAREDES: return "¡Pared ensayada!"
	return ""
