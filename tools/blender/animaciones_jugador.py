"""
Genera y verifica las animaciones de jugador que faltaban para el partido 3D.
Uso en Blender (con jugador_chibi.blend abierto):
    exec(open(r"...animaciones_jugador.py", encoding="utf-8").read())
    construir_todas(); informe = verificar_todas()

Convencion de poses (grados; el personaje mira a -Y y su izquierda es +X):
  t/k/f + L/R : muslo (negativo = adelante), rodilla (+ dobla), pie (+ punta abajo; por defecto queda plano)
  ab + L/R    : abrir la pierna hacia afuera;  y + L/R: girar el plano de la pierna;  tw: torcer
  tp/tr/ty    : torso adelante / inclinar a su izquierda / girar el pecho a su izquierda
  hp/hr/hz    : cabeza abajo / inclinar / girar
  pitch/roll/hy: toda la cadera (adelante / a su izquierda / girar a su izquierda)
  loc=(x,y,z) : corrimiento de la cadera;  ground=1: la baja hasta que el pie mas bajo apoye
  apoyar=1    : mide la malla real y la baja/sube hasta tocar el piso (poses tiradas)
  gL/gR       : donde van las manos (IK), en el cuerpo en reposo
  bisagraL/R  : 1 (siempre, salvo =0): el codo gira solo sobre su bisagra (sin nudo en la malla)
"""
import bpy, math, os
import numpy as np
from mathutils import Vector, Quaternion, Matrix

FPS = 24
TICK = 6            # cuadros por tick del motor (0.25 s)
PISO = -0.021       # punto mas bajo en reposo (contorno incluido): es el piso


def _ctx():
    arm = bpy.data.objects['Esqueleto']; ad = arm.data
    R3 = {b.name: b.matrix_local.to_3x3() for b in ad.bones}
    return arm, ad, R3


def rx(d): return Quaternion((1, 0, 0), math.radians(d))
def ry(d): return Quaternion((0, 1, 0), math.radians(d))
def rz(d): return Quaternion((0, 0, 1), math.radians(d))


def _rise(t, k):
    return 0.5 - (0.25 * math.cos(math.radians(t)) + 0.25 * math.cos(math.radians(t + k)))


def _ik(S, T, l1, l2, pole):
    d = T - S; D = max(0.05, min(d.length, l1 + l2 - 1e-4)); dn = d.normalized()
    a = (l1 * l1 - l2 * l2 + D * D) / (2 * D); h = math.sqrt(max(l1 * l1 - a * a, 0))
    pp = pole - dn * pole.dot(dn); pp.normalize()
    return S + dn * a + pp * h, S + dn * D


def _codo_bisagra(u0, f0, S, E, Tn):
    """Codo que solo gira sobre su bisagra. La malla tiene el codo doblado 119
    grados (manos en la cintura): girando el antebrazo por el camino mas corto
    se sale del plano del codo y la malla se retuerce (se ve un nudo). Aca el
    antebrazo solo abre o cierra sobre el eje del codo en reposo, y el giro que
    falta lo hace el brazo entero desde el hombro."""
    n0 = u0.cross(f0).normalized(); phi0 = u0.angle(f0)
    e = (E - S).normalized(); t = (Tn - E).normalized(); phi = e.angle(t)
    qfo = Quaternion(n0, phi - phi0)
    f = Quaternion(n0, phi) @ u0

    def base(a, b):
        b2 = b - a * a.dot(b)
        b2 = b2.normalized() if b2.length > 1e-6 else n0.cross(a).normalized()
        return Matrix((a, b2, a.cross(b2))).transposed()
    qup = (base(e, t) @ base(u0, f).transposed()).to_quaternion()
    return qup, qfo


MANOS_REPOSO = {'L': (0.30, -0.08, 0.60), 'R': (-0.30, -0.08, 0.60)}


def pose(P):
    arm, ad, R3 = _ctx()
    g = lambda k, d=0: P.get(k, d)

    def setq(n, q):
        M = R3[n]; arm.pose.bones[n].rotation_quaternion = (M.inverted() @ q.to_matrix() @ M).to_quaternion()

    def restdir(n): return (ad.bones[n].tail_local - ad.bones[n].head_local).normalized()
    for pb in arm.pose.bones:
        pb.rotation_mode = 'QUATERNION'; pb.rotation_quaternion = (1, 0, 0, 0); pb.location = (0, 0, 0)
    for side, s in (('L', 1), ('R', -1)):
        t, k = g('t' + side), g('k' + side); f = g('f' + side, -(t + k))
        setq('Muslo.' + side, ry(-s * g('ab' + side)) @ rz(g('y' + side)) @ rx(t) @ rz(g('tw' + side)))
        setq('Pierna.' + side, rx(k)); setq('Pie.' + side, rx(f))
    loc = list(P.get('loc', (0, 0, 0)))
    if len(loc) == 2: loc = [loc[0], 0.0, loc[1]]
    if g('ground'):
        loc[2] = -min(_rise(g('tL'), g('kL')), _rise(g('tR'), g('kR'))) + g('lift')
    arm.pose.bones['Cadera'].location = R3['Cadera'].inverted() @ Vector(loc)
    setq('Cadera', ry(g('roll')) @ rx(g('pitch')) @ rz(g('hy')))
    setq('Torso', rx(g('tp')) @ ry(g('tr')) @ rz(g('ty')))
    setq('Cabeza', rz(g('hz')) @ ry(g('hr')) @ rx(g('hp')))
    for side, s in (('L', 1), ('R', -1)):
        S = ad.bones['Brazo.' + side].head_local.copy()
        T = Vector(P.get('g' + side, MANOS_REPOSO[side]))
        pole = Vector(P.get('p' + side, (s * 1.0, 0.35, -0.6)))
        E, Tn = _ik(S, T, ad.bones['Brazo.' + side].length, ad.bones['Antebrazo.' + side].length, pole)
        if g('bisagra' + side, 1):
            qup, qfo = _codo_bisagra(restdir('Brazo.' + side), restdir('Antebrazo.' + side), S, E, Tn)
        else:
            qup = restdir('Brazo.' + side).rotation_difference((E - S).normalized())
            qfo = restdir('Antebrazo.' + side).rotation_difference(qup.inverted() @ (Tn - E).normalized())
        setq('Brazo.' + side, qup); setq('Antebrazo.' + side, qfo)
    bpy.context.view_layer.update()


MALLAS = ['Cabeza', 'Pelo', 'Camiseta', 'Short', 'Botines', 'Manos', 'Guantes', 'Piernas', 'Medias', 'Mangas', 'Brazos', 'Orejas']


def min_z():
    dg = bpy.context.evaluated_depsgraph_get(); lo = 9.0; quien = ''
    for n in MALLAS:
        ob = bpy.data.objects.get(n)
        if ob is None or not ob.visible_get(): continue
        ev = ob.evaluated_get(dg); me = ev.to_mesh()
        co = np.empty(len(me.vertices) * 3); me.vertices.foreach_get('co', co); co = co.reshape(-1, 3)
        M = np.array(ev.matrix_world); z = float((co @ M[:3, :3].T + M[:3, 3])[:, 2].min()); ev.to_mesh_clear()
        if z < lo: lo, quien = z, n
    return lo, quien


def _apoyar(P):
    """Baja o sube la cadera hasta que la malla real toque el piso."""
    loc = list(P.get('loc', (0, 0, 0)))
    if len(loc) == 2: loc = [loc[0], 0.0, loc[1]]
    for _ in range(3):
        P['loc'] = tuple(loc); pose(P)
        z, _q = min_z()
        if abs(z - PISO) < 0.004: break
        loc[2] += PISO - z
    P['loc'] = tuple(loc)
    return P


def construir(nombre, claves, bucle=False):
    arm, ad, R3 = _ctx()
    arm.animation_data_create(); arm.animation_data.action = None
    viejo = bpy.data.actions.get(nombre)
    if viejo: bpy.data.actions.remove(viejo)
    act = bpy.data.actions.new(nombre); act.use_fake_user = True; arm.animation_data.action = act
    previo = {}
    for f, P in claves:
        P = dict(P)
        if P.get('apoyar'): P = _apoyar(P)
        pose(P)
        for pb in arm.pose.bones:
            q = pb.rotation_quaternion.copy()
            # continuidad de signo: evita que un hueso gire "por el camino largo"
            if pb.name in previo and previo[pb.name].dot(q) < 0: q.negate(); pb.rotation_quaternion = q
            previo[pb.name] = q
            pb.keyframe_insert('rotation_quaternion', frame=f); pb.keyframe_insert('location', frame=f)
    arm.animation_data.action = None
    return act


def _curvas(act):
    try: return list(act.fcurves)
    except AttributeError:
        out = []
        for l in act.layers:
            for st in l.strips:
                for cb in st.channelbags: out += list(cb.fcurves)
        return out


def lineal(act):
    for fc in _curvas(act):
        for k in fc.keyframe_points: k.interpolation = 'LINEAR'


# ---------------------------------------------------------------- utilidades de poses
LISTO = dict(ground=1, tL=-10, kL=25, tR=-10, kR=25, tp=8, hp=-4,
             gL=(0.33, -0.12, 0.62), gR=(-0.33, -0.12, 0.62))


def carrera(p, **extra):
    """Pose del ciclo Correr en la fase p (0..1): el mismo de Correr/Correr_Gambeta."""
    a = 2 * math.pi * p; P = dict(ground=1)
    for side, ph in (('R', a), ('L', a + math.pi)):
        t = -42 * math.sin(ph); k = 12 + 80 * max(0, math.cos(ph)) ** 1.2
        P['t' + side] = t; P['k' + side] = k; P['f' + side] = -(t + k) * 0.55 + 20 * max(0, math.cos(ph))
    P['lift'] = 0.045 * max(0, math.cos(2 * a)) - 0.02
    P.update(hy=10 * math.sin(a), tp=15 + 3 * math.cos(2 * a), ty=-18 * math.sin(a), hz=8 * math.sin(a),
             hp=-8 + 2 * math.cos(2 * a))
    sw = 55 * math.sin(a)
    for side, s, aa in (('L', 1, -sw), ('R', -1, sw)):
        up = rx(aa) @ Vector((s * 0.42, 0.05, -1)).normalized()
        # mano a ~0.5 m del hombro, adelantada por el codo doblado
        mano = Vector((s * 0.235, 0, 1.0)) + up * 0.3 + (rx(aa * 0.7) @ Vector((s * 0.18, -1.0, -0.2)).normalized()) * 0.22
        P['g' + side] = tuple(mano)
    P.update(extra)
    return P


