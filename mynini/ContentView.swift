import SwiftUI
import SceneKit
import Observation

// MARK: - Main Content View
struct ContentView: View {
    @State private var game = FactoryRPG()

    var body: some View {
        ZStack {
            Color(red: 0.025, green: 0.045, blue: 0.075)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if game.screen != .mission {
                    NavigationTabBar(screen: $game.screen)
                }

                ZStack {
                    switch game.screen {
                    case .command:
                        CommandCenterView(game: game)
                    case .armory:
                        ArmoryView(game: game)
                    case .skills:
                        SkillTreeView(game: game)
                    case .codex:
                        CodexView(game: game)
                    case .mission:
                        Mission3DView(game: game)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            AudioManager.shared.start()
        }
    }
}

// MARK: - Navigation Tab Bar
struct NavigationTabBar: View {
    @Binding var screen: FactoryRPG.Screen

    var body: some View {
        HStack(spacing: 8) {
            TabButton(title: "指揮中心", icon: "shield.fill", target: .command, current: screen) { screen = $0 }
            TabButton(title: "吸塵器工坊", icon: "wrench.and.screwdriver.fill", target: .armory, current: screen) { screen = $0 }
            TabButton(title: "核心技能", icon: "bolt.shield.fill", target: .skills, current: screen) { screen = $0 }
            TabButton(title: "塵怪圖鑑", icon: "book.closed.fill", target: .codex, current: screen) { screen = $0 }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.4))
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let target: FactoryRPG.Screen
    let current: FactoryRPG.Screen
    let action: (FactoryRPG.Screen) -> Void

    var isSelected: Bool { target == current }

    var body: some View {
        Button(action: { action(target) }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
                    .font(.caption.weight(.bold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.cyan.opacity(0.25) : Color.white.opacity(0.06), in: Capsule())
            .overlay(Capsule().stroke(isSelected ? Color.cyan : Color.clear, lineWidth: 1))
            .foregroundStyle(isSelected ? Color.cyan : Color.white.opacity(0.7))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - RPG Game Controller & State
@MainActor
@Observable
final class FactoryRPG {
    enum Screen {
        case command
        case armory
        case skills
        case codex
        case mission
    }

    private let defaults = UserDefaults.standard

    var screen: Screen = .command
    var unlockedZone: Int
    var credits: Int
    var gems: Int
    var rank: Int
    var experience: Int
    var currentZone: FactoryZone?
    var missionState: MissionState?

    // Upgrade Levels
    var motorLevel: Int
    var tankLevel: Int
    var batteryLevel: Int
    var engineSpeedLevel: Int

    // Skill Levels
    var dashLevel: Int
    var vortexLevel: Int
    var uvRayLevel: Int

    // Defeated Monster Stats for Codex
    var dustDefeated: Int
    var scrapDefeated: Int
    var oilDefeated: Int
    var bossDefeated: Int

    init() {
        credits = defaults.integer(forKey: "factoryCredits")
        gems = defaults.integer(forKey: "factoryGems")
        rank = max(defaults.integer(forKey: "factoryRank"), 1)
        experience = defaults.integer(forKey: "factoryExperience")
        unlockedZone = max(defaults.integer(forKey: "factoryUnlockedZone"), 1)

        motorLevel = max(defaults.integer(forKey: "motorLevel"), 1)
        tankLevel = max(defaults.integer(forKey: "tankLevel"), 1)
        batteryLevel = max(defaults.integer(forKey: "batteryLevel"), 1)
        engineSpeedLevel = max(defaults.integer(forKey: "engineSpeedLevel"), 1)

        dashLevel = max(defaults.integer(forKey: "dashLevel"), 1)
        vortexLevel = max(defaults.integer(forKey: "vortexLevel"), 0)
        uvRayLevel = max(defaults.integer(forKey: "uvRayLevel"), 0)

        dustDefeated = defaults.integer(forKey: "dustDefeated")
        scrapDefeated = defaults.integer(forKey: "scrapDefeated")
        oilDefeated = defaults.integer(forKey: "oilDefeated")
        bossDefeated = defaults.integer(forKey: "bossDefeated")
    }

    var experienceToNextRank: Int {
        100 + (rank - 1) * 60
    }

    var rankProgress: Double {
        min(Double(experience) / Double(experienceToNextRank), 1.0)
    }

    // Calculated Hero Stats
    var suctionPower: Float {
        Float(15 + (motorLevel - 1) * 8)
    }

    var suctionRadius: Float {
        1.8 + Float(motorLevel) * 0.25
    }

    var tankCapacity: Int {
        20 + (tankLevel - 1) * 10
    }

    var maxBattery: Float {
        100.0 + Float((batteryLevel - 1) * 25)
    }

    var speedMultiplier: Float {
        1.0 + Float(engineSpeedLevel - 1) * 0.15
    }

    func begin(_ zone: FactoryZone) {
        guard zone.id <= unlockedZone else { return }
        currentZone = zone
        missionState = nil
        screen = .mission
        AudioManager.shared.playSFX(.buttonClick)
        AudioManager.shared.playBGM(zone.isBossSector ? .boss : .zone(zone.id))
    }

    func finishMission(cleared: Bool, earnedCredits: Int, earnedGems: Int, earnedXP: Int, dustCount: Int, scrapCount: Int, oilCount: Int, bossCount: Int) {
        if cleared {
            credits += earnedCredits
            gems += earnedGems
            experience += earnedXP
            dustDefeated += dustCount
            scrapDefeated += scrapCount
            oilDefeated += oilCount
            bossDefeated += bossCount

            applyRankUps()

            if let zone = currentZone {
                unlockedZone = min(max(unlockedZone, zone.id + 1), FactoryZone.all.count)
            }
            missionState = .cleared(credits: earnedCredits, gems: earnedGems, xp: earnedXP)
        } else {
            missionState = .failed
        }
        AudioManager.shared.playSFX(cleared ? .victory : .defeat)
        save()
    }

    func leaveMission() {
        currentZone = nil
        missionState = nil
        screen = .command
        AudioManager.shared.playBGM(.hqBase)
    }

    func retryMission() {
        guard let currentZone else { return }
        begin(currentZone)
    }

    func upgradeMotor() {
        let cost = motorLevel * 50
        if credits >= cost {
            credits -= cost
            motorLevel += 1
            save()
        }
    }

    func upgradeTank() {
        let cost = tankLevel * 40
        if credits >= cost {
            credits -= cost
            tankLevel += 1
            save()
        }
    }

    func upgradeBattery() {
        let cost = batteryLevel * 45
        if credits >= cost {
            credits -= cost
            batteryLevel += 1
            save()
        }
    }

    func upgradeEngineSpeed() {
        let cost = engineSpeedLevel * 60
        if credits >= cost {
            credits -= cost
            engineSpeedLevel += 1
            save()
        }
    }

    func upgradeDash() {
        let cost = (dashLevel + 1) * 80
        if credits >= cost {
            credits -= cost
            dashLevel += 1
            save()
        }
    }

    func upgradeVortex() {
        let cost = (vortexLevel + 1) * 120
        if credits >= cost && gems >= 5 {
            credits -= cost
            gems -= 5
            vortexLevel += 1
            save()
        }
    }

    func upgradeUVRay() {
        let cost = (uvRayLevel + 1) * 150
        if credits >= cost && gems >= 10 {
            credits -= cost
            gems -= 10
            uvRayLevel += 1
            save()
        }
    }

    private func applyRankUps() {
        while experience >= experienceToNextRank {
            experience -= experienceToNextRank
            rank += 1
        }
    }

    private func save() {
        defaults.set(credits, forKey: "factoryCredits")
        defaults.set(gems, forKey: "factoryGems")
        defaults.set(rank, forKey: "factoryRank")
        defaults.set(experience, forKey: "factoryExperience")
        defaults.set(unlockedZone, forKey: "factoryUnlockedZone")

        defaults.set(motorLevel, forKey: "motorLevel")
        defaults.set(tankLevel, forKey: "tankLevel")
        defaults.set(batteryLevel, forKey: "batteryLevel")
        defaults.set(engineSpeedLevel, forKey: "engineSpeedLevel")

        defaults.set(dashLevel, forKey: "dashLevel")
        defaults.set(vortexLevel, forKey: "vortexLevel")
        defaults.set(uvRayLevel, forKey: "uvRayLevel")

        defaults.set(dustDefeated, forKey: "dustDefeated")
        defaults.set(scrapDefeated, forKey: "scrapDefeated")
        defaults.set(oilDefeated, forKey: "oilDefeated")
        defaults.set(bossDefeated, forKey: "bossDefeated")
    }
}

enum MissionState: Equatable {
    case cleared(credits: Int, gems: Int, xp: Int)
    case failed
}

// MARK: - Zone Data
struct FactoryZone: Identifiable, Equatable {
    let id: Int
    let name: String
    let subtitle: String
    let objective: String
    let icon: String
    let clearReward: Int
    let gemReward: Int
    let experienceReward: Int
    let isBossSector: Bool
    let tint: Color

    static let all: [FactoryZone] = [
        FactoryZone(id: 1, name: "客廳", subtitle: "起始清理區", objective: "消除地毯與沙發周圍的灰塵怪", icon: "sofa.fill", clearReward: 60, gemReward: 2, experienceReward: 50, isBossSector: false, tint: .cyan),
        FactoryZone(id: 2, name: "長廊", subtitle: "通道廢墟", objective: "清理走廊，回收散落的高硬度鐵屑蟲", icon: "door.left.hand.open", clearReward: 100, gemReward: 4, experienceReward: 90, isBossSector: false, tint: .mint),
        FactoryZone(id: 3, name: "倉儲區", subtitle: "原料庫房", objective: "避開毒油，清掃大量微塵與鐵屑", icon: "shippingbox.fill", clearReward: 160, gemReward: 6, experienceReward: 140, isBossSector: false, tint: .yellow),
        FactoryZone(id: 4, name: "組裝線", subtitle: "自動化車間", objective: "清除傳送帶的高密塵埃與機械遺骸", icon: "gearshape.2.fill", clearReward: 240, gemReward: 10, experienceReward: 210, isBossSector: false, tint: .orange),
        FactoryZone(id: 5, name: "中央工廠", subtitle: "塵暴魔王決戰區", objective: "擊敗「巨型塵暴魔王 BOSS」，重獲工廠淨化權！", icon: "crown.fill", clearReward: 450, gemReward: 25, experienceReward: 400, isBossSector: true, tint: .purple)
    ]
}

// MARK: - Command Center View
struct CommandCenterView: View {
    @Bindable var game: FactoryRPG
    @State private var isShowingAudioSettings = false

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                CommandHeader(game: game)

                HStack {
                    Spacer()
                    Button(action: {
                        isShowingAudioSettings = true
                        AudioManager.shared.playSFX(.buttonClick)
                    }) {
                        Label("音效控制", systemImage: "waveform.circle.fill")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.purple.opacity(0.3), in: Capsule())
                            .foregroundStyle(.purple)
                    }
                    .buttonStyle(.plain)
                }

                VacuumHeroHeroCard(game: game)
                ZoneMapView(unlockedZone: game.unlockedZone, begin: game.begin)
            }
            .padding(20)
        }
        .sheet(isPresented: $isShowingAudioSettings) {
            AudioSettingsView()
        }
    }
}

struct CommandHeader: View {
    @Bindable var game: FactoryRPG

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("NINI // 3D VACUUM RPG")
                        .font(.caption.weight(.bold))
                        .tracking(2)
                        .foregroundStyle(.cyan)
                    Text("吸塵英雄指揮中心")
                        .font(.largeTitle.weight(.black))
                        .foregroundStyle(.white)
                    Label("RANK \(game.rank) 級指揮官", systemImage: "shield.fill")
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.mint)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    Label("\(game.credits)", systemImage: "c.circle.fill")
                        .font(.headline.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(width: 96, alignment: .leading)
                        .foregroundStyle(.yellow)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.08), in: Capsule())

