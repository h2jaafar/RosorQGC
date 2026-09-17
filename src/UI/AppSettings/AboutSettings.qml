import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

/// About: what this app is, which build it is, who to call, where the logs are,
/// and the licence notice a GPL derivative owes its users. Until this page the
/// version lived only at the bottom of the application menu and the licence
/// files were referenced from nowhere in the app.
Rectangle {
    color:          qgcPal.window
    anchors.fill:   parent

    readonly property real _margins: ScreenTools.defaultFontPixelHeight
    readonly property var  _appSettings: QGroundControl.settingsManager.appSettings

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    QGCFlickable {
        anchors.margins:    _margins
        anchors.fill:       parent
        contentWidth:       column.width
        contentHeight:      column.height
        clip:               true

        ColumnLayout {
            id:         column
            width:      Math.min(parent.width, ScreenTools.defaultFontPixelWidth * 80)
            spacing:    _margins

            SettingsGroupLayout {
                Layout.fillWidth:   true
                heading:            qsTr("This app")

                LabelledLabel { label: qsTr("Name");        labelText: QGroundControl.appName }
                LabelledLabel { label: qsTr("Version");     labelText: QGroundControl.qgcVersion }
                LabelledLabel { label: qsTr("Build date");  labelText: QGroundControl.qgcAppDate; visible: QGroundControl.qgcAppDate !== "" }
                LabelledLabel { label: qsTr("Channel");     labelText: QGroundControl.qgcDailyBuild ? qsTr("Daily (development)") : qsTr("Stable") }
            }

            SettingsGroupLayout {
                Layout.fillWidth:   true
                heading:            qsTr("Support")

                QGCLabel {
                    Layout.fillWidth:   true
                    wrapMode:           Text.WordWrap
                    text:               qsTr("Rosor builds and supports this ground station for its aircraft. When you report a problem, quote the version above and send the telemetry log of the flight.")
                }
                QGCLabel {
                    linkColor:          qgcPal.text
                    text:               "<a href=\"https://rosor.ca\">rosor.ca</a>"
                    onLinkActivated:    (link) => Qt.openUrlExternally(link)
                }
            }

            SettingsGroupLayout {
                Layout.fillWidth:   true
                heading:            qsTr("Where the logs are")

                QGCLabel {
                    Layout.fillWidth:   true
                    wrapMode:           Text.WordWrap
                    font.pointSize:     ScreenTools.smallFontPointSize
                    text:               qsTr("Telemetry logs (one .tlog per session, armed or not):")
                }
                QGCLabel {
                    Layout.fillWidth:   true
                    wrapMode:           Text.WrapAnywhere
                    text:               _appSettings.telemetrySavePath
                }
                QGCLabel {
                    Layout.fillWidth:   true
                    wrapMode:           Text.WordWrap
                    font.pointSize:     ScreenTools.smallFontPointSize
                    text:               qsTr("Crash reports:")
                }
                QGCLabel {
                    Layout.fillWidth:   true
                    wrapMode:           Text.WrapAnywhere
                    text:               _appSettings.crashSavePath
                }
            }

            SettingsGroupLayout {
                Layout.fillWidth:   true
                heading:            qsTr("Licence")

                QGCLabel {
                    Layout.fillWidth:   true
                    wrapMode:           Text.WordWrap
                    // The Apache-or-GPL choice for this build is Rosor's to make and is
                    // deliberately not asserted here (see CLAUDE.md); the page states
                    // the upstream terms and points at where Rosor's terms live.
                    text:               qsTr("Built on QGroundControl, an open-source ground control station by the Dronecode Foundation and its contributors, which is made available under the Apache License 2.0 and the GNU General Public License v3. The licence terms for this Rosor build, and access to its source code, are provided by Rosor with the app. Map data and imagery are the property of their respective providers.")
                }
                QGCLabel {
                    linkColor:          qgcPal.text
                    text:               "<a href=\"https://www.gnu.org/licenses/gpl-3.0.html\">GNU GPL v3</a> · <a href=\"https://www.apache.org/licenses/LICENSE-2.0\">Apache 2.0</a> · <a href=\"https://qgroundcontrol.com\">qgroundcontrol.com</a>"
                    onLinkActivated:    (link) => Qt.openUrlExternally(link)
                }
            }
        }
    }
}