def ciclo(p, muslo, rodilla, vuelo, torso, brazo, **extra):
    """Un ciclo de piernas como carrera() pero con otra amplitud: el trote y la
    caminata del partido. Mismo arranque (p=0, derecha pasando) que Correr:
    la vista cambia de una a otra sin cambiar de pie."""
    a = 2 * math.pi * p; P = dict(ground=1)
    for side, ph in (('R', a), ('L', a + math.pi)):
        t = -muslo * math.sin(ph); k = 8 + rodilla * max(0, math.cos(ph)) ** 1.2
        P['t' + side] = t; P['k' + side] = k
        P['f' + side] = -(t + k) * 0.55 + 20 * (rodilla / 80.0) * max(0, math.cos(ph))
    P['lift'] = vuelo * max(0, math.cos(2 * a)) - vuelo * 0.45
    r = brazo / 55.0
    P.update(hy=10 * r * math.sin(a), tp=torso + 2 * r * math.cos(2 * a), ty=-18 * r * math.sin(a), hz=8 * r * math.sin(a),
             hp=-6 + 2 * r * math.cos(2 * a))
    sw = brazo * math.sin(a)
    for side, s, aa in (('L', 1, -sw), ('R', -1, sw)):
        up = rx(aa) @ Vector((s * 0.42, 0.05, -1)).normalized()
        mano = Vector((s * 0.235, 0, 1.0)) + up * 0.3 + (rx(aa * 0.7) @ Vector((s * 0.18, -1.0, -0.2)).normalized()) * (0.12 + 0.1 * r)
        P['g' + side] = tuple(mano)
    P.update(extra)
    return P


def _mezcla(a, b, t):
    """Pose intermedia (valores numericos y manos)."""
    out = {}
    for k in set(a) | set(b):
        va, vb = a.get(k, b.get(k)), b.get(k, a.get(k))
        if isinstance(va, (int, float)) and isinstance(vb, (int, float)): out[k] = va + (vb - va) * t
        elif isinstance(va, tuple): out[k] = tuple(x + (y - x) * t for x, y in zip(va, vb))
        else: out[k] = vb if t >= 0.5 else va
    return out


# ---------------------------------------------------------------- definiciones
def espejar(P):
    """La pose del otro lado: izquierda <-> derecha (el personaje mira a -Y, su
    izquierda es +X). Cambia los parametros de cada pierna y brazo, da vuelta la X
    de manos, polos y cadera, y el signo de los giros de costado."""
    Q = {}
    for k, v in P.items():
        if len(k) >= 2 and k[-1] in 'LR' and k[:-1] in ('t', 'k', 'f', 'ab', 'y', 'tw', 'g', 'p'):
            k2 = k[:-1] + ('R' if k[-1] == 'L' else 'L')
            if k[:-1] in ('g', 'p'):
                v = (-v[0], v[1], v[2])
            elif k[:-1] in ('y', 'tw'):
                v = -v
            Q[k2] = v
        elif k in ('roll', 'tr', 'ty', 'hz', 'hr', 'hy'):
            Q[k] = -v
        elif k == 'loc':
            Q[k] = (-v[0],) + tuple(v[1:])
        else:
            Q[k] = v
    return Q


