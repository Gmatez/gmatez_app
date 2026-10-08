package com.gmatez.gmatez_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

class CallForegroundService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return if (intent?.action == ACTION_START) {
            startInForeground()
            START_STICKY
        } else {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            running = false
            START_NOT_STICKY
        }
    }

    private fun startInForeground() {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            manager.getNotificationChannel(CHANNEL_ID) == null
        ) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Calls",
                NotificationManager.IMPORTANCE_LOW,
            )
            channel.setSound(null, null)
            channel.enableVibration(false)
            manager.createNotificationChannel(channel)
        }

        val openApp = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_call)
            .setContentTitle("Gmatez call")
            .setContentText("Call in progress")
            .setOngoing(true)
            .setContentIntent(openApp)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE or
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        running = true
    }

    companion object {
        private const val ACTION_START = "com.gmatez.gmatez_app.CALL_AUDIO_START"
        private const val ACTION_STOP = "com.gmatez.gmatez_app.CALL_AUDIO_STOP"
        private const val CHANNEL_ID = "gmatez_call"
        private const val NOTIFICATION_ID = 4101
        private var running = false
        private var requested = false

        fun start(context: Context) {
            if (requested) {
                return
            }
            requested = true
            val intent = Intent(context, CallForegroundService::class.java)
            intent.action = ACTION_START
            ContextCompat.startForegroundService(context, intent)
        }

        fun stop(context: Context) {
            if (!requested && !running) {
                return
            }
            requested = false
            running = false
            val intent = Intent(context, CallForegroundService::class.java)
            intent.action = ACTION_STOP
            context.startService(intent)
        }
    }
}
