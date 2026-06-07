import SwiftUI
import SwiftData

// MARK: - 功能大厅
struct FunctionsView: View {
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("自动化工具")) {
                    NavigationLink(destination: MassSenderView()) {
                        HStack {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(.white)
                                .padding(6)
                                .background(Color.orange)
                                .cornerRadius(8)
                            Text("高级群发助手")
                                .font(.system(size: 16))
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("功能")
        }
    }
}

// MARK: - 群发助手主界面
struct MassSenderView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MassSendTask.triggerTime) private var tasks: [MassSendTask]
    @State private var showingAddTask = false

    var body: some View {
        List {
            ForEach(tasks) { task in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(task.taskName)
                            .font(.headline)
                        Spacer()
                        Toggle("", isOn: Bindable(task).isActive)
                            .labelsHidden()
                    }

                    Text("发送给: \(task.targetNames.joined(separator: ", "))")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .lineLimit(1)

                    Text("内容: \(task.messageContent)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(2)

                    HStack {
                        Image(systemName: "clock")
                        Text("\(formatDate(task.triggerTime)) (\(task.repeatMode))")
                    }
                    .font(.caption)
                    .foregroundColor(task.isActive ? .green : .gray)
                }
                .padding(.vertical, 4)
            }
            .onDelete(perform: deleteTask)
        }
        .navigationTitle("群发助手")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddTask = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskView()
        }
    }

    private func deleteTask(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(tasks[index])
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - 新建定时群发任务表单
struct AddTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.presentationMode) var presentationMode

    @State private var taskName = ""
    @State private var messageContent = ""
    @State private var triggerTime = Date()
    @State private var repeatMode = "单次"

    let repeatOptions = ["单次", "每天", "每周", "每月"]
    @State private var selectedTargets = ["所有客户群", "VIP客户名单"]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("基础信息")) {
                    TextField("任务名称 (如: 节日祝福群发)", text: $taskName)
                }

                Section(header: Text("发送目标")) {
                    HStack {
                        Text("已选 \(selectedTargets.count) 个对象")
                        Spacer()
                        Button("选择群/好友") {
                        }
                    }
                    if !selectedTargets.isEmpty {
                        Text(selectedTargets.joined(separator: ", "))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                Section(header: Text("群发内容")) {
                    TextEditor(text: $messageContent)
                        .frame(height: 100)
                }

                Section(header: Text("触发与重复机制")) {
                    DatePicker("执行时间", selection: $triggerTime)
                    Picker("重复周期", selection: $repeatMode) {
                        ForEach(repeatOptions, id: \.self) { mode in
                            Text(mode).tag(mode)
                        }
                    }
                }
            }
            .navigationTitle("新建群发任务")
            .navigationBarItems(
                leading: Button("取消") { presentationMode.wrappedValue.dismiss() },
                trailing: Button("保存") { saveTask() }
                    .disabled(taskName.isEmpty || messageContent.isEmpty)
            )
        }
    }

    private func saveTask() {
        let newTask = MassSendTask(
            taskName: taskName,
            targetNames: selectedTargets,
            targetIds: ["mock_id_1", "mock_id_2"],
            messageContent: messageContent,
            triggerTime: triggerTime,
            repeatMode: repeatMode
        )
        modelContext.insert(newTask)

        // 同步群发任务到云端服务器
        WebSocketManager.shared.syncMassTaskToServer(task: newTask)

        presentationMode.wrappedValue.dismiss()
    }
}