                    Label("\(game.gems)", systemImage: "diamond.fill")
                        .font(.headline.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(width: 96, alignment: .leading)
                        .foregroundStyle(.purple)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.08), in: Capsule())
                }
                .frame(width: 120)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("指揮官經驗值")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer()
                    Text("\(game.experience) / \(game.experienceToNextRank) XP")
                        .font(.caption.monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.cyan)
                }
                ProgressView(value: min(max(game.rankProgress, 0), 1))
                    .tint(.cyan)
            }
        }
        .padding(18)
        .background(HUDPanel(tint: .cyan))
    }
}

struct VacuumHeroHeroCard: View {
    @Bindable var game: FactoryRPG

    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(.cyan.opacity(0.18))
                    .frame(width: 110, height: 110)

                Image("vacuum cleaner")
                    .resizable()
                    .scaledToFit()
                    .padding(10)
                    .shadow(color: .cyan.opacity(0.8), radius: 15)
            }
            .frame(width: 110, height: 110)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("V-01 渦輪吸塵者")
                        .font(.title3.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.white)
                    Spacer(minLength: 8)
                    Text("LV. \(game.motorLevel)")
                        .font(.caption.weight(.black))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .layoutPriority(1)
                        .frame(minWidth: 52)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.cyan, in: Capsule())
                        .foregroundStyle(.black)
                }

                Text("配備相片主角「V-01 吸塵器」，具備強效旋風吸力與粒子消解射線。拖拽操縱桿在 3D 戰場中清掃異變塵怪與巨大 BOSS！")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))

                HStack(spacing: 12) {
                    StatBadge(label: "容量", value: "\(game.tankCapacity)", icon: "shippingbox.fill", color: .mint)
                    StatBadge(label: "電池", value: "\(Int(game.maxBattery))", icon: "battery.100.bolt", color: .green)
                }
            }
        }
        .padding(18)
        .background(HUDPanel(tint: .cyan))
    }
}

struct StatBadge: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
            Text("\(label): \(value)")
                .font(.caption2.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .layoutPriority(1)
                .frame(minWidth: 52, alignment: .trailing)
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
    }
}

struct ZoneMapView: View {
    let unlockedZone: Int
    let begin: (FactoryZone) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("3D 任務關卡地圖")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            ForEach(FactoryZone.all) { zone in
                ZoneCard(zone: zone, isUnlocked: zone.id <= unlockedZone, begin: { begin(zone) })
            }
        }
    }
}

struct ZoneCard: View {
    let zone: FactoryZone
    let isUnlocked: Bool
    let begin: () -> Void

    var body: some View {
        Button(action: begin) {
            HStack(spacing: 15) {
                Image(systemName: isUnlocked ? zone.icon : "lock.fill")
                    .font(.title2)
                    .frame(width: 52, height: 52)
                    .background(zone.tint.opacity(isUnlocked ? 0.22 : 0.08), in: RoundedRectangle(cornerRadius: 15))
                    .foregroundStyle(isUnlocked ? zone.tint : .secondary)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("SECTOR 0\(zone.id)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(zone.tint)
                        if zone.isBossSector {
                            Text("BOSS 關卡")
                                .font(.caption2.weight(.black))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.red.opacity(0.8), in: Capsule())
                                .foregroundStyle(.white)
                        }
                    }

                    Text(zone.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(isUnlocked ? zone.subtitle : "完成前一區域解鎖")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.58))
                }

