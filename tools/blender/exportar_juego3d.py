"""
Exporta los modelos chibi a GLB listos para un motor 3D en tiempo real.
Uso (desde Blender, con el .blend abierto):  exec(open(r"...exportar_juego3d.py").read()); exportar("jugador"|"golero"|"pelota"|"estadio", carpeta)
NO guarda el .blend: trabaja sobre la copia en memoria. Volve a abrir el archivo despues si queres seguir editando.

Que hace:
  - saca el Subdivision (low poly), deja el contorno (Solidify invertido = "inverted hull", funciona en cualquier motor
    con backface culling: material "Contorno" es de una sola cara)
  - vuelve a pegar ojos/boca/cachetes sobre la cabeza low poly
  - convierte curvas (ojos, lineas) a malla
  - reemplaza los materiales toon de Blender por materiales PBR simples con el mismo nombre y color base
    (el toon se hace en el motor con un shader; los nombres sirven para cambiar colores de equipo)
  - exporta todas las acciones como animaciones (arrancan en t=0; los loops terminan igual que empiezan)
"""
import bpy, math, os
from mathutils import Vector
from mathutils.bvhtree import BVHTree

FACE = {'Ojos': 0.012, 'Boca': 0.004, 'Boca_Linea': 0.006, 'Lengua': 0.007, 'Cachetes': 0.005}


def _color_of(m):
    nt = m.node_tree if m.use_nodes else None
    if nt and 'Color' in nt.nodes and nt.nodes['Color'].type == 'RGB':
        return tuple(nt.nodes['Color'].outputs[0].default_value)[:3]
    if nt:
        for n in nt.nodes:
            if n.type == 'EMISSION':
                return tuple(n.inputs['Color'].default_value)[:3]
    return tuple(m.diffuse_color)[:3]


def convert_materials(alpha=None, extra=None):
    """extra(nombre, material_nuevo, material_viejo) permite ajustes especiales (texturas, etc.)"""
    alpha = alpha or {}
    for m in list(bpy.data.materials):
        if m.users == 0 or m.name.endswith('_toon'):
            continue
        col = _color_of(m); a = alpha.get(m.name, 1.0); cull = m.use_backface_culling
        name = m.name; m.name = name + '_toon'
        g = bpy.data.materials.new(name); g.use_nodes = True
        bs = g.node_tree.nodes.get('Principled BSDF')
        bs.inputs['Base Color'].default_value = (*col, 1)
        bs.inputs['Roughness'].default_value = 1.0; bs.inputs['Metallic'].default_value = 0.0
        if 'Specular IOR Level' in bs.inputs:
            bs.inputs['Specular IOR Level'].default_value = 0.0
        if a < 1.0:
            bs.inputs['Alpha'].default_value = a; g.surface_render_method = 'BLENDED'
        g.use_backface_culling = cull; g.diffuse_color = (*col, a)
        if extra:
            extra(name, g, m)
        m.user_remap(g)


def reproject_face(head_name, items):
    head = bpy.data.objects[head_name]
    ol = head.modifiers.get('Contorno')
    if ol: ol.show_viewport = False
    dg = bpy.context.evaluated_depsgraph_get(); dg.update()
    bvh = BVHTree.FromObject(head.evaluated_get(dg), dg)
    if ol: ol.show_viewport = True
    Mh = head.matrix_world; Mhi = Mh.inverted(); dy = (Mhi.to_3x3() @ Vector((0, 1, 0))).normalized()

    def fix(pw, off):
        loc, nor, i, d = bvh.ray_cast(Mhi @ Vector((pw.x, pw.y - 3, pw.z)), dy)
        return pw if loc is None else Mh @ (loc + nor.normalized() * off)

    for n, off in items.items():
        ob = bpy.data.objects.get(n)
        if not ob: continue
        Mw = ob.matrix_world; Mwi = Mw.inverted()
        if ob.type == 'MESH':
            for v in ob.data.vertices: v.co = Mwi @ fix(Mw @ v.co, off)
            ob.data.update()
        elif ob.type == 'CURVE':
            for sp in ob.data.splines:
                for pt in sp.points:
                    pt.co = (*(Mwi @ fix(Mw @ Vector(pt.co[:3]), off)), 1)


