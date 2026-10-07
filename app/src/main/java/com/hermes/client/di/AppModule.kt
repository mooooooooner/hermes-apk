package com.hermes.client.di

import android.content.Context
import androidx.room.Room
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
import com.google.gson.Gson
import com.google.gson.GsonBuilder
import com.hermes.client.data.local.HermesDatabase
import com.hermes.client.data.local.MessageDao
import com.hermes.client.data.local.RunDao
import com.hermes.client.data.local.SessionDao
import com.hermes.client.data.remote.DynamicUrlInterceptor
import com.hermes.client.data.remote.FilesApi
import com.hermes.client.data.remote.FilesAuthInterceptor
import com.hermes.client.data.remote.FilesUrlInterceptor
import com.hermes.client.data.remote.HermesApi
import com.hermes.client.data.prefs.SettingsRepository
import coil.ImageLoader
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import java.util.concurrent.TimeUnit
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object AppModule {

    @Provides
    @Singleton
    fun provideGson(): Gson = GsonBuilder()
        .setLenient()
        .serializeNulls()
        .create()

    @Provides
    @Singleton
    @ApplicationScope
    fun provideApplicationScope(): CoroutineScope =
        CoroutineScope(SupervisorJob() + Dispatchers.Default)

    @Provides
    @Singleton
    fun provideOkHttpClient(settings: SettingsRepository): OkHttpClient {
        val logging = HttpLoggingInterceptor().apply {
            level = HttpLoggingInterceptor.Level.BASIC
        }
        return OkHttpClient.Builder()
            .addInterceptor(DynamicUrlInterceptor(settings))
            .addInterceptor(logging)
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(90, TimeUnit.SECONDS)
            .writeTimeout(90, TimeUnit.SECONDS)
            .callTimeout(0, TimeUnit.SECONDS)
            .retryOnConnectionFailure(true)
            .build()
    }

    /** SSE connections stay open indefinitely and must not be killed by a read timeout. */
    @Provides
    @Singleton
    @SseClient
    fun provideSseClient(settings: SettingsRepository): OkHttpClient =
        OkHttpClient.Builder()
            .addInterceptor(DynamicUrlInterceptor(settings))
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(0, TimeUnit.MILLISECONDS)
            .writeTimeout(0, TimeUnit.MILLISECONDS)
            .retryOnConnectionFailure(true)
            .build()

    @Provides
    @Singleton
    fun provideRetrofit(client: OkHttpClient, gson: Gson): Retrofit = Retrofit.Builder()
        .baseUrl("http://localhost/")
        .client(client)
        .addConverterFactory(GsonConverterFactory.create(gson))
        .build()

    @Provides
    @Singleton
    fun provideHermesApi(retrofit: Retrofit): HermesApi = retrofit.create(HermesApi::class.java)

    @Provides
    @Singleton
    @FilesClient
    fun provideFilesClient(settings: SettingsRepository): OkHttpClient {
        val logging = HttpLoggingInterceptor().apply {
            level = HttpLoggingInterceptor.Level.BASIC
        }
        return OkHttpClient.Builder()
            .addInterceptor(FilesUrlInterceptor(settings))
            .addInterceptor(logging)
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(90, TimeUnit.SECONDS)
            .writeTimeout(120, TimeUnit.SECONDS)
            .callTimeout(0, TimeUnit.SECONDS)
            .retryOnConnectionFailure(true)
            .build()
    }

    @Provides
    @Singleton
    @FilesClient
    fun provideFilesRetrofit(
        @FilesClient client: OkHttpClient,
        gson: Gson,
    ): Retrofit = Retrofit.Builder()
        .baseUrl("http://localhost/")
        .client(client)
        .addConverterFactory(GsonConverterFactory.create(gson))
        .build()

    @Provides
    @Singleton
    fun provideFilesApi(@FilesClient retrofit: Retrofit): FilesApi =
        retrofit.create(FilesApi::class.java)

    /** Coil image loader that authenticates requests to the companion file service. */
    @Provides
    @Singleton
    fun provideImageLoader(
        @ApplicationContext context: Context,
        settings: SettingsRepository,
    ): ImageLoader = ImageLoader.Builder(context)
        .okHttpClient {
            OkHttpClient.Builder()
                .addInterceptor(FilesAuthInterceptor(settings))
                .build()
        }
        .build()
}

@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {

    private val MIGRATION_1_2 = object : Migration(1, 2) {
        override fun migrate(db: SupportSQLiteDatabase) {
            db.execSQL("ALTER TABLE messages ADD COLUMN segments TEXT NOT NULL DEFAULT '[]'")
        }
    }

    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context): HermesDatabase =
        Room.databaseBuilder(context, HermesDatabase::class.java, HermesDatabase.NAME)
            .addMigrations(MIGRATION_1_2)
            .fallbackToDestructiveMigration()
            .build()

    @Provides
    fun provideSessionDao(db: HermesDatabase): SessionDao = db.sessionDao()

    @Provides
    fun provideMessageDao(db: HermesDatabase): MessageDao = db.messageDao()

    @Provides
    fun provideRunDao(db: HermesDatabase): RunDao = db.runDao()
}
