package app.nerdin.core.api

/**
 * Semantic Version (major.minor.patch).
 */
data class Version(
    val major: Int,
    val minor: Int,
    val patch: Int
) : Comparable<Version> {

    override fun compareTo(other: Version): Int {
        return compareValuesBy(this, other,
            { it.major },
            { it.minor },
            { it.patch }
        )
    }

    fun isCompatibleWith(min: Version, max: Version?): Boolean {
        return this >= min && (max == null || this <= max)
    }

    override fun toString(): String = "$major.$minor.$patch"

    companion object {
        val ZERO = Version(0, 0, 0)

        fun parse(s: String): Version {
            val parts = s.split(".")
            require(parts.size == 3) { "Invalid version string: $s" }
            return Version(
                major = parts[0].toInt(),
                minor = parts[1].toInt(),
                patch = parts[2].toInt()
            )
        }
    }
}
