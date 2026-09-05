/// Computes the cook's daily wage from the Owner's tiered rate table.
///
/// Verified against the Owner's real example: 17 orders -> ₱360
/// (base ₱320 for the 1–29 bracket + a flat ₱40 add-on every tier).
///
/// Brackets confirmed by the Owner: 1–29 (₱320), 30–39 (₱370),
/// 40–49 (₱470), 50–59 (₱570), 60–69 (₱670) — each +₱40 flat.
/// Beyond 69, the same +₱100-per-bracket pattern continues, per the
/// Owner: "once you go past it, it's just another flat add-on."
class WageCalculator {
  const WageCalculator._();

  static const int flatAddOn = 40;

  static int computeWage(int ordersSold) {
    return _baseForOrders(ordersSold) + flatAddOn;
  }

  static int _baseForOrders(int orders) {
    if (orders <= 29) return 320;
    if (orders <= 39) return 370;
    if (orders <= 49) return 470;
    if (orders <= 59) return 570;
    if (orders <= 69) return 670;

    // Beyond 69: same pattern continues, +100 per additional 10-order
    // bracket past the 60–69 bracket.
    final extraBrackets = ((orders - 70) ~/ 10) + 1;
    return 670 + (extraBrackets * 100);
  }
}
