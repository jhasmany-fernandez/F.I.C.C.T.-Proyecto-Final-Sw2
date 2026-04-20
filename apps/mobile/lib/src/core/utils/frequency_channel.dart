int? wifiChannelFromFrequency(int frequency) {
  if (frequency == 2484) {
    return 14;
  }

  if (frequency >= 2412 && frequency <= 2472) {
    return ((frequency - 2407) / 5).round();
  }

  if (frequency >= 5000 && frequency <= 5895) {
    return ((frequency - 5000) / 5).round();
  }

  if (frequency >= 5955 && frequency <= 7115) {
    return ((frequency - 5950) / 5).round();
  }

  return null;
}