def definiciones():
    D = {}
    # CABEZAZO: 2 ticks, contacto 0.55. El salto (hasta 0.65 m) lo pone el motor.
    D['Cabecear'] = dict(ticks=2, contacto=0.55, aerea=True, hueso='Cabeza', extremo='-y', claves=[
        (1, dict(ground=1, tL=-15, kL=45, tR=-15, kR=45, tp=-12, hp=-18, gL=(0.42, 0.12, 0.85), gR=(-0.42, 0.12, 0.85))),
        (5, dict(loc=(0, 0.0, 0.0), tL=10, kL=70, tR=10, kR=70, tp=-18, hp=-20, gL=(0.6, -0.05, 1.2), gR=(-0.6, -0.05, 1.2))),
        (8, dict(loc=(0, 0.0, 0.0), tL=-5, kL=40, tR=-5, kR=40, tp=16, hp=18, gL=(0.38, 0.22, 0.75), gR=(-0.38, 0.22, 0.75))),
        (13, dict(ground=1, tL=-12, kL=35, tR=-12, kR=35, tp=6, hp=-2, gL=(0.36, -0.1, 0.62), gR=(-0.36, -0.1, 0.62))),
    ])
    # VOLEA: 3 ticks, contacto 0.375, aerea (de costado, pierna derecha alta).
    D['Volea'] = dict(ticks=3, contacto=0.375, aerea=True, hueso='Pie.R', extremo='+z', claves=[
        (1, dict(ground=1, tL=-10, kL=30, tR=45, kR=80, tr=8, gL=(0.62, -0.08, 0.95), gR=(-0.5, 0.1, 0.85))),
        (5, dict(tL=-5, kL=35, tR=-35, kR=65, abR=30, yR=-25, tr=18, ty=12, hp=0, gL=(0.62, 0.0, 0.85), gR=(-0.45, -0.2, 1.0))),
        (8, dict(tL=-5, kL=35, tR=-80, kR=5, fR=40, abR=42, tr=30, tp=-10, hp=4, gL=(0.55, 0.05, 0.75), gR=(-0.4, -0.35, 1.1))),
        (12, dict(tL=-5, kL=35, tR=-60, kR=25, abR=25, tr=15, tp=-4, gL=(0.5, 0.0, 0.75), gR=(-0.42, -0.2, 0.9))),
        (19, dict(ground=1, tL=-10, kL=30, tR=-10, kR=30, tp=6, hp=-2, gL=(0.36, -0.1, 0.62), gR=(-0.36, -0.1, 0.62))),
    ])
    # CHILENA: 5 ticks, contacto 0.35, aerea; el ultimo tick ya se levanta.
    D['Chilena'] = dict(ticks=5, contacto=0.35, aerea=True, hueso='Pie.R', extremo='+z', claves=[
        (1, dict(ground=1, tL=-10, kL=40, tR=30, kR=60, tp=-15, hp=-12, gL=(0.5, 0.0, 1.2), gR=(-0.5, 0.0, 1.2))),
        (6, dict(loc=(0, 0, 0.1), pitch=-60, tL=-80, kL=30, tR=0, kR=40, hp=20, gL=(0.66, 0.05, 0.95), gR=(-0.66, 0.05, 0.95))),
        # En el golpe la pierna derecha queda vertical (cadera -100 + muslo -80): es su punto
        # mas alto. Antes (-110/-110) pasaba por la vertical dos cuadros antes del contacto.
        (12, dict(loc=(0, 0, 0.25), pitch=-100, tL=10, kL=30, tR=-80, kR=5, fR=30, hp=25, gL=(0.7, 0.1, 0.9), gR=(-0.7, 0.1, 0.9))),
        (18, dict(loc=(0, 0, 0.0), pitch=-95, tL=-40, kL=40, tR=-20, kR=40, hp=28, gL=(0.55, 0.4, 0.8), gR=(-0.55, 0.4, 0.8))),
        (24, dict(apoyar=1, pitch=-80, tL=-50, kL=60, tR=-45, kR=55, hp=32, gL=(0.6, 0.25, 0.7), gR=(-0.6, 0.25, 0.7))),
        (31, dict(apoyar=1, pitch=-35, tL=-80, kL=110, tR=-75, kR=105, tp=10, hp=5, gL=(0.4, 0.35, 0.6), gR=(-0.4, 0.35, 0.6))),
    ])
    # PALOMITA: 4 ticks, contacto 0.375, aerea; termina tirado boca abajo.
    # En la palomita el golpe es cuando el cuerpo queda horizontal, no cuando la cabeza esta mas alta.
    D['Palomita'] = dict(ticks=4, contacto=0.375, aerea=True, hueso='Cabeza', extremo='horizontal', claves=[
        (1, dict(ground=1, tL=-20, kL=50, tR=20, kR=40, tp=25, hp=-18, gL=(0.4, 0.25, 0.8), gR=(-0.4, 0.25, 0.8))),
        (6, dict(pitch=45, tL=30, kL=10, tR=40, kR=15, hp=-50, gL=(0.5, -0.4, 1.1), gR=(-0.5, -0.4, 1.1))),
        (10, dict(pitch=80, tL=10, kL=5, tR=15, kR=10, hp=-80, gL=(0.6, -0.35, 0.95), gR=(-0.6, -0.35, 0.95))),
        (18, dict(pitch=85, tL=10, kL=10, tR=12, kR=12, hp=-82, gL=(0.5, -0.5, 1.0), gR=(-0.5, -0.5, 1.0))),
        (25, dict(apoyar=1, pitch=88, tL=8, kL=8, tR=8, kR=10, hp=-84, gL=(0.45, -0.45, 1.1), gR=(-0.45, -0.45, 1.1))),
    ])
    # PECHO: 3 ticks, contacto 0 (la pelota llega al empezar) y amortigua.
    D['Pecho'] = dict(ticks=3, contacto=0.0, aerea=False, hueso='Torso', extremo='+y', claves=[
        (1, dict(ground=1, tL=-8, kL=20, tR=-8, kR=20, tp=-20, hp=-2, gL=(0.66, -0.05, 0.95), gR=(-0.66, -0.05, 0.95))),
        (7, dict(ground=1, tL=-12, kL=40, tR=-12, kR=40, tp=-10, hp=4, gL=(0.56, -0.1, 0.8), gR=(-0.56, -0.1, 0.8))),
        (13, dict(ground=1, tL=-10, kL=30, tR=-10, kR=30, tp=5, hp=8, gL=(0.42, -0.1, 0.65), gR=(-0.42, -0.1, 0.65))),
        (19, dict(LISTO)),
    ])
    # TACO: 2 ticks, contacto 0.5. Exagerado para que se lea de lejos: pasa la
    # pierna por arriba de la pelota, el talon sale fuerte para atras (cuerpo
    # adelante, mira por arriba del hombro) y termina con el talon arriba.
    D['Taco'] = dict(ticks=2, contacto=0.5, aerea=False, hueso='Pie.R', extremo='+y', claves=[
        (1, dict(LISTO)),
        (3, dict(ground=1, tL=-12, kL=32, tR=-60, kR=50, fR=15, tp=-2, hp=-2, gL=(0.55, -0.05, 0.85), gR=(-0.55, -0.05, 0.85))),
        (5, dict(ground=1, tL=-10, kL=34, tR=-10, kR=45, tp=18, hz=-20, hp=-4, gL=(0.6, -0.1, 0.9), gR=(-0.6, 0.1, 0.9))),
        (7, dict(ground=1, tL=-8, kL=38, tR=50, kR=55, fR=-30, tp=34, hz=-40, hp=-10, gL=(0.68, -0.2, 1.0), gR=(-0.6, 0.25, 0.95))),
        (9, dict(ground=1, tL=-8, kL=38, tR=62, kR=115, fR=-20, tp=36, hz=-45, hp=-10, gL=(0.68, -0.2, 1.02), gR=(-0.6, 0.3, 1.0))),
        (13, dict(LISTO)),
    ])
    # AMAGUE DE CENTRO: 3 ticks. Arma la pierna como para centrar, frena y engancha.
    D['Amague'] = dict(ticks=3, contacto=None, aerea=False, claves=[
        (1, dict(ground=1, tL=-15, kL=30, tR=30, kR=60, ty=-10, gL=(0.6, -0.1, 0.9), gR=(-0.4, 0.2, 0.8))),
        (6, dict(ground=1, tL=-18, kL=34, tR=65, kR=105, ty=-18, tr=-10, hp=4, gL=(0.66, -0.12, 1.0), gR=(-0.5, 0.3, 0.95))),
        (10, dict(ground=1, tL=-15, kL=34, tR=-35, kR=75, fR=10, ty=18, hp=4, gL=(0.55, -0.1, 0.85), gR=(-0.45, -0.15, 0.8))),
        (14, dict(ground=1, tL=15, kL=40, tR=-10, kR=35, hy=20, ty=10, tp=12, gL=(0.4, -0.1, 0.72), gR=(-0.42, -0.1, 0.72))),
        (19, carrera(0.0)),
    ])
    # CROQUETA: 4 ticks. Pelota del pie derecho al izquierdo (fase 0.30-0.66).
    D['Regate_Croqueta'] = dict(ticks=4, contacto=None, aerea=False, regate='croqueta', claves=[
        (1, carrera(0.75)),
        (7, dict(ground=1, tL=-8, kL=30, tR=-15, kR=20, abR=15, fR=-5, tr=4, tp=12, hp=4, gL=(0.5, -0.1, 0.8), gR=(-0.5, -0.1, 0.8))),
        (11, dict(ground=1, tL=-5, kL=32, tR=-22, kR=22, abR=-8, yR=25, tr=0, tp=12, hp=5, gL=(0.52, -0.1, 0.82), gR=(-0.5, -0.1, 0.78))),
        (15, dict(ground=1, tL=-22, kL=22, abL=-8, yL=-25, tR=-5, kR=32, tr=-5, tp=12, hp=5, gL=(0.5, -0.1, 0.78), gR=(-0.52, -0.1, 0.82))),
        (18, dict(ground=1, tL=-30, kL=25, yL=-20, tR=5, kR=35, tr=-4, tp=14, hp=3, gL=(0.45, -0.12, 0.75), gR=(-0.48, -0.08, 0.78))),
        (25, carrera(0.25)),
    ])
    # BICICLETA: 6 ticks. Dos pasadas por delante de la pelota (2/12-9/12) y sale.
    # La pelota mide lo que la pierna del chibi: no se puede pasar "por arriba".
    # Cada pasada es un circulo grande (entra por adentro, pasa por delante y
    # sale bien abierta), con el cuerpo que se hamaca y los brazos abiertos.
    def pasada(lado, etapa):
        s = 1 if lado == 'R' else -1
        o = 'L' if lado == 'R' else 'R'
        if etapa == 0:    # levanta y cruza por adentro
            P = {'t' + lado: -70, 'k' + lado: 100, 'ab' + lado: -35, 't' + o: -10, 'k' + o: 45}
            P.update(roll=-8 * s, tr=8 * s, ty=14 * s, loc=(0.05 * s, 0, 0))
        elif etapa == 1:  # por delante de la pelota, arriba
            P = {'t' + lado: -88, 'k' + lado: 72, 'ab' + lado: 25, 't' + o: -10, 'k' + o: 48}
            P.update(roll=-2 * s, tr=0, ty=20 * s, loc=(0.02 * s, 0, 0))
        else:             # sale por afuera y apoya abierto
            P = {'t' + lado: -25, 'k' + lado: 35, 'ab' + lado: 60, 't' + o: -8, 'k' + o: 40}
            P.update(roll=10 * s, tr=-12 * s, ty=10 * s, loc=(-0.06 * s, 0, 0))
        alto, bajo = 0.92, 0.8
        P.update(ground=1, tp=14, hp=8, gL=(0.62, -0.08, alto if s < 0 else bajo),
                 gR=(-0.62, -0.08, alto if s > 0 else bajo))
        return P
    D['Regate_Bicicleta'] = dict(ticks=6, contacto=None, aerea=False, regate='bicicleta', claves=[
        (1, carrera(0.75)),
        (7, dict(LISTO, tp=14, hp=8, kL=35, kR=35)),
        (10, pasada('R', 0)), (13, pasada('R', 1)), (16, pasada('R', 2)),
        (19, pasada('L', 0)), (22, pasada('L', 1)), (25, pasada('L', 2)),
        (28, dict(ground=1, tL=-25, kL=20, abL=5, fL=10, tR=10, kR=40, tp=15, hp=2, gL=(0.5, -0.1, 0.8), gR=(-0.55, -0.1, 0.8))),
        (37, carrera(0.25)),
    ])
    # RULETA: 6 ticks. Vuelta completa (2/12-9/12) pisando la pelota con cada pie.
    rul = [(1, carrera(0.75)), (7, dict(LISTO, tp=10, hp=6))]
    pasos = [(9, dict(tR=-25, kR=30, fR=-25, tL=-5, kL=30)), (14, dict(tR=5, kR=40, tL=-8, kL=30)),
             (17, dict(tR=-5, kR=30, tL=-5, kL=30)), (20, dict(tL=-25, kL=30, fL=-25, tR=-5, kR=30)),
             (25, dict(tL=5, kL=40, tR=-8, kR=30)), (28, dict(tL=-8, kL=30, tR=-10, kR=30))]
    for f, piernas in pasos:
        g = (f - 7) / 21.0
        P = dict(ground=1, hy=-360 * g, tp=10, hp=6, gL=(0.55, -0.05, 0.85), gR=(-0.55, -0.05, 0.85)); P.update(piernas)
        rul.append((f, P))
    rul.append((37, carrera(0.25)))
    D['Regate_Ruleta'] = dict(ticks=6, contacto=None, aerea=False, regate='ruleta', claves=rul)
    # GLOBITO: 8 ticks. Corre, levanta la pelota con la punta (4/12), la mira pasar y la busca.
    glo = [(f, carrera((f - 1) / 12.0)) for f in (1, 4, 7, 10, 13)]
    glo += [(17, dict(ground=1, tL=-10, kL=30, tR=-40, kR=20, fR=-30, tp=5, hp=0, gL=(0.5, -0.1, 0.8), gR=(-0.5, -0.1, 0.8))),
            (22, dict(ground=1, tL=-8, kL=28, tR=-55, kR=15, fR=-20, tp=-5, hp=-22, gL=(0.55, -0.1, 0.9), gR=(-0.55, -0.1, 0.9))),
            (29, carrera(0.0, hp=-14))]
    glo += [(f, carrera((f - 29) / 12.0)) for f in (32, 35, 38, 41, 44, 47)] + [(49, carrera(20 / 12.0))]
    D['Regate_Globito'] = dict(ticks=8, contacto=None, aerea=False, regate='globito', claves=glo)
    # ELASTICA: 3 ticks. Con el exterior la saca bien afuera (fase 0.4), con el
    # interior la cruza al otro lado (0.6) y sigue. El cuerpo se tira fuerte para
    # cada lado. La pelota va por elastica_3d() (VistaCancha3D.elastica_3d): la
    # del 2D se iba a 0.9 m del pie.
    # Exagerada para que se lea de lejos: amaga con todo el cuerpo (se inclina y
    # mira para afuera) y la MISMA pierna derecha cambia de direccion.
    der = dict(gL=(0.66, -0.05, 1.0), gR=(-0.45, -0.12, 0.74))
    izq = dict(gL=(0.45, -0.12, 0.74), gR=(-0.66, -0.05, 1.0))
    D['Regate_Elastica'] = dict(ticks=3, contacto=None, aerea=False, regate='elastica_3d', claves=[
        (1, carrera(0.75)),
        (5, dict(ground=1, tL=-8, kL=40, tR=-35, kR=35, abR=35, yR=-25, roll=-9, tr=-14, ty=-14, hz=-15, tp=10, hp=-6, loc=(-0.04, 0, 0), **der)),
        (8, dict(ground=1, tL=-8, kL=45, tR=-40, kR=28, abR=62, yR=-40, roll=-14, tr=-22, ty=-18, hz=-20, tp=10, hp=-6, loc=(-0.08, 0, 0), **der)),
        (11, dict(ground=1, tL=-8, kL=45, tR=-45, kR=30, abR=-40, yR=45, roll=14, tr=22, ty=18, hz=20, tp=10, hp=-6, loc=(0.08, 0, 0), **izq)),
        (14, dict(ground=1, tL=-30, kL=35, abL=15, tR=5, kR=45, roll=8, tr=12, ty=10, hz=10, tp=12, hp=-2, loc=(0.06, 0, 0), **izq)),
        (19, carrera(0.25)),
    ])
    # BARRIDA: 3 ticks; desliza sobre la cadera izquierda y el ultimo tick se levanta.
    D['Barrida'] = dict(ticks=3, contacto=None, aerea=False, claves=[
        (1, carrera(0.0)),
        (5, dict(apoyar=1, roll=70, pitch=-25, tL=-85, kL=5, fL=10, tR=-30, kR=80, hp=-10, hr=-30,
                 gL=(0.5, 0.35, 0.7), gR=(-0.5, -0.1, 1.2))),
        (10, dict(apoyar=1, roll=72, pitch=-22, tL=-88, kL=5, fL=10, tR=-32, kR=82, hp=-10, hr=-32,
                  gL=(0.5, 0.35, 0.7), gR=(-0.5, -0.1, 1.2))),
        (13, dict(apoyar=1, roll=35, pitch=-5, tL=-60, kL=110, tR=-50, kR=90, tp=15, hp=-2, hr=-12,
                  gL=(0.45, 0.2, 0.5), gR=(-0.45, -0.1, 0.8))),
        (19, dict(ground=1, tL=-30, kL=70, tR=-25, kR=65, tp=20, hp=-8, gL=(0.4, -0.2, 0.6), gR=(-0.4, -0.2, 0.6))),
    ])
    # BLOQUEO: 3 ticks; estira la pierna al costado con los brazos atras, y vuelve.
    D['Bloquear'] = dict(ticks=3, contacto=None, aerea=False, claves=[
        (1, dict(LISTO)),
        (6, dict(ground=1, tL=-5, kL=50, tR=-50, kR=5, fR=0, abR=30, ty=20, tp=10, hp=-4,
                 gL=(0.12, 0.3, 0.7), gR=(-0.12, 0.3, 0.7))),
        (13, dict(ground=1, tL=-8, kL=40, tR=-15, kR=30, abR=10, ty=8, tp=10, hp=-4, gL=(0.3, 0.1, 0.65), gR=(-0.3, 0.1, 0.65))),
        (19, dict(LISTO)),
    ])
    # CAIDA: 5 ticks; trastabilla, se tira de frente y queda PANZA AL PISO con la
    # cabeza levantada (la cabeza chibi mide 0.83: agachada levantaba el cuerpo
    # 0.5 m y se veia flotando sobre un brazo). Despues se arrodilla y se para.
    cod = dict(pL=(1, -0.3, -0.8), pR=(-1, -0.3, -0.8))
    tirado = dict(apoyar=1, pitch=90, tp=-15, hp=-95, tL=4, kL=8, tR=6, kR=40,
                  gL=(0.5, -0.3, 1.3), gR=(-0.5, -0.3, 1.3), **cod)
    D['Caer'] = dict(ticks=5, contacto=None, aerea=False, claves=[
        (1, dict(ground=1, tL=-20, kL=30, tR=35, kR=70, tp=30, hp=-15, gL=(0.45, -0.45, 0.95), gR=(-0.45, -0.45, 0.95))),
        (5, dict(apoyar=1, pitch=50, tL=-5, kL=20, tR=30, kR=50, tp=10, hp=-45, gL=(0.4, -0.55, 1.1), gR=(-0.4, -0.55, 1.1))),
        (9, dict(tirado)),
        (12, dict(tirado, tp=-19, kR=32, hp=-98)),   # asienta: camiseta y short en el piso
        (18, dict(tirado)),
        (23, dict(apoyar=1, pitch=55, tp=10, hp=-40, tL=-60, kL=110, tR=-55, kR=110, gL=(0.35, -0.55, 0.75), gR=(-0.35, -0.55, 0.75))),
        (27, dict(apoyar=1, pitch=10, tp=15, hp=-10, tL=-10, kL=95, tR=-80, kR=90, gL=(0.3, -0.3, 0.55), gR=(-0.3, -0.3, 0.55))),
        (31, dict(LISTO)),
    ])
    # LESIONADO: 8 ticks; se agarra la rodilla derecha, cae de costado y queda en el piso.
    rod = dict(gL=(0.02, -0.32, 0.45), gR=(-0.14, -0.3, 0.42), pL=(1, -0.2, 0.3), pR=(-1, -0.2, 0.3))
    D['Lesionado'] = dict(ticks=8, contacto=None, aerea=False, claves=[
        (1, dict(ground=1, tL=-5, kL=25, tR=-20, kR=70, tp=15, hp=4, gL=(0.0, -0.28, 0.58), gR=(-0.2, -0.25, 0.55))),
        (8, dict(apoyar=1, roll=-55, pitch=15, tL=-30, kL=50, tR=-50, kR=90, tp=10, hp=0, hr=20, **rod)),
        (14, dict(apoyar=1, roll=-85, tL=-70, kL=100, tR=-80, kR=110, tp=15, hp=5, hr=35, **rod)),
        (24, dict(apoyar=1, roll=-40, pitch=-55, tL=-75, kL=100, tR=-85, kR=110, tp=20, hp=18, hr=10, **rod)),
        (34, dict(apoyar=1, roll=-82, tL=-72, kL=100, tR=-80, kR=110, tp=15, hp=5, hr=34, **rod)),
        (49, dict(apoyar=1, roll=-84, tL=-70, kL=100, tR=-80, kR=110, tp=15, hp=5, hr=35, **rod)),
    ])
    # LATERAL: prepara (levanta la pelota) y saca (suelta en 0.25). La cabeza chibi no
    # deja pasar la pelota por arriba: se sostiene adelante de la frente.
    D['Lateral_Prepara'] = dict(ticks=3, contacto=None, aerea=False, claves=[
        (1, dict(ground=1, tL=-5, kL=15, tR=-5, kR=15, tp=4, hp=0, gL=(0.13, -0.36, 0.95), gR=(-0.13, -0.36, 0.95))),
        (10, dict(ground=1, tL=-5, kL=15, tR=-5, kR=15, tp=-8, hp=-6, gL=(0.15, -0.58, 1.22), gR=(-0.15, -0.58, 1.22))),
        (19, dict(ground=1, tL=-5, kL=18, tR=-5, kR=18, tp=-16, hp=-8, gL=(0.14, -0.62, 1.28), gR=(-0.14, -0.62, 1.28))),
    ])
    D['Lateral'] = dict(ticks=2, contacto=0.25, aerea=False, hueso='Antebrazo.L', extremo='-y', claves=[
        (1, dict(ground=1, tL=-5, kL=18, tR=-5, kR=18, tp=-16, hp=-8, gL=(0.14, -0.62, 1.28), gR=(-0.14, -0.62, 1.28))),
        (4, dict(ground=1, tL=-5, kL=18, tR=-5, kR=18, tp=14, hp=-4, gL=(0.14, -0.66, 1.1), gR=(-0.14, -0.66, 1.1))),
        (8, dict(ground=1, tL=-5, kL=22, tR=-5, kR=22, tp=24, hp=-2, gL=(0.14, -0.5, 0.9), gR=(-0.14, -0.5, 0.9))),
        (13, dict(LISTO)),
    ])
    # FESTEJO: loop de 0.5 s, brazos arriba. El motor pone los saltitos.
    arriba = dict(ground=1, tL=-5, kL=20, tR=-5, kR=20, tp=-8, hp=-12, gL=(0.58, -0.08, 1.45), gR=(-0.58, -0.08, 1.45))
    abajo = dict(ground=1, tL=-8, kL=32, tR=-8, kR=32, tp=-4, hp=-10, gL=(0.5, -0.2, 1.12), gR=(-0.5, -0.2, 1.12))
    D['Festejar'] = dict(ticks=2, contacto=None, aerea=False, bucle=True, claves=[
        (1, arriba), (4, abajo), (7, arriba), (10, abajo), (13, arriba)])
    # ATAJAR VOLANDO (arquero): 4 ticks, estirado del todo en 10/23 (el contacto de
    # VistaCancha3D). Se impulsa, vuela de costado hacia su derecha con los guantes
    # hacia la pelota (la cabeza chibi es mas larga que el brazo: no puede pasarla
    # por arriba, los brazos van adelante de la cara) y queda tirado.
    guardia_v = dict(ground=1, tL=-25, kL=50, tR=-25, kR=50, abL=8, abR=8, tp=18, hp=-12, gL=(0.3, -0.35, 0.8), gR=(-0.3, -0.35, 0.8))
    estira = dict(gL=(0.02, -0.46, 1.36), gR=(-0.2, -0.44, 1.3), pL=(1, 0.6, -0.2), pR=(-1, 0.6, -0.2))
    D['Atajar_Volando'] = dict(ticks=4, contacto=None, aerea=False, claves=[
        (1, dict(guardia_v)),
        (5, dict(ground=1, tL=-15, kL=35, tR=-45, kR=80, abR=20, roll=-15, tp=15, hp=-10, tr=-15, loc=(-0.15, 0, 0), gL=(0.2, -0.4, 1.1), gR=(-0.35, -0.4, 1.15))),
        (8, dict(roll=-60, tL=10, kL=15, tR=5, kR=10, abL=10, tr=-10, hp=-5, hr=-10, loc=(-0.6, 0, 0.35), **estira)),
        (11, dict(roll=-85, tL=5, kL=5, tR=0, kR=5, abL=8, tr=-5, hp=0, hr=-15, loc=(-1.05, 0, 0.3), **estira)),
        (13, dict(roll=-88, tL=8, kL=10, tR=4, kR=10, tr=-5, hp=0, hr=-15, loc=(-1.2, 0, 0.2), **estira)),
        (16, dict(apoyar=1, roll=-88, tL=-10, kL=30, tR=-15, kR=40, tp=5, hp=0, hr=-10, loc=(-1.3, 0, 0),
                  gL=(0.1, -0.4, 1.25), gR=(-0.15, -0.4, 1.2), pL=(1, 0.6, -0.2), pR=(-1, 0.6, -0.2))),
        (25, dict(apoyar=1, roll=-85, tL=-20, kL=45, tR=-25, kR=55, tp=10, hp=5, hr=-10, loc=(-1.3, 0, 0),
                  gL=(0.25, -0.35, 1.0), gR=(-0.1, -0.35, 1.05), pL=(1, 0.6, -0.2), pR=(-1, 0.6, -0.2))),
    ])
    # --- PELOTA PARADA Y OFICIALES -------------------------------------------------
    # El brazo del chibi llega a ~1.45 de alto y la cabeza a 1.95: derecho para
    # arriba queda tapado por el pelo. "Arriba" es en diagonal, afuera de la cabeza;
    # el tablero va adelante del pecho.
    # BARRERA: loop de 1 s. Pies juntos, manos cruzadas adelante, se acomoda.
    barrera = dict(ground=1, tL=-4, kL=10, tR=-4, kR=10, abL=-3, abR=-3, tp=6, hp=-3,
                   gL=(-0.06, -0.2, 0.5), gR=(0.06, -0.22, 0.52), pL=(1, -0.3, -0.6), pR=(-1, -0.3, -0.6))
    D['Barrera'] = dict(ticks=4, contacto=None, aerea=False, bucle=True, claves=[
        (1, dict(barrera)), (13, dict(barrera, tp=3, hp=-1, kL=14, kR=14, gL=(-0.06, -0.2, 0.53), gR=(0.06, -0.22, 0.55))),
        (25, dict(barrera))])
    # BARRERA_SALTO: 3 ticks. Se agacha, salta con las manos en su lugar y cae.
    D['Barrera_Salto'] = dict(ticks=3, contacto=None, aerea=False, claves=[
        (1, dict(barrera)),
        (4, dict(barrera, tL=-35, kL=60, tR=-35, kR=60, tp=15)),
        (9, dict(barrera, ground=0, tL=-8, kL=25, tR=-8, kR=25, tp=-4, hp=-6, loc=(0, 0, 0.4))),
        (13, dict(barrera, tL=-30, kL=55, tR=-30, kR=55, tp=12)),
        (19, dict(barrera))])
    # LEVANTAR_BRAZO: 2 ticks. El que patea el corner avisa la jugada.
    D['Levantar_Brazo'] = dict(ticks=2, contacto=None, aerea=False, claves=[
        (1, dict(LISTO)),
        (7, dict(ground=1, tL=-6, kL=14, tR=-6, kR=14, tp=0, hp=-10, tr=-6,
                 gL=(0.34, -0.1, 0.58), gR=(-0.55, -0.1, 1.3), pR=(-1, 0.3, -0.2))),
        (13, dict(ground=1, tL=-6, kL=14, tR=-6, kR=14, tp=0, hp=-10, tr=-6,
                  gL=(0.34, -0.1, 0.58), gR=(-0.56, -0.08, 1.31), pR=(-1, 0.3, -0.2)))])
    # TARJETA (arbitro): 2 ticks. Mano al bolsillo de atras y el brazo bien arriba.
    parado_of = dict(ground=1, tL=-4, kL=8, tR=-4, kR=8, tp=2, hp=-4)
    D['Tarjeta'] = dict(ticks=2, contacto=None, aerea=False, claves=[
        (1, dict(parado_of, gL=(0.36, -0.03, 0.54), gR=(-0.36, -0.03, 0.54))),
        (5, dict(parado_of, tr=4, gL=(0.36, -0.05, 0.55), gR=(-0.22, 0.2, 0.55), pR=(-1, 0.6, 0.0))),
        (9, dict(parado_of, tr=-4, hp=-8, gL=(0.4, -0.12, 0.6), gR=(-0.5, -0.15, 1.15), pR=(-1, 0.3, -0.2))),
        (13, dict(parado_of, tr=-6, hp=-10, gL=(0.42, -0.14, 0.62), gR=(-0.56, -0.08, 1.31), pR=(-1, 0.3, -0.2)))])
    # TARJETA_COMPLETA (arbitro): 10 ticks. Saca la tarjeta del bolsillo de atras,
    # la muestra con el brazo arriba (la sostiene), la baja y la guarda. La tarjeta
    # se ve en la mano entre TARJETA_EN_MANO (VistaCancha3D) = cuadros 10 y 50.
    tarj_arriba = dict(parado_of, tr=-6, hp=-10, gL=(0.42, -0.14, 0.62), gR=(-0.56, -0.08, 1.31), pR=(-1, 0.3, -0.2))
    D['Tarjeta_Completa'] = dict(ticks=10, contacto=None, aerea=False, claves=[
        (1, dict(parado_of, gL=(0.36, -0.03, 0.54), gR=(-0.36, -0.03, 0.54))),
        (6, dict(parado_of, tr=4, gL=(0.36, -0.05, 0.55), gR=(-0.22, 0.2, 0.55), pR=(-1, 0.6, 0.0))),
        (10, dict(parado_of, tr=2, gL=(0.36, -0.05, 0.56), gR=(-0.3, -0.3, 0.8), pR=(-1, 0.3, -0.3))),
        (16, dict(tarj_arriba)),
        (40, dict(tarj_arriba, tr=-8, gR=(-0.57, -0.1, 1.32))),
        (46, dict(parado_of, tr=0, gL=(0.38, -0.08, 0.58), gR=(-0.3, -0.3, 0.8), pR=(-1, 0.3, -0.3))),
        (52, dict(parado_of, tr=4, gL=(0.36, -0.05, 0.55), gR=(-0.22, 0.2, 0.55), pR=(-1, 0.6, 0.0))),
        (61, dict(parado_of, gL=(0.36, -0.03, 0.54), gR=(-0.36, -0.03, 0.54)))])
    # BANDERA_ARRIBA (asistente, offside): 5 ticks. Se frena, sube el brazo,
    # sacude la bandera y la deja quieta. Antes subia en un cuarto de segundo y no se notaba.
    # El brazo casi estirado en diagonal hacia afuera (derecho arriba choca con
    # la cabeza), el codo hacia abajo y bisagraR: el codo solo gira sobre su
    # eje. Con el IK comun el antebrazo se salia del plano del codo y la malla
    # se retorcia (nudo). La mano va sobre un arco alrededor del hombro: al
    # sacudir no cambia el codo. A 60 grados y en el plano del cuerpo: mas
    # cerca de la vertical o hacia adelante, desde la camara del partido el
    # antebrazo pasaba por delante de la cara.
    def mano_arriba(grados, y=0.0, r=0.51):
        a = math.radians(grados)
        return (-0.235 - r * math.sin(a), y, 1.0 + r * math.cos(a))
    def bandera_arriba(grados, lado=0.0):
        return dict(parado_of, bisagraR=1, tr=-6 - 3 * lado, hp=-10, roll=2 * lado, gL=(0.36, -0.03, 0.56),
                    gR=mano_arriba(60 + grados), pR=(-0.3, 0.3, -1))
    D['Bandera_Arriba'] = dict(ticks=5, contacto=None, aerea=False, claves=[
        (1, dict(parado_of, gL=(0.36, -0.03, 0.54), gR=(-0.38, -0.08, 0.56))),
        (5, dict(parado_of, bisagraR=1, tr=-3, hp=-4, gL=(0.36, -0.03, 0.55), gR=mano_arriba(100, -0.2, 0.44), pR=(-0.3, 0.3, -1))),
        (10, bandera_arriba(0.0, 1.0)),
        (13, bandera_arriba(-6, 1.0)), (16, bandera_arriba(5, 1.0)),
        (19, bandera_arriba(-6, 1.0)), (22, bandera_arriba(5, 1.0)),
        (26, bandera_arriba(0.0, 0.5)), (31, bandera_arriba(0.0, 0.5))])
    # BANDERA_HORIZONTAL (asistente, lateral/corner/saque): 2 ticks. Señala al costado.
    D['Bandera_Horizontal'] = dict(ticks=2, contacto=None, aerea=False, claves=[
        (1, dict(parado_of, gL=(0.36, -0.03, 0.54), gR=(-0.38, -0.08, 0.56))),
        (7, dict(parado_of, tr=-8, hz=-20, gL=(0.36, -0.03, 0.56), gR=(-0.68, -0.05, 1.0), pR=(0, 1, -0.3))),
        (13, dict(parado_of, tr=-8, hz=-20, gL=(0.36, -0.03, 0.56), gR=(-0.68, -0.05, 1.0), pR=(0, 1, -0.3)))])
    # TABLERO (cuarto arbitro, cambios): 2 ticks. El tablero arriba con las dos manos.
    # El tablero sobre la cabeza, como en la tele: los dos brazos arriba en V,
    # casi derechos, con el codo en bisagra (sin nudo). El brazo del chibi no
    # llega arriba de la cabeza: el tablero (juego) tiene mangos cortos desde
    # las manos. A 45 grados las manos asoman por fuera del pelo desde atras.
    def manos_tablero(grados, r=0.52):
        a = math.radians(grados)
        return dict(bisagraL=1, bisagraR=1, pL=(0.3, 0.3, -1), pR=(-0.3, 0.3, -1),
                    gL=(0.235 + r * math.sin(a), 0.0, 1.0 + r * math.cos(a)),
                    gR=(-0.235 - r * math.sin(a), 0.0, 1.0 + r * math.cos(a)))
    D['Tablero'] = dict(ticks=2, contacto=None, aerea=False, claves=[
        (1, dict(parado_of, gL=(0.36, -0.03, 0.54), gR=(-0.36, -0.03, 0.54))),
        (4, dict(parado_of, **manos_tablero(95, 0.44))),
        (8, dict(parado_of, **manos_tablero(45))),
        (13, dict(parado_of, **manos_tablero(45)))])
    # ATAJAR VOLANDO A SU IZQUIERDA: la misma estirada, espejada (antes se espejaba el
    # modelo entero en el juego y el lado salia mal).
    D['Atajar_Volando_Izq'] = dict(D['Atajar_Volando'], claves=[(f, espejar(P)) for f, P in D['Atajar_Volando']['claves']])
    # REMATE CON EFECTO (derecha, cara interna): 2 ticks como Patear_Corriendo
    # y el golpe en el mismo lugar (4/11), asi cae en el contacto del motor.
    # Apoya la izquierda al costado de la pelota, la derecha sale de atras con
    # el pie abierto (el interno de frente a la pelota), la envuelve y termina
    # cruzada adelante, con la cadera girada y los brazos abiertos.
    ef_brazos = dict(gL=(0.62, -0.2, 0.95), gR=(-0.5, 0.18, 0.8))
    D['Remate_Efecto'] = dict(ticks=2, contacto=4.0 / 11.0, aerea=False, hueso='Pie.R', extremo='-y', claves=[
        (1, dict(ground=1, tL=-18, kL=28, tR=48, kR=88, fR=25, yR=-20, abR=16, ty=-12, tp=-4, tr=-6, hp=-10, **ef_brazos)),
        (3, dict(ground=1, tL=-10, kL=30, tR=22, kR=70, fR=15, yR=-40, abR=12, hy=-4, ty=-8, tp=-2, tr=-8, hp=-12, **ef_brazos)),
        (5, dict(ground=1, tL=-8, kL=32, tR=-44, kR=10, fR=8, yR=-50, abR=4, hy=8, ty=4, tp=4, tr=-8, hp=-14,
                 gL=(0.64, -0.1, 0.98), gR=(-0.5, 0.05, 0.85))),
        (8, dict(ground=1, tL=-8, kL=30, tR=-45, kR=30, fR=5, yR=-40, abR=-32, hy=24, ty=10, tp=2, tr=-4, hp=-6,
                 gL=(0.5, 0.15, 0.9), gR=(-0.45, -0.3, 0.9))),
        (13, dict(ground=1, tL=-6, kL=26, tR=-15, kR=40, yR=-15, abR=-10, hy=10, ty=5, tp=6, hp=-4,
                  gL=(0.42, 0.05, 0.7), gR=(-0.4, -0.15, 0.72))),
    ])
    # SE ACOMODA PARA EL EFECTO: 3 ticks antes del remate. Dos pasos cortos
    # frenando, abre los brazos, mira el arco y baja la vista a la pelota;
    # termina en la pose del primer cuadro de Remate_Efecto.
    D['Efecto_Acomoda'] = dict(ticks=3, contacto=None, aerea=False, claves=[
        (1, carrera(0.0)),
        (6, dict(ground=1, tL=-25, kL=30, tR=22, kR=55, fR=10, hy=-6, ty=-6, tp=10, hp=6, gL=(0.5, -0.1, 0.8), gR=(-0.45, 0.1, 0.75))),
        (11, dict(ground=1, tL=18, kL=50, tR=-20, kR=28, hy=-8, ty=-8, tp=6, hp=4, gL=(0.56, -0.15, 0.88), gR=(-0.48, 0.12, 0.78))),
        (15, dict(ground=1, tL=-12, kL=30, tR=30, kR=65, fR=15, yR=-12, abR=10, hy=-4, ty=-10, tp=0, tr=-4, hp=-8, **ef_brazos)),
        (19, dict(D['Remate_Efecto']['claves'][0][1])),
    ])
    # TROTAR y CAMINAR: los pasos del partido por debajo del pique. Antes todo
    # era Correr con la zancada achicada y a 2 m/s parecia un pique en camara
    # lenta. Loops de 4 ticks; la vista los avanza con los metros recorridos.
    def loop_de(f, n=8, **kw):
        return [(1 + i * 3, f(i / n, **kw)) for i in range(n + 1)]
    D['Trotar'] = dict(ticks=4, contacto=None, aerea=False, bucle=True,
                       claves=loop_de(lambda p: ciclo(p, muslo=30, rodilla=58, vuelo=0.025, torso=9, brazo=40)))
    D['Caminar'] = dict(ticks=4, contacto=None, aerea=False, bucle=True,
                        claves=loop_de(lambda p: ciclo(p, muslo=19, rodilla=24, vuelo=0.0, torso=3, brazo=20)))
    # FORCEJEAR: corre hombro con hombro con el rival que tiene a su derecha:
    # se inclina hacia el, el brazo derecho abierto contra su cuerpo y mira
    # la pelota. La de la izquierda es la misma espejada.
    def forcejeo(p):
        P = ciclo(p, muslo=30, rodilla=58, vuelo=0.02, torso=10, brazo=30)
        P.update(tr=-9, hz=-12, gR=(-0.66, -0.02, 0.9), pR=(-0.3, 0.3, -1))
        return P
    D['Forcejear'] = dict(ticks=4, contacto=None, aerea=False, bucle=True, claves=loop_de(forcejeo))
    D['Forcejear_Izq'] = dict(D['Forcejear'], claves=[(f, espejar(P)) for f, P in D['Forcejear']['claves']])
    # RESPIRAR: el quieto del partido, loop de 2 s. Brazos sueltos a los costados
    # (el Quieto original tiene las manos en la cintura: parado en la cancha no
    # quedaba bien), respira (pecho y hombros suben) y pasa el peso de un pie al otro.
    def respira(r, peso):
        return dict(ground=1, tL=-3 - 2 * peso, kL=6, tR=-3 + 2 * peso, kR=6, roll=1.5 * peso, tr=-1.0 * peso,
                    tp=3 - 2.0 * r, hp=-3 + 1.5 * r,
                    gL=(0.37, -0.03, 0.52 + 0.025 * r), gR=(-0.37, -0.03, 0.52 + 0.025 * r),
                    pL=(0.4, 1.0, -0.2), pR=(-0.4, 1.0, -0.2))
    D['Respirar'] = dict(ticks=8, contacto=None, aerea=False, bucle=True, claves=[
        (1, respira(0, 0.3)), (13, respira(1, 0.0)), (25, respira(0, -0.3)), (37, respira(1, 0.0)), (49, respira(0, 0.3))])
    return D


