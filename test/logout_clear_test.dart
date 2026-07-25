import 'package:flutter_task/core/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Logout must wipe everything tied to the account so the next login starts
// clean, while app-level settings (theme, language, onboarding) survive.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('clearAccountData drops account keys, keeps app settings', () async {
    SharedPreferences.setMockInitialValues({
      StorageKeys.authToken: 'tok',
      StorageKeys.refreshToken: 'ref',
      StorageKeys.userJson: '{"id":1}',
      StorageKeys.isLoggedIn: true,
      StorageKeys.userId: '1',
      StorageKeys.userEmail: 'a@b.com',
      'some_future_account_key': 'leak',
      StorageKeys.isDarkMode: true,
      StorageKeys.selectedLanguage: 'en',
      StorageKeys.isFirstLaunch: false,
    });
    final storage = StorageService();
    await storage.init();

    await storage.clearAccountData();

    // account data gone — including keys not explicitly listed anywhere
    expect(storage.getString(StorageKeys.authToken), isNull);
    expect(storage.getString(StorageKeys.userJson), isNull);
    expect(storage.getString(StorageKeys.userEmail), isNull);
    expect(storage.containsKey('some_future_account_key'), isFalse);
    expect(storage.getBool(StorageKeys.isLoggedIn), isNull);

    // app-level settings preserved
    expect(storage.getBool(StorageKeys.isDarkMode), isTrue);
    expect(storage.getString(StorageKeys.selectedLanguage), 'en');
    expect(storage.getBool(StorageKeys.isFirstLaunch), isFalse);
  });
}
