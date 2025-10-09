package com.flockbusiness

import io.flutter.embedding.android.FlutterActivity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import androidx.core.app.NotificationManagerCompat

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "flock_channel",
                "Flock Notifications",
                NotificationManager.IMPORTANCE_DEFAULT
            )
            val manager = NotificationManagerCompat.from(this)
            manager.createNotificationChannel(channel)
        }
    }
}