import Foundation

/// Thin client for the parts of TMDb's v3 API this app needs: browsable
/// "popular"/"top rated"/"trending" lists for movies and TV, plus resolving
/// each result's IMDb ID so it can be matched against Stremio addon streams
/// (which key everything off IMDb-style "tt..." ids).
enum TMDbAPI {
    private static let base = "https://api.themoviedb.org/3"
    private static let imageBase = "https://image.tmdb.org/t/p/w780"

    private struct ListResponse: Codable {
        let results: [RawItem]
    }

    private struct TrendingResponse: Codable {
        let results: [RawItem]
    }

    private struct RawItem: Codable {
        let id: Int
        let title: String?
        let name: String?
        let overview: String?
        let posterPath: String?
        let backdropPath: String?
        let mediaType: String?

        enum CodingKeys: String, CodingKey {
            case id, title, name, overview
            case posterPath = "poster_path"
            case backdropPath = "backdrop_path"
            case mediaType = "media_type"
        }
    }

    private struct ExternalIDs: Codable {
        let imdbId: String?
        enum CodingKeys: String, CodingKey { case imdbId = "imdb_id" }
    }

    enum MediaKind: String {
        case movie
        case tv

        /// The `type` value Stremio addons expect.
        var stremioType: String { self == .movie ? "movie" : "series" }
    }

    private static func url(_ path: String, query: [String: String] = [:]) -> URL? {
        var components = URLComponents(string: base + path)
        var items = [URLQueryItem(name: "api_key", value: TMDbSecrets.apiKey)]
        items += query.map { URLQueryItem(name: $0.key, value: $0.value) }
        components?.queryItems = items
        return components?.url
    }

    /// Fetches a list (popular/top_rated) and resolves each item's IMDb ID
    /// concurrently, returning ready-to-display MetaPreviews.
    private static func fetchList(path: String, kind: MediaKind, limit: Int = 15) async -> [MetaPreview] {
        guard !TMDbSecrets.apiKey.isEmpty, let listURL = url(path) else { return [] }
        guard let (data, _) = try? await URLSession.shared.data(from: listURL),
              let decoded = try? JSONDecoder().decode(ListResponse.self, from: data) else { return [] }

        let items = Array(decoded.results.prefix(limit))
        return await withTaskGroup(of: MetaPreview?.self) { group in
            for item in items {
                group.addTask { await preview(for: item, kind: kind) }
            }
            var results: [MetaPreview] = []
            for await item in group {
                if let item { results.append(item) }
            }
            return results
        }
    }

    static func fetchTrending(limit: Int = 15) async -> [MetaPreview] {
        guard !TMDbSecrets.apiKey.isEmpty, let listURL = url("/trending/all/week") else { return [] }
        guard let (data, _) = try? await URLSession.shared.data(from: listURL),
              let decoded = try? JSONDecoder().decode(TrendingResponse.self, from: data) else { return [] }

        let items = Array(decoded.results.prefix(limit))
        return await withTaskGroup(of: MetaPreview?.self) { group in
            for item in items {
                let kind: MediaKind = item.mediaType == "tv" ? .tv : .movie
                group.addTask { await preview(for: item, kind: kind) }
            }
            var results: [MetaPreview] = []
            for await item in group {
                if let item { results.append(item) }
            }
            return results
        }
    }

    static func popularMovies(limit: Int = 15) async -> [MetaPreview] {
        await fetchList(path: "/movie/popular", kind: .movie, limit: limit)
    }

    static func topRatedMovies(limit: Int = 15) async -> [MetaPreview] {
        await fetchList(path: "/movie/top_rated", kind: .movie, limit: limit)
    }

    static func popularSeries(limit: Int = 15) async -> [MetaPreview] {
        await fetchList(path: "/tv/popular", kind: .tv, limit: limit)
    }

    static func topRatedSeries(limit: Int = 15) async -> [MetaPreview] {
        await fetchList(path: "/tv/top_rated", kind: .tv, limit: limit)
    }

    static func search(query: String, limit: Int = 20) async -> [MetaPreview] {
        guard !TMDbSecrets.apiKey.isEmpty, !query.isEmpty,
              let searchURL = url("/search/multi", query: ["query": query]) else { return [] }
        guard let (data, _) = try? await URLSession.shared.data(from: searchURL),
              let decoded = try? JSONDecoder().decode(ListResponse.self, from: data) else { return [] }

        let items = decoded.results
            .filter { $0.mediaType == "movie" || $0.mediaType == "tv" }
            .prefix(limit)
        return await withTaskGroup(of: MetaPreview?.self) { group in
            for item in items {
                let kind: MediaKind = item.mediaType == "tv" ? .tv : .movie
                group.addTask { await preview(for: item, kind: kind) }
            }
            var results: [MetaPreview] = []
            for await item in group {
                if let item { results.append(item) }
            }
            return results
        }
    }

    private static func preview(for item: RawItem, kind: MediaKind) async -> MetaPreview? {
        guard let imdbId = await externalIDs(id: item.id, kind: kind) else { return nil }
        let poster = item.posterPath.map { imageBase + $0 }
        let backdrop = item.backdropPath.map { imageBase + $0 }
        return MetaPreview(
            id: imdbId,
            type: kind.stremioType,
            name: item.title ?? item.name ?? "Untitled",
            poster: poster,
            background: backdrop ?? poster,
            description: item.overview
        )
    }

