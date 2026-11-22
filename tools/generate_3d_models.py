from pathlib import Path
import numpy as np
import trimesh

out = Path(__file__).resolve().parents[1] / 'assets' / 'models'
out.mkdir(parents=True, exist_ok=True)

def put(scene, name, mesh, color, xyz=(0,0,0), axis=None, angle=0):
    mesh = mesh.copy()
    if angle and axis is not None:
        mesh.apply_transform(trimesh.transformations.rotation_matrix(angle, axis))
    mesh.apply_translation(xyz)
    mesh.visual.vertex_colors = np.asarray(list(color)+[255], dtype=np.uint8)
    scene.add_geometry(mesh, geom_name=name)

def box(scene, n, scale, color, xyz):
    put(scene,n,trimesh.creation.box(extents=scale),color,xyz)

def ball(scene,n,r,color,xyz):
    put(scene,n,trimesh.creation.icosphere(subdivisions=2, radius=r),color,xyz)

def cyl(scene,n,r,h,color,xyz,sections=20):
    put(scene,n,trimesh.creation.cylinder(radius=r,height=h,sections=sections),color,xyz)

def cone(scene,n,r,h,color,xyz):
    put(scene,n,trimesh.creation.cone(radius=r,height=h,sections=20),color,xyz)

def base(scene):
    cyl(scene,'gold-plinth',1.1,.13,(186,136,54),(0,0,-.45),sections=44)
    cyl(scene,'obsidian-plinth',1.02,.11,(18,41,46),(0,0,-.35),sections=44)

s=trimesh.Scene(); base(s)
box(s,'car-chassis',(1.8,.77,.26),(234,158,71),(0,0,-.05))
box(s,'car-cabin',(.91,.67,.33),(232,202,128),(-.12,0,.23))
box(s,'front-window',(.03,.58,.23),(54,107,133),(.35,0,.25))
for i,x in enumerate([-.62,.62]):
 for j,y in enumerate([-.42,.42]):
  cyl(s,f'wheel-{i}-{j}',.25,.16,(22,29,32),(x,y,-.23),sections=24)
for i,y in enumerate([-.21,.21]): box(s,f'headlight-{i}',(.07,.16,.11),(255,249,215),(.93,y,-.02))
(out/'gold_car.glb').write_bytes(s.export(file_type='glb'))

s=trimesh.Scene();base(s)
# yacht: rounded low hull, cabin, golden mast, triangular sail
box(s,'hull',(2.0,.7,.3),(235,222,194),(0,0,-.04))
box(s,'waterline',(1.86,.72,.07),(46,144,156),(0,0,-.2))
box(s,'cabin',(.73,.56,.30),(70,124,148),(-.27,0,.23))
box(s,'deck',(1.66,.56,.09),(192,151,81),(.02,0,.13))
cyl(s,'mast',.035,1.48,(227,180,79),(.30,0,.78),sections=12)
# Triangular sail drawn as a 3D triangle mesh
v=np.array([[.29,-.07,.32],[.29,-.07,1.46],[-.46,-.07,.40],[.29,.07,.32],[.29,.07,1.46],[-.46,.07,.40]])
f=np.array([[0,1,2],[5,4,3],[0,2,5],[0,5,3],[1,4,5],[1,5,2],[0,3,4],[0,4,1]])
put(s,'sail',trimesh.Trimesh(vertices=v,faces=f,process=False),(253,249,214))
(out/'pearl_yacht.glb').write_bytes(s.export(file_type='glb'))

s=trimesh.Scene();base(s)
cyl(s,'crown-ring',.70,.30,(211,155,57),(0,0,.08),sections=32)
for i in range(7):
 import math
 a=2*math.pi*i/7
 x,y=.57*math.cos(a),.57*math.sin(a)
 cone(s,f'prong-{i}',.17,.8,(232,180,78),(x,y,.60))
 ball(s,f'gem-{i}',.11,(83,220,190),(x,y,1.01))
ball(s,'royal-top',.18,(236,88,118),(0,0,.9))
(out/'royal_crown.glb').write_bytes(s.export(file_type='glb'))

s=trimesh.Scene();base(s)
cyl(s,'rocket-body',.25,1.60,(230,229,219),(0,0,.48),sections=24)
cone(s,'rocket-tip',.30,.53,(232,113,104),(0,0,1.54))
cyl(s,'rocket-window',.145,.07,(60,165,193),(0,-.23,.77),sections=24)
for i in range(4):
 import math
 a=i*math.pi/2
 box(s,f'fin-{i}',(.39,.10,.52),(211,103,91),(.27*math.cos(a),.27*math.sin(a),-.16))
cone(s,'engine-flame',.14,.42,(242,176,83),(0,0,-.47))
(out/'sky_rocket.glb').write_bytes(s.export(file_type='glb'))

s=trimesh.Scene();base(s)
box(s,'dice-body',(1.12,1.12,1.12),(248,247,229),(0,0,.21))
# 6 front pips, 3 top pips, 1 right pip
for k,(x,z) in enumerate([(x,z) for x in [-.34,.34] for z in [-.13,.21,.55]]):
 ball(s,f'front-pip-{k}',.095,(22,45,49),(x,-.574,z))
for k,(x,y) in enumerate([(-.3,-.3),(0,0),(.3,.3)]):
 ball(s,f'top-pip-{k}',.09,(22,45,49),(x,y,.778))
ball(s,'right-pip',.115,(22,45,49),(.578,0,.21))
(out/'pearl_dice.glb').write_bytes(s.export(file_type='glb'))

for p in out.glob('*.glb'):
 sc=trimesh.load(p,force='scene')
 assert sc.geometry and len(p.read_bytes()) > 500
 print(p.name, 'meshes=',len(sc.geometry),'bytes=',p.stat().st_size)
