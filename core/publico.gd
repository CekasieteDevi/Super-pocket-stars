class_name Publico
extends RefCounted

## Público (§8.4 #22) — "+0 a +5 según aforo × ocupación × ánimo de la
## hinchada". Simplificado a un solo número que ya integra las tres cosas:
## Team.fans (ver core/fans.gd) — 0 fans es un estadio vacío (+0), 100 es
## una hinchada a pleno (+5). Solo pesa para el LOCAL: la gente que se
## banca ir a la cancha es mayormente la de casa.
const BONUS_MAXIMO := 5.0


static func modificador(fans_local: float) -> float:
	return clamp(fans_local, 0.0, 100.0) / 100.0 * BONUS_MAXIMO
