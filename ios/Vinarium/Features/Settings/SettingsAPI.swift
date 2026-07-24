import Foundation

enum SettingsAPI {
    static func loadChangelog() async throws -> [ChangelogVersion] {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: VinariumGraphQL.ChangelogQuery()
        )
        return data.changelog.map { entry in
            ChangelogVersion(
                version: entry.version,
                date: entry.date.flatMap { GraphQLHelpers.parseISO8601($0) },
                notes: entry.notes
            )
        }
    }

    static func loadCellarInfo() async throws -> CellarSettingsInfo {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: VinariumGraphQL.CellarInfoQuery()
        )
        let info = data.cellarInfo
        return CellarSettingsInfo(
            rows: info.rows,
            cols: info.cols,
            zones: info.zones,
            capacity: info.capacity,
            placedCount: info.placedCount
        )
    }

    static func reconfigureCellar(
        rows: Int,
        cols: Int,
        zones: Int
    ) async throws -> ReconfigureCellarOutcome {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: VinariumGraphQL.ReconfigureCellarMutation(
                rows: Int32(rows),
                cols: Int32(cols),
                zones: Int32(zones)
            )
        )
        let result = data.reconfigureCellar
        if let info = result.asCellarInfo {
            return .success(
                CellarSettingsInfo(
                    rows: info.rows,
                    cols: info.cols,
                    zones: info.zones,
                    capacity: info.capacity,
                    placedCount: info.placedCount
                )
            )
        }
        if let blocked = result.asCellarReconfigureBlocked {
            return .blocked(outOfBounds: blocked.outOfBoundsCount)
        }
        throw APIError.invalidResponse
    }

    static func exportData() async throws -> String {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: VinariumGraphQL.ExportDataQuery()
        )
        return data.exportData
    }

    static func importData(payload: String) async throws -> ImportSummary {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: VinariumGraphQL.ImportDataMutation(payload: payload)
        )
        let result = data.importData
        return ImportSummary(
            wines: result.wines,
            cellar: result.cellar,
            tasting: result.tasting,
            recommendation: result.recommendation,
            gift: result.gift,
            journal: result.journal
        )
    }

    /// Permanently delete the signed-in account and all of its data. Irreversible.
    /// The caller signs out locally afterwards to route back to the login screen.
    static func deleteAccount() async throws {
        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: VinariumGraphQL.DeleteAccountMutation()
        )
    }
}
