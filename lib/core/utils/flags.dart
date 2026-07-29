// Maps a country or known city to an ISO-3166 alpha-2 code for the flag widget.
// (Emoji flags don't render on Android, so we use a flag package keyed by code.)
const _countryCode = {
  'Tunisia': 'TN',
  'France': 'FR',
  'Turkey': 'TR',
  'Qatar': 'QA',
  'Egypt': 'EG',
  'Germany': 'DE',
  'Italy': 'IT',
  'Spain': 'ES',
};

const _cityCountry = {
  'Tunis': 'Tunisia',
  'Sfax': 'Tunisia',
  'Sousse': 'Tunisia',
  'Paris': 'France',
  'Marseille': 'France',
  'Lyon': 'France',
  'Lille': 'France',
  'Istanbul': 'Turkey',
};

// Null when the place isn't recognised — callers hide the flag rather than
// show the wrong country (the own-posts endpoint sends no ISO code at all).
String? countryCodeFor(String place) {
  final country = _countryCode.containsKey(place) ? place : _cityCountry[place];
  return _countryCode[country];
}
