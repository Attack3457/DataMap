// 📁 File: Views/OnboardingView.swift
// 🎯 WELCOME AND ONBOARDING EXPERIENCE

import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var showMainApp = false
    @Environment(\.dismiss) private var dismiss
    
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: LocalizedStrings.welcomeTitle,
            subtitle: LocalizedStrings.welcomeSubtitle,
            imageName: "globe.desk.fill",
            description: "Transform your file system into an immersive 3D world map where every file and folder has its place on the globe.",
            color: .blue
        ),
        OnboardingPage(
            title: LocalizedStrings.feature1Title,
            subtitle: "See your files in a whole new way",
            imageName: "map.fill",
            description: "Navigate through your file system using familiar geographic metaphors. Root folders become continents, subfolders become countries, and files become buildings.",
            color: .green
        ),
        OnboardingPage(
            title: LocalizedStrings.feature2Title,
            subtitle: "Lightning-fast file scanning",
            imageName: "bolt.fill",
            description: "Our advanced scanning engine can process thousands of files per second using GPU acceleration and smart caching.",
            color: .orange
        ),
        OnboardingPage(
            title: LocalizedStrings.feature3Title,
            subtitle: "Find anything instantly",
            imageName: "magnifyingglass",
            description: "Use spatial search to find files by location, advanced filters by size and date, or traditional text search.",
            color: .purple
        ),
        OnboardingPage(
            title: "Privacy First",
            subtitle: "Your data stays on your device",
            imageName: "lock.shield.fill",
            description: "DataMap processes everything locally. No internet required, no data collection, complete privacy.",
            color: .red
        )
    ]
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [pages[currentPage].color.opacity(0.1), pages[currentPage].color.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.5), value: currentPage)
                
                // Bottom controls
                VStack(spacing: 24) {
                    // Page indicator
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? pages[currentPage].color : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .scaleEffect(index == currentPage ? 1.2 : 1.0)
                                .animation(.spring(response: 0.3), value: currentPage)
                        }
                    }
                    
                    // Navigation buttons
                    HStack(spacing: 16) {
                        if currentPage > 0 {
                            Button(LocalizedStrings.previousStep) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    currentPage -= 1
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        Spacer()
                        
                        if currentPage < pages.count - 1 {
                            Button(LocalizedStrings.nextStep) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    currentPage += 1
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        } else {
                            Button(LocalizedStrings.getStarted) {
                                completeOnboarding()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                    }
                    .padding(.horizontal, 32)
                    
                    // Skip button
                    if currentPage < pages.count - 1 {
                        Button(LocalizedStrings.skipTour) {
                            completeOnboarding()
                        }
                        .foregroundColor(.secondary)
                        .font(.footnote)
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .fullScreenCover(isPresented: $showMainApp) {
            MainAppLayout()
        }
    }
    
    private func completeOnboarding() {
        // Mark onboarding as completed
        UserDefaults.standard.set(true, forKey: "onboarding_completed")
        
        // Log analytics event
        AnalyticsManager.shared.logEvent("onboarding_completed", properties: [
            "pages_viewed": String(currentPage + 1),
            "completion_method": currentPage == pages.count - 1 ? "finished" : "skipped"
        ])
        
        // Show main app
        withAnimation(.easeInOut(duration: 0.5)) {
            showMainApp = true
        }
    }
}

// MARK: - Onboarding Page View
struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(page.color.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: page.imageName)
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(page.color)
            }
            .scaleEffect(1.0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: page.color)
            
            // Text content
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                
                Text(page.subtitle)
                    .font(.title2)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                Text(page.description)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 32)
                    .lineLimit(nil)
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Onboarding Page Model
struct OnboardingPage {
    let title: String
    let subtitle: String
    let imageName: String
    let description: String
    let color: Color
}

// MARK: - Welcome Screen
struct WelcomeScreen: View {
    @State private var showOnboarding = false
    @State private var animateIcon = false
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [.blue.opacity(0.1), .purple.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // App icon animation
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(.blue.opacity(0.1))
                            .frame(width: 140, height: 140)
                            .scaleEffect(animateIcon ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: animateIcon)
                        
                        Image(systemName: "globe.desk.fill")
                            .font(.system(size: 64, weight: .light))
                            .foregroundColor(.blue)
                            .rotationEffect(.degrees(animateIcon ? 360 : 0))
                            .animation(.linear(duration: 20.0).repeatForever(autoreverses: false), value: animateIcon)
                    }
                    
                    VStack(spacing: 8) {
                        Text(LocalizedStrings.appName)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text(LocalizedStrings.appTagline)
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 16) {
                    Button(LocalizedStrings.getStarted) {
                        showOnboarding = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: 200)
                    
                    Button("Continue without tour") {
                        // Skip directly to main app
                        UserDefaults.standard.set(true, forKey: "onboarding_completed")
                        // This would navigate to main app
                    }
                    .foregroundColor(.secondary)
                    .font(.footnote)
                }
                .padding(.bottom, 50)
            }
            .padding(.horizontal, 32)
        }
        .onAppear {
            animateIcon = true
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView()
        }
    }
}

// MARK: - Feature Highlight View
struct FeatureHighlightView: View {
    let title: String
    let description: String
    let systemImage: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.1))
                    .frame(width: 48, height: 48)
                
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Quick Start Guide
struct QuickStartGuide: View {
    @Environment(\.dismiss) private var dismiss
    
    private let steps = [
        QuickStartStep(
            title: "1. Choose a Directory",
            description: "Select any folder on your device to start exploring",
            icon: "folder.badge.plus"
        ),
        QuickStartStep(
            title: "2. Watch the Magic",
            description: "Files are instantly mapped to geographic coordinates",
            icon: "map.fill"
        ),
        QuickStartStep(
            title: "3. Navigate & Explore",
            description: "Use zoom controls and search to find what you need",
            icon: "magnifyingglass"
        ),
        QuickStartStep(
            title: "4. Customize Experience",
            description: "Adjust performance settings and visual preferences",
            icon: "gearshape.fill"
        )
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.yellow)
                        
                        Text("Quick Start Guide")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Get up and running in minutes")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Steps
                    LazyVStack(spacing: 16) {
                        ForEach(steps.indices, id: \.self) { index in
                            QuickStartStepView(step: steps[index], isLast: index == steps.count - 1)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Action button
                    Button("Start Exploring") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 20)
                }
                .padding(.bottom, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LocalizedStrings.close) {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct QuickStartStep {
    let title: String
    let description: String
    let icon: String
}

struct QuickStartStepView: View {
    let step: QuickStartStep
    let isLast: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Step indicator
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(.blue.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: step.icon)
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                
                if !isLast {
                    Rectangle()
                        .fill(.blue.opacity(0.3))
                        .frame(width: 2, height: 40)
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                Text(step.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(step.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Preview
#Preview("Onboarding") {
    OnboardingView()
}

#Preview("Welcome") {
    WelcomeScreen()
}

#Preview("Quick Start") {
    QuickStartGuide()
}