import Foundation

extension Wine {
    /// Maps the shared `WineListFields` fragment (used by the wine list and the
    /// global search) into the domain model. Single source of truth so both
    /// query paths stay in sync.
    init(listFields w: VinariumGraphQL.WineListFields) {
        // Wine-only fields now live under the `details` union member.
        let details = w.details?.asWineDetails
        self.init(
            id: w.id,
            name: w.name,
            beverageType: BeverageType(graphql: w.beverageType),
            color: details?.color.map { WineColor(graphql: $0) },
            subtype: w.subtype.flatMap { BeverageSubtype(graphql: $0) },
            domain: w.producer,
            vintage: details?.vintage,
            appellation: details?.appellation,
            region: w.region,
            country: w.country,
            grapeVarieties: details?.grapeVarieties,
            alcoholContent: w.alcoholContent,
            classification: details?.classification,
            purchasePrice: w.purchase?.price,
            purchaseDate: w.purchase?.date,
            drinkFrom: details?.drinkWindow?.from,
            drinkUntil: details?.drinkWindow?.until,
            notes: w.notes,
            giftedBy: w.gift?.received?.from,
            rating: w.consumption?.rating,
            isFavorite: w.consumption?.favorite ?? false,
            giftedTo: w.gift?.given?.recipientName,
            recommendedBy: w.recommendation?.recommenderName,
            contacts: w.consumption?.contacts,
            latitude: w.place?.latitude,
            longitude: w.place?.longitude,
            placeName: w.place?.name,
            isInCellar: w.cellar != nil,
            consumedDate: w.consumption?.consumedDate.flatMap { GraphQLHelpers.parseISO8601($0) },
            // The gifted view means gifts received, carried by the gift's received
            // facet (the given facet stands for a wine handed to someone else).
            isGifted: w.gift?.received != nil,
            isRecommended: w.recommendation != nil,
            ownerName: w.ownerName,
            createdAt: GraphQLHelpers.parseISO8601(w.createdAt) ?? Date(),
            updatedAt: GraphQLHelpers.parseISO8601(w.updatedAt) ?? Date()
        )
    }
}
