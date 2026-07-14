package com.marvisociety.app.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material.icons.filled.Storefront
import androidx.compose.material3.Badge
import androidx.compose.material3.BadgedBox
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.marvisociety.app.BuildConfig
import com.marvisociety.app.data.UserRole
import com.marvisociety.app.l10n.MarviL10n
import com.marvisociety.app.ui.components.SyncErrorBanner
import com.marvisociety.app.ui.screens.AdminDashboardScreen
import com.marvisociety.app.ui.screens.BookingsScreen
import com.marvisociety.app.ui.screens.CommunityScreen
import com.marvisociety.app.ui.screens.ConfigurationRequiredScreen
import com.marvisociety.app.ui.screens.DirectChatScreen
import com.marvisociety.app.ui.screens.DiscoverScreen
import com.marvisociety.app.ui.screens.InboxScreen
import com.marvisociety.app.ui.screens.MemberProfileScreen
import com.marvisociety.app.ui.screens.OfferDetailScreen
import com.marvisociety.app.ui.screens.OnboardingScreen
import com.marvisociety.app.ui.screens.ProfileScreen
import com.marvisociety.app.ui.screens.ApprovalPendingScreen
import com.marvisociety.app.ui.screens.SocialHandlesRequiredScreen
import com.marvisociety.app.ui.screens.VenueStudioScreen
import com.marvisociety.app.ui.theme.MarviColor
import com.marvisociety.app.ui.theme.MarviTheme
import com.marvisociety.app.ui.viewmodel.AppViewModel
import kotlinx.coroutines.launch

private data class TabSpec(val route: String, val labelKey: MarviL10n.Key, val icon: @Composable () -> Unit)

@Composable
fun MarviApp(viewModel: AppViewModel = viewModel()) {
    MarviTheme {
        when {
            !BuildConfig.USE_REMOTE_BACKEND && !BuildConfig.DEBUG -> {
                ConfigurationRequiredScreen(viewModel)
            }
            viewModel.isBootstrapping && viewModel.isRemoteMode && !viewModel.hasCompletedOnboarding -> {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = MarviColor.Rose)
                }
            }
            !viewModel.hasCompletedOnboarding -> OnboardingScreen(viewModel)
            // Match iOS ContentView gate order
            viewModel.needsSocialHandlesEntry -> SocialHandlesRequiredScreen(viewModel)
            viewModel.needsAdminApproval -> ApprovalPendingScreen(viewModel)
            viewModel.isBootstrapping -> {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = MarviColor.Rose)
                }
            }
            else -> MainShell(viewModel)
        }
    }
}

