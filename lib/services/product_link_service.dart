import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

class ProductLinkImageResult {
  ProductLinkImageResult({
    required this.imageUrl,
    required this.imageBytes,
    this.contentType,
  });

  final String imageUrl;
  final Uint8List imageBytes;
  final String? contentType;
}

class ProductLinkMetadata {
  const ProductLinkMetadata({
    this.image,
    this.price,
    this.currency,
  });

  final ProductLinkImageResult? image;
  final double? price;
  final String? currency;
}

class ProductLinkService {
  ProductLinkService({http.Client? client}) : _client = client ?? http.Client();

  static const Map<String, String> _requestHeaders = {
    'user-agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'accept-language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7',
    'accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'accept-encoding': 'gzip, deflate, br, zstd',
  };

  final http.Client _client;

  bool supportsUrl(String url) => _parseUri(url) != null;

  Future<ProductLinkImageResult?> fetchPrimaryImage(String url) async {
    final metadata = await fetchMetadata(url);
    return metadata?.image;
  }

  Future<ProductLinkMetadata?> fetchMetadata(String url) async {
    final uri = _parseUri(url);
    if (uri == null) {
      return null;
    }

    final pageResponse = await _client.get(uri, headers: _requestHeaders);
    if (pageResponse.statusCode != 200) {
      throw Exception(
        'Failed to load product page (${pageResponse.statusCode})',
      );
    }

    final body = _decodeBody(pageResponse);
    final document = html_parser.parse(body);

    final imageUrl = _extractImageUrl(document, uri);
    ProductLinkImageResult? imageResult;

    if (imageUrl != null) {
      if (_isDataUrl(imageUrl)) {
        final dataBytes = _decodeDataUrl(imageUrl);
        if (dataBytes != null) {
          imageResult = ProductLinkImageResult(
            imageUrl: imageUrl,
            imageBytes: dataBytes.bytes,
            contentType: dataBytes.contentType,
          );
        } else {
          throw Exception('Failed to decode inline image data');
        }
      } else {
        final imageResponse = await _client.get(
          Uri.parse(imageUrl),
          headers: _requestHeaders,
        );
        if (imageResponse.statusCode != 200) {
          throw Exception(
            'Failed to load product image (${imageResponse.statusCode})',
          );
        }

        imageResult = ProductLinkImageResult(
          imageUrl: imageUrl,
          imageBytes: imageResponse.bodyBytes,
          contentType: imageResponse.headers['content-type'],
        );
      }
    }

    final priceResult = _extractPrice(document);

    return ProductLinkMetadata(
      image: imageResult,
      price: priceResult?.amount,
      currency: priceResult?.currency,
    );
  }

  void dispose() {
    _client.close();
  }

