package com.hermes.client.ui.chat

import android.content.Context
import android.media.MediaRecorder
import android.os.Build
import java.io.File

/**
 * Records a single voice note to an AAC/.m4a file in the app cache. The file is handed to the
 * chat as an attachment and uploaded to the file service, so Hermes receives the raw audio rather
 * than an on-device transcript.
 */
class VoiceRecorder(private val context: Context) {

    private var recorder: MediaRecorder? = null
    private var outputFile: File? = null

    fun start(): File? {
        abort()
        val dir = File(context.cacheDir, "voice").apply { mkdirs() }
        val file = File(dir, "voice_${System.currentTimeMillis()}.m4a")
        val rec = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(context)
        } else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }
        return try {
            rec.setAudioSource(MediaRecorder.AudioSource.MIC)
            rec.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            rec.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            rec.setAudioEncodingBitRate(96_000)
            rec.setAudioSamplingRate(44_100)
            rec.setOutputFile(file.absolutePath)
            rec.prepare()
            rec.start()
            recorder = rec
            outputFile = file
            file
        } catch (_: Exception) {
            runCatching { rec.release() }
            file.delete()
            null
        }
    }

    /** Stops recording and returns the captured file, or null when nothing usable was recorded. */
    fun stop(): File? {
        val rec = recorder ?: return null
        val file = outputFile
        recorder = null
        outputFile = null
        return try {
            rec.stop()
            rec.release()
            if (file != null && file.exists() && file.length() > 0) {
                file
            } else {
                file?.delete()
                null
            }
        } catch (_: Exception) {
            runCatching { rec.release() }
            file?.delete()
            null
        }
    }

    /** Discard an in-progress recording (e.g. the screen is left). */
    fun abort() {
        val rec = recorder ?: return
        recorder = null
        runCatching { rec.stop() }
        runCatching { rec.release() }
        outputFile?.delete()
        outputFile = null
    }
}
