import QtQuick

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightMap

// Hosts the primary flight display as a PipView pane so it can trade places
// with the map, the same way the video stream already does.
//
// Only used when there is no video stream: PipView takes exactly two items, so
// the PFD stands in as item2 when video is absent rather than competing with it.
Item {
    id: _root

    property Item pipView
    property Item pipState: pfdPipState

    /// The pane fills the whole fly view, including the strip under the toolbar,
    /// so the PFD is inset by the toolbar height to keep its heading strip visible.
    property real topInset: 0

    PipState {
        id:      pfdPipState
        pipView: _root.pipView
        isDark:  true
    }

    PrimaryFlightDisplay {
        anchors.fill:      parent
        anchors.topMargin: _root.topInset
    }
}
