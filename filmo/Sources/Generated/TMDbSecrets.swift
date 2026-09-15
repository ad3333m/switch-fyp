// This file is overwritten at CI build time from the TMDB_API_KEY GitHub
// Actions secret (see .github/workflows/build-ios.yml) - the real key is
// never committed to source control. This placeholder keeps local builds
// (outside CI) compiling; TMDb calls will simply fail gracefully with an
// empty key until you fill one in locally for development.
enum TMDbSecrets {
    static let apiKey = ""
}