    private static func externalIDs(id: Int, kind: MediaKind) async -> String? {
        guard let idsURL = url("/\(kind.rawValue)/\(id)/external_ids") else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: idsURL),
              let decoded = try? JSONDecoder().decode(ExternalIDs.self, from: data) else { return nil }
        return decoded.imdbId
    }

    // MARK: - Detail enrichment (rating, age rating, genres, runtime, cast)

    struct ExtraDetails {
        let rating: Double?
        let certification: String?
        let genres: [String]
        let runtimeMinutes: Int?
        let cast: [String]
    }

    private struct FindResponse: Codable {
        let movieResults: [RawItem]
        let tvResults: [RawItem]
        enum CodingKeys: String, CodingKey {
            case movieResults = "movie_results"
            case tvResults = "tv_results"
        }
    }

    private struct Genre: Codable { let name: String }

    private struct MovieDetails: Codable {
        let genres: [Genre]?
        let voteAverage: Double?
        let runtime: Int?
        let releaseDates: ReleaseDates?
        enum CodingKeys: String, CodingKey {
            case genres
            case voteAverage = "vote_average"
            case runtime
            case releaseDates = "release_dates"
        }
    }

    private struct ReleaseDates: Codable { let results: [ReleaseDatesCountry] }
    private struct ReleaseDatesCountry: Codable {
        let iso31661: String
        let releaseDates: [ReleaseDateEntry]
        enum CodingKeys: String, CodingKey {
            case iso31661 = "iso_3166_1"
            case releaseDates = "release_dates"
        }
    }
    private struct ReleaseDateEntry: Codable { let certification: String }

    private struct TVDetails: Codable {
        let genres: [Genre]?
        let voteAverage: Double?
        let episodeRunTime: [Int]?
        let contentRatings: ContentRatings?
        enum CodingKeys: String, CodingKey {
            case genres
            case voteAverage = "vote_average"
            case episodeRunTime = "episode_run_time"
            case contentRatings = "content_ratings"
        }
    }
    private struct ContentRatings: Codable { let results: [ContentRatingCountry] }
    private struct ContentRatingCountry: Codable {
        let iso31661: String
        let rating: String
        enum CodingKeys: String, CodingKey {
            case iso31661 = "iso_3166_1"
            case rating
        }
    }

    private struct Credits: Codable { let cast: [CastMember]? }
    private struct CastMember: Codable { let name: String }

    /// Resolves a TMDb-internal id for an IMDb id via the `/find` endpoint,
    /// then fetches full details (rating, certification, genres, runtime)
    /// plus top-billed cast, concurrently.
    static func fetchExtraDetails(imdbId: String, type: String) async -> ExtraDetails? {
        guard !TMDbSecrets.apiKey.isEmpty, imdbId.hasPrefix("tt"),
              let findURL = url("/find/\(imdbId)", query: ["external_source": "imdb_id"]) else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: findURL),
              let found = try? JSONDecoder().decode(FindResponse.self, from: data) else { return nil }

        let kind: MediaKind = type == "series" ? .tv : .movie
        guard let match = (kind == .tv ? found.tvResults.first : found.movieResults.first) else { return nil }

        async let detailsTask = fetchDetails(id: match.id, kind: kind)
        async let castTask = fetchCast(id: match.id, kind: kind)
        let details = await detailsTask
        let cast = await castTask
        guard let details else { return nil }
        return ExtraDetails(
            rating: details.rating,
            certification: details.certification,
            genres: details.genres,
            runtimeMinutes: details.runtimeMinutes,
            cast: cast
        )
    }

    private static func fetchCast(id: Int, kind: MediaKind) async -> [String] {
        guard let creditsURL = url("/\(kind.rawValue)/\(id)/credits") else { return [] }
        guard let (data, _) = try? await URLSession.shared.data(from: creditsURL),
              let decoded = try? JSONDecoder().decode(Credits.self, from: data) else { return [] }
        return (decoded.cast ?? []).prefix(6).map(\.name)
    }

    private static func fetchDetails(id: Int, kind: MediaKind) async -> ExtraDetails? {
        if kind == .movie {
            guard let detailsURL = url("/movie/\(id)", query: ["append_to_response": "release_dates"]) else { return nil }
            guard let (data, _) = try? await URLSession.shared.data(from: detailsURL),
                  let decoded = try? JSONDecoder().decode(MovieDetails.self, from: data) else { return nil }
            let certification = decoded.releaseDates?.results
                .first(where: { $0.iso31661 == "US" })?
                .releaseDates.first(where: { !$0.certification.isEmpty })?.certification
            return ExtraDetails(
                rating: decoded.voteAverage,
                certification: certification,
                genres: (decoded.genres ?? []).map(\.name),
                runtimeMinutes: decoded.runtime,
                cast: []
            )
        } else {
            guard let detailsURL = url("/tv/\(id)", query: ["append_to_response": "content_ratings"]) else { return nil }
            guard let (data, _) = try? await URLSession.shared.data(from: detailsURL),
                  let decoded = try? JSONDecoder().decode(TVDetails.self, from: data) else { return nil }
            let certification = decoded.contentRatings?.results.first(where: { $0.iso31661 == "US" })?.rating
            return ExtraDetails(
                rating: decoded.voteAverage,
                certification: certification,
                genres: (decoded.genres ?? []).map(\.name),
                runtimeMinutes: decoded.episodeRunTime?.first,
                cast: []
            )
        }
    }
}
