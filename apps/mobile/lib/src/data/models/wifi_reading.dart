class WifiReading {
  const WifiReading({
    required this.ssid,
    required this.bssid,
    required this.rssi,
    required this.frequency,
    required this.channel,
    required this.timestamp,
  });

  final String ssid;
  final String bssid;
  final int rssi;
  final int frequency;
  final int? channel;
  final DateTime timestamp;

  Map<String, Object?> toJson() {
    return {
      'ssid': ssid,
      'bssid': bssid,
      'rssi': rssi,
      'frequency': frequency,
      'channel': channel,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory WifiReading.fromJson(Map<String, dynamic> json) {
    return WifiReading(
      ssid: json['ssid'] as String,
      bssid: json['bssid'] as String,
      rssi: json['rssi'] as int,
      frequency: json['frequency'] as int,
      channel: json['channel'] as int?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
