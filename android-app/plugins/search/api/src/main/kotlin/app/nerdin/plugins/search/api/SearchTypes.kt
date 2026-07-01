package app.nerdin.plugins.search.api

data class SearchOptions(
    val maxResults: Int = 10,
    val type: SearchType = SearchType.WEB
)

enum class SearchType { WEB, LOCAL, CODE, NEWS }

data class SearchResult(
    val query: String,
    val results: List<SearchItem> = emptyList(),
    val totalResults: Int = 0
)

data class SearchItem(
    val title: String,
    val url: String,
    val snippet: String,
    val score: Float = 0.0f
)
