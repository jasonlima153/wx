import SwiftUI

struct ScheduleListScreen: View {
    @EnvironmentObject var session: AppSession
    @State private var showCreateSheet = false
    
    var body: some View {
        NavigationStack {
            List(session.scheduledTasks) { task in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.message_content)
                            .font(.headline)
                            .lineLimit(1)
                        Text("目标: \(task.targets)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("计划时间: \(task.send_time)")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    // 状态标贴
                    Text(task.status == "pending" ? "等待发送" : (task.status == "sent" ? "发送成功" : "失败"))
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(task.status == "pending" ? Color.orange.opacity(0.2) : (task.status == "sent" ? Color.green.opacity(0.2) : Color.red.opacity(0.2)))
                        .foregroundColor(task.status == "pending" ? .orange : (task.status == "sent" ? .green : .red))
                        .cornerRadius(4)
                }
            }
            .navigationTitle("定时群发")
            .toolbar {
                Button(action: { showCreateSheet = true }) {
                    Image(systemName: "plus.circle.fill").font(.title3)
                }
            }
            .task {
                await session.loadScheduledTasks()
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateTaskSheet()
            }
        }
    }
}

// 新建定时任务表单
struct CreateTaskSheet: View {
    @EnvironmentObject var session: AppSession
    @Environment(\.dismiss) var dismiss
    
    @State private var messageText = ""
    @State private var selectedDate = Date()
    @State private var selectedTargets: Set<String> = [] // 勾选的联系人/群集合
    
    var body: some View {
        NavigationStack {
            Form {
                Section("第一步：选择接收对象（可多选）") {
                    List(session.contacts) { contact in
                        HStack {
                            Text(contact.remark.isEmpty ? contact.nickname : contact.remark)
                            Spacer()
                            if selectedTargets.contains(contact.wx_id) {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            } else {
                                Image(systemName: "circle").foregroundColor(.gray)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedTargets.contains(contact.wx_id) {
                                selectedTargets.remove(contact.wx_id)
                            } else {
                                selectedTargets.insert(contact.wx_id)
                            }
                        }
                    }
                    .frame(height: 200) // 限制列表高度
                }
                
                Section("第二步：输入发送内容") {
                    TextField("想要定时发送的微信文本...", text: $messageText)
                }
                
                Section("第三步：选择投递时间") {
                    DatePicker("选择具体时间", selection: $selectedDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                }
            }
            .navigationTitle("创建定时微信")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("提交审核") { submitTask() }.disabled(messageText.isEmpty || selectedTargets.isEmpty)
                }
            }
        }
    }
    
    func submitTask() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timeString = formatter.string(from: selectedDate)
        
        // 拼接勾选的目标 wxid
        let targetsString = Array(selectedTargets).joined(separator: ",")
        
        let payload: [String: Any] = [
            "id": UUID().uuidString,
            "message_content": messageText,
            "msg_type": "text",
            "target_accounts": "2",
            "targets": targetsString,
            "send_time": timeString,
            "status": "pending"
        ]
        
        // POST 给宝塔后端数据库，后台调度器会自动接管，在指定时间通过电脑微信帮你发出去
        guard let url = URL(string: "http://120.48.88.19:8000/api/scheduled_tasks/create") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        URLSession.shared.dataTask(with: req) { _, _, _ in
            DispatchQueue.main.async {
                Task {
                    await session.loadScheduledTasks() // 刷新列表
                    dismiss()
                }
            }
        }.resume()
    }
}
