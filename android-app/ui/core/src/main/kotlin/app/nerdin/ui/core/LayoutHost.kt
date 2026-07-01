package app.nerdin.ui.core

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Chat
import androidx.compose.material.icons.outlined.Folder
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import app.nerdin.ui.api.LayoutRegistry
import app.nerdin.ui.api.SlotContainer
import app.nerdin.ui.api.UiSlot
import app.nerdin.ui.api.SlotPosition

/** Bottom navigation tabs */
enum class ScreenTab(val label: String, val icon: @Composable () -> Unit) {
    CHAT("Chat", { Icon(Icons.Outlined.Chat, contentDescription = "Chat") }),
    WORKSPACE("Workspace", { Icon(Icons.Outlined.Folder, contentDescription = "Workspace") }),
    SETTINGS("Settings", { Icon(Icons.Outlined.Settings, contentDescription = "Settings") })
}

/** The content composable for each screen tab */
@Composable
fun ScreenContent(tab: ScreenTab, layoutRegistry: LayoutRegistry) {
    when (tab) {
        ScreenTab.CHAT -> SlotContainer("main.content.chat", single = true, layoutRegistry = layoutRegistry)
        ScreenTab.WORKSPACE -> SlotContainer("main.content.workspace", single = true, layoutRegistry = layoutRegistry)
        ScreenTab.SETTINGS -> SlotContainer("main.content.settings", single = true, layoutRegistry = layoutRegistry)
    }
}

/**
 * Root composable of the Nerdin app.
 * Defines the built-in slot structure and renders the layout.
 *
 * Slot tree:
 * - topbar.start   (default: nothing)
 * - topbar.center  (default: "Nerdin" title)
 * - topbar.end     (default: nothing — plugins add buttons here)
 * - main.content   (default: agent chat screen)
 * - main.content.chat
 * - main.content.workspace
 * - main.content.settings
 * - main.sidebar   (default: hidden, plugins can add panels)
 * - bottom.nav     (default: bottom tab bar)
 * - bottom.status  (default: nothing)
 */
@Composable
@OptIn(ExperimentalMaterial3Api::class)
fun LayoutHost(
    layoutRegistry: LayoutRegistry,
    agentScreen: @Composable () -> Unit = {},
    workspaceScreen: @Composable () -> Unit = {},
    settingsScreen: @Composable () -> Unit = {},
) {
    var selectedTab by remember { mutableIntStateOf(0) }

    // Register built-in slots once
    DisposableEffect(Unit) {
        layoutRegistry.registerBuiltInSlots(
            listOf(
                UiSlot("topbar.start", null, SlotPosition.START, "TopBar Start"),
                UiSlot("topbar.center", null, SlotPosition.CENTER, "TopBar Center"),
                UiSlot("topbar.end", null, SlotPosition.END, "TopBar End"),
                UiSlot("main.content", null, SlotPosition.FULL, "Main Content"),
                UiSlot("main.content.chat", "main.content", SlotPosition.FULL, "Chat Screen"),
                UiSlot("main.content.workspace", "main.content", SlotPosition.FULL, "Workspace Screen"),
                UiSlot("main.content.settings", "main.content", SlotPosition.FULL, "Settings Screen"),
                UiSlot("main.sidebar", null, SlotPosition.START, "Sidebar"),
                UiSlot("bottom.nav", null, SlotPosition.BOTTOM, "Bottom Navigation"),
                UiSlot("bottom.status", null, SlotPosition.BOTTOM, "Status Bar"),
            )
        )
        onDispose { }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    SlotContainer("topbar.center", layoutRegistry = layoutRegistry)
                },
                navigationIcon = {
                    SlotContainer("topbar.start", layoutRegistry = layoutRegistry)
                },
                actions = {
                    SlotContainer("topbar.end", layoutRegistry = layoutRegistry)
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface,
                    titleContentColor = MaterialTheme.colorScheme.onSurface,
                )
            )
        },
        bottomBar = {
            Column {
                // Status bar
                SlotContainer("bottom.status", layoutRegistry = layoutRegistry)

                // Navigation
                if (!layoutRegistry.hasContent("bottom.nav")) {
                    // Default bottom navigation
                    NavigationBar {
                        ScreenTab.entries.forEachIndexed { index, tab ->
                            NavigationBarItem(
                                selected = selectedTab == index,
                                onClick = { selectedTab = index },
                                icon = { tab.icon() },
                                label = { Text(tab.label) }
                            )
                        }
                    }
                } else {
                    // Plugin-provided navigation
                    SlotContainer("bottom.nav", layoutRegistry = layoutRegistry)
                }
            }
        }
    ) { padding ->
        Row(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            // Sidebar (collapsible)
            val hasSidebar = layoutRegistry.hasContent("main.sidebar")
            if (hasSidebar) {
                SlotContainer("main.sidebar", layoutRegistry = layoutRegistry)
            }

            // Main content by selected tab
            when (selectedTab) {
                0 -> agentScreen()
                1 -> workspaceScreen()
                2 -> settingsScreen()
            }
        }
    }
}
