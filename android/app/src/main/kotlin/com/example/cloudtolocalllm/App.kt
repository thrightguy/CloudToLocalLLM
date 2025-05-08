package com.example.cloudtolocalllm

import io.flutter.app.FlutterApplication
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugin.common.PluginRegistry.PluginRegistrantCallback
import io.flutter.plugins.GeneratedPluginRegistrant

class App : FlutterApplication(), PluginRegistrantCallback {
  override fun onCreate() {
    super.onCreate()
  }

  override fun registerWith(registry: PluginRegistry) {
    // Manual plugin registration using the generated registrant if needed
  }
}