def asentar(nombre, d, pasadas=3, tolerancia=0.012):
    """Recorre todos los cuadros midiendo la malla real. Donde algo atraviesa el piso
    (sumando el salto del motor en las aereas) sube la cadera en ese cuadro.
    Entre dos claves la interpolacion puede hundir un pie aunque las claves apoyen."""
    arm, ad, R3 = _ctx(); act = bpy.data.actions[nombre]; arm.animation_data.action = act
    sc = bpy.context.scene; n = d['ticks'] * TICK; cad = arm.pose.bones['Cadera']
    corregidos = 0
    for _ in range(pasadas):
        hubo = False
        for f in range(1, n + 2):
            sc.frame_set(f)
            z, _q = min_z()
            if d.get('aerea') and d.get('contacto') is not None:
                z += salto_motor((f - 1) / n, d['contacto'])
            if z < PISO - tolerancia:
                cad.location = cad.location + R3['Cadera'].inverted() @ Vector((0, 0, PISO - z))
                cad.keyframe_insert('location', frame=f); hubo = True; corregidos += 1
        if not hubo: break
    arm.animation_data.action = None
    return corregidos


def poner_anclajes():
    """Puntos de contacto con la pelota, pegados a los huesos. Van en el GLB como nodos
    vacios y el partido 3D lleva la pelota a ellos en el instante del golpe."""
    from mathutils import Matrix
    arm, ad, R3 = _ctx()
    col = arm.users_collection[0]
    b = ad.bones
    tail = lambda n: b[n].tail_local.copy()
    # punto en reposo (mundo) -> desplazamiento local desde la punta del hueso
    puntos = {
        'Mano_L': ('Antebrazo.L', tail('Antebrazo.L')),
        'Mano_R': ('Antebrazo.R', tail('Antebrazo.R')),
        'Pecho': ('Torso', tail('Torso') + Vector((0, -0.22, -0.2))),
        # frente: adelante de la cabeza, a la altura de las cejas
        'Frente': ('Cabeza', Vector((0, -0.47, 1.62))),
        # empeine: apenas atras y arriba de la punta del botin
        'Pie_R': ('Pie.R', tail('Pie.R') + Vector((0, 0.04, 0.03))),
        'Pie_L': ('Pie.L', tail('Pie.L') + Vector((0, 0.04, 0.03))),
        # talon: detras del tobillo, cerca del piso
        'Talon_R': ('Pie.R', b['Pie.R'].head_local + Vector((0, 0.09, -0.04))),
    }
    for nombre, (hueso, mundo) in puntos.items():
        ob = bpy.data.objects.get(nombre) or bpy.data.objects.new(nombre, None)
        if ob.name not in col.objects: col.objects.link(ob)
        ob.empty_display_type = 'SPHERE'; ob.empty_display_size = 0.05
        ob.parent = arm; ob.parent_type = 'BONE'; ob.parent_bone = hueso
        ob.matrix_parent_inverse = Matrix.Identity(4)
        ob.location = R3[hueso].inverted() @ (mundo - tail(hueso))
    return list(puntos)


