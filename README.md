# Godot Cursor Drag Lag

This simple godot 4.5 project has nothing but a texturerect and some simple code to allow dragging or attaching it to the cursor.

The texture dramatically lags behind the cursor on higher rate monitors unless VSync is disabled.

Because the cursor is OS/hardware-based and any texture that's being dragged or designed to look "attached" to the cursor is software-based, there will always be a delay in it's position.

There are many tutorials on inventory drag and drop/click interactions like [this one]( https://www.youtube.com/watch?v=uNepyWzSw80) that do not seem to have this issue, but likely they're running lower refresh rate monitors and/or have VSync disabled.