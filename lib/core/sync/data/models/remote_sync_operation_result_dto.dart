class RemoteSyncOperationResultDto {
  const RemoteSyncOperationResultDto({
    required this.operationId,
    required this.type,
    required this.entityLocalId,
    required this.status,
    this.data,
    this.error,
    this.conflictType,
  });

  final String operationId;
  final String type;
  final String entityLocalId;
  final String status;
  final Map<String, dynamic>? data;
  final String? error;
  final String? conflictType;

  factory RemoteSyncOperationResultDto.fromJson(Map<String, dynamic> json) {
    return RemoteSyncOperationResultDto(
      operationId: json['operationId'] as String,
      type: json['type'] as String,
      entityLocalId: json['entityLocalId'] as String,
      status: json['status'] as String,
      data: _asMap(json['data']),
      error: json['error'] as String?,
      conflictType: json['conflictType'] as String?,
    );
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map) {
      return value.cast<String, dynamic>();
    }
    return null;
  }
}
