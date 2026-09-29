"""
Peinados del chibi 3D (jugador y golero). Cada peinado es una malla aparte pegada al hueso Cabeza,
con material Pelo (+ Contorno) y la propiedad 'peinado' = su numero. exportar_juego3d.py los mete
todos en el GLB y Godot (Jugador3D) muestra solo el del jugador.
Uso (desde Blender, con el .blend abierto):
    exec(open(r"...peinados.py").read()); construir_peinados(); mostrar(n)
  construir_peinados() borra y vuelve a armar los peinados 2..9 (el 0 es la malla 'Pelo' original,
  el 1 es pelado: sin malla). mostrar(n) deja visible solo el peinado n (para renders).
"""
import bpy, bmesh, math
from mathutils import Vector, Matrix, Quaternion, noise

PEINADOS = ['puntas', 'pelado', 'rapado', 'mohicano', 'afro', 'jopo', 'raya', 'rulos', 'hongo', 'alto']
# Centro de la cabeza y frente (-Y) en Blender, con el esqueleto en reposo.
C = Vector((0.0, -0.056, 1.542))
HUNDE = 0.014  # lo que se mete adentro de la piel el borde del casquete (el corte no se ve)
OREJA = [Vector((0.555, -0.02, 1.45)), Vector((-0.555, -0.02, 1.45))]


