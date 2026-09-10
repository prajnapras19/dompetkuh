---
name: measure-startup
description: Build, install, and measure Dompetkuh's cold-start time on the connected device the correct way — profile mode, force-stop between launches, and discarding the first post-install launch — so a normal one-time reinstall cost doesn't get mistaken for a real performance regression. Use whenever startup "feels slow" needs checking, or before/after a change that might affect app startup.
---

# Measuring Dompetkuh startup correctly

A naive "install and launch once" check reliably produces a false alarm on
this project. Follow this exact sequence instead.

## Why the naive way lies

1. **Debug builds are inherently slow to start (11-17s)** — that's JIT/VM
   overhead baked into `flutter run` / debug APKs, unrelated to any code
   change. It is not representative of what a real user experiences and
   must never be used as a performance signal.
2. **The first launch after any install/reinstall is slower than every
   launch after it** — Android does one-time dex2oat/profile work on a
   freshly installed APK. Expect a launch (or two) at 4.5-5s even in
   profile mode right after `adb install -r`, dropping to the real ~2.3s
   steady-state number from the third launch onward. Reporting that first
   reading as "the" startup time is the single most common way this
   project's perf checks have gone wrong.

## Correct procedure

```bash
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH="/home/prajna/codes/flutter/bin:/home/prajna/Android/Sdk/cmake/3.22.1/bin:/home/prajna/Android/Sdk/platform-tools:$PATH"
cd /home/prajna/codes/dompetkuh

# Profile mode — close to release performance, without debug's JIT/VM
# overhead. Never use a debug build to judge startup performance.
flutter build apk --profile

adb install -r build/app/outputs/flutter-apk/app-profile.apk

# Launch 4 times, force-stopping between each. Discard the first 1-2
# readings (post-install settling) — only the later, stable readings are
# the real number.
for i in 1 2 3 4; do
  adb shell am force-stop com.prajnapras.dompetkuh
  sleep 2
  adb shell am start -W com.prajnapras.dompetkuh/.MainActivity | grep TotalTime
done
```

Expect output like:
```
TotalTime: 4577   <- discard: post-install settling
TotalTime: 2327   <- real number starts here
TotalTime: 2339
TotalTime: 2316
```

Only compare the **steady-state (3rd/4th launch) numbers** against a
previous steady-state baseline. A steady-state number moving from ~2.3s to
something meaningfully higher (not just one noisy reading) is a real
regression worth investigating; a single high first reading after a fresh
install is not.

## If you need a deeper breakdown

For engine-level timing (framework build time vs GPU rasterization time —
useful to confirm whether a slowdown is app code or the known Impeller
shader-compile cost on first frame), use Flutter's own trace tool instead
of `am start -W`:

```bash
adb shell am force-stop com.prajnapras.dompetkuh
flutter run --profile --trace-startup -d <device-id>
# prints "Time to first frame" and writes build/start_up_info.json with
# timeToFrameworkInitMicros / timeToFirstFrameRasterizedMicros / etc.
```

`timeToFirstFrameRasterizedMicros` sitting around 3s while
`timeToFirstFrameMicros` is under 500ms means the gap is GPU shader
compilation, not slow app/framework code — this has been consistently true
on this project's test device and is not itself a regression to chase.

## Comparing against the reference app

The reference app (`henry.dev.mywallet`, native Kotlin) launches via a
different entry activity:

```bash
adb shell am force-stop henry.dev.mywallet
adb shell am start -W henry.dev.mywallet/.presentation.view.SplashScreenActivity
```

It cold-starts in ~750-850ms. That gap vs. our ~2.3s is expected and not
closable — it has no Flutter engine/shader-compile cost to pay. Don't
treat that comparison as an apples-to-apples regression signal.
