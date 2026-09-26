import SwiftUI

// MARK: - Audio Settings & Sound Effect Preview Control Sheet
struct AudioSettingsView: View {
    @ObservedObject var audio = AudioManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.04, green: 0.06, blue: 0.1)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        // Title Header
                        HStack {
                            Image(systemName: "waveform.circle.fill")
                                .font(.title)
                                .foregroundStyle(.cyan)
                            Text("音效與音樂控制中心")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        .padding(.bottom, 4)

                        // Master Mute Switch
                        VStack(spacing: 12) {
                            Toggle(isOn: $audio.isMuted.animation()) {
                                HStack(spacing: 12) {
                                    Image(systemName: audio.isMuted ? "speaker.slash.fill" : "speaker.wave.3.fill")
                                        .font(.title3)
                                        .foregroundStyle(audio.isMuted ? .red : .green)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("全域靜音模式")
                                            .font(.headline.weight(.bold))
                                            .foregroundStyle(.white)
                                        Text(audio.isMuted ? "所有音樂與音效已關閉" : "音效與音樂播放中")
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.6))
                                    }
                                }
                            }
                            .tint(.cyan)
                        }
                        .padding(16)
                        .background(HUDPanel(tint: audio.isMuted ? .red : .cyan))

                        // Volume Controls
                        VStack(spacing: 18) {
                            Text("音量與背景音樂調整")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.cyan)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            // BGM Volume Slider
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Label("背景音樂音量 (BGM)", systemImage: "music.note")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Text("\(Int(audio.bgmVolume * 100))%")
                                        .font(.caption.monospacedDigit().weight(.bold))
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                        .foregroundStyle(.cyan)
                                }
                                Slider(value: $audio.bgmVolume, in: 0...1)
                                    .tint(.cyan)
                                    .disabled(audio.isMuted)
                            }

                            // SFX Volume Slider
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Label("遊戲音效音量 (SFX)", systemImage: "bolt.fill")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Text("\(Int(audio.sfxVolume * 100))%")
                                        .font(.caption.monospacedDigit().weight(.bold))
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                        .foregroundStyle(.yellow)
                                }
                                Slider(value: $audio.sfxVolume, in: 0...1)
                                    .tint(.yellow)
                                    .disabled(audio.isMuted)
                            }
                        }
                        .padding(16)
                        .background(HUDPanel(tint: .cyan))

                        // BGM Track Tester
                        VStack(spacing: 14) {
                            Text("背景音樂曲目試聽 (BGM Tracks)")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.purple)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if let track = audio.currentTrack {
                                HStack {
                                    Image(systemName: "play.circle.fill")
                                        .foregroundStyle(.purple)
                                    Text("當前播放: \(track.name)")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                    Spacer()
                                }
                                .padding(10)
                                .background(Color.purple.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
                            }

                            HStack(spacing: 10) {
                                Button("HQ 基地曲") {
                                    audio.playBGM(.hqBase)
                                }
                                .buttonStyle(AudioButtonStyle(color: .cyan))

                                Button("關卡電音") {
                                    audio.playBGM(.zone(1))
                                }
                                .buttonStyle(AudioButtonStyle(color: .mint))

                                Button("BOSS 戰曲") {
                                    audio.playBGM(.boss)
                                }
                                .buttonStyle(AudioButtonStyle(color: .purple))
                            }
                        }
                        .padding(16)
                        .background(HUDPanel(tint: .purple))

                        // SFX Test Buttons Grid
                        VStack(spacing: 14) {
                            Text("音效試聽面板 (Sound Effects Test)")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.yellow)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                SFXTestButton(title: "點擊按鈕", icon: "hand.tap.fill", color: .cyan) {
                                    audio.playSFX(.buttonClick)
                                }
                                SFXTestButton(title: "頁籤切換", icon: "square.grid.2x2.fill", color: .mint) {
                                    audio.playSFX(.tabSwitch)
                                }
                                SFXTestButton(title: "裝備升級", icon: "arrow.up.circle.fill", color: .yellow) {
                                    audio.playSFX(.upgrade)
                                }
                                SFXTestButton(title: "渦輪衝刺", icon: "bolt.fill", color: .orange) {
                                    audio.playSFX(.dash)
                                }
                                SFXTestButton(title: "黑洞漩渦", icon: "tornado", color: .purple) {
                                    audio.playSFX(.vortex)
                                }
                                SFXTestButton(title: "UV 紫外線光束", icon: "sun.max.fill", color: .red) {
                                    audio.playSFX(.uvRay)
                                }
                                SFXTestButton(title: "吸入塵怪", icon: "sparkles", color: .green) {
                                    audio.playSFX(.enemyAbsorbed)
                                }
                                SFXTestButton(title: "擊中 BOSS", icon: "hammer.fill", color: .red) {
                                    audio.playSFX(.bossHit)
                                }
                                SFXTestButton(title: "BOSS 爆裂擊殺", icon: "crown.fill", color: .purple) {
                                    audio.playSFX(.bossDefeated)
                                }
                                SFXTestButton(title: "通關勝利樂章", icon: "trophy.fill", color: .yellow) {
                                    audio.playSFX(.victory)
                                }
                                SFXTestButton(title: "關卡失敗結算", icon: "xmark.octagon.fill", color: .gray) {
                                    audio.playSFX(.defeat)
                                }
                            }
                        }
                        .padding(16)
                        .background(HUDPanel(tint: .yellow))
                    }
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") {
                        dismiss()
                    }
                    .foregroundStyle(.cyan)
                    .font(.body.weight(.bold))
                }
            }
        }
    }
}

struct AudioButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.bold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(configuration.isPressed ? color.opacity(0.4) : color.opacity(0.2), in: Capsule())
            .overlay(Capsule().stroke(color, lineWidth: 1))
            .foregroundStyle(color)
    }
}

struct SFXTestButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(color.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
