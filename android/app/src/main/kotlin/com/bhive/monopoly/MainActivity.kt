package com.bhive.monopoly

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var bhiveBluetooth: BhiveBluetoothBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        bhiveBluetooth = BhiveBluetoothBridge(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        bhiveBluetooth?.onPermissionResult(requestCode, grantResults)
    }

    override fun onDestroy() {
        bhiveBluetooth?.dispose()
        bhiveBluetooth = null
        super.onDestroy()
    }
}
