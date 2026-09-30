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
  qpL/qpR     : giro del pie (cuaternion w,x,y,z, ejes del esqueleto) en vez de f: lo usan los clips en cinta
Los clips de andar (Correr, Trotar, Caminar y los de la seccion "locomocion en cinta") no usan
angulos: ubican cada tobillo en la cancha y resuelven la pierna. Despues de construirlos:
    escribir_avance(r"...tools/blender/avance_locomocion.json"); [medir_cinta(n) for n in LOCOMOCION_CINTA]
"""
import bpy, math, os
import numpy as np
from mathutils import Vector, Quaternion, Matrix

FPS = 24
TICK = 6            # cuadros por tick del motor (0.25 s)
PISO = -0.021       # punto mas bajo en reposo (contorno incluido): es el piso
PUNTA_PIE = Vector((0, 0.04, 0.03))   # anclas Pie_L/Pie_R: el empeine, apenas atras y arriba de la punta


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
        setq('Pierna.' + side, rx(k))
        setq('Pie.' + side, Quaternion(P['qp' + side]) if 'qp' + side in P else rx(f))
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


# ---------------------------------------------------------------- locomocion en cinta
# Los clips de andar van "en cinta": el cuerpo queda en el lugar y el pie
# apoyado retrocede a la velocidad del cuerpo. La vista avanza cada clip con
# los metros que recorre el cuerpo (avance_locomocion.json, que pasa a
# data/acciones_v2.json) y el pie apoyado queda quieto en la cancha. Los
# Correr, Trotar y Caminar anteriores movian las piernas por angulos: el pie
# apoyado casi no retrocedia y patinaba lo mismo que avanzaba el cuerpo
# (Correr: 7,48 m/s de pie contra 6,88 de cuerpo; docs/motor_v2.md, etapa 2).
# Aca cada tobillo tiene un lugar en la cancha y la pierna se resuelve (IK).
ESCALA_JUEGO = 0.75       # Jugador3D.ESCALA_CHIBI: 1 m de Blender es 0,75 m del juego
# Fraccion del largo de la pierna que se usa: estirada del todo, la rodilla
# se ve trabada. Con 0.97 la cadera parada queda 1,4 cm (de Blender) debajo
# de la de Respirar, que no se nota en el fundido.
ALCANCE = 0.97
GIRO_PIERNA_MAX = 40.0    # grados que el plano de la pierna sigue al pie cuando la cadera gira
POLOS = dict(pL=(1.0, 0.35, -0.6), pR=(-1.0, 0.35, -0.6))   # codos: el polo por defecto de pose()
TRONCO = ('hy', 'tp', 'tr', 'ty', 'hp', 'hr', 'hz', 'gL', 'gR', 'pL', 'pR', 'roll', 'pitch')
# Correr: 2,2 m del juego por ciclo (1,1 por paso) y cada pie apoyado el 16%
# del ciclo. La pierna del chibi mide 0,38 m del juego: el pie apoyado barre
# 0,47 m de Blender (lo que da la pierna con la cadera abajo) y el resto es
# vuelo. Los clips en cinta van a 24 cuadros por ciclo: la vista los avanza
# por metros y la duracion no importa, pero con 12 el apoyo duraba 2 cuadros
# y entre uno y otro el pie se hundia 1,2 cm (las rotaciones se interpolan).
METROS_CORRER, APOYO_CORRER, TICKS_CORRER = 2.2, 0.16, 4
V_CORRER = METROS_CORRER / ESCALA_JUEGO / (TICKS_CORRER * TICK / FPS)   # m de Blender por segundo


def _tronco(P, **extra):
    """Solo lo de la cintura para arriba de una pose (las piernas las pone la cinta)."""
    Q = dict(POLOS)
    Q.update({k: v for k, v in P.items() if k in TRONCO}); Q.update(extra)
    return Q


def _suave(x):
    x = min(max(x, 0.0), 1.0)
    return x * x * (3 - 2 * x)


def _rot2(v, grados):
    """Un punto del piso girado alrededor del cuerpo (+ = hacia su izquierda)."""
    return (rz(grados) @ Vector((v[0], v[1], 0.0))).to_2d()


def _curva(puntos):
    """Funcion t -> valor que pasa por los puntos (t, valor), sin frenar en cada uno."""
    ts = [p[0] for p in puntos]; vs = [p[1] for p in puntos]

    def f(t):
        if t <= ts[0]: return vs[0]
        if t >= ts[-1]: return vs[-1]
        i = max(j for j in range(len(ts) - 1) if ts[j] <= t)
        h = ts[i + 1] - ts[i]; s = (t - ts[i]) / h
        m = [0.0 if j in (0, len(ts) - 1) else (vs[j + 1] - vs[j - 1]) / (ts[j + 1] - ts[j - 1]) for j in (i, i + 1)]
        return ((2 * s ** 3 - 3 * s ** 2 + 1) * vs[i] + (s ** 3 - 2 * s ** 2 + s) * h * m[0]
                + (-2 * s ** 3 + 3 * s ** 2) * vs[i + 1] + (s ** 3 - s ** 2) * h * m[1])
    return f


def _pierna(side):
    """La pierna en reposo: cabeza de la Cadera, articulacion del muslo, muslo
    (hasta la rodilla), pierna (rodilla -> tobillo), punta del pie (tobillo ->
    ancla Pie_L/R) y altura del tobillo con el pie plano en el piso."""
    arm, ad, R3 = _ctx(); b = ad.bones
    muslo = b['Muslo.' + side].head_local.copy()
    rod = b['Pierna.' + side].head_local.copy(); tob = b['Pie.' + side].head_local.copy()
    return dict(cad=b['Cadera'].head_local.copy(), muslo=muslo, u1=rod - muslo, u2=tob - rod,
                punta=b['Pie.' + side].tail_local + PUNTA_PIE - tob, tobillo_z=tob.z)


def _tobillo(s, ab, y, t, k, u1, u2):
    return (ry(-s * ab) @ rz(y) @ rx(t)) @ (u1 + rx(k) @ u2)


def _resolver_pierna(side, d, y, geo):
    """ab, t, k (grados) que llevan el tobillo al punto d, medido desde la
    articulacion del muslo en el marco de la Cadera ya girada. Arranca de la
    pierna plana y corrige con Newton: el esqueleto no es plano (el tobillo
    esta 2 cm adelante de la pierna). Devuelve tambien el error (m de Blender)."""
    s = 1 if side == 'L' else -1
    u1, u2 = geo['u1'], geo['u2']; l1, l2 = u1.length, u2.length
    dp = rz(-y) @ d
    n = math.hypot(dp.x, dp.z); fw = -dp.y
    D = max(0.05, min(math.hypot(fw, n), (l1 + l2) * 0.999))
    inter = math.acos(max(-1.0, min(1.0, (l1 * l1 + l2 * l2 - D * D) / (2 * l1 * l2))))
    beta = math.acos(max(-1.0, min(1.0, (l1 * l1 + D * D - l2 * l2) / (2 * l1 * D))))
    x = np.array([-s * math.degrees(math.atan2(-dp.x, -dp.z)),
                  -math.degrees(math.atan2(fw, n) + beta), 180.0 - math.degrees(inter)])
    meta = np.array(d)

    def f(v): return np.array(_tobillo(s, v[0], y, v[1], v[2], u1, u2))
    for _ in range(25):
        r = f(x) - meta
        if np.linalg.norm(r) < 1e-6: break
        J = np.column_stack([(f(x + h) - f(x)) / 1e-3 for h in np.eye(3) * 1e-3])
        x = x + np.linalg.lstsq(J, -r, rcond=None)[0]
        x[2] = max(x[2], 0.0)          # la rodilla no se dobla al reves
    return float(x[0]), float(x[1]), float(x[2]), float(np.linalg.norm(f(x) - meta))


def _velocidad(cuerpo, t, e=1e-3):
    return (cuerpo(t + e)[0] - cuerpo(t - e)[0]).length / (2 * e)


def _apoyo_en(a, t, geo):
    """Tobillo (x, y) y rumbo del pie durante un apoyo. Con pivote=(t0, t1, rumbo)
    el pie gira sobre la punta: el ancla no se mueve y el talon da la vuelta."""
    if 'pivote' not in a:
        return Vector(a['pos']), a['yaw']
    t0, t1, y1 = a['pivote']
    yaw = a['yaw'] + (y1 - a['yaw']) * _suave((t - t0) / (t1 - t0))
    ancla = Vector(a['pos']) + (rz(a['yaw']) @ geo['punta']).to_2d()
    return ancla - (rz(yaw) @ geo['punta']).to_2d(), yaw


def _pie_en(plan, t, cuerpo, alto_paso, geo):
    """Donde va un pie en el segundo t: (tobillo x,y; altura sobre el apoyo;
    rumbo; punta abajo en grados; apoyado). En el aire va de un apoyo al
    siguiente saliendo y llegando quieto en la cancha: si arrancara con
    velocidad, el primer cuadro en el aire ya contaria como patinar."""
    for i, a in enumerate(plan):
        if t > a['off']: continue
        if t >= a['on'] or i == 0:
            p, yaw = _apoyo_en(a, max(t, a['on']), geo)
            return p, 0.0, yaw, 0.0, True
        b = plan[i - 1]; dur = a['on'] - b['off']; s = (t - b['off']) / dur
        p0, y0 = _apoyo_en(b, b['off'], geo); p1, y1 = _apoyo_en(a, a['on'], geo)
        # En la cancha el pie sale y llega con velocidad 0 y al principio y al
        # final del paso solo sube y baja: el cuadro en que despega o apoya ya
        # no avanza (en Caminar era el 90% de lo que patinaba). Ese tramo dura
        # hasta el 10% del paso, lo que tarda el cuerpo en alejarse 3 cm: si
        # se aleja mas, la pierna no llega y el pie queda arrastrado.
        m0 = min(0.1, 0.03 / max(_velocidad(cuerpo, b['off']) * dur, 1e-6))
        m1 = min(0.1, 0.03 / max(_velocidad(cuerpo, a['on']) * dur, 1e-6))
        adelante = _suave((s - m0) / (1 - m0 - m1))
        # Un paso corto (acomodarse) no levanta el pie como uno de carrera.
        h = min(alto_paso, 0.3 * (p1 - p0).length + 0.02)
        return (p0 + (p1 - p0) * adelante, h * math.sin(math.pi * s) ** 0.6, y0 + (y1 - y0) * adelante,
                min(30.0, 150.0 * h) * math.sin(math.pi * s) * (1 - s), False)
    p, yaw = _apoyo_en(plan[-1], plan[-1]['off'], geo)
    return p, 0.0, yaw, 0.0, True


def _clip_cinta(ticks, cuerpo, pies, alto, arriba, alto_paso, t0=0.0, direccion=(0.0, -1.0)):
    """Arma un clip en cinta, una clave por cuadro.
    cuerpo(t) -> (Vector 2D en la cancha de Blender, rumbo en grados, + = a su izquierda).
    pies: {'L'|'R': [apoyos]}; cada apoyo es dict(on, off, pos=(x, y) del tobillo, yaw[, pivote]).
    alto(t): altura deseada de la articulacion del muslo; la baja lo que haga falta para que el
    pie apoyado llegue al piso. arriba(t): tronco, cabeza y brazos (claves de TRONCO).
    El clip saca la traslacion del cuerpo (queda en el lugar) y deja el giro."""
    geo = {s: _pierna(s) for s in 'LR'}
    largo = {s: ALCANCE * (geo[s]['u1'].length + geo[s]['u2'].length) for s in 'LR'}
    dvec = Vector(direccion).normalized()
    n = ticks * TICK; claves = []; avance = []; giros = []; recorrido = [0.0]; peor = 0.0
    c_ini, psi_ini = cuerpo(t0)
    for f in range(1, n + 2):
        t = t0 + (f - 1) / FPS
        c, psi = cuerpo(t)
        A = dict(arriba(t)); hy = psi + A.pop('hy', 0.0)
        Qc = ry(A.get('roll', 0.0)) @ rx(A.get('pitch', 0.0)) @ rz(hy)
        pie = {s: _pie_en(pies[s], t, cuerpo, alto_paso, geo[s]) for s in 'LR'}
        H = alto(t)
        for s in 'LR':
            p, sube = pie[s][0], pie[s][1]
            if sube > 0.03: continue            # en el aire no importa si estira de mas
            g = geo[s]
            cadera = (g['cad'] + Qc @ (g['muslo'] - g['cad'])).to_2d()
            dxy = ((p - c) - cadera).length
            if dxy < largo[s]:
                H = min(H, g['tobillo_z'] + sube + math.sqrt(largo[s] ** 2 - dxy ** 2))
        loc = Vector((0.0, 0.0, H - geo['L']['muslo'].z))
        P = dict(A, hy=hy, loc=tuple(loc))
        for s in 'LR':
            g = geo[s]; p, sube, yaw, punta, apoyado = pie[s]
            meta = Vector(((p - c).x, (p - c).y, g['tobillo_z'] + sube))
            d = Qc.inverted() @ (meta - (g['cad'] + loc + Qc @ (g['muslo'] - g['cad'])))
            if d.length > largo[s]:
                # En el aire, si la pierna no llega, el pie va hacia la cadera
                # (arrastrado) y no hacia abajo: estirada, la pierna lo metia
                # debajo del piso y el detector tomaba ese punto como el suelo.
                d = d * (largo[s] / d.length)
            y = max(-GIRO_PIERNA_MAX, min(GIRO_PIERNA_MAX, yaw - hy))
            ab, tt, k, err = _resolver_pierna(s, d, y, g)
            if apoyado: peor = max(peor, err)
            sg = 1 if s == 'L' else -1
            # El pie queda plano en la cancha (o con la punta abajo en el aire)
            # por mas que la pierna gire: se le pone el giro que falta.
            qp = (Qc @ ry(-sg * ab) @ rz(y) @ rx(tt) @ rx(k)).inverted() @ rz(yaw) @ rx(punta)
            P.update({'t' + s: tt, 'k' + s: k, 'ab' + s: ab, 'y' + s: y, 'qp' + s: tuple(qp)})
        claves.append((f, P))
        avance.append(round((c - c_ini).dot(dvec) * ESCALA_JUEGO, 4))
        giros.append(round(psi - psi_ini, 2))
        if f > 1:
            recorrido.append(recorrido[-1] + (c - cuerpo(t - 1 / FPS)[0]).length * ESCALA_JUEGO)
    cinta = dict(avance_m=avance, metros=avance[-1], direccion=[round(dvec.x, 4), round(-dvec.y, 4)],
                 giro=giros[-1], error_ik=peor)
    if any(giros):
        # La vista avanza los giros con lo que ya giro el cuerpo, no con el reloj.
        cinta['giro_por_cuadro'] = giros
    if any(b < a for a, b in zip(avance, avance[1:])):
        # El cuerpo va y vuelve (media vuelta): la vista lo avanza con los
        # metros recorridos, que no bajan.
        cinta['recorrido_m'] = [round(r, 4) for r in recorrido]
    return dict(ticks=ticks, claves=claves, cinta=cinta)


def _cinta_ciclo(ticks, metros, apoyo, direccion, centros, alto, arriba, alto_paso):
    """Un loop en cinta. metros: los que avanza el cuerpo por ciclo, del juego.
    apoyo: fraccion del ciclo que cada pie esta en el piso. El derecho esta en
    el medio de su apoyo en la fase 0.5 y el izquierdo en la 0: en la 0 el
    derecho pasa por debajo del cuerpo, como en el Correr de antes, y la vista
    cambia de clip sin cambiar de pie. centros: donde queda cada tobillo,
    relativo al cuerpo, en el medio del apoyo. alto(p) y arriba(p) por fase."""
    T = ticks * TICK / FPS; dvec = Vector(direccion).normalized()
    v = metros / ESCALA_JUEGO / T

    def cuerpo(t): return dvec * v * t, 0.0
    pies = {s: [dict(on=(fase + c) * T - apoyo * T / 2, off=(fase + c) * T + apoyo * T / 2,
                     pos=dvec * v * (fase + c) * T + Vector(centros[s]), yaw=0.0) for c in range(-1, 4)]
            for s, fase in (('R', 0.5), ('L', 0.0))}

    def fase(t): return (t / T) % 1.0
    return _clip_cinta(ticks, cuerpo, pies, lambda t: alto(fase(t)), lambda t: arriba(fase(t)), alto_paso,
                       t0=T, direccion=direccion)


def _pisadas(X, pasos, dvec):
    """Apoyos de una carrera que acelera o frena. X(t): metros de Blender
    recorridos (no decrece). pasos: (pie, a, antes, despues, costado): el
    tobillo apoya en el punto a del recorrido (y costado a su izquierda),
    llega cuando el cuerpo esta `antes` detras de a y se va cuando esta
    `despues` adelante. None: desde antes del clip o hasta despues."""
    lado = Vector((-dvec.y, dvec.x))

    def cuando(x):
        lo, hi = -3.0, 3.0
        for _ in range(60):
            mid = (lo + hi) / 2
            lo, hi = (mid, hi) if X(mid) < x else (lo, mid)
        return hi
    plan = {'L': [], 'R': []}
    for pie, a, antes, despues, costado in pasos:
        plan[pie].append(dict(on=-9.0 if antes is None else cuando(a - antes),
                              off=9.0 if despues is None else cuando(a + despues),
                              pos=dvec * a + lado * costado, yaw=0.0))
    return plan


def _fase_por_pisadas(plan):
    """La fase de Correr en cada t segun cuando apoya cada pie: el derecho
    apoya en 0.5 - apoyo/2 y el izquierdo medio ciclo despues."""
    ev = sorted((a['on'], s) for s in 'LR' for a in plan[s] if -5 < a['on'] < 5)
    p0 = 0.5 - APOYO_CORRER / 2 + (0.5 if ev[0][1] == 'L' else 0.0)
    ts = [e[0] for e in ev]; ps = [p0 + 0.5 * i for i in range(len(ev))]

    def f(t):
        if t <= ts[0]: return ps[0] - (ts[0] - t) * 0.5 / (ts[1] - ts[0])
        if t >= ts[-1]: return ps[-1] + (t - ts[-1]) * 0.5 / (ts[-1] - ts[-2])
        i = max(j for j in range(len(ts) - 1) if ts[j] <= t)
        return ps[i] + 0.5 * (t - ts[i]) / (ts[i + 1] - ts[i])
    return f


def _alto_correr(p):
    """Cadera de Correr por fase: abajo en el medio de cada apoyo (la rodilla
    amortigua) y arriba en el vuelo."""
    return 0.47 + 0.05 * (1 - math.cos(4 * math.pi * p)) / 2


def _giro_en_el_lugar(ticks, rumbo, pies, lado):
    """Media vuelta o cuarto de vuelta sin avanzar. rumbo: [(t, grados)] de la
    cadera; los pies pisan girados y uno pivotea sobre la punta. La cabeza y
    el pecho giran antes que la cadera, como quien mira adonde va."""
    T = ticks * TICK / FPS
    yaw = _curva(rumbo)

    def arriba(t):
        b = math.sin(math.pi * min(max(t / (0.8 * T), 0.0), 1.0))
        A = _mezcla(_tronco(respira(0, 0.3)), _tronco(LISTO), b)
        A['hz'] = A.get('hz', 0.0) + 24 * lado * math.sin(math.pi * min(max(t / (0.55 * T), 0.0), 1.0))
        A['ty'] = A.get('ty', 0.0) + 14 * lado * b
        return A
    return _clip_cinta(ticks, lambda t: (Vector((0.0, 0.0)), yaw(t)), pies,
                       lambda t: 0.575 - 0.05 * math.sin(math.pi * min(t / T, 1.0)), arriba, 0.1)


def respira(r, peso):
    """RESPIRAR: el quieto del partido. Brazos sueltos a los costados (el Quieto
    original tiene las manos en la cintura: parado en la cancha no quedaba
    bien), respira (pecho y hombros suben) y pasa el peso de un pie al otro."""
    return dict(ground=1, tL=-3 - 2 * peso, kL=6, tR=-3 + 2 * peso, kR=6, roll=1.5 * peso, tr=-1.0 * peso,
                tp=3 - 2.0 * r, hp=-3 + 1.5 * r,
                gL=(0.37, -0.03, 0.52 + 0.025 * r), gR=(-0.37, -0.03, 0.52 + 0.025 * r),
                pL=(0.4, 1.0, -0.2), pR=(-0.4, 1.0, -0.2))


def definiciones_locomocion():
    D = {}
    # CORRER, TROTAR y CAMINAR en cinta. Mismos brazos y tronco que antes
    # (carrera y ciclo); las piernas salen de donde pisa cada pie.
    D['Correr'] = dict(contacto=None, aerea=False, bucle=True, **_cinta_ciclo(
        TICKS_CORRER, METROS_CORRER, APOYO_CORRER, (0, -1), {'L': (0.10, 0), 'R': (-0.10, 0)},
        _alto_correr, lambda p: _tronco(carrera(p)), 0.22))
    # Trotar: 1,3 m por ciclo; a 3 m/s son 2,3 ciclos por segundo. Antes
    # 2,4 m: con la pierna del chibi el pie apoyado no llegaba a barrerlos.
    D['Trotar'] = dict(contacto=None, aerea=False, bucle=True, **_cinta_ciclo(
        4, 1.3, 0.26, (0, -1), {'L': (0.12, 0), 'R': (-0.12, 0)},
        lambda p: 0.47 + 0.03 * (1 - math.cos(4 * math.pi * p)) / 2,
        lambda p: _tronco(ciclo(p, muslo=30, rodilla=58, vuelo=0.025, torso=9, brazo=40)), 0.11))
    # Caminar: siempre un pie en el piso (apoyo 0.56 > 0.5). La cadera sube
    # sola en el medio del apoyo: la limita el largo de la pierna.
    D['Caminar'] = dict(contacto=None, aerea=False, bucle=True, **_cinta_ciclo(
        4, 0.62, 0.56, (0, -1), {'L': (0.14, 0), 'R': (-0.14, 0)},
        lambda p: 0.53, lambda p: _tronco(ciclo(p, muslo=19, rodilla=24, vuelo=0.0, torso=3, brazo=20)), 0.05))
    # CORRER DE COSTADO hacia su izquierda: paso de arquero. Sale con el pie
    # izquierdo bien abierto, el derecho se junta sin cruzarse, rodillas
    # flexionadas (con la pierna abierta la cadera no da mas alto).
    D['Correr_Costado_Izq'] = dict(contacto=None, aerea=False, bucle=True, **_cinta_ciclo(
        4, 1.0, 0.30, (1, 0), {'L': (0.22, 0), 'R': (-0.22, 0)},
        lambda p: 0.43 + 0.015 * (1 - math.cos(4 * math.pi * p)) / 2,
        lambda p: _tronco(dict(tp=14, tr=4, hp=-8, gL=(0.42, -0.2, 0.72 + 0.02 * math.cos(4 * math.pi * p)),
                               gR=(-0.42, -0.2, 0.72 + 0.02 * math.cos(4 * math.pi * p)))), 0.07))
    D['Correr_Costado_Der'] = dict(D['Correr_Costado_Izq'])
    # CORRER DE ESPALDAS: pasos cortos y rapidos, el pie apoya atras y el
    # cuerpo pasa por encima hacia atras. Tronco derecho y la vista adelante.
    D['Correr_Espaldas'] = dict(contacto=None, aerea=False, bucle=True, **_cinta_ciclo(
        4, 1.0, 0.30, (0, 1), {'L': (0.12, 0), 'R': (-0.12, 0)},
        lambda p: 0.46 + 0.02 * (1 - math.cos(4 * math.pi * p)) / 2,
        lambda p: _tronco(ciclo(p, muslo=20, rodilla=40, vuelo=0.0, torso=5, brazo=25), hp=-6), 0.08))
    # ARRANQUE: de parado (Respirar) a Correr. Se inclina, el derecho da el
    # primer paso corto y los pasos se alargan con la velocidad. Termina a la
    # velocidad de Correr con el derecho en el aire. Como Correr, la vista lo
    # avanza por metros: los 6 ticks son para que cada apoyo tenga cuadros.
    t0, T = 0.12, 6 * TICK / FPS

    def x_arranque(t):
        if t <= t0: return 0.0
        if t >= T: return V_CORRER * (T - t0) * 2 / 3 + V_CORRER * (t - T)
        u = (t - t0) / (T - t0)
        return V_CORRER * (T - t0) * (u * u - u ** 3 / 3)
    plan = _pisadas(x_arranque, [('R', 0.0, None, 0.0, -0.15), ('L', 0.0, None, 0.22, 0.15),
                                 ('R', 0.22, 0.08, 0.30, -0.13), ('L', 0.85, 0.20, 0.24, 0.12),
                                 ('R', 1.55, 0.22, 0.24, -0.11), ('L', 2.45, 0.235, 0.235, 0.10),
                                 ('R', 3.6, 0.235, 0.235, -0.10)], Vector((0, -1)))
    plan['R'][0]['off'] = 0.08          # el primer paso sale antes de que el cuerpo se mueva
    fase_a = _fase_por_pisadas(plan)

    def arriba_arranque(t):
        A = _mezcla(_tronco(respira(0, 0.0)), _tronco(carrera(fase_a(t))), _suave((t - 0.1) / 0.7))
        A['tp'] += 14 * _suave(t / 0.3) * (1 - _suave((t - 0.6) / 0.9))
        return A
    D['Arranque'] = dict(contacto=None, aerea=False, **_clip_cinta(
        6, lambda t: (Vector((0.0, -x_arranque(t))), 0.0), plan,
        lambda t: 0.575 + (_alto_correr(fase_a(t)) - 0.575) * _suave(t / 0.6), arriba_arranque, 0.22))
    # La fase de Correr en la que termina: la vista sigue con Correr desde ahi.
    D['Arranque']['cinta']['fase_final'] = round(fase_a(T) % 1.0, 4)
    # FRENADA: de Correr (el derecho apoyando) a parado. Frena con dos apoyos
    # largos bien adelante, el cuerpo atras, y junta los pies. Termina en la
    # pose del primer cuadro de Respirar. 6 ticks, por lo mismo que Arranque.
    ts = 1.0

    def x_frenada(t):
        if t <= 0: return V_CORRER * t
        u = min(t / ts, 1.0)
        return V_CORRER * ts * (u - u * u / 2)
    fin = V_CORRER * ts / 2
    plan = _pisadas(x_frenada, [('L', 0.235 - METROS_CORRER / ESCALA_JUEGO / 2, 0.235, 0.235, 0.10),
                                ('R', 0.235, 0.235, 0.20, -0.10), ('L', 0.95, 0.32, 0.30, 0.12),
                                ('R', fin, 0.30, None, -0.14)], Vector((0, -1)))
    plan['L'].append(dict(on=1.04, off=9.0, pos=Vector((0.14, -fin)), yaw=0.0))
    fase_f = _fase_por_pisadas(plan)

    def arriba_frenada(t):
        freno = dict(POLOS, tp=-6, hp=-10, ty=0, hz=0, hy=0, tr=0, gL=(0.5, -0.28, 0.8), gR=(-0.5, -0.28, 0.8))
        A = _mezcla(_tronco(carrera(fase_f(t))), freno, _suave(t / 0.5))
        return _mezcla(A, _tronco(respira(0, 0.3)), _suave((t - 0.7) / 0.7))
    D['Frenada'] = dict(contacto=None, aerea=False, **_clip_cinta(
        6, lambda t: (Vector((0.0, -x_frenada(t))), 0.0), plan,
        lambda t: _alto_correr(fase_f(t)) + (0.575 - _alto_correr(fase_f(t))) * _suave((t - 0.6) / 0.8),
        arriba_frenada, 0.22))
    # La fase de Correr en la que empieza (el derecho apoyando).
    D['Frenada']['cinta']['fase_inicial'] = round(fase_f(0.0) % 1.0, 4)
    # GIROS en el lugar hacia su izquierda (la vista pone el rumbo del
    # arranque y el clip gira la cadera; "giro" en avance_locomocion.json).
    # 90: abre el izquierdo, pivotea sobre la punta del derecho y lo trae.
    L0, R0 = (0.15, 0.0), (-0.15, 0.0)
    D['Giro_90_Izq'] = dict(contacto=None, aerea=False, **_giro_en_el_lugar(2, [
        (0, 0), (0.06, 4), (0.22, 50), (0.40, 88), (0.5, 90)], {
        'L': [dict(on=-9, off=0.06, pos=L0, yaw=0.0), dict(on=0.22, off=9, pos=_rot2(L0, 85), yaw=80.0)],
        'R': [dict(on=-9, off=0.26, pos=R0, yaw=0.0, pivote=(0.06, 0.24, 40.0)),
              dict(on=0.42, off=9, pos=_rot2(R0, 90), yaw=90.0)]}, 1))
    # 180: cuatro pasos, cada pie gira unos 60 grados por paso.
    D['Giro_180_Izq'] = dict(contacto=None, aerea=False, **_giro_en_el_lugar(3, [
        (0, 0), (0.05, 4), (0.20, 55), (0.38, 115), (0.54, 160), (0.66, 178), (0.75, 180)], {
        'L': [dict(on=-9, off=0.05, pos=L0, yaw=0.0), dict(on=0.20, off=0.36, pos=_rot2(L0, 75), yaw=85.0),
              dict(on=0.54, off=9, pos=_rot2(L0, 180), yaw=175.0)],
        'R': [dict(on=-9, off=0.24, pos=R0, yaw=0.0, pivote=(0.05, 0.22, 45.0)),
              dict(on=0.40, off=0.52, pos=_rot2(R0, 125), yaw=125.0),
              dict(on=0.66, off=9, pos=_rot2(R0, 180), yaw=180.0)]}, 1))
    # MEDIA VUELTA corriendo, hacia su izquierda. El cuerpo del motor da la
    # vuelta frenando en linea recta (giro_acel), pasa por 0 y sale al reves:
    # frena con dos apoyos largos, gira 180 en dos pasos casi parado (el
    # derecho pivotea sobre la punta) y sale corriendo al reves. Antes se
    # veia Correr_Espaldas con el modelo girando y el pie barria el piso.
    # Frena en 1 m del juego (la vista lo empieza a esa distancia de parar) y
    # vuelve con la misma aceleracion.
    frenado = 1.0 / ESCALA_JUEGO
    acel = V_CORRER * V_CORRER / (2 * frenado); t_s = V_CORRER / acel

    def x_vuelta(t):
        if t <= 0: return V_CORRER * t
        if t <= t_s: return V_CORRER * t - acel * t * t / 2
        return frenado - acel * (t - t_s) ** 2 / 2

    def en(tc, costado, grados):
        """Tobillo en el medio de un apoyo: debajo del cuerpo, al costado, girado."""
        return Vector((0.0, -x_vuelta(tc))) + _rot2((costado, 0.0), grados)
    plan = {
        'L': [dict(on=-0.50, off=-0.34, pos=en(-0.42, 0.10, 0), yaw=0.0),
              dict(on=0.38, off=0.62, pos=en(0.50, 0.12, 0), yaw=0.0),
              dict(on=0.84, off=1.00, pos=en(0.92, 0.13, 75), yaw=85.0),
              dict(on=1.16, off=1.28, pos=en(1.22, 0.13, 180), yaw=180.0),
              dict(on=1.62, off=1.70, pos=en(1.66, 0.10, 180), yaw=180.0),
              dict(on=2.02, off=2.08, pos=en(2.05, 0.10, 180), yaw=180.0)],
        'R': [dict(on=-1.00, off=-0.84, pos=en(-0.92, -0.10, 0), yaw=0.0),
              dict(on=0.0, off=0.16, pos=en(0.08, -0.10, 0), yaw=0.0),
              dict(on=0.66, off=0.96, pos=en(0.75, -0.14, 0), yaw=0.0, pivote=(0.78, 0.94, 45.0)),
              dict(on=1.10, off=1.22, pos=en(1.16, -0.13, 125), yaw=125.0),
              dict(on=1.40, off=1.50, pos=en(1.45, -0.10, 180), yaw=180.0),
              dict(on=1.83, off=1.89, pos=en(1.86, -0.10, 180), yaw=180.0)]}
    fase_v = _fase_por_pisadas(plan)
    yaw_v = _curva([(0, 0), (0.72, 0), (0.86, 40), (1.0, 95), (1.12, 140), (1.24, 172), (1.34, 180), (1.75, 180)])

    def arriba_vuelta(t):
        freno = dict(POLOS, tp=-6, hp=-10, ty=0, hz=0, hy=0, tr=0, gL=(0.5, -0.28, 0.8), gR=(-0.5, -0.28, 0.8))
        gira = _tronco(LISTO)
        A = _mezcla(_tronco(carrera(fase_v(t))), freno, _suave((t - 0.1) / 0.4))
        A = _mezcla(A, gira, _suave((t - 0.6) / 0.25))
        A = _mezcla(A, _tronco(carrera(fase_v(t)), tp=22), _suave((t - 1.2) / 0.3))
        A['hz'] = A.get('hz', 0.0) + 30 * math.sin(math.pi * min(max((t - 0.62) / 0.5, 0.0), 1.0))
        return A

    def alto_vuelta(t):
        return _alto_correr(fase_v(t)) + (0.53 - _alto_correr(fase_v(t))) * (
            _suave((t - 0.6) / 0.2) - _suave((t - 1.2) / 0.2))
    D['Media_Vuelta_Izq'] = dict(contacto=None, aerea=False, **_clip_cinta(
        7, lambda t: (Vector((0.0, -x_vuelta(t))), yaw_v(t)), plan, alto_vuelta, arriba_vuelta, 0.22))
    D['Media_Vuelta_Izq']['cinta']['metros_frenado'] = round(frenado * ESCALA_JUEGO, 4)
    D['Media_Vuelta_Izq']['cinta']['fase_final'] = round(fase_v(7 * TICK / FPS) % 1.0, 4)
    # Empieza como Frenada: el derecho apoyando. La vista la arranca cuando
    # Correr pasa por esa fase y no funde dos pasos distintos.
    D['Media_Vuelta_Izq']['cinta']['fase_inicial'] = round(fase_v(0.0) % 1.0, 4)
    # Los del otro lado, espejados.
    for izq, der in (('Correr_Costado_Izq', 'Correr_Costado_Der'), ('Giro_90_Izq', 'Giro_90_Der'),
                     ('Giro_180_Izq', 'Giro_180_Der'), ('Media_Vuelta_Izq', 'Media_Vuelta_Der')):
        c = dict(D[izq]['cinta']); c['giro'] = -c['giro']; c['direccion'] = [-c['direccion'][0], c['direccion'][1]]
        if 'giro_por_cuadro' in c:
            c['giro_por_cuadro'] = [-g for g in c['giro_por_cuadro']]
        # Espejado cambia de pie: la fase de Correr corre medio ciclo.
        for k in ('fase_inicial', 'fase_final'):
            if k in c:
                c[k] = round((c[k] + 0.5) % 1.0, 4)
        D[der] = dict(D[izq], claves=[(f, espejar(P)) for f, P in D[izq]['claves']], cinta=c)
    return D


# ---------------------------------------------------------------- definiciones
def espejar(P):
    """La pose del otro lado: izquierda <-> derecha (el personaje mira a -Y, su
    izquierda es +X). Cambia los parametros de cada pierna y brazo, da vuelta la X
    de manos, polos y cadera, y el signo de los giros de costado."""
    Q = {}
    for k, v in P.items():
        if len(k) >= 2 and k[-1] in 'LR' and k[:-1] in ('t', 'k', 'f', 'ab', 'y', 'tw', 'g', 'p', 'qp'):
            k2 = k[:-1] + ('R' if k[-1] == 'L' else 'L')
            if k[:-1] in ('g', 'p'):
                v = (-v[0], v[1], v[2])
            elif k[:-1] == 'qp':
                # Espejar en X: el giro sobre X queda, los de Y y Z cambian de signo.
                v = (v[0], v[1], -v[2], -v[3])
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
    # TROTAR y CAMINAR (los pasos del partido por debajo del pique) y CORRER:
    # en definiciones_locomocion(), en cinta.
    def loop_de(f, n=8, **kw):
        return [(1 + i * 3, f(i / n, **kw)) for i in range(n + 1)]
    # FORCEJEAR: corre hombro con hombro con el rival que tiene a su derecha:
    # se inclina hacia el, el brazo derecho abierto contra su cuerpo y mira
    # la pelota. La de la izquierda es la misma espejada.
    def forcejeo(p):
        P = ciclo(p, muslo=30, rodilla=58, vuelo=0.02, torso=10, brazo=30)
        P.update(tr=-9, hz=-12, gR=(-0.66, -0.02, 0.9), pR=(-0.3, 0.3, -1))
        return P
    D['Forcejear'] = dict(ticks=4, contacto=None, aerea=False, bucle=True, claves=loop_de(forcejeo))
    D['Forcejear_Izq'] = dict(D['Forcejear'], claves=[(f, espejar(P)) for f, P in D['Forcejear']['claves']])
    # RESPIRAR: loop de 2 s (la pose en respira(), afuera: la usan los clips en cinta).
    D['Respirar'] = dict(ticks=8, contacto=None, aerea=False, bucle=True, claves=[
        (1, respira(0, 0.3)), (13, respira(1, 0.0)), (25, respira(0, -0.3)), (37, respira(1, 0.0)), (49, respira(0, 0.3))])
    D.update(definiciones_locomocion())
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
        'Pie_R': ('Pie.R', tail('Pie.R') + PUNTA_PIE),
        'Pie_L': ('Pie.L', tail('Pie.L') + PUNTA_PIE),
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
        act = construir(nombre, d['claves'])
        if d.get('cinta'):
            # Una clave por cuadro y lineal entre claves, como lo dibuja Godot
            # (el GLB se muestrea por cuadro): con Bezier el pie apoyado se
            # mecia entre dos cuadros.
            lineal(act)
        # En cinta el pie apoyado ya pisa justo el piso: subir la cadera en un
        # cuadro lo despegaria y volveria a patinar.
        hechas[nombre] = 0 if d.get('cinta') else asentar(nombre, d)
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


def locomocion_cinta():
    """Nombres de los clips en cinta (los que arma _clip_cinta)."""
    return [n for n, d in definiciones_locomocion().items() if d.get('cinta')]


def escribir_avance(ruta):
    """Lo que la vista necesita para avanzar cada clip en cinta con los metros
    reales: metros del juego en cada cuadro (avance_m), hacia donde ([x a su
    izquierda, z adelante]) y cuanto gira (grados, + = a su izquierda). Lo lee
    tools/generar_acciones_v2.py y lo pasa a data/acciones_v2.json."""
    import json
    out = {n: {k: v for k, v in d['cinta'].items() if k != 'error_ik'}
           for n, d in definiciones_locomocion().items() if d.get('cinta')}
    with open(ruta, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(out, f, indent=1, sort_keys=True)
        f.write('\n')
    return sorted(out)


def medir_cinta(nombre, d=None, sub=3):
    """Lo mismo que DetectorPatinaV2 (Godot) pero en Blender: cuanto desliza en
    la cancha la punta del pie (ancla Pie_L/R) mientras esta a menos de 1,5 cm
    del juego de su punto mas bajo, con el cuerpo avanzando lo que dice
    avance_m. Mide `sub` veces por cuadro (el detector va a 60 Hz): de a un
    cuadro, el ultimo cuadro en el aire de cada paso contaba entero.
    Metros y m/s del juego."""
    arm, ad, R3 = _ctx(); d = d or definiciones_locomocion()[nombre]; c = d['cinta']
    arm.animation_data_create(); arm.animation_data.action = bpy.data.actions[nombre]
    sc = bpy.context.scene; n = d['ticks'] * TICK
    dvec = Vector((c['direccion'][0], -c['direccion'][1]))
    pts = {s: [] for s in 'LR'}
    for i in range(n * sub + 1):
        f, frac = 1 + i // sub, (i % sub) / sub
        sc.frame_set(f, subframe=frac)
        a0 = c['avance_m'][f - 1]; a1 = c['avance_m'][min(f, n)]
        cuerpo = dvec * ((a0 + (a1 - a0) * frac) / ESCALA_JUEGO)
        for s in 'LR':
            w = bpy.data.objects['Pie_' + s].matrix_world.translation
            pts[s].append(Vector((w.x + cuerpo.x, w.y + cuerpo.y, w.z)))
    arm.animation_data.action = None
    suelo = min(p.z for s in 'LR' for p in pts[s])
    desliza = 0.0; cuadros = 0
    for s in 'LR':
        for a, b in zip(pts[s], pts[s][1:]):
            if min(a.z, b.z) <= suelo + 0.015 / ESCALA_JUEGO:
                desliza += (b - a).to_2d().length; cuadros += 1
    desliza *= ESCALA_JUEGO
    dur = n / FPS
    r = dict(nombre=nombre, desliza_m=round(desliza, 4), avance_m=round(c['metros'], 3), giro=c['giro'],
             error_ik_mm=round(c['error_ik'] * ESCALA_JUEGO * 1000, 2),
             pie_ms=round(desliza / max(cuadros / (FPS * sub), 1e-6), 3), cuerpo_ms=round(abs(c['metros']) / dur, 3))
    r['relacion'] = round(r['pie_ms'] / r['cuerpo_ms'], 3) if r['cuerpo_ms'] > 0 else None
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
