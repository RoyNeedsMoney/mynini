import Foundation
import AVFoundation
import Combine

// MARK: - Game Audio Manager (Procedural Music & SFX Engine)
@MainActor
final class AudioManager: ObservableObject {
    static let shared = AudioManager()

    // Sound Toggles & Volume Settings
    @Published var isMuted: Bool {
        didSet {
            UserDefaults.standard.set(isMuted, forKey: "audio_isMuted")
            if isMuted {
                stopBGM()
            } else {
                playCurrentBGM()
            }
        }
    }
    
    @Published var bgmVolume: Float {
        didSet {
            UserDefaults.standard.set(bgmVolume, forKey: "audio_bgmVolume")
            bgmPlayerNode.volume = isMuted ? 0 : bgmVolume
        }
    }
    
    @Published var sfxVolume: Float {
        didSet {
            UserDefaults.standard.set(sfxVolume, forKey: "audio_sfxVolume")
        }
    }

    // Audio Engine & Nodes
    private let audioEngine = AVAudioEngine()
    private let bgmPlayerNode = AVAudioPlayerNode()
    private let sfxPlayerNode = AVAudioPlayerNode()
    private let vacuumHumNode = AVAudioPlayerNode()

    // BGM State
    enum BGMTrack: Equatable {
        case hqBase
        case zone(Int)
        case boss
        
        var name: String {
            switch self {
            case .hqBase: return "指揮中心電音 (HQ Ambient)"
            case .zone(let id): return "第 \(id) 關衝刺節奏 (Zone \(id) Theme)"
            case .boss: return "塵暴魔王決戰曲 (Boss Battle Theme)"
            }
        }
    }

    @Published private(set) var currentTrack: BGMTrack?
    private var bgmTask: Task<Void, Never>?
    private var isEngineRunning = false

    // Audio Format
    private let sampleRate: Double = 44100.0
    private lazy var audioFormat: AVAudioFormat = {
        AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    }()

    private init() {
        self.isMuted = UserDefaults.standard.bool(forKey: "audio_isMuted")
        let storedBGM = UserDefaults.standard.float(forKey: "audio_bgmVolume")
        self.bgmVolume = storedBGM == 0 && !UserDefaults.standard.bool(forKey: "hasSetAudio") ? 0.7 : storedBGM
        let storedSFX = UserDefaults.standard.float(forKey: "audio_sfxVolume")
        self.sfxVolume = storedSFX == 0 && !UserDefaults.standard.bool(forKey: "hasSetAudio") ? 0.8 : storedSFX
        
        UserDefaults.standard.set(true, forKey: "hasSetAudio")
        
        setupAudioEngine()
    }

    private func setupAudioEngine() {
        activateAudioSession()

        audioEngine.attach(bgmPlayerNode)
        audioEngine.attach(sfxPlayerNode)
        audioEngine.attach(vacuumHumNode)

        let mainMixer = audioEngine.mainMixerNode
        audioEngine.connect(bgmPlayerNode, to: mainMixer, format: audioFormat)
        audioEngine.connect(sfxPlayerNode, to: mainMixer, format: audioFormat)
        audioEngine.connect(vacuumHumNode, to: mainMixer, format: audioFormat)

        bgmPlayerNode.volume = isMuted ? 0 : bgmVolume
        sfxPlayerNode.volume = sfxVolume
        vacuumHumNode.volume = 0.0

        do {
            try audioEngine.start()
            isEngineRunning = true
            bgmPlayerNode.play()
            sfxPlayerNode.play()
            vacuumHumNode.play()
            currentTrack = .hqBase
            playCurrentBGM()
        } catch {
            print("Failed to start AVAudioEngine: \(error)")
        }
    }

    func start() {
        activateAudioSession()

        if !audioEngine.isRunning {
            do {
                try audioEngine.start()
            } catch {
                print("Failed to start AVAudioEngine: \(error)")
                return
            }
        }

        if !bgmPlayerNode.isPlaying { bgmPlayerNode.play() }
        if !sfxPlayerNode.isPlaying { sfxPlayerNode.play() }
        if !vacuumHumNode.isPlaying { vacuumHumNode.play() }

        if currentTrack == nil {
            currentTrack = .hqBase
        }
        if !isMuted, bgmTask == nil {
            playCurrentBGM()
        }
    }

