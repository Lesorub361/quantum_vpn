package com.quantum.vpn.quantum_vpn

import android.app.Activity
import android.content.Intent
import id.laskarmedia.openvpn_flutter.OpenVPNFlutterPlugin
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        OpenVPNFlutterPlugin.connectWhileGranted(requestCode == 24 && resultCode == Activity.RESULT_OK)
        super.onActivityResult(requestCode, resultCode, data)
    }
}
