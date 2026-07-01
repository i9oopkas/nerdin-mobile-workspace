package app.nerdin.ui.api

/**
 * Declares where a slot renders relative to its siblings within the parent slot.
 */
enum class SlotPosition {
    /** Render at the start of the parent (left in LTR) */
    START,
    /** Render in the center of the parent */
    CENTER,
    /** Render at the end of the parent (right in LTR) */
    END,
    /** Render at the top of the parent */
    TOP,
    /** Render in the middle (vertically) */
    MIDDLE,
    /** Render at the bottom of the parent */
    BOTTOM,
    /** Take the full parent slot (overrides other content) */
    FULL,
    /** Render as a floating overlay */
    OVERLAY,
    /** Render as a standalone item within a list/flow layout */
    ITEM,
}
