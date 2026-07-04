package com.marvisociety.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import com.marvisociety.app.ui.MarviApp
import com.marvisociety.app.ui.viewmodel.AppViewModel
import com.marvisociety.app.ui.viewmodel.AppViewModelFactory

class MainActivity : ComponentActivity() {
    private val viewModel: AppViewModel by viewModels { AppViewModelFactory(application) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            MarviApp(viewModel = viewModel)
        }
    }
}
