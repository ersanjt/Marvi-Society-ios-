package com.marvisociety.app.ui

import android.net.Uri
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material.icons.filled.Storefront
import androidx.compose.material3.Badge
import androidx.compose.material3.BadgedBox
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.marvisociety.app.BuildConfig
import com.marvisociety.app.data.UserRole
import com.marvisociety.app.l10n.MarviL10n
import com.marvisociety.app.ui.components.BootstrapSplash
import com.marvisociety.app.ui.components.SyncErrorBanner
import com.marvisociety.app.ui.screens.AdminDashboardScreen
import com.marvisociety.app.ui.screens.ApprovalPendingScreen
import com.marvisociety.app.ui.screens.BookingsScreen
import com.marvisociety.app.ui.screens.CollaborationChatScreen
import com.marvisociety.app.ui.screens.CollaborationThreadScreen
import com.marvisociety.app.ui.screens.CommunityScreen
import com.marvisociety.app.ui.screens.ConfigurationRequiredScreen
import com.marvisociety.app.ui.screens.DirectChatScreen
import com.marvisociety.app.ui.screens.DiscoverScreen
import com.marvisociety.app.ui.screens.EstablishmentWizardScreen
import com.marvisociety.app.ui.screens.InboxScreen
import com.marvisociety.app.ui.screens.MemberProfileScreen
import com.marvisociety.app.ui.screens.OfferDetailScreen
import com.marvisociety.app.ui.screens.OnboardingScreen
import com.marvisociety.app.ui.screens.ProfileScreen
import com.marvisociety.app.ui.screens.SocialHandlesRequiredScreen
import com.marvisociety.app.ui.screens.VenueStudioScreen
import com.marvisociety.app.ui.theme.MarviColor
import com.marvisociety.app.ui.theme.MarviTheme
import com.marvisociety.app.ui.theme.TabBarBackground
import com.marvisociety.app.ui.theme.TabSelected
import com.marvisociety.app.ui.viewmodel.AppViewModel
import kotlinx.coroutines.launch

private data class TabSpec(val route: String, val labelKey: MarviL10n.Key, val icon: ImageVector)

