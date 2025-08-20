#!/bin/bash
set -e

echo "🚀 Building Flutter Web app..."
flutter pub get
flutter build web --release --base-href "/tv-tracker/"

echo "🚀 Deploying to GitHub Pages..."
flutter pub global run peanut

git push origin gh-pages --force

echo "✅ Deployed! Visit:"
echo "   https://maxpaxio.github.io/TV-Tracker/"