                Spacer()

                if isUnlocked {
                    VStack(alignment: .trailing, spacing: 4) {
                        Label("+\(zone.clearReward)", systemImage: "c.circle.fill")
                            .font(.caption.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.yellow)
                        Label("+\(zone.gemReward)", systemImage: "diamond.fill")
                            .font(.caption.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.purple)
                    }
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(14)
            .background(HUDPanel(tint: isUnlocked ? zone.tint : .gray))
        }
        .buttonStyle(.plain)
        .disabled(!isUnlocked)
    }
}

// MARK: - Armory Shop View
struct ArmoryView: View {
    @Bindable var game: FactoryRPG

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("吸塵器升級工坊")
                    .font(.largeTitle.weight(.black))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 16) {
                    Image("vacuum cleaner")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 140, height: 140)
                        .shadow(color: .cyan.opacity(0.8), radius: 20)
                        .padding(10)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("V-01 吸塵核心")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.cyan)

                        Text("擁有幣值：\(game.credits) 晶幣")
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.yellow)

                        Text("透過戰鬥收集的晶幣強化馬達吸力、集塵容量與高能電池。")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(18)
                .background(HUDPanel(tint: .cyan))

                VStack(spacing: 14) {
                    UpgradeCard(
                        title: "吸力馬達 (Motor)",
                        level: game.motorLevel,
                        desc: "提升每秒消滅塵怪的數值與吸取範圍",
                        statText: "當前吸力: \(Int(game.suctionPower)) ATK",
                        cost: game.motorLevel * 50,
                        canAfford: game.credits >= game.motorLevel * 50,
                        action: game.upgradeMotor
                    )

                    UpgradeCard(
                        title: "擴充集塵箱 (Dust Tank)",
                        level: game.tankLevel,
                        desc: "提高每次任務集塵箱容量上限，延長戰鬥效率",
                        statText: "集塵容量: \(game.tankCapacity) 單位",
                        cost: game.tankLevel * 40,
                        canAfford: game.credits >= game.tankLevel * 40,
                        action: game.upgradeTank
                    )

                    UpgradeCard(
                        title: "高能鋰電池 (Battery)",
                        level: game.batteryLevel,
                        desc: "增加吸塵器最大電量 HP 上限",
                        statText: "電池電量: \(Int(game.maxBattery)) HP",
                        cost: game.batteryLevel * 45,
                        canAfford: game.credits >= game.batteryLevel * 45,
                        action: game.upgradeBattery
                    )

                    UpgradeCard(
                        title: "渦輪移動引擎 (Engine)",
                        level: game.engineSpeedLevel,
                        desc: "加速 3D 戰場中 V-01 的移動游移速度",
                        statText: "移動速度: \(String(format: "%.2f", game.speedMultiplier))x",
                        cost: game.engineSpeedLevel * 60,
                        canAfford: game.credits >= game.engineSpeedLevel * 60,
                        action: game.upgradeEngineSpeed
                    )
                }
            }
            .padding(20)
        }
    }
}

struct UpgradeCard: View {
    let title: String
    let level: Int
    let desc: String
    let statText: String
    let cost: Int
    let canAfford: Bool
    let action: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.headline.weight(.bold))
                    Text("LV. \(level)")
                        .font(.caption.weight(.black))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.cyan)
                }

                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))

                Text(statText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.mint)
            }

            Spacer()

            Button(action: action) {
                HStack(spacing: 4) {
                    Image(systemName: "c.circle.fill")
                    Text("\(cost)")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .font(.subheadline.weight(.bold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(canAfford ? Color.cyan : Color.gray.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(canAfford ? .black : .white.opacity(0.4))
            }
            .buttonStyle(.plain)
            .disabled(!canAfford)
        }
        .padding(16)
        .background(HUDPanel(tint: .cyan))
    }
}

// MARK: - Skill Tree View
struct SkillTreeView: View {
    @Bindable var game: FactoryRPG

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("核心黑科技技能")
                    .font(.largeTitle.weight(.black))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    Label("\(game.credits) 晶幣", systemImage: "c.circle.fill")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.yellow)
                    Spacer()
                    Label("\(game.gems) 紫寶石", systemImage: "diamond.fill")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.purple)
                }
                .font(.headline.weight(.bold))
                .padding(14)
                .background(HUDPanel(tint: .purple))

                VStack(spacing: 16) {
                    SkillCard(
                        name: "渦輪衝鋒 (Turbo Dash)",
                        icon: "bolt.fill",
                        level: game.dashLevel,
                        desc: "向移動方向快速衝刺，暫時無敵並撞碎小型塵怪",
                        costText: "\( (game.dashLevel + 1) * 80 ) 晶幣",
                        canAfford: game.credits >= (game.dashLevel + 1) * 80,
                        upgradeAction: game.upgradeDash
                    )

                    SkillCard(
                        name: "超強黑洞漩渦 (Vortex Suction)",
                        icon: "tornado",
                        level: game.vortexLevel,
                        desc: "引發強大引力場，將全戰場塵怪與寶物瞬移吸向吸塵器",
                        costText: "\( (game.vortexLevel + 1) * 120 ) 晶幣 + 5 寶石",
                        canAfford: game.credits >= (game.vortexLevel + 1) * 120 && game.gems >= 5,
                        upgradeAction: game.upgradeVortex
                    )

                    SkillCard(
                        name: "紫外線消解光束 (UV Ray Blast)",
                        icon: "sun.max.fill",
                        level: game.uvRayLevel,
                        desc: "發射高能紫外線射線，對全範圍敵方造成大量高額灼燒傷害",
                        costText: "\( (game.uvRayLevel + 1) * 150 ) 晶幣 + 10 寶石",
                        canAfford: game.credits >= (game.uvRayLevel + 1) * 150 && game.gems >= 10,
                        upgradeAction: game.upgradeUVRay
                    )
                }
            }
            .padding(20)
        }
    }
}

struct SkillCard: View {
    let name: String
    let icon: String
    let level: Int
    let desc: String
    let costText: String
    let canAfford: Bool
    let upgradeAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.purple)
                    .frame(width: 44, height: 44)
                    .background(.purple.opacity(0.2), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.headline.weight(.bold))
                    Text(level > 0 ? "技能等級 LV.\(level)" : "未解鎖")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(level > 0 ? .mint : .secondary)
                }
                Spacer()
            }

            Text(desc)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))

            HStack {
                Text("升級需求: \(costText)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Button(action: upgradeAction) {
                    Text(level == 0 ? "解鎖技能" : "升級技能")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(canAfford ? Color.purple : Color.gray.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(!canAfford)
            }
        }
        .padding(16)
        .background(HUDPanel(tint: .purple))
    }
}

// MARK: - Monster Codex View
struct CodexView: View {
    @Bindable var game: FactoryRPG

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("異變塵怪圖鑑")
                    .font(.largeTitle.weight(.black))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 14) {
                    CodexCard(
                        name: "微塵小妖 (Dust Bunny)",
                        icon: "circle.fill",
                        color: .brown,
                        desc: "隨處可見的微型灰塵堆，移動迅速但耐久極低。",
                        defeatCount: game.dustDefeated
                    )

                    CodexCard(
                        name: "高硬鐵屑蟲 (Scrap Beetle)",
                        icon: "bolt.fill",
                        color: .gray,
                        desc: "散落工廠的金屬零件，具有高硬度外殼，消滅後提供額外晶幣。",
                        defeatCount: game.scrapDefeated
                    )

                    CodexCard(
                        name: "毒廢油史萊姆 (Toxic Oil)",
                        icon: "drop.fill",
                        color: .green,
                        desc: "來自機油外洩的液態污染物，會向周圍噴射污漬攻擊。",
                        defeatCount: game.oilDefeated
                    )

                    CodexCard(
                        name: "塵暴魔王 (Master Dust Lord)",
                        icon: "crown.fill",
                        color: .purple,
                        desc: "占領中央工廠核心的終極 BOSS，召喚塵暴旋風並擁有巨大血量！",
                        defeatCount: game.bossDefeated
                    )
                }
            }
            .padding(20)
        }
    }
}

