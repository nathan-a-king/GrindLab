//
//  WelcomeTipsView.swift
//  Coffee Grind Analyzer
//
//  Created by Codex on 8/20/25.
//

import SwiftUI

struct WelcomeTipsView: View {
    let onContinue: () -> Void
    let onOpenHelp: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.14, green: 0.10, blue: 0.08),
                    Color(red: 0.08, green: 0.06, blue: 0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    header

                    VStack(alignment: .leading, spacing: 18) {
                        tipRow(
                            icon: "ruler.fill",
                            title: "Calibrate once",
                            message: "Use the ruler image in Settings so every analysis reflects true particle size."
                        )

                        tipRow(
                            icon: "sun.max.fill",
                            title: "Light matters",
                            message: "Shoot on a bright, even surface. Avoid harsh shadows and keep the flash handy."
                        )

                        tipRow(
                            icon: "square.grid.3x3",
                            title: "Keep things tidy",
                            message: "Spread grounds thinly and fill the camera frame. The live grid helps center your sample."
                        )
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )

                    callToAction
                }
                .padding(30)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 16) {
            Image("app-icon-display")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)

            VStack(spacing: 8) {
                Text("Welcome to GrindLab")
                    .font(.system(size: 32, weight: .semibold, design: .default))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.9)

                Text("Three quick tips to get rock-solid grind readings.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func tipRow(icon: String, title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var callToAction: some View {
        VStack(spacing: 16) {
            Button(action: onContinue) {
                Text("Start Exploring")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white)
                    )
                    .foregroundColor(Color(red: 0.20, green: 0.15, blue: 0.12))
            }

            Button(action: onOpenHelp) {
                HStack(spacing: 8) {
                    Image(systemName: "questionmark.circle")
                    Text("Need a detailed walkthrough?")
                }
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.85))
            }

            Text("You can revisit these tips anytime from Settings → Help & Tips.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 4)
    }
}

struct WelcomeTipsView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeTipsView(onContinue: {}, onOpenHelp: {})
            .preferredColorScheme(.dark)
    }
}
