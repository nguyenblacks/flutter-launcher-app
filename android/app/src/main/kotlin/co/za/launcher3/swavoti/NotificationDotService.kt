package co.za.launcher3.swavoti

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class NotificationDotService : NotificationListenerService() {
    companion object {
        var activeNotifications = mutableMapOf<String, Int>()
        var listener: ((Map<String, Int>) -> Unit)? = null
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        updateNotifications()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        updateNotifications()
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        updateNotifications()
    }

    private fun updateNotifications() {
        try {
            val sbns = getActiveNotifications()
            activeNotifications.clear()
            for (sbn in sbns) {
                val pkg = sbn.packageName
                activeNotifications[pkg] = (activeNotifications[pkg] ?: 0) + 1
            }
            listener?.invoke(activeNotifications)
        } catch (e: Exception) {
            // Ignore if service not fully connected
        }
    }
}