struct CodexCard: View {
    let name: String
    let icon: String
    let color: Color
    let desc: String
    let defeatCount: Int

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(color)
                .frame(width: 56, height: 56)
                .background(color.opacity(0.2), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.headline.weight(.bold))
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                Text("累計討伐消滅: \(defeatCount) 隻")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.yellow)
            }
            Spacer()
        }
        .padding(16)
        .background(HUDPanel(tint: color))
    }
}

// MARK: - 3D SceneKit Battle View
struct Mission3DView: View {
    @Bindable var game: FactoryRPG

    @State private var batteryHP: Float = 100.0
    @State private var tankFilled: Int = 0
    @State private var earnedCredits: Int = 0
    @State private var earnedGems: Int = 0
    @State private var earnedXP: Int = 0

    @State private var dustKilled: Int = 0
    @State private var scrapKilled: Int = 0
    @State private var oilKilled: Int = 0
    @State private var bossKilled: Int = 0

    @State private var bossHP: Float = 500.0
    @State private var maxBossHP: Float = 500.0

    @State private var joystickOffset: CGSize = .zero

    @State private var battleScene: Vacuum3DBattleScene?
    @State private var mapSnapshot = MissionMapSnapshot()

    var body: some View {
        if let zone = game.currentZone {
            ZStack {
                // SceneKit 3D Render Canvas
                if let battleScene = battleScene {
                    SceneKitViewBridge(scene: battleScene.scene)
                        .ignoresSafeArea()
                }

                // Mini-map: the camera can follow the player while this keeps the
                // complete mission layout and stationary monster positions visible.
                VStack {
                    HStack {
                        Spacer()
                        MissionMiniMap(snapshot: mapSnapshot)
                            .frame(width: 148, height: 148)
                            .padding(.trailing, 18)
                            .padding(.top, 10)
                    }
                    Spacer()
                }

                // 3D Battle Overlay HUD
                VStack {
                    // Top Bar HUD
                    HStack {
                        Button(action: {
                            battleScene?.stopLoop()
                            game.leaveMission()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.headline)
                                .padding(12)
                                .background(.black.opacity(0.6), in: Circle())
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(zone.name)
                                .font(.headline.weight(.bold))
                            Text(zone.subtitle)
                                .font(.caption)
                                .foregroundStyle(zone.tint)
                        }

                        Spacer()

                        HStack(spacing: 12) {
                            Label("\(earnedCredits)", systemImage: "c.circle.fill")
                                .foregroundStyle(.yellow)
                            Label("\(earnedGems)", systemImage: "diamond.fill")
                                .foregroundStyle(.purple)
                        }
                        .font(.subheadline.weight(.bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.6), in: Capsule())
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                    // Boss Health Bar (if Sector 5)
                    if zone.isBossSector && bossHP > 0 {
                        VStack(spacing: 4) {
                            HStack {
                                Text("塵暴魔王 (Master Dust Lord)")
                                    .font(.caption.weight(.black))
                                    .foregroundStyle(.red)
                                Spacer()
                                Text("\(Int(bossHP)) / \(Int(maxBossHP)) HP")
                                    .font(.caption.monospacedDigit())
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .foregroundStyle(.white)
                            }
                            ProgressView(value: min(max(Double(bossHP), 0), Double(maxBossHP)), total: Double(maxBossHP))
                                .tint(.red)
                        }
                        .padding(10)
                        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, 40)
                    }

                    // Battery & Capacity Gauges
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("吸塵器電量 HP")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.green)
                            ProgressView(value: min(max(Double(batteryHP), 0), Double(game.maxBattery)), total: Double(game.maxBattery))
                                .tint(.green)
                                .frame(width: 140)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("集塵箱 (\(tankFilled)/\(game.tankCapacity))")
                                .font(.caption2.weight(.bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.mint)
                            ProgressView(value: min(max(Double(tankFilled), 0), Double(game.tankCapacity)), total: Double(game.tankCapacity))
                                .tint(.mint)
                                .frame(width: 140)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)

                    Spacer()

                    // Bottom Battle Controls (Joystick & Skill Buttons)
                    HStack(alignment: .bottom) {
                        // Touch Virtual Joystick
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.15))
                                .frame(width: 120, height: 120)

                            Circle()
                                .fill(.cyan)
                                .frame(width: 48, height: 48)
                                .offset(joystickOffset)
                                .shadow(color: .cyan, radius: 8)
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let limit: CGFloat = 45
                                    let dist = hypot(value.translation.width, value.translation.height)
                                    if dist > limit {
                                        let angle = atan2(value.translation.height, value.translation.width)
                                        joystickOffset = CGSize(width: cos(angle) * limit, height: sin(angle) * limit)
                                    } else {
                                        joystickOffset = value.translation
                                    }
                                    let dx = Float(joystickOffset.width / limit)
                                    let dz = Float(joystickOffset.height / limit)
                                    battleScene?.updateMoveVector(dx: dx, dz: dz)
                                    let intensity = min(1.0, hypot(dx, dz))
                                    AudioManager.shared.setVacuumHum(active: intensity > 0.05, intensity: intensity)
                                }
                                .onEnded { _ in
                                    joystickOffset = .zero
                                    battleScene?.updateMoveVector(dx: 0, dz: 0)
                                    AudioManager.shared.setVacuumHum(active: false)
                                }
                        )
                        .padding(.leading, 20)
                        .padding(.bottom, 20)

                        Spacer()

                        // RPG Active Skill Buttons
                        HStack(spacing: 16) {
                            // Turbo Dash
                            Button(action: triggerDash) {
                                VStack(spacing: 2) {
                                    Image(systemName: "bolt.fill")
                                        .font(.title3)
                                    Text("衝鋒")
                                        .font(.caption2.weight(.bold))
                                }
                                .frame(width: 60, height: 60)
                                .background(Color.yellow.opacity(0.8), in: Circle())
                                .foregroundStyle(.black)
                            }

                            // Vortex Black Hole
                            if game.vortexLevel > 0 {
                                Button(action: triggerVortex) {
                                    VStack(spacing: 2) {
                                        Image(systemName: "tornado")
                                            .font(.title3)
                                        Text("黑洞")
                                            .font(.caption2.weight(.bold))
                                    }
                                    .frame(width: 60, height: 60)
                                    .background(Color.purple.opacity(0.8), in: Circle())
                                    .foregroundStyle(.white)
                                }
                            }

                            // UV Ray
                            if game.uvRayLevel > 0 {
                                Button(action: triggerUVRay) {
                                    VStack(spacing: 2) {
                                        Image(systemName: "sun.max.fill")
                                            .font(.title3)
                                        Text("UV射線")
                                            .font(.caption2.weight(.bold))
                                    }
                                    .frame(width: 60, height: 60)
                                    .background(Color.red.opacity(0.8), in: Circle())
                                    .foregroundStyle(.white)
                                }
                            }
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }

