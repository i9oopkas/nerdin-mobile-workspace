package app.nerdin.core.api

/**
 * Base interface for all events flowing through the Nerdin event bus.
 * Events are published via [PluginContext.publishEvent] and can be subscribed
 * to via [PluginContext.subscribe].
 */
interface NerdinEvent
