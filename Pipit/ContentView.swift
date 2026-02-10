//
//  ContentView.swift
//  Pipit
//
//  Main content view with sidebar navigation
//

import SwiftUI

struct ContentView: View {
    @AppStorage("sailsSid") private var sailsSid: String = ""
    @State private var viewModel: AppViewModel
    @State private var showSettings = false
    
    init() {
        let sailsSid = UserDefaults.standard.string(forKey: "sailsSid") ?? ""
        _viewModel = State(initialValue: AppViewModel(sailsSid: sailsSid.isEmpty ? nil : sailsSid))
    }
    
    var body: some View {
        Group {
            if sailsSid.isEmpty {
                needsSetupView
            } else {
                mainView
            }
        }
        .task {
            if !sailsSid.isEmpty && viewModel.creators.isEmpty {
                await viewModel.loadCreators()
            }
        }
        .onChange(of: sailsSid) { oldValue, newValue in
            // Update view model when cookie changes
            viewModel = AppViewModel(sailsSid: newValue.isEmpty ? nil : newValue)
            if !newValue.isEmpty {
                Task {
                    await viewModel.loadCreators()
                }
            }
        }
    }
    
    private var mainView: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showSettings = true
                        } label: {
                            Label("Settings", systemImage: "gear")
                        }
                    }
                }
        } detail: {
            if viewModel.selectedCreator != nil {
                ContentGridView(viewModel: viewModel)
            } else {
                ContentUnavailableView {
                    Label("Select a Creator", systemImage: "person.crop.rectangle.stack")
                } description: {
                    Text("Choose a creator or channel from the sidebar to view content")
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showSettings = false
                            }
                        }
                    }
            }
        }
    }
    
    private var needsSetupView: some View {
        NavigationStack {
            SettingsView()
                .navigationTitle("Setup Required")
        }
    }
}

#Preview {
    ContentView()
}
