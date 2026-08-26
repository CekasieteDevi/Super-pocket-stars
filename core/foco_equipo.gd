class_name FocoEquipo
extends RefCounted

## §7.4.2: foco de entrenamiento del EQUIPO. Qué practica el plantel
## entero — físico, técnico, defensivo, táctico o pelota parada.
##
## Es el hermano colectivo del foco individual (§7.4.3, ver
## core/entrenamiento.gd): aquel elige un atributo puntual para dos o tres
## jugadores, este elige un área para los dieciocho. Y es ortogonal a la
## carga (§7.4.1, ver core/carga_entrenamiento.gd), que dice CUÁNTO se
## entrena y no QUÉ. Los tres se apilan.
##
## Lo que lo vuelve una decisión y no un botón de "más es mejor" son dos
## cosas:
##
##   PRESUPUESTO FIJO. Enfocar un área no regala crecimiento: se lo saca
##   al resto. Lo que ganan los atributos del área lo pierden, repartido,
##   todos los demás. No se puede practicar todo.
##
##   REPARTO POR TAMAÑO. El presupuesto se divide entre los atributos del
##   área, así que enfocar un área CHICA da un empujón grande a pocos
##   atributos y una GRANDE da un empujón chico a muchos. Sin esto,
##   "técnico" (8 atributos) sería cuatro veces mejor que "defensivo" (2)
##   y no habría nada que elegir.
##
## No hay que tocarlo cada semana: el área elegida se acumula en
## Team.foco_semanas mientras pasan los días, y al cierre de temporada
## pesa según cuántas semanas estuvo puesta. Cambiar de área a mitad de
## año reparte, no reinicia.

## Sin énfasis: todo crece parejo. Es una opción legítima, no la ausencia
## de una — un plantel disparejo prefiere no resignar nada.
const GENERAL := "general"

const AREAS := ["general", "fisico", "tecnico", "defensivo", "tactico", "pelota_parada"]
const POR_DEFECTO := GENERAL

## Qué toca cada área. Cuatro salen de data/attribute_groups.json; pelota
## parada es transversal (no es un grupo, es una situación de juego) y por
## eso se lista a mano.
const ATRIBUTOS := {
	"general": [],
	"fisico": ["velocidad", "aceleracion", "agilidad", "salto", "fuerza", "energia", "vitalidad"],
	"tecnico": ["control", "pases", "centros", "tiro", "volea"],
	"defensivo": ["quite", "barrida"],
	"tactico": ["vision", "inteligencia"],
	"pelota_parada": ["tiros_libres", "efecto", "cabezazo", "centros"],
}

const ETIQUETAS := {
	"general": "General",
	"fisico": "Físico",
	"tecnico": "Técnico",
	"defensivo": "Defensivo",
	"tactico": "Táctico",
	"pelota_parada": "Pelota parada",
}

const DESCRIPCIONES := {
	"general": "Sin énfasis: todo crece parejo.",
	"fisico": "Correr, gimnasio, resistencia.",
	"tecnico": "Control, pase, definición.",
	"defensivo": "Marca y recuperación.",
	"tactico": "Video, movimientos, lectura de juego.",
	"pelota_parada": "Córners, tiros libres, centros.",
}

## Cuánto crecimiento mueve el foco, en total. Se reparte ENTRE los
## atributos del área y se le descuenta, repartido, a todos los demás:
## la suma de los multiplicadores es siempre la misma, elijas lo que
## elijas. Calibrado con tests/_diag_foco_equipo.gd.
const PRESUPUESTO := 2.5

## Piso del multiplicador de un atributo desatendido. Sin esto, un área
## chica podía dejar al resto en negativo y hacer que los atributos
## RETROCEDAN por no practicarlos, que no es el trato: el trato es crecer
## más despacio.
const MULTIPLICADOR_MINIMO := 0.35


static func existe(area: String) -> bool:
	return ATRIBUTOS.has(area)


static func atributos_de(area: String) -> Array:
	return ATRIBUTOS.get(area, [])


## Multiplicador de crecimiento por atributo, dado el reparto de la
## temporada ({area: fracción}, ver Team.reparto_foco) y la lista de
## atributos que tiene el jugador.
static func multiplicadores(reparto: Dictionary, atributos: Array) -> Dictionary:
	var salida := {}
	for attr in atributos:
		salida[attr] = 0.0
	var total_fraccion := 0.0

	for area in reparto:
		var fraccion: float = float(reparto[area])
		if fraccion <= 0.0 or not ATRIBUTOS.has(area):
			continue
		total_fraccion += fraccion
		var del_area := {}
		for attr in atributos_de(area):
			if salida.has(attr):
				del_area[attr] = true
		var n_foco := del_area.size()
		var n_resto: int = atributos.size() - n_foco
		# Sin atributos en el área (o sin resto) no hay nada que repartir:
		# el área se comporta como "general".
		var mult_foco := 1.0
		var mult_resto := 1.0
		if n_foco > 0 and n_resto > 0:
			mult_foco = 1.0 + PRESUPUESTO / float(n_foco)
			mult_resto = maxf(MULTIPLICADOR_MINIMO, 1.0 - PRESUPUESTO / float(n_resto))
		for attr in atributos:
			salida[attr] += fraccion * (mult_foco if del_area.has(attr) else mult_resto)

	# Lo que no cubrió ningún área cuenta como "general" (multiplicador 1).
	if total_fraccion < 1.0:
		var falta: float = 1.0 - total_fraccion
		for attr in atributos:
			salida[attr] += falta
	return salida


## Texto para la UI: el área y qué le hace al plantel.
static func resumen(area: String) -> String:
	if area == GENERAL or not ATRIBUTOS.has(area):
		return DESCRIPCIONES.get(GENERAL, "")
	var lista: Array = atributos_de(area)
	return "%s Sube %s; el resto crece más despacio." % [
		DESCRIPCIONES.get(area, ""), ", ".join(lista)]


## Que practica un club segun como juega. Sin esto los 200 clubes de la
## piramide entrenarian todos "general" y el sistema no existiria para
## nadie salvo el jugador. El mapeo es uno a uno con Estilos.LISTA, asi
## que las cinco areas aparecen en la liga.
const POR_ESTILO := {
	"Tiki taka": "tecnico",
	"Contragolpe": "fisico",
	"Juego directo": "pelota_parada",
	"Presión alta": "tactico",
	"Defensivo": "defensivo",
	"Físico": "fisico",
}


static func para_estilo(estilo: String) -> String:
	return str(POR_ESTILO.get(estilo, POR_DEFECTO))
