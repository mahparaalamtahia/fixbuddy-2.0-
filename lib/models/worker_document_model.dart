class WorkerDocumentModel {
  final String id;
  final String workerId;
  final String documentType;
  final String fileName;
  final String filePath;
  final int fileSize;
  final String mimeType;
  final DateTime uploadedAt;
  final DateTime? verifiedAt;
  final String? verifiedBy;
  final String status;
  final String? rejectionReason;

  WorkerDocumentModel({
    required this.id,
    required this.workerId,
    required this.documentType,
    required this.fileName,
    required this.filePath,
    required this.fileSize,
    required this.mimeType,
    required this.uploadedAt,
    this.verifiedAt,
    this.verifiedBy,
    required this.status,
    this.rejectionReason,
  });

  factory WorkerDocumentModel.fromJson(Map<String, dynamic> json) {
    return WorkerDocumentModel(
      id: json['id'] as String,
      workerId: json['worker_id'] as String,
      documentType: json['document_type'] as String,
      fileName: json['file_name'] as String,
      filePath: json['file_path'] as String,
      fileSize: json['file_size'] as int? ?? 0,
      mimeType: json['mime_type'] as String,
      uploadedAt: DateTime.parse(json['uploaded_at'] as String),
      verifiedAt: json['verified_at'] != null
          ? DateTime.parse(json['verified_at'] as String)
          : null,
      verifiedBy: json['verified_by'] as String?,
      status: json['status'] as String,
      rejectionReason: json['rejection_reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'worker_id': workerId,
      'document_type': documentType,
      'file_name': fileName,
      'file_path': filePath,
      'file_size': fileSize,
      'mime_type': mimeType,
      'status': status,
    };
  }
}
