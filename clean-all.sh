

# Detener todos los procesos de Gradle
pkill -f gradle

# Limpiar papelera
sudo rm -rf ~/.Trash/*

# Limpiar cachés temporales del sistema
sudo rm -rf /tmp/*
rm -rf ~/Library/Caches/*

flutter clean

rm -rf ~/.gradle/caches/
rm -rf ~/.gradle/daemon/
rm -rf ~/.gradle/wrapper/

rm -rf android/.gradle
rm -rf android/app/build
rm -rf android/build

rm -rf ~/.gradle

# Limpiar derivedData de Xcode (puede ser varios GB)
#rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Limpiar simuladores iOS antiguos
#xcrun simctl delete unavailable

flutter clean

# Limpiar caché de pub
flutter pub cache clean

flutter pub get
