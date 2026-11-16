# Pusher's Java SDK logs through slf4j, whose binding class isn't shipped —
# R8 flags it in release. Nothing uses the binding, so silence it.
-dontwarn org.slf4j.**

# firebase_messaging: internal helper classes were reorganised in newer plugin
# versions; older compiled bytecode still references them. R8 flags them as
# missing in release — silence the warnings so the build succeeds.
-dontwarn io.flutter.plugins.firebase.messaging.ErrorCallback
-dontwarn io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingBackgroundExecutor
-dontwarn io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingUtils
-dontwarn io.flutter.plugins.firebase.messaging.FlutterFirebasePermissionManager$RequestPermissionsSuccessCallback
-dontwarn io.flutter.plugins.firebase.messaging.FlutterFirebasePermissionManager
-dontwarn io.flutter.plugins.firebase.messaging.FlutterFirebaseRemoteMessageLiveData
-dontwarn io.flutter.plugins.firebase.messaging.JobIntentService

# flutter_stripe bundles the RN Stripe SDK, which references Stripe's optional
# push-provisioning (Google Pay card) classes we don't ship. R8 can't find them
# in release; the feature is unused, so keep the API and silence the warnings.
-keep class com.stripe.android.pushProvisioning.** { *; }
-dontwarn com.stripe.android.pushProvisioning.**
-dontwarn com.reactnativestripesdk.**