  Uri? _parseUri(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.scheme.isEmpty) {
      return null;
    }
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      return null;
    }
    if (uri.host.isEmpty) {
      return null;
    }
    return uri;
  }

  String _decodeBody(http.Response response) {
    final contentType = response.headers['content-type'];
    Encoding encoding = utf8;
    if (contentType != null) {
      final charsetMatch = RegExp(
        'charset=([^;]+)',
        caseSensitive: false,
      ).firstMatch(contentType);
      if (charsetMatch != null) {
        final charset = charsetMatch.group(1)?.trim().toLowerCase();
        if (charset != null) {
          encoding = Encoding.getByName(charset) ?? utf8;
        }
      }
    }
    return encoding.decode(response.bodyBytes);
  }

  String? _extractImageUrl(dom.Document document, Uri pageUri) {
    final metaTags = document.getElementsByTagName('meta');
    final lookupKeys = <String>[
      'og:image',
      'og:image:url',
      'og:image:secure_url',
      'twitter:image',
      'twitter:image:src',
      'twitter:image:url',
      'image',
      'image:url',
      'thumbnail',
      'thumbnailurl',
    ];

    for (final key in lookupKeys) {
      final content = _findMetaContent(metaTags, key);
      final normalized = _normalizeImageUrl(pageUri, content);
      if (normalized != null) {
        return normalized;
      }
    }

    final linkUrl = _findLinkImageUrl(document, pageUri);
    if (linkUrl != null) {
      return linkUrl;
    }

    final structuredDataUrl = _extractImageFromStructuredData(
      document,
      pageUri,
    );
    if (structuredDataUrl != null) {
      return structuredDataUrl;
    }

    final preloadUrl = _extractFromPreloadLinks(document, pageUri);
    if (preloadUrl != null) {
      return preloadUrl;
    }

    final sourceUrl = _extractFromSourceElements(
      document.querySelectorAll(
        'source[srcset], source[data-srcset], source[data-src]',
      ),
      pageUri,
    );
    if (sourceUrl != null) {
      return sourceUrl;
    }

    final imageUrl = _extractFromImageElements(
      document.getElementsByTagName('img'),
      pageUri,
    );
    if (imageUrl != null) {
      return imageUrl;
    }

    final noscriptUrl = _extractImageFromNoscript(document, pageUri);
    if (noscriptUrl != null) {
      return noscriptUrl;
    }

    return null;
  }

  String? _findMetaContent(List<dom.Element> metaTags, String key) {
    final keyLower = key.toLowerCase();
    for (final meta in metaTags) {
      for (final attribute in ['property', 'name', 'itemprop']) {
        final value = meta.attributes[attribute]?.toLowerCase();
        if (value == keyLower) {
          final content =
              meta.attributes['content'] ?? meta.attributes['value'];
          if (content != null) {
            final trimmed = content.trim();
            if (trimmed.isNotEmpty) {
              return trimmed;
            }
          }
        }
      }
    }
    return null;
  }

  String? _findLinkImageUrl(dom.Document document, Uri pageUri) {
    final selectors = ["link[rel='image_src']", "link[itemprop='image']"];

    for (final selector in selectors) {
      final element = document.querySelector(selector);
      final href = element?.attributes['href'];
      final normalized = _normalizeImageUrl(pageUri, href);
      if (normalized != null) {
        return normalized;
      }
    }

    return null;
  }

  String? _extractFromPreloadLinks(dom.Document document, Uri pageUri) {
    final preloadLinks = document.querySelectorAll(
      "link[rel='preload'][as='image']",
    );
    for (final link in preloadLinks) {
      final href = link.attributes['href'];
      final normalized = _normalizeImageUrl(pageUri, href);
      if (normalized != null) {
        return normalized;
      }
    }
    return null;
  }

  String? _extractFromSourceElements(List<dom.Element> elements, Uri pageUri) {
    for (final element in elements) {
      final srcset =
          element.attributes['data-srcset'] ?? element.attributes['srcset'];
      final srcsetUrl = _pickBestSrcFromSrcset(pageUri, srcset);
      if (srcsetUrl != null) {
        return srcsetUrl;
      }

      final src = element.attributes['data-src'] ?? element.attributes['src'];
      final normalized = _normalizeImageUrl(pageUri, src);
      if (normalized != null) {
        return normalized;
      }
    }
    return null;
  }

  String? _extractFromImageElements(List<dom.Element> elements, Uri pageUri) {
    const attributeCandidates = [
      'data-zoom-image',
      'data-large_image',
      'data-large-image',
      'data-large-img',
      'data-hires',
      'data-highres',
      'data-old-hires',
      'data-default-src',
      'data-default-image',
      'data-src-large',
      'data-src-medium',
      'data-src-small',
      'data-srcset',
      'data-main-image',
      'data-image',
      'data-image-url',
      'data-original',
      'data-original-src',
      'data-desktop-src',
      'data-mobile-src',
      'data-asset-img',
      'data-preview-image',
      'data-photo',
      'data-img',
      'data-lazy',
      'data-lazy-src',
      'data-medium-image',
      'data-zoom-src',
      'data-src',
    ];

    for (final element in elements) {
      for (final attribute in attributeCandidates) {
        final value = element.attributes[attribute];
        final normalized = _normalizeImageUrl(pageUri, value);
        if (normalized != null) {
          return normalized;
        }
      }

      final srcset =
          element.attributes['data-srcset'] ?? element.attributes['srcset'];
      final srcsetUrl = _pickBestSrcFromSrcset(pageUri, srcset);
      if (srcsetUrl != null) {
        return srcsetUrl;
      }

      final src = element.attributes['src'];
      final normalizedSrc = _normalizeImageUrl(pageUri, src);
      if (normalizedSrc != null) {
        return normalizedSrc;
      }
    }
    return null;
  }

  String? _extractImageFromNoscript(dom.Document document, Uri pageUri) {
    final noscripts = document.getElementsByTagName('noscript');
    for (final noscript in noscripts) {
      final raw = noscript.text.trim();
      if (raw.isEmpty) {
        continue;
      }
      try {
        final fragment = html_parser.parseFragment(raw);
        final img = fragment.querySelector('img');
        if (img == null) {
          continue;
        }
        final attributes = [
          'data-zoom-image',
          'data-large_image',
          'data-large-image',
          'data-src',
          'src',
          'data-image',
          'data-image-url',
        ];
        for (final attribute in attributes) {
          final value = img.attributes[attribute];
          final normalized = _normalizeImageUrl(pageUri, value);
          if (normalized != null) {
            return normalized;
          }
        }
        final srcset =
            img.attributes['data-srcset'] ?? img.attributes['srcset'];
        final srcsetUrl = _pickBestSrcFromSrcset(pageUri, srcset);
        if (srcsetUrl != null) {
          return srcsetUrl;
        }
      } catch (_) {
        // Ignore invalid fragments.
      }
    }
    return null;
  }

  String? _pickBestSrcFromSrcset(Uri pageUri, String? srcset) {
    if (srcset == null) {
      return null;
    }
    final entries = srcset.split(',');
    String? best;
    var bestScore = -1.0;
    for (final entry in entries) {
      final parts = entry.trim().split(RegExp(r'\s+'));
      if (parts.isEmpty) {
        continue;
      }
      final urlPart = parts.first;
      var score = 0.0;
      if (parts.length > 1) {
        final descriptor = parts[1].toLowerCase();
        if (descriptor.endsWith('w')) {
          final value = double.tryParse(
            descriptor.substring(0, descriptor.length - 1),
          );
          if (value != null) {
            score = value;
          }
        } else if (descriptor.endsWith('x')) {
          final value = double.tryParse(
            descriptor.substring(0, descriptor.length - 1),
          );
          if (value != null) {
            score = value * 1000;
          }
        }
      }

      final normalized = _normalizeImageUrl(pageUri, urlPart);
      if (normalized != null && score >= bestScore) {
        bestScore = score;
        best = normalized;
      }
    }

    if (best != null) {
      return best;
    }

    if (entries.isNotEmpty) {
      final fallbackUrl = entries.last.trim().split(RegExp(r'\s+')).first;
      return _normalizeImageUrl(pageUri, fallbackUrl);
    }

    return null;
  }

  String? _extractImageFromStructuredData(dom.Document document, Uri pageUri) {
    final scripts = document.getElementsByTagName('script');
    for (final script in scripts) {
      final typeAttr = script.attributes['type']?.toLowerCase();
      final isStructuredData =
          typeAttr == null ||
          typeAttr.contains('ld+json') ||
          typeAttr == 'application/json';
      if (!isStructuredData) {
        continue;
      }

      final raw = script.text.trim();
      if (raw.isEmpty) {
        continue;
      }

      try {
        final decoded = jsonDecode(raw);
        final imageCandidate = _extractImageFromJson(decoded);
        final normalized = _normalizeImageUrl(pageUri, imageCandidate);
        if (normalized != null) {
          return normalized;
        }
      } catch (_) {
        // Ignore invalid JSON blobs.
      }
    }
    return null;
  }

  String? _extractImageFromJson(dynamic data) {
    if (data is String) {
      return data;
    }

    if (data is List) {
      for (final item in data) {
        final result = _extractImageFromJson(item);
        if (result != null) {
          return result;
        }
      }
      return null;
    }

    if (data is Map) {
      final typeValue = data['@type'];
      if (typeValue is String && typeValue.toLowerCase().contains('image')) {
        final urlValue = data['url'];
        if (urlValue is String && urlValue.trim().isNotEmpty) {
          return urlValue;
        }
      }

      const prioritizedKeys = [
        'image',
        'images',
        'imageUrl',
        'imageURL',
        'thumbnail',
        'thumbnailUrl',
        'thumbnailURL',
        'photo',
        'photos',
        'photoUrl',
        'photoURL',
        'media',
        'mediaUrl',
        'logo',
        'contentUrl',
        'contentURL',
        'url',
      ];

      for (final key in prioritizedKeys) {
        if (!data.containsKey(key)) {
          continue;
        }
        final result = _extractImageFromJson(data[key]);
        if (result != null) {
          if (key == 'url' && !_isLikelyImageUrl(result)) {
            continue;
          }
          return result;
        }
      }

      if (data.containsKey('@graph')) {
        final graphResult = _extractImageFromJson(data['@graph']);
        if (graphResult != null) {
          return graphResult;
        }
      }
    }

    return null;
  }

  _PriceExtractionResult? _extractPrice(dom.Document document) {
    double? amount;
    String? currency;

    final metaTags = document.getElementsByTagName('meta');
    for (final meta in metaTags) {
      final attributes = meta.attributes;
      final property = (attributes['property'] ??
              attributes['itemprop'] ??
              attributes['name'] ??
              '')
          .toLowerCase();
      final content = (attributes['content'] ?? attributes['value'] ?? '')
          .trim();
      if (content.isEmpty) {
        continue;
      }

      if (property.contains('price')) {
        final parsed = _parsePriceValue(content);
        if (parsed != null && amount == null) {
          amount = parsed;
        }
        if (currency == null) {
          currency = _detectCurrencyInText(content);
        }
      }

      if (property.contains('currency')) {
        final normalized = _normalizeCurrencyCode(content);
        if (normalized != null && currency == null) {
          currency = normalized;
        }
      }

      if (amount != null && currency != null) {
        break;
      }
    }

    if (amount != null && currency != null) {
      return _PriceExtractionResult(amount: amount, currency: currency);
    }

    final priceElements = document.querySelectorAll('[itemprop=price]');
    for (final element in priceElements) {
      final rawValue = (element.attributes['content'] ??
              element.attributes['value'] ??
              element.text)
          .trim();
      if (rawValue.isEmpty) {
        continue;
      }

      final parsed = _parsePriceValue(rawValue);
      if (parsed == null) {
        continue;
      }

      amount ??= parsed;

      final currencyCandidate =
          element.attributes['pricecurrency'] ??
              element.attributes['data-currency'] ??
              element.attributes['currency'] ??
              '';
      final normalizedCurrency = _normalizeCurrencyCode(currencyCandidate);
      if (normalizedCurrency != null && currency == null) {
        currency = normalizedCurrency;
      } else if (currency == null) {
        currency = _detectCurrencyInText(rawValue) ??
            _detectCurrencyInText(element.text);
      }

      if (amount != null && currency != null) {
        break;
      }
    }

    if (amount != null && currency != null) {
      return _PriceExtractionResult(amount: amount, currency: currency);
    }

    final scriptTags = document.getElementsByTagName('script');
    for (final script in scriptTags) {
      final typeAttr = script.attributes['type']?.toLowerCase();
      if (typeAttr != null &&
          !typeAttr.contains('ld+json') &&
          typeAttr != 'application/json') {
        continue;
      }

      final rawJson = script.text.trim();
      if (rawJson.isEmpty) {
        continue;
      }

      dynamic decoded;
      try {
        decoded = jsonDecode(rawJson);
      } catch (_) {
        final normalized = rawJson.replaceAll(RegExp(r'}\s*{'), '},{');
        final wrapped = '[$normalized]';
        try {
          decoded = jsonDecode(wrapped);
        } catch (_) {
          continue;
        }
      }

      final Iterable<dynamic> candidates =
          decoded is List ? decoded : <dynamic>[decoded];

      for (final candidate in candidates) {
        final result = _extractPriceFromJson(candidate);
        if (result == null) {
          continue;
        }
        amount ??= result.amount;
        currency ??= result.currency;
        if (amount != null && currency != null) {
          return _PriceExtractionResult(amount: amount, currency: currency);
        }
      }
    }

    if (amount != null) {
      return _PriceExtractionResult(amount: amount, currency: currency);
    }

    return null;
  }

  _PriceExtractionResult? _extractPriceFromJson(dynamic data) {
    if (data is List) {
      for (final item in data) {
        final result = _extractPriceFromJson(item);
        if (result != null) {
          return result;
        }
      }
      return null;
    }

    if (data is Map) {
      final lowerKeyed = <String, dynamic>{};
      data.forEach((key, value) {
        lowerKeyed[key.toString().toLowerCase()] = value;
      });

      if (lowerKeyed.containsKey('@graph')) {
        final graphResult = _extractPriceFromJson(lowerKeyed['@graph']);
        if (graphResult != null) {
          return graphResult;
        }
      }

      if (lowerKeyed.containsKey('offers')) {
        final offersResult = _extractPriceFromJson(lowerKeyed['offers']);
        if (offersResult != null) {
          return offersResult;
        }
      }

      if (lowerKeyed.containsKey('pricespecification')) {
        final specResult =
            _extractPriceFromJson(lowerKeyed['pricespecification']);
        if (specResult != null) {
          return specResult;
        }
      }

      double? amount;
      String? currency;

      final priceCandidate = lowerKeyed['price'] ??
          lowerKeyed['lowprice'] ??
          lowerKeyed['highprice'] ??
          lowerKeyed['priceamount'];
      if (priceCandidate != null) {
        final parsed = _parsePriceValue(_stringifyJsonValue(priceCandidate));
        if (parsed != null) {
          amount = parsed;
          currency = _detectCurrencyInText(_stringifyJsonValue(priceCandidate));
        }
      }

      if (amount == null && lowerKeyed['amount'] != null) {
        final parsed = _parsePriceValue(_stringifyJsonValue(lowerKeyed['amount']));
        if (parsed != null) {
          amount = parsed;
        }
      }

      if (lowerKeyed.containsKey('pricecurrency')) {
        final normalized = _normalizeCurrencyCode(
          _stringifyJsonValue(lowerKeyed['pricecurrency']),
        );
        if (normalized != null) {
          currency ??= normalized;
        }
      }

      if (lowerKeyed.containsKey('currency')) {
        final normalized =
            _normalizeCurrencyCode(_stringifyJsonValue(lowerKeyed['currency']));
        if (normalized != null) {
          currency ??= normalized;
        }
      }

      if (lowerKeyed.containsKey('currenciesaccepted')) {
        final normalized = _normalizeCurrencyCode(
          _stringifyJsonValue(lowerKeyed['currenciesaccepted']),
        );
        if (normalized != null) {
          currency ??= normalized;
        }
      }

      if (amount != null) {
        return _PriceExtractionResult(amount: amount, currency: currency);
      }

      return null;
    }

    if (data is String) {
      final parsed = _parsePriceValue(data);
      if (parsed != null) {
        return _PriceExtractionResult(
          amount: parsed,
          currency: _detectCurrencyInText(data),
        );
      }
    }

    return null;
  }

  String _stringifyJsonValue(dynamic value) {
    if (value == null) {
      return '';
    }
    if (value is String) {
      return value;
    }
    if (value is num) {
      return value.toString();
    }
    if (value is List && value.isNotEmpty) {
      return _stringifyJsonValue(value.first);
    }
    return value.toString();
  }

  double? _parsePriceValue(String? raw) {
    if (raw == null) {
      return null;
    }
    var sanitized = raw.replaceAll(RegExp(r'[^0-9,.-]'), '');
    if (sanitized.isEmpty) {
      return null;
    }

    final lastComma = sanitized.lastIndexOf(',');
    final lastDot = sanitized.lastIndexOf('.');

    if (lastComma != -1 && lastDot != -1) {
      if (lastComma > lastDot) {
        sanitized = sanitized.replaceAll('.', '');
        sanitized = sanitized.replaceAll(',', '.');
      } else {
        sanitized = sanitized.replaceAll(',', '');
      }
    } else if (lastComma != -1) {
      final decimals = sanitized.length - lastComma - 1;
      if (decimals > 0 && decimals <= 2) {
        sanitized =
            sanitized.replaceRange(lastComma, lastComma + 1, '.');
      }
      sanitized = sanitized.replaceAll(',', '');
    } else if (lastDot != -1) {
      final decimals = sanitized.length - lastDot - 1;
      if (decimals > 2) {
        sanitized = sanitized.replaceAll('.', '');
      }
    }

    sanitized = sanitized.replaceAll('--', '-');

    return double.tryParse(sanitized);
  }

  String? _normalizeCurrencyCode(String? raw) {
    if (raw == null) {
      return null;
    }
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final symbolMap = <String, String>{
      '\u20BA': 'TRY',
      'TRY': 'TRY',
      'TL': 'TRY',
      '\u20A4': 'GBP',
      '\u00A3': 'GBP',
      '\u20AC': 'EUR',
      'EUR': 'EUR',
      r'US$': 'USD',
      'USD': 'USD',
      r'$': 'USD',
      'CAD': 'CAD',
      r'C$': 'CAD',
      r'CA$': 'CAD',
      'AUD': 'AUD',
      r'A$': 'AUD',
      r'AU$': 'AUD',
      '\u20BD': 'RUB',
      'RUB': 'RUB',
      '\u00A5': 'JPY',
      'JPY': 'JPY',
      '\u20A9': 'KRW',
      'KRW': 'KRW',
      '\u20B9': 'INR',
      'INR': 'INR',
    };

    for (final entry in symbolMap.entries) {
      if (trimmed.contains(entry.key)) {
        return entry.value;
      }
      if (trimmed.toUpperCase() == entry.key) {
        return entry.value;
      }
    }

    final lettersOnly =
        trimmed.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    if (lettersOnly.isEmpty) {
      return null;
    }
    if (lettersOnly == 'TL') {
      return 'TRY';
    }
    if (lettersOnly.length == 3) {
      return lettersOnly;
    }

    final match = RegExp(r'[A-Z]{3}').firstMatch(lettersOnly);
    if (match != null) {
      final code = match.group(0);
      if (code == 'TL') {
        return 'TRY';
      }
      return code;
    }

    return null;
  }

  String? _detectCurrencyInText(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return _normalizeCurrencyCode(raw);
  }

  String? _normalizeImageUrl(Uri pageUri, String? rawUrl) {
    if (rawUrl == null) {
      return null;
    }
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (trimmed.startsWith('//')) {
      return '${pageUri.scheme}:$trimmed';
    }
    final parsed = Uri.tryParse(trimmed);
    if (parsed == null) {
      return null;
    }
    String normalized;
    if (parsed.hasScheme) {
      normalized = parsed.toString();
    } else {
      normalized = pageUri.resolveUri(parsed).toString();
    }
    if (normalized == pageUri.toString()) {
      return null;
    }
    if (!_isDataUrl(normalized) && !_isLikelyImageUrl(normalized)) {
      return null;
    }
    return normalized;
  }

  bool _isLikelyImageUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.startsWith('data:image/')) {
      return true;
    }
    const extensions = [
      '.jpg',
      '.jpeg',
      '.png',
      '.webp',
      '.gif',
      '.bmp',
      '.svg',
      '.avif',
      '.heic',
      '.heif',
      '.jfif',
    ];
    for (final ext in extensions) {
      if (lower.contains(ext)) {
        return true;
      }
    }
    return lower.contains('/image') || lower.contains('/img');
  }

  bool _isDataUrl(String url) {
    return url.startsWith('data:');
  }

  _DataUrlResult? _decodeDataUrl(String dataUrl) {
    final match = RegExp(
      r'^data:([^;,]+)?(;base64)?,(.*)$',
      caseSensitive: false,
    ).firstMatch(dataUrl.trim());
    if (match == null) {
      return null;
    }

    final mimeType = match.group(1) ?? 'image/jpeg';
    final isBase64 = match.group(2)?.contains('base64') ?? false;
    final dataPart = match.group(3) ?? '';

    if (isBase64) {
      try {
        final decoded = base64.decode(dataPart);
        return _DataUrlResult(
          bytes: Uint8List.fromList(decoded),
          contentType: mimeType,
        );
      } catch (_) {
        return null;
      }
    }

    final bytes = utf8.encode(Uri.decodeFull(dataPart));
    return _DataUrlResult(
      bytes: Uint8List.fromList(bytes),
      contentType: mimeType,
    );
  }
}

class _DataUrlResult {
  _DataUrlResult({required this.bytes, required this.contentType});

  final Uint8List bytes;
  final String contentType;
}

class _PriceExtractionResult {
  const _PriceExtractionResult({required this.amount, this.currency});

  final double amount;
  final String? currency;
}
