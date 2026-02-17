# 🎬 NeuroShell Demo Script

> Estimated runtime: 3–5 minutes  
> Record with: QuickTime (⌘⇧5) or OBS  
> Resolution: 1920×1080 recommended  
> Tip: Pause 1–2 seconds between each action so viewers can follow

---

## Scene 1: First Launch (30 sec)
**What to show:** The app opens with a warm welcome — not a scary blank terminal.

```
[Action] Launch NeuroShell (⌘R from Xcode)
[Pause]  Let the welcome messages appear in the terminal
[Show]   Point out the sidebar: navigation, timer status, mood selector
```

**Narration idea:** *"When you open NeuroShell, you're not greeted with a blank cursor and silence. You get a welcome, tips, and a reminder that you can just ask for help."*

---

## Scene 2: Getting Help (20 sec)
**What to show:** Built-in help is friendly, not a man page wall of text.

```
help
```

**Narration idea:** *"Type 'help' and you get human-readable guidance, not a wall of flags and options."*

---

## Scene 3: Smart Suggestions — Natural Language (40 sec)
**What to show:** Start typing in plain English and watch suggestions appear in real-time.

```
[Type slowly] show me what files are here
[Pause]       Let the suggestion bar populate
[Click]       Click the "ls -la" suggestion
[Pause]       Let it run, show the ✅ celebration message
```

Then try another:

```
[Type slowly] find large files
[Pause]       Show the suggestions that appear
[Click]       Pick one or press Enter
```

Then one more:

```
[Type slowly] go home
[Pause]       Show "cd ~" suggestion appears
[Click]       Run it
```

**Narration idea:** *"You don't need to memorize commands. Just describe what you want in your own words. NeuroShell suggests the right command and explains what it does."*

---

## Scene 4: Command Explanations (20 sec)
**What to show:** The yellow explanation bar that appears while typing.

```
[Type slowly, don't press Enter] grep
[Pause]       Show the 💡 explanation: "Searches for text in files — like Ctrl+F but for multiple files"
[Clear input]
[Type slowly] chmod
[Pause]       Show explanation: "Changes who can access a file — like changing locks"
[Clear input]
[Type slowly] sudo
[Pause]       Show explanation with ⚠️ warning
```

**Narration idea:** *"Every command gets a real-time, jargon-free explanation. No Googling, no guessing."*

---

## Scene 5: Running Real Commands (30 sec)
**What to show:** The terminal actually works — it's not a toy.

```
pwd
ls -la
mkdir neuroshell-demo
cd neuroshell-demo
touch hello.txt
echo "NeuroShell is awesome" > hello.txt
cat hello.txt
ls -la
```

**Narration idea:** *"This is a real terminal. Everything you'd normally do works here — but with guardrails."*

---

## Scene 6: Error Handling — Gentle, Not Scary (30 sec)
**What to show:** Trigger errors and show how NeuroShell responds with kindness.

```
cd nonexistent-folder
```
> Shows: "Directory not found" + "💡 Tip: Use 'ls' to see what's in the current directory"

```
fakecmd123
```
> Shows: error + "💡 This might be a permissions issue or the command might not exist"

```
cat doesnotexist.txt
```
> Shows: error with helpful guidance

**Narration idea:** *"When something goes wrong, you don't get yelled at. You get an explanation, a suggestion, and a reminder that errors are just clues."*

---

## Scene 7: Encouragement System (15 sec)
**What to show:** The built-in emotional support.

```
encourage me
```
> Shows a random encouragement message like "🌟 You're doing amazing!"

```
encourage
```
> Another one — show it rotates through different messages

**Narration idea:** *"Sometimes you just need to hear that you're doing okay."*

---

## Scene 8: "Where Was I?" (25 sec)
**What to show:** Context recovery — the killer feature for ADHD.

First, build up some context:
```
cd ~
cd Desktop
git status
ls -la
```

Then click the **"Where was I?"** button in the top-right corner of the terminal.

> Shows: current directory, recent commands, pinned notes, saved memory slots

**Narration idea:** *"You got distracted. You came back. You have no idea what you were doing. One click and NeuroShell tells you exactly where you left off."*

---

## Scene 9: Task Chunker (45 sec)
**What to show:** Click **"Task Chunker"** in the sidebar.

```
[Action] Click "Task Chunker" in sidebar
[Type]   "Deploy my project" in the description box
[Click]  "Break It Down!" button
[Pause]  Show the generated steps with difficulty ratings and time estimates
```

Show the steps:
> 1. 🟢 Check your status — `git status` (~2 min)  
> 2. 🟡 Run tests — `npm test` (~5 min)  
> 3. 🟡 Build the project — `npm run build` (~5 min)  
> ...