def _contexto(**kw):
    """temp_override con la ventana de Blender si hay. Sin pantalla (blender -b)
    no hay ventanas y los operadores andan igual sin ella."""
    wins = bpy.context.window_manager.windows
    if wins:
        kw['window'] = wins[0]
    return bpy.context.temp_override(**kw)


def curves_to_mesh():
    for o in [o for o in bpy.data.objects if o.type == 'CURVE' and o.visible_get()]:
        o.data.bevel_resolution = 1; o.data.resolution_u = 6
        with _contexto(active_object=o, selected_objects=[o], selected_editable_objects=[o], object=o):
            bpy.ops.object.convert(target='MESH')


def drop_subdivision():
    for o in bpy.data.objects:
        if o.type == 'MESH':
            s = o.modifiers.get('Subdivision')
            if s: o.modifiers.remove(s)


def rest_pose():
    for arm in [o for o in bpy.data.objects if o.type == 'ARMATURE']:
        if arm.animation_data: arm.animation_data.action = None
        for pb in arm.pose.bones:
            pb.rotation_quaternion = (1, 0, 0, 0); pb.location = (0, 0, 0)
    bpy.context.view_layer.update()


def tri_count():
    dg = bpy.context.evaluated_depsgraph_get(); tot = 0; per = {}
    for o in bpy.data.objects:
        if o.type != 'MESH' or not o.visible_get(): continue
        ev = o.evaluated_get(dg); me = ev.to_mesh(); me.calc_loop_triangles()
        per[o.name] = len(me.loop_triangles); tot += per[o.name]; ev.to_mesh_clear()
    return tot, per


def export_glb(path, animations=True, colores='MATERIAL'):
    wins = bpy.context.window_manager.windows
    if wins:
        win = wins[0]
        area = next((a for a in win.screen.areas if a.type == 'VIEW_3D'), win.screen.areas[0])
        ctx = bpy.context.temp_override(window=win, area=area, scene=win.scene, view_layer=win.view_layer)
    else:
        ctx = bpy.context.temp_override()
    with ctx:
        bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_visible=True, export_apply=True,
                                  export_animations=animations, export_animation_mode='ACTIONS',
                                  export_anim_slide_to_zero=True, export_skins=True, export_yup=True,
                                  export_materials='EXPORT', export_cameras=False, export_lights=False,
                                  export_vertex_color=colores)


def prep_character():
    rest_pose(); drop_subdivision(); bpy.context.view_layer.update()
    head = [o.name for o in bpy.data.objects if o.type == 'MESH' and o.name.endswith('Cabeza')][0]
    reproject_face(head, FACE)
    curves_to_mesh()
    convert_materials({'Cachetes': 0.55})
    for a in bpy.data.actions: a.use_fake_user = True