    private func activateAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("Failed to configure AVAudioSession: \(error)")
        }
        #endif
    }

    private func ensureEngineRunning() {
        activateAudioSession()
        start()
    }

    // MARK: - Sound Effect Types
    enum SoundEffect {
        case buttonClick
        case tabSwitch
        case upgrade
        case dash
        case vortex
        case uvRay
        case enemyAbsorbed
        case bossHit
        case bossDefeated
        case victory
        case defeat
    }

    func playSFX(_ sfx: SoundEffect) {
        guard !isMuted, sfxVolume > 0 else { return }
        ensureEngineRunning()

        let buffer: AVAudioPCMBuffer?
        switch sfx {
        case .buttonClick:
            buffer = generateToneBuffer(frequency: 1000, duration: 0.04, type: .sine, fadeOut: true)
        case .tabSwitch:
            buffer = generateTwoToneBuffer(freq1: 700, freq2: 1200, duration: 0.06)
        case .upgrade:
            buffer = generateArpeggioBuffer(notes: [523.25, 659.25, 783.99, 1046.50], noteDuration: 0.07, type: .square)
        case .dash:
            buffer = generateSweepBuffer(startFreq: 400, endFreq: 1800, duration: 0.18, type: .saw)
        case .vortex:
            buffer = generateSweepBuffer(startFreq: 800, endFreq: 120, duration: 0.45, type: .triangle)
        case .uvRay:
            buffer = generateLaserBuffer(duration: 0.3)
        case .enemyAbsorbed:
            buffer = generateTwoToneBuffer(freq1: 1200, freq2: 2400, duration: 0.08)
        case .bossHit:
            buffer = generateToneBuffer(frequency: 110, duration: 0.12, type: .square, fadeOut: true)
        case .bossDefeated:
            buffer = generateExplosionArpeggioBuffer()
        case .victory:
            buffer = generateFanfareBuffer(isVictory: true)
        case .defeat:
            buffer = generateFanfareBuffer(isVictory: false)
        }

        if let buffer = buffer {
            sfxPlayerNode.volume = sfxVolume
            sfxPlayerNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
            if !sfxPlayerNode.isPlaying {
                sfxPlayerNode.play()
            }
        }
    }

    // MARK: - Vacuum Engine Noise Control
    func setVacuumHum(active: Bool, intensity: Float = 0.5) {
        guard !isMuted, sfxVolume > 0 else {
            vacuumHumNode.volume = 0
            return
        }
        ensureEngineRunning()

        if active {
            if vacuumHumBuffer == nil {
                vacuumHumBuffer = generateNoiseBuffer(duration: 1.0, cutoff: 800.0)
            }
            if let buf = vacuumHumBuffer {
                vacuumHumNode.volume = sfxVolume * intensity * 0.35
                if !isHumming {
                    isHumming = true
                    vacuumHumNode.scheduleBuffer(buf, at: nil, options: .loops, completionHandler: nil)
                }
            }
        } else {
            isHumming = false
            vacuumHumNode.volume = 0.0
        }
    }
    private var isHumming = false
    private var vacuumHumBuffer: AVAudioPCMBuffer?

    // MARK: - BGM Control
    func playBGM(_ track: BGMTrack) {
        guard currentTrack != track else { return }
        currentTrack = track
        playCurrentBGM()
    }

    private func playCurrentBGM() {
        stopBGMTask()
        guard !isMuted, let track = currentTrack else { return }

        bgmTask = Task { [weak self] in
            guard let self = self else { return }
            while !Task.isCancelled {
                let loopBuffer: AVAudioPCMBuffer?
                switch track {
                case .hqBase:
                    loopBuffer = self.generateHQBaseBGMBuffer()
                case .zone(let id):
                    loopBuffer = self.generateZoneBGMBuffer(zoneId: id)
                case .boss:
                    loopBuffer = self.generateBossBGMBuffer()
                }

                if let buffer = loopBuffer, !Task.isCancelled {
                    let semaphore = DispatchSemaphore(value: 0)
                    await MainActor.run {
                        self.bgmPlayerNode.volume = self.isMuted ? 0 : self.bgmVolume
                        self.bgmPlayerNode.scheduleBuffer(buffer) {
                            semaphore.signal()
                        }
                    }
                    // Wait for loop buffer to complete
                    let timeout = Double(buffer.frameLength) / self.sampleRate
                    try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                } else {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
            }
        }
    }

    func stopBGM() {
        stopBGMTask()
        bgmPlayerNode.stop()
        bgmPlayerNode.play()
    }

    private func stopBGMTask() {
        bgmTask?.cancel()
        bgmTask = nil
    }

    // MARK: - Waveform & Procedural Audio Generators
    private enum WaveType {
        case sine
        case square
        case triangle
        case saw
    }

    private func generateToneBuffer(frequency: Float, duration: Double, type: WaveType, fadeOut: Bool = true) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount

        let channels = buffer.floatChannelData?[0]
        let delta = (2.0 * Float.pi * frequency) / Float(sampleRate)
        var phase: Float = 0.0

        for i in 0..<Int(frameCount) {
            var val: Float = 0.0
            switch type {
            case .sine:
                val = sin(phase)
            case .square:
                val = sin(phase) >= 0 ? 0.6 : -0.6
            case .triangle:
                val = (2.0 / Float.pi) * asin(sin(phase))
            case .saw:
                val = (2.0 * (phase / (2.0 * Float.pi) - floor(phase / (2.0 * Float.pi) + 0.5)))
            }

            if fadeOut {
                let env = 1.0 - (Float(i) / Float(frameCount))
                val *= env
            }

            channels?[i] = val * 0.5
            phase += delta
            if phase >= 2.0 * Float.pi { phase -= 2.0 * Float.pi }
        }

        return buffer
    }

    private func generateTwoToneBuffer(freq1: Float, freq2: Float, duration: Double) -> AVAudioPCMBuffer? {
        let halfFrames = Int(sampleRate * duration * 0.5)
        let totalFrames = AVAudioFrameCount(halfFrames * 2)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: totalFrames) else { return nil }
        buffer.frameLength = totalFrames

        let channels = buffer.floatChannelData?[0]
        var phase: Float = 0.0

        let delta1 = (2.0 * Float.pi * freq1) / Float(sampleRate)
        let delta2 = (2.0 * Float.pi * freq2) / Float(sampleRate)

        for i in 0..<halfFrames {
            channels?[i] = sin(phase) * 0.4
            phase += delta1
        }
        phase = 0.0
        for i in halfFrames..<Int(totalFrames) {
            let env = 1.0 - Float(i - halfFrames) / Float(halfFrames)
            channels?[i] = sin(phase) * 0.4 * env
            phase += delta2
        }

        return buffer
    }

    private func generateSweepBuffer(startFreq: Float, endFreq: Float, duration: Double, type: WaveType) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount

        let channels = buffer.floatChannelData?[0]
        var phase: Float = 0.0

        for i in 0..<Int(frameCount) {
            let progress = Float(i) / Float(frameCount)
            let currFreq = startFreq + (endFreq - startFreq) * progress
            let delta = (2.0 * Float.pi * currFreq) / Float(sampleRate)

            var val: Float = 0.0
            switch type {
            case .sine: val = sin(phase)
            case .square: val = sin(phase) >= 0 ? 0.5 : -0.5
            case .triangle: val = (2.0 / Float.pi) * asin(sin(phase))
            case .saw: val = (2.0 * (phase / (2.0 * Float.pi) - floor(phase / (2.0 * Float.pi) + 0.5)))
            }

            let env = sin(Float.pi * progress) // smooth bell envelope
            channels?[i] = val * 0.4 * env
            phase += delta
        }

        return buffer
    }

    private func generateLaserBuffer(duration: Double) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount

        let channels = buffer.floatChannelData?[0]
        var phase: Float = 0.0

        for i in 0..<Int(frameCount) {
            let progress = Float(i) / Float(frameCount)
            let currFreq = 2200.0 * exp(-3.5 * progress) // exponential drop
            let delta = (2.0 * Float.pi * Float(currFreq)) / Float(sampleRate)

            let val = (sin(phase) >= 0 ? 0.5 : -0.5) * (1.0 - progress)
            channels?[i] = val * 0.45
            phase += delta
        }

        return buffer
    }

    private func generateArpeggioBuffer(notes: [Float], noteDuration: Double, type: WaveType) -> AVAudioPCMBuffer? {
        let framesPerNote = Int(sampleRate * noteDuration)
        let totalFrames = AVAudioFrameCount(framesPerNote * notes.count)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: totalFrames) else { return nil }
        buffer.frameLength = totalFrames

        let channels = buffer.floatChannelData?[0]

        for (nIdx, noteFreq) in notes.enumerated() {
            let delta = (2.0 * Float.pi * noteFreq) / Float(sampleRate)
            var phase: Float = 0.0

            for f in 0..<framesPerNote {
                let idx = nIdx * framesPerNote + f
                let env = 1.0 - (Float(f) / Float(framesPerNote))
                var val: Float = 0.0
                switch type {
                case .sine: val = sin(phase)
                case .square: val = sin(phase) >= 0 ? 0.5 : -0.5
                case .triangle: val = (2.0 / Float.pi) * asin(sin(phase))
                case .saw: val = (2.0 * (phase / (2.0 * Float.pi) - floor(phase / (2.0 * Float.pi) + 0.5)))
                }

                channels?[idx] = val * 0.4 * env
                phase += delta
            }
        }

        return buffer
    }

    private func generateExplosionArpeggioBuffer() -> AVAudioPCMBuffer? {
        let duration = 0.8
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount

        let channels = buffer.floatChannelData?[0]
        var phase: Float = 0.0

        for i in 0..<Int(frameCount) {
            let progress = Float(i) / Float(frameCount)
            let noise = Float.random(in: -0.6...0.6)
            let lowTone = sin(phase) * 0.4
            let delta = (2.0 * Float.pi * (180.0 * (1.0 - progress))) / Float(sampleRate)
            phase += delta

            let env = 1.0 - progress
            channels?[i] = (noise * 0.6 + lowTone * 0.4) * env * 0.5
        }

        return buffer
    }

    private func generateNoiseBuffer(duration: Double, cutoff: Float) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount

        let channels = buffer.floatChannelData?[0]
        var lastVal: Float = 0.0
        let alpha: Float = 0.15 // simple lowpass filter

        for i in 0..<Int(frameCount) {
            let rawNoise = Float.random(in: -0.8...0.8)
            let filtered = lastVal + alpha * (rawNoise - lastVal)
            lastVal = filtered
            channels?[i] = filtered * 0.3
        }

        return buffer
    }

    private func generateFanfareBuffer(isVictory: Bool) -> AVAudioPCMBuffer? {
        // Chord sequence
        let notes: [Float] = isVictory ? [523.25, 659.25, 783.99, 1046.50] : [440.00, 349.23, 293.66, 220.00]
        let noteDur = isVictory ? 0.12 : 0.18
        return generateArpeggioBuffer(notes: notes, noteDuration: noteDur, type: isVictory ? .square : .saw)
    }

    // MARK: - Procedural BGM Track Generators (HQ, Level, Boss)
    private func generateHQBaseBGMBuffer() -> AVAudioPCMBuffer? {
        // Calm ambient chords: Cmaj7 (C, E, G, B) -> Am7 (A, C, E, G) -> Fmaj7 (F, A, C, E) -> G7 (G, B, D, F)
        let bpm = 90.0
        let secondsPerBar = (60.0 / bpm) * 4.0
        let totalDuration = secondsPerBar * 4.0 // 4 bars loop
        let frameCount = AVAudioFrameCount(sampleRate * totalDuration)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount
        let channels = buffer.floatChannelData?[0]

        let chords: [[Float]] = [
            [261.63, 329.63, 392.00, 493.88], // Cmaj7
            [220.00, 261.63, 329.63, 392.00], // Am7
            [174.61, 220.00, 261.63, 329.63], // Fmaj7
            [196.00, 246.94, 293.66, 349.23]  // G7
        ]

        let framesPerBar = Int(sampleRate * secondsPerBar)

        for barIdx in 0..<4 {
            let chord = chords[barIdx]
            let startFrame = barIdx * framesPerBar

            for f in 0..<framesPerBar {
                let idx = startFrame + f
                if idx >= Int(frameCount) { break }
                let progress = Float(f) / Float(framesPerBar)

                var sampleSum: Float = 0.0
                for (nIdx, freq) in chord.enumerated() {
                    let phase = Float(idx) * ((2.0 * Float.pi * freq) / Float(sampleRate))
                    let wave = sin(phase) + 0.3 * sin(phase * 2.0)
                    let subArp = sin(Float(idx) * ((2.0 * Float.pi * (freq * 2.0)) / Float(sampleRate))) * 0.15 * sin(Float(f) * 0.01)
                    sampleSum += (wave + subArp) * (nIdx == 0 ? 0.35 : 0.2)
                }

                // Smooth pad envelope per bar
                let env = sin(Float.pi * progress)
                channels?[idx] = sampleSum * env * 0.15
            }
        }

        return buffer
    }

    private func generateZoneBGMBuffer(zoneId: Int) -> AVAudioPCMBuffer? {
        // Upbeat rhythmic synthwave chiptune BGM
        let bpm = 124.0 + Double(zoneId * 3)
        let beatDuration = 60.0 / bpm
        let barDuration = beatDuration * 4.0
        let totalDuration = barDuration * 4.0 // 4 bars
        let frameCount = AVAudioFrameCount(sampleRate * totalDuration)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount
        let channels = buffer.floatChannelData?[0]

        // Bass scale per zone
        let baseFreqs: [Float] = [130.81, 146.83, 164.81, 174.61] // C, D, E, F
        let rootFreq = baseFreqs[(zoneId - 1) % baseFreqs.count]
        let melNotes: [Float] = [rootFreq, rootFreq * 1.25, rootFreq * 1.5, rootFreq * 1.875, rootFreq * 2.0]

        let totalFrames = Int(frameCount)
        let framesPerBeat = Int(sampleRate * beatDuration)

        for f in 0..<totalFrames {
            let beatIdx = f / framesPerBeat
            let beatProgress = Float(f % framesPerBeat) / Float(framesPerBeat)

            // Driving 16th note bassline
            let sub16th = (f / (framesPerBeat / 4)) % 4
            let bassFreq = (sub16th == 3) ? rootFreq * 0.75 : rootFreq * 0.5
            let bassPhase = Float(f) * ((2.0 * Float.pi * bassFreq) / Float(sampleRate))
            let bassWave = (sin(bassPhase) >= 0 ? 0.4 : -0.4) * (1.0 - beatProgress * 0.5)

            // Lead synth note selector
            let noteIdx = (beatIdx * 3 + sub16th) % melNotes.count
            let leadFreq = melNotes[noteIdx]
            let leadPhase = Float(f) * ((2.0 * Float.pi * leadFreq) / Float(sampleRate))
            let leadWave = (2.0 / Float.pi) * asin(sin(leadPhase)) * (1.0 - beatProgress)

            // Hi-hat / synth click on off-beats
            let hihat = (sub16th % 2 == 1) ? Float.random(in: -0.15...0.15) * (1.0 - beatProgress * 2.0) : 0.0

            let combined = (bassWave * 0.3 + leadWave * 0.25 + hihat * 0.1) * 0.4
            channels?[f] = combined
        }

        return buffer
    }

    private func generateBossBGMBuffer() -> AVAudioPCMBuffer? {
        // Fast, aggressive D-minor boss battle theme (bpm 148)
        let bpm = 148.0
        let beatDuration = 60.0 / bpm
        let barDuration = beatDuration * 4.0
        let totalDuration = barDuration * 4.0 // 4 bars
        let frameCount = AVAudioFrameCount(sampleRate * totalDuration)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount
        let channels = buffer.floatChannelData?[0]

        let rootFreq: Float = 146.83 // D3
        let bossScale: [Float] = [146.83, 174.61, 196.00, 220.00, 261.63, 293.66, 349.23, 392.00] // D minor pentatonic/harmonic

        let totalFrames = Int(frameCount)
        let framesPerBeat = Int(sampleRate * beatDuration)

        for f in 0..<totalFrames {
            let sub16th = (f / (framesPerBeat / 4)) % 16
            let beatProgress = Float(f % (framesPerBeat / 4)) / Float(framesPerBeat / 4)

            // Aggressive saw bass
            let bassPhase = Float(f) * ((2.0 * Float.pi * (rootFreq * 0.5)) / Float(sampleRate))
            let sawBass = (2.0 * (bassPhase / (2.0 * Float.pi) - floor(bassPhase / (2.0 * Float.pi) + 0.5))) * 0.4

            // Fast frantic arpeggio lead
            let arpNote = bossScale[sub16th % bossScale.count]
            let arpPhase = Float(f) * ((2.0 * Float.pi * arpNote) / Float(sampleRate))
            let arpWave = (sin(arpPhase) >= 0 ? 0.35 : -0.35) * (1.0 - beatProgress)

            // Heavy kick & snare noise punch
            var drum: Float = 0.0
            if sub16th % 4 == 0 {
                // Kick
                drum = sin(Float(f) * 0.08) * (1.0 - beatProgress * 3.0)
            } else if sub16th % 4 == 2 {
                // Snare
                drum = Float.random(in: -0.4...0.4) * (1.0 - beatProgress * 2.0)
            }

            let combined = (sawBass * 0.35 + arpWave * 0.3 + drum * 0.25) * 0.45
            channels?[f] = combined
        }

        return buffer
    }
}
