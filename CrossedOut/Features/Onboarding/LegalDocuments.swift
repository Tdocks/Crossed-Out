import Foundation

/// In-app copies of the legal documents (source of truth: legal/EULA.md and
/// legal/PRIVACY_POLICY.md in the repo). Bundled as Swift constants so the
/// terms render instantly and offline at the moment of consent.
///
/// `termsVersion` is the version string recorded in `legal_acceptances`
/// (migration 0023). Bump it whenever the documents materially change —
/// every signed-in user will then be asked to accept the new version once.
enum LegalDocuments {

    static let termsVersion = "2026-07-18"

    struct Section: Identifiable {
        let id = UUID()
        let heading: String?
        let body: String
    }

    // MARK: - Terms of Use & EULA

    static let termsTitle = "Terms of Use & EULA"
    static let termsUpdated = "Last updated July 18, 2026"

    static let termsSections: [Section] = [
        Section(heading: nil, body: "By creating an account or using Crossed Out (\u{201C}the App\u{201D}), you agree to these Terms. If you do not agree, please do not use the App."),
        Section(heading: "1. Eligibility", body: "You must be at least 13 years old (or the minimum digital-consent age in your region) to use the App. If you are under 18, you represent that a parent or guardian has reviewed and agreed to these Terms."),
        Section(heading: "2. Your account", body: "A real account (Sign in with Apple or email/password) is required. You are responsible for your account and for keeping your credentials secure. You may delete your account at any time in Settings \u{2192} Delete Account, which permanently removes your account and associated content."),
        Section(heading: "3. Acceptable use and zero tolerance for objectionable content", body: "Crossed Out includes features where users may create or share content (community posts, prayer requests, shared \u{201C}Bridge\u{201D} messages, notes). There is zero tolerance for objectionable, abusive, harassing, hateful, sexually explicit, violent, deceptive, or illegal content, and for abusive users. You agree not to post or transmit such content, impersonate others, harvest data, solicit funds without authorization, or claim divine authority over another user.\n\nYou can report objectionable content or block an abusing user from within the App. We will review reports and act on them within 24 hours, removing content and ejecting users who violate these Terms. We may remove content or suspend accounts at our discretion to keep the community safe."),
        Section(heading: "4. Spiritual, medical, legal, and financial content", body: "The App and its AI guide (\u{201C}Kyra\u{201D}) provide spiritual encouragement and information, not professional advice. Kyra and the App are not a substitute for a pastor, licensed counselor, physician, attorney, financial advisor, or emergency services. Nothing in the App should be relied on as medical, mental health, legal, or financial advice. If you are in crisis, contact local emergency services or a crisis line (in the U.S., call or text 988)."),
        Section(heading: "5. AI-generated content", body: "Some content is generated or framed by AI and may contain errors. The App is designed to ground Scripture in real, unaltered Bible text, but you should verify anything important against Scripture and trusted teachers. We do not guarantee the accuracy or completeness of AI output."),
        Section(heading: "6. Content ownership and license", body: "You retain ownership of content you create. You grant Crossed Out a limited, worldwide, royalty-free license to host, store, display, and transmit your content solely to operate and improve the App. You are responsible for content you share and represent that you have the right to share it."),
        Section(heading: "7. Intellectual property", body: "The App, its design, and its original content are owned by Crossed Out and protected by law. Bible text is provided under the applicable translation's terms (public-domain translations, and licensed translations under their licenses)."),
        Section(heading: "8. Subscriptions (Crossed Out Plus)", body: "Paid subscriptions, if offered, are billed through the Apple App Store and governed by Apple's terms in addition to these. Subscriptions auto-renew unless canceled at least 24 hours before the period ends; manage or cancel in your Apple account settings."),
        Section(heading: "9. Disclaimers and limitation of liability", body: "The App is provided \u{201C}as is\u{201D} without warranties of any kind. To the maximum extent permitted by law, Crossed Out is not liable for indirect, incidental, or consequential damages arising from your use of the App."),
        Section(heading: "10. Changes and termination", body: "We may update these Terms; material changes will be communicated in-App. We may suspend or terminate access for violations. You may stop using the App and delete your account at any time."),
        Section(heading: "11. Contact", body: "Questions about these Terms: reach us through the Crossed Out support page listed on the App Store.")
    ]

    // MARK: - Privacy Policy

    static let privacyTitle = "Privacy Policy"
    static let privacyUpdated = "Last updated July 18, 2026"

    static let privacySections: [Section] = [
        Section(heading: nil, body: "Crossed Out (\u{201C}we\u{201D}) respects your privacy. This policy explains what we collect, why, and your choices. Because a faith app necessarily touches sensitive topics, we hold this data to a high standard."),
        Section(heading: "1. Information we collect", body: "Account: email address (email/password sign-up) or an Apple-provided identifier (Sign in with Apple; you may use Apple's Hide My Email).\n\nFaith & wellbeing inputs you provide: your selected focus areas (e.g. anxiety, grief, addiction, marriage), daily mood check-ins, verse feedback, reflections and notes, and independent-study devotionals. This can reveal sensitive personal circumstances, and we treat it as sensitive data.\n\nUsage: in-app activity needed to personalize content (verses shown, completions, streaks) and privacy-preserving product analytics and crash reports (no advertising identifiers).\n\nWe do not collect precise location unless you use a location-based feature and grant permission, and we do not use third-party advertising SDKs."),
        Section(heading: "2. How we use it", body: "To personalize Scripture, devotionals, and guidance to what you're going through (the core function of the App). To operate features you use (community, saved content, streaks). To keep the community safe (reviewing reports, enforcing our Terms). To improve the App via aggregate, privacy-preserving analytics.\n\nWe do not sell your personal information, and we do not use your content to train third-party foundation models."),
        Section(heading: "3. AI processing", body: "When you use AI features (the Kyra guide, AI devotional suggestions, semantic search), the text you submit and relevant context are sent to our AI provider (currently OpenAI) solely to generate a response. We send the minimum needed and do not include your identity beyond what the feature requires. Our provider processes this under its API terms and does not use API data to train its models."),
        Section(heading: "4. Storage and security", body: "Data is stored with our backend provider (Supabase) with row-level security so each user can access only their own content. We use encryption in transit and access controls. No system is perfectly secure, but we work to protect your data."),
        Section(heading: "5. Sharing", body: "We share data only with service providers who help us run the App (hosting, AI processing, analytics/crash reporting) under contract, or when required by law, or to protect safety. Content you choose to post to community or share via Bridge is visible to its intended audience."),
        Section(heading: "6. Your choices and rights", body: "Access/deletion: delete your account and associated content anytime in Settings \u{2192} Delete Account. This is permanent.\n\nRegional rights: depending on your location (e.g. GDPR/CCPA), you may have rights to access, correct, delete, or port your data, and to object to certain processing. Contact us to exercise these.\n\nNotifications: manage in device settings."),
        Section(heading: "7. Children", body: "The App is not directed to children under 13, and we do not knowingly collect their data. If you believe a child has provided data, contact us for removal."),
        Section(heading: "8. Changes", body: "We will post updates here and communicate material changes in-App."),
        Section(heading: "9. Contact", body: "Privacy questions or requests: reach us through the Crossed Out support page listed on the App Store.")
    ]
}
