/// Computes the cook's daily wage from the Owner's tiered rate table.
///
/// Actual business rules confirmed by client:
/// - 1 – 29 orders = ₱370
/// - 30 – 39 orders = ₱420
/// - 40 – 49 orders = ₱520
/// - 50 – 59 orders = ₱620
/// - and so on (+₱100 per additional 10-order bracket).
class WageCalculator {
  const WageCalculator._();

  static int computeWage(int ordersSold) {
    if (ordersSold <= 0) return 0;
    if (ordersSold <= 29) return 370;

    // From 30 onwards: starts at ₱420, +₱100 every 10 orders
    final extraBrackets = (ordersSold - 30) ~/ 10;
    return 420 + (extraBrackets * 100);
  }
}
