// SpeechService.swift
// TTS（文字轉語音）與 STT（語音轉文字）服務
// 依賴：AVFoundation、Combine、Speech 框架
// Info.plist 需要：NSMicrophoneUsageDescription、NSSpeechRecognitionUsageDescription

import AVFoundation
import Combine
import Speech

class SpeechService: NSObject, ObservableObject {

  // MARK: - Published

  @Published var isListening = false
  @Published var transcribedText = ""
  /// 非空時表示發生錯誤，UI 可監聽此值顯示提示
  @Published var errorMessage: String?

  // MARK: - Private — TTS

  private let synthesizer = AVSpeechSynthesizer()

  // MARK: - Private — STT

  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?
  private let audioEngine = AVAudioEngine()
  /// 是否已在 inputNode 安裝 tap（防止重複 installTap 崩潰）
  private var tapInstalled = false

  /// STT 辨識結束後呼叫（傳入最終辨識文字）
  var onRecognitionFinished: ((String) -> Void)?

  // MARK: - Language Mapping

  /// 將各種語言描述轉換為 BCP-47 locale 代碼
  static func bcp47(for language: String?) -> String {
    guard let lang = language?.lowercased().trimmingCharacters(in: .whitespaces),
          !lang.isEmpty else { return "en-US" }
    switch lang {
    case "en-us", "英文", "english", "en":          return "en-US"
    case "ja-jp", "日文", "japanese", "ja":          return "ja-JP"
    case "ko-kr", "韓文", "korean",  "ko":           return "ko-KR"
    case "zh-tw", "中文", "繁體中文", "chinese", "zh": return "zh-TW"
    case "fr-fr", "法文", "french",  "fr":           return "fr-FR"
    case "de-de", "德文", "german",  "de":           return "de-DE"
    case "es-es", "西班牙文", "spanish", "es":        return "es-ES"
    default:
      return lang.contains("-") ? lang : "en-US"
    }
  }

  // MARK: - TTS

  /// synthesizer 宣告為 class-level 實例變數（非函式局部變數），
  /// 確保在整個 speak 過程中不會被 ARC 提前回收。
  // private let synthesizer = AVSpeechSynthesizer()  ← 已在上方宣告，此為說明注解

  func speak(_ text: String, language: String?) {
    let localeId = SpeechService.bcp47(for: language)
    print("🔊 speak: \"\(text)\" locale=\(localeId)")

    // ① 強制停止 STT，確保 audioEngine.stop() + removeTap 已執行、session 已 deactivate
    stopListening()

    // ② 語音模式下說完後可能接著錄音，保持 .playAndRecord
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(
        .playAndRecord,
        mode: .default,
        options: [.defaultToSpeaker, .allowBluetoothHFP]
      )
      // notifyOthersOnDeactivation 確保其他 audio clients 知道 session 狀態
      try session.setActive(true, options: .notifyOthersOnDeactivation)
    } catch {
      print("🔊 AVAudioSession setup failed: \(error.localizedDescription)")
    }

    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = AVSpeechSynthesisVoice(language: localeId)
    utterance.rate = 0.45
    synthesizer.stopSpeaking(at: .immediate)
    synthesizer.speak(utterance)

