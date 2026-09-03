class_name Publico
extends RefCounted

## Público (§8.4 #22) — "+0 a +5 según aforo × ocupación × ánimo de la
## hinchada". Solo pesa para el LOCAL: la gente que se banca ir a la
## cancha es mayormente la de casa.
##
## Recibe el APOYO (0..1, ver Fans.apoyo) y no la cantidad de hinchas.
## Desde que la hinchada es un numero real y exponencial, el crudo no
## sirve para esto: cualquier club de primera tiene millones y saturaria
## el bonus, y cualquiera de decima tiene miles y no lo tocaria nunca.
## Lo que importa es si la hinchada es grande PARA SU CATEGORIA, que es
## justo lo que devuelve Fans.apoyo.
const BONUS_MAXIMO := 5.0


static func modificador(apoyo_local: float) -> float:
	return clamp(apoyo_local, 0.0, 1.0) * BONUS_MAXIMO
