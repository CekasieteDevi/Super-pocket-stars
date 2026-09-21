class_name Entrenamiento
extends RefCounted

## §7.4.2: qué practica el plantel entero. Dos ranuras, físico y táctico,
## y en cada una un ejercicio que queda puesto hasta que el club lo
## cambie a mano.
##
## Un ejercicio hace dos cosas:
##
##   CRECIMIENTO. Al cierre de temporada, los atributos del ejercicio
##   crecen más y el resto crece más despacio. El presupuesto es fijo:
##   lo que gana el ejercicio lo pierde, repartido, todo lo demás. Cada
##   ranura tiene la mitad del presupuesto que tenía el foco de un área,
##   así que elegir los dos ejercicios mueve lo mismo que movía el foco.
##
##   BONUS EN EL PARTIDO. Mientras el ejercicio está puesto, el equipo
##   suma en los duelos de lo que practica. Solo cuenta el ejercicio
##   elegido HOY: lo practicado el mes pasado ya no da nada.
##
## Es ortogonal a la carga (§7.4.1, ver core/carga_entrenamiento.gd), que
## dice CUÁNTO se entrena y no QUÉ. Los dos se apilan.
##
## Los arqueros no tienen ejercicio: ninguna lista toca sus atributos, y
## el reparto les deja esos atributos a x1 (crecen parejo).

const FISICO := "fisico"
const TACTICO := "tactico"
const RANURAS := [FISICO, TACTICO]

## Sin énfasis en la ranura. Es una opción legítima: un plantel disparejo
## prefiere no resignar nada.
const LIBRE := "libre"

## En el orden en que se muestran.
const EJERCICIOS := {
	FISICO: ["libre", "correr", "rondo", "obstaculos", "gimnasio"],
	TACTICO: ["libre", "penales", "tiros_libres", "centros", "jugadas_armadas", "presion"],
}

const ETIQUETAS := {
	"libre": "Libre",
	"correr": "Correr",
	"rondo": "Rondo de pases",
	"obstaculos": "Obstáculos",
	"gimnasio": "Gimnasio",
	"penales": "Penales",
	"tiros_libres": "Tiros libres",
	"centros": "Centros",
	"jugadas_armadas": "Jugadas armadas",
	"presion": "Presión y marca",
}

## Qué ve el club en el partido, dicho en una línea.
const DESCRIPCIONES := {
	"libre": "Sin énfasis: todo crece parejo y no hay bonus en el partido.",
	"correr": "El plantel se cansa menos durante el partido.",
	"rondo": "Suma en los duelos de pase.",
	"obstaculos": "Suma en la gambeta y al aguantar la pelota.",
	"gimnasio": "Suma en el juego aéreo defensivo y en el pelotazo.",
	"penales": "Suma en los penales, en el partido y en la tanda.",
	"tiros_libres": "Suma en los tiros libres directos.",
	"centros": "Suma en los centros y en los remates de cabeza y de volea.",
	"jugadas_armadas": "La táctica nueva se asimila más rápido.",
	"presion": "Suma en el quite y en la barrida.",
}

## Qué atributos crecen más. Salen de data/attribute_groups.json; ningún
## ejercicio toca los atributos de arquero.
const ATRIBUTOS := {
	"libre": [],
	"correr": ["velocidad", "aceleracion", "energia"],
	"rondo": ["pases", "vision"],
	"obstaculos": ["agilidad", "control"],
	"gimnasio": ["fuerza", "salto", "vitalidad"],
	"penales": ["tiro", "efecto"],
	"tiros_libres": ["tiros_libres", "efecto"],
	"centros": ["centros", "cabezazo", "volea"],
	"jugadas_armadas": ["vision", "inteligencia"],
	"presion": ["quite", "barrida"],
}

## Atributos de duelo que reciben el bonus en el MotorEspacial. Es el
## atributo que los motores le pasan a MatchEngine._bloques_equipo.
## Correr y jugadas armadas no están: su bonus va por otro lado (ver
## factor_desgaste y Familiaridad._ganancia).
const DUELOS := {
	"rondo": ["pases"],
	"obstaculos": ["control"],
	"gimnasio": ["salto", "fuerza"],
	"tiros_libres": ["tiros_libres"],
	"centros": ["centros", "cabezazo", "volea"],
	"presion": ["quite", "barrida"],
}

## El penal no tiene atributo propio: se patea con `tiro`, igual que
## cualquier remate. Por eso el MotorEspacial lo marca con esta situación.
const SITUACION_PENAL := "penal"
## El MatchEngine no juega penales, tiros libres, centros ni duelos
## aéreos: todo eso queda adentro de sus duelos de pase, gambeta, quite y
## tiro. Con esta situación pide el bonus EQUIVALENTE (ver EQUIVALENCIA).
const SITUACION_ABSTRACTA := "abstracto"

