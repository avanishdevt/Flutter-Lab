#!/bin/zsh
# Usage: ./run_chrome.sh 01   (runs exp01 on Chrome)
set -e
SRC="$(cd "$(dirname "$0")" && pwd)"
F=$(ls "$SRC"/exp$1_*_main.dart)
APP="$SRC/chrome_app"
[ -d "$APP" ] || flutter create --platforms=web "$APP"
cd "$APP"
case "$1" in
  05) flutter pub add provider ;;
  06) flutter pub add sqflite path sqflite_common_ffi_web; dart run sqflite_common_ffi_web:setup ;;
  07|08|09) flutter pub add firebase_core cloud_firestore ;;
  10) flutter pub add firebase_core cloud_firestore crypto ;;
esac
cp "$F" lib/main.dart
[ -f lib/firebase_options.dart ] || { [[ "$1" -ge 7 ]] && echo "Run 'flutterfire configure' in $APP (select Web) first." && exit 1; }
flutter run -d chrome "${@:2}"
