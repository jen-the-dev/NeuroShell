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
        var dropTimer: Float = 0; var dropDecay: Float = 0; var dropAmp: Float = 0

        return AVAudioSourceNode(format: fmt) { _, _, fc, bl -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(bl)
            guard let buf = abl.first?.mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            let dt: Float = 1.0 / sr

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
                    dropDecay = 1.0
                    dropAmp = Float.random(in: 0.2...0.7)
                    dropTimer = Float.random(in: 0.003...0.06)
                }
                if dropDecay > 0.01 {
                    s += Float.random(in: -1...1) * dropDecay * dropAmp * 0.4
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
    /// Dual-band ocean with audible wave surges, foamy crests, and receding hiss.
    private static func makeOcean(_ fmt: AVAudioFormat, _ sr: Float) -> AVAudioSourceNode {
        var rows = [Float](repeating: 0, count: 16)
        var runSum: Float = 0; var idx: UInt32 = 0
        // Body band (~350 Hz)
        var bodyLp1: Float = 0; var bodyLp2: Float = 0
        // Surf/hiss band (~2 kHz)
        var surfLp: Float = 0; var surfHp: Float = 0
        // Wave oscillators
        var wavePhase: Float = 0
        var subPhase: Float = Float.random(in: 0...1)
        var tidePhase: Float = Float.random(in: 0...1)

        return AVAudioSourceNode(format: fmt) { _, _, fc, bl -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(bl)
            guard let buf = abl.first?.mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            let dt: Float = 1.0 / sr

            for i in 0..<Int(fc) {
                let noise = NoiseGenerator.pinkStep(idx: &idx, rows: &rows, runningSum: &runSum)
                let white = Float.random(in: -1...1)

                // Band 1: body — two-pole LP ~350 Hz (audible on laptop speakers)
                bodyLp1 += 0.048 * (noise - bodyLp1)
                bodyLp2 += 0.048 * (bodyLp1 - bodyLp2)

                // Band 2: surf hiss — LP ~2 kHz then HP ~600 Hz
                surfLp += 0.25 * (noise - surfLp)
                let surfHpOut = surfLp - surfHp
                surfHp += 0.08 * surfHpOut

                // Primary wave ~7 seconds (asymmetric: slow build, faster crash)
                wavePhase += 0.143 * dt
                if wavePhase > 1 { wavePhase -= 1 }
                let rawWave = sinf(wavePhase * 2.0 * Float.pi)
                // Shape: positive half is the surge/crash, negative is the calm trough
                let surge = rawWave > 0 ? powf(rawWave, 0.7) : rawWave * 0.3

                // Secondary wave ~11 s for variation
                subPhase += 0.091 * dt
                if subPhase > 1 { subPhase -= 1 }
                let sub = sinf(subPhase * 2.0 * Float.pi) * 0.25

                // Slow tide ~45 s for long-term drift
                tidePhase += 0.022 * dt
                if tidePhase > 1 { tidePhase -= 1 }
                let tide = sinf(tidePhase * 2.0 * Float.pi) * 0.15

                // Combined envelope (0.05 – 1.0)
                let env = max(0.05, min(1.0, (surge + sub + tide) * 0.5 + 0.55))

                // Mix body with envelope
                var s = bodyLp2 * env * 2.5

                // Foam/wash: surf hiss only at wave crests
                let foamGate = max(0, surge - 0.1)
                s += surfHpOut * foamGate * 1.8

                // Extra white noise fizz at the peak of each wave
                let fizz = max(0, surge - 0.5)
                s += white * fizz * 0.35

                buf[i] = tanhf(s * 1.8) * 0.55
            }
            return noErr
        }
    }

    // MARK: - Thunder
    /// Dual-band rumble with sharp crack transients and slow rolling decay.
    private static func makeThunder(_ fmt: AVAudioFormat, _ sr: Float) -> AVAudioSourceNode {
        var rows = [Float](repeating: 0, count: 16)
        var runSum: Float = 0; var idx: UInt32 = 0
        // Sub band ~100 Hz (feel)
        var subLp1: Float = 0; var subLp2: Float = 0
        // Mid band ~250 Hz (hear) — this is what makes thunder audible on small speakers
        var midLp1: Float = 0; var midLp2: Float = 0
        // Crack transient state
        var crackDecay: Float = 0
        // Rolling rumble (medium decay)
        var rollDecay: Float = 0
        // Deep boom (slow decay)
        var boomDecay: Float = 0
        // Event timer
        var boomTimer: Float = Float.random(in: 1.5...5)
        // Ambient modulation
        var ambPhase: Float = 0

        return AVAudioSourceNode(format: fmt) { _, _, fc, bl -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(bl)
            guard let buf = abl.first?.mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            let dt: Float = 1.0 / sr

            for i in 0..<Int(fc) {
                let noise = NoiseGenerator.pinkStep(idx: &idx, rows: &rows, runningSum: &runSum)
                let white = Float.random(in: -1...1)

                // Sub band: two-pole LP ~100 Hz
                subLp1 += 0.014 * (noise - subLp1)
                subLp2 += 0.014 * (subLp1 - subLp2)

                // Mid band: two-pole LP ~250 Hz — audible on laptop speakers
                midLp1 += 0.035 * (noise - midLp1)
                midLp2 += 0.035 * (midLp1 - midLp2)

                // Ambient bed — slow undulation so it's not dead silence between booms
                ambPhase += 0.06 * dt
                if ambPhase > 1 { ambPhase -= 1 }
                let amb = 0.15 + 0.1 * sinf(ambPhase * 2.0 * Float.pi)
                var s = (subLp2 * 1.5 + midLp2 * 2.0) * amb

                // Boom event
                boomTimer -= dt
                if boomTimer <= 0 {
                    let intensity = Float.random(in: 0.5...1.0)
                    crackDecay = intensity          // sharp crack
                    rollDecay = intensity * 0.8     // mid-duration rolling
                    boomDecay = intensity            // long sub boom
                    boomTimer = Float.random(in: 3...12)
                }

                // Layer 1: crack — bright transient (white noise, ~8 ms)
                if crackDecay > 0.01 {
                    s += white * crackDecay * 0.7
                    crackDecay *= 0.9985   // ~8 ms
                }

                // Layer 2: rolling mid rumble (~1.5 second decay)
                if rollDecay > 0.01 {
                    s += midLp1 * rollDecay * 5.0
                    rollDecay *= 0.99992   // ~1.5 s
                }

                // Layer 3: deep boom (~4 second decay)
                if boomDecay > 0.01 {
                    s += subLp2 * boomDecay * 6.0
                    boomDecay *= 0.99997   // ~3.5 s
                }

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
    /// Rapid crackle impulses + occasional bigger pops + quiet low rumble bed.
    private static func makeFire(_ fmt: AVAudioFormat, _ sr: Float) -> AVAudioSourceNode {
        var rows = [Float](repeating: 0, count: 16)
        var runSum: Float = 0; var idx: UInt32 = 0
        var lpBed: Float = 0
        var crackTimer: Float = 0; var crackDecay: Float = 0; var crackAmp: Float = 0
        var popTimer: Float = Float.random(in: 0.3...1.5); var popDecay: Float = 0

        return AVAudioSourceNode(format: fmt) { _, _, fc, bl -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(bl)
            guard let buf = abl.first?.mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            let dt: Float = 1.0 / sr

            for i in 0..<Int(fc) {
                let noise = NoiseGenerator.pinkStep(idx: &idx, rows: &rows, runningSum: &runSum)

                // Low rumble bed
                lpBed += 0.008 * (noise - lpBed)
                var s = lpBed * 0.25

                // Frequent small crackles (every 8-80 ms)
                crackTimer -= dt
                if crackTimer <= 0 {
                    crackDecay = 1.0
                    crackAmp = Float.random(in: 0.15...0.6)
                    crackTimer = Float.random(in: 0.008...0.08)
                }
                if crackDecay > 0.01 {
                    s += Float.random(in: -1...1) * crackDecay * crackAmp * 0.4
                    crackDecay *= 0.985   // ~5 ms decay
                }

                // Bigger pops (every 0.2-1.5 s)
                popTimer -= dt
                if popTimer <= 0 {
                    popDecay = 1.0
                    popTimer = Float.random(in: 0.2...1.5)
                }
                if popDecay > 0.01 {
                    s += Float.random(in: -1...1) * popDecay * 0.6
                    popDecay *= 0.993   // ~15 ms decay
                }

                buf[i] = tanhf(s * 2.0) * 0.5
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
    /// Babbling brook: mid-frequency water flow bed, bright bubbling, and random splash events.
    private static func makeStream(_ fmt: AVAudioFormat, _ sr: Float) -> AVAudioSourceNode {
        var rows = [Float](repeating: 0, count: 16)
        var runSum: Float = 0; var idx: UInt32 = 0
        // Flow bed (mid freq body)
        var flowLp1: Float = 0; var flowLp2: Float = 0
        // Bright bubble layer
        var bubLp: Float = 0; var bubHp: Float = 0
        // Bubble oscillators with drifting rates
        var bubblePhases: [Float] = [0, 0, 0, 0, 0, 0]
        var bubbleRates: [Float] = [3.2, 5.7, 8.1, 11.3, 2.4, 6.9]
        var driftTimer: Float = 0
        // Splash events (small gurgle/drip sounds)
        var splashTimer: Float = Float.random(in: 0.1...0.5)
        var splashDecay: Float = 0; var splashAmp: Float = 0
        // Gentle flow modulation
        var flowPhase: Float = 0

        return AVAudioSourceNode(format: fmt) { _, _, fc, bl -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(bl)
            guard let buf = abl.first?.mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            let dt: Float = 1.0 / sr

            for i in 0..<Int(fc) {
                let noise = NoiseGenerator.pinkStep(idx: &idx, rows: &rows, runningSum: &runSum)

                // Layer 1: mid-frequency flow bed — two-pole LP ~600 Hz for body
                flowLp1 += 0.08 * (noise - flowLp1)
                flowLp2 += 0.08 * (flowLp1 - flowLp2)

                // Gentle flow undulation
                flowPhase += 0.18 * dt
                if flowPhase > 1 { flowPhase -= 1 }
                let flowMod = 0.6 + 0.4 * sinf(flowPhase * 2.0 * Float.pi)
                var s = flowLp2 * flowMod * 0.7

                // Layer 2: bright bubble texture — LP ~3 kHz, HP ~400 Hz
                bubLp += 0.35 * (noise - bubLp)
                let bHpOut = bubLp - bubHp
                bubHp += 0.055 * bHpOut

                // Periodically jitter bubble rates so pattern never repeats
                driftTimer -= dt
                if driftTimer <= 0 {
                    for j in 0..<6 {
                        bubbleRates[j] += Float.random(in: -0.5...0.5)
                        bubbleRates[j] = max(1.5, min(14.0, bubbleRates[j]))
                    }
                    driftTimer = Float.random(in: 0.8...2.5)
                }

                // Multi-rate bubble modulation (6 oscillators)
                var mod: Float = 0
                for j in 0..<6 {
                    bubblePhases[j] += bubbleRates[j] * dt
                    if bubblePhases[j] > 1 { bubblePhases[j] -= 1 }
                    mod += max(0, sinf(bubblePhases[j] * 2.0 * Float.pi))
                }
                mod = mod / 6.0 * 0.75 + 0.25
                s += bHpOut * mod * 1.2

                // Layer 3: random splash/gurgle events
                splashTimer -= dt
                if splashTimer <= 0 {
                    splashDecay = 1.0
                    splashAmp = Float.random(in: 0.15...0.5)
                    splashTimer = Float.random(in: 0.05...0.4)
                }
                if splashDecay > 0.01 {
                    s += Float.random(in: -1...1) * splashDecay * splashAmp * 0.3
                    splashDecay *= 0.997   // ~30 ms — slightly longer than fire crackles
                }

                buf[i] = tanhf(s * 2.0) * 0.5
            }
            return noErr
        }
    }
}