def definicion_agarrar():
    """Arquero: agarra la pelota (4 ticks, recepcion: contacto al empezar)."""
    return dict(ticks=4, contacto=0.0, aerea=False, hueso='Antebrazo.L', extremo='-y', claves=[
        (1, dict(ground=1, tL=-12, kL=30, tR=-12, kR=30, tp=12, hp=-6,
                 gL=(0.13, -0.5, 0.92), gR=(-0.13, -0.5, 0.92))),
        (7, dict(ground=1, tL=-15, kL=40, tR=-15, kR=40, tp=18, hp=0,
                 gL=(0.12, -0.36, 0.8), gR=(-0.12, -0.36, 0.8))),
        (13, dict(ground=1, tL=-12, kL=35, tR=-12, kR=35, tp=14, hp=-2,
                  gL=(0.1, -0.3, 0.82), gR=(-0.1, -0.3, 0.82))),
        (25, dict(ground=1, tL=-6, kL=18, tR=-6, kR=18, tp=6, hp=-4,
                  gL=(0.1, -0.3, 0.85), gR=(-0.1, -0.3, 0.85))),
    ])


def definiciones_golero():
    """Arquero con la pelota en las manos (golero_chibi.blend). La pose de
    sostenerla es la del final de Agarrar: las manos juntas adelante del pecho."""
    D = {}
    manos = dict(gL=(0.1, -0.3, 0.85), gR=(-0.1, -0.3, 0.85))

    def sostiene(r, peso):
        return dict(ground=1, tL=-5 - 2 * peso, kL=16, tR=-5 + 2 * peso, kR=16, roll=1.5 * peso, tr=-1.0 * peso,
                    tp=6 - 2.0 * r, hp=-4 + 1.5 * r,
                    gL=(0.1, -0.3, 0.85 + 0.02 * r), gR=(-0.1, -0.3, 0.85 + 0.02 * r))
    # SOSTIENE: loop de 2 s. Entre el agarre y el saque, la pelota contra el pecho.
    D['Arquero_Sostiene'] = dict(ticks=8, contacto=None, aerea=False, bucle=True, claves=[
        (1, sostiene(0, 0.3)), (13, sostiene(1, 0.0)), (25, sostiene(0, -0.3)), (37, sostiene(1, 0.0)), (49, sostiene(0, 0.3))])
    # LEVANTA: 6 ticks. Estirada que termina en agarre (3D-08): arranca en la
    # pose de caer de Atajar_Volando (16/24, tirado de costado hacia su derecha,
    # la cadera 1.3 m al costado), se trae la pelota al pecho y se hace bolita,
    # se queda un momento, gira hacia adelante, apoya la rodilla derecha y se
    # para con la pelota en las manos: termina en la pose de Arquero_Sostiene
    # (cadera en su lugar; el juego la deja donde cayo mientras se levanta).
    tirado = dict(apoyar=1, roll=-86, tp=22, hp=6, hr=-10, loc=(-1.3, 0, 0),
                  tL=-45, kL=75, tR=-50, kR=85, gL=(0.1, -0.32, 0.82), gR=(-0.1, -0.32, 0.82))
    D['Arquero_Levanta'] = dict(ticks=6, contacto=None, aerea=False, claves=[
        (1, dict(apoyar=1, roll=-88, tL=-10, kL=30, tR=-15, kR=40, tp=5, hp=0, hr=-10, loc=(-1.3, 0, 0),
                 gL=(0.1, -0.4, 1.25), gR=(-0.15, -0.4, 1.2), pL=(1, 0.6, -0.2), pR=(-1, 0.6, -0.2))),
        (6, dict(tirado)),
        (13, dict(tirado, tp=25, hp=4)),
        (19, dict(apoyar=1, roll=-45, tL=-70, kL=100, tR=-25, kR=110, tp=28, hp=0, hr=-5, loc=(-0.95, 0, 0),
                  gL=(0.1, -0.32, 0.82), gR=(-0.1, -0.32, 0.82))),
        (25, dict(apoyar=1, roll=0, tL=-78, kL=85, tR=5, kR=95, tp=16, hp=-4, loc=(-0.5, 0, 0),
                  gL=(0.1, -0.31, 0.83), gR=(-0.1, -0.31, 0.83))),
        (31, dict(ground=1, tL=-40, kL=60, tR=-22, kR=55, tp=14, hp=-4, loc=(-0.15, 0, 0),
                  gL=(0.1, -0.3, 0.84), gR=(-0.1, -0.3, 0.84))),
        (37, sostiene(0, 0.3)),
    ])
    D['Arquero_Levanta_Izq'] = dict(D['Arquero_Levanta'], claves=[(f, espejar(P)) for f, P in D['Arquero_Levanta']['claves']])
    # ATAJADAS POR ZONA: 4 ticks como el agarre, con las manos en la pelota en
    # 6/24 (el juego arranca la animacion 1 tick antes del agarre del motor) y
    # terminan en la pose de Arquero_Sostiene. La cabeza del chibi no deja
    # pasar las manos por arriba ni adelante de la cara: lo mas alto que
    # agarra parado es a la altura de la boca, saltando.
    guardia = dict(ground=1, tL=-25, kL=50, tR=-25, kR=50, abL=8, abR=8, tp=18, hp=-12,
                   gL=(0.3, -0.35, 0.8), gR=(-0.3, -0.35, 0.8))
    # ARRIBA: se agacha, salta y la agarra adelante de la boca (manos a 1.53,
    # 1.15 m en el juego), cae y se la trae al pecho.
    D['Atajar_Arriba'] = dict(ticks=4, contacto=None, aerea=False, claves=[
        (1, dict(guardia)),
        (4, dict(ground=1, tL=-40, kL=80, tR=-40, kR=80, abL=8, abR=8, tp=22, hp=-14,
                 gL=(0.28, -0.4, 0.8), gR=(-0.28, -0.4, 0.8))),
        (7, dict(loc=(0, 0, 0.55), tL=-10, kL=35, tR=-10, kR=35, tp=4, hp=-8,
                 gL=(0.12, -0.5, 1.02), gR=(-0.12, -0.5, 1.02))),
        (10, dict(loc=(0, 0, 0.4), tL=-15, kL=40, tR=-15, kR=40, tp=8, hp=-6,
                  gL=(0.1, -0.45, 0.95), gR=(-0.1, -0.45, 0.95))),
        (14, dict(ground=1, tL=-30, kL=65, tR=-30, kR=65, tp=16, hp=-4,
                  gL=(0.1, -0.32, 0.86), gR=(-0.1, -0.32, 0.86))),
        (25, sostiene(0, 0.3)),
    ])
    # ABAJO: baja a una rodilla (la derecha al piso, la izquierda adelante) y
    # la recoge con las dos manos junto al piso (manos a 0.32, 0.24 m en el
    # juego); se la trae a la panza y se para.
    abajo = dict(apoyar=1, tL=-60, kL=110, tR=0, kR=115, abL=14, abR=4, yL=-10, tp=14, hp=-16,
                 gL=(0.14, -0.52, 0.5), gR=(-0.14, -0.52, 0.5))
    D['Atajar_Abajo'] = dict(ticks=4, contacto=None, aerea=False, claves=[
        (1, dict(guardia)),
        (4, dict(ground=1, tL=-45, kL=80, tR=-10, kR=70, tp=16, hp=-12,
                 gL=(0.14, -0.5, 0.62), gR=(-0.14, -0.5, 0.62))),
        (7, dict(abajo)),
        (11, dict(abajo, tp=10, hp=-10, gL=(0.1, -0.38, 0.62), gR=(-0.1, -0.38, 0.62))),
        (17, dict(ground=1, tL=-35, kL=60, tR=-20, kR=55, tp=12, hp=-4,
                  gL=(0.1, -0.32, 0.82), gR=(-0.1, -0.32, 0.82))),
        (25, sostiene(0, 0.3)),
    ])
    # ESTIRADA ALTA: la de Atajar_Volando (mismos cuadros: estirado en 10/24,
    # cae en 16/24) pero en diagonal y bien arriba, al angulo: las manos a
    # ~1.85 (1.4 m en el juego, mas el salto del juego).
    estira = dict(gL=(0.02, -0.46, 1.36), gR=(-0.2, -0.44, 1.3), pL=(1, 0.6, -0.2), pR=(-1, 0.6, -0.2))
    vuela = definiciones()['Atajar_Volando']['claves']
    D['Atajar_Volando_Alto'] = dict(ticks=4, contacto=None, aerea=False, claves=[
        (1, dict(vuela[0][1])),
        (5, dict(ground=1, tL=-15, kL=35, tR=-50, kR=85, abR=20, roll=-10, tp=10, hp=-12, tr=-10, loc=(-0.15, 0, 0),
                 gL=(0.2, -0.4, 1.15), gR=(-0.35, -0.4, 1.2))),
        (8, dict(roll=-50, tL=10, kL=15, tR=5, kR=20, abL=10, tr=-10, hp=-5, hr=-10, loc=(-0.7, 0, 0.95), **estira)),
        (11, dict(roll=-55, tL=5, kL=5, tR=0, kR=5, abL=8, tr=-5, hp=0, hr=-15, loc=(-1.0, 0, 1.0), **estira)),
        (13, dict(roll=-70, tL=8, kL=10, tR=4, kR=10, tr=-5, hp=0, hr=-15, loc=(-1.15, 0, 0.7), **estira)),
        (16, dict(vuela[5][1])),
        (25, dict(vuela[6][1])),
    ])
    D['Atajar_Volando_Alto_Izq'] = dict(D['Atajar_Volando_Alto'],
                                        claves=[(f, espejar(P)) for f, P in D['Atajar_Volando_Alto']['claves']])
    # LANZA: 2 ticks como el pase del motor. Saque con la mano por abajo, la
    # pelota rodando: la derecha va atras, da un paso largo con la izquierda y
    # la suelta abajo, adelante del pie (lo mas bajo de la mano, 7/12).
    D['Arquero_Lanza'] = dict(ticks=2, contacto=7.0 / 12.0, aerea=False, hueso='Antebrazo.R', extremo='-z', claves=[
        (1, dict(sostiene(0, 0.0), gL=(0.12, -0.3, 0.88), gR=(-0.08, -0.32, 0.78))),
        (4, dict(ground=1, tL=-30, kL=35, tR=12, kR=30, tp=20, ty=-20, hp=-10,
                 gL=(0.4, -0.35, 0.85), gR=(-0.33, 0.3, 0.55))),
        (8, dict(ground=1, tL=-45, kL=65, tR=25, kR=50, tp=40, ty=4, hp=-26,
                 gL=(0.45, -0.1, 0.75), gR=(-0.16, -0.6, 0.48))),
        (13, dict(ground=1, tL=-25, kL=35, tR=5, kR=25, tp=14, hp=-6,
                  gL=(0.35, -0.2, 0.7), gR=(-0.25, -0.5, 0.95))),
    ])
    # VOLEO: 4 ticks como el saque_arco del motor. Paso con la derecha, adelanta
    # la pelota, la suelta (8/24), planta la izquierda y le pega de volea con la
    # derecha (12/24, lo mas rapido del pie), que sigue bien arriba.
    D['Arquero_Voleo'] = dict(ticks=4, contacto=0.5, aerea=False, hueso='Pie.R', extremo='rapido', claves=[
        (1, dict(sostiene(0, 0.0), **manos)),
        (5, dict(ground=1, tL=10, kL=25, tR=-30, kR=30, tp=10, hp=-4, gL=(0.1, -0.42, 0.8), gR=(-0.1, -0.42, 0.8))),
        (9, dict(ground=1, tL=-30, kL=30, tR=35, kR=80, fR=20, tp=8, hp=-4, gL=(0.1, -0.46, 0.75), gR=(-0.1, -0.46, 0.75))),
        (11, dict(ground=1, tL=-20, kL=28, tR=15, kR=85, fR=25, tp=4, hp=-4, gL=(0.45, -0.3, 0.82), gR=(-0.4, -0.12, 0.72))),
        (13, dict(ground=1, tL=-8, kL=25, tR=-50, kR=20, fR=35, tp=-8, hp=-2, gL=(0.62, -0.15, 1.0), gR=(-0.5, 0.15, 0.8))),
        (17, dict(ground=1, tL=0, kL=15, tR=-85, kR=35, fR=30, tp=-15, hp=0, gL=(0.6, -0.05, 1.02), gR=(-0.45, 0.1, 0.85))),
        (25, dict(ground=1, tL=-10, kL=30, tR=-15, kR=35, tp=6, hp=-4, gL=(0.4, -0.15, 0.68), gR=(-0.4, -0.15, 0.68))),
    ])
    # SAQUE DE ARCO: 4 ticks. Llega corriendo, planta la izquierda al lado de
    # la pelota, le pega abajo con el empeine (12/24) y sigue con la pierna arriba.
    D['Saque_Arco'] = dict(ticks=4, contacto=0.5, aerea=False, hueso='Pie.R', extremo='rapido', claves=[
        (1, carrera(0.0)), (4, carrera(0.25)), (7, carrera(0.5)),
        (10, dict(ground=1, tL=-28, kL=28, tR=40, kR=100, fR=30, tr=10, ty=-15, hy=-8, tp=4, hp=-4,
                  gL=(0.66, -0.15, 1.0), gR=(-0.45, 0.25, 0.72))),
        (13, dict(ground=1, tL=-5, kL=30, tR=-45, kR=15, fR=40, tr=12, ty=5, hy=8, tp=-4, hp=-2,
                  gL=(0.62, -0.05, 1.05), gR=(-0.4, -0.3, 0.85))),
        (17, dict(ground=1, tL=5, kL=20, tR=-95, kR=30, fR=30, tr=8, tp=-14, hp=0,
                  gL=(0.6, 0.05, 1.0), gR=(-0.35, -0.35, 0.9))),
        (25, dict(ground=1, tL=-10, kL=30, tR=-25, kR=40, tp=8, hp=-4, gL=(0.4, -0.15, 0.68), gR=(-0.4, -0.15, 0.68))),
    ])
    return D


