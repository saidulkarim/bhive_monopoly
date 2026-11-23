package com.bhive.monopoly

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothServerSocket
import android.bluetooth.BluetoothSocket
import android.content.Intent
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.io.InputStream
import java.nio.charset.StandardCharsets
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger

/**
 * Paired Android-to-Android Bluetooth Classic (secure RFCOMM) networking.
 * Uses exactly the existing bHiVE JSON room messages, newline framed.
 * All blocking socket operations run off the Android main thread.
 */
class BhiveBluetoothBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    companion object {
        const val PERMISSION_REQUEST = 14021
        private const val CHANNEL = "com.bhive.monopoly/bluetooth"
        private const val EVENTS = "com.bhive.monopoly/bluetooth_events"
        private const val MAX_PACKET_BYTES = 1_048_576
        private val SERVICE_ID: UUID = UUID.fromString("cadb6f71-408e-4770-befe-cceab80c3189")
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val readerPool = Executors.newCachedThreadPool()
    private val writer = Executors.newSingleThreadExecutor()
    private val clients = ConcurrentHashMap<String, BluetoothSocket>()
    // BluetoothSocket does not expose an isClosed property on Android.
    // Track successfully connected sockets explicitly; remove them BEFORE an
    // intentional close to distinguish user disconnects from I/O failures.
    private val openSockets = ConcurrentHashMap.newKeySet<BluetoothSocket>()
    private val number = AtomicInteger(0)

    @Volatile private var server: BluetoothServerSocket? = null
    @Volatile private var guest: BluetoothSocket? = null
    @Volatile private var hostRunning = false
    @Volatile private var events: EventChannel.EventSink? = null
    private var permissionResult: MethodChannel.Result? = null

    init {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
        EventChannel(messenger, EVENTS).setStreamHandler(this)
    }

    private fun adapter(): BluetoothAdapter? =
        (activity.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter

    override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink?) {
        events = eventSink
    }

    override fun onCancel(arguments: Any?) {
        events = null
    }

    private fun emit(type: String, peer: String, message: String = "") {
        mainHandler.post {
            events?.success(mapOf("type" to type, "peer" to peer, "message" to message))
        }
    }

    private fun permissionsNeeded(): Array<String> = if (Build.VERSION.SDK_INT >= 31) {
        arrayOf(Manifest.permission.BLUETOOTH_CONNECT)
    } else {
        emptyArray()
    }

    private fun hasPermission(): Boolean = permissionsNeeded().all {
        activity.checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED
    }

