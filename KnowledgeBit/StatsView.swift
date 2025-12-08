import SwiftUI
import SwiftData

struct StatsView: View {
  @Query(sort: \StudyLog.date, order: .reverse) var logs: [StudyLog]

  var body: some View {
    VStack(spacing: 15) {
      // 1. 火焰與連續天數
      HStack {
        Image(systemName: "flame.fill")
          .font(.largeTitle)
          .foregroundStyle(.orange)

        VStack(alignment: .leading) {
          Text("連續學習")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text("\(calculateStreak()) 天")
            .font(.title2)
            .bold()
        }
        Spacer()
      }
      .padding(.horizontal)

      // 2. 過去 7 天的圓圈圈
      HStack(spacing: 12) {
        ForEach(0..<7) { dayOffset in
          let date = Calendar.current.date(byAdding: .day, value: -6 + dayOffset, to: Date())!
          let isCompleted = checkIsCompleted(date: date)
          let isToday = Calendar.current.isDateInToday(date)

          VStack {
            // 星期幾 (例如 Mon)
            Text(date.formatted(.dateTime.weekday(.abbreviated)))
              .font(.caption2)
              .foregroundStyle(.secondary)

            // 圓圈
            Circle()
              .fill(isCompleted ? Color.green : (isToday ? Color.gray.opacity(0.2) : Color.gray.opacity(0.1)))
              .frame(width: 30, height: 30)
              .overlay {
                if isCompleted {
                  Image(systemName: "checkmark")
                    .font(.caption)
                    .foregroundStyle(.white)
                }
              }
          }
        }
      }
    }
    .padding()
    .background(Color.white)
    .cornerRadius(12)
    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    .padding(.horizontal)
  }

  // 計算連續天數 (簡易版邏輯)
  func calculateStreak() -> Int {
    // 這裡可以寫更複雜的邏輯，目前先簡單回傳總打卡天數
    return logs.count
  }

  // 檢查某一天是否有打卡紀錄
  func checkIsCompleted(date: Date) -> Bool {
    return logs.contains { log in
      Calendar.current.isDate(log.date, inSameDayAs: date)
    }
  }
}
