import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Registers the licences of assets bundled in lcd_kit (the OFL Silkscreen
/// font) so they appear on the app's licence page.
void registerLcdKitLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      ['Silkscreen font'],
      await rootBundle.loadString(
        'packages/lcd_kit/assets/fonts/Silkscreen-OFL.txt',
      ),
    );
  });
}