def construir_todas(solo=None, golero=False):
    D = definiciones_golero() if golero else definiciones(); hechas = {}
    for nombre, d in D.items():
        if solo and nombre not in solo: continue
        construir(nombre, d['claves'])
        hechas[nombre] = asentar(nombre, d)
    return hechas


# ---------------------------------------------------------------- verificacion
def salto_motor(progreso, impacto):
    """CoreografiaPartido.salto: sube hasta 0.65 m en el impacto y baja."""
    sub = min(max(progreso / max(impacto, 0.001), 0.0), 1.0)
    if progreso <= impacto: return math.sin(sub * math.pi * 0.5) * 0.65
    return math.cos(min(max((progreso - impacto) / (1.0 - impacto), 0.0), 1.0) * math.pi * 0.5) * 0.65


def _cara_abajo(arm, R3):
    """Grados que la cara mira hacia el piso (0 = al frente)."""
    pb = arm.pose.bones['Cabeza']
    frente = (arm.matrix_world.to_3x3() @ pb.matrix.to_3x3() @ R3['Cabeza'].inverted() @ Vector((0, -1, 0))).normalized()
    return math.degrees(math.asin(max(-1.0, min(1.0, -frente.z))))


def _torso_parado(arm, R3):
    pb = arm.pose.bones['Torso']
    arriba = (arm.matrix_world.to_3x3() @ pb.matrix.to_3x3() @ R3['Torso'].inverted() @ Vector((0, 0, 1))).normalized()
    return arriba.z > 0.8


