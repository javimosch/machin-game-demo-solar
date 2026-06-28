---
name: machin-game-demo-solar
description: Build, run, and modify machin-game-demo-solar — a 3D solar-system simulator with procedural GPU-mesh planets, fixed-timestep orbital sim, 6DOF fly camera, and a pure-MFL vec3 math module. Use when working on this repo, or as the worked example of machin's math3d module + fixed-timestep simulation patterns.
---

# machin-game-demo-solar

A **3D solar-system simulator** — 7 procedurally-textured GPU-mesh planets orbiting a sun, with a 6DOF free-fly camera and a **fixed-timestep** simulation loop. Written in [machin](https://github.com/javimosch/machin) (MFL) via raylib's C FFI. It drives two roadmap items from the [game-dev north star](https://github.com/javimosch/machin/blob/main/docs/NORTH-STAR-GAMEDEV.md): the **vector/math module** (feature #2) and **fixed-timestep sim** (feature #6).

> Shared game-dev setup, the FFI surface, and cross-cutting gotchas live in the canonical **[machin-gamedev skill](https://github.com/javimosch/machin/blob/main/skills/machin-gamedev/SKILL.md)**. This file covers the specifics of this demo.

## Build & run

```bash
./build.sh                     # machin encode solar.src -> solar.mfl, machin build -> ./machin-game-demo-solar
./machin-game-demo-solar
```

Needs `machin` **v0.48.0+** (pointer/array FFI), a C compiler, **raylib**, and a display. `build.sh` prefers a system raylib, else vendors the prebuilt static release into `vendor/` (no root).

## Architecture

### math3d: pure-MFL vec3 module (inline)

A `Vec3` struct with value-semantic operations — the first reusable vector layer for machin game-dev:

```
type Vec3 struct { x float y float z float }
func v3(x, y, z) (v)
func v3_add(a, b) (r)       func v3_sub(a, b) (r)
func v3_scale(a, s) (r)     func v3_dot(a, b) (d)
func v3_cross(a, b) (r)     func v3_len(a) (l)    func v3_len_sq(a) (d)
func v3_norm(a) (r)         func v3_lerp(a, b, t) (r)
func v3_dist(a, b) (d)
```

All solar-system computations (orbit positions, camera vectors, normals) flow through these ops. Structs are value types — every op returns a new `Vec3`.

### Fixed-timestep simulation

The orbital sim advances at exactly 60 Hz (16.67 ms per step), decoupled from the render frame rate:

```
sim += dt
while sim >= FIXED_DT:
    for each body: body.angle += body.speed * FIXED_DT
    sim -= FIXED_DT
    if steps > 8: break   // spiral-of-death cap
```

An 8-step cap prevents the simulation from running away after a long pause or frame stall. The render loop uses `GetFrameTime()` for smooth camera movement; planet positions are interpolated implicitly (the sim always catches up before drawing).

### Procedural sphere mesh

`make_sphere(rings, sectors, radius, seed)` generates a UV sphere:
- `rings × sectors` quads, each = 2 triangles, non-indexed (flat shading)
- Total vertices: `rings * sectors * 6`
- Each vertex: position on sphere, normal (= normalized position), RGBA color
- Color from `planet_color(nx, ny, nz, seed)` using `noise3`:
  - Rocky base modulated by noise
  - Gas-giant bands via `sin(lat * 7 + noise3(...))`
  - Ice caps at `|lat| > 0.75`
- Uploaded once via `UploadMesh` → `LoadModelFromMesh`; drawn each frame with `DrawModelEx`

### Planet bodies

```
type Body struct {
    model Model      // uploaded GPU mesh
    orbit float      // orbital radius
    speed float      // angular speed (rad/sim-second)
    angle float      // current angle (updated each sim step)
    rad   float      // visual radius
    color Color      // halo tint
}
```

World-space position: `body_pos(b) = v3(orbit*cos(angle), 0, orbit*sin(angle))`. All bodies orbit in the XZ plane (flat ecliptic).

### Fly camera

`FlyCam` struct holds `pos`, `yaw`, `pitch`. Each frame:
- `GetMouseDelta()` → yaw/pitch accumulate
- Forward = `v3(cos(pitch)*sin(yaw), -sin(pitch), cos(pitch)*cos(yaw))`
- Right = `v3(cos(yaw), 0, -sin(yaw))` (perpendicular, horizontal)
- WASD translates along forward/right, Q/E along world up
- Shift boosts speed ×3, R resets to start position

## The Mesh cstruct

```
cstruct Mesh { vertexCount i32 triangleCount i32 vertices ptr normals ptr colors ptr vaoId u32 vboId ptr }
```

Field names must match raylib's `Mesh` exactly. The `normals` field is new vs. the planet chunk demo — it's declared but not used for lighting (colors are pre-lit). Unset fields default to zero/NULL; `UploadMesh` handles them.

## Patterns worth copying

- **Fixed-timestep sim**: decouple physics from rendering. Use an accumulator + cap. Planetary motion is smooth and deterministic even when the window is resized.
- **math3d module**: every 3D computation goes through `v3_*` ops — no inline `ax*dx + ay*dy + az*dz` anywhere. The module is inline now; extract to `math3d.src` for reuse.
- **Procedural surface detail**: `noise3` on the unit-sphere surface point + a planet seed gives banded/ice-capped/mottled planets from one function.
- **Struct as value type**: `step_body(b, dt)` returns a new `Body` — the caller reassigns `bodies[k] = step_body(...)`. No mutation across function boundaries.
- **Opaque handles in structs**: `Model` (an opaque `cstruct Model {}`) lives inside `Body` — stored, copied, and passed to `DrawModelEx` without issue.

## Modifying

- **Orbits**: change `orbit`, `speed`, and initial `angle` in the `Body` literals in `main()`. Add `inclination` to tilt orbits out of the XZ plane.
- **Planets**: adjust `rings`/`sectors` (higher = smoother, lower = retro-faceted), `rad` (visual size), and `seedf` (procedural surface).
- **Colours**: tweak `planet_color()` thresholds and band frequencies.
- **Camera**: change `sens` (mouse sensitivity), `spd` (movement speed), fov, or start position.
- **Sun colour**: `sun_color()` generates the sun's surface noise.
- After any edit to `solar.src`, re-run `./build.sh` (never hand-edit `solar.mfl` — it is generated).

## Frontier (next steps from here)

- Extract `math3d.src` as a vendored module (adds a build step: `machin encode math3d.src` → cat → main).
- Textured planets: `LoadTexture` + a UV sphere mesh with texcoords + a lit shader.
- Kepler orbits (6 orbital elements) → elliptical, inclined orbits.
- Moon systems (hierarchical transforms: moon matrix = planet matrix × moon-local).
- Orbit path lines via `DrawLine3D` (tessellated ellipse).
- Gravity simulation (n-body with Verlet/RK4 integrator) — the physics layer for Tier 4.
