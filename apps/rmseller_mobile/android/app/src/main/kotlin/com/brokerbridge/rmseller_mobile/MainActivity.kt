package com.brokerbridge.rmseller_mobile

import android.app.Activity
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.provider.ContactsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.brokerbridge.rmseller/contacts"
    private var pendingResult: MethodChannel.Result? = null
    private val REQUEST_CODE_PICK_CONTACT = 2001

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "pickContact") {
                if (pendingResult != null) {
                    result.error("ALREADY_ACTIVE", "Contact picker is already active", null)
                    return@setMethodCallHandler
                }
                pendingResult = result
                try {
                    val intent = Intent(Intent.ACTION_PICK, ContactsContract.CommonDataKinds.Phone.CONTENT_URI)
                    startActivityForResult(intent, REQUEST_CODE_PICK_CONTACT)
                } catch (e: Exception) {
                    pendingResult = null
                    result.error("PICKER_ERROR", "Failed to launch system contact picker: ${e.message}", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_PICK_CONTACT) {
            val result = pendingResult
            pendingResult = null
            if (result == null) return

            if (resultCode == Activity.RESULT_OK && data != null && data.data != null) {
                val contactUri: Uri = data.data!!
                val projection = arrayOf(
                    ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                    ContactsContract.CommonDataKinds.Phone.NUMBER
                )
                var cursor: Cursor? = null
                try {
                    cursor = contentResolver.query(contactUri, projection, null, null, null)
                    if (cursor != null && cursor.moveToFirst()) {
                        val nameIndex = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
                        val numberIndex = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                        val name = if (nameIndex >= 0) cursor.getString(nameIndex) else "Selected Contact"
                        val number = if (numberIndex >= 0) cursor.getString(numberIndex) else ""

                        val map = HashMap<String, String>()
                        map["name"] = name ?: "Selected Contact"
                        map["phone"] = number ?: ""
                        result.success(map)
                    } else {
                        result.error("NO_DATA", "No contact details returned", null)
                    }
                } catch (e: Exception) {
                    result.error("QUERY_ERROR", "Failed to read contact details: ${e.message}", null)
                } finally {
                    cursor?.close()
                }
            } else {
                // Cancelled by user
                result.success(null)
            }
        }
    }
}
