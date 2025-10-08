String currencySymbol(String currencyCode) {
  final upper = currencyCode.toUpperCase();
  const symbols = <String, String>{
    'TRY': '\u20BA',
    'USD': '\$',
    'EUR': '\u20AC',
    'GBP': '\u00A3',
    'JPY': '\u00A5',
    'CAD': 'C\$',
    'AUD': 'A\$',
    'CHF': 'CHF',
    'CNY': '\u00A5',
    'RUB': '\u20BD',
  };

  return symbols[upper] ?? upper;
}

String formatPrice(double price, String currencyCode) {
  final symbol = currencySymbol(currencyCode);
  return '$symbol ${formatAmount(price)}';
}

String formatAmount(double price) {
  return price.toStringAsFixed(2);
}
