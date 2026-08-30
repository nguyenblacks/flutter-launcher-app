package co.za.launcher3.swavoti

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class NotificationDotService : NotificationListenerService() {
    companion object {
        var notificationCounts: MutableMap<String, Int> = mutableMapOf()
        var listener: ((Map<String, Int>) -> Unit)? = null
    }

    override fun onListenerConnected() {
        try {
            super.onListenerConnected()
            updateNotifications()
        } catch (e: Exception) {
            // Service not ready yet — ignore
        }
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
            val counts: MutableMap<String, Int> = mutableMapOf()
            if (sbns != null) {
                for (sbn in sbns) {
                    if (sbn == null) continue
                    val pkg: String = sbn?.packageName ?: continue
                    val current: Int = counts.getOrDefault(pkg, 0)
                    counts[pkg] = current + 1
                }
            }
            notificationCounts = counts
            listener?.invoke(counts)
        } catch (e: Exception) {
            // Ignore if service not fully connected
        }
    }
}
