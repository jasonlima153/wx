import SwiftUI

struct ContactPickerView: View {
    @Environment(\.presentationMode) var presentationMode

    let allContacts = ["张小龙", "文件传输助手", "前端开发群", "产品核心群", "李四", "王五"]

    @State private var selectedContacts: Set<String> = []

    var onForward: ([String]) -> Void

    var body: some View {
        NavigationView {
            List {
                ForEach(allContacts, id: \.self) { contact in
                    Button(action: {
                        toggleSelection(contact)
                    }) {
                        HStack {
                            Image(systemName: selectedContacts.contains(contact) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedContacts.contains(contact) ? .green : .gray)
                                .font(.title2)

                            Image(systemName: "person.crop.square.fill")
                                .resizable()
                                .frame(width: 40, height: 40)
                                .foregroundColor(.blue.opacity(0.6))
                                .cornerRadius(6)
                                .padding(.leading, 8)

                            Text(contact)
                                .foregroundColor(.primary)
                                .font(.system(size: 16))

                            Spacer()
                        }
                    }
                }
            }
            .listStyle(PlainListStyle())
            .navigationTitle("选择联系人")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("取消") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button(selectedContacts.count == allContacts.count ? "取消全选" : "全选") {
                    if selectedContacts.count == allContacts.count {
                        selectedContacts.removeAll()
                    } else {
                        selectedContacts = Set(allContacts)
                    }
                }
            )

            VStack {
                Button(action: {
                    onForward(Array(selectedContacts))
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("发送 (\(selectedContacts.count))")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedContacts.isEmpty ? Color.gray.opacity(0.5) : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(selectedContacts.isEmpty)
                .padding(.horizontal)
                .padding(.bottom, 10)
            }
            .background(Color(UIColor.systemBackground).shadow(radius: 2))
        }
    }

    private func toggleSelection(_ contact: String) {
        if selectedContacts.contains(contact) {
            selectedContacts.remove(contact)
        } else {
            selectedContacts.insert(contact)
        }
    }
}
