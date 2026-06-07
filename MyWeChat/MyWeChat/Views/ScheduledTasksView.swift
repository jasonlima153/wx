import SwiftUI

// MARK: - 定时群发任务列表视图
struct ScheduledTasksView: View {
    @StateObject private var taskManager = ScheduledTaskManager.shared
    @State private var showingCreateTask = false

    var body: some View {
        NavigationView {
            List {
                if taskManager.tasks.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock.badge.questionmark")
                            .font(.system(size: 40))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("暂无定时任务")
                            .foregroundColor(.gray)
                        Text("点击右上角 + 创建群发任务")
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    ForEach(taskManager.tasks) { task in
                        ScheduledTaskRowView(task: task)
                            .contextMenu {
                                Button(role: .destructive) {
                                    taskManager.deleteTask(task.id)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }

                                if task.status == .running {
                                    Button {
                                        taskManager.pauseTask(task.id)
                                    } label: {
                                        Label("暂停", systemImage: "pause")
                                    }
                                }

                                if task.status == .paused {
                                    Button {
                                        taskManager.resumeTask(task.id)
                                    } label: {
                                        Label("继续", systemImage: "play")
                                    }
                                }
                            }
                    }
                }
            }
            .listStyle(PlainListStyle())
            .navigationTitle("定时群发")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCreateTask = true }) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 22))
                    }
                }
            }
            .sheet(isPresented: $showingCreateTask) {
                CreateScheduledTaskView()
            }
            .onAppear {
                taskManager.fetchTasks()
            }
            .refreshable {
                taskManager.fetchTasks()
            }
        }
    }
}

// MARK: - 任务行视图
struct ScheduledTaskRowView: View {
    let task: ScheduledMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题行
            HStack {
                Text(task.name.isEmpty ? "群发任务" : task.name)
                    .font(.system(size: 17, weight: .medium))
                    .lineLimit(1)

                Spacer()

                // 状态标签
                Text(task.statusText)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(statusTextColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusBgColor)
                    .cornerRadius(Capsule().radius / 2)
            }

            // 消息预览
            Text(task.messageContent)
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .lineLimit(2)

            // 信息行
            HStack(spacing: 16) {
                Label("\(task.targetAccounts.count)个账号", systemImage: "person.2")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)

                Label("\(task.targets.count)个目标", systemImage: "bubble.left.and.bubble.right")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)

                Spacer()

                Text("进度: \(task.progressText)")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }

            // 时间行
            HStack(spacing: 16) {
                Label(task.nextRunDisplay, systemImage: "clock")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)

                Label(task.repeatIntervalDisplay, systemImage: "repeat")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 6)
    }

    private var statusTextColor: Color {
        switch task.status {
        case .pending: return .blue
        case .running: return .green
        case .paused: return .orange
        case .completed: return .gray
        }
    }

    private var statusBgColor: Color {
        switch task.status {
        case .pending: return Color.blue.opacity(0.15)
        case .running: return Color.green.opacity(0.15)
        case .paused: return Color.orange.opacity(0.15)
        case .completed: return Color.gray.opacity(0.15)
        }
    }
}

// MARK: - 定时任务管理器
class ScheduledTaskManager: ObservableObject {
    static let shared = ScheduledTaskManager()

    @Published var tasks: [ScheduledMessage] = []

    private var baseURL: String {
        WebSocketManager.shared.serverURL.replacingOccurrences(of: "/ws", with: "")
    }

    func fetchTasks() {
        guard let url = URL(string: "\(baseURL)/api/scheduled_tasks") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }
            let result = json.map { ScheduledMessage(from: $0) }
            DispatchQueue.main.async {
                self?.tasks = result
            }
        }.resume()
    }

    func createTask(name: String, messageContent: String, msgType: String,
                    targetAccounts: [String], targets: [String],
                    sendTime: Date, repeatInterval: Int, repeatCount: Int,
                    completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/scheduled_tasks") else {
            completion(false)
            return
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let body: [String: Any] = [
            "name": name,
            "message_content": messageContent,
            "msg_type": msgType,
            "target_accounts": targetAccounts,
            "targets": targets,
            "send_time": formatter.string(from: sendTime),
            "repeat_interval": repeatInterval,
            "repeat_count": repeatCount
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let jsonData = try? JSONSerialization.data(withJSONObject: body) {
            URLSession.shared.uploadTask(with: request, from: jsonData) { [weak self] data, _, _ in
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   json["status"] as? String == "ok" {
                    DispatchQueue.main.async {
                        self?.fetchTasks()
                    }
                    completion(true)
                } else {
                    completion(false)
                }
            }.resume()
        }
    }

    func deleteTask(_ taskID: String) {
        guard let url = URL(string: "\(baseURL)/api/scheduled_tasks/\(taskID)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        URLSession.shared.dataTask(with: request) { [weak self] _, _, _ in
            DispatchQueue.main.async {
                self?.fetchTasks()
            }
        }.resume()
    }

    func pauseTask(_ taskID: String) {
        guard let url = URL(string: "\(baseURL)/api/scheduled_tasks/\(taskID)/pause") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"

        URLSession.shared.dataTask(with: request) { [weak self] _, _, _ in
            DispatchQueue.main.async {
                self?.fetchTasks()
            }
        }.resume()
    }

    func resumeTask(_ taskID: String) {
        guard let url = URL(string: "\(baseURL)/api/scheduled_tasks/\(taskID)/resume") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"

        URLSession.shared.dataTask(with: request) { [weak self] _, _, _ in
            DispatchQueue.main.async {
                self?.fetchTasks()
            }
        }.resume()
    }
}
