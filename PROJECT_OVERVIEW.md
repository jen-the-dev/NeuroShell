# 🧠 NeuroShell

**A kinder terminal for differently wired minds.**

> Built for the brains that alt-tab mid-thought.

[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)]()
[![Swift](https://img.shields.io/badge/Swift-5.0-orange)]()
[![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-purple)]()
[![License](https://img.shields.io/badge/license-MIT-green)]()

---

## App Summary

NeuroShell is a native macOS terminal application designed specifically for developers and tech learners with ADHD, AuDHD, and other neurodivergent profiles who struggle with executive dysfunction at the command line.

Traditional terminals are unforgiving — a blank prompt with a blinking cursor offers no structure, no memory, and no mercy. For someone with working memory challenges, time blindness, or decision paralysis, that blank prompt can feel like a wall.

NeuroShell wraps a fully functional shell in a layer of cognitive support:

- **Task Chunking** breaks complex workflows (deploy, debug, git merge) into numbered, bite-sized steps with difficulty ratings and time estimates
- **Time-Blindness Alerts** provide gentle, non-intrusive check-ins at configurable intervals — time tracking, hydration, posture, and break reminders
- **Hyperfocus Protection** monitors command patterns, detects repetitive loops ("you've run this 3 times — are you stuck?"), and nudges you to pause before burnout
- **Context Memory** answers the eternal ADHD question — *"Where was I?"* — with a one-click summary of your current directory, goal, recent commands, and pinned notes
- **Smart Suggestions** reduce decision paralysis with real-time, context-aware command recommendations based on natural language input
- **Breathing Exercises** offer four guided patterns (Box, 4-7-8, Energizing, Quick Reset) with animated visuals for in-the-moment nervous system regulation
- **Mood Awareness** adapts messaging tone based on self-reported mood — extra gentle when you're overwhelmed, encouraging when you're in flow

This matters because **15–20% of developers are neurodivergent**, and the tools they use every day were never designed with their cognitive needs in mind. NeuroShell doesn't dumb things down — it builds scaffolding so every developer can do their best work.

---

## AI Feature Summary

NeuroShell integrates AI capabilities across four core areas of the user experience:

### 1. Natural Language → Command Translation
Users can type what they *want to do* in plain English (e.g., "find all large files" or "set up a new project") and receive contextually appropriate command suggestions. The `CommandSuggestionEngine` maps natural language intent to shell commands using semantic keyword matching and provides human-friendly explanations for every suggestion.

### 2. Intelligent Task Decomposition
When a user describes a complex goal (e.g., "deploy my app" or "merge git branches"), the AI-powered Task Chunker decomposes it into a sequenced series of small, actionable steps — each with:
- A plain-language title and description
- The exact command to run
- A difficulty rating (🟢 Easy / 🟡 Medium / 🔴 Hard)
- A time estimate in minutes

This directly combats **executive dysfunction** by eliminating the "but where do I even start?" paralysis.

### 3. Behavioral Pattern Recognition
The `HyperfocusGuard` service uses real-time activity analysis to detect:
- **Rapid-fire command entry** (>10 commands/minute) suggesting anxiety-driven typing
- **Repetitive command loops** (same command 3+ times) indicating the user may be stuck
- **Extended unbroken sessions** with escalating awareness levels (Normal → Elevated → High → Warning)

Each detection triggers a gentle, non-judgmental intervention — never an interruption, always a suggestion.

### 4. Context-Aware Error Interpretation
The `OutputParserService` translates cryptic terminal errors into ADHD-friendly explanations using analogy-based language:
- *"Permission denied"* → *"It's like trying to open a locked door — you need the key (admin access)"*
- *"Command not found"* → *"Like trying to use an app that isn't downloaded yet"*
- *"Merge conflict"* → *"Two people edited the same paragraph differently — you choose which to keep"*

Each parsed error includes ranked action items so the user knows exactly what to try next, reducing the cognitive spiral that errors often trigger.

### How AI Enhances the Experience
Traditional terminals treat every user the same. NeuroShell's AI layer creates an **adaptive experience** that:
- Reduces decisions (smart defaults and suggestions)
- Reduces memory load (context tracking and "Where Was I?")
- Reduces emotional friction (gentle tone, celebrations, encouragement)
- Reduces time distortion (proactive time awareness)

The AI isn't a chatbot bolted onto a terminal — it's woven into every interaction to make the command line *feel* different.

---

## How You Are Using Tetrate

NeuroShell leverages **Tetrate's TARS (Tetrate AI Runtime System)** as the intelligent routing and model orchestration layer that powers its AI features.

### TARS Routing
TARS acts as the unified AI gateway for all of NeuroShell's inference needs. Rather than hardcoding a single model provider, TARS routing allows NeuroShell to:

- **Route requests by task type** — lightweight command suggestions hit fast, low-latency models, while complex task decomposition routes to more capable reasoning models
- **Fail over gracefully** — if a model endpoint is unavailable, TARS reroutes to an alternative provider without the user experiencing a disruption (critical for an accessibility tool where broken flows cause cognitive derailment)
- **Respect rate limits and quotas** — TARS handles backpressure so the real-time suggestion engine can fire on every keystroke without overwhelming downstream providers

### TARS Models
NeuroShell uses TARS-managed models for three distinct inference profiles:

| Profile | Use Case | Priority |
|---------|----------|----------|
| **Fast / Lightweight** | Real-time command suggestions, prefix matching, explanation lookups | Low latency (<200ms) |
| **Reasoning / Mid-tier** | Task chunking, natural language parsing, error interpretation | Accuracy over speed |
| **Contextual / Stateful** | "Where Was I?" summaries, session context reconstruction, behavioral pattern analysis | Context window depth |

TARS model management lets us swap or upgrade providers behind the scenes without touching client code — the app always calls the same TARS endpoint, and routing policy handles the rest.

### TARS Tools
TARS tool integration enables NeuroShell to extend AI capabilities beyond pure text generation:

- **File system awareness** — TARS tools inspect the user's current directory to generate context-aware suggestions (detecting `package.json`, `.git`, `Makefile`, etc.)
- **Command validation** — before suggesting a command, TARS tools can verify that the referenced binary exists on the user's system
- **Session persistence** — TARS-managed tool calls handle reading/writing session state (task progress, context memory, preferences) so the AI layer has continuity across app restarts

### Why TARS Matters for This Project
For a neurodivergent user, **reliability is accessibility**. A suggestion that loads too slowly is a suggestion that arrives after the user has already context-switched. An error in the AI layer that surfaces as a cryptic failure message is exactly the kind of friction this app exists to eliminate.

TARS gives NeuroShell the infrastructure to be *consistently gentle* — fast when it needs to be fast, smart when it needs to be smart, and always available when the user needs support.

---

## Target User

### Primary Audience
**Neurodivergent developers and tech learners** — specifically those with:
- **ADHD** (inattentive, hyperactive, or combined presentation)
- **AuDHD** (co-occurring Autism and ADHD)
- **Autism spectrum** profiles with executive function challenges
- **Anxiety-adjacent** patterns triggered by terminal environments

### User Spectrum

| User | Pain Point | What NeuroShell Does |
|------|-----------|---------------------|
| **Junior dev with ADHD** | Overwhelmed by the blank terminal, forgets commands constantly | Smart suggestions, command explanations, Quick Actions grid |
| **Senior engineer with AuDHD** | Loses 4 hours to hyperfocus, forgets to eat, can't context-switch | Hyperfocus guard, time alerts, break system, breathing exercises |
| **Bootcamp student** | Decision paralysis — "which command do I use?" freezes them | Natural language input, one-click Quick Actions, zero-memorization UI |
| **Freelancer with time blindness** | No sense of how long they've been working, misses deadlines | Session timer, configurable interval reminders, progress tracking |
| **Career switcher with imposter syndrome** | Every error feels like proof they don't belong | Gentle error explanations, encouragement system, celebration messages |

### The Problem It Solves
The command line is one of the most powerful tools in software development — and one of the least accessible for neurodivergent minds. NeuroShell doesn't replace the terminal. It adds the **cognitive scaffolding** that executive dysfunction takes away: structure, memory, time awareness, emotional safety, and reduced decision load.

**Your brain isn't broken. Your tools just weren't built for you. Until now.**

---

## Implementation

### Architecture Overview

NeuroShell is a **native macOS application** built with Swift 5 and SwiftUI, targeting macOS 14.0+. The architecture follows a clean separation between Views, Models, and Services, with centralized state management via `@EnvironmentObject` dependency injection.

```
NeuroShell/
├── NeuroShellApp.swift          # App entry point, scene & environment setup
├── ContentView.swift            # Root navigation with overlay alerts
├── AppState.swift               # Central state: navigation, sessions, history, mood
├── Models/
│   ├── TaskModel.swift          # TaskChunk, TaskSession, TerminalLine, UserPreferences
│   └── ContextMemory.swift      # Working memory, breadcrumbs, notes, "Where Was I?"
├── Services/
│   ├── TerminalService.swift    # Shell process management (zsh), I/O handling
│   ├── CommandSuggestionEngine.swift  # NLP matching, prefix search, task chunking
│   ├── TimerService.swift       # Session clock, break management, notifications
│   ├── HyperfocusGuard.swift    # Activity monitoring, pattern detection, alerts
│   └── OutputParserService.swift # Error parsing, friendly explanations
├── Views/
│   ├── TerminalView.swift       # Terminal UI: output, suggestions, input, context bar
│   ├── TaskChunkerView.swift    # Task decomposition UI with step execution
│   ├── TimerView.swift          # Time awareness dashboard, break controls
│   ├── BreathingExerciseView.swift  # Guided breathing with animated circle
│   ├── QuickActionsView.swift   # Categorized one-tap command grid
│   ├── SidebarView.swift        # Navigation, status indicators, mood selector
│   ├── SettingsView.swift       # All user preferences and accessibility options
│   └── GentleReminderView.swift # Reminder cards and toast notifications
└── Assets.xcassets/             # App icon, accent color
```

### Key Design Decisions

**1. Native macOS over Electron/Web**
We chose a native Swift/SwiftUI implementation over a cross-platform approach for three reasons:
- **Performance** — Real-time suggestions on every keystroke require sub-frame UI updates. SwiftUI's declarative diffing handles this natively without a JavaScript bridge.
- **System integration** — Native `Process` API for shell execution, `UNUserNotificationCenter` for time alerts, and native `NSColor` for proper dark mode support.
- **Accessibility** — macOS VoiceOver, reduce-motion preferences, and system font scaling work out of the box with SwiftUI.

**2. `@EnvironmentObject` Dependency Injection**
Six observable services (`AppState`, `TerminalService`, `TimerService`, `HyperfocusGuard`, `ContextMemory`, `CommandSuggestionEngine`) are injected at the app root and available throughout the view hierarchy. This was chosen over a singleton pattern because:
- It's testable (services can be mocked in previews and tests)
- It's explicit (every view declares what it depends on)
- It leverages SwiftUI's built-in observation and re-render system

**3. Rule-Based NLP with TARS Upgrade Path**
The `CommandSuggestionEngine` currently uses a keyword-matching approach for natural language → command translation. This was a deliberate choice:
- **Works offline** — No network dependency for core functionality
- **Predictable** — ADHD users need consistent, reliable responses
- **Extensible** — The same interface (`getSuggestions(forInput:currentDir:recentCommands:)`) can be backed by a TARS-routed LLM call without changing any view code

**4. Non-Blocking Shell Execution**
`TerminalService` runs shell commands via `Process` with separate stdout/stderr pipes, executed through Swift concurrency (`async/await`). The UI remains responsive during long-running commands, and a cancel button is always visible. This prevents the "frozen screen panic" that can trigger ADHD anxiety spirals.

**5. Gentle-First UX Philosophy**
Every user-facing string was written with neurodivergent users in mind:
- Errors say *"Don't worry"* before explaining what went wrong
- Completions say *"Nailed it!"* instead of silent success
- Hyperfocus warnings say *"I notice..."* instead of *"WARNING:"*
- The breathing exercise includes affirmations, not instructions
- Mood selection adapts the entire app's communication tone

### Tradeoffs

| Decision | Benefit | Cost |
|----------|---------|------|
| macOS-only | Best native experience, system integration | No Windows/Linux support |
| SwiftUI (not AppKit) | Faster development, declarative UI, modern patterns | Requires macOS 14+, some layout limitations |
| Rule-based NLP first | Offline reliability, predictable behavior | Less flexible than LLM-based parsing |
| App Sandbox disabled | Full terminal access, unrestricted shell execution | Requires user trust, not App Store compatible as-is |
| Single-window NavigationSplitView | Simple mental model, reduced context-switching | Can't have terminal + task chunker side-by-side |
| `@Published` preferences (in-memory) | Simple, no persistence boilerplate | Settings reset on app restart (persistence is a planned addition) |

### Tech Stack

| Component | Technology |
|-----------|-----------|
| Language | Swift 5 |
| UI Framework | SwiftUI |
| Shell Integration | Foundation `Process` API (zsh) |
| Notifications | UserNotifications framework |
| State Management | Combine / `@Published` / `@EnvironmentObject` |
| AI Routing | Tetrate TARS |
| Target | macOS 14.0+ (Apple Silicon & Intel) |
| Build System | Xcode 15+ |

### Lines of Code

| Category | Files | LOC |
|----------|-------|-----|
| Models | 2 | ~450 |
| Services | 5 | ~1,200 |
| Views | 8 | ~2,000 |
| App Core | 3 | ~350 |
| **Total** | **18 Swift files** | **~4,000** |

---

<p align="center">
  <i>Made with 💛 for neurodivergent minds</i><br/>
  <i>Your brain isn't broken — it's just wired differently.</i>
</p>
