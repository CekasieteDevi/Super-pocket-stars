extends SceneTree

## Cuanto salta la pelota de un fotograma al siguiente, y POR QUE.
##
## El reporte del usuario: "el pase va lejos del jugador y despues se
## teletransporta a los pies; con las intercepciones igual". Un tiron es
## un desplazamiento que la velocidad del tick anterior no explica: la
## pelota no acelera sola.

const SEED := 4400
const PARTIDOS := 8
const TIRON_MINIMO := 2.5


func _init() -> void:
	var tirones := []
	var por_causa := {}
	var fotogramas := 0
	for i in range(PARTIDOS):
		var r1 := RandomNumberGenerator.new()
		r1.seed = SEED + i
		var a := Team.generar("A", r1, 0, NivelDivision.potencial(4), "Uruguay", NivelDivision.realizacion(4))
		var b := Team.generar("B", r1, 400, NivelDivision.potencial(4), "Uruguay", NivelDivision.realizacion(4))
		var r2 := RandomNumberGenerator.new()
		r2.seed = SEED + i
		var res := MotorEspacial.simular(a, b, r2, true)
		var fot: Array = res["fotogramas"]
		fotogramas += fot.size()
		for k in range(2, fot.size()):
			var p0: Vector2 = _pos(fot[k - 2])
			var p1: Vector2 = _pos(fot[k - 1])
			var p2: Vector2 = _pos(fot[k])
			var previo: float = p0.distance_to(p1)
			var d: float = p1.distance_to(p2)
			# La pelota no acelera sola: si el paso de este tick no lo
			# explica el paso del anterior, hubo un salto.
			if d < TIRON_MINIMO or d <= previo * 1.6 + 0.5:
				continue
			tirones.append(d)
			var causa := _causa(fot[k - 1], fot[k])
			if not por_causa.has(causa):
				por_causa[causa] = []
			por_causa[causa].append(d)

	tirones.sort()
	print("tirones: %d en %d partidos (%.1f por partido, %d fotogramas)" % [
		tirones.size(), PARTIDOS, float(tirones.size()) / PARTIDOS, fotogramas])
	if not tirones.is_empty():
		print("  mediana %.1f m | p90 %.1f m | max %.1f m" % [
			tirones[tirones.size() / 2], tirones[int(tirones.size() * 0.9)], tirones[-1]])
	var causas := por_causa.keys()
	causas.sort_custom(func(x, y): return por_causa[x].size() > por_causa[y].size())
	for c in causas:
		var arr: Array = por_causa[c]
		arr.sort()
		print("  %-26s %4d  (%.1f/partido)  mediana %.1f m  max %.1f m" % [
			c, arr.size(), float(arr.size()) / PARTIDOS, arr[arr.size() / 2], arr[-1]])
	quit()


func _pos(f: Dictionary) -> Vector2:
	return Vector2(f["pelota"]["x"], f["pelota"]["y"])


## De que jugada salio el tiron, leido igual que lo lee la vista.
func _causa(anterior: Dictionary, actual: Dictionary) -> String:
	if int(actual.get("detenido", 0)) > 0 or int(anterior.get("detenido", 0)) > 0:
		return "pelota parada"
	var ev = actual.get("evento", null)
	var antes: int = int(anterior["pelota"]["poseedor_id"])
	var ahora: int = int(actual["pelota"]["poseedor_id"])
	var tipo := ""
	if ev != null:
		tipo = "%s/%s" % [str(ev.get("tipo", "")), str(ev.get("resultado", ""))]
	if antes == -1 and ahora != -1:
		return "toma posesion %s" % tipo
	if antes != -1 and ahora == -1:
		return "suelta la pelota %s" % tipo
	if antes != ahora:
		return "cambia de dueno %s" % tipo
	return "en juego %s" % tipo
