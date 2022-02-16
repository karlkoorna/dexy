if [ ! -f dexy.sh ]; then
	echo "Must be run from the project folder!"
	exit 1
fi

if [[ ! $(command -v java) || ! $(command -v keytool) || ! $(command -v jarsigner) ]]; then
	echo "Java JDK not installed!"
	exit 1
fi

if [[ ! $(command -v adb) ]]; then
	echo "Android Debug Bridge not installed!"
	exit 1
fi

if [[ $(adb devices | wc -l) -lt 3 ]]; then
	echo "Device not connected!"
	exit 1
fi

if [[ $(adb devices | wc -l) -gt 3 ]]; then
	echo "Multiple devices conected!"
	exit 1
fi

APK_PATH=$(adb shell pm path com.dexcom.dexcomone | cut -c 10- | sed "s#/#//#g")

if [[ ! $APK_PATH ]]; then
	echo "App not installed!"
	exit 1
fi

rm -r tmp/

echo "Downloading apktool..."
curl -s -S -L -o tmp/apktool.jar https://github.com/iBotPeaches/Apktool/releases/download/v2.6.0/apktool_2.6.0.jar

if [[ $? -ne 0 ]]; then
	echo "Failed to download!"
	exit 1
fi

echo "Pulling app from device..."
adb pull $APK_PATH tmp/app.apk &> /dev/null

if [[ $? -ne 0 ]]; then
	echo "Failed to pull!"
	exit 1
fi

echo "Decompiling app..."
java -jar tmp/apktool.jar d -f -o tmp/app tmp/app.apk > /dev/null

if [[ $? -ne 0 ]]; then
	echo "Failed to decompile!"
	exit 1
fi

echo "Patching app..."
sed -i 's#.end param#.end param\ninvoke-virtual {p0}, Lcom/dexcom/dexcomone/ui/acm/AcmActivity;->finish()V#' tmp/app/smali_classes2/com/dexcom/dexcomone/ui/acm/AcmActivity.smali
# sed -i -E 's#(<application.+)>#\1 android:networkSecurityConfig="@xml/network_security_config">#' tmp/app/AndroidManifest.xml &&
# cp network_security_config.xml tmp/app/res/xml/

if [[ $? -ne 0 ]]; then
	echo "Failed to patch!"
	exit 1
fi

echo "Compiling app..."
java -jar tmp/apktool.jar b --use-aapt2 -o tmp/app-patched.apk tmp/app > /dev/null

if [[ $? -ne 0 ]]; then
	echo "Failed to compile!"
	exit 1
fi

echo "Signing app..."
keytool -genkey -keystore tmp/keystore -storepass password -keyalg EC -groupname secp384r1 -alias Dexy -dname "CN=Dexy, OU=Dexy, O=Dexy, L=Dexy, S=Dexy, C=XX" > /dev/null &&
jarsigner -keystore tmp/keystore -storepass password -sigalg SHA256withECDSA -digestalg SHA-256 tmp/app-patched.apk Dexy > /dev/null

if [[ $? -ne 0 ]]; then
	echo "Failed to sign!"
	exit 1
fi

echo "Installing app..."

adb uninstall com.dexcom.dexcomone > /dev/null &&
adb install tmp/app-patched.apk &> /dev/null
adb shell am start -n com.dexcom.dexcomone/com.dexcom.phoenix.ui.SplashActivity > /dev/null

rm -r tmp/
echo "Done"
