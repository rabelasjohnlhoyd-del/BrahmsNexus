/// Reusable enterprise validation rules for user input across the app.
class InputMessageValidationResult {
  final bool isValid;
  final String? errorMessage;
  final String sanitizedText;

  const InputMessageValidationResult({
    required this.isValid,
    this.errorMessage,
    required this.sanitizedText,
  });
}

class InputValidators {
  /// Validates an input message box based on enterprise rules:
  /// - Required: configurable (default true)
  /// - Minimum: [minLength] (default 10 characters)
  /// - Maximum: [maxLength] (default 300 characters)
  /// - Letters, numbers, spaces, punctuation, special characters allowed
  /// - Multiple spaces: Normalized to a single space
  /// - HTML / Script: Rejected (no `<script>`, tags, etc.)
  /// - Excessive repeated characters: Filtered/rejected (max 3 consecutive identical characters)
  static InputMessageValidationResult validateMessage(
    String? input, {
    String fieldName = 'Reason / Note',
    bool required = true,
    int minLength = 10,
    int maxLength = 300,
  }) {
    if (input == null || input.trim().isEmpty) {
      if (required) {
        return InputMessageValidationResult(
          isValid: false,
          errorMessage: '$fieldName is required (minimum $minLength characters).',
          sanitizedText: '',
        );
      }
      return const InputMessageValidationResult(isValid: true, sanitizedText: '');
    }

    final trimmed = input.trim();

    // 1. Reject HTML / Script tags
    final lower = trimmed.toLowerCase();
    if (lower.contains('<script') ||
        lower.contains('</script>') ||
        lower.contains('<iframe') ||
        lower.contains('javascript:') ||
        RegExp(r'<[^>]+>').hasMatch(trimmed)) {
      return InputMessageValidationResult(
        isValid: false,
        errorMessage: 'Bawal ang HTML tags o scripts sa $fieldName.',
        sanitizedText: trimmed,
      );
    }

    // 2. Normalize multiple spaces into single space
    final normalized = trimmed.replaceAll(RegExp(r'\s+'), ' ');

    // 3. Minimum length
    if (normalized.length < minLength) {
      return InputMessageValidationResult(
        isValid: false,
        errorMessage: '$fieldName must be at least $minLength characters.',
        sanitizedText: normalized,
      );
    }

    // 4. Maximum length
    if (normalized.length > maxLength) {
      return InputMessageValidationResult(
        isValid: false,
        errorMessage: '$fieldName must not exceed $maxLength characters.',
        sanitizedText: normalized,
      );
    }

    // 5. Limit / filter excessive repeated characters (more than 3 consecutive identical characters like "aaaa" or "....")
    if (RegExp(r'(.)\1{3,}').hasMatch(normalized)) {
      return InputMessageValidationResult(
        isValid: false,
        errorMessage: 'Bawal ang sobra-sobrang paulit-ulit na letra/simbolo sa $fieldName.',
        sanitizedText: normalized,
      );
    }

    return InputMessageValidationResult(
      isValid: true,
      sanitizedText: normalized,
    );
  }

  /// Validates Philippine mobile number:
  /// - Must start with 09
  /// - Exactly 11 digits
  /// - Maximum 3 consecutive identical digits
  static String? validatePhilippinePhone(String? value, {String label = 'Contact number'}) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required.';
    }
    final raw = value.trim().replaceAll(RegExp(r'\s'), '');
    if (!raw.startsWith('09')) {
      return '$label must start with 09 (e.g. 09171234567).';
    }
    if (raw.length != 11 || !RegExp(r'^[0-9]+$').hasMatch(raw)) {
      return '$label must be exactly 11 numeric digits.';
    }
    if (RegExp(r'(.)\1{3,}').hasMatch(raw)) {
      return '$label cannot have more than 3 consecutive identical digits.';
    }
    return null;
  }

  /// Validates customer name for orders:
  /// - Letters, spaces, hyphens, and apostrophes only
  /// - Minimum 2 characters, maximum 60 characters
  /// - Must contain valid letters and vowels
  /// - No single word exceeding 20 characters
  /// - Each name part at least 2 characters
  /// - No keyboard mashing or low-diversity repeating patterns
  /// - No more than 3 consecutive identical letters
  static String? validateCustomerName(String? value, {String label = 'Customer name'}) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required.';
    }
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length < 2) {
      return '$label must be at least 2 characters.';
    }
    if (normalized.length > 60) {
      return '$label must not exceed 60 characters.';
    }
    if (!RegExp(r"^[a-zA-ZñÑáéíóúÁÉÍÓÚ\s\-'.]+$").hasMatch(normalized)) {
      return '$label must contain letters only (no numbers or symbols).';
    }
    if (!RegExp(r"[a-zA-ZñÑáéíóúÁÉÍÓÚ]").hasMatch(normalized)) {
      return '$label must contain valid letters.';
    }
    
    // Check words
    final words = normalized.split(' ');
    for (final word in words) {
      if (word.length > 20) {
        return '$label cannot contain a word longer than 20 characters.';
      }
      if (word.length < 2) {
        return 'Each word in $label must be at least 2 characters.';
      }
      // Each word should contain at least one vowel
      if (!RegExp(r'[aeiouáéíóúAEIOUÁÉÍÓÚ]').hasMatch(word)) {
        return 'Each part of $label must contain a vowel. Please enter a valid name.';
      }
    }

    // No more than 3 consecutive identical characters (e.g. "aaaa")
    if (RegExp(r'(.)\1{3,}', caseSensitive: false).hasMatch(normalized)) {
      return '$label contains excessive repeated characters.';
    }

    // Repeated patterns of 2-4 characters (e.g. asdasdasd, haha, ababab)
    if (RegExp(r'(.{2,4})\1{2,}', caseSensitive: false).hasMatch(normalized)) {
      return '$label appears to contain repetitive pattern characters.';
    }

    // Excessive consonant cluster (5 or more consonants in a row)
    if (RegExp(r'[bcdfghjklmnpqrstvwxyz]{5,}', caseSensitive: false).hasMatch(normalized)) {
      return '$label contains an unnatural sequence of consonants.';
    }

    // Character diversity check (guard against keyboard mashing like "adsadasdsadasdsa")
    final lettersOnly = normalized.toLowerCase().replaceAll(RegExp(r'[^a-zñáéíóú]'), '');
    final uniqueLetters = lettersOnly.split('').toSet().length;
    if (lettersOnly.length >= 8 && uniqueLetters <= 2) {
      return '$label has too few unique letters. Please enter a real name.';
    }
    if (lettersOnly.length >= 12 && uniqueLetters <= 3) {
      return '$label has too few unique letters. Please enter a real name.';
    }
    if (lettersOnly.length >= 18 && uniqueLetters <= 4) {
      return '$label has too few unique letters. Please enter a real name.';
    }

    return null;
  }
}