    fun onPermissionResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != PERMISSION_REQUEST) return false
        val pending = permissionResult
        permissionResult = null
        pending?.success(grantResults.isNotEmpty() && grantResults.all {
            it == PackageManager.PERMISSION_GRANTED
        })
        return true
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "permissions" -> {
                    if (hasPermission()) {
                        result.success(true)
                    } else if (permissionResult != null) {
                        result.error("PERMISSION_BUSY", "Nearby devices permission is pending.", null)
                    } else {
                        permissionResult = result
                        activity.requestPermissions(permissionsNeeded(), PERMISSION_REQUEST)
                    }
                }
                "enabled" -> result.success(adapter()?.isEnabled == true)
                "openSettings" -> {
                    activity.startActivity(Intent(Settings.ACTION_BLUETOOTH_SETTINGS))
                    result.success(null)
                }
                "pairedDevices" -> {
                    requireReady()
                    val devices = adapter()!!.bondedDevices.map { device ->
                        mapOf("name" to (device.name ?: "Bluetooth device"), "address" to device.address)
                    }.sortedBy { it["name"] ?: "" }
                    result.success(devices)
                }
                "startHost" -> startHost(result)
                "connect" -> connect(call.argument<String>("address") ?: "", result)
                "send" -> {
                    val peer = call.argument<String>("peer") ?: ""
                    val message = call.argument<String>("message") ?: ""
                    if (peer.isBlank() || message.isEmpty() || message.toByteArray(StandardCharsets.UTF_8).size > MAX_PACKET_BYTES) {
                        result.error("PACKET", "Invalid or oversized Bluetooth packet.", null)
                    } else {
                        send(peer, message)
                        result.success(null)
                    }
                }
                "stop" -> {
                    closeSockets()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (error: Exception) {
            result.error("BLUETOOTH", error.message ?: "Bluetooth operation failed.", null)
        }
    }

    private fun requireReady() {
        if (!hasPermission()) throw SecurityException("Nearby devices permission required.")
        if (adapter()?.isEnabled != true) throw IllegalStateException("Bluetooth is turned off.")
    }

    private fun startHost(result: MethodChannel.Result) {
        requireReady()
        closeSockets()
        readerPool.execute {
            var opened = false
            try {
                val listening = adapter()!!.listenUsingRfcommWithServiceRecord("bHiVE Monopoly", SERVICE_ID)
                server = listening
                hostRunning = true
                opened = true
                mainHandler.post { result.success(null) }
                while (hostRunning) {
                    val socket = listening.accept() // blocks on background thread
                    if (!hostRunning) {
                        socket.close()
                        break
                    }
                    val id = "bt-${number.incrementAndGet()}"
                    openSockets.add(socket)
                    clients[id] = socket
                    emit("connected", id)
                    readSocket(socket, id)
                }
            } catch (error: Exception) {
                if (!opened) {
                    mainHandler.post { result.error("HOST", error.message ?: "Bluetooth host failed.", null) }
                } else if (hostRunning) {
                    emit("error", "host", error.message ?: "Bluetooth host stopped.")
                }
            } finally {
                hostRunning = false
                try { server?.close() } catch (_: Exception) { }
                server = null
            }
        }
    }

    private fun connect(address: String, result: MethodChannel.Result) {
        requireReady()
        if (!Regex("(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}").matches(address)) {
            result.error("ADDRESS", "Select a paired Bluetooth host phone.", null)
            return
        }
        closeSockets()
        readerPool.execute {
            var socket: BluetoothSocket? = null
            try {
                socket = adapter()!!.getRemoteDevice(address)
                    .createRfcommSocketToServiceRecord(SERVICE_ID)
                socket.connect() // blocking, runs off UI thread
                openSockets.add(socket)
                guest = socket
                mainHandler.post { result.success(null) }
                readSocket(socket, "client")
            } catch (error: Exception) {
                socket?.let { openSockets.remove(it) }
                try { socket?.close() } catch (_: Exception) { }
                mainHandler.post { result.error("CONNECT", error.message ?: "Cannot connect to host phone.", null) }
            }
        }
    }

    private fun readSocket(socket: BluetoothSocket, id: String) {
        readerPool.execute {
            try {
                val input = socket.inputStream
                while (openSockets.contains(socket)) {
                    val packet = readLine(input) ?: break
                    emit("message", id, packet)
                }
            } catch (error: IOException) {
                if (openSockets.contains(socket)) emit("error", id, error.message ?: "Bluetooth connection lost.")
            } finally {
                openSockets.remove(socket)
                clients.remove(id, socket)
                if (id == "client" && guest === socket) guest = null
                try { socket.close() } catch (_: Exception) { }
                emit("disconnected", id)
            }
        }
    }

    // Bounded packet reader. Huge or malformed messages cannot exhaust RAM.
    private fun readLine(input: InputStream): String? {
        val buffer = ByteArrayOutputStream()
        while (true) {
            val value = input.read()
            if (value == -1) return if (buffer.size() == 0) null else throw IOException("Truncated packet.")
            if (value == '\n'.code) break
            if (buffer.size() >= MAX_PACKET_BYTES) throw IOException("Bluetooth packet too large.")
            buffer.write(value)
        }
        return buffer.toString(StandardCharsets.UTF_8.name())
    }

    private fun send(peer: String, message: String) {
        val socket = if (peer == "client") guest else clients[peer]
        if (socket == null || !openSockets.contains(socket)) {
            emit("error", peer, "Bluetooth peer is disconnected.")
            return
        }
        writer.execute {
            if (!openSockets.contains(socket)) return@execute
            try {
                val bytes = (message + "\n").toByteArray(StandardCharsets.UTF_8)
                socket.outputStream.write(bytes)
                socket.outputStream.flush()
            } catch (error: IOException) {
                if (openSockets.remove(socket)) {
                    emit("error", peer, error.message ?: "Bluetooth send failed.")
                }
                try { socket.close() } catch (_: Exception) { }
            }
        }
    }

    private fun closeSockets() {
        hostRunning = false
        try { server?.close() } catch (_: Exception) { }
        server = null
        // Mark sockets closed before closing them. The reader threads can then
        // finish without reporting an intentional stop as a connection error.
        val closing = openSockets.toList()
        openSockets.clear()
        for (socket in closing) {
            try { socket.close() } catch (_: Exception) { }
        }
        clients.clear()
        guest = null
    }

    fun dispose() {
        closeSockets()
        events = null
        val pending = permissionResult
        permissionResult = null
        pending?.error("DISPOSED", "Bluetooth screen was closed.", null)
        readerPool.shutdownNow()
        writer.shutdownNow()
    }
}