def prep_estadio():
    """Saca personajes y pelota, pasa las franjas del cesped a geometria y la red a textura con alfa."""
    import bmesh, numpy as np
    es = bpy.context.scene; M = dict(es['medidas']); hl, hw = M['largo'] / 2, M['ancho'] / 2
    for lc in bpy.context.view_layer.layer_collection.children:
        if lc.name in ('Golero', 'Jugador_Campo', 'Pelota'):
            lc.exclude = True
    c2 = tuple(bpy.data.materials['Cesped'].node_tree.nodes['Color2'].outputs[0].default_value)[:3]
    g = bpy.data.objects['Cesped']; w = M['largo'] / 18; X0, X1 = -(hl + 6), hl + 6; Y0, Y1 = -(hw + 6), hw + 6
    xs = [X0]; k = math.floor(X0 / w) + 1
    while k * w < X1:
        xs.append(k * w); k += 1
    xs.append(X1)
    bm = bmesh.new(); vb = [bm.verts.new((x, Y0, 0)) for x in xs]; vt = [bm.verts.new((x, Y1, 0)) for x in xs]
    for i in range(len(xs) - 1):
        f = bm.faces.new((vb[i], vb[i + 1], vt[i + 1], vt[i]))
        f.material_index = int(math.floor(((xs[i] + xs[i + 1]) / 2) / w)) % 2
    bm.to_mesh(g.data); bm.free()
    if len(g.data.materials) < 2:
        g.data.materials.append(None)
    cell = 0.22; N = 64; img = bpy.data.images.new('Red_Textura', N, N, alpha=True)
    px = np.zeros((N, N, 4), dtype=np.float32); t = 3; px[:, :t, :] = 1; px[:t, :, :] = 1
    img.pixels.foreach_set(px.ravel()); img.pack()
    for nm in ('Arco_Izq_Red', 'Arco_Der_Red'):
        ob = bpy.data.objects[nm]
        for m in [m for m in ob.modifiers if m.type == 'WIREFRAME']:
            ob.modifiers.remove(m)
        bm = bmesh.new(); bm.from_mesh(ob.data)
        bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(1), verts=list(bm.verts), edges=list(bm.edges))
        bmesh.ops.triangulate(bm, faces=list(bm.faces))
        uv = bm.loops.layers.uv.verify()
        for f in bm.faces:
            n = f.normal; t1 = Vector((0, 0, 1)).cross(n)
            t1 = t1.normalized() if t1.length > 1e-4 else Vector((1, 0, 0)); t2 = n.cross(t1)
            for l in f.loops:
                p = l.vert.co; l[uv].uv = (p.dot(t1) / cell, p.dot(t2) / cell)
        bm.to_mesh(ob.data); bm.free()

    def extra(name, g_new, old):
        nt = g_new.node_tree; bs = nt.nodes['Principled BSDF']
        if name == 'Arco_Red':
            tex = nt.nodes.new('ShaderNodeTexImage'); tex.image = img; tex.interpolation = 'Closest'
            rnd = nt.nodes.new('ShaderNodeMath'); rnd.operation = 'ROUND'
            nt.links.new(tex.outputs['Alpha'], rnd.inputs[0]); nt.links.new(rnd.outputs[0], bs.inputs['Alpha'])
            g_new.surface_render_method = 'DITHERED'; g_new.use_backface_culling = False
    convert_materials(extra=extra)
    c2m = bpy.data.materials.new('Cesped_2'); c2m.use_nodes = True; b = c2m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*c2, 1); b.inputs['Roughness'].default_value = 1.0
    if 'Specular IOR Level' in b.inputs:
        b.inputs['Specular IOR Level'].default_value = 0.0
    g.data.materials[1] = c2m


# Tipo de cada material del personaje unido (va en la U del UV; Godot lo lee en personaje.gdshader).
TIPOS = {'Equipo_Rojo': 1, 'Equipo_Blanco': 2, 'Pelo': 3, 'Piel': 4, 'Ojos': 5, 'Boca': 5, 'Lengua': 5,
         'Cachetes': 6, 'Contorno': 7}


