import QtQuick

// Artificial horizon styled to match Mission Planner's HUD, which is what Rosor
// pilots are used to reading.
//
// Deliberately separate from QGCArtificialHorizon: that one is shared with the
// round attitude instruments and uses QGC's own hsla gradients, so restyling it
// would change those too. Colours here were taken from a capture of Mission
// Planner's desktop HUD -- note that hud.html in an MP install is the *browser*
// HUD and renders differently, so it is not the reference.
Item {
    id: root

    property real rollAngle:  0
    property real pitchAngle: 0

    /// Vertical travel of the horizon per degree of pitch.
    property real pixelsPerDegree: height / 90

    clip: true

    Item {
        id: horizon

        // Oversized so the corners stay covered at full roll and pitch.
        width:            root.width * 3
        height:           root.height * 4
        anchors.centerIn: parent

        transform: [
            Translate {
                y: root.pitchAngle * root.pixelsPerDegree
            },
            Rotation {
                origin.x: horizon.width / 2
                origin.y: horizon.height / 2
                angle:    -root.rollAngle
            }
        ]

        Rectangle {
            anchors.left:   parent.left
            anchors.right:  parent.right
            anchors.top:    parent.top
            height:         parent.height / 2
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#4a5fc8" }
                GradientStop { position: 0.55; color: "#93a6e4" }
                GradientStop { position: 1.0; color: "#dfeaf7" }
            }
        }

        Rectangle {
            anchors.left:   parent.left
            anchors.right:  parent.right
            anchors.bottom: parent.bottom
            height:         parent.height / 2
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#9bb824" }
                GradientStop { position: 0.45; color: "#93ae21" }
                GradientStop { position: 1.0; color: "#414f07" }
            }
        }

        // Pitch ladder rides with the horizon: white, every 5 degrees, longer bars
        // on the tens. No numerals on the scale itself -- pitch is read from the
        // live numeral under the aircraft symbol instead.
        Canvas {
            id:           ladder
            anchors.fill: parent

            property real pitchAngle: root.pitchAngle
            property real ppd:        root.pixelsPerDegree

            onPitchAngleChanged: requestPaint()
            onPpdChanged:        requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()

                var cx = width / 2
                var cy = height / 2

                // Bar lengths come off the view HEIGHT, not its width. MP's HUD
                // is near enough square; this pane is closer to 2:1, so scaling
                // horizontal geometry by width stretched the ladder to roughly
                // twice the length it should be and ran it under the tapes.
                var longHalf  = root.height * 0.146
                var shortHalf = root.height * 0.082

                ctx.strokeStyle = "white"
                ctx.lineWidth   = Math.max(1, root.height * 0.0079)

                for (var deg = -40; deg <= 40; deg += 5) {
                    if (deg === 0) {
                        continue    // the horizon line itself is the sky/ground edge
                    }

                    var y = cy - (deg * ppd)
                    var half = (deg % 10 === 0) ? longHalf : shortHalf

                    ctx.beginPath()
                    ctx.moveTo(cx - half, y)
                    ctx.lineTo(cx + half, y)
                    ctx.stroke()

                }
            }
        }
    }
}
