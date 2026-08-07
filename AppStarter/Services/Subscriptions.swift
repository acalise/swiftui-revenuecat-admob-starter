import Foundation
import SwiftUI

#if canImport(RevenueCat)
import RevenueCat
#endif

/// RevenueCat subscriptions behind a small, observable API.
///
/// ## Why RevenueCat rather than StoreKit 2 directly
/// StoreKit 2 is genuinely good, and for a single non-consumable unlock you
/// don't need anything else. For *subscriptions* you'd still be signing up for:
/// server-side receipt validation (so a jailbroken device can't fake it),
/// renewal / cancellation / billing-retry / grace-period state you have to model
/// yourself, restore that works across devices and reinstalls, and the same
/// again for Android if you ever ship it. That's weeks of work whose failure
/// mode is "a paying customer loses access", and no user can see any of it.
///
/// The reason that matters most for this starter, though, is measurement.
/// RevenueCat is the join point between purchases and ad spend: the AppsFlyer
/// and Apple Search Ads hooks in `configure()` are what let you compute cost per
/// *paying subscriber* rather than cost per install. For a subscription app,
/// cost-per-install is a number that will confidently point you the wrong way.
///
/// ## The model
/// One entitlement (`AppConfig.entitlementID`). Products map to it in the
/// dashboard, so adding a lifetime tier or running a regional price test is
/// config, not a release. **Check the entitlement, never a product identifier.**
///
/// ## Without a RevenueCat key
/// Everything still runs. `purchase()` flips a local debug unlock so the paywall
/// and every gated feature can be exercised before App Store Connect exists.
@MainActor
@Observable
final class Subscriptions {

    /// Shared instance. A singleton because entitlement state is genuinely
    /// global, two views must never disagree about whether the user has paid.
    static let shared = Subscriptions()

    enum Tier: String { case free, pro }

    /// The current tier. Views observing this re-render when it changes.
    private(set) var tier: Tier = .free

    /// Plans fetched from the current offering. Empty until `loadPlans()` runs,
    /// and empty forever if RevenueCat isn't configured, which is what lets the
    /// paywall fall back to placeholder copy in development.
    private(set) var plans: [Plan] = []

    var isPro: Bool { tier == .pro }

    /// True when the SDK is keyed *and* linked, i.e. purchases can really happen.
    var isConfigured: Bool {
        #if canImport(RevenueCat)
        return AppConfig.revenueCatEnabled
        #else
        return false
        #endif
    }

    // MARK: - Persistence keys

    /// Last known tier, so a cold start on a plane doesn't show a paying
    /// customer a paywall. Optimistic on purpose: a churned user keeping access
    /// until their next online launch is a far cheaper mistake than locking out
    /// someone who paid.
    private let cachedTierKey = "sub.cachedTier"

    /// Debug override. `pro` force-unlocks; `free` force-locks even over a real
    /// entitlement, so you can check the free experience without cancelling a
    /// sandbox subscription. Ignored in release builds.
    private let overrideKey = "sub.debugOverride"

    private var didConfigure = false

    private init() {
        if let raw = UserDefaults.standard.string(forKey: cachedTierKey),
           let cached = Tier(rawValue: raw) {
            tier = cached
        }
        applyDebugOverride()
    }

    // MARK: - Bootstrap

    /// Configure the SDK and refresh entitlement state.
    ///
    /// Two of the calls in here are the ones people skip, and neither failure is
    /// visible from the dashboard:
    ///
    /// - `enableAdServicesAttributionTokenCollection()`, without it, Apple
    ///   Search Ads conversions never reach RevenueCat, so you get
    ///   cost-per-install per keyword and never cost-per-*subscriber* per
    ///   keyword. Enabling the Apple Ads integration in the dashboard does
    ///   nothing on its own.
    ///
    /// - `setAppsflyerID()`, without it, RevenueCat silently drops every revenue
    ///   event it would have forwarded to AppsFlyer. See `Analytics.swift` note 1.
    func start() async {
        #if canImport(RevenueCat)
        guard AppConfig.revenueCatEnabled, !didConfigure else {
            await refresh()
            return
        }
        didConfigure = true

        #if DEBUG
        // Verbose logging is how you verify the two calls below actually landed:
        // RevenueCat prints its synced subscriber attributes, and seeing
        // `$appsflyerId` there with a real value is the single line that proves
        // the whole attribution pipe works. It works even with ATT denied.
        Purchases.logLevel = .debug
        #endif

        Purchases.configure(withAPIKey: AppConfig.revenueCatKey)
        Purchases.shared.attribution.enableAdServicesAttributionTokenCollection()

        if let afID = Analytics.appsFlyerID {
            Purchases.shared.attribution.setAppsflyerID(afID)
        }

        await refresh()
        await loadPlans()
        #else
        await refresh()
        #endif
    }