def verificar(nombre, d):
    arm, ad, R3 = _ctx(); act = bpy.data.actions[nombre]; arm.animation_data.action = act
    sc = bpy.context.scene
    n = d['ticks'] * TICK; fr = act.frame_range
    r = {'nombre': nombre, 'duracion_s': round((fr[1] - fr[0]) / FPS, 3), 'motor_s': d['ticks'] * 0.25}
    r['duracion_ok'] = abs(r['duracion_s'] - r['motor_s']) < 1.0 / FPS + 1e-6
    peor_piso = (9.0, 0, ''); peor_cara = (-90.0, 0); peor_suelo = (-90.0, 0); posiciones = []; torso_z = []
    f_contacto = 1 + d['contacto'] * n if d.get('contacto') is not None else -99
    for f in range(1, n + 2):
        sc.frame_set(f); prog = (f - 1) / n
        z, q = min_z()
        sube = salto_motor(prog, d['contacto']) if d.get('aerea') and d.get('contacto') is not None else 0.0
        z += sube
        if z < peor_piso[0]: peor_piso = (round(z, 3), f, q)
        # En el cabezazo la cara mira a la pelota justo en el golpe: se exime ese instante.
        exento = d.get('hueso') == 'Cabeza' and abs(f - f_contacto) <= 2
        c = _cara_abajo(arm, R3)
        if _torso_parado(arm, R3) and not exento:
            if c > peor_cara[0]: peor_cara = (round(c, 1), f)
        # Tirado o volando tampoco puede quedar la cara contra el piso: desde la
        # camara solo se veia el pelo (palomita y caida, primera version).
        if not exento and c > peor_suelo[0]: peor_suelo = (round(c, 1), f)
        if d.get('hueso'):
            pb = arm.pose.bones[d['hueso']]
            p = (arm.matrix_world @ pb.tail) + Vector((0, 0, sube))
            posiciones.append(p.copy())
        pt = arm.pose.bones['Torso']
        torso_z.append((arm.matrix_world.to_3x3() @ pt.matrix.to_3x3() @ R3['Torso'].inverted() @ Vector((0, 0, 1))).normalized().z)
    r['piso_min'] = peor_piso; r['piso_ok'] = peor_piso[0] >= PISO - 0.035
    r['cara_abajo_max'] = peor_cara; r['cara_ok'] = peor_cara[0] <= 25.0
    r['cara_al_piso_max'] = peor_suelo; r['cara_piso_ok'] = peor_suelo[0] <= 50.0
    if d.get('contacto') is not None and posiciones:
        ext = d['extremo']
        if ext == 'horizontal':
            # primer cuadro con el torso a mas de 70 grados de la vertical
            vals = [1.0 if z < math.cos(math.radians(70)) else 0.0 for z in torso_z]
        elif ext == '-y': vals = [-p.y for p in posiciones]
        elif ext == '+y': vals = [p.y for p in posiciones]
        elif ext == '+z': vals = [p.z for p in posiciones]
        elif ext == '-z': vals = [-p.z for p in posiciones]
        elif ext == 'rapido':
            # El golpe de una patada: donde el pie va mas rapido.
            vals = [(posiciones[min(i + 1, len(posiciones) - 1)] - posiciones[max(i - 1, 0)]).length
                    for i in range(len(posiciones))]
        else: vals = [-p.y for p in posiciones]
        f_ext = int(np.argmax(vals)) + 1; f_obj = 1 + d['contacto'] * n
        r['contacto_cuadro'] = f_ext; r['contacto_motor'] = round(f_obj, 1)
        r['contacto_ok'] = abs(f_ext - f_obj) <= 1.6 or (d['contacto'] == 0.0 and f_ext <= 2)
    else:
        r['contacto_ok'] = True
    if d.get('bucle'):
        sc.frame_set(1); a = [pb.matrix.copy() for pb in arm.pose.bones]
        sc.frame_set(n + 1); b = [pb.matrix.copy() for pb in arm.pose.bones]
        r['bucle_ok'] = all((x.to_translation() - y.to_translation()).length < 1e-3 for x, y in zip(a, b))
    arm.animation_data.action = None
    r['ok'] = all(v for k, v in r.items() if k.endswith('_ok'))
    return r


