package com.ariabod.dastyar

import android.app.ActivityManager
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.os.PersistableBundle
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.security.KeyStore
import java.security.MessageDigest
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.ariabod.dastyar/privacy"
        private const val LLM_CHANNEL = "com.ariabod.dastyar/llm"
        private const val MODEL_CHANNEL = "com.ariabod.dastyar/model"
        private const val REQ_IMPORT_MODEL = 7101
        private const val KEYSTORE_PROVIDER = "AndroidKeyStore"
        private const val KEY_ALIAS = "dastyar_local_store_v1"
        private const val PREFIX = "enc1:"
        private const val EXTRA_IS_SENSITIVE = "android.content.extra.IS_SENSITIVE"
    }

    private var pendingImport: MethodChannel.Result? = null
    private var pendingImportDest: String? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // مدیریت فایل مدل اختیاری: پوشهٔ خصوصی برنامه، امضای SHA-256،
        // واردکردن فایل با پنجرهٔ سیستم (بدون مجوز دسترسی به حافظه).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MODEL_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "modelsDir" -> {
                        val d = File(filesDir, "models")
                        d.mkdirs()
                        result.success(d.absolutePath)
                    }
                    "sha256" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.success(null)
                        } else {
                            Thread {
                                val h = try { sha256Of(File(path)) } catch (e: Exception) { null }
                                mainHandler.post { result.success(h) }
                            }.start()
                        }
                    }
                    "totalRamMb" -> {
                        val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                        val info = ActivityManager.MemoryInfo()
                        am.getMemoryInfo(info)
                        result.success((info.totalMem / (1024L * 1024L)).toInt())
                    }
                    "supportedAbi" -> {
                        val ok = Build.VERSION.SDK_INT >= 26 &&
                            Build.SUPPORTED_ABIS.contains("arm64-v8a")
                        result.success(ok)
                    }
                    "importFile" -> {
                        if (pendingImport != null) {
                            result.error("BUSY", "import in progress", null)
                        } else {
                            pendingImport = result
                            pendingImportDest = call.argument<String>("dest")
                            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "*/*"
                            }
                            try {
                                startActivityForResult(intent, REQ_IMPORT_MODEL)
                            } catch (e: Exception) {
                                pendingImport = null
                                result.success(null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LLM_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isReady" -> {
                        // موتور استنتاج بومی هنوز پیادهسازی نشده است؛ صادقانه
                        // false برگردانده میشود تا لایهٔ Dart هرگز بک‌اند
                        // ناتوان را فعال انتخاب نکند.
                        result.success(false)
                    }
                    "load", "cancel", "dispose" -> result.success(null)
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "seal" -> {
                            val plain = call.argument<String>("text") ?: ""
                            result.success(sealText(plain))
                        }
                        "open" -> {
                            val payload = call.argument<String>("payload") ?: ""
                            result.success(openText(payload))
                        }
                        "copySensitive" -> {
                            val text = call.argument<String>("text") ?: ""
                            val sensitive = call.argument<Boolean>("sensitive") ?: true
                            copyToClipboard(text, sensitive)
                            result.success(true)
                        }
                        "setSecureScreen" -> {
                            val enabled = call.argument<Boolean>("enabled") ?: false
                            if (enabled) {
                                window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            } else {
                                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            }
                            result.success(true)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("PRIVACY_ERR", e.message, null)
                }
            }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQ_IMPORT_MODEL) return
        val res = pendingImport ?: return
        val dest = pendingImportDest
        pendingImport = null
        pendingImportDest = null
        val uri = data?.data
        if (resultCode != RESULT_OK || uri == null || dest == null) {
            res.success(null)
            return
        }
        Thread {
            val name = try { copyUri(uri, File(dest)) } catch (e: Exception) { null }
            mainHandler.post { res.success(name) }
        }.start()
    }

    /** محتوای فایل انتخاب‌شده را در مقصد کپی می‌کند و نام اصلی آن را برمی‌گرداند. */
    private fun copyUri(uri: Uri, dest: File): String {
        var name = "imported-model.gguf"
        contentResolver.query(uri, null, null, null, null)?.use { c ->
            val idx = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (idx >= 0 && c.moveToFirst()) name = c.getString(idx) ?: name
        }
        dest.parentFile?.mkdirs()
        contentResolver.openInputStream(uri).use { input ->
            requireNotNull(input) { "cannot open" }
            dest.outputStream().use { out -> input.copyTo(out, 1 shl 20) }
        }
        return name
    }

    private fun sha256Of(f: File): String {
        val md = MessageDigest.getInstance("SHA-256")
        FileInputStream(f).use { input ->
            val buf = ByteArray(1 shl 20)
            while (true) {
                val n = input.read(buf)
                if (n <= 0) break
                md.update(buf, 0, n)
            }
        }
        return md.digest().joinToString("") { "%02x".format(it) }
    }

    private fun getOrCreateKey(): SecretKey {
        val ks = KeyStore.getInstance(KEYSTORE_PROVIDER).apply { load(null) }
        val existing = ks.getEntry(KEY_ALIAS, null) as? KeyStore.SecretKeyEntry
        if (existing != null) return existing.secretKey

        val keyGen = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            KEYSTORE_PROVIDER,
        )
        val spec = KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .build()
        keyGen.init(spec)
        return keyGen.generateKey()
    }

    private fun sealText(plain: String): String {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, getOrCreateKey())
        val iv = cipher.iv
        val ct = cipher.doFinal(plain.toByteArray(Charsets.UTF_8))
        val packed = ByteArray(1 + iv.size + ct.size)
        packed[0] = iv.size.toByte()
        System.arraycopy(iv, 0, packed, 1, iv.size)
        System.arraycopy(ct, 0, packed, 1 + iv.size, ct.size)
        return PREFIX + Base64.encodeToString(packed, Base64.NO_WRAP)
    }

    private fun openText(payload: String): String {
        if (!payload.startsWith(PREFIX)) return payload
        val packed = Base64.decode(payload.removePrefix(PREFIX), Base64.NO_WRAP)
        require(packed.size > 13) { "Invalid encrypted payload" }
        val ivLen = packed[0].toInt() and 0xFF
        require(ivLen in 12..16 && packed.size > 1 + ivLen) { "Invalid GCM IV" }
        val iv = packed.copyOfRange(1, 1 + ivLen)
        val ct = packed.copyOfRange(1 + ivLen, packed.size)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, getOrCreateKey(), GCMParameterSpec(128, iv))
        return String(cipher.doFinal(ct), Charsets.UTF_8)
    }

    private fun copyToClipboard(text: String, sensitive: Boolean) {
        val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = ClipData.newPlainText("dastyar", text)
        // ClipDescription.setExtras از API 26 (اندروید ۸) به بعد وجود دارد؛
        // گارد N (API 24) روی اندروید ۷.x منجر به NoSuchMethodError میشد.
        if (sensitive && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val extras = PersistableBundle().apply {
                putBoolean(EXTRA_IS_SENSITIVE, true)
            }
            clip.description.extras = extras
        }
        cm.setPrimaryClip(clip)
    }
}
