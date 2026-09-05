/// Karne (meat) o gasul (gas) na hiniling ng isang branch.
enum TransferRequestType {
  meat,
  gas;

  String get label => this == TransferRequestType.meat ? 'Karne' : 'Gasul';
}

enum TransferRequestStatus {
  pending,
  photoTaken,
  submitted;

  String get label {
    switch (this) {
      case TransferRequestStatus.pending:
        return 'Pending';
      case TransferRequestStatus.photoTaken:
        return 'Photo Taken';
      case TransferRequestStatus.submitted:
        return 'Submitted';
    }
  }
}

/// Isang request mula sa isang branch (via Owner's announcement/report)
/// na kailangan ng dagdag na karne o gasul. Ang `suggestedSourceBranchName`
/// ay STATIC/MOCK na lang muna — ang totoong pagpili ng pinaka-malapit
/// at may-sapat-pa-na-stock na branch ay gagawin ng DSS sa backend phase
/// (deferred, pure frontend muna).
class TransferRequest {
  const TransferRequest({
    required this.id,
    required this.branchId,
    required this.branchName,
    required this.type,
    required this.suggestedSourceBranchName,
    this.status = TransferRequestStatus.pending,
  });

  final String id;
  final String branchId;
  final String branchName;
  final TransferRequestType type;
  final String suggestedSourceBranchName;
  final TransferRequestStatus status;

  TransferRequest copyWith({TransferRequestStatus? status}) {
    return TransferRequest(
      id: id,
      branchId: branchId,
      branchName: branchName,
      type: type,
      suggestedSourceBranchName: suggestedSourceBranchName,
      status: status ?? this.status,
    );
  }
}