                // Mission Result Overlay
                if let state = game.missionState {
                    switch state {
                    case .cleared(let c, let g, let xp):
                        MissionClearedOverlay(
                            zone: zone,
                            credits: c,
                            gems: g,
                            xp: xp,
                            retry: {
                                battleScene?.stopLoop()
                                game.retryMission()
                            },
                            leave: {
                                battleScene?.stopLoop()
                                game.leaveMission()
                            }
                        )
                    case .failed:
                        MissionFailedOverlay(
                            zone: zone,
                            retry: {
                                battleScene?.stopLoop()
                                game.retryMission()
                            },
                            leave: {
                                battleScene?.stopLoop()
                                game.leaveMission()
                            }
                        )
                    }
                }
            }
            .onAppear {
                batteryHP = game.maxBattery
                let scene = Vacuum3DBattleScene(zone: zone, playerStats: game)
                self.battleScene = scene
                scene.onUpdate = { hp, tank, c, g, xp, bHP, dCount, sCount, oCount, bCount, snapshot, isFinished, isWon in
                    Task { @MainActor in
                        self.batteryHP = hp
                        self.tankFilled = tank
                        self.earnedCredits = c
                        self.earnedGems = g
                        self.earnedXP = xp
                        self.bossHP = bHP
                        self.dustKilled = dCount
                        self.scrapKilled = sCount
                        self.oilKilled = oCount
                        self.bossKilled = bCount
                        self.mapSnapshot = snapshot

                        if isFinished {
                            scene.stopLoop()
                            game.finishMission(
                                cleared: isWon,
                                earnedCredits: c + (isWon ? zone.clearReward : 0),
                                earnedGems: g + (isWon ? zone.gemReward : 0),
                                earnedXP: xp + (isWon ? zone.experienceReward : 0),
                                dustCount: dCount,
                                scrapCount: sCount,
                                oilCount: oCount,
                                bossCount: bCount
                            )
                        }
                    }
                }
            }
            .onDisappear {
                battleScene?.stopLoop()
                AudioManager.shared.setVacuumHum(active: false)
                battleScene = nil
            }
        }
    }

    private func triggerDash() {
        AudioManager.shared.playSFX(.dash)
        battleScene?.performDash()
    }

    private func triggerVortex() {
        AudioManager.shared.playSFX(.vortex)
        battleScene?.performVortex()
    }

    private func triggerUVRay() {
        AudioManager.shared.playSFX(.uvRay)
        battleScene?.performUVRay()
    }
}

// MARK: - SceneKit View Bridge (Cross Platform)
#if os(iOS)
struct SceneKitViewBridge: UIViewRepresentable {
    let scene: SCNScene

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = scene
        scnView.allowsCameraControl = false
        scnView.autoenablesDefaultLighting = true
        scnView.antialiasingMode = .multisampling4X
        scnView.isPlaying = true
        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        if uiView.scene !== scene {
            uiView.scene = scene
        }
    }
}
#else
struct SceneKitViewBridge: NSViewRepresentable {
    let scene: SCNScene

    func makeNSView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = scene
        scnView.allowsCameraControl = false
        scnView.autoenablesDefaultLighting = true
        scnView.antialiasingMode = .multisampling4X
        scnView.isPlaying = true
        return scnView
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        if nsView.scene !== scene {
            nsView.scene = scene
        }
    }
}
#endif

struct MissionMapSnapshot {
    var playerPosition: CGPoint = .zero
    var enemyPositions: [CGPoint] = []
    var bossPosition: CGPoint?
}

struct MissionMiniMap: View {
    let snapshot: MissionMapSnapshot

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.black.opacity(0.78))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(.cyan.opacity(0.7), lineWidth: 1))

                Canvas { context, size in
                    let mapRect = CGRect(x: 12, y: 28, width: size.width - 24, height: size.height - 40)
                    context.stroke(Path(roundedRect: mapRect, cornerRadius: 5), with: .color(.white.opacity(0.22)), lineWidth: 1)

                    for position in snapshot.enemyPositions {
                        let point = mapPoint(position, in: mapRect)
                        context.fill(Path(ellipseIn: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)), with: .color(.red))
                    }

                    if let bossPosition = snapshot.bossPosition {
                        let point = mapPoint(bossPosition, in: mapRect)
                        context.fill(Path(ellipseIn: CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)), with: .color(.purple))
                    }

                    let playerPoint = mapPoint(snapshot.playerPosition, in: mapRect)
                    context.fill(Path(ellipseIn: CGRect(x: playerPoint.x - 4, y: playerPoint.y - 4, width: 8, height: 8)), with: .color(.cyan))
                }

                Text("小地圖")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 12)
                    .padding(.top, 7)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("小地圖，青色是玩家，紅色是怪物，紫色是 BOSS")
    }

    private func mapPoint(_ position: CGPoint, in rect: CGRect) -> CGPoint {
        let normalizedX = (position.x + 14) / 28
        let normalizedZ = (position.y + 16) / 24
        return CGPoint(
            x: rect.minX + normalizedX * rect.width,
            y: rect.minY + normalizedZ * rect.height
        )
    }
}

// MARK: - 3D Battle Engine Class (SceneKit implementation)
@MainActor
final class Vacuum3DBattleScene: NSObject, SCNSceneRendererDelegate {
    let scene = SCNScene()
    let zone: FactoryZone

    private var playerNode = SCNNode()
    private var cameraNode = SCNNode()
    private var enemies: [SCNNode] = []

    private var moveDx: Float = 0
    private var moveDz: Float = 0

    private var playerHP: Float
    private var playerMaxHP: Float
    private var tankCount: Int = 0
    private var tankCapacity: Int

    private var creditsEarned: Int = 0
    private var gemsEarned: Int = 0
    private var xpEarned: Int = 0

    private var dustKilled: Int = 0
    private var scrapKilled: Int = 0
    private var oilKilled: Int = 0
    private var bossKilled: Int = 0

    private var bossNode: SCNNode?
    private var bossHP: Float = 500.0
    private var maxBossHP: Float = 500.0

    private var timer: Timer?
    private var isCompleted: Bool = false
    private var missionElapsed: TimeInterval = 0
    private var additionalWavesSpawned: Int = 0
    private var nextWaveAt: TimeInterval?
    private var pendingEnemySpawns: Int = 0
    private var enemySpawnAccumulator: TimeInterval = 0

    var onUpdate: ((Float, Int, Int, Int, Int, Float, Int, Int, Int, Int, MissionMapSnapshot, Bool, Bool) -> Void)?

    private var currentMapSnapshot: MissionMapSnapshot {
        MissionMapSnapshot(
            playerPosition: CGPoint(x: CGFloat(playerNode.position.x), y: CGFloat(playerNode.position.z)),
            enemyPositions: enemies.map { CGPoint(x: CGFloat($0.position.x), y: CGFloat($0.position.z)) },
            bossPosition: bossNode.flatMap { bossHP > 0 ? CGPoint(x: CGFloat($0.position.x), y: CGFloat($0.position.z)) : nil }
        )
    }

    init(zone: FactoryZone, playerStats: FactoryRPG) {
        self.zone = zone
        self.playerHP = playerStats.maxBattery
        self.playerMaxHP = playerStats.maxBattery
        self.tankCapacity = playerStats.tankCapacity
        super.init()

        setup3DWorld()
        setupPlayer()
        spawnEnemies()
        scheduleNextWave()
        startLoop()
    }

    func stopLoop() {
        isCompleted = true
        timer?.invalidate()
        timer = nil
    }

