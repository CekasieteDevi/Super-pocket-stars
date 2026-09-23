class_name Changelog
extends RefCounted

## Registro de cambios de la aplicación: una entrada por cada cambio, la
## más nueva primero. La pantalla de inicio muestra la versión de la
## primera entrada y la lista completa.
##
## Este archivo es la ÚNICA fuente de la versión. El hook de pre-commit
## (.githooks/pre-commit) rechaza el commit que no agrega una entrada
## nueva, así que ninguna IA ni persona puede cambiar el código sin dejar
## registrado qué hizo. Las reglas para escribir la entrada están en
## CLAUDE.md, sección "Changelog".

const RUTA := "res://data/changelog.json"

## Formato x.x.xx: el último tramo sube de a uno por cambio. Dos dígitos
## fijos para que "0.1.09" < "0.1.10" también compare bien como texto.
const PATRON_VERSION := "^[0-9]+[.][0-9]+[.][0-9]{2}$"


static func cargar() -> Array:
	var datos = DataLoader.load_json(RUTA)
	return datos if datos is Array else []


static func version_actual() -> String:
	var entradas := cargar()
	return str(entradas[0]["version"]) if not entradas.is_empty() else "?"


## Lista de problemas del registro; vacía si está bien. La usa el test de
## regresión para que un changelog roto no llegue a commitearse.
static func validar(entradas: Array) -> Array:
	var errores := []
	if entradas.is_empty():
		errores.append("el changelog no tiene entradas")
	var patron := RegEx.create_from_string(PATRON_VERSION)
	var anterior: Array = []
	for e in entradas:
		if not (e is Dictionary):
			errores.append("una entrada no es un objeto: %s" % str(e))
			continue
		var version := str(e.get("version", ""))
		if patron.search(version) == null:
			errores.append("versión con formato inválido: '%s'" % version)
			continue
		if str(e.get("cambio", "")).strip_edges().is_empty():
			errores.append("la versión %s no dice qué cambió" % version)
		if str(e.get("fecha", "")).length() != 10:
			errores.append("la versión %s no tiene fecha AAAA-MM-DD" % version)
		var partes := Array(version.split(".")).map(func(p): return int(p))
		if not anterior.is_empty() and not _es_menor(partes, anterior):
			errores.append("la versión %s no es menor que la de arriba" % version)
		anterior = partes
	return errores


static func _es_menor(a: Array, b: Array) -> bool:
	for i in 3:
		if a[i] != b[i]:
			return a[i] < b[i]
	return false
