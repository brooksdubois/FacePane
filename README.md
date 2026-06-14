# WindowPane

> A simple, free alternative for displaying your camera feed during screen shares and screen recordings.

## What It Does

WindowPane gives you a small, floating window with your camera feed on your current screen!

<img width="1470" height="956" alt="Screenshot 2026-06-13 at 9 42 24 PM" src="https://github.com/user-attachments/assets/3e1e0d41-1588-4efd-b52d-8597e125f338" />

This is intended for making screencaps with the "Screen Recording" tool apple provides, or for Face Time/Zoom/Teams/Slack/Discord calls where you want to share your screen but still keep your face visible.

### Why I Created It

I wanted something very small and simple without the entire bloat of a full-blown studio like CapCut.

I also wanted a freely floating window I can use in any app that's resizable, customizable, and clean.

It's great for doing business and showing off your code!

### Why I Open-Sourced It

**Why not?** It's a simple utility that took me less than a few hours to vibe-code with Codex and ChatGPT & it works perfectly.

Also, I don't have an Apple Developer subscription right this minute to deploy to the App Store... 

So, I've decided just to share the code on my GitHub for anyone to use this as a portfolio piece.

**Hope you enjoy!**

## How to Run

This is an XCode project. Install XCode, then you can simply clone the repo and open it in XCode and click "Run".

### To Compile it as an App for your Applications Folder

1. Set build destination to your Mac
  - In Xcode’s top toolbar, make sure the run destination says something like: "My Mac" (not iPhone or simulator)

3. Set signing for local use. You do not need paid Apple Developer Program for this.
 - Click the project in the left sidebar:
   - WindowPane project → WindowPane target → Signing & Capabilities
   - Signing Certificate: Sign to Run Locally
 - Or leave automatic signing enabled with your personal Apple ID team.

3. Build Release mode
  - Product → Scheme → Edit Scheme...
  - Select Run on the left.
  - Set: Build Configuration: Release
  - Close the sheet.
  - Then build: Product → Build (or: Cmd + B)

4. Find the built app
  - In Xcode’s left sidebar, scroll to: Products
  - You should see: WindowPane.app
  - Right-click it: Show in Finder

5. Copy it to Applications
  - In Finder, copy: WindowPane.app to: /Applications

Now you can open it like a normal app!

#### This App Comes with No Guarantees, Warrantees, or Other Expectations... The Code is Free For Anyone to Copy & Use!