    private func setup3DWorld() {
        // Dark factory atmosphere with a restrained tint for each mission.
        scene.background.contents = platformColor(for: Color(red: 0.012, green: 0.018, blue: 0.032))

        let floorGeometry = SCNFloor()
        floorGeometry.reflectivity = 0.05
        let floorMaterial = SCNMaterial()
        floorMaterial.diffuse.contents = platformColor(for: Color(red: 0.035, green: 0.05, blue: 0.07))
        floorGeometry.materials = [floorMaterial]
        scene.rootNode.addChildNode(SCNNode(geometry: floorGeometry))

        addFactoryGrid()
        addZoneGeometry()

        // Lighting
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.color = platformColor(for: Color(red: 0.2, green: 0.25, blue: 0.35))
        ambientLight.light?.intensity = 300
        scene.rootNode.addChildNode(ambientLight)

        let dirLight = SCNNode()
        dirLight.light = SCNLight()
        dirLight.light?.type = .directional
        dirLight.light?.intensity = 850
        dirLight.position = SCNVector3(x: 10, y: 20, z: 10)
        dirLight.eulerAngles = SCNVector3(x: -.pi / 4, y: .pi / 4, z: 0)
        scene.rootNode.addChildNode(dirLight)

        // Camera Node
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 14, z: 12)
        cameraNode.eulerAngles = SCNVector3(x: -1.0, y: 0, z: 0)
        scene.rootNode.addChildNode(cameraNode)
    }

    private func addFactoryGrid() {
        let gridColor = zone.tint.opacity(0.22)

        for x in stride(from: -14.0, through: 14.0, by: 2.0) {
            addBox(
                width: 0.025,
                height: 0.015,
                length: 24,
                position: SCNVector3(x: Float(x), y: 0.015, z: -4),
                color: gridColor
            )
        }

        for z in stride(from: -16.0, through: 8.0, by: 2.0) {
            addBox(
                width: 28,
                height: 0.015,
                length: 0.025,
                position: SCNVector3(x: 0, y: 0.016, z: Float(z)),
                color: gridColor
            )
        }

        addBox(
            width: 30,
            height: 4,
            length: 0.25,
            position: SCNVector3(x: 0, y: 2, z: -18),
            color: Color(red: 0.025, green: 0.035, blue: 0.055)
        )
    }

    private func addZoneGeometry() {
        let accent = zone.tint.opacity(0.55)
        let metal = Color(red: 0.16, green: 0.19, blue: 0.23)

        switch zone.id {
        case 1:
            // Living room: a rug and a simple sofa silhouette.
            addBox(width: 8, height: 0.08, length: 4, position: SCNVector3(x: 0, y: 0.05, z: -8), color: accent)
            addBox(width: 7, height: 1.0, length: 1.0, position: SCNVector3(x: 0, y: 0.5, z: -13), color: metal)
            addBox(width: 7, height: 2.0, length: 0.35, position: SCNVector3(x: 0, y: 1.5, z: -13.35), color: accent)
        case 2:
            // Corridor: repeating pillars and a lit doorway.
            for x in stride(from: -10.0, through: 10.0, by: 5.0) {
                addBox(width: 0.7, height: 3.5, length: 0.7, position: SCNVector3(x: Float(x), y: 1.75, z: -12), color: metal)
            }
            addBox(width: 10, height: 0.18, length: 0.3, position: SCNVector3(x: 0, y: 3.3, z: -12), color: accent)
        case 3:
            // Storage: stacked crates for the raw-material warehouse.
            for x in [-9.0, -6.5, 6.5, 9.0] {
                addBox(width: 1.8, height: 1.8, length: 1.8, position: SCNVector3(x: Float(x), y: 0.9, z: -11), color: metal)
                addBox(width: 1.1, height: 1.1, length: 0.12, position: SCNVector3(x: Float(x), y: 0.9, z: -10.05), color: accent)
            }
        case 4:
            // Assembly line: conveyor, rollers, and warning lights.
            addBox(width: 20, height: 0.35, length: 3.0, position: SCNVector3(x: 0, y: 0.25, z: -12), color: metal)
            for x in stride(from: -8.0, through: 8.0, by: 4.0) {
                let roller = SCNCylinder(radius: 0.45, height: 3.2)
                roller.materials = [material(for: accent)]
                let node = SCNNode(geometry: roller)
                node.position = SCNVector3(x: Float(x), y: 0.7, z: -12)
                node.eulerAngles.z = .pi / 2
                scene.rootNode.addChildNode(node)
            }
        default:
            // Central factory: reactor core and four warning pylons.
            let reactor = SCNCylinder(radius: 2.8, height: 0.35)
            reactor.materials = [material(for: accent)]
            let reactorNode = SCNNode(geometry: reactor)
            reactorNode.position = SCNVector3(x: 0, y: 0.2, z: -11)
            scene.rootNode.addChildNode(reactorNode)

            for x in [-7.0, 7.0] {
                addBox(width: 0.8, height: 3.5, length: 0.8, position: SCNVector3(x: Float(x), y: 1.75, z: -13), color: .red)
            }
        }
    }

    private func addBox(width: CGFloat, height: CGFloat, length: CGFloat, position: SCNVector3, color: Color) {
        let geometry = SCNBox(width: width, height: height, length: length, chamferRadius: 0.05)
        geometry.materials = [material(for: color)]
        let node = SCNNode(geometry: geometry)
        node.position = position
        scene.rootNode.addChildNode(node)
    }

    private func material(for color: Color) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = platformColor(for: color)
        material.emission.contents = platformColor(for: color.opacity(0.12))
        return material
    }

    private func setupPlayer() {
        let box = SCNBox(width: 1.6, height: 0.8, length: 1.6, chamferRadius: 0.2)

        let mat = SCNMaterial()
        if let safeCGImage = createSafePowerOfTwoCGImage(named: "vacuum cleaner", targetSize: CGSize(width: 512, height: 512)) {
            mat.diffuse.contents = safeCGImage
        } else {
            mat.diffuse.contents = platformColor(for: zone.tint)
        }
        box.materials = [mat]

        playerNode = SCNNode(geometry: box)
        playerNode.position = SCNVector3(x: 0, y: 0.4, z: 0)

        // Suction Spotlight
        let spot = SCNNode()
        spot.light = SCNLight()
        spot.light?.type = .spot
        spot.light?.color = platformColor(for: zone.tint)
        spot.light?.spotOuterAngle = 60
        spot.position = SCNVector3(0, 0.5, -0.5)
        playerNode.addChildNode(spot)

        scene.rootNode.addChildNode(playerNode)
    }

    private func createSafePowerOfTwoCGImage(named name: String, targetSize: CGSize) -> CGImage? {
        #if os(iOS)
        guard let uiImage = UIImage(named: name) else { return nil }
        let cgImage = uiImage.cgImage
        #else
        guard let nsImage = NSImage(named: name) else { return nil }
        var rect = CGRect(origin: .zero, size: nsImage.size)
        let cgImage = nsImage.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        #endif

        guard let sourceImage = cgImage else { return nil }

        let width = Int(targetSize.width)
        let height = Int(targetSize.height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }

        context.draw(sourceImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    private func platformColor(for color: Color) -> Any {
        #if os(iOS)
        return UIColor(color)
        #else
        return NSColor(color)
        #endif
    }

    private func spawnEnemies() {
        spawnEnemyWave(count: zone.id * 5 + 6)

        // Spawn Boss if Boss Sector
        if zone.isBossSector {
            let bNode = createBossNode()
            bNode.position = SCNVector3(0, 1.5, -15)
            bossNode = bNode
            scene.rootNode.addChildNode(bNode)
        }
    }

    private func spawnEnemyWave(count: Int) {
        pendingEnemySpawns += count
    }

    private func spawnQueuedEnemyIfNeeded() {
        guard pendingEnemySpawns > 0 else {
            enemySpawnAccumulator = 0
            return
        }

        enemySpawnAccumulator += 0.033
        guard enemySpawnAccumulator >= 0.5 else { return }

        enemySpawnAccumulator -= 0.5
        pendingEnemySpawns -= 1

        let enemy = createEnemyNode(kind: Int.random(in: 0...2))
        let randomX = Float.random(in: -12...12)
        let randomZ = Float.random(in: -14...(-3))
        enemy.position = SCNVector3(randomX, 0.5, randomZ)
        enemies.append(enemy)
        scene.rootNode.addChildNode(enemy)
        playEnemySpawnEffect(for: enemy)
    }

    private func playEnemySpawnEffect(for enemy: SCNNode) {
        enemy.scale = SCNVector3(0.15, 0.15, 0.15)
        enemy.opacity = 0

        let appear = SCNAction.group([
            SCNAction.scale(to: 1.0, duration: 0.2),
            SCNAction.fadeIn(duration: 0.2)
        ])
        enemy.runAction(appear)

        let ringGeometry = SCNTorus(ringRadius: 0.55, pipeRadius: 0.025)
        ringGeometry.materials = [material(for: zone.tint)]
        let ring = SCNNode(geometry: ringGeometry)
        ring.position = SCNVector3(0, -0.42, 0)
        ring.eulerAngles.x = .pi / 2
        ring.opacity = 0.8
        enemy.addChildNode(ring)

        let ringEffect = SCNAction.sequence([
            SCNAction.group([
                SCNAction.scale(to: 1.5, duration: 0.35),
                SCNAction.fadeOut(duration: 0.35)
            ]),
            SCNAction.removeFromParentNode()
        ])
        ring.runAction(ringEffect)
    }

    private func scheduleNextWave() {
        guard zone.id >= 3 else { return }
        nextWaveAt = missionElapsed + TimeInterval.random(in: 0...20)
    }

    private func updateWaves() {
        if zone.id == 5 && dustKilled + scrapKilled + oilKilled >= 100 {
            nextWaveAt = nil
            return
        }

        guard let nextWaveAt, missionElapsed >= nextWaveAt else { return }

        let maximumAdditionalWaves: Int? = zone.id == 3 ? 1 : zone.id == 4 ? 2 : nil
        if let maximumAdditionalWaves, additionalWavesSpawned >= maximumAdditionalWaves {
            self.nextWaveAt = nil
            return
        }

        additionalWavesSpawned += 1
        spawnEnemyWave(count: zone.id * 5 + 6)

        if zone.id == 5 {
            scheduleNextWave()
        } else if additionalWavesSpawned < (maximumAdditionalWaves ?? 0) {
            scheduleNextWave()
        } else {
            self.nextWaveAt = nil
        }
    }

    private var canFinishMission: Bool {
        switch zone.id {
        case 3:
            return additionalWavesSpawned >= 1
        case 4:
            return additionalWavesSpawned >= 2
        case 5:
            return dustKilled + scrapKilled + oilKilled >= 100
        default:
            return true
        }
    }

    private func createEnemyNode(kind: Int) -> SCNNode {
        let node = SCNNode()
        node.name = "\(kind)"

        switch kind {
        case 0:
            // Dust Bunny: a soft-looking creature with ears, eyes and a glowing dust core.
            addPart(to: node, geometry: SCNSphere(radius: 0.48), color: Color(red: 0.38, green: 0.24, blue: 0.16), position: SCNVector3(0, 0.48, 0))
            addPart(to: node, geometry: SCNSphere(radius: 0.14), color: .brown, position: SCNVector3(-0.28, 0.8, 0))
            addPart(to: node, geometry: SCNSphere(radius: 0.14), color: .brown, position: SCNVector3(0.28, 0.8, 0))
            addPart(to: node, geometry: SCNSphere(radius: 0.055), color: .white, position: SCNVector3(-0.16, 0.58, -0.39))
            addPart(to: node, geometry: SCNSphere(radius: 0.055), color: .white, position: SCNVector3(0.16, 0.58, -0.39))
            addPart(to: node, geometry: SCNSphere(radius: 0.025), color: .cyan, position: SCNVector3(-0.16, 0.58, -0.44))
            addPart(to: node, geometry: SCNSphere(radius: 0.025), color: .cyan, position: SCNVector3(0.16, 0.58, -0.44))
            addPart(to: node, geometry: SCNTorus(ringRadius: 0.25, pipeRadius: 0.025), color: .orange, position: SCNVector3(0, 0.47, -0.43))

        case 1:
            // Scrap Beetle: layered armor, antennae and six small legs.
            addPart(to: node, geometry: SCNBox(width: 0.95, height: 0.5, length: 0.72, chamferRadius: 0.16), color: Color(white: 0.32), position: SCNVector3(0, 0.48, 0))
            addPart(to: node, geometry: SCNSphere(radius: 0.42), color: Color(white: 0.52), position: SCNVector3(0, 0.62, 0.04), scale: SCNVector3(1.0, 0.55, 0.82))
            addPart(to: node, geometry: SCNSphere(radius: 0.16), color: .yellow, position: SCNVector3(0, 0.62, -0.39), scale: SCNVector3(1.0, 0.5, 0.7))
            for x in [-0.45, 0.45] {
                for z in [-0.22, 0.0, 0.22] {
                    addPart(to: node, geometry: SCNCylinder(radius: 0.035, height: 0.38), color: .gray, position: SCNVector3(Float(x), 0.3, Float(z)))
                }
            }
            addPart(to: node, geometry: SCNSphere(radius: 0.045), color: .red, position: SCNVector3(-0.13, 0.69, -0.53))
            addPart(to: node, geometry: SCNSphere(radius: 0.045), color: .red, position: SCNVector3(0.13, 0.69, -0.53))

        default:
            // Toxic Oil Slime: translucent body, bright core and warning bubbles.
            let slime = SCNSphere(radius: 0.55)
            slime.firstMaterial?.transparency = 0.88
            addPart(to: node, geometry: slime, color: Color(red: 0.12, green: 0.58, blue: 0.22), position: SCNVector3(0, 0.52, 0), scale: SCNVector3(1.0, 0.72, 0.9))
            node.childNodes.last?.geometry?.firstMaterial?.transparency = 0.88
            node.childNodes.last?.geometry?.firstMaterial?.emission.contents = platformColor(for: Color(red: 0.04, green: 0.2, blue: 0.06))
            addPart(to: node, geometry: SCNSphere(radius: 0.2), color: .yellow, position: SCNVector3(0, 0.55, -0.42))
            addPart(to: node, geometry: SCNSphere(radius: 0.07), color: .green, position: SCNVector3(-0.42, 0.9, 0))
            addPart(to: node, geometry: SCNSphere(radius: 0.055), color: .green, position: SCNVector3(0.37, 0.98, 0.04))
            addPart(to: node, geometry: SCNSphere(radius: 0.045), color: .white, position: SCNVector3(-0.15, 0.7, -0.48))
            addPart(to: node, geometry: SCNSphere(radius: 0.045), color: .white, position: SCNVector3(0.15, 0.7, -0.48))
            addPart(to: node, geometry: SCNSphere(radius: 0.02), color: .black, position: SCNVector3(-0.15, 0.7, -0.52))
            addPart(to: node, geometry: SCNSphere(radius: 0.02), color: .black, position: SCNVector3(0.15, 0.7, -0.52))
        }

        return node
    }

    private func createBossNode() -> SCNNode {
        let node = SCNNode()
        let body = SCNCylinder(radius: 2.05, height: 2.8)
        addPart(to: node, geometry: body, color: .purple, position: SCNVector3(0, 0, 0))
        addPart(to: node, geometry: SCNTorus(ringRadius: 2.08, pipeRadius: 0.12), color: .orange, position: SCNVector3(0, 1.0, 0))
        addPart(to: node, geometry: SCNSphere(radius: 0.62), color: .red, position: SCNVector3(0, 0.25, -1.88))
        addPart(to: node, geometry: SCNSphere(radius: 0.18), color: .white, position: SCNVector3(-0.38, 0.65, -1.88))
        addPart(to: node, geometry: SCNSphere(radius: 0.18), color: .white, position: SCNVector3(0.38, 0.65, -1.88))
        addPart(to: node, geometry: SCNSphere(radius: 0.08), color: .yellow, position: SCNVector3(-0.38, 0.65, -2.02))
        addPart(to: node, geometry: SCNSphere(radius: 0.08), color: .yellow, position: SCNVector3(0.38, 0.65, -2.02))
        for x in [-0.9, 0.0, 0.9] {
            addPart(to: node, geometry: SCNCone(topRadius: 0.0, bottomRadius: 0.28, height: 0.85), color: .yellow, position: SCNVector3(Float(x), 1.85, 0))
        }
        return node
    }

    private func addPart(to parent: SCNNode, geometry: SCNGeometry, color: Color, position: SCNVector3, scale: SCNVector3 = SCNVector3(1, 1, 1)) {
        geometry.materials = [material(for: color)]
        let part = SCNNode(geometry: geometry)
        part.position = position
        part.scale = scale
        parent.addChildNode(part)
    }

    func updateMoveVector(dx: Float, dz: Float) {
        self.moveDx = dx
        self.moveDz = dz
    }

    func performDash() {
        let dashDist: Float = 1.0
        playerNode.position.x += moveDx * dashDist
        playerNode.position.z += moveDz * dashDist
    }

    func performVortex() {
        let affectedCount = max(1, enemies.count / 4)
        for enemy in enemies.prefix(affectedCount) {
            let action = SCNAction.move(to: playerNode.position, duration: 0.4)
            enemy.runAction(action)
        }
    }

    func performUVRay() {
        let affectedCount = max(1, enemies.count / 4)
        let affectedEnemies = Array(enemies.prefix(affectedCount))
        for enemy in affectedEnemies {
            let fadeOut = SCNAction.sequence([
                SCNAction.fadeOpacity(to: 0.2, duration: 0.2),
                SCNAction.removeFromParentNode()
            ])
            enemy.runAction(fadeOut)
            creditsEarned += 10
            xpEarned += 12
        }
        enemies.removeFirst(min(affectedCount, enemies.count))
    }

    private func startLoop() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    private func tick() {
        guard !isCompleted else { return }

        missionElapsed += 0.033
        updateWaves()
        spawnQueuedEnemyIfNeeded()

        // Move Player
        let speed: Float = 0.35
        playerNode.position.x += moveDx * speed
        playerNode.position.z += moveDz * speed

        // Keep player in boundary
        playerNode.position.x = min(max(playerNode.position.x, -14), 14)
        playerNode.position.z = min(max(playerNode.position.z, -16), 8)

        // Smooth camera follow
        cameraNode.position.x = playerNode.position.x * 0.5
        cameraNode.position.z = playerNode.position.z + 12.0

        // Suction logic & Enemy AI
        var remainingEnemies: [SCNNode] = []
        for enemy in enemies {
            let dx = playerNode.position.x - enemy.position.x
            let dz = playerNode.position.z - enemy.position.z
            let dist = sqrt(dx * dx + dz * dz)

            if dist < 2.5 {
                // Suction absorption animation
                let scale = SCNAction.scale(to: 0.1, duration: 0.2)
                let remove = SCNAction.removeFromParentNode()
                enemy.runAction(SCNAction.sequence([scale, remove]))

                tankCount += 1
                AudioManager.shared.playSFX(.enemyAbsorbed)
                creditsEarned += 8
                xpEarned += 10
                if Int.random(in: 0...5) == 0 { gemsEarned += 1 }

                if enemy.name == "0" { dustKilled += 1 }
                else if enemy.name == "1" { scrapKilled += 1 }
                else { oilKilled += 1 }
            } else {
                // Monsters stay at their spawn positions until the player reaches them.
                remainingEnemies.append(enemy)
            }
        }
        enemies = remainingEnemies

        // Boss Battle updates
        if let boss = bossNode, bossHP > 0 {
            let bdx = playerNode.position.x - boss.position.x
            let bdz = playerNode.position.z - boss.position.z
            let bdist = sqrt(bdx * bdx + bdz * bdz)

            if bdist < 4.0 {
                bossHP -= 4.0
                AudioManager.shared.playSFX(bossHP <= 0 ? .bossDefeated : .bossHit)
                creditsEarned += 5
                if bossHP <= 0 {
                    bossKilled += 1
                    creditsEarned += 200
                    gemsEarned += 15
                    xpEarned += 250
                    boss.runAction(SCNAction.removeFromParentNode())
                }
            }
        }

        // Check Victory Defeat conditions
        let enemiesCleared = enemies.isEmpty
            && pendingEnemySpawns == 0
            && (bossNode == nil || bossHP <= 0)
            && canFinishMission
        if enemiesCleared {
            stopLoop()
            onUpdate?(playerHP, tankCount, creditsEarned, gemsEarned, xpEarned, bossHP, dustKilled, scrapKilled, oilKilled, bossKilled, currentMapSnapshot, true, true)
        } else {
            onUpdate?(playerHP, tankCount, creditsEarned, gemsEarned, xpEarned, bossHP, dustKilled, scrapKilled, oilKilled, bossKilled, currentMapSnapshot, false, false)
        }
    }

    deinit {
        timer?.invalidate()
    }
}

// MARK: - Overlays
struct HUDPanel: View {
    let tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(tint.opacity(0.35), lineWidth: 1)
            )
    }
}

