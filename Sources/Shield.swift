import WebKit

// The ad blocker, the same as Search for Mac's (Shield.swift there): a
// content rule list compiled once and enforced inside WebKit's networking,
// before a request is made. Third parties whose only job is to watch or to
// sell, and the few slots that are reliably an advertisement.

@MainActor
final class Shield {
    static let shared = Shield()

    private(set) var list: WKContentRuleList?
    private var waiting: [WKUserContentController] = []

    private static let unwanted = [
        "doubleclick.net", "googlesyndication.com", "googleadservices.com",
        "googletagservices.com", "google-analytics.com", "googletagmanager.com",
        "adservice.google.com", "amazon-adsystem.com", "adnxs.com", "adsrvr.org",
        "criteo.com", "criteo.net", "taboola.com", "outbrain.com",
        "rubiconproject.com", "pubmatic.com", "openx.net", "casalemedia.com",
        "smartadserver.com", "sharethrough.com", "indexww.com", "bidswitch.net",
        "33across.com", "teads.tv", "moatads.com", "adroll.com",
        "scorecardresearch.com", "quantserve.com", "chartbeat.com",
        "hotjar.com", "mouseflow.com", "fullstory.com", "clarity.ms",
        "mixpanel.com", "amplitude.com", "segment.com", "segment.io",
        "branch.io", "appsflyer.com", "adjust.com", "analytics.tiktok.com",
        "connect.facebook.net", "ads-twitter.com", "analytics.twitter.com",
    ]

    private static let slots = [
        ".adsbygoogle", "ins.adsbygoogle", "[id^=\"google_ads_\"]",
        "[id^=\"div-gpt-ad\"]", "[id^=\"taboola-\"]", "#taboola-below-article",
        "iframe[src*=\"doubleclick.net\"]", "iframe[src*=\"googlesyndication\"]",
        "iframe[src*=\"amazon-adsystem\"]",
        ".ad-slot", ".ad-slot-container", ".top-banner-ad-container",
        ".ad-leaderboard", ".ad-billboard", ".ad-giga", ".ad-mpu", ".ad-mrec",
        ".ad-unit", ".adunit", ".adslot", ".dfp-ad", ".gpt-ad", ".w_ad",
    ]

    private static let slotsBySite: [(sites: [String], selector: String)] = [
        (["*as.com", "*elpais.com"], ".ad"),
        (["*theguardian.com"], ".top-fronts-banner-ad-container"),
        (["*independent.co.uk", "*the-independent.com"], "#billboard-wrapper"),
        (["*cnn.com"], ".ad-slot-header__wrapper"),
    ]

    func compile() {
        guard list == nil else { return }
        var rules: [[String: Any]] = Shield.unwanted.map { domain in
            let escaped = domain.replacingOccurrences(of: ".", with: "\\.")
            return [
                "trigger": ["url-filter": "^https?://([^/]+\\.)?\(escaped)", "load-type": ["third-party"]],
                "action": ["type": "block"],
            ]
        }
        rules.append([
            "trigger": ["url-filter": ".*"],
            "action": ["type": "css-display-none", "selector": Shield.slots.joined(separator: ", ")],
        ])
        rules += Shield.slotsBySite.map { entry in
            [
                "trigger": ["url-filter": ".*", "if-domain": entry.sites],
                "action": ["type": "css-display-none", "selector": entry.selector],
            ]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: rules),
              let json = String(data: data, encoding: .utf8),
              let store = WKContentRuleListStore.default()
        else { return }
        store.compileContentRuleList(forIdentifier: "search-shield", encodedContentRuleList: json) { [weak self] compiled, _ in
            MainActor.assumeIsolated {
                guard let self, let compiled else { return }
                self.list = compiled
                self.waiting.forEach { $0.add(compiled) }
                self.waiting = []
            }
        }
    }

    /// Every tab asks for it; whoever asks before it is ready gets it then.
    func protect(_ controller: WKUserContentController) {
        if let list { controller.add(list) } else { waiting.append(controller) }
    }
}