@Composable
private fun MainShell(viewModel: AppViewModel) {
    val navController = rememberNavController()
    val scope = rememberCoroutineScope()
    val tabs = tabsForRole(viewModel.selectedRole)

    Scaffold(
        bottomBar = {
            NavigationBar(containerColor = MarviColor.Panel) {
                tabs.forEachIndexed { index, tab ->
                    NavigationBarItem(
                        selected = viewModel.workspaceTabIndex == index,
                        onClick = {
                            viewModel.setWorkspaceTab(index)
                            navController.navigate(tab.route) {
                                popUpTo(navController.graph.startDestinationId) { saveState = true }
                                launchSingleTop = true
                                restoreState = true
                            }
                        },
                        icon = {
                            if (tab.route == "bookings" || tab.route == "inbox") {
                                BadgedBox(badge = {
                                    if (viewModel.unreadInboxCount > 0) {
                                        Badge { Text(viewModel.unreadInboxCount.toString()) }
                                    }
                                }) { tab.icon() }
                            } else {
                                tab.icon()
                            }
                        },
                        label = { Text(viewModel.t(tab.labelKey)) },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = MarviColor.Rose,
                            selectedTextColor = MarviColor.Rose,
                            unselectedIconColor = MarviColor.Muted,
                            unselectedTextColor = MarviColor.Muted,
                            indicatorColor = MarviColor.Rose.copy(alpha = 0.12f)
                        )
                    )
                }
            }
        }
    ) { padding ->
        androidx.compose.foundation.layout.Column(modifier = Modifier.padding(padding)) {
            viewModel.lastSyncError?.let { error ->
                SyncErrorBanner(
                    message = error,
                    retryTitle = viewModel.t(MarviL10n.Key.RETRY),
                    onRetry = { viewModel.refreshFromServer() },
                    onDismiss = { viewModel.dismissSyncError() }
                )
            }

            NavHost(
                navController = navController,
                startDestination = tabs.first().route
            ) {
                composable("discover") {
                    DiscoverScreen(viewModel) { offer ->
                        navController.navigate("offer/${offer.id}")
                    }
                }
                composable("community") {
                    CommunityScreen(
                        viewModel,
                        onOpenMember = { member ->
                            navController.navigate("member/${member.id}")
                        },
                        onOpenThread = { thread ->
                            navController.navigate("chat/${thread.id}/${thread.peerName}")
                        }
                    )
                }
                composable(
                    route = "member/{memberId}",
                    arguments = listOf(navArgument("memberId") { type = NavType.StringType })
                ) { entry ->
                    val memberId = entry.arguments?.getString("memberId").orEmpty()
                    val member = viewModel.memberSearchResults.find { it.id == memberId }
                        ?: com.marvisociety.app.data.MemberSearchResult(
                            id = memberId,
                            userId = memberId,
                            displayName = "Member",
                            handle = "",
                            city = "",
                            avatarUrl = null,
                            isVenue = false,
                            isFollowing = false
                        )
                    MemberProfileScreen(
                        member = member,
                        viewModel = viewModel,
                        onMessage = { peerId ->
                            scope.launch {
                                runCatching {
                                    val threadId = viewModel.openDirectThread(peerId)
                                    navController.navigate("chat/$threadId/${member.displayName}")
                                }
                            }
                        },
                        onBack = { navController.popBackStack() }
                    )
                }
                composable("bookings") { BookingsScreen(viewModel) }
                composable("profile") { ProfileScreen(viewModel) }
                composable("studio") { VenueStudioScreen(viewModel) }
                composable("inbox") { InboxScreen(viewModel) }
                composable("admin") { AdminDashboardScreen(viewModel) }
                composable(
                    route = "offer/{offerId}",
                    arguments = listOf(navArgument("offerId") { type = NavType.StringType })
                ) { entry ->
                    val offerId = entry.arguments?.getString("offerId")
                    val offer = viewModel.offers.find { it.id == offerId }
                    if (offer != null) {
                        OfferDetailScreen(offer, viewModel) { navController.popBackStack() }
                    }
                }
                composable(
                    route = "chat/{threadId}/{peerName}",
                    arguments = listOf(
                        navArgument("threadId") { type = NavType.StringType },
                        navArgument("peerName") { type = NavType.StringType }
                    )
                ) { entry ->
                    val threadId = entry.arguments?.getString("threadId").orEmpty()
                    val peerName = entry.arguments?.getString("peerName").orEmpty()
                    DirectChatScreen(threadId, peerName, viewModel) { navController.popBackStack() }
                }
            }
        }
    }
}

private fun tabsForRole(role: UserRole): List<TabSpec> = when (role) {
    UserRole.CREATOR -> listOf(
        TabSpec("discover", MarviL10n.Key.EXPLORE) { Icon(Icons.Default.Search, null) },
        TabSpec("community", MarviL10n.Key.COMMUNITY_TAB) { Icon(Icons.Default.Groups, null) },
        TabSpec("bookings", MarviL10n.Key.MY_EVENTS) { Icon(Icons.Default.CalendarMonth, null) },
        TabSpec("profile", MarviL10n.Key.PROFILE) { Icon(Icons.Default.Person, null) }
    )
    UserRole.VENUE -> listOf(
        TabSpec("studio", MarviL10n.Key.STUDIO) { Icon(Icons.Default.Storefront, null) },
        TabSpec("community", MarviL10n.Key.COMMUNITY_TAB) { Icon(Icons.Default.Groups, null) },
        TabSpec("inbox", MarviL10n.Key.INBOX) { Icon(Icons.Default.Notifications, null) },
        TabSpec("profile", MarviL10n.Key.ACCOUNT) { Icon(Icons.Default.Person, null) }
    )
    UserRole.ADMIN -> listOf(
        TabSpec("admin", MarviL10n.Key.ADMIN) { Icon(Icons.Default.Shield, null) },
        TabSpec("inbox", MarviL10n.Key.INBOX) { Icon(Icons.Default.Notifications, null) },
        TabSpec("profile", MarviL10n.Key.ACCOUNT) { Icon(Icons.Default.Person, null) }
    )
}
