package com.hermes.client.data.remote.dto

import com.google.gson.annotations.SerializedName

/** Response of `POST /upload` on the companion file service. */
data class UploadedFileDto(
    @SerializedName("id") val id: String? = null,
    @SerializedName("name") val name: String? = null,
    @SerializedName("size") val size: Long = 0,
    @SerializedName("mime") val mime: String? = null,
    /** Absolute path on the server, usable directly by the agent's file tools. */
    @SerializedName("path") val path: String? = null,
    /** Public URL the app can fetch the bytes from. */
    @SerializedName("url") val url: String? = null,
    @SerializedName("created") val created: Long? = null,
)

/** One entry of `GET /commands` (server-editable slash-command list). */
data class CommandDto(
    @SerializedName("name") val name: String = "",
    @SerializedName("description") val description: String? = null,
    @SerializedName("template") val template: String? = null,
)
