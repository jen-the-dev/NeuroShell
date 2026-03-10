import AVFoundation
import Foundation

// MARK: - Noise Generator
/// Procedural audio generator with per-element synthesis strategies.
/// Each SoundElement uses a distinct algorithm — rain has drops, fire crackles,
/// birds chirp, ocean surges — rather than just filtered pink noise.
final class NoiseGenerator {
    let element: SoundElement
    let sourceNode: AVAudioSourceNode

    init(element: SoundElement) {
        self.element = element

        guard let fmt = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) else {
            fatalError("Failed to create audio format")
        }
        let sr: Float = 44100

        switch element {
        case .rain:    sourceNode = Self.makeRain(fmt, sr)
        case .wind:    sourceNode = Self.makeWind(fmt, sr)
        case .ocean:   sourceNode = Self.makeOcean(fmt, sr)
        case .thunder: sourceNode = Self.makeThunder(fmt, sr)
        case .birds:   sourceNode = Self.makeBirds(fmt, sr)
        case .fire:    sourceNode = Self.makeFire(fmt, sr)
        case .forest:  sourceNode = Self.makeForest(fmt, sr)
        case .stream:  sourceNode = Self.makeStream(fmt, sr)
        }
    }

    // MARK: - Pink Noise Helper (Voss-McCartney)

    @inline(__always)
    private static func pinkStep(
        idx: inout UInt32,
        rows: inout [Float],
        runningSum: inout Float
    ) -> Float {
        idx &+= 1
        let changed = idx ^ (idx &- 1)
        for oct in 0..<16 {
            if changed & (1 << oct) != 0 {
                runningSum -= rows[oct]
                let w = Float.random(in: -1...1)
                rows[oct] = w
                runningSum += w
            }
        }
        return (runningSum + Float.random(in: -1...1)) / 17.0
    }

    // MARK: - Rain
    /// Band-passed pink noise with random raindrop impact impulses.
    private static func makeRain(_ fmt: AVAudioFormat, _ sr: Float) -> AVAudioSourceNode {
        var rows = [Float](repeating: 0, count: 16)
        var runSum: Float = 0; var idx: UInt32 = 0
        var lp: Float = 0; var hp: Float = 0
        // Drop state — attack ramp prevents sample-level discontinuity (clicks)
        var dropTimer: Float = 0; var dropDecay: Float = 0
        var dropAmp: Float = 0; var dropAttack: Float = 0
        // LP filter on drop noise — softer than raw white, less harsh
        var dropLp: Float = 0

        return AVAudioSourceNode(format: fmt) { _, _, fc, bl -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(bl)
            guard let buf = abl.first?.mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            let dt: Float = 1.0 / sr
            let attackInc: Float = dt / 0.001   // 1 ms linear attack ramp

            for i in 0..<Int(fc) {
                let noise = NoiseGenerator.pinkStep(idx: &idx, rows: &rows, runningSum: &runSum)

                // Band-pass: LP ~2.5 kHz then HP ~300 Hz for rainy texture
                lp += 0.30 * (noise - lp)
                let hpOut = lp - hp
                hp += 0.042 * hpOut
                var s = hpOut

                // Random raindrop impacts — short noise bursts
                dropTimer -= dt
                if dropTimer <= 0 {
                    dropAttack = 0           // start attack from zero — no click
                    dropDecay = 1.0
                    dropAmp = Float.random(in: 0.2...0.7)
                    dropTimer = Float.random(in: 0.003...0.06)
                }
                if dropDecay > 0.01 {
                    dropAttack = min(1.0, dropAttack + attackInc)   // 1 ms ramp
                    dropLp += 0.55 * (Float.random(in: -1...1) - dropLp)  // LP-filtered noise
                    s += dropLp * dropDecay * dropAttack * dropAmp * 0.45
                    dropDecay *= 0.99   // ~9 ms decay
                }

                buf[i] = tanhf(s * 2.5) * 0.45
            }
            return noErr
        }
    }

    // MARK: - Wind
    /// Deep low-passed noise with very slow gusting modulation.
    private static func makeWind(_ fmt: AVAudioFormat, _ sr: Float) -> AVAudioSourceNode {
        var rows = [Float](repeating: 0, count: 16)
        var runSum: Float = 0; var idx: UInt32 = 0
        var lp1: Float = 0; var lp2: Float = 0
        var gustPhase: Float = 0
        var subPhase: Float = Float.random(in: 0...1)

        return AVAudioSourceNode(format: fmt) { _, _, fc, bl -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(bl)
            guard let buf = abl.first?.mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            let dt: Float = 1.0 / sr

            for i in 0..<Int(fc) {
                let noise = NoiseGenerator.pinkStep(idx: &idx, rows: &rows, runningSum: &runSum)

                // Two-pole LP ~400 Hz — deep, muffled wind
                lp1 += 0.055 * (noise - lp1)
                lp2 += 0.055 * (lp1 - lp2)
                var s = lp2

                // Slow gusting: primary 0.07 Hz (~14 s) + secondary 0.03 Hz
                gustPhase += 0.07 * dt
                if gustPhase > 1 { gustPhase -= 1 }
                subPhase += 0.03 * dt
                if subPhase > 1 { subPhase -= 1 }

                let gust = sinf(gustPhase * 2.0 * Float.pi)
                let sub  = sinf(subPhase  * 2.0 * Float.pi) * 0.4
                let env  = 0.15 + 0.85 * max(0, (gust + sub) * 0.5 + 0.5)
                s *= env

                buf[i] = tanhf(s * 3.0) * 0.5
            }
            return noErr
        }
    }

    // MARK: - Ocean
    /// Rocky shoreline: two staggered wave oscillators for continuous crash energy.
    /// Each wave: cubic approach → sharp crash → rocky drain. Sub-bass impact thump,
    /// spray hiss, drainage hiss gated to recession only (prevents gain stacking).
    private static func makeOcean(_ fmt: AVAudioFormat, _ sr: Float) -> AVAudioSourceNode {
        var rows = [Float](repeating: 0, count: 16)
        var runSum: Float = 0; var idx: UInt32 = 0
        // Body band ~300 Hz — wave mass
        var bodyLp1: Float = 0; var bodyLp2: Float = 0
        // Sub band ~80 Hz — impact thump
        var subLp1: Float = 0; var subLp2: Float = 0
        // Spray/hiss: bandpass LP ~3 kHz → HP ~500 Hz
        var sprayLp: Float = 0; var sprayHp: Float = 0
        // Filtered fizz
        var fizzLp: Float = 0

        // Wave 1 — primary (~7 s period)
        var wave1Phase: Float = 0
        var impact1Decay: Float = 0
        var drain1Decay:  Float = 0
        var crash1Triggered = false

        // Wave 2 — staggered (~9 s period, offset so crashes interleave)
        var wave2Phase: Float = Float.random(in: 0.35...0.55)
        var impact2Decay: Float = 0
        var drain2Decay:  Float = 0
        var crash2Triggered = false

        // Size modulation ~11 s + slow tide ~45 s
        var subPhase:  Float = Float.random(in: 0...1)
        var tidePhase: Float = Float.random(in: 0...1)

        // Compute asymmetric surge from phase (0→1 cycle)
        func waveSurge(_ p: Float) -> Float {
            if p < 0.65 {
                let t = p / 0.65
                return t * t * t                       // cubic ease-in: slow approach
            } else if p < 0.75 {
                let t = (p - 0.65) / 0.10
                return 1.0 - t * t                     // fast quadratic crash
            } else {
                let t = (p - 0.75) / 0.25
                return max(0, (1.0 - t) * 0.30)        // slow rocky drain
            }
        }

        return AVAudioSourceNode(format: fmt) { _, _, fc, bl -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(bl)
            guard let buf = abl.first?.mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            let dt: Float = 1.0 / sr

            for i in 0..<Int(fc) {
                let noise = NoiseGenerator.pinkStep(idx: &idx, rows: &rows, runningSum: &runSum)

                // Filter banks
                subLp1   += 0.011 * (noise - subLp1)
                subLp2   += 0.011 * (subLp1 - subLp2)
                bodyLp1  += 0.042 * (noise - bodyLp1)
                bodyLp2  += 0.042 * (bodyLp1 - bodyLp2)
                sprayLp  += 0.38  * (noise - sprayLp)
                let sprayHpOut = sprayLp - sprayHp
                sprayHp  += 0.07  * sprayHpOut
                fizzLp   += 0.22  * (Float.random(in: -1...1) - fizzLp)

                // Size + tide envelopes
                subPhase  += (1.0 / 11.0) * dt; if subPhase  > 1 { subPhase  -= 1 }
                tidePhase += (1.0 / 45.0) * dt; if tidePhase > 1 { tidePhase -= 1 }
                let sizeEnv = 0.75 + 0.25 * sinf(subPhase  * 2.0 * Float.pi)
                let tide    = 0.85 + 0.15 * sinf(tidePhase * 2.0 * Float.pi)
                let tideEnv = sizeEnv * tide

                // — Wave 1 —
                let prev1 = wave1Phase
                wave1Phase += (1.0 / 7.0) * dt; if wave1Phase > 1 { wave1Phase -= 1 }
                let surge1 = waveSurge(wave1Phase)
                if prev1 < 0.65 && wave1Phase >= 0.65 && !crash1Triggered {
                    let v = Float.random(in: 0.7...1.0)
                    impact1Decay = v; drain1Decay = v * 0.9
                    crash1Triggered = true
                }
                if wave1Phase < 0.1 { crash1Triggered = false }

                // — Wave 2 —
                let prev2 = wave2Phase
                wave2Phase += (1.0 / 9.0) * dt; if wave2Phase > 1 { wave2Phase -= 1 }
                let surge2 = waveSurge(wave2Phase)
                if prev2 < 0.65 && wave2Phase >= 0.65 && !crash2Triggered {
                    let v = Float.random(in: 0.55...0.95)
                    impact2Decay = v; drain2Decay = v * 0.9
                    crash2Triggered = true
                }
                if wave2Phase < 0.1 { crash2Triggered = false }

                var s: Float = 0

                // Layer 1: body roar — both waves contribute
                s += bodyLp2 * (surge1 + surge2 * 0.75) * tideEnv * 2.8

                // Layer 2: sub-bass impact thumps — independent per wave
                if impact1Decay > 0.005 {
                    s += subLp2 * impact1Decay * 5.0
                    impact1Decay *= 0.99988   // ~250 ms
                }
                if impact2Decay > 0.005 {
                    s += subLp2 * impact2Decay * 4.0
                    impact2Decay *= 0.99988
                }

                // Layer 3: crash spray — threshold 0.45 for earlier hiss onset
                let crashGate1 = max(0, surge1 - 0.45)
                let crashGate2 = max(0, surge2 - 0.45)
                s += sprayHpOut * (crashGate1 * 2.2 + crashGate2 * 1.8)

                // Layer 4: rocky drain hiss — recession only, no stacking with crash
                if drain1Decay > 0.01 {
                    let rec1 = max(0, 1.0 - surge1 * 4.0)
                    s += sprayHpOut * drain1Decay * rec1 * 1.6
                    drain1Decay *= 0.99993   // ~2 s
                }
                if drain2Decay > 0.01 {
                    let rec2 = max(0, 1.0 - surge2 * 4.0)
                    s += sprayHpOut * drain2Decay * rec2 * 1.3
                    drain2Decay *= 0.99993
                }

                // Layer 5: fizz at crash peaks
                let fizz = max(0, surge1 - 0.68) + max(0, surge2 - 0.68)
                s += fizzLp * fizz * 0.7

                buf[i] = tanhf(s * 1.3) * 0.60
            }
            return noErr
        }
    }

    // MARK: - Thunder
    /// Distant rolling thunder: gradual swell attack (~200–400 ms) into slow multi-layer decay.
    /// Two independent event timers allow overlapping rumbles. No hard-onset transients.
    private static func makeThunder(_ fmt: AVAudioFormat, _ sr: Float) -> AVAudioSourceNode {
        var rows = [Float](repeating: 0, count: 16)
        var runSum: Float = 0; var idx: UInt32 = 0
        // Sub band ~80 Hz — 3-pole LP for deeper, more physical rumble
        var subLp1: Float = 0; var subLp2: Float = 0; var subLp3: Float = 0
        // Mid band ~200 Hz — 2-pole LP for the audible roll
        var midLp1: Float = 0; var midLp2: Float = 0
        // Filtered noise for very soft crack
        var crackLp: Float = 0; var crackDecay: Float = 0

        // Roll envelope — tracks current level and peak independently so we can ramp up
        var rollEnv: Float = 0; var rollPeak: Float = 0
        // Boom envelope — same pattern, slower attack and decay
        var boomEnv: Float = 0; var boomPeak: Float = 0

        // Two independent event cells so rumbles can overlap
        var timer1: Float = Float.random(in: 1.0...4.0)
        var timer2: Float = Float.random(in: 4.0...9.0)
        // Ambient modulation
        var ambPhase: Float = 0

        return AVAudioSourceNode(format: fmt) { _, _, fc, bl -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(bl)
            guard let buf = abl.first?.mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            let dt: Float = 1.0 / sr
            let rollAttackInc: Float = dt / 0.20   // 200 ms to peak
            let boomAttackInc: Float = dt / 0.40   // 400 ms to peak

            for i in 0..<Int(fc) {
                let noise = NoiseGenerator.pinkStep(idx: &idx, rows: &rows, runningSum: &runSum)

                // Sub: 3-pole LP ~80 Hz for deep felt rumble
                subLp1 += 0.011 * (noise - subLp1)
                subLp2 += 0.011 * (subLp1 - subLp2)
                subLp3 += 0.011 * (subLp2 - subLp3)

                // Mid: 2-pole LP ~200 Hz for audible rolling component
                midLp1 += 0.028 * (noise - midLp1)
                midLp2 += 0.028 * (midLp1 - midLp2)

                // LP-filtered noise for very soft crack
                crackLp += 0.35 * (Float.random(in: -1...1) - crackLp)

                // Quiet ambient bed — subtle constant presence, never total silence
                ambPhase += 0.05 * dt
                if ambPhase > 1 { ambPhase -= 1 }
                let amb = 0.05 + 0.03 * sinf(ambPhase * 2.0 * Float.pi)
                var s = (subLp3 * 2.0 + midLp2 * 1.5) * amb

                // Event cell 1 — main strike
                timer1 -= dt
                if timer1 <= 0 {
                    let intensity = Float.random(in: 0.5...1.0)
                    crackDecay = intensity * 0.35
                    rollPeak   = max(rollPeak, intensity * 0.9)
                    boomPeak   = max(boomPeak, intensity)
                    timer1     = Float.random(in: 5...14)
                }

                // Event cell 2 — secondary/distant overlap
                timer2 -= dt
                if timer2 <= 0 {
                    let intensity = Float.random(in: 0.3...0.7)
                    rollPeak = max(rollPeak, intensity * 0.6)
                    boomPeak = max(boomPeak, intensity * 0.75)
                    timer2   = Float.random(in: 6...18)
                }

                // Roll envelope: ramp up to peak, then decay
                if rollEnv < rollPeak {
                    rollEnv = min(rollPeak, rollEnv + rollPeak * rollAttackInc)
                } else {
                    rollEnv  *= 0.99992   // ~1.5 s decay
                    rollPeak *= 0.99992
                }

                // Boom envelope: slower attack, longer decay
                if boomEnv < boomPeak {
                    boomEnv = min(boomPeak, boomEnv + boomPeak * boomAttackInc)
                } else {
                    boomEnv  *= 0.99997   // ~3.5 s decay
                    boomPeak *= 0.99997
                }

                // Layer 1: faint filtered crack (~10 ms)
                if crackDecay > 0.005 {
                    s += crackLp * crackDecay * 0.25
                    crackDecay *= 0.990
                }

                // Layer 2: rolling mid rumble via smooth envelope
                s += midLp2 * rollEnv * 5.5

                // Layer 3: deep sub boom via smooth envelope
                s += subLp3 * boomEnv * 7.0

                buf[i] = tanhf(s * 1.5) * 0.6
            }
            return noErr
        }
    }

    // MARK: - Birds
    /// FM-synthesis chirps at random intervals over a quiet ambient bed.
    /// Two independent voices with different pitch ranges for realism.
    private static func makeBirds(_ fmt: AVAudioFormat, _ sr: Float) -> AVAudioSourceNode {
        // Voice 1 — lower pitched
        var ph1: Float = 0; var mp1: Float = 0
        var ct1: Float = Float.random(in: 0.3...1.5)
        var cd1: Float = 0; var ca1: Float = 0; var cf1: Float = 3000
        var c1on = false
        // Voice 2 — higher, shorter
        var ph2: Float = 0; var mp2: Float = 0
        var ct2: Float = Float.random(in: 0.8...2.5)
        var cd2: Float = 0; var ca2: Float = 0; var cf2: Float = 4500
        var c2on = false
        // Quiet background
        var rows = [Float](repeating: 0, count: 16)
        var runSum: Float = 0; var idx: UInt32 = 0
        var bgLp: Float = 0

        return AVAudioSourceNode(format: fmt) { _, _, fc, bl -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(bl)
            guard let buf = abl.first?.mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            let dt: Float = 1.0 / sr

            for i in 0..<Int(fc) {
                var s: Float = 0

                // Voice 1
                s += NoiseGenerator.chirpSample(
                    dt: dt, phase: &ph1, modPhase: &mp1,
                    timer: &ct1, dur: &cd1, age: &ca1,
                    freq: &cf1, active: &c1on,
                    freqLo: 2000, freqHi: 5500,
                    durLo: 0.04, durHi: 0.18,
                    gapLo: 0.3, gapHi: 2.0
                )

                // Voice 2
                s += NoiseGenerator.chirpSample(
                    dt: dt, phase: &ph2, modPhase: &mp2,
                    timer: &ct2, dur: &cd2, age: &ca2,
                    freq: &cf2, active: &c2on,
                    freqLo: 3000, freqHi: 6500,
                    durLo: 0.03, durHi: 0.12,
                    gapLo: 0.5, gapHi: 3.0
                ) * 0.7

                // Very quiet ambient background
                let noise = NoiseGenerator.pinkStep(idx: &idx, rows: &rows, runningSum: &runSum)
                bgLp += 0.05 * (noise - bgLp)
                s += bgLp * 0.06

                buf[i] = s
            }
            return noErr
        }
    }

    /// Single sample of an FM-synthesis bird chirp with pitch sweep.
    @inline(__always)
    private static func chirpSample(
        dt: Float,
        phase: inout Float, modPhase: inout Float,
        timer: inout Float, dur: inout Float, age: inout Float,
        freq: inout Float, active: inout Bool,
        freqLo: Float, freqHi: Float,
        durLo: Float, durHi: Float,
        gapLo: Float, gapHi: Float
    ) -> Float {
        if active {
            age += dt
            if age >= dur {
                active = false
                timer = Float.random(in: gapLo...gapHi)
                return 0
            }
            let p = age / dur
            // Envelope: fast attack, sustain, smooth release
            let env: Float
            if p < 0.08      { env = p / 0.08 }
            else if p < 0.6  { env = 1.0 }
            else              { env = max(0, (1.0 - p) / 0.4) }

            // Rising frequency sweep
            let sweep = freq * (1.0 + p * 0.3)
            // FM modulation for timbral richness
            modPhase += sweep * 2.1 * dt
            let fm = sinf(modPhase * 2.0 * Float.pi) * sweep * 0.4
            phase += (sweep + fm) * dt
            return sinf(phase * 2.0 * Float.pi) * env * 0.35
        } else {
            timer -= dt
            if timer <= 0 {
                active = true; age = 0
                dur = Float.random(in: durLo...durHi)
                freq = Float.random(in: freqLo...freqHi)
                phase = 0; modPhase = 0
            }
            return 0
        }
    }

    // MARK: - Fire
    /// Layered fire: combustion roar + flame hiss, both flicker-modulated,
    /// three independent crackle voices, and enhanced wood pops with sub-bass thump.
    private static func makeFire(_ fmt: AVAudioFormat, _ sr: Float) -> AVAudioSourceNode {
        var rows = [Float](repeating: 0, count: 16)
        var runSum: Float = 0; var idx: UInt32 = 0

        // Layer 1: Combustion roar — 2-pole LP ~1.5 kHz → HP ~200 Hz
        var roarLp1: Float = 0; var roarLp2: Float = 0; var roarHp: Float = 0

        // Layer 2: Flame hiss — LP ~4 kHz → HP ~600 Hz
        var hissLp: Float = 0; var hissHp: Float = 0

        // Flame flicker (3 incommensurate LFOs, randomised start phase)
        var flick1: Float = Float.random(in: 0...1)
        var flick2: Float = Float.random(in: 0...1)
        var flick3: Float = Float.random(in: 0...1)

        // Crackle Voice A (fast/bright — 5–40 ms)
        var crackTimerA: Float = Float.random(in: 0.005...0.040)
        var crackDecayA: Float = 0; var crackAttackA: Float = 0
        var crackAmpA:   Float = 0; var crackLpA:     Float = 0

        // Crackle Voice B (medium — 15–65 ms)
        var crackTimerB: Float = Float.random(in: 0.015...0.065)
        var crackDecayB: Float = 0; var crackAttackB: Float = 0
        var crackAmpB:   Float = 0; var crackLpB:     Float = 0

        // Crackle Voice C (deep/slow — 30–100 ms)
        var crackTimerC: Float = Float.random(in: 0.030...0.100)
        var crackDecayC: Float = 0; var crackAttackC: Float = 0
        var crackAmpC:   Float = 0; var crackLpC:     Float = 0

        // Wood pop — mid body + sub thump triggered together
        var popTimer:    Float = Float.random(in: 0.3...2.5)
        var popDecayMid: Float = 0; var popAttackMid: Float = 0; var popLpMid: Float = 0
        var popDecaySub: Float = 0; var popAttackSub: Float = 0; var popLpSub: Float = 0

        return AVAudioSourceNode(format: fmt) { _, _, fc, bl -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(bl)
            guard let buf = abl.first?.mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            let dt: Float    = 1.0 / sr
            let twoPi: Float = 2.0 * Float.pi

            let attackIncA:   Float = dt / 0.0003   // 0.3 ms
            let attackIncB:   Float = dt / 0.0004   // 0.4 ms
            let attackIncC:   Float = dt / 0.0005   // 0.5 ms
            let attackIncPop: Float = dt / 0.001    // 1.0 ms

            for i in 0..<Int(fc) {
                let noise = NoiseGenerator.pinkStep(idx: &idx, rows: &rows, runningSum: &runSum)

                // Flame flicker envelope — 3 incommensurate LFOs, never repeating exactly
                flick1 += 0.8 * dt;  if flick1 > 1 { flick1 -= 1 }
                flick2 += 1.7 * dt;  if flick2 > 1 { flick2 -= 1 }
                flick3 += 3.1 * dt;  if flick3 > 1 { flick3 -= 1 }
                let rawFlick = sinf(flick1 * twoPi) * 0.5
                             + sinf(flick2 * twoPi) * 0.3
                             + sinf(flick3 * twoPi) * 0.2
                let flicker: Float = 0.55 + 0.45 * rawFlick   // [0.10, 1.00]

                // Layer 1: Combustion roar — the foundational fire "whoosh"
                roarLp1 += 0.20 * (noise   - roarLp1)
                roarLp2 += 0.20 * (roarLp1 - roarLp2)
                let roarHpOut = roarLp2 - roarHp
                roarHp += 0.028 * roarHpOut
                var s = roarHpOut * flicker * 0.55

                // Layer 2: Flame hiss — bright gas-burning texture
                hissLp += 0.42 * (noise - hissLp)
                let hissHpOut = hissLp - hissHp
                hissHp += 0.082 * hissHpOut
                s += hissHpOut * flicker * 0.22

                // Layer 3: Crackle Voice A (fast/bright)
                crackTimerA -= dt
                if crackTimerA <= 0 {
                    crackAttackA = 0; crackDecayA = 1.0
                    crackAmpA    = Float.random(in: 0.15...0.55)
                    crackTimerA  = Float.random(in: 0.005...0.040)
                }
                if crackDecayA > 0.01 {
                    crackAttackA  = min(1.0, crackAttackA + attackIncA)
                    crackLpA     += 0.50 * (Float.random(in: -1...1) - crackLpA)
                    s += crackLpA * crackDecayA * crackAttackA * crackAmpA * 0.30
                    crackDecayA  *= 0.984   // ~6 ms
                }

                // Layer 4: Crackle Voice B (medium)
                crackTimerB -= dt
                if crackTimerB <= 0 {
                    crackAttackB = 0; crackDecayB = 1.0
                    crackAmpB    = Float.random(in: 0.20...0.60)
                    crackTimerB  = Float.random(in: 0.015...0.065)
                }
                if crackDecayB > 0.01 {
                    crackAttackB  = min(1.0, crackAttackB + attackIncB)
                    crackLpB     += 0.38 * (Float.random(in: -1...1) - crackLpB)
                    s += crackLpB * crackDecayB * crackAttackB * crackAmpB * 0.28
                    crackDecayB  *= 0.987   // ~8 ms
                }

                // Layer 5: Crackle Voice C (deep/slow)
                crackTimerC -= dt
                if crackTimerC <= 0 {
                    crackAttackC = 0; crackDecayC = 1.0
                    crackAmpC    = Float.random(in: 0.25...0.70)
                    crackTimerC  = Float.random(in: 0.030...0.100)
                }
                if crackDecayC > 0.01 {
                    crackAttackC  = min(1.0, crackAttackC + attackIncC)
                    crackLpC     += 0.24 * (Float.random(in: -1...1) - crackLpC)
                    s += crackLpC * crackDecayC * crackAttackC * crackAmpC * 0.25
                    crackDecayC  *= 0.990   // ~10 ms
                }

                // Layer 6: Wood pop — mid crack + sub-bass thump
                popTimer -= dt
                if popTimer <= 0 {
                    popAttackMid = 0; popDecayMid = 1.0
                    popAttackSub = 0; popDecaySub = 1.0
                    popTimer = Float.random(in: 0.3...2.5)
                }
                if popDecayMid > 0.005 {
                    popAttackMid  = min(1.0, popAttackMid + attackIncPop)
                    popLpMid     += 0.082 * (Float.random(in: -1...1) - popLpMid)
                    s += popLpMid * popDecayMid * popAttackMid * 0.55
                    popDecayMid  *= 0.9970   // ~35 ms
                }
                if popDecaySub > 0.005 {
                    popAttackSub  = min(1.0, popAttackSub + attackIncPop)
                    popLpSub     += 0.011 * (Float.random(in: -1...1) - popLpSub)
                    s += popLpSub * popDecaySub * popAttackSub * 0.65
                    popDecaySub  *= 0.9985   // ~70 ms
                }

                buf[i] = tanhf(s * 1.8) * 0.52
            }
            return noErr
        }
    }

    // MARK: - Forest
    /// Layered forest: leafy mid-band rustling, cricket/insect texture, and distinct rustle events.
    private static func makeForest(_ fmt: AVAudioFormat, _ sr: Float) -> AVAudioSourceNode {
        var rows = [Float](repeating: 0, count: 16)
        var runSum: Float = 0; var idx: UInt32 = 0
        // Leaf rustle band (mid)
        var leafLp: Float = 0; var leafHp: Float = 0
        // Bright rustle band (for distinct rustle events)
        var rustLp: Float = 0
        // Multiple sway oscillators for organic movement
        var sway1: Float = 0; var sway2: Float = Float.random(in: 0...1)
        var sway3: Float = Float.random(in: 0...1)
        // Rustle events
        var rustleTimer: Float = Float.random(in: 1...3); var rustleDecay: Float = 0
        // Cricket layer
        var cricketPhase: Float = 0; var cricketTimer: Float = Float.random(in: 0.5...2)
        var cricketDur: Float = 0; var cricketAge: Float = 0
        var cricketFreq: Float = 4800; var cricketOn = false
        // Occasional creak
        var creakPhase: Float = 0; var creakTimer: Float = Float.random(in: 5...15)
        var creakDecay: Float = 0; var creakFreq: Float = 280

        return AVAudioSourceNode(format: fmt) { _, _, fc, bl -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(bl)
            guard let buf = abl.first?.mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            let dt: Float = 1.0 / sr

            for i in 0..<Int(fc) {
                let noise = NoiseGenerator.pinkStep(idx: &idx, rows: &rows, runningSum: &runSum)

                // Layer 1: base leaf rustle — band-pass LP ~1.5 kHz, HP ~250 Hz
                leafLp += 0.20 * (noise - leafLp)
                let hpOut = leafLp - leafHp
                leafHp += 0.035 * hpOut

                // Organic sway from 3 incommensurate oscillators
                sway1 += 0.04 * dt; if sway1 > 1 { sway1 -= 1 }
                sway2 += 0.023 * dt; if sway2 > 1 { sway2 -= 1 }
                sway3 += 0.011 * dt; if sway3 > 1 { sway3 -= 1 }
                let swayVal = sinf(sway1 * 2.0 * Float.pi) * 0.35
                    + sinf(sway2 * 2.0 * Float.pi) * 0.25
                    + sinf(sway3 * 2.0 * Float.pi) * 0.15
                let swayEnv = 0.35 + 0.65 * max(0, swayVal * 0.5 + 0.5)

                var s = hpOut * swayEnv

                // Layer 2: distinct rustle bursts (brighter, sharper)
                rustleTimer -= dt
                if rustleTimer <= 0 {
                    rustleDecay = Float.random(in: 0.4...0.9)
                    rustleTimer = Float.random(in: 1.0...4.0)
                }
                if rustleDecay > 0.02 {
                    // Bright filtered noise for rustles
                    rustLp += 0.35 * (noise - rustLp)
                    s += rustLp * rustleDecay * 0.5
                    rustleDecay *= 0.9999   // ~1 second fade
                }

                // Layer 3: cricket/insect — fast AM sine at ~4-6 kHz
                if cricketOn {
                    cricketAge += dt
                    if cricketAge >= cricketDur {
                        cricketOn = false
                        cricketTimer = Float.random(in: 0.3...2.5)
                    } else {
                        let cEnv = 1.0 - (cricketAge / cricketDur)  // linear fade
                        cricketPhase += cricketFreq * dt
                        // Fast AM at ~45 Hz gives the buzzy insect quality
                        let am = (sinf(cricketPhase * 45.0 * 2.0 * Float.pi / cricketFreq) > 0) ? Float(1.0) : Float(0.0)
                        let cricket = sinf(cricketPhase * 2.0 * Float.pi) * am * cEnv
                        s += cricket * 0.08
                    }
                } else {
                    cricketTimer -= dt
                    if cricketTimer <= 0 {
                        cricketOn = true; cricketAge = 0
                        cricketDur = Float.random(in: 0.3...1.5)
                        cricketFreq = Float.random(in: 4200...6000)
                        cricketPhase = 0
                    }
                }

                // Layer 4: occasional tree creak (low FM tone, rare)
                creakTimer -= dt
                if creakTimer <= 0 {
                    creakDecay = Float.random(in: 0.3...0.6)
                    creakFreq = Float.random(in: 200...380)
                    creakTimer = Float.random(in: 8...20)
                    creakPhase = 0
                }
                if creakDecay > 0.02 {
                    creakPhase += creakFreq * dt
                    let creakFm = sinf(creakPhase * 3.7 * 2.0 * Float.pi) * 30
                    let creak = sinf((creakFreq + creakFm) * creakPhase / creakFreq * 2.0 * Float.pi)
                    s += creak * creakDecay * 0.06
                    creakDecay *= 0.99993   // ~2 second fade
                }

                buf[i] = tanhf(s * 2.0) * 0.4
            }
            return noErr
        }
    }

    // MARK: - Stream
    /// Babbling brook: continuous turbulent flow — never silent, no fast oscillators.
    /// All modulation is sub-Hz (0.08–0.21 Hz) so there's no audible pulsing.
    /// Low-frequency gurgles over rocks replace the rain-like high-frequency splashes.
    private static func makeStream(_ fmt: AVAudioFormat, _ sr: Float) -> AVAudioSourceNode {
        var rows = [Float](repeating: 0, count: 16)
        var runSum: Float = 0; var idx: UInt32 = 0

        // Layer 1: Deep turbulent body — 2-pole LP ~245 Hz
        var deepLp1: Float = 0; var deepLp2: Float = 0
        // Layer 2: Mid turbulence — 2-pole LP ~700 Hz, HP ~120 Hz
        var midLp1: Float = 0; var midLp2: Float = 0; var midHp: Float = 0
        // Layer 3: Bright sparkle — LP ~2.5 kHz, HP ~600 Hz
        var sparkLp: Float = 0; var sparkHp: Float = 0

        // Sub-Hz flow modulation — 3 incommensurate slow LFOs (~12 s, ~8 s, ~5 s)
        // All well below audible frequency — produce gentle volume swells, not tonal artifacts
        var flowPhase1: Float = Float.random(in: 0...1)
        var flowPhase2: Float = Float.random(in: 0...1)
        var flowPhase3: Float = Float.random(in: 0...1)

        // Layer 4: Rock gurgle — water tumbling over stones (~0.5–3 s intervals, ~70 ms decay)
        var gurgle1Timer:  Float = Float.random(in: 0.5...3.0)
        var gurgle1Decay:  Float = 0; var gurgle1Amp:    Float = 0
        var gurgle1Attack: Float = 0; var gurgle1Lp:     Float = 0

        // Layer 5: Deep slow gurgle — lower, rarer (~2–6 s intervals, ~200 ms decay)
        var gurgle2Timer:  Float = Float.random(in: 2.0...6.0)
        var gurgle2Decay:  Float = 0; var gurgle2Amp:    Float = 0
        var gurgle2Attack: Float = 0
        var gurgle2Lp1:    Float = 0; var gurgle2Lp2:    Float = 0

        return AVAudioSourceNode(format: fmt) { _, _, fc, bl -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(bl)
            guard let buf = abl.first?.mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            let dt: Float = 1.0 / sr
            let gurgle1AttackInc: Float = dt / 0.015   // 15 ms — soft onset
            let gurgle2AttackInc: Float = dt / 0.030   // 30 ms — even softer

            for i in 0..<Int(fc) {
                let noise = NoiseGenerator.pinkStep(idx: &idx, rows: &rows, runningSum: &runSum)

                // Sub-Hz flow modulation — gentle volume swells, never audible as tone
                flowPhase1 += 0.08 * dt; if flowPhase1 > 1 { flowPhase1 -= 1 }
                flowPhase2 += 0.13 * dt; if flowPhase2 > 1 { flowPhase2 -= 1 }
                flowPhase3 += 0.21 * dt; if flowPhase3 > 1 { flowPhase3 -= 1 }
                let flowMod = 0.65 + 0.20 * sinf(flowPhase1 * 2.0 * Float.pi)
                           + 0.10 * sinf(flowPhase2 * 2.0 * Float.pi)
                           + 0.05 * sinf(flowPhase3 * 2.0 * Float.pi)  // [0.30, 1.00]

                // Layer 1: Deep turbulent body — continuous, always present
                deepLp1 += 0.035 * (noise - deepLp1)
                deepLp2 += 0.035 * (deepLp1 - deepLp2)
                var s = deepLp2 * flowMod * 1.8

                // Layer 2: Mid turbulence — bandpass gives the characteristic stream "rush"
                midLp1 += 0.098 * (noise - midLp1)
                midLp2 += 0.098 * (midLp1 - midLp2)
                let midHpOut = midLp2 - midHp
                midHp += 0.017 * midHpOut
                s += midHpOut * flowMod * 1.4

                // Layer 3: Bright sparkle — constant airy shimmer of water surface
                sparkLp += 0.30 * (noise - sparkLp)
                let sparkHpOut = sparkLp - sparkHp
                sparkHp += 0.082 * sparkHpOut
                s += sparkHpOut * flowMod * 0.45

                // Layer 4: Rock gurgle — LP ~380 Hz noise burst, 15 ms attack, ~70 ms decay
                gurgle1Timer -= dt
                if gurgle1Timer <= 0 {
                    gurgle1Attack = 0
                    gurgle1Decay  = 1.0
                    gurgle1Amp    = Float.random(in: 0.4...0.9)
                    gurgle1Timer  = Float.random(in: 0.5...3.0)
                }
                if gurgle1Decay > 0.01 {
                    gurgle1Attack  = min(1.0, gurgle1Attack + gurgle1AttackInc)
                    gurgle1Lp     += 0.055 * (Float.random(in: -1...1) - gurgle1Lp)
                    s += gurgle1Lp * gurgle1Decay * gurgle1Attack * gurgle1Amp * 1.0
                    gurgle1Decay  *= 0.9985   // ~70 ms
                }

                // Layer 5: Deep slow gurgle — LP ~155 Hz 2-pole, 30 ms attack, ~200 ms decay
                gurgle2Timer -= dt
                if gurgle2Timer <= 0 {
                    gurgle2Attack = 0
                    gurgle2Decay  = 1.0
                    gurgle2Amp    = Float.random(in: 0.5...1.0)
                    gurgle2Timer  = Float.random(in: 2.0...6.0)
                }
                if gurgle2Decay > 0.01 {
                    gurgle2Attack  = min(1.0, gurgle2Attack + gurgle2AttackInc)
                    gurgle2Lp1    += 0.022 * (Float.random(in: -1...1) - gurgle2Lp1)
                    gurgle2Lp2    += 0.022 * (gurgle2Lp1 - gurgle2Lp2)
                    s += gurgle2Lp2 * gurgle2Decay * gurgle2Attack * gurgle2Amp * 1.5
                    gurgle2Decay  *= 0.9995   // ~210 ms
                }

                buf[i] = tanhf(s * 1.6) * 0.50
            }
            return noErr
        }
    }
}
