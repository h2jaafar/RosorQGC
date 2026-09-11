#include "AndroidInterface.h"
#include "QGCLoggingCategory.h"

#include <QtCore/QJniObject>
#include <QtCore/QJniEnvironment>

QGC_LOGGING_CATEGORY(AndroidInterfaceLog, "qgc.android.src.androidinterface")

namespace AndroidInterface
{

QList<QPair<QString, QString>> getBondedBluetoothDevices()
{
    QList<QPair<QString, QString>> devices;

    const QJniObject adapter = QJniObject::callStaticObjectMethod(
        "android/bluetooth/BluetoothAdapter", "getDefaultAdapter",
        "()Landroid/bluetooth/BluetoothAdapter;");
    if (!adapter.isValid()) {
        (void) cleanJavaException();
        qCWarning(AndroidInterfaceLog) << "No default Bluetooth adapter";
        return devices;
    }

    const QJniObject bonded = adapter.callObjectMethod("getBondedDevices", "()Ljava/util/Set;");
    if (!bonded.isValid()) {
        // Thrown rather than returned when BLUETOOTH_CONNECT has not been granted.
        (void) cleanJavaException();
        return devices;
    }

    const QJniObject iterator = bonded.callObjectMethod("iterator", "()Ljava/util/Iterator;");
    if (!iterator.isValid()) {
        (void) cleanJavaException();
        return devices;
    }

    while (iterator.callMethod<jboolean>("hasNext")) {
        const QJniObject device = iterator.callObjectMethod("next", "()Ljava/lang/Object;");
        if (!device.isValid()) {
            continue;
        }

        const QJniObject address = device.callObjectMethod("getAddress", "()Ljava/lang/String;");
        if (!address.isValid()) {
            continue;
        }

        const QJniObject name = device.callObjectMethod("getName", "()Ljava/lang/String;");
        devices.append(qMakePair(address.toString(), name.isValid() ? name.toString() : QString()));
    }

    (void) cleanJavaException();

    return devices;
}

bool cleanJavaException()
{
    QJniEnvironment jniEnv;
    const bool result = jniEnv.checkAndClearExceptions();
    return result;
}

jclass getActivityClass()
{
    static jclass javaClass = nullptr;

    if (!javaClass) {
        QJniEnvironment env;
        if (!env.isValid()) {
            qCWarning(AndroidInterfaceLog) << "Invalid QJniEnvironment";
            return nullptr;
        }

        if (!QJniObject::isClassAvailable(kJniQGCActivityClassName)) {
            qCWarning(AndroidInterfaceLog) << "Class Not Available";
            return nullptr;
        }

        javaClass = env.findClass(kJniQGCActivityClassName);
        if (!javaClass) {
            qCWarning(AndroidInterfaceLog) << "Class Not Found";
            return nullptr;
        }

        env.checkAndClearExceptions();
    }

    return javaClass;
}

void setNativeMethods()
{
    qCDebug(AndroidInterfaceLog) << "Registering Native Functions";

    JNINativeMethod javaMethods[] {
        {"qgcLogDebug",   "(Ljava/lang/String;)V", reinterpret_cast<void *>(jniLogDebug)},
        {"qgcLogWarning", "(Ljava/lang/String;)V", reinterpret_cast<void *>(jniLogWarning)}
    };

    (void) AndroidInterface::cleanJavaException();

    jclass objectClass = AndroidInterface::getActivityClass();
    if(!objectClass) {
        qCWarning(AndroidInterfaceLog) << "Couldn't find class:" << objectClass;
        return;
    }

    QJniEnvironment jniEnv;
    jint val = jniEnv->RegisterNatives(objectClass, javaMethods, std::size(javaMethods));

    if (val < 0) {
        qCWarning(AndroidInterfaceLog) << "Error registering methods:" << val;
    } else {
        qCDebug(AndroidInterfaceLog) << "Native Functions Registered";
    }

    (void) AndroidInterface::cleanJavaException();
}

void jniLogDebug(JNIEnv *envA, jobject thizA, jstring messageA)
{
    Q_UNUSED(thizA);

    const char * const stringL = envA->GetStringUTFChars(messageA, nullptr);
    const QString logMessage = QString::fromUtf8(stringL);
    envA->ReleaseStringUTFChars(messageA, stringL);
    (void) QJniEnvironment::checkAndClearExceptions(envA);
    qCDebug(AndroidInterfaceLog) << logMessage;
}

void jniLogWarning(JNIEnv *envA, jobject thizA, jstring messageA)
{
    Q_UNUSED(thizA);

    const char * const stringL = envA->GetStringUTFChars(messageA, nullptr);
    const QString logMessage = QString::fromUtf8(stringL);
    envA->ReleaseStringUTFChars(messageA, stringL);
    (void) QJniEnvironment::checkAndClearExceptions(envA);
    qCWarning(AndroidInterfaceLog) << logMessage;
}

bool checkStoragePermissions()
{
    // Call the Java method to check and request storage permissions
    const bool hasPermission = QJniObject::callStaticMethod<jboolean>(
        kJniQGCActivityClassName,
        "checkStoragePermissions",
        "()Z"
    );

    if (hasPermission) {
        qCDebug(AndroidInterfaceLog) << "Storage permissions granted";
    } else {
        qCWarning(AndroidInterfaceLog) << "Storage permissions not granted";
    }

    return hasPermission;
}

QString getSDCardPath()
{
    if (!checkStoragePermissions()) {
        qCWarning(AndroidInterfaceLog) << "Storage Permission Denied";
        return QString();
    }

    const QJniObject result = QJniObject::callStaticObjectMethod(kJniQGCActivityClassName, "getSDCardPath", "()Ljava/lang/String;");
    if (!result.isValid()) {
        qCWarning(AndroidInterfaceLog) << "Call to java getSDCardPath failed: Invalid Result";
        return QString();
    }

    return result.toString();
}

void setKeepScreenOn(bool on)
{
    Q_UNUSED(on);

    //-- Screen is locked on while QGC is running on Android
}

} // namespace AndroidInterface