def _ss(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def _ang(p):
    """(u, lado): u 0 = frente, 1 = nuca (por el costado); lado = x normalizado."""
    d = p - C
    th = math.atan2(d.x, -d.y)
    return (1 - math.cos(th)) / 2, d.x


def _linea(p, zf, zl, zb, patilla=0.0):
    """Altura del nacimiento del pelo en la direccion de p: zf al frente, zl al costado, zb en la nuca."""
    u, _x = _ang(p)
    if u < 0.5:
        z = zf + (zl - zf) * _ss(0.0, 0.5, u)
    else:
        z = zl + (zb - zl) * _ss(0.5, 1.0, u)
    # patilla adelante de la oreja
    if patilla:
        z -= patilla * math.exp(-((u - 0.40) / 0.06) ** 2)
    return z


def _oreja(p):
    return min((p - o).length for o in OREJA)


def _cabeza(nivel):
    cab = bpy.data.objects['Cabeza']
    sub = cab.modifiers.get('Subdivision'); con = cab.modifiers.get('Contorno')
    viejo = (sub.levels, con.show_viewport)
    sub.levels = nivel; con.show_viewport = False
    dg = bpy.context.evaluated_depsgraph_get(); dg.update()
    me = bpy.data.meshes.new_from_object(cab.evaluated_get(dg), depsgraph=dg)
    sub.levels = viejo[0]; con.show_viewport = viejo[1]
    me.transform(cab.matrix_world)
    return me


def casquete(bm, m_de, alto_de, nivel=1, banda=0.05, extra=None):
    """Agrega a bm la piel de la cabeza donde m_de(p) > -banda, corrida por la normal:
    alto_de(p, n) adentro (m >= banda) y -HUNDE afuera, con transicion suave.
    extra(p, n, peso) -> Vector: corrimiento adicional (peso = cuanto es pelo)."""
    me = _cabeza(nivel)
    b2 = bmesh.new(); b2.from_mesh(me); bpy.data.meshes.remove(me)
    b2.normal_update()
    ms = {v: m_de(v.co) for v in b2.verts}
    bmesh.ops.delete(b2, geom=[f for f in b2.faces if max(ms[v] for v in f.verts) < -banda], context='FACES')
    bmesh.ops.delete(b2, geom=[v for v in b2.verts if not v.link_faces], context='VERTS')
    nuevos = []
    for v in b2.verts:
        p = v.co.copy(); n = v.normal.copy(); w = _ss(-banda, banda, ms[v])
        d = n * (alto_de(p, n) * w - HUNDE * (1 - w))
        if extra:
            d += extra(p, n, w)
        nuevos.append((v, p + d))
    for v, q in nuevos:
        v.co = q
    tmp = bpy.data.meshes.new('_tmp'); b2.to_mesh(tmp); b2.free()
    bm.from_mesh(tmp); bpy.data.meshes.remove(tmp)


def _pieza(bm, fn, M):
    """fn(b) crea geometria en un bmesh nuevo; se transforma por M y se agrega a bm."""
    b2 = bmesh.new(); fn(b2); bmesh.ops.transform(b2, matrix=M, verts=b2.verts)
    tmp = bpy.data.meshes.new('_tmp'); b2.to_mesh(tmp); b2.free()
    bm.from_mesh(tmp); bpy.data.meshes.remove(tmp)


def punta(bm, base, direc, largo, ancho, aplaste=1.0, segs=6, rot=0.0):
    """Cono de base 'base' hacia 'direc'. aplaste < 1 lo achata en su X local."""
    q = Vector((0, 0, 1)).rotation_difference(direc.normalized())
    M = Matrix.Translation(base) @ q.to_matrix().to_4x4() @ Matrix.Rotation(rot, 4, 'Z') \
        @ Matrix.Diagonal((aplaste, 1, 1, 1)) @ Matrix.Translation((0, 0, largo / 2))
    _pieza(bm, lambda b: bmesh.ops.create_cone(b, cap_ends=True, segments=segs, radius1=ancho,
                                               radius2=0.0, depth=largo), M)


def bola(bm, centro, r, esc=(1, 1, 1), segs=8, anillos=6):
    M = Matrix.Translation(centro) @ Matrix.Diagonal((*esc, 1))
    _pieza(bm, lambda b: bmesh.ops.create_uvsphere(b, u_segments=segs, v_segments=anillos, radius=r), M)


def mechon(bm, puntos, anchos, grosores, lados=6, arriba=None):
    """Mechon: tubo achatado por la polilinea 'puntos' que termina en punta. anchos/grosores por punto
    (el ultimo se ignora: es la punta). El grosor va hacia afuera de la cabeza (desde C) o 'arriba'."""
    pts = [Vector(p) for p in puntos]; n = len(pts)
    anillos = []
    for i in range(n - 1):
        t = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        up = (arriba if arriba is not None else (pts[i] - C)).normalized()
        nn = (up - t * up.dot(t)).normalized(); b = t.cross(nn)
        anillo = []
        for j in range(lados):
            a = 2 * math.pi * j / lados
            anillo.append(bm.verts.new(pts[i] + b * anchos[i] * math.cos(a) + nn * grosores[i] * math.sin(a)))
        anillos.append(anillo)
    tip = bm.verts.new(pts[-1])
    bm.faces.new(list(reversed(anillos[0])))
    for i in range(len(anillos) - 1):
        a0, a1 = anillos[i], anillos[i + 1]
        for j in range(lados):
            bm.faces.new((a0[j], a0[(j + 1) % lados], a1[(j + 1) % lados], a1[j]))
    a0 = anillos[-1]
    for j in range(lados):
        bm.faces.new((a0[j], a0[(j + 1) % lados], tip))


def _curva(ctrl, pasos):
    """Catmull-Rom por los puntos de control -> 'pasos' puntos."""
    P = [Vector(c) for c in ctrl]; P = [P[0]] + P + [P[-1]]; out = []
    for k in range(pasos):
        s = k / (pasos - 1) * (len(ctrl) - 1); i = min(int(s), len(ctrl) - 2); t = s - i
        p0, p1, p2, p3 = P[i], P[i + 1], P[i + 2], P[i + 3]
        out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                          + (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t))
    return out


