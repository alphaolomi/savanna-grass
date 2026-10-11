# Release shrinking (R8) for the on-device model runtime, per flutter_gemma's
# README. MediaPipe loads its graph and calculators reflectively from native
# code, so R8 must not strip or rename them.

# MediaPipe
-keep class com.google.mediapipe.** { *; }
-dontwarn com.google.mediapipe.**

# Protocol Buffers
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.protobuf.**

# LiteRT / local agents
-keep class com.google.ai.edge.** { *; }
-dontwarn com.google.ai.edge.**
