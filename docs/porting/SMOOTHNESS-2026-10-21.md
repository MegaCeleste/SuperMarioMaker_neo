# Runtime smoothness — 2026-10-21

The user authorized a focused smoothness investigation and correction, after
reporting that play felt less fluid than Mario Maker. No new course content,
physics tuning, Antigravity, publication or reference-checkout changes belong
to this round.

## Findings and changes

The local display reports120Hz. The project uses60Hz physics, VSync enabled
by default, nearest texture sampling and GL Compatibility. Built-in physics
interpolation was disabled. The old camera fix correctly stopped camera/body
clock disagreement, but left actors and scenery on60 distinct positions per
second. Fixed-FPS screenshots verified geometry, single sprites and camera
stability; they did not measure wall-clock frame pacing.

WorldPresentation now snapshots foreground physics movers and the physical
camera before each tick. Immediately before drawing, it interpolates their
translations using the same fraction. RenderingServer receives the displayed
actor transforms; Node2D positions, collision masks, state timers, input and AI
continue to see the completed physical tick. Utility.camera_render_offset
separates the displayed camera from the camera used for physical culling.
The existing Background receives the corresponding parallax correction and
one repeat of overscan. Global engine interpolation remains off so editor
gestures, render-time effects and scripted pose changes keep their clocks.
physics_jitter_fix is0 for this custom interpolation path, as recommended in
the [Godot ProjectSettings reference](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html#class-projectsettings-property-physics-common-physics-jitter-fix).

Only translation is blended. Sprite frames, facing, squash, scale and rotating
render-time poses stay current. A pause retains the last displayed actor and
camera positions; resuming starts from that held pose. New actors have no old
history, large teleports snap, reparented bodies relinquish their world drawing
transform, and edit/play transitions clear the display correction. Shadows use
the displayed hierarchy so their silhouettes cannot lag behind interpolated
actors. Sub-sprite movement driven by individual enemy scripts is not a claim
of complete interpolation of every visual in OpenWE.

PixelShadows previously scanned and rebuilt every visible-in-tree source on
every render, including static terrain outside the camera. Commands are now
cached until a source/copy redraw invalidates them. Copy redraw matters when a
hidden CanvasGroup is shown again. Distant sprites are skipped before opacity,
sampling, material and ancestor processing. Current pose/material/opacity,
overlap alpha, source removal and editor ground edits retain the existing
rendering rules.

## Evidence

GL wall-clock probes use a visible960x540 window on the local GTX1660Ti.
Each sample has a warmup and about two seconds of sampling. The probe disables
VSync in its own process, uses Engine.max_fps, and never passes --fixed-fps or
reads back images during timing. It is not a measurement of display scanout,
hardware input latency or exact Nintendo-game parity.

|120 FPS sample|Before|After|
|---|---:|---:|
|Distinct displayed positions in241 render samples|121 (interpolation disabled control)|241|
|Fixture shadow synchronization, mean|1.268ms|0.691ms|
|Fixture +512 distant static sprites, mean|5.981ms|1.891ms|

The unmodified fixture already had stable120 FPS software pacing in the first
sample. Its frame interval p99 was8.899ms before and9.159ms in the after sample;
this is not evidence of improved frame-time variance or increased overall FPS.
The measured gains are intermediate movement positions and lower shadow CPU
cost. Short host-dependent samples are diagnostic evidence, not a universal
performance guarantee.60 FPS sampling also completes normally. A144 FPS
software pacing sample records289 distinct displayed positions versus121
physical positions; its fixture frame-time p99 is7.717ms. The actual monitor
remains120Hz, so this does not verify native144Hz display presentation.

Artifacts remain ignored in .godot/porting-tests/: pacing_before_120.json,
pacing_cached_120.json, pacing_after_120.json, pacing_uninterpolated_120.json,
pacing_after_60.json, pacing_after_144.json and the corresponding stdout/engine logs. The initial
before probe also sampled Godot's low-frequency Performance CPU counters;
those stale monitor values include startup and are not used in this analysis.
The later probe removes those counters and measures shadow time directly.

Validation:

- Import, five sprite metadata checks and all44 native regression scenes pass.
- world_presentation_test independently checks fractional positions, unchanged
  physical state, camera synchronization, pause/resume, a first-tick pause
  after factory placement, teleport/editor reset and held reparent cleanup.
  Its120 FPS GL mode also checks actual magenta
  pixels at five fractions instead of relying only on reported transforms.
- The existing120 FPS fixed-screen walking/running GL matrix passes for both
  sizes, directions and fixed/animated poses. Its position probes now read the
  displayed transform that the GPU uses; the independent pixel bounds remain.
- Normal running mushroom-growth GL reels pass at60/120 FPS in both directions:
  exactly one drawing and a stable paused display anchor.
- Pixel-shadow GL alpha/rotation/fractional-zoom checks pass. The static-cache
  check keeps shadows visible while verifying unchanged commands are reused.
  A verbose shutdown audit identifies retained WAV/Ogg audio playback only,
  with no leaked actor, presentation, silhouette or image resources.
- The stationary walking/running brake-dust120 FPS GL probe also passes after
  interpolation. No cloud-following behavior was reintroduced.

Interpolation estimates positions between two completed ticks. It can place
the drawing up to one physics step (16.7ms) behind the latest collision state.
That is a visual latency tradeoff, not a measured improvement in input latency.
No extra input queue, simulation-rate increase or altered acceleration/jump
constants was introduced. See the
[Godot interpolation caveats](https://docs.godotengine.org/en/stable/tutorials/rendering/jitter_stutter.html).
