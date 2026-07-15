# Pusher's Java SDK logs through slf4j, whose binding class isn't shipped —
# R8 flags it in release. Nothing uses the binding, so silence it.
-dontwarn org.slf4j.**