## Lo que suma en el bloque B del duelo el ejercicio puesto. Va en el
## bloque B porque es del EQUIPO, como la familiaridad (-8 a +5) y el
## capitán (+2). Calibrado con tests/_diag_entrenamiento_partido.gd.
## Es `static var` y no const para que el diagnostico lo pueda agrandar y
## medir el efecto por encima del ruido, igual que MatchEngine.DUELOS_POR_ATAQUE.
static var BONUS_DUELO := 3.0

## Correr: cuánto se reduce el desgaste por duelo en el partido
## (Team.desgastar). Lo aplican los dos motores. Medido con
## tests/_diag_entrenamiento_partido.gd (300 partidos, división 5): con
## 0,85 no movía nada (+0,02 de diferencia de gol por partido en el
## espacial); con 0,6 da +0,13, parecido a lo que dan los demás.
const FACTOR_DESGASTE_CORRER := 0.6

## Qué fracción del bonus recibe cada duelo del MatchEngine, por
## ejercicio. Un ejercicio que en el MotorEspacial suma en UN tipo de
## jugada, en el MatchEngine suma en los duelos donde esa jugada quedó
## plegada, con esta fracción. Sin esto, la IA que entrena centros no
## ganaría nada en sus partidos y la que entrena presión ganaría todo.
##
## Medido con tests/_diag_entrenamiento_partido.gd (bonus x5, 300
## partidos): diferencia de gol por partido, espacial contra abstracto.
## Con todo en 1,0 daba rondo +0,21/+0,54, gimnasio (0,15) +0,19/0,00 y
## centros (tiro 0,3) +0,43/+0,05; presión ya daba +0,46/+0,51. Con estos
## valores quedan dentro del ruido (~0,1). Correr no escala con el bonus,
## así que su fila se calculó al bonus real: en el espacial da +0,13 y
## cada 1,0 de pases o quite da ~+0,1 en el abstracto.
## Penales y tiros libres casi no mueven el resultado en ninguno de los
## dos motores (+0,01): son jugadas raras. Su fuerte es la tanda y el
## crecimiento.
const EQUIVALENCIA := {
	"correr": {"pases": 0.6, "quite": 0.6},
	"rondo": {"pases": 0.3},
	"obstaculos": {"control": 2.0},
	"gimnasio": {"quite": 0.25},
	"penales": {"tiro": 0.05},
	"tiros_libres": {"tiro": 0.05},
	"centros": {"tiro": 0.8, "pases": 0.3},
	"presion": {"quite": 1.0},
}

## Cuánto crecimiento mueve CADA ranura. Se reparte entre los atributos
## del ejercicio y se le descuenta, repartido, a todos los demás. El foco
## de un área usaba 2,5; con dos ranuras cada una usa la mitad y elegir
## los dos ejercicios mueve lo mismo. Medido con tests/_diag_foco_equipo.gd.
const PRESUPUESTO_RANURA := 1.25

## Piso del multiplicador de un atributo desatendido. Sin esto, dos
## ejercicios chicos podían dejar al resto en negativo y hacer que los
## atributos RETROCEDAN. El trato es crecer más despacio.
const MULTIPLICADOR_MINIMO := 0.35


static func existe(ranura: String, ejercicio: String) -> bool:
	return EJERCICIOS.has(ranura) and (EJERCICIOS[ranura] as Array).has(ejercicio)


## "libre_fisico" y "libre_tactico" son las claves con que Team anota las
## semanas de una ranura libre (ver Team.avanzar_dias).
static func ranura_de(ejercicio: String) -> String:
	if ejercicio.begins_with(LIBRE + "_"):
		return ejercicio.trim_prefix(LIBRE + "_")
	for ranura in RANURAS:
		if (EJERCICIOS[ranura] as Array).has(ejercicio) and ejercicio != LIBRE:
			return ranura
	return ""


static func atributos_de(ejercicio: String) -> Array:
	return ATRIBUTOS.get(ejercicio, [])


## Los dos ejercicios puestos en el equipo.
static func elegidos(equipo: Team) -> Array:
	return [equipo.ejercicio_fisico, equipo.ejercicio_tactico]


static func tiene(equipo: Team, ejercicio: String) -> bool:
	return equipo.ejercicio_fisico == ejercicio or equipo.ejercicio_tactico == ejercicio


