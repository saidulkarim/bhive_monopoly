#!/usr/bin/env python3
"""Safely add Android Bluetooth permission and MainActivity bridge wiring.
Run from the bHiVE Flutter project root AFTER extracting Phase 14.1.
Requires only Python 3; safely creates .phase14_1.bak backups.
"""
from pathlib import Path
import re
import shutil
import sys

root = Path.cwd()
manifest = root / 'android/app/src/main/AndroidManifest.xml'
main_candidates = list((root / 'android/app/src/main/kotlin').rglob('MainActivity.kt'))
main_activity = main_candidates[0] if len(main_candidates) == 1 else (root / 'android/app/src/main/kotlin/com/bhive/monopoly/MainActivity.kt')
bridge = root / 'android/app/src/main/kotlin/com/bhive/monopoly/BhiveBluetoothBridge.kt'

if not manifest.is_file() or not main_activity.is_file() or not bridge.is_file():
    print('ERROR: Run from the Flutter project root; expected Android files are missing.')
    sys.exit(2)

text = manifest.read_text(encoding='utf-8')
perms = '''
    <!-- Phase 14.1: Paired Android Bluetooth Classic multiplayer. -->
    <uses-feature android:name="android.hardware.bluetooth" android:required="false" />
    <uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />'''

if 'android.permission.BLUETOOTH_CONNECT' not in text:
    match = re.search(r'<manifest\b[^>]*>', text, re.S)
    if not match:
        raise SystemExit('ERROR: Cannot identify Android manifest opening tag.')
    shutil.copy2(manifest, str(manifest) + '.phase14_1.bak')
    text = text[:match.end()] + perms + text[match.end():]
    manifest.write_text(text, encoding='utf-8')
    print('UPDATED:', manifest)
else:
    print('SKIP: Bluetooth permissions already in AndroidManifest.xml')

source = main_activity.read_text(encoding='utf-8')
if 'BhiveBluetoothBridge' in source:
    print('SKIP: MainActivity already registers Bluetooth bridge.')
    sys.exit(0)

# Do not silently discard custom Android logic. Require a simple FlutterActivity.
pattern = r'(?m)^\s*class\s+MainActivity\s*:\s*FlutterActivity\s*\(\s*\)\s*(?:\{\s*\})?\s*$'
if not re.search(pattern, source):
    print('ERROR: Your MainActivity.kt contains custom logic or unexpected structure.')
    print('Merge the code below into your MainActivity rather than replacing it:')
    print('''
private var bhiveBluetooth: BhiveBluetoothBridge? = null

override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    bhiveBluetooth = BhiveBluetoothBridge(this, flutterEngine.dartExecutor.binaryMessenger)
}

override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
    super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    bhiveBluetooth?.onPermissionResult(requestCode, grantResults)
}

override fun onDestroy() {
    bhiveBluetooth?.dispose()
    bhiveBluetooth = null
    super.onDestroy()
}
''')
    print('Also import io.flutter.embedding.engine.FlutterEngine')
    sys.exit(3)

new_source = '''package com.bhive.monopoly

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
'''
shutil.copy2(main_activity, str(main_activity) + '.phase14_1.bak')
main_activity.write_text(new_source, encoding='utf-8')
print('UPDATED:', main_activity)
print('DONE. Now run flutter analyze, flutter test test/game/, and flutter build apk --debug')