    print("🔊 Voice used=\(utterance.voice?.language ?? "none")")
  }

  /// 翻面時依序朗讀：正面 → 停頓 0.5 秒 → 背面
  /// 利用 AVSpeechSynthesizer 的 utterance 排隊機制，不需要 DispatchQueue.asyncAfter。
  func speakCard(front: String, back: String, language: String?) {
    let localeId = SpeechService.bcp47(for: language)
    print("🔊 speakCard front=\"\(front)\" back=\"\(back)\" locale=\(localeId)")

    // ① 強制停止 STT：確保 audioEngine.stop() + inputNode.removeTap 已執行，
    //    並同步呼叫 setActive(false)，讓後續 TTS 可乾淨地接管 session。
    stopListening()

    // ② TTS 模式不需錄音，使用 .playback 可獲得最乾淨的播放路由；
    //    .defaultToSpeaker 確保走揚聲器而非聽筒。
    //    notifyOthersOnDeactivation 讓其他 audio client（如音樂 App）知道 session 狀態。
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(
        .playback,
        mode: .default,
        options: .defaultToSpeaker
      )
      try session.setActive(true, options: .notifyOthersOnDeactivation)
    } catch {
      print("🔊 AVAudioSession setup failed: \(error.localizedDescription)")
    }

    synthesizer.stopSpeaking(at: .immediate)

    // 正面 utterance
    let frontUtterance = AVSpeechUtterance(string: front)
    frontUtterance.voice = AVSpeechSynthesisVoice(language: localeId)
    frontUtterance.rate = 0.45

    // 背面 utterance — preUtteranceDelay 實現 0.5 秒停頓
    let backUtterance = AVSpeechUtterance(string: back)
    backUtterance.voice = AVSpeechSynthesisVoice(language: localeId)
    backUtterance.rate = 0.45
    backUtterance.preUtteranceDelay = 0.5

    // 依序加入隊列：synthesizer 會自動先說完 front 再說 back
    synthesizer.speak(frontUtterance)
    synthesizer.speak(backUtterance)
  }

  func stopSpeaking() {
    synthesizer.stopSpeaking(at: .immediate)
  }

  // MARK: - STT 權限

  /// 同時請求麥克風與語音辨識授權，回傳兩者皆通過才為 true
  func requestPermissions() async -> Bool {
    let micGranted: Bool
    if #available(iOS 17.0, *) {
      micGranted = await AVAudioApplication.requestRecordPermission()
    } else {
      micGranted = await withCheckedContinuation { cont in
        AVAudioSession.sharedInstance().requestRecordPermission {
          cont.resume(returning: $0)
        }
      }
    }
    guard micGranted else { return false }

    return await withCheckedContinuation { cont in
      SFSpeechRecognizer.requestAuthorization {
        cont.resume(returning: $0 == .authorized)
      }
    }
  }

  // MARK: - Engine 重置（防崩潰核心）

  /// 在每次 startListening 前必須呼叫。
  /// 依序：① 取消辨識任務 ② 結束辨識請求 ③ 停止引擎 ④ 移除 tap
  /// 不論引擎是否在運行，④ 都必須執行，否則下次 installTap 會崩潰。
  private func resetEngine() {
    // ① 取消辨識任務
    recognitionTask?.cancel()
    recognitionTask = nil

    // ② 結束辨識請求
    recognitionRequest?.endAudio()
    recognitionRequest = nil

    // ③ 停止引擎
    if audioEngine.isRunning {
      audioEngine.stop()
    }

    // ④ 移除 tap — 不論引擎狀態，已安裝才呼叫（呼叫未安裝的 tap 會 crash）
    if tapInstalled {
      audioEngine.inputNode.removeTap(onBus: 0)
      tapInstalled = false
    }
  }

  // MARK: - STT 啟動

  func startListening(language: String?) throws {
    let localeId = SpeechService.bcp47(for: language)
    guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeId)),
          recognizer.isAvailable else {
      throw SpeechError.recognizerUnavailable
    }

    // ① 完整重置 engine + 同步 deactivate session（修正 mDataByteSize(0) 根本原因）
    //    resetEngine() 確保舊的 tap 已移除，stopSpeaking() 中斷任何進行中的 TTS。
    stopListening()   // 含 resetEngine() + setActive(false)
    stopSpeaking()

    // ② Audio Session 切換：先明確 deactivate（讓系統回收資源），再切至 .record。
    //    若前次 session 已是 inactive，setActive(false) 會靜默失敗，不影響後續。
    let session = AVAudioSession.sharedInstance()
    do {
      try? session.setActive(false, options: .notifyOthersOnDeactivation)
      try session.setCategory(.record, mode: .measurement, options: .duckOthers)
      try session.setActive(true, options: .notifyOthersOnDeactivation)
    } catch {
      throw SpeechError.audioSessionSetupFailed(error)
    }

    // 建立辨識請求
    let req = SFSpeechAudioBufferRecognitionRequest()
    req.shouldReportPartialResults = true   // 即時回傳部分結果
    recognitionRequest = req

    // 建立辨識任務
    recognitionTask = recognizer.recognitionTask(with: req) { [weak self] result, error in
      guard let self else { return }

      if let result {
        DispatchQueue.main.async {
          self.transcribedText = result.bestTranscription.formattedString
        }
      }

      // 辨識結束條件：出現錯誤，或辨識引擎回傳最終結果
      if error != nil || result?.isFinal == true {
        let finalText = result?.bestTranscription.formattedString ?? self.transcribedText
        DispatchQueue.main.async {
          self.stopListening()
          self.onRecognitionFinished?(finalText)
        }
      }
    }

    // 安裝 Audio Tap
    let inputNode = audioEngine.inputNode
    let format = inputNode.outputFormat(forBus: 0)
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
      // Simulator 上可能收到 mDataByteSize == 0 的空 buffer，跳過避免警告
      guard buffer.audioBufferList.pointee.mBuffers.mDataByteSize > 0 else { return }
      self?.recognitionRequest?.append(buffer)
    }
    tapInstalled = true

    // 準備並啟動引擎
    audioEngine.prepare()
    do {
      try audioEngine.start()
    } catch {
      // 啟動失敗（Simulator 無硬體麥克風等）：清理所有資源後拋出
      resetEngine()
      try? session.setActive(false, options: .notifyOthersOnDeactivation)
      let msg = SpeechError.audioEngineFailedToStart(error).errorDescription ?? error.localizedDescription
      DispatchQueue.main.async { self.errorMessage = msg }
      throw SpeechError.audioEngineFailedToStart(error)
    }

    DispatchQueue.main.async {
      self.isListening = true
      self.errorMessage = nil
    }
  }

  // MARK: - STT 停止

  func stopListening() {
    resetEngine()
    // 同步停用 AudioSession，讓後續 speak() 能立即以 .playAndRecord 重啟 session，
    // 避免 DispatchQueue.main.async 與 TTS 的 setActive(true) 產生 race condition
    // 導致 IPCAUClient: can't connect to server 錯誤。
    try? AVAudioSession.sharedInstance().setActive(
      false, options: .notifyOthersOnDeactivation)
    DispatchQueue.main.async { [weak self] in
      self?.isListening = false
    }
  }

  // MARK: - 模糊比對

  /// 忽略大小寫、標點符號與多餘空白的寬鬆比對
  func matches(recognized: String, expected: String) -> Bool {
    func normalize(_ s: String) -> String {
      s.lowercased()
        .components(separatedBy: .punctuationCharacters).joined(separator: " ")
        .components(separatedBy: .whitespaces).filter { !$0.isEmpty }.joined(separator: " ")
    }
    let a = normalize(recognized)
    let b = normalize(expected)
    if a == b { return true }
    // 短答案（≤30 字元）：包含即算正確，應對口音差異
    let shorter = min(a.count, b.count)
    guard shorter > 0 else { return false }
    if shorter <= 30 { return a.contains(b) || b.contains(a) }
    return false
  }

  // MARK: - 錯誤定義

  enum SpeechError: LocalizedError {
    case recognizerUnavailable
    case requestFailed
    case audioSessionSetupFailed(Error)
    case audioEngineFailedToStart(Error)

    var errorDescription: String? {
      switch self {
      case .recognizerUnavailable:
        return "語音辨識器目前無法使用，請確認裝置支援此語言"
      case .requestFailed:
        return "無法建立語音辨識請求"
      case .audioSessionSetupFailed(let e):
        return "Audio Session 設定失敗：\(e.localizedDescription)"
      case .audioEngineFailedToStart(let e):
        return "音訊引擎無法啟動（Simulator 不支援實體麥克風）：\(e.localizedDescription)"
      }
    }
  }
}
