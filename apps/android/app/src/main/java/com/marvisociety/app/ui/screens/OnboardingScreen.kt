package com.marvisociety.app.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun OnboardingScreen(onComplete: (handle: String, city: String, inviteCode: String) -> Unit) {
    var handle by remember { mutableStateOf("@aylin.in.istanbul") }
    var city by remember { mutableStateOf("Istanbul") }
    var inviteCode by remember { mutableStateOf("MARVI-IST") }
    var error by remember { mutableStateOf("") }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text("Marvi Society", style = MaterialTheme.typography.headlineLarge)
        Text("Istanbul's private creator and venue collaboration club.")
        OutlinedTextField(value = handle, onValueChange = { handle = it }, label = { Text("Instagram") }, modifier = Modifier.fillMaxWidth())
        OutlinedTextField(value = city, onValueChange = { city = it }, label = { Text("City") }, modifier = Modifier.fillMaxWidth())
        OutlinedTextField(value = inviteCode, onValueChange = { inviteCode = it }, label = { Text("Invite code") }, modifier = Modifier.fillMaxWidth())
        if (error.isNotEmpty()) Text(error, color = MaterialTheme.colorScheme.error)
        Button(
            onClick = {
                val valid = setOf("MARVI-IST", "MARVI2026", "TSS-REF")
                if (inviteCode.uppercase() !in valid) {
                    error = "Invalid invite code. Try MARVI-IST."
                } else {
                    error = ""
                    onComplete(handle, city, inviteCode)
                }
            },
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("Enter Marvi Society")
        }
    }
}
