import 'dart:io';

import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class WifiConnectionService {
  WifiConnectionService({NetworkInfo? networkInfo})
    : _networkInfo = networkInfo ?? NetworkInfo();

  final NetworkInfo _networkInfo;

  Future<WifiConnectionInfo?> getConnectedWifiInfo() async {
    if (!Platform.isAndroid) {
      return null;
    }

    final status = await Permission.locationWhenInUse.request();
    if (!status.isGranted) {
      return null;
    }

    final locationServiceEnabled =
        await Permission.locationWhenInUse.serviceStatus.isEnabled;
    if (!locationServiceEnabled) {
      return null;
    }

    final wifiName = await _networkInfo.getWifiName();
    final wifiBssid = await _networkInfo.getWifiBSSID();
    if (wifiName == null || wifiName.trim().isEmpty) {
      return null;
    }

    return WifiConnectionInfo(
      ssid: wifiName.replaceAll('"', '').trim(),
      bssid: wifiBssid?.replaceAll('"', '').trim(),
    );
  }
}

class WifiConnectionInfo {
  const WifiConnectionInfo({required this.ssid, required this.bssid});

  final String ssid;
  final String? bssid;
}
