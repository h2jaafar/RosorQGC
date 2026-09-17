import QtQml.Models

import QGroundControl
import QGroundControl.Controls

ListModel {
    ListElement {
        name: qsTr("General")
        url: "qrc:/qml/QGroundControl/AppSettings/GeneralSettings.qml"
        iconUrl: "qrc:/res/RosorLogo.png"
        pageVisible: function() { return true }
    }

    ListElement {
        name: qsTr("Fly View")
        url: "qrc:/qml/QGroundControl/AppSettings/FlyViewSettings.qml"
        iconUrl: "qrc:/qmlimages/PaperPlane.svg"
        pageVisible: function() { return true }
    }

    ListElement {
        name: qsTr("Plan View")
        url: "qrc:/qml/QGroundControl/AppSettings/PlanViewSettings.qml"
        iconUrl: "qrc:/qmlimages/Plan.svg"
        pageVisible: function() { return true }
    }

    ListElement {
        name: qsTr("Video")
        url: "qrc:/qml/QGroundControl/AppSettings/VideoSettings.qml"
        iconUrl: "qrc:/InstrumentValueIcons/camera.svg"
        pageVisible: function() { return QGroundControl.settingsManager.videoSettings.visible }
    }

    ListElement {
        name: "Divider"
    }

    ListElement {
        name: qsTr("ADSB Server")
        url: "qrc:/qml/QGroundControl/AppSettings/ADSBServerSettings.qml"
        iconUrl: "qrc:/InstrumentValueIcons/airplane.svg"
        // Engineer pages (ADSB Server, Remote ID, Telemetry) show in Advanced mode
        // only. An operator sees General, Fly View, Plan View, Video, Comm Links,
        // Maps, NTRIP/RTK, Help and About.
        pageVisible: function() { return QGroundControl.corePlugin.showAdvancedUI }
    }

    ListElement {
        name: qsTr("Comm Links")
        url: "qrc:/qml/QGroundControl/AppSettings/LinkSettings.qml"
        iconUrl: "qrc:/InstrumentValueIcons/usb.svg"
        pageVisible: function() { return true }
    }

    ListElement {
        name: qsTr("Logging")
        url: "qrc:/qml/QGroundControl/Controls/AppLogging.qml"
        iconUrl: "qrc:/InstrumentValueIcons/conversation.svg"
        pageVisible: function() { return true }
    }

    ListElement {
        name: qsTr("Maps")
        url: "qrc:/qml/QGroundControl/AppSettings/MapSettings.qml"
        iconUrl: "qrc:/InstrumentValueIcons/globe.svg"
        pageVisible: function() { return true }
    }

    ListElement {
        name: qsTr("NTRIP/RTK")
        url: "qrc:/qml/QGroundControl/AppSettings/NTRIPSettings.qml"
        iconUrl: "qrc:/InstrumentValueIcons/globe.svg"
        pageVisible: function() {
            return QGroundControl.settingsManager &&
                   QGroundControl.settingsManager.ntripSettings !== undefined
        }
    }

    ListElement {
        name: qsTr("PX4 Log Transfer")
        url: "qrc:/qml/QGroundControl/AppSettings/PX4LogTransferSettings.qml"
        iconUrl: "qrc:/InstrumentValueIcons/inbox-download.svg"
        pageVisible: function() {
            var activeVehicle = QGroundControl.multiVehicleManager.activeVehicle
            return QGroundControl.corePlugin.options.showPX4LogTransferOptions &&
                        QGroundControl.px4ProFirmwareSupported &&
                        (activeVehicle ? activeVehicle.px4Firmware : true)
        }
    }

    ListElement {
        name: qsTr("Remote ID")
        url: "qrc:/qml/QGroundControl/AppSettings/RemoteIDSettings.qml"
        iconUrl: "qrc:/qmlimages/RidIconManNoID.svg"
        pageVisible: function() { return QGroundControl.corePlugin.showAdvancedUI }
    }

    ListElement {
        name: qsTr("Telemetry")
        url: "qrc:/qml/QGroundControl/AppSettings/TelemetrySettings.qml"
        iconUrl: "qrc:/InstrumentValueIcons/drone.svg"
        pageVisible: function() { return QGroundControl.corePlugin.showAdvancedUI }
    }

    ListElement {
        name: "Divider"
    }

    ListElement {
        name: qsTr("Help")
        url: "qrc:/qml/QGroundControl/AppSettings/HelpSettings.qml"
        iconUrl: "qrc:/InstrumentValueIcons/question.svg"
        pageVisible: function() { return true }
    }
    ListElement {
        name: qsTr("About")
        url: "qrc:/qml/QGroundControl/AppSettings/AboutSettings.qml"
        iconUrl: "qrc:/res/RosorLogo.png"
        pageVisible: function() { return true }
    }

    ListElement {
        name: "Divider"
    }

    ListElement {
        name: qsTr("Mock Link")
        url: "qrc:/qml/QGroundControl/AppSettings/MockLink.qml"
        iconUrl: "qrc:/InstrumentValueIcons/drone.svg"
        pageVisible: function() { return ScreenTools.isDebug }
    }

    ListElement {
        name: qsTr("Debug")
        url: "qrc:/qml/QGroundControl/AppSettings/DebugWindow.qml"
        iconUrl: "qrc:/InstrumentValueIcons/bug.svg"
        pageVisible: function() { return ScreenTools.isDebug }
    }

    ListElement {
        name: qsTr("Palette Test")
        url: "qrc:/qml/QGroundControl/AppSettings/QmlTest.qml"
        iconUrl: "qrc:/InstrumentValueIcons/photo.svg"
        pageVisible: function() { return ScreenTools.isDebug }
    }
}
