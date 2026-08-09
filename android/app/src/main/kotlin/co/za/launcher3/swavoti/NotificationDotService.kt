package co.za.launcher3.swavoti

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class NotificationDotService : NotificationListenerService() {
    companion object {
        var activeNotifications: MutableMap<String, Int> = mutableMapOf()
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
            val sbns: Array<StatusBarNotification> = getActiveNotifications() ?: emptyArray()
            val counts: MutableMap<String, Int> = mutableMapOf()
            for (sbn in sbns) {
                val pkg: String = sbn.packageName ?: continue
                val current: Int = counts.getOrDefault(pkg, 0)
                counts[pkg] = current + 1
            }
            activeNotifications = counts
            listener?.invoke(counts)
        } catch (e: Exception) {
            // Ignore if service not fully connected
        }
    }
}
