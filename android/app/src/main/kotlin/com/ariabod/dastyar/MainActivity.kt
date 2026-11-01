package com.ariabod.dastyar

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.Build
import android.os.PersistableBundle
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.ariabod.dastyar/privacy"
        private const val KEYSTORE_PROVIDER = "AndroidKeyStore"
        private const val KEY_ALIAS = "dastyar_local_store_v1"
        private const val PREFIX = "enc1:"
        private const val EXTRA_IS_SENSITIVE = "android.content.extra.IS_SENSITIVE"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
        if (sensitive && Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val extras = PersistableBundle().apply {
                putBoolean(EXTRA_IS_SENSITIVE, true)
            }
            clip.description.extras = extras
        }
        cm.setPrimaryClip(clip)
    }
}