def verificar_todas(solo=None, golero=False):
    D = definiciones_golero() if golero else definiciones(); out = []
    for nombre, d in D.items():
        if solo and nombre not in solo: continue
        out.append(verificar(nombre, d))
    return out


def hoja(nombre, carpeta, cuadros=8, pelota_regate=True):
    """Hoja de control: cuadros repartidos, camara 3/4 de los sprites."""
    arm, ad, R3 = _ctx(); d = definiciones()[nombre]; sc = bpy.context.scene
    act = bpy.data.actions[nombre]; arm.animation_data.action = act
    n = d['ticks'] * TICK
    cam = bpy.data.objects.get('Camara_Correr') or sc.camera; sc.camera = cam
    sc.render.resolution_x = sc.render.resolution_y = 256; sc.render.filter_size = 1.5
    sc.render.film_transparent = False
    os.makedirs(carpeta, exist_ok=True); rutas = []
    bola = None
    if d.get('regate') and pelota_regate:
        bola = bpy.data.objects.get('_bola_control')
        if not bola:
            import bmesh
            me = bpy.data.meshes.new('_bola_control'); bm = bmesh.new()
            bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=6, radius=0.29); bm.to_mesh(me); bm.free()
            bola = bpy.data.objects.new('_bola_control', me); sc.collection.objects.link(bola)
            m = bpy.data.materials.new('_bola_control'); m.diffuse_color = (0.1, 0.4, 1, 1); me.materials.append(m)
    for i in range(cuadros):
        f = 1 + round(i * n / (cuadros - 1)); sc.frame_set(f)
        if bola:
            off, alt = trayectoria_regate(d['regate'], (f - 1) / n)
            # adelante = -Y, derecha del jugador = -X; metros del 3D / escala del chibi
            bola.location = (-off[1] / 0.75, -off[0] / 0.75, 0.29 + alt / 0.75)
        sc.render.filepath = os.path.join(carpeta, '%s_%02d.png' % (nombre, i)); bpy.ops.render.render(write_still=True)
        rutas.append(sc.render.filepath)
    if bola: bpy.data.objects.remove(bola, do_unlink=True)
    arm.animation_data.action = None
    return rutas


def elastica_3d(fase):
    """La elastica del 3D (copia de VistaCancha3D.elastica_3d): (adelante, derecha) en metros del juego."""
    sm = lambda x: (lambda y: y * y * (3 - 2 * y))(min(max(x, 0.0), 1.0))
    f = min(max(fase, 0.0), 1.0)
    if f < 0.4: return 0.32, 0.36 * sm(f / 0.4)
    if f < 0.6: return 0.32, 0.36 - 0.68 * sm((f - 0.4) / 0.2)
    return 0.32 + 0.12 * sm((f - 0.6) / 0.4), -0.32 + 0.14 * sm((f - 0.6) / 0.4)


def trayectoria_regate(tipo, fase):
    """Copia de VistaPartido._trayectoria_regate en el marco del jugador: (adelante, derecha), altura."""
    if tipo == 'elastica_3d':
        return elastica_3d(fase), 0.0
    f = min(max(fase, 0.0), 1.0); sm = lambda x: x * x * (3 - 2 * x)
    ad, lat, alt = 0.35, 0.0, 0.0
    if tipo == 'croqueta':
        if f < 0.30: ad, lat = 0.22 + (0.34 - 0.22) * f / 0.30, 0.28
        elif f < 0.66:
            tr = sm((f - 0.30) / 0.36); ad, lat = 0.34 + tr * 0.08, 0.28 + (-0.56) * tr
        else:
            s = sm((f - 0.66) / 0.34); ad, lat = 0.42 + s * 0.10, -0.28
    elif tipo == 'bicicleta':
        a0, s0 = 2 / 12, 9 / 12
        if f < a0: ad = 0.24 + 0.14 * f / a0
        elif f < s0: ad = 0.38
        else:
            s = sm((f - s0) / (1 - s0)); ad, lat = 0.38 + s * 0.55, -0.30 * s
    elif tipo == 'elastica':
        ad, lat = 0.30 + 0.65 * f, math.sin(f * math.pi * 2) * 0.85
    elif tipo == 'ruleta':
        g0, s0, R = 2 / 12, 9 / 12, 0.32
        if f < g0:
            c = f / g0; ad = 0.25 + (R - 0.25) * c
        elif f < s0:
            g = (f - g0) / (s0 - g0); a = -2 * math.pi * g; ad, lat = math.cos(a) * R, math.sin(a) * R
        else:
            e = (f - s0) / (1 - s0); ad = R + 0.2 * e
    elif tipo == 'globito':
        T, C, H, P = 4 / 12, 7 / 12, 2.6, 0.8
        if f < T:
            ad = 0.25 + 0.10 * f / T
        else:
            s = (f - T) / (1 - T)
            cuerpo = 0.9 + 0.1 * min(1, (f - T) / (C - T)) if f < C else 1.0 + 2.4 * sm((f - C) / (1 - C))
            if s < P:
                v = s / P; ad, alt = (1.25 + 2.35 * v) - cuerpo, H * math.sin(v * math.pi)
            else:
                ru = (s - P) / (1 - P); ad = (3.6 + 0.25 * ru) - cuerpo
    # en el marco del motor lateral = derecha del jugador (ver VistaCancha3D)
    return (ad, lat), alt
