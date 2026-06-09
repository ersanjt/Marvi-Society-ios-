package com.marvisociety.app.ui

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.marvisociety.app.ui.screens.BookingsScreen
import com.marvisociety.app.ui.screens.DiscoverScreen
import com.marvisociety.app.ui.screens.MapScreen
import com.marvisociety.app.ui.screens.OnboardingScreen
import com.marvisociety.app.ui.screens.ProfileScreen
import com.marvisociety.app.ui.theme.MarviTheme
import com.marvisociety.app.ui.viewmodel.AppViewModel

sealed class MarviTab(val route: String, val label: String) {
    data object Discover : MarviTab("discover", "Discover")
    data object Nearby : MarviTab("nearby", "Nearby")
    data object Bookings : MarviTab("bookings", "Bookings")
    data object Profile : MarviTab("profile", "Profile")
}

@Composable
fun MarviApp(viewModel: AppViewModel = viewModel()) {
    MarviTheme {
        if (!viewModel.hasCompletedOnboarding) {
            OnboardingScreen(onComplete = viewModel::completeOnboarding)
            return
        }

        val navController = rememberNavController()
        val tabs = listOf(MarviTab.Discover, MarviTab.Nearby, MarviTab.Bookings, MarviTab.Profile)
        val navBackStackEntry by navController.currentBackStackEntryAsState()
        val currentDestination = navBackStackEntry?.destination

        Scaffold(
            bottomBar = {
                NavigationBar {
                    tabs.forEach { tab ->
                        NavigationBarItem(
                            icon = {
                                Icon(
                                    imageVector = when (tab) {
                                        MarviTab.Discover -> Icons.Default.Search
                                        MarviTab.Nearby -> Icons.Default.Map
                                        MarviTab.Bookings -> Icons.Default.CalendarMonth
                                        MarviTab.Profile -> Icons.Default.Person
                                    },
                                    contentDescription = tab.label
                                )
                            },
                            label = { Text(tab.label) },
                            selected = currentDestination?.hierarchy?.any { it.route == tab.route } == true,
                            onClick = {
                                navController.navigate(tab.route) {
                                    popUpTo(navController.graph.findStartDestination().id) { saveState = true }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            }
                        )
                    }
                }
            }
        ) { innerPadding ->
            NavHost(
                navController = navController,
                startDestination = MarviTab.Discover.route,
                modifier = Modifier.padding(innerPadding)
            ) {
                composable(MarviTab.Discover.route) { DiscoverScreen(viewModel) }
                composable(MarviTab.Nearby.route) { MapScreen(viewModel) }
                composable(MarviTab.Bookings.route) { BookingsScreen(viewModel) }
                composable(MarviTab.Profile.route) { ProfileScreen(viewModel) }
            }
        }
    }
}
