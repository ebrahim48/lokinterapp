import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_task/features/auth/data/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

// Verifies the Step-2 transporter multipart body matches the API spec:
// isTransporter text "true", operatingCountries as a JSON string, legalName +
// address text, transportLicense as its own file, businessDocuments[] indexed.
void main() {
  test('transporter step 2 builds the spec multipart', () async {
    final dir = Directory.systemTemp.createTempSync('reg_test');
    final license = File('${dir.path}/license.pdf')..writeAsStringSync('x');
    final legal = File('${dir.path}/legal.pdf')..writeAsStringSync('y');
    PlatformFile pf(File f) =>
        PlatformFile(name: f.uri.pathSegments.last, size: f.lengthSync(), path: f.path);

    final form = await AuthRepository.transporterStep2(
      fields: {
        'firstName': 'John',
        'lastName': 'Doe',
        'country': 'US',
        'phone': '5512345678',
        'email': 'john.doe@example.com',
        'password': 'Passw0rd!',
      },
      otp: '4821',
      operatingCountries: ['US', 'FR', 'SN'],
      legalName: 'Acme Logistics LLC',
      address: '12 Market Street, Dakar',
      transportLicense: pf(license),
      businessDocuments: [pf(legal)],
    );

    final fields = {for (final e in form.fields) e.key: e.value};
    expect(fields['step'], '2');
    expect(fields['firstName'], 'John');
    expect(fields['country'], 'US');
    expect(fields['otp'], '4821');
    expect(fields['isTransporter'], 'true'); // text, not 1/0
    expect(fields['operatingCountries'], '["US","FR","SN"]'); // JSON string, one field
    expect(fields['legalName'], 'Acme Logistics LLC');
    expect(fields['address'], '12 Market Street, Dakar');
    // operatingCountries must NOT be bracket-indexed
    expect(form.fields.any((e) => e.key.startsWith('operatingCountries[')), isFalse);

    final fileKeys = form.files.map((e) => e.key).toList();
    expect(fileKeys, contains('transportLicense'));
    expect(fileKeys, contains('businessDocuments[0]'));

    dir.deleteSync(recursive: true);
  });
}