def _en_cabeza(dir_, altura=0.0):
    """Punto de la piel de la cabeza en la direccion dir_ desde C (+ altura por la normal) y normal."""
    cab = bpy.data.objects['Cabeza']
    if '_bvh' not in bpy.app.driver_namespace:
        from mathutils.bvhtree import BVHTree
        me = _cabeza(1); bm = bmesh.new(); bm.from_mesh(me); bpy.data.meshes.remove(me)
        bpy.app.driver_namespace['_bvh'] = BVHTree.FromBMesh(bm); bm.free()
    bvh = bpy.app.driver_namespace['_bvh']
    loc, nor, i, dist = bvh.ray_cast(C + dir_.normalized() * 2.0, -dir_.normalized())
    if loc is None:
        return C + dir_.normalized() * 0.5, dir_.normalized()
    return loc + nor * altura, nor


def _dir(elev, az):
    """elev: 0 horizonte, 90 arriba. az: 0 frente (-Y), 90 izquierda del jugador (+X), 180 nuca."""
    e, a = math.radians(elev), math.radians(az)
    return Vector((math.cos(e) * math.sin(a), -math.cos(e) * math.cos(a), math.sin(e)))


# ---------------------------------------------------------------- peinados

def _sobre(ctrl, pasos=7):
    """Puntos de un mechon dados como (elevacion, azimut, altura sobre la piel)."""
    return _curva([_en_cabeza(_dir(e, a), h)[0] for e, a, h in ctrl], pasos)


def p_rapado(bm):
    # Pelo al ras: la forma de la cabeza con el nacimiento marcado (entradas y patillas cortas).
    def m(p):
        u, x = _ang(p)
        z = _linea(p, 1.735, 1.575, 1.22, patilla=0.07)
        z += 0.035 * math.exp(-((u - 0.14) / 0.07) ** 2)  # entradas
        return (p.z - z) + min(0.0, _oreja(p) - 0.15)
    casquete(bm, m, lambda p, n: 0.022, banda=0.03)


def p_mohicano(bm):
    # Costados al ras de piel (sin pelo), una franja al medio y una cresta de puntas hacia atras.
    def m(p):
        return (0.11 - abs(p.x)) + min(0.0, p.z - 1.70 + max(0.0, p.y) * 1.2)
    casquete(bm, m, lambda p, n: 0.04, banda=0.035)
    n_p = 7
    for i in range(n_p):
        t = i / (n_p - 1)
        ang = math.radians(30 + 165 * t)          # de la frente a la nuca, pasando por arriba
        base, nor = _en_cabeza(Vector((0, -math.cos(ang), math.sin(ang))), 0.0)
        alto = 0.14 + 0.24 * math.sin(math.pi * (0.2 + 0.7 * t))
        inclina = (nor + Vector((0, 0.7, 0.1))).normalized()
        punta(bm, base - nor * 0.04, inclina, alto + 0.04, 0.15, aplaste=0.4, segs=8)


def p_afro(bm):
    # Volumen grande y redondo, hecho de bollos grandes sobre un casco alto.
    def m(p):
        return (p.z - _linea(p, 1.72, 1.50, 1.26)) + min(0.0, _oreja(p) - 0.12)

    def alto(p, n):
        d = p - C
        g = 0.10 + 0.14 * _ss(-0.05, 0.40, d.z)
        return g * (0.3 + 0.7 * _ss(0.0, 0.2, m(p)))
    casquete(bm, m, alto, nivel=1, banda=0.05)
    N = 90; ga = math.pi * (3 - math.sqrt(5))
    for i in range(N):
        zz = 1 - 2 * (i + 0.5) / N
        r = math.sqrt(1 - zz * zz); th = ga * i
        base, nor = _en_cabeza(Vector((r * math.cos(th), r * math.sin(th), zz)), 0.0)
        mm = m(base)
        if mm < 0.02:
            continue
        h = alto(base, nor)
        rr = (0.075 + 0.05 * _ss(0.0, 0.25, mm)) * (1 + 0.15 * noise.noise(base * 8.0))
        bola(bm, base + nor * (h - rr * 0.35), rr, segs=7, anillos=4)