    // MARK: - Entitlement state

    /// Re-read entitlement state from RevenueCat. Cheap: the SDK caches.
    func refresh() async {
        #if canImport(RevenueCat)
        guard AppConfig.revenueCatEnabled else { applyDebugOverride(); return }
        do {
            let info = try await Purchases.shared.customerInfo()
            apply(info)
        } catch {
            // Keep the last known good state. A network blip must never
            // downgrade a paying customer.
            debugLog("refresh failed: \(error.localizedDescription)")
            applyDebugOverride()
        }
        #else
        applyDebugOverride()
        #endif
    }

    #if canImport(RevenueCat)
    private func apply(_ info: CustomerInfo) {
        let active = info.entitlements.active[AppConfig.entitlementID] != nil
        setTier(active ? .pro : .free)
        applyDebugOverride()
    }
    #endif

    private func setTier(_ newTier: Tier) {
        tier = newTier
        UserDefaults.standard.set(newTier.rawValue, forKey: cachedTierKey)
    }

    /// Layers the debug override on top of whatever RevenueCat said.
    private func applyDebugOverride() {
        #if DEBUG
        switch UserDefaults.standard.string(forKey: overrideKey) {
        case "pro": tier = .pro
        case "free": tier = .free // force-lock wins over a real entitlement
        default: break
        }
        #endif
    }

    /// Debug only: force a tier, or pass `nil` to hand control back to RevenueCat.
    func setDebugOverride(_ newTier: Tier?) {
        #if DEBUG
        if let newTier {
            UserDefaults.standard.set(newTier.rawValue, forKey: overrideKey)
        } else {
            UserDefaults.standard.removeObject(forKey: overrideKey)
        }
        Task { await refresh() }
        #endif
    }

    // MARK: - Plans

    /// A purchasable plan, flattened for the paywall.
    struct Plan: Identifiable, Hashable {
        let id: String
        /// Localised price string, already formatted for the user's store front.
        /// **Always display this** rather than a hardcoded price, otherwise you
        /// end up showing "$29.99" to someone whose store will charge ¥4,500.
        let price: String
        let amount: Double
        let currency: String
        /// "Monthly" / "Yearly" / "Lifetime" / …
        let periodLabel: String
        /// Free-trial length in days, 0 when there's no introductory offer.
        let trialDays: Int
        let isAnnual: Bool
        let productID: String
    }

    /// Fetch the current offering's packages.
    func loadPlans() async {
        #if canImport(RevenueCat)
        guard AppConfig.revenueCatEnabled else { return }
        do {
            let offerings = try await Purchases.shared.offerings()
            let offering = AppConfig.offeringID.isEmpty
                ? offerings.current
: offerings.all[AppConfig.offeringID]

            guard let offering else {
                debugLog("no offering found. Check RevenueCat → Offerings.")
                return
            }
            plans = offering.availablePackages.map(Plan.init(package:))
            packagesByID = Dictionary(
                uniqueKeysWithValues: offering.availablePackages.map { ($0.identifier, $0) }
            )
        } catch {
            debugLog("offerings failed: \(error.localizedDescription)")
        }
        #endif
    }

    #if canImport(RevenueCat)
    private var packagesByID: [String: Package] = [:]
    #endif

    // MARK: - Purchase / restore

    enum PurchaseResult {
        case success
        /// The user tapped Cancel. Not an error: do not show an alert.
        case cancelled
        case failure(String)
    }

