import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../core/notifications/push.dart';
import '../../core/router/routes.dart';
import '../../core/state/session.dart';
import '../../core/utils/json.dart';

/// Sends a signed-in Pandit to the right screen for their KYC status
/// (replaces the `navigation.reset(...)` blocks in Splash / Verify /
/// WaitingForApproval).
void goToDestination(BuildContext context, Json? user, {bool isNewAccount = false}) {
  final dest = destinationFor(user, isNewAccount: isNewAccount);
  if (dest == AuthDestination.home || dest == AuthDestination.intro || dest == AuthDestination.referral) {
    Push.registerToken();
  }
  switch (dest) {
    case AuthDestination.home:
      context.go(R.home);
    case AuthDestination.intro:
      context.go(R.intro);
    case AuthDestination.referral:
      context.go(R.referral);
    case AuthDestination.profileInfo:
      context.go(R.profileInfo);
    case AuthDestination.waiting:
      context.go(R.waiting);
  }
}