## Multiplicador de crecimiento por atributo, dado el reparto de la
## temporada ({ejercicio: fracción de su ranura}, ver Team.reparto_ejercicios)
## y la lista de atributos que tiene el jugador. Cada ranura empuja por su
## lado y los empujones se suman; la suma de los multiplicadores queda
## igual elijas lo que elijas, salvo cuando actúa el piso.
static func multiplicadores(reparto: Dictionary, atributos: Array) -> Dictionary:
	var salida := {}
	for attr in atributos:
		salida[attr] = 1.0

	for ejercicio in reparto:
		var fraccion: float = float(reparto[ejercicio])
		if fraccion <= 0.0 or not ATRIBUTOS.has(ejercicio):
			continue
		var del_ejercicio := {}
		for attr in atributos_de(ejercicio):
			if salida.has(attr):
				del_ejercicio[attr] = true
		var n_foco := del_ejercicio.size()
		var n_resto: int = atributos.size() - n_foco
		# Sin atributos del ejercicio (o sin resto) no hay nada que
		# repartir: el ejercicio se comporta como "libre".
		if n_foco == 0 or n_resto == 0:
			continue
		var suma_foco: float = PRESUPUESTO_RANURA / float(n_foco)
		var resta_resto: float = PRESUPUESTO_RANURA / float(n_resto)
		for attr in atributos:
			salida[attr] += fraccion * (suma_foco if del_ejercicio.has(attr) else -resta_resto)

	for attr in salida:
		salida[attr] = maxf(MULTIPLICADOR_MINIMO, float(salida[attr]))
	return salida


## Lo que suma el entrenamiento en el bloque B de un duelo. `atributo` es
## el que se disputa; `situacion` marca lo que el atributo solo no dice
## (el penal) o que el duelo es del MatchEngine (ver EQUIVALENCIA).
static func bonus_duelo(equipo: Team, atributo: String, situacion: String = "") -> float:
	var bonus := 0.0
	for ejercicio in elegidos(equipo):
		if situacion == SITUACION_ABSTRACTA:
			bonus += BONUS_DUELO * float((EQUIVALENCIA.get(ejercicio, {}) as Dictionary).get(atributo, 0.0))
		elif situacion == SITUACION_PENAL:
			if ejercicio == "penales":
				bonus += BONUS_DUELO
		elif (DUELOS.get(ejercicio, []) as Array).has(atributo):
			bonus += BONUS_DUELO
	return bonus


## Cuánto se multiplica el desgaste por duelo (Team.desgastar).
static func factor_desgaste(equipo: Team) -> float:
	return FACTOR_DESGASTE_CORRER if tiene(equipo, "correr") else 1.0


## Lo que suma en la chance de convertir un penal de la tanda
## (Penales._chance_gol, que no pasa por bloques). Es el mismo BONUS_DUELO,
## en puntos de porcentaje.
static func bonus_tanda(equipo: Team) -> float:
	return BONUS_DUELO / 100.0 if tiene(equipo, "penales") else 0.0


## Texto para la UI: qué crece y qué da en el partido.
static func resumen(ejercicio: String) -> String:
	var lista: Array = atributos_de(ejercicio)
	if lista.is_empty():
		return str(DESCRIPCIONES.get(LIBRE, ""))
	return "%s Crecen más %s; el resto crece más despacio." % [
		DESCRIPCIONES.get(ejercicio, ""), ", ".join(lista)]


## Qué practica un club según cómo juega. Sin esto los 200 clubes de la
## pirámide entrenarían todos "libre" y el sistema no existiría para
## nadie salvo el jugador. Cubre Estilos.LISTA entero.
const POR_ESTILO := {
	"Tiki taka": ["rondo", "jugadas_armadas"],
	"Contragolpe": ["correr", "centros"],
	"Juego directo": ["gimnasio", "centros"],
	"Presión alta": ["correr", "presion"],
	"Defensivo": ["gimnasio", "presion"],
	"Físico": ["gimnasio", "tiros_libres"],
}


## [físico, táctico] para un estilo.
static func para_estilo(estilo: String) -> Array:
	return (POR_ESTILO.get(estilo, [LIBRE, LIBRE]) as Array).duplicate()


## Partidas guardadas antes de las ranuras: el foco de un área pasa al
## par de ejercicios más parecido.
const DESDE_FOCO_VIEJO := {
	"general": ["libre", "libre"],
	"fisico": ["correr", "libre"],
	"tecnico": ["rondo", "libre"],
	"defensivo": ["libre", "presion"],
	"tactico": ["libre", "jugadas_armadas"],
	"pelota_parada": ["libre", "tiros_libres"],
}