def p_jopo(bm):
    # Costados cortos y un jopo ancho adelante: sube desde la frente, sale hacia adelante y baja
    # de a poco hacia la coronilla.
    def m(p):
        return (p.z - _linea(p, 1.74, 1.57, 1.24, patilla=0.06)) + min(0.0, _oreja(p) - 0.15)

    def extra(p, n, w):
        d = p - C
        ancho = 1 - _ss(0.26, 0.46, abs(d.x))
        arriba = _ss(0.10, 0.30, d.z)
        atras = 1 - _ss(-0.30, 0.30, d.y)              # 1 adelante, 0 en la coronilla
        k = ancho * arriba
        sube = 0.25 * atras * k
        adelante = 0.13 * (1 - _ss(-0.5, -0.1, d.y)) * k
        surcos = 0.018 * math.sin(d.x * 30) * k * atras  # mechones marcados
        return Vector((0, -adelante, sube + surcos)) * w
    casquete(bm, m, lambda p, n: 0.035, nivel=1, banda=0.03, extra=extra)


def p_raya(bm):
    # Raya al costado: casco corto y mechones que cruzan la frente de un lado al otro.
    def m(p):
        return (p.z - _linea(p, 1.74, 1.57, 1.24, patilla=0.07)) + min(0.0, _oreja(p) - 0.14)
    casquete(bm, m, lambda p, n: 0.05, banda=0.03)
    cruzan = [[(45, 22, 0.03), (40, -8, 0.08), (27, -30, 0.08), (12, -44, 0.03)],
              [(64, 30, 0.03), (58, -10, 0.09), (40, -48, 0.09), (18, -70, 0.03)],
              [(80, 70, 0.03), (76, -30, 0.09), (56, -82, 0.09), (32, -108, 0.03)],
              [(78, 150, 0.03), (70, -140, 0.07), (45, -130, 0.06), (25, -128, 0.02)]]
    otro = [[(55, 32, 0.03), (46, 56, 0.07), (30, 76, 0.03)],
            [(75, 95, 0.03), (56, 104, 0.07), (36, 118, 0.03)]]
    for c in cruzan:
        mechon(bm, _sobre(c, 8), [0.14] * 8, [0.06] * 8, lados=6)
    for c in otro:
        mechon(bm, _sobre(c, 6), [0.10] * 6, [0.05] * 6, lados=6)


def p_rulos(bm):
    # Rulos cortos: base al ras y bolitas por toda la cabeza.
    def m(p):
        return (p.z - _linea(p, 1.72, 1.56, 1.26)) + min(0.0, _oreja(p) - 0.14)
    casquete(bm, m, lambda p, n: 0.04, banda=0.03)
    # puntos repartidos (espiral de Fibonacci)
    N = 120; ga = math.pi * (3 - math.sqrt(5)); hechos = 0
    for i in range(N):
        zz = 1 - 2 * (i + 0.5) / N
        r = math.sqrt(1 - zz * zz); th = ga * i
        dirv = Vector((r * math.cos(th), r * math.sin(th), zz))
        base, nor = _en_cabeza(dirv, 0.0)
        if m(base) < 0.035:
            continue
        rr = 0.07 + 0.012 * noise.noise(base * 9.0)
        bola(bm, base + nor * 0.035, rr, segs=7, anillos=4)
        hechos += 1
    return hechos


def p_hongo(bm):
    # Taza: casco redondo con flequillo recto y corte horizontal alrededor.
    def m(p):
        u, x = _ang(p)
        z = 1.615 + (1.43 - 1.615) * _ss(0.28, 0.55, u)
        return (p.z - z)

    def alto(p, n):
        d = p - C
        return 0.075 + 0.02 * _ss(0.0, 0.4, d.z)

    def extra(p, n, w):
        # el borde de abajo sale un poco para afuera (casco)
        d = p - C; lado = Vector((d.x, d.y, 0)).normalized()
        return lado * 0.02 * w
    casquete(bm, m, alto, nivel=1, banda=0.018, extra=extra)


