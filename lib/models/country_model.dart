import 'package:country_picker/country_picker.dart';

class CountryModel {
  const CountryModel({
    required this.name,
    required this.isoCode,
    required this.dialCode,
    this.minNationalLength = 7,
    this.maxNationalLength = 15,
    this.flagEmoji,
  });

  final String name;
  final String isoCode;
  final String dialCode;
  final int minNationalLength;
  final int maxNationalLength;
  final String? flagEmoji;

  factory CountryModel.fromCountry(Country country) {
    final isIndia = country.countryCode == 'IN';
    final isUs = country.countryCode == 'US';
    return CountryModel(
      name: country.name,
      isoCode: country.countryCode,
      dialCode: '+${country.phoneCode}',
      flagEmoji: country.flagEmoji,
      minNationalLength: isIndia || isUs ? 10 : 7,
      maxNationalLength: isUs ? 10 : (isIndia ? 10 : 15),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CountryModel &&
          runtimeType == other.runtimeType &&
          isoCode == other.isoCode &&
          dialCode == other.dialCode;

  @override
  int get hashCode => Object.hash(isoCode, dialCode);

  static const CountryModel defaultCountry = CountryModel(
    name: 'India',
    isoCode: 'IN',
    dialCode: '+91',
    minNationalLength: 10,
    maxNationalLength: 10,
    flagEmoji: '🇮🇳',
  );
}
