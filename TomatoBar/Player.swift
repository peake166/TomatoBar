import AVFoundation
import SwiftUI
import Combine

class TBPlayer: ObservableObject {
    private var windupSound: AVAudioPlayer
    private var dingSound: AVAudioPlayer
    private var tickingSound: AVAudioPlayer
    
    // 使用AppSettings管理设置
    private var settings = AppSettings.shared
    
    // 保存订阅
    private var cancellables = Set<AnyCancellable>()

    private func setVolume(_ sound: AVAudioPlayer, _ volume: Double) {
        sound.setVolume(Float(volume), fadeDuration: 0)
    }

    init() {
        let windupSoundAsset = NSDataAsset(name: "windup")
        let dingSoundAsset = NSDataAsset(name: "ding")
        let tickingSoundAsset = NSDataAsset(name: "ticking")

        let wav = AVFileType.wav.rawValue
        do {
            windupSound = try AVAudioPlayer(data: windupSoundAsset!.data, fileTypeHint: wav)
            dingSound = try AVAudioPlayer(data: dingSoundAsset!.data, fileTypeHint: wav)
            tickingSound = try AVAudioPlayer(data: tickingSoundAsset!.data, fileTypeHint: wav)
        } catch {
            fatalError("Error initializing players: \(error)")
        }

        windupSound.prepareToPlay()
        dingSound.prepareToPlay()
        tickingSound.numberOfLoops = -1
        tickingSound.prepareToPlay()

        // 应用初始音量
        setVolume(windupSound, settings.windupVolume)
        setVolume(dingSound, settings.dingVolume)
        setVolume(tickingSound, settings.tickingVolume)
        
        // 监听音量设置的变化
        setupVolumeObservers()
    }
    
    // 设置音量观察器 - 修复版本
    private func setupVolumeObservers() {
        // 使用Publisher而不是直接使用Binding
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                guard let self = self else { return }
                // 当用户默认值变化时更新音量
                DispatchQueue.main.async {
                    self.updateAllVolumes()
                }
            }
            .store(in: &cancellables)
        
        // 初始更新一次
        updateAllVolumes()
    }
    
    // 更新所有音量
    func updateAllVolumes() {
        setVolume(windupSound, settings.windupVolume)
        setVolume(dingSound, settings.dingVolume)
        setVolume(tickingSound, settings.tickingVolume)
    }

    func playWindup() {
        windupSound.play()
    }

    func playDing() {
        dingSound.play()
    }

    func startTicking() {
        tickingSound.play()
    }

    func stopTicking() {
        tickingSound.stop()
    }
}
