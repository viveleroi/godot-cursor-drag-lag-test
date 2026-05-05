# Godot Cursor Drag Lag

A minimal Godot 4.6 project demonstrating why a texture "attached" to the mouse cursor visibly lags behind the OS cursor, and how the rendering pipeline and VSync settings affect the size of that gap.

The scene is a single `TextureRect` that follows the mouse, alongside a custom-drawn red pointer dot. Toggles in the top-right corner let you switch between the OS cursor and a custom cursor, and turn VSync on or off so you can compare the trade-offs side by side.

## What you are seeing

Swing the mouse quickly with the OS cursor visible and VSync enabled. The dragged texture trails noticeably behind the cursor — the faster the motion, the bigger the visible gap. Disable VSync, or hide the OS cursor, and the gap shrinks or disappears.

This is not a bug in the script. It is a consequence of mixing two completely different rendering paths on the same screen.

## The two pipelines

### OS cursor (hardware path)

On every modern desktop OS the mouse cursor is drawn by the GPU or compositor, not by the application:

- **Windows**: a hardware cursor plane managed by the GPU and the DWM compositor.
- **macOS**: WindowServer composites a hardware cursor on top of every frame.
- **Linux (X11/Wayland)**: the DRM cursor plane, when the driver supports it.

The OS reads HID input at the device's polling rate (often 125–1000 Hz) and updates the cursor's position at display scanout. The cursor is layered *on top of* whatever the application has drawn, so its position is independent of the application's frame rate. Even at 30 fps your cursor still feels instantaneous.

End-to-end latency from physical motion to a moved cursor on screen is typically around **5–10 ms**.

### Application-rendered texture (software path)

When the script positions the `TextureRect` at `event.global_position`, the input has to travel:

1. HID device → OS driver → input queue
2. OS dispatches the event to the application on its next frame tick
3. The script reads it in `_input` and updates the node's `global_position`
4. Godot renders a new frame on the GPU
5. The frame is handed to the swapchain
6. The frame is presented at the next vblank (or immediately, with VSync off)
7. The compositor (DWM / WindowServer / Mutter) re-composites the window
8. The display scans the frame out
9. The hardware cursor is then drawn over the top of that already-late frame

On a fast machine this totals roughly **16–50+ ms**. The difference between this and the ~5 ms hardware cursor is the lag the eye sees.

## The role of VSync

VSync synchronizes frame presentation with the monitor's refresh. Each mode has different latency characteristics:

| Mode | Behavior | Typical added lag |
| --- | --- | --- |
| `VSYNC_DISABLED` | Present immediately; tearing possible | ~0 frames |
| `VSYNC_ENABLED` | Wait for vblank to present | 1–2 frames (~16–33 ms at 60 Hz) |
| `VSYNC_ADAPTIVE` | VSync above refresh, off below | 0–1 frame |
| `VSYNC_MAILBOX` | Triple-buffered; always presents the newest frame at vblank | ~1 frame, no stutter |

With VSync on, the rendered frame is held until the next vblank and the compositor often holds it for one more frame after that. Meanwhile the hardware cursor keeps updating every scanout. The texture has no chance to catch up.

With VSync off, frames present as soon as they are ready (often several hundred FPS). The texture's position can land on screen close to its real-time value and the gap shrinks below most people's perceptual threshold — at the cost of tearing.

This is why so many drag-and-drop tutorials look snappy in their videos: they are often recorded on lower-refresh-rate displays or with VSync disabled, where the gap is small enough to ignore.

## Display refresh rate matters

- 60 Hz → one frame = 16.7 ms
- 144 Hz → one frame = 6.9 ms
- 240 Hz → one frame = 4.2 ms

Higher refresh rates shrink every term in the pipeline above, which is part of why this lag has become more visible in recent years. Modern monitors expose a gap that 60 Hz panels mostly hid.

## Approaches to the problem

### 1. Hide the OS cursor and draw your own

