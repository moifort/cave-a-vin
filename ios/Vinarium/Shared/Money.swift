import Foundation

/// Prices are stored and summed in euros everywhere (the backend's canonical
/// currency): the cellar's total value, household sharing and aggregation all
/// stay correct with a single currency. Only the presentation is localized, by
/// converting the euro amount to the user's currency at display time and back to
/// euros when a price is typed in.
///
/// Wine prices are estimates, so exchange-rate drift is immaterial; the table is
/// bundled and refreshed per release rather than fetched live. A currency absent
/// from the table simply shows in euros.
enum Money {
    /// EUR -> currency multipliers. Keep EUR = 1.
    private static let ratesPerEur: [String: Double] = [
        "EUR": 1,
        "USD": 1.08,
        "GBP": 0.85,
        "JPY": 170,
        "CHF": 0.95,
        "CAD": 1.47,
        "AUD": 1.63,
    ]

    private static let symbols: [String: String] = [
        "EUR": "€", "USD": "$", "GBP": "£", "JPY": "¥", "CHF": "CHF", "CAD": "$", "AUD": "$",
    ]

    /// The currency shown to the user, from their region. Falls back to euros for
    /// any region whose currency we have no rate for.
    static var displayCurrencyCode: String {
        let code = Locale.autoupdatingCurrent.currency?.identifier ?? "EUR"
        return ratesPerEur[code] != nil ? code : "EUR"
    }

    /// The symbol for the display currency, e.g. "€", "$", "¥".
    static var displayCurrencySymbol: String {
        symbols[displayCurrencyCode] ?? "€"
    }

    /// Format an amount stored in euros into the user's display currency.
    /// `fractionLength` overrides the currency's default digit count (used for
    /// compact filter labels).
    static func formattedFromEur(_ eur: Double, fractionLength: Int? = nil) -> String {
        let code = displayCurrencyCode
        let amount = eur * (ratesPerEur[code] ?? 1)
        var style = Decimal.FormatStyle.Currency(code: code, locale: .autoupdatingCurrent)
        if let fractionLength { style = style.precision(.fractionLength(fractionLength)) }
        return Decimal(amount).formatted(style)
    }

    /// Convert an amount the user typed in their display currency back to euros
    /// for storage.
    static func toEur(_ displayAmount: Double) -> Double {
        displayAmount / (ratesPerEur[displayCurrencyCode] ?? 1)
    }

    /// Convert an amount stored in euros into the display currency, for prefilling
    /// an editable price field.
    static func fromEur(_ eur: Double) -> Double {
        eur * (ratesPerEur[displayCurrencyCode] ?? 1)
    }

    /// Prefill text for an editable price field: the display-currency amount, with
    /// its cents when it has any. `%.0f` used to round here, so opening the edit
    /// form and saving turned 12.50 into 13.
    static func editableTextFromEur(_ eur: Double) -> String {
        decimalText(fromEur(eur))
    }

    /// A number the user typed, comma or dot. The decimal pad shows whichever
    /// separator the locale uses, so a French "12,5" must not be read as no price
    /// at all — which is what `Double("12,5")` returns.
    static func number(_ typed: String) -> Double? {
        let normalized = typed
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        return normalized.isEmpty ? nil : Double(normalized)
    }

    /// Renders without trailing zeros: "12.5", "350". Not `%g`, whose six
    /// significant digits turn a four-figure bottle into "1.23457e+06".
    static func decimalText(_ value: Double) -> String {
        if value == value.rounded() { return String(format: "%.0f", value) }
        return String(format: "%.2f", value)
            .replacingOccurrences(of: "0$", with: "", options: .regularExpression)
    }
}
