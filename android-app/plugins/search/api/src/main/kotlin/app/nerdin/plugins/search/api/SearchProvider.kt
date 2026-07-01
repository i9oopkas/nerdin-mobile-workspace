package app.nerdin.plugins.search.api

import app.nerdin.core.api.NerdinService

interface SearchProvider : NerdinService {
    suspend fun search(query: String, options: SearchOptions = SearchOptions()): SearchResult
}
