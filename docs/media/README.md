# Dock demo media

- `dock-demo-120fps.mp4`: 14.3-second H.264 recording, 2640 × 330, 120 fps,
  YUV 4:2:0, with MP4 fast-start metadata for playback.
- `dock-demo.webp`: looping 1440 × 180 animated preview sampled at 60 fps.
  Identical frames are coalesced while preserving their display durations.
- `dock-demo-poster.png`: still frame from the MP4, showing Herdr magnification.

The actual Quickshell dock was captured on a 240 Hz display using wf-recorder
at 120 fps. Pointer motion was delivered at 240 Hz, alternating slow hover
inspection with full-width flicks lasting roughly 0.4–0.6 seconds, rapid
direction reversals, and quick exits/re-entries. Each sweep accelerates and
decelerates rather than moving at a constant speed. Playback is real-time;
no motion interpolation or speed-up was applied. The MP4 contains 1,716 frames
over 14.3 seconds.

There are 18 pinned applications installed on the recording machine, including
Herdr, Google Chrome, Ghostty, Kitty, Signal, Files, Text Editor, Calculator,
Clocks, Image Viewer, Document Viewer, mpv, Resources, Disks, Disk Usage Analyzer,
Passwords and Keys, Font Manager, and Settings. Existing running applications
also appear after the divider.

Unread counts on Herdr, Chrome, Signal, and Files are synthetic demonstration
values, delivered through `com.canonical.Unity.LauncherEntry.Update`. The Herdr
count and Files progress change during the capture. These do not imply that
every application shown publishes launcher state natively.

A neutral backdrop and a dock-only crop exclude personal desktop content. Demo
settings were isolated from the installed dock, and its normal configuration
was restored after recording. The animated preview provides inline playback
in the README; the linked MP4 provides the full capture frame rate.
