extends SceneTree

## Que le cuesta al partido esperar al pateador designado.
##
## Estirar una pausa es lo que en su momento bajo los goles un 22% cuando
## se animaron los cambios. Se compara el MISMO partido, con la misma
## semilla, con y sin roles asignados.

const PARTIDOS := 80


func _init() -> void:
	for modo in ["sin", "mejor", "peor"]:
		var con_roles: bool = modo != "sin"
		var rng := RandomNumberGenerator.new()
		rng.seed = 31337
		var goles := 0
		var corners := 0
		var minutos := 0
		for p in range(PARTIDOS):
			var a := Team.generar("Local", rng, 0)
			var b := Team.generar("Visita", rng, 1000)
			if con_roles:
				for eq in [a, b]:
					for clave in [Roles.CORNERS, Roles.LIBRES_CERCA, Roles.LIBRES_LEJOS]:
						Roles.asignar(eq, clave, _titular(eq, clave, modo == "peor"))
			var r := MotorEspacial.simular(a, b, rng, false)
			goles += int(r["goles_local"]) + int(r["goles_visitante"])
			for ev in r.get("eventos", []):
				if str(ev.get("tipo", "")) == "corner":
					corners += 1
				minutos = maxi(minutos, int(ev.get("minuto", 0)))
		print("%-6s  goles/partido %.2f   corners/partido %.2f   minuto max %d" % [
			modo,
			float(goles) / PARTIDOS, float(corners) / PARTIDOS, minutos])
	quit()


## El mejor o el peor titular para el rol. Se miden los dos: el "peor"
## aisla el efecto de ESPERARLO, el "mejor" es lo que haria un jugador de
## verdad y es la comparacion que importa para saber si el cambio movio
## la economia del partido.
func _titular(equipo: Team, clave: String, peor: bool) -> int:
	var elegido := -1
	var limite := INF if peor else -INF
	for j in equipo.jugadores:
		if str(j["posicion"]) == "ARQ":
			continue
		var v := Roles.valor_de(j, clave)
		if (peor and v < limite) or (not peor and v > limite):
			limite = v
			elegido = int(j["id"])
	return elegido
