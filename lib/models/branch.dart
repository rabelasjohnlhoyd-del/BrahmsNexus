/// Master record for a branch/outlet. Route sequence determines the
/// order the Driver visits branches during the daily route (pickup of
/// staff, stock transfer stops, deliveries).
class Branch {
  const Branch({
    required this.id,
    required this.name,
    required this.dailyRouteSequence,
  });

  final String id;
  final String name;

  /// Order of this branch in the driver's daily route (1 = first stop).
  final int dailyRouteSequence;
}

/// Sample branches based on the client interview. Replace with
/// Supabase-backed records once the backend is wired up — branch
/// names/addresses rarely change, so this belongs in the "static
/// data" (Supabase) side rather than Firebase.
const List<Branch> kSampleBranches = [
  Branch(id: 'br1', name: 'Dayap, Calauan', dailyRouteSequence: 1),
  Branch(id: 'br2', name: 'Sta. Cruz', dailyRouteSequence: 2),
  Branch(id: 'br3', name: 'Pila', dailyRouteSequence: 3),
  Branch(id: 'br4', name: 'Labuin', dailyRouteSequence: 4),
  Branch(id: 'br5', name: 'Pagsanjan', dailyRouteSequence: 5),
];
