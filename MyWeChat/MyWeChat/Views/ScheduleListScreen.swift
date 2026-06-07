import SwiftUI

struct ScheduleListScreen: View {
    @EnvironmentObject private var session: AppSession
    @State private var creating = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(session.schedules) { item in
                    ScheduleRow(task: item)
                        .swipeActions {
                            Button(role: .destructive) {
                                Task { await session.deleteSchedule(item.id) }
                            } label: { Text("删除") }
                            Button {
                                Task { await session.toggleSchedule(id: item.id, enabled: !item.enabled) }
                            } label: { Text(item.enabled ? "停用" : "启用") }
                        }
                }
            }
            .navigationTitle("定时任务")
            .toolbar {
                Button {
                    creating = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $creating) {
                ScheduleEditorScreen { draft in
                    Task {
                        await session.createSchedule(draft)
                        creating = false
                    }
                }
            }
        }
    }
}

struct ScheduleRow: View {
    let task: ScheduleTask

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(task.title).font(.headline)
                Spacer()
                Text(task.enabled ? "启用" : "停用")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(task.enabled ? Color.green.opacity(0.15) : Color.gray.opacity(0.15))
                    .clipShape(Capsule())
            }
            Text(task.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("首次：\(task.sendAt.formatted(date: .abbreviated, time: .shortened))  循环：\(task.repeatCount) 次  间隔：\(Int(task.repeatInterval)) 秒")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}
