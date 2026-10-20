package net.volgatech.volgatech_pro

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.provider.CalendarContract
import android.provider.ContactsContract
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// What the mail reader hands to other apps (lib/mail/text_intents.dart):
/// a contact to add, an event for the calendar, text to translate. Each
/// opens the other app's own form, so nothing is saved without the user.
object TextIntents {
    fun handle(activity: Activity, call: MethodCall, result: MethodChannel.Result) {
        val intent = when (call.method) {
            "addContact" -> Intent(ContactsContract.Intents.Insert.ACTION).apply {
                type = ContactsContract.RawContacts.CONTENT_TYPE
                call.argument<String>("name")?.let {
                    putExtra(ContactsContract.Intents.Insert.NAME, it)
                }
                call.argument<String>("email")?.let {
                    putExtra(ContactsContract.Intents.Insert.EMAIL, it)
                }
                call.argument<String>("phone")?.let {
                    putExtra(ContactsContract.Intents.Insert.PHONE, it)
                }
            }
            "addEvent" -> Intent(Intent.ACTION_INSERT).apply {
                data = CalendarContract.Events.CONTENT_URI
                putExtra(CalendarContract.Events.TITLE, call.argument<String>("title"))
                putExtra(CalendarContract.Events.DESCRIPTION, call.argument<String>("description"))
                putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, call.argument<Number>("begin")?.toLong() ?: 0L)
                putExtra(CalendarContract.EXTRA_EVENT_END_TIME, call.argument<Number>("end")?.toLong() ?: 0L)
                putExtra(CalendarContract.EXTRA_EVENT_ALL_DAY, call.argument<Boolean>("allDay") ?: false)
            }
            "translate" -> {
                val text = Intent(Intent.ACTION_PROCESS_TEXT).apply {
                    type = "text/plain"
                    putExtra(Intent.EXTRA_PROCESS_TEXT, call.argument<String>("text"))
                    putExtra(Intent.EXTRA_PROCESS_TEXT_READONLY, true)
                }
                // No translator installed: the caller shares the text instead.
                if (activity.packageManager.queryIntentActivities(text, 0).isEmpty()) {
                    result.success(false)
                    return
                }
                Intent.createChooser(text, "Перевести")
            }
            else -> {
                result.notImplemented()
                return
            }
        }
        try {
            activity.startActivity(intent)
            result.success(true)
        } catch (e: ActivityNotFoundException) {
            result.success(false)
        }
    }
}
