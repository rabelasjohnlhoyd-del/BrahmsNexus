/// Meat or gas requested by a branch.
enum TransferRequestType {
  meat,
  gas;

  String get label => this == TransferRequestType.meat ? 'Meat' : 'Gas';
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

/// A request from a branch (via the Owner's announcement/report) that
/// needs extra meat or gas. `suggestedSourceBranchName` is STATIC/MOCK
/// for now — the real selection of the nearest branch with enough
/// spare stock will be done by the DSS in the backend phase (deferred,
/// pure frontend for now).
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
