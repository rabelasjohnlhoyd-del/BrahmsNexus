/// Master record for a branch/outlet. Route sequence determines the
/// order the Driver visits branches during the daily route (pickup of
/// staff, stock transfer stops, deliveries).
///
/// NOTE: This route sequence is currently a static/mock default order.
/// The real order should eventually be computed by the DSS backend
/// based on which staff are working that day and their addresses —
/// deferred until the DSS Analytics phase (pure frontend for now).
class Branch {
  const Branch({
    required this.id,
    required this.name,
    required this.municipality,
    required this.dailyRouteSequence,
  });

  final String id;
  final String name;
  final String municipality;

  /// Order of this branch in the driver's daily route (1 = first stop).
  final int dailyRouteSequence;

  String get fullName => '$name, $municipality';
}

/// Actual branch list as given by the Owner (barangay-level detail).
/// Replace with Supabase-backed records once the backend is wired up
/// — branch names/addresses rarely change, so this belongs in the
/// "static data" (Supabase) side rather than Firebase.
const List<Branch> kSampleBranches = [
  Branch(
    id: 'br1',
    name: 'Brgy. Gatid',
    municipality: 'Sta. Cruz',
    dailyRouteSequence: 1,
  ),
  Branch(
    id: 'br2',
    name: 'Brgy. Labuin',
    municipality: 'Pila',
    dailyRouteSequence: 2,
  ),
  Branch(
    id: 'br3',
    name: 'Brgy. Sta. Clara Sur',
    municipality: 'Pila',
    dailyRouteSequence: 3,
  ),
  Branch(
    id: 'br4',
    name: 'Brgy. Nanhaya',
    municipality: 'Victoria',
    dailyRouteSequence: 4,
  ),
  Branch(
    id: 'br5',
    name: 'Brgy. San Francisco',
    municipality: 'Victoria',
    dailyRouteSequence: 5,
  ),
  Branch(
    id: 'br6',
    name: 'Brgy. Dayap',
    municipality: 'Calauan',
    dailyRouteSequence: 6,
  ),
];
