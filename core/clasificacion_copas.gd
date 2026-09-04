class_name ClasificacionCopas
extends RefCounted

## Quién entra a cada copa doméstica (§10). Antes entraban TODOS —los 200
## clubes al Rey, los 20 de cada división a la interna— y ninguno de esos
## dos números es potencia de 2, así que la primera ronda era una ronda
## previa con pases libres: al Rey entraban 200, jugaban 144 y 56 pasaban
## sin jugar; a la interna entraban 20, jugaban 8 y 12 pasaban sin jugar.
## El club del jugador se saltaba la primera ronda más veces de las que la
## jugaba y el cuadro no se entendía.
##
## Ahora clasifica una cantidad que SÍ es potencia de 2 y el cuadro sale
## perfecto, sin un solo pase libre:
##
##   - Copa del Rey: 128 clubes, 7 rondas. Diez divisiones no reparten
##     cupos parejos —ninguna potencia de 2 es divisible por 10, porque
##     10 tiene el factor 5— así que los cupos bajan por escalones, que
##     además es como entran las copas nacionales de verdad.
##   - Copa de división: los 16 mejores de esa división, 4 rondas. Arranca
##     en octavos.
##
## El orden de mérito sale de la TABLA DE LA TEMPORADA ANTERIOR, no de la
## actual: la copa se sortea antes de que se juegue una sola fecha. Un
## club que ascendió o descendió clasifica por la división donde JUGÓ, y
## entra igual aunque ahora esté en otra.

## Cupos al Rey por división, índice 0 = primera. Suma 128.
const CUPOS_COPA_NACIONAL := [20, 20, 16, 16, 12, 12, 8, 8, 8, 8]

## Cupos a la copa de división, sobre los 20 que la juegan.
const CUPOS_COPA_DIVISION := 16

## Clave de mérito de un club sin temporada anterior. Va por encima de
## cualquier posición real (la peor es 10ª división, 20°: 920) para que un
## club sin datos quede SIEMPRE detrás de uno que sí jugó.
const CLAVE_SIN_DATOS := 100000.0


## Cuántos clubes entran al Rey en total. Se suma en vez de escribirlo
## para que cambiar CUPOS_COPA_NACIONAL alcance: una sola fuente de verdad.
static func total_copa_nacional() -> int:
	var total := 0
	for c in CUPOS_COPA_NACIONAL:
		total += int(c)
	return total


## Cuántos cupos tiene una división (0 = primera). Una división más allá
## de la tabla de cupos hereda el último escalón.
static func cupos_de(division_idx: int) -> int:
	if CUPOS_COPA_NACIONAL.is_empty():
		return 0
	return int(CUPOS_COPA_NACIONAL[clampi(division_idx, 0, CUPOS_COPA_NACIONAL.size() - 1)])


## La foto de las tablas finales, para que las copas de la temporada que
## viene sepan quién terminó dónde. Hay que sacarla ANTES de
## Piramide.fin_de_temporada: esa llamada resetea la tabla y mueve clubes
## de división, y después ya no hay temporada anterior que mirar.
##
## Formato: nombre_club -> {"division": int 1-based, "posicion": int 1-based}.
static func posiciones_finales(piramide) -> Dictionary:
	var salida := {}
	for d in range(piramide.divisiones.size()):
		var orden: Array = piramide.divisiones[d].tabla_ordenada()
		for i in range(orden.size()):
			salida[str(orden[i])] = {"division": d + 1, "posicion": i + 1}
	return salida


## Los 128 del Rey: los primeros de cada división de la temporada
## anterior, según los cupos de esa división.
static func clasificados_nacional(piramide, posiciones: Dictionary = {}) -> Array:
	var salida := []
	var tablas := _tablas_de_referencia(piramide, posiciones)
	for d in range(tablas.size()):
		var tabla: Array = tablas[d]
		salida.append_array(tabla.slice(0, mini(cupos_de(d), tabla.size())))
	return salida


## Los 16 de la copa interna: los mejores de los clubes que juegan ESA
## división ahora. El que bajó de la división de arriba entra con mejor
## derecho que cualquiera de esta, porque su clave de mérito trae la
## división donde jugó.
static func clasificados_de_division(piramide, division_idx: int, posiciones: Dictionary = {}) -> Array:
	if division_idx < 0 or division_idx >= piramide.divisiones.size():
		return []
	var orden := _ordenar_por_merito(piramide.divisiones[division_idx].equipos, posiciones)
	return orden.slice(0, mini(CUPOS_COPA_DIVISION, orden.size()))


## Los clubes agrupados por la división que JUGARON la temporada pasada,
## cada grupo ordenado por posición. Sin temporada anterior (partida
## recién empezada) cada club cae en la división donde está hoy.
static func _tablas_de_referencia(piramide, posiciones: Dictionary) -> Array:
	var tablas := []
	for d in range(piramide.divisiones.size()):
		tablas.append([])
	for d in range(piramide.divisiones.size()):
		for equipo in piramide.divisiones[d].equipos:
			var idx := d
			if posiciones.has(equipo.nombre):
				idx = clampi(int(posiciones[equipo.nombre].get("division", d + 1)) - 1,
					0, tablas.size() - 1)
			tablas[idx].append(equipo)
	for d in range(tablas.size()):
		tablas[d] = _ordenar_por_merito(tablas[d], posiciones)
	return tablas


static func _ordenar_por_merito(equipos: Array, posiciones: Dictionary) -> Array:
	var copia := equipos.duplicate()
	copia.sort_custom(func(a, b):
		var ka := _clave_de_merito(a, posiciones)
		var kb := _clave_de_merito(b, posiciones)
		if ka != kb:
			return ka < kb
		# El desempate por nombre no es cosmético: sort_custom no es
		# estable, y sin él dos clubes con la misma clave podían entrar o
		# quedar afuera según el orden del array, que cambia solo.
		return a.nombre < b.nombre
	)
	return copia


## Cuanto MÁS CHICA, mejor clasificado. Mezcla división y posición en un
## solo número para que se puedan comparar clubes de divisiones distintas:
## el último de la 9ª (820) sigue por encima del primero de la 10ª (901).
static func _clave_de_merito(equipo, posiciones: Dictionary) -> float:
	if posiciones.has(equipo.nombre):
		var fila: Dictionary = posiciones[equipo.nombre]
		return (int(fila.get("division", 1)) - 1) * 100.0 + int(fila.get("posicion", 99))
	# Primera temporada del mundo: no hay tabla anterior de nada, así que
	# el orden lo da la reputación, que es lo único que ya distingue un
	# club grande de uno chico (Team.reputacion, sembrada por Economia).
	return CLAVE_SIN_DATOS + (100.0 - equipo.reputacion)
