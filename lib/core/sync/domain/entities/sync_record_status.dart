enum SyncRecordStatus {
  pending('pending'),
  sending('sending'),
  synced('synced'),
  failed('failed'),
  conflict('conflict'),
  canceled('canceled');

  const SyncRecordStatus(this.wireValue);

  final String wireValue;

  static SyncRecordStatus fromWireValue(String value) {
    return SyncRecordStatus.values.firstWhere(
      (status) => status.wireValue == value,
      orElse: () => SyncRecordStatus.pending,
    );
  }
}
