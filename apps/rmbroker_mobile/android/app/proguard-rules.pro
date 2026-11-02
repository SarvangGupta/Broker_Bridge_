# google_mlkit_text_recognition references the optional Chinese, Devanagari,
# Japanese and Korean recognizers. The app uses only Latin (GST/cheque OCR),
# so those packs are not bundled; R8 must not fail on the missing classes.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
