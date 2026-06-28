# machin-game-demo-solar

A **3D solar-system simulator** written in [machin](https://github.com/javimosch/machin) (MFL) and rendered with raylib. Every planet is a **procedural GPU mesh** with `noise3`-driven surface detail (bands, ice caps, mottled terrain), orbiting at its own rate in a **fixed-timestep simulation** decoupled from the frame rate. Fly around with a 6DOF WASD+mouse camera.

Part of [**awesome-machin**](https://github.com/javimosch/awesome-machin).

```
         *  *    *       machin — solar system
    *          *         7 procedurally-textured planets
       ☀                noise3 surface detail · banded gas giants · rocky worlds
  *         *     *      fixed-timestep orbital sim · 6DOF fly camera
       *         *       WASD fly · mouse look · Q/E up/down · R reset
```

## Why it exists

This is the next step after the [planet chunk demo](https://github.com/javimosch/machin-game-demo-planet) — instead of one static mesh, it builds **multiple moving GPU meshes** that interact through a simulation. It drives two high-impact gaps from the [game-dev north star](https://github.com/javimosch/machin/blob/main/docs/NORTH-STAR-GAMEDEV.md):

| what | why |
|---|---|
| **math3d module** (inline for now) | A pure-MFL `Vec3` type with add/sub/scale/dot/cross/len/norm/lerp/dist — every calculation in this demo flows through it. This is feature #2 on the roadmap (the vector/matrix layer), and every future game-dev project inherits it. |
| **fixed-timestep simulation** | Orbital motion advances at a steady 60 Hz regardless of frame rate — the accumulator pattern (feature #6: deterministic fixed-step loops). Pause, resize, tab away — the planets don't jump. |
| **procedural sphere mesh** | A UV sphere generator with per-vertex noise3 colouring — gas-giant bands, polar ice caps, and mottled rocky surfaces all from the same function keyed by a planet seed. |
| **6DOF fly camera** | WASD + mouse-look with yaw/pitch angles — the standard free-fly camera computed from the math3d module. |

So the demo is a **bridge from Tier 2** (one static GPU mesh) **toward Tier 4** (many dynamic objects in a sim loop, driven by reusable vector math).

## Build

Needs the `machin` compiler (**v0.48.0+**), a C compiler, **raylib**, and a display.

```bash
./build.sh                    # → ./machin-game-demo-solar
./machin-game-demo-solar
```

`build.sh` uses a **system raylib** if installed; otherwise it **vendors raylib's prebuilt static release** into `vendor/` automatically — no root required.

## Controls

| key | action |
|---|---|
| WASD | fly forward/back, strafe left/right |
| Mouse | look around |
| Q / E | fly up / down |
| Shift | boost speed |
| R | reset camera |
| Esc | quit |

## How it works

### math3d module

Pure-MFL `Vec3` struct with value-semantic ops:

```
type Vec3 struct { x float y float z float }
func v3_add(a, b) (r) { r = Vec3{a.x+b.x, a.y+b.y, a.z+b.z} }
func v3_norm(a) (r) { l := sqrt(a.x*a.x + a.y*a.y + a.z*a.z) + 0.0000001  r = v3_scale(a, 1.0/l) }
func v3_cross(a, b) (r) { r = Vec3{a.y*b.z - a.z*b.y, a.z*b.x - a.x*b.z, a.x*b.y - a.y*b.x} }
// ... plus dot, len, lerp, dist, scale, sub
```

Every position, velocity, orbit computation, and camera vector goes through these ops — no inline trig scattered through the codebase.

### Fixed-timestep sim

```
sim += dt
while sim >= FIXED_DT:
    for each planet: angle += speed * FIXED_DT
    sim -= FIXED_DT
```

The render loop can run at any rate; the planets advance at exactly 60 Hz. An 8-step cap prevents the spiral of death after long pauses.

### Procedural spheres

Each planet is a UV sphere (`rings × sectors` quads, non-indexed for flat shading). For each vertex, `noise3` on the unit sphere point + a planet seed produces:
- **Gas giants**: latitude bands from `sin(lat * 7 + noise3(...))` give Jupiter-like stripes.
- **Rocky worlds**: `noise3` modulates a brown-grey base for cratered/mottled terrain.
- **Ice caps**: poles turn white-blue when `|lat| > 0.75`.
- **Sun**: bright yellow-orange with noise for surface texture.

### Camera

Yaw and pitch accumulate from `GetMouseDelta()`. Forward = `(cos(pitch)*sin(yaw), -sin(pitch), cos(pitch)*cos(yaw))`. WASD translates along forward/right/up (computed fresh each frame from the math3d module).

## The Mesh cstruct

raylib's `Mesh` is declared with the fields we touch — `normals` is new (vs. the planet chunk demo):

```
cstruct Mesh { vertexCount i32 triangleCount i32 vertices ptr normals ptr colors ptr vaoId u32 vboId ptr }
```

Field **names** must match raylib's `Mesh` (the boundary marshals by name); the other fields default to zero/NULL, which `UploadMesh` handles. Needs machin **v0.48.0+**.

## Future directions

- **Textured planets**: `LoadTexture` + a UV-mapped mesh + a fragment shader for real diffuse lighting from the sun.
- **Kepler orbits**: elliptical orbits with eccentricity and inclination — every planet gets six orbital elements.
- **Moon systems**: nested orbits (moon around planet, planet around sun) — drives hierarchical transform composition.
- **Gravity simulation**: n-body with a fixed-timestep integrator (Verlet/RK4) — the physics layer for Tier 4.
- **Extract math3d.src**: pull the Vec3 ops into a vendored `math3d.src` module for reuse across projects.
- **Orbit lines / UI**: draw orbit paths with raylib `DrawLine3D` and a clickable planet info panel.

## License

MIT