@Composable
fun MarviApp(viewModel: AppViewModel = viewModel()) {
    MarviTheme {
        when {
            !BuildConfig.USE_REMOTE_BACKEND && !BuildConfig.DEBUG -> {
                ConfigurationRequiredScreen(viewModel)
            }
            viewModel.isBootstrapping && viewModel.isRemoteMode && !viewModel.hasCompletedOnboarding -> {
                BootstrapSplash(viewModel.t(MarviL10n.Key.LOADING_WORKSPACE))
            }
            !viewModel.hasCompletedOnboarding -> OnboardingScreen(viewModel)
            viewModel.needsSocialHandlesEntry -> SocialHandlesRequiredScreen(viewModel)
            viewModel.needsAdminApproval -> ApprovalPendingScreen(viewModel)
            viewModel.isBootstrapping -> {
                BootstrapSplash(viewModel.t(MarviL10n.Key.LOADING_WORKSPACE))
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
    val backStack by navController.currentBackStackEntryAsState()
    val currentRoute = backStack?.destination?.route.orEmpty()
    val hideBottomBar = currentRoute.startsWith("offer/") ||
        currentRoute.startsWith("member/") ||
        currentRoute.startsWith("chat/") ||
        currentRoute.startsWith("collab") ||
        currentRoute == "establishment_wizard"

    Scaffold(
        containerColor = MarviColor.Surface,
        bottomBar = {
            if (!hideBottomBar) {
                NavigationBar(containerColor = TabBarBackground, tonalElevation = 0.dp) {
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
                                when (tab.route) {
                                    "bookings" -> BadgedBox(badge = {
                                        if (viewModel.eventsTabBadgeCount > 0) {
                                            Badge(containerColor = TabSelected) {
                                                Text(viewModel.eventsTabBadgeCount.toString())
                                            }
                                        }
                                    }) { Icon(tab.icon, contentDescription = viewModel.t(tab.labelKey)) }
                                    "inbox" -> BadgedBox(badge = {
                                        if (viewModel.unreadInboxCount > 0) {
                                            Badge(containerColor = TabSelected) {
                                                Text(viewModel.unreadInboxCount.coerceAtMost(99).toString())
                                            }
                                        }
                                    }) { Icon(tab.icon, contentDescription = viewModel.t(tab.labelKey)) }
                                    else -> Icon(tab.icon, contentDescription = viewModel.t(tab.labelKey))
                                }
                            },
                            label = {
                                Text(
                                    viewModel.t(tab.labelKey),
                                    fontSize = 10.sp,
                                    fontWeight = if (viewModel.workspaceTabIndex == index) FontWeight.Bold else FontWeight.SemiBold
                                )
                            },
                            colors = NavigationBarItemDefaults.colors(
                                selectedIconColor = TabSelected,
                                selectedTextColor = TabSelected,
                                unselectedIconColor = MarviColor.Muted,
                                unselectedTextColor = MarviColor.Muted,
                                indicatorColor = TabSelected.copy(alpha = 0.12f)
                            )
                        )
                    }
                }
            }
        }
    ) { padding ->
        Column(modifier = Modifier.padding(padding)) {
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
                            navController.navigate(
                                "chat/${thread.id}/${Uri.encode(thread.peerName)}"
                            )
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
                                    navController.navigate(
                                        "chat/$threadId/${Uri.encode(member.displayName)}"
                                    )
                                }
                            }
                        },
                        onBack = { navController.popBackStack() }
                    )
                }
                composable("bookings") {
                    BookingsScreen(viewModel, onOpenMessages = { navController.navigate("collab") })
                }
                composable("collab") {
                    CollaborationChatScreen(
                        viewModel = viewModel,
                        onOpenConversation = { convo ->
                            val title = convo.title.ifBlank { "Marvi" }
                            navController.navigate("collabchat/${convo.id}/${Uri.encode(title)}")
                        },
                        onBack = { navController.popBackStack() }
                    )
                }
                composable(
                    route = "collabchat/{conversationId}/{title}",
                    arguments = listOf(
                        navArgument("conversationId") { type = NavType.StringType },
                        navArgument("title") { type = NavType.StringType }
                    )
                ) { entry ->
                    val conversationId = entry.arguments?.getString("conversationId").orEmpty()
                    val title = Uri.decode(entry.arguments?.getString("title").orEmpty())
                    CollaborationThreadScreen(conversationId, title, viewModel) { navController.popBackStack() }
                }
                composable("profile") { ProfileScreen(viewModel) }
                composable("studio") {
                    VenueStudioScreen(
                        viewModel = viewModel,
                        onAddEstablishment = { navController.navigate("establishment_wizard") }
                    )
                }
                composable("establishment_wizard") {
                    EstablishmentWizardScreen(
                        viewModel = viewModel,
                        onBack = { navController.popBackStack() },
                        onSubmitted = {
                            viewModel.refreshFromServer()
                            navController.popBackStack()
                        }
                    )
                }
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
                    val peerName = Uri.decode(entry.arguments?.getString("peerName").orEmpty())
                    DirectChatScreen(threadId, peerName, viewModel) { navController.popBackStack() }
                }
            }
        }
    }
}

private fun tabsForRole(role: UserRole): List<TabSpec> = when (role) {
    UserRole.CREATOR -> listOf(
        TabSpec("discover", MarviL10n.Key.EXPLORE, Icons.Default.AutoAwesome),
        TabSpec("community", MarviL10n.Key.COMMUNITY_TAB, Icons.Default.Groups),
        TabSpec("inbox", MarviL10n.Key.INBOX, Icons.Default.Notifications),
        TabSpec("bookings", MarviL10n.Key.MY_EVENTS, Icons.Default.CalendarMonth),
        TabSpec("profile", MarviL10n.Key.PROFILE, Icons.Default.Person)
    )
    UserRole.VENUE -> listOf(
        TabSpec("studio", MarviL10n.Key.STUDIO, Icons.Default.Storefront),
        TabSpec("community", MarviL10n.Key.COMMUNITY_TAB, Icons.Default.Groups),
        TabSpec("inbox", MarviL10n.Key.INBOX, Icons.Default.Notifications),
        TabSpec("profile", MarviL10n.Key.ACCOUNT, Icons.Default.Person)
    )
    UserRole.ADMIN -> listOf(
        TabSpec("admin", MarviL10n.Key.ADMIN, Icons.Default.Shield),
        TabSpec("inbox", MarviL10n.Key.INBOX, Icons.Default.Notifications),
        TabSpec("profile", MarviL10n.Key.ACCOUNT, Icons.Default.Person)
    )
}
