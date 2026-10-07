package com.hermes.client.di

import javax.inject.Qualifier

@Qualifier
@Retention(AnnotationRetention.BINARY)
annotation class ApplicationScope

@Qualifier
@Retention(AnnotationRetention.BINARY)
annotation class SseClient

@Qualifier
@Retention(AnnotationRetention.BINARY)
annotation class FilesClient
