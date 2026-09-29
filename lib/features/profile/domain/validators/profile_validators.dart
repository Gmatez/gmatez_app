class ProfileValidators {
  static String? displayName(String value) {
    final name = value.trim();
    if (name.length < 2) {
      return 'Name must be at least 2 characters.';
    }
    if (name.length > 40) {
      return 'Name must be 40 characters or fewer.';
    }
    return null;
  }

  static String? bio(String value) {
    if (value.length > 280) {
      return 'Bio must be 280 characters or fewer.';
    }
    return null;
  }

  static String? country(String value) {
    final country = value.trim();
    if (country.isEmpty) {
      return null;
    }
    if (!RegExp(r'^[A-Za-z]{2}$').hasMatch(country)) {
      return 'Use a 2-letter country code.';
    }
    return null;
  }

  static String? language(String value) {
    final language = value.trim();
    if (language.isEmpty) {
      return null;
    }
    if (!RegExp(r'^[A-Za-z-]{2,16}$').hasMatch(language)) {
      return 'Use a short language code such as en.';
    }
    return null;
  }

  static String? avatarUrl(String value) {
    final url = value.trim();
    if (url.isEmpty) {
      return null;
    }
    final parsed = Uri.tryParse(url);
    if (parsed == null ||
        !(parsed.isScheme('http') || parsed.isScheme('https')) ||
        url.length > 2048) {
      return 'Avatar must be an http(s) URL.';
    }
    return null;
  }

  static String? ratePerMinuteCents(String value) {
    if (value.trim().isEmpty) {
      return null;
    }
    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed < 0 || parsed > 100000) {
      return 'Rate must be between 0 and 100000 cents.';
    }
    return null;
  }
}
