#pragma once

#include <QtCore/QString>
#include <QtCore/QList>
#include <QtCore/QPair>
#include <QtCore/QLoggingCategory>

#include <jni.h>

Q_DECLARE_LOGGING_CATEGORY(AndroidInterfaceLog)

namespace AndroidInterface
{
    bool cleanJavaException();
    jclass getActivityClass();
    void setNativeMethods();
    void jniLogDebug(JNIEnv *envA, jobject thizA, jstring messageA);
    void jniLogWarning(JNIEnv *envA, jobject thizA, jstring messageA);
    bool checkStoragePermissions();
    QString getSDCardPath();
    void setKeepScreenOn(bool on);

    /// Addresses and names of the adapter's bonded (paired) Bluetooth devices.
    /// Qt exposes pairingStatus() for a known address but has no way to enumerate
    /// bonds, so this goes at BluetoothAdapter.getBondedDevices() directly.
    /// Requires BLUETOOTH_CONNECT on API 31+; returns empty without it.
    QList<QPair<QString, QString>> getBondedBluetoothDevices();

    constexpr const char *kJniQGCActivityClassName = "ca/rosor/qgc/QGCActivity";
};