def _srgb(c):
    return c * 12.92 if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def unir_personaje():
    """Une todas las mallas visibles del personaje en una sola ('Chibi') con un solo material.
    Lo que iba pegado a un hueso pasa a estar pesado 100% a ese hueso. Cada cara lleva en el color
    del vertice (sRGB) el color de su material, y en el UV (u=tipo, v=alfa) como se pinta.
    Los peinados (peinados.py, propiedad 'peinado' = k) van todos: su v es 2 + k (en glTF queda
    -1 - k) y Godot muestra solo el del jugador."""
    arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    mallas = [o for o in bpy.data.objects if o.type == 'MESH' and o.visible_get()]
    tris_antes = tri_count()[0]
    dg = bpy.context.evaluated_depsgraph_get()
    copias = []
    for o in mallas:
        arm_mod = next((m for m in o.modifiers if m.type == 'ARMATURE'), None)
        if arm_mod: arm_mod.show_viewport = False
        dg.update()
        me = bpy.data.meshes.new_from_object(o.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
        if arm_mod: arm_mod.show_viewport = True
        me.transform(o.matrix_world)
        n = len(me.loops)
        col = me.color_attributes.new('Color', 'FLOAT_COLOR', 'CORNER'); uv = me.uv_layers.new(name='Tipo')
        cols = [0.0] * (n * 4); uvs = [0.0] * (n * 2)
        peinado = o.get('peinado')
        for p in me.polygons:
            m = me.materials[p.material_index] if p.material_index < len(me.materials) else None
            bs = m.node_tree.nodes.get('Principled BSDF') if m and m.use_nodes else None
            c = bs.inputs['Base Color'].default_value if bs else (1, 1, 1, 1)
            a = bs.inputs['Alpha'].default_value if bs else 1.0
            t = TIPOS.get(m.name if m else '', 0)
            if peinado is not None:
                a = 2 + peinado
            for li in p.loop_indices:
                cols[li * 4:li * 4 + 4] = (_srgb(c[0]), _srgb(c[1]), _srgb(c[2]), 1.0)
                uvs[li * 2:li * 2 + 2] = (t, a)
        col.data.foreach_set('color', cols); uv.data.foreach_set('uv', uvs)
        c = bpy.data.objects.new(o.name + '_unir', me)
        arm.users_collection[0].objects.link(c)
        if not c.vertex_groups:
            for g in o.vertex_groups:
                c.vertex_groups.new(name=g.name)
        if o.parent_type == 'BONE':
            c.vertex_groups.new(name=o.parent_bone).add(range(len(me.vertices)), 1.0, 'REPLACE')
        copias.append(c)
    for o in mallas:
        o.hide_set(True); o.hide_render = True
    with _contexto(active_object=copias[0], object=copias[0],
                                   selected_objects=copias, selected_editable_objects=copias):
        bpy.ops.object.join()
    ob = copias[0]; ob.name = 'Chibi'; me = ob.data; me.name = 'Chibi'
    for uvl in [u for u in me.uv_layers if u.name != 'Tipo']:
        me.uv_layers.remove(uvl)
    me.materials.clear(); me.materials.append(bpy.data.materials.new('Chibi'))
    me.polygons.foreach_set('material_index', [0] * len(me.polygons))
    me.color_attributes.active_color = me.color_attributes['Color']
    huesos = {b.name for b in arm.data.bones}
    for g in [g for g in ob.vertex_groups if g.name not in huesos]:
        ob.vertex_groups.remove(g)
    ob.parent = arm; ob.matrix_parent_inverse = arm.matrix_world.inverted()
    ob.modifiers.new('Armature', 'ARMATURE').object = arm
    bpy.context.view_layer.update()
    return tris_antes, tri_count()[0]


def exportar(tipo, carpeta):
    if tipo == 'estadio':
        os.makedirs(carpeta, exist_ok=True); prep_estadio()
        path = os.path.join(carpeta, 'estadio.glb'); export_glb(path, animations=False)
        return path, tri_count()[0]
    os.makedirs(carpeta, exist_ok=True)
    if tipo in ('jugador', 'golero'):
        for o in bpy.data.objects:
            if 'peinado' in o:
                o.hide_set(False); o.hide_viewport = False; o.hide_render = False
        prep_character(); unir_personaje()
        path = os.path.join(carpeta, tipo + '.glb'); export_glb(path, colores='ACTIVE')
    elif tipo == 'pelota':
        convert_materials()
        path = os.path.join(carpeta, 'pelota.glb'); export_glb(path)
    else:
        raise ValueError(tipo)
    return path, tri_count()[0]
