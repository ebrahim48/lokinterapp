# Pusher's Java SDK logs through slf4j, whose binding class isn't shipped —
# R8 flags it in release. Nothing uses the binding, so silence it.
-dontwarn org.slf4j.**

# flutter_stripe bundles the RN Stripe SDK, which references Stripe's optional
# push-provisioning (Google Pay card) classes we don't ship. R8 can't find them
# in release; the feature is unused, so keep the API and silence the warnings.
-keep class com.stripe.android.pushProvisioning.** { *; }
-dontwarn com.stripe.android.pushProvisioning.**
-dontwarn com.reactnativestripesdk.**