```
[Click]  The "Run" button on Step 1 to show it executes in the terminal
[Click]  The ✓ checkmark to mark a step complete — show the celebration
```

Then try a template:
```
[Click]  "Debug an error" template button
[Pause]  Show how it generates a different set of steps
```

**Narration idea:** *"'Deploy my project' is terrifying. Five small steps with green dots? That's doable. Task Chunker turns mountains into staircases."*

---

## Scene 10: Quick Actions (20 sec)
**What to show:** Click **"Quick Actions"** in the sidebar.

```
[Action] Click "Quick Actions" in sidebar
[Show]   Scroll through the categorized buttons
[Click]  "Where Am I?" button → runs pwd
[Click]  "What's Here?" button → runs ls -la  
[Click]  "Open Finder Here" → opens Finder at current directory
```

**Narration idea:** *"Zero memorization. Just buttons. Tap what you want, it runs."*

---

## Scene 11: Mood Check-In (15 sec)
**What to show:** Click different mood emojis in the sidebar footer.

```
[Click]  😊 emoji → show "Awesome! Let's make the most of this energy!"
[Click]  😰 emoji → show "Take a breath. You don't have to do everything right now."
```

**Narration idea:** *"NeuroShell checks in with you. When you tell it you're overwhelmed, it doesn't push harder — it pulls back."*

---

## Scene 12: Timer & Breaks (25 sec)
**What to show:** Click **"Timer & Breaks"** in the sidebar.

```
[Action] Click "Timer & Breaks" in sidebar
[Show]   Session timer counting, progress bar toward break
[Click]  The "☕ Quick — 5 min" break button
[Show]   Break countdown starts, break ideas appear
```

**Narration idea:** *"Time blindness is real. NeuroShell tracks time so you don't have to, and makes taking breaks feel like a reward, not a failure."*

---

## Scene 13: Breathing Exercise (30 sec)
**What to show:** Click **"Breathing"** in the sidebar.

```
[Action] Click "Breathing" in sidebar
[Click]  Select "Box Breathing" pattern
[Click]  "Start Breathing" button
[Show]   Watch the circle expand and contract for 1-2 full cycles
[Pause]  Show the affirmation text at the bottom
[Click]  "Stop" after 2 cycles (don't wait for all 4 in the demo)
```

**Narration idea:** *"When your nervous system is on fire, you don't need another productivity tool. You need to breathe. NeuroShell has that too."*

---

## Scene 14: Settings (15 sec)
**What to show:** Quick fly-through of settings.

```
[Action] Click "Settings" in sidebar
[Show]   Scroll through — point out:
         • Font size slider
         • Hyperfocus limit (45 min default)
         • Reminder toggles
         • Reduce motion / high contrast accessibility
         • "Your brain isn't broken" message at the bottom
```

**Narration idea:** *"Everything is customizable. Your brain, your rules."*

---

## Scene 15: Closing Shot (10 sec)
**What to show:** Switch back to terminal tab.

```
[Action] Click "Terminal" in sidebar

breathe
```

> Shows: "🫁 Take a deep breath..."

End on the terminal with the message visible.

**Narration idea:** *"NeuroShell. A kinder terminal for differently wired minds."*

---

## 🎥 Recording Tips

| Tip | Why |
|-----|-----|
| Type slowly (2-3 chars/sec) | Viewers need to read what you're typing |
| Pause 2 seconds after each result | Let the output breathe on screen |
| Use ⌘+ to zoom the app to 125-150% | Better readability in video |
| Record audio separately | Cleaner narration, easier to edit |
| Show your face in a corner (optional) | Builds connection for hackathon judges |
| Keep it under 5 minutes | Attention spans — you know this one 😉 |

## 🎵 Suggested Background Music
Something lo-fi, calm, and unobtrusive. Try:
- [Lofi Girl](https://www.youtube.com/watch?v=jfKfPfyJRdk) (royalty-free streams)
- [Chillhop](https://chillhop.com/listen) (free with attribution)
- Or just silence — the app speaks for itself

---

## Quick Command Sequence (Copy-Paste Cheat Sheet)

If you just want the raw commands in order:

```
help
ls -la
pwd
mkdir neuroshell-demo
cd neuroshell-demo
touch hello.txt
echo "NeuroShell is awesome" > hello.txt
cat hello.txt
cd nonexistent-folder
fakecmd123
encourage me
cd ~
ls -la
breathe
```

---

*Total demo flow: 15 scenes, ~4 minutes, covers every major feature.*