def p_alto(bm):
    # Alto y plano arriba (flat top) con costados cortos.
    def m(p):
        return (p.z - _linea(p, 1.73, 1.57, 1.24, patilla=0.06)) + min(0.0, _oreja(p) - 0.15)

    def extra(p, n, w):
        d = p - C
        # lo de arriba sube hasta una tapa plana, un poco mas ancha arriba
        r = math.hypot(d.x, d.y + 0.02)
        k = _ss(0.08, 0.30, d.z) * (1 - _ss(0.38, 0.50, r))
        sube = max(0.0, C.z + 0.56 - 0.08 * _ss(0.2, 0.46, r) - p.z) * k
        abre = Vector((d.x, d.y + 0.02, 0)) * 0.12 * k * _ss(0.0, 0.3, sube)
        return (Vector((0, 0, sube)) + abre) * w
    casquete(bm, m, lambda p, n: 0.03, nivel=1, banda=0.03, extra=extra)


CONSTRUCTORES = {2: p_rapado, 3: p_mohicano, 4: p_afro, 5: p_jopo, 6: p_raya, 7: p_rulos, 8: p_hongo, 9: p_alto}


def _nombre(k):
    return 'Pelo' if k == 0 else 'Pelo_%d_%s' % (k, PEINADOS[k])


def construir_peinados(solo=None):
    arm = bpy.data.objects['Esqueleto']; pelo = bpy.data.objects['Pelo']
    viejo = arm.data.pose_position; arm.data.pose_position = 'REST'
    bpy.context.view_layer.update()
    bpy.app.driver_namespace.pop('_bvh', None)
    pelo['peinado'] = 0
    hechos = {}
    try:
        for k, fn in CONSTRUCTORES.items():
            if solo is not None and k not in solo:
                continue
            nom = _nombre(k)
            ob = bpy.data.objects.get(nom)
            if ob:
                me_v = ob.data; bpy.data.objects.remove(ob); bpy.data.meshes.remove(me_v)
            bm = bmesh.new(); fn(bm)
            bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            me = bpy.data.meshes.new(nom); bm.to_mesh(me); bm.free()
            me.transform(pelo.matrix_world.inverted())
            for poly in me.polygons: poly.use_smooth = True
            me.materials.append(bpy.data.materials['Pelo']); me.materials.append(bpy.data.materials['Contorno'])
            ob = bpy.data.objects.new(nom, me)
            for col in pelo.users_collection: col.objects.link(ob)
            ob.parent = arm; ob.parent_type = 'BONE'; ob.parent_bone = 'Cabeza'
            ob.matrix_parent_inverse = pelo.matrix_parent_inverse.copy(); ob.location = (0, 0, 0)
            ob['peinado'] = k
            s = ob.modifiers.new('Subdivision', 'SUBSURF'); s.levels = 1; s.render_levels = 1
            c0 = pelo.modifiers['Contorno']; c = ob.modifiers.new('Contorno', 'SOLIDIFY')
            for a in ('thickness', 'offset', 'use_flip_normals', 'material_offset', 'material_offset_rim',
                      'use_rim', 'use_even_offset', 'use_quality_normals'):
                setattr(c, a, getattr(c0, a))
            hechos[nom] = len(me.polygons)
    finally:
        arm.data.pose_position = viejo
        bpy.context.view_layer.update()
    return hechos


def peinados_en_escena():
    return {o['peinado']: o for o in bpy.data.objects if o.type == 'MESH' and 'peinado' in o}


def mostrar(n):
    """Deja visible (vista y render) solo el peinado n. n = None muestra todos (para exportar)."""
    for k, o in peinados_en_escena().items():
        ver = n is None or k == n
        o.hide_set(not ver); o.hide_render = not ver; o.hide_viewport = False