If there is no hardware cursor on screen there is nothing for the eye to compare against. The texture and a custom-drawn pointer go through the same pipeline, so they move together. This is what most full-screen game UIs do.

```gdscript
Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
```

The "Use OS mouse" toggle in this demo flips between this mode and a visible OS cursor so you can compare directly. Note that this only fixes the *perception* — the absolute input-to-photon latency is still pipeline-bound, it just has nothing visible to be measured against.

### 2. Make the dragged texture *be* the OS cursor

Godot can hand a texture to the OS as a custom hardware cursor:

```gdscript
Input.set_custom_mouse_cursor(my_texture, Input.CURSOR_ARROW, hotspot)
```

The dragged item is now drawn on the hardware cursor plane and stays perfectly locked to input. Trade-offs:

- Static image only — no shaders, no per-frame tinting, no animation tied to game state
- Size limits (Windows commonly enforces 32×32 or 64×64; other platforms vary)
- One image at a time; no compositing of multiple elements

This is the cleanest answer for inventory drag-and-drop where the icon does not need to do anything fancy.

### 3. Predict the cursor position

Use mouse velocity from recent `InputEventMouseMotion.relative` samples to project the texture's position ~1 frame ahead. Closes the gap during steady motion but overshoots on direction changes — careful damping is required, and a poorly tuned predictor looks worse than the original lag.

### 4. Tighten the rendering pipeline

- `Input.use_accumulated_input = false` (already set here) delivers every sub-frame motion event instead of merging them.
- `VSYNC_DISABLED` or `VSYNC_MAILBOX` reduces presentation latency.
- Exclusive fullscreen on Windows bypasses DWM and removes a frame of compositor lag.
- A higher-refresh-rate display shrinks every per-frame term.

None of these eliminate the gap on their own, but stacked together they can push it below the perceptible threshold (~10–15 ms for most viewers).

### 5. Design around it

The honest workaround is layout: anchor the dragged item visibly *near* the cursor (the offset this demo uses), not *under* it. Once the eye accepts that the texture is following the cursor rather than glued to it, the trailing motion stops reading as broken.

## What this demo lets you compare

The Settings panel exposes:

- **Mouse mode**
  - *Custom drawn* — OS cursor hidden; a red dot is rendered by Godot at the input position. The icon trails it with an offset.
  - *OS cursor* — OS cursor visible; the icon trails it with an offset. This is the worst-case comparison and where the lag is most obvious.
  - *Hardware cursor* — the icon texture *is* the OS cursor (`Input.set_custom_mouse_cursor`). The dragged `TextureRect` nodes are hidden because the cursor itself is showing the icon.
- **VSync** — `Disabled`, `Enabled`, `Adaptive`, `Mailbox`.
- **Fullscreen** — toggles `WINDOW_MODE_EXCLUSIVE_FULLSCREEN`. On Windows this bypasses DWM and removes a frame of compositor lag.
- **Stats readout** (top-left) — current FPS, frame time, VSync mode, and fullscreen state.

A second green-tinted draggable follows the cursor on the opposite side of the input-driven one. It is positioned in `_process` (once per rendered frame, reading `get_viewport().get_mouse_position()`) rather than in `_input` (every motion event). Compare its motion against the red-tinted input-driven one to see whether per-event vs per-frame updates make a perceptible difference at the engine layer.

## Still on the table

- A position predictor with a tunable look-ahead — closes the gap during steady motion at the cost of overshoot on direction changes.

## References

- [`DisplayServer.window_set_vsync_mode`](https://docs.godotengine.org/en/stable/classes/class_displayserver.html#class-displayserver-method-window-set-vsync-mode)
- [`Input.set_custom_mouse_cursor`](https://docs.godotengine.org/en/stable/classes/class_input.html#class-input-method-set-custom-mouse-cursor)
- The original observation that prompted this demo: drag-and-drop tutorials such as [this one](https://www.youtube.com/watch?v=uNepyWzSw80) look snappy in their videos, but conditions had to be right.
