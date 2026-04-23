class DeviceRegistration {
  const DeviceRegistration({
    required this.deviceId,
    required this.platform,
    required this.registeredAt,
  });

  final String deviceId;
  final String platform;
  final DateTime registeredAt;
}