struct MissionClearedOverlay: View {
    let zone: FactoryZone
    let credits: Int
    let gems: Int
    let xp: Int
    let retry: () -> Void
    let leave: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 54))
                    .foregroundStyle(zone.tint)

                Text("任務成功！區域已淨化")
                    .font(.largeTitle.weight(.black))
                    .foregroundStyle(.white)

                Text("\(zone.name) 的異變塵怪已完全清除！")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))

                HStack(spacing: 18) {
                    Label("+\(credits) 晶幣", systemImage: "c.circle.fill")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.yellow)
                    Label("+\(gems) 寶石", systemImage: "diamond.fill")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.purple)
                    Label("+\(xp) XP", systemImage: "star.fill")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.cyan)
                }
                .font(.headline.weight(.bold))

                HStack(spacing: 16) {
                    Button("再玩一次", action: retry)
                        .buttonStyle(.bordered)
                        .tint(.white)

                    Button("返回基地", action: leave)
                        .buttonStyle(.borderedProminent)
                        .tint(zone.tint)
                }
                .padding(.top, 10)
            }
            .padding(28)
            .background(HUDPanel(tint: zone.tint))
            .padding(28)
        }
    }
}

struct MissionFailedOverlay: View {
    let zone: FactoryZone
    let retry: () -> Void
    let leave: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(.red)

                Text("任務失敗")
                    .font(.largeTitle.weight(.black))
                    .foregroundStyle(.white)

                Text("吸塵器電力耗盡，請至工坊升級電池或馬達後重新挑戰。")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))

                HStack(spacing: 16) {
                    Button("重新嘗試", action: retry)
                        .buttonStyle(.bordered)
                        .tint(.white)

                    Button("返回基地", action: leave)
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                }
            }
            .padding(28)
            .background(HUDPanel(tint: .red))
            .padding(28)
        }
    }
}

// MARK: - Xcode Canvas Preview
#Preview {
    ContentView()
}
