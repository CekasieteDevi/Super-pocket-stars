extends SceneTree

## El changelog que muestra la pantalla de inicio está bien formado: cada
## entrada tiene versión x.x.xx, fecha y frase, y las versiones bajan de
## arriba hacia abajo sin repetirse.

const SEED := 2109

var fallos := 0


func _init() -> void:
	var entradas := Changelog.cargar()
	_ok(not entradas.is_empty(), "data/changelog.json se lee y tiene entradas")
	var errores := Changelog.validar(entradas)
	for e in errores:
		_ok(false, str(e))
	_ok(errores.is_empty(), "el changelog cumple el formato (%d entradas)" % entradas.size())
	_ok(Changelog.version_actual() == str(entradas[0]["version"]) if not entradas.is_empty() else false,
		"la versión actual es la de la primera entrada")

	# El validador tiene que detectar lo que el hook no mira.
	var repetida := [
		{"version": "0.1.01", "fecha": "2026-09-21", "cambio": "b"},
		{"version": "0.1.01", "fecha": "2026-09-21", "cambio": "a"}]
	_ok(not Changelog.validar(repetida).is_empty(), "una versión repetida es un error")
	var mal_formato := [{"version": "0.1.1", "fecha": "2026-09-21", "cambio": "a"}]
	_ok(not Changelog.validar(mal_formato).is_empty(), "una versión sin dos dígitos al final es un error")
	var sin_frase := [{"version": "0.1.00", "fecha": "2026-09-21", "cambio": " "}]
	_ok(not Changelog.validar(sin_frase).is_empty(), "una entrada sin frase es un error")

	print("FALLOS=%d" % fallos)
	quit(1 if fallos else 0)


func _ok(condicion: bool, mensaje: String) -> void:
	print(("OK: " if condicion else "FALLA: ") + mensaje)
	if not condicion:
		fallos += 1