    /// Buy a plan.
    ///
    /// With no RevenueCat key this flips the local debug unlock, so the whole
    /// flow stays testable before App Store Connect exists.
    func purchase(_ plan: Plan?) async -> PurchaseResult {
        #if canImport(RevenueCat)
        guard AppConfig.revenueCatEnabled, let plan, let package = packagesByID[plan.id] else {
            return grantDebugUnlock()
        }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled { return .cancelled }
            apply(result.customerInfo)

            // Report to analytics only on a real entitlement grant, so a purchase
            // that somehow fails to entitle doesn't inflate the revenue numbers.
            if isPro {
                if plan.trialDays > 0 {
                    Analytics.trackTrialStart(amount: plan.amount, currency: plan.currency,
                                              productID: plan.productID, plan: plan.periodLabel)
                } else {
                    Analytics.trackPurchase(amount: plan.amount, currency: plan.currency,
                                            productID: plan.productID, plan: plan.periodLabel)
                }
            }
            return .success
        } catch {
            if let rcError = error as? ErrorCode, rcError == .purchaseCancelledError {
                return .cancelled
            }
            return .failure(error.localizedDescription)
        }
        #else
        return grantDebugUnlock()
        #endif
    }

    /// Restore purchases.
    ///
    /// Apple requires a visible restore control anywhere you sell a subscription
    ///: a missing one is a routine rejection (guideline 3.1.1), and a reviewer
    /// on a clean device *will* look for it.
    func restore() async -> PurchaseResult {
        #if canImport(RevenueCat)
        guard AppConfig.revenueCatEnabled else {
            return isPro ? .success : .failure("Nothing to restore.")
        }
        do {
            apply(try await Purchases.shared.restorePurchases())
            return isPro ? .success : .failure("No previous purchases found for this Apple ID.")
        } catch {
            return .failure(error.localizedDescription)
        }
        #else
        return isPro ? .success : .failure("Nothing to restore.")
        #endif
    }

    private func grantDebugUnlock() -> PurchaseResult {
        #if DEBUG
        setDebugOverride(.pro)
        setTier(.pro)
        debugLog("no RevenueCat key, granted local debug unlock")
        return .success
        #else
        return .failure("Purchases are unavailable right now.")
        #endif
    }

    // MARK: - Accounts

    /// Link purchases to your own user id, so a subscription follows the user
    /// across devices and platforms. Only call this if you have real accounts,
    /// with anonymous users RevenueCat's own id is already the right identity.
    func logIn(_ appUserID: String) async {
        #if canImport(RevenueCat)
        guard AppConfig.revenueCatEnabled else { return }
        if let result = try? await Purchases.shared.logIn(appUserID) {
            apply(result.customerInfo)
        }
        #endif
    }

    /// Detach from the current user id. Call on logout.
    func logOut() async {
        #if canImport(RevenueCat)
        guard AppConfig.revenueCatEnabled else { return }
        if let info = try? await Purchases.shared.logOut() { apply(info) }
        #endif
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[subscriptions] \(message)")
        #endif
    }
}

// MARK: - Package → Plan

#if canImport(RevenueCat)
extension Subscriptions.Plan {
    init(package: Package) {
        let product = package.storeProduct
        let intro = product.introductoryDiscount
        let isFreeTrial = intro?.paymentMode == .freeTrial

        self.init(
            id: package.identifier,
            price: product.localizedPriceString,
            amount: NSDecimalNumber(decimal: product.price).doubleValue,
            currency: product.currencyCode ?? "USD",
            periodLabel: Self.label(for: package.packageType),
            trialDays: isFreeTrial ? Self.days(in : intro?.subscriptionPeriod): 0,
            isAnnual: package.packageType == .annual,
            productID: product.productIdentifier
        )
    }

    private static func label(for type: PackageType) -> String {
        switch type {
        case .annual: "Yearly"
        case .sixMonth: "6 months"
        case .threeMonth: "3 months"
        case .twoMonth: "2 months"
        case .monthly: "Monthly"
        case .weekly: "Weekly"
        case .lifetime: "Lifetime"
        default: "Plan"
        }
    }

    private static func days(in period: SubscriptionPeriod?) -> Int {
        guard let period else { return 0 }
        return switch period.unit {
        case .day: period.value
        case .week: period.value * 7
        case .month: period.value * 30
        case .year: period.value * 365
        @unknown default: 0
        }
    }
}
#endif
