# Simple-Island

> *This is a Dynamic Notch project, yes. another one...*

## The Philosophy

There are dozens of "Dynamic Island" apps for macOS out there. But somewhere along the line, they lost their way. They try to cram the entire world into a tiny black pill—calculators, weather widgets, full control centers, and overwhelming menus. Instead of being a subtle helper, they end up becoming a bloated hindrance.

**Simple-Island** was born out of frustration with that trend. Inspired by other great open-source notch projects, the core idea here is **extreme minimalism**. It does exactly what it is supposed to do: perfectly mimic the native, compact, and non-intrusive behavior of the iOS Dynamic Island on your Mac, without the bloat. 

It stays out of your way when you don't need it, and expands gracefully only when necessary.

## Features

* **True Stationary Behavior:** Unlike many other apps, Simple-Island survives the macOS WindowServer. By utilizing private `CGSSpace` APIs, the island lives in a hidden system workspace. This means it **will not slide or glitch** when you use the 3-finger swipe (Mission Control) to change desktops. It stays physically glued to the top of your screen.
* **Minimalist Media Player:** Automatically detects playback from **Spotify** and **Apple Music**.
* **Dynamic Resizing:** * On a MacBook with a physical notch: Hides seamlessly into the hardware cutout.
  * On an external monitor: Shrinks to a tiny, elegant pill when idle.
  * Expands fluidly with iOS-style spring animations to reveal the album art and an animated waveform only when music is playing.
* **Zero Intrusive Menus:** No settings panels popping up in your face. It just works.

## Installation & Setup

1. Clone this repository.
2. Open `Simple-Island.xcodeproj` in Xcode (macOS 14.0+ recommended).
3. Build and Run (`Cmd + R`).

**Note on Permissions:** The first time you play a song on Spotify or Apple Music while the app is running, macOS will ask for **Automation** permissions. This is required for the app to securely fetch the current track data via AppleScript without injecting unauthorized code into the media players.

## Credits & Acknowledgements

This project was built on the shoulders of giants. A special thanks to the open-source community, particularly the [Atoll](https://github.com/Ebullioscopic/Atoll) / `boring.notch` projects, whose brilliant implementation of the `CGSSpace` private API served as the foundation to fix the notorious macOS Mission Control dragging issue.
