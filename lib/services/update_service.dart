import 'package:flutter/material.dart';
import 'package:upgrader/upgrader.dart';

class UpdateService {
  static Widget wrapWithUpdateChecker(BuildContext context, Widget child) {
    return UpgradeAlert(
      upgrader: Upgrader(),
      dialogStyle: UpgradeDialogStyle.material,
      showIgnore: false,
      shouldPopScope: () => false,
      barrierDismissible: false,
      child: child,
    );
  }
}
