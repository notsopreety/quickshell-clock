import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick.Controls
import QtQuick.Layouts

PanelWindow {
    id: root

    WlrLayershell.layer: WlrLayershell.Background
    WlrLayershell.namespace: "material-clock"

    anchors {
        top: true
        left: true
    }

    FileView {
        id: settingsFile
        path: Quickshell.env("HOME") + "/.config/quickshell/clock/settings.json"
        JsonAdapter {
            id: settings
            property int winX: 100
            property int winY: 100
            property int winSize: 320
            property int scallops: 12
            property int amplitude: 5
            property bool showNumbers: true
            property bool showTicks: true
            property bool showDayLabel: true
            property bool showDigitalTime: true
            property bool showDateBadge: true
            property bool showSecondHand: true
            property bool showSecondHandLine: true
            property bool usePywal: true
            property string accentColor: "#903B3B"
            property string bgColor: "#ecd1c7"
            property string primaryColor: "#090F1B"
            property int numberDistOffset: 40
            property int tickDistOffset: 15
            property real hourThickness: 0.07
            property real minuteThickness: 0.05
            property real secondThickness: 0.03
            property real hand1Length: 60
            property real hand2Length: 100
            property real hand3Length: 120
        }
    }

    // ── Pywal Integration ──
    FileView {
        id: walColorsFile
        path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
        JsonAdapter {
            id: walColors
            // Placeholder properties to be filled by JSON
            property var colors: ({})
            property var special: ({})
        }
    }

    // Root properties bound to settings
    property int winSize: settings.winSize
    property int scallops: settings.scallops
    property int amplitude: settings.amplitude
    property bool showNumbers: settings.showNumbers
    property bool showTicks: settings.showTicks
    property bool showDayLabel: settings.showDayLabel
    property bool showDigitalTime: settings.showDigitalTime
    property bool showDateBadge: settings.showDateBadge
    property bool showSecondHand: settings.showSecondHand
    property bool showSecondHandLine: settings.showSecondHandLine
    property bool usePywal: settings.usePywal
    
    // Helper function to check if Pywal color exists
    function getWalColor(key, fallback) {
        if (!usePywal) return fallback;
        if (key.startsWith("special.")) {
            var s = key.split(".")[1];
            return (walColors.special && walColors.special[s]) ? walColors.special[s] : fallback;
        }
        return (walColors.colors && walColors.colors[key]) ? walColors.colors[key] : fallback;
    }

    // Dynamic Colors: Pywal vs Settings
    property color bgColor: getWalColor("color1", settings.bgColor || "#ecd1c7")
    property color accentColor: getWalColor("color2", settings.accentColor || "#903B3B")
    property color primaryColor: getWalColor("special.foreground", settings.primaryColor || "#090F1B")
    property color secondaryColor: getWalColor("color6", "#000000")
    
    // THE ULTIMATE RESPONSIVE SCALE
    // Everything is calculated as a fraction of winSize.
    // We treat the settings as "base pixels at 320px size" and convert them to ratios.
    readonly property real ratio: winSize / 320.0
    
    property real hourThickness: settings.hourThickness // Already a ratio (0.07)
    property real minuteThickness: settings.minuteThickness // Already a ratio (0.05)
    property real secondThickness: settings.secondThickness // Already a ratio (0.03)
    
    // Convert "pixel" settings to proportional winSize units
    property real hand1Len: (settings.hand1Length / 320.0) * winSize
    property real hand2Len: (settings.hand2Length / 320.0) * winSize
    property real hand3Len: (settings.hand3Length / 320.0) * winSize
    
    property real numOffset: (settings.numberDistOffset / 320.0) * winSize
    property real tickOffset: (settings.tickDistOffset / 320.0) * winSize
    property real ampScaled: (amplitude / 320.0) * winSize

    margins {
        top: settings.winY
        left: settings.winX
    }

    implicitWidth: winSize
    implicitHeight: winSize
    color: "transparent"

    // Clock Logic
    property var currentTime: new Date()
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: currentTime = new Date()
    }

    // ── Scalloped Background ──
    Canvas {
        id: clockFace
        anchors.fill: parent
        anchors.margins: winSize * 0.03
        antialiasing: true

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        Connections {
            target: root
            function onScallopsChanged() { clockFace.requestPaint() }
            function onAmplitudeChanged() { clockFace.requestPaint() }
            function onWinSizeChanged() { clockFace.requestPaint() }
        }

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var cx = width / 2;
            var cy = height / 2;
            var radius = Math.min(width, height) / 2 - ampScaled - (winSize * 0.015);

            ctx.beginPath();
            for (var i = 0; i <= 360; i += 0.5) {
                var angle = i * Math.PI / 180;
                var r = radius + ampScaled * Math.cos(scallops * angle);
                var x = cx + r * Math.cos(angle);
                var y = cy + r * Math.sin(angle);
                if (i === 0) ctx.moveTo(x, y);
                else ctx.lineTo(x, y);
            }
            ctx.closePath();
            ctx.fillStyle = bgColor;
            ctx.fill();
        }
    }

    // ── Tick Marks (responsive to scallop amplitude) ──
    Repeater {
        model: showTicks ? 60 : 0
        Rectangle {
            required property int index
            property bool isHour: index % 5 == 0
            property real tickAngleRad: index * 6 * Math.PI / 180
            property real displayAngle: tickAngleRad - Math.PI / 2

            // Responsive: follows the scalloped perimeter
            property real baseRadius: winSize / 2 - ampScaled - (winSize * 0.03)
            property real dist: baseRadius + ampScaled * Math.cos(scallops * tickAngleRad) - tickOffset

            width: (isHour ? winSize * 0.009 : winSize * 0.003)
            height: (isHour ? winSize * 0.037 : winSize * 0.018)
            color: isHour ? primaryColor : Qt.rgba(primaryColor.r, primaryColor.g, primaryColor.b, 0.2)
            radius: width / 2

            x: parent.width / 2 + dist * Math.cos(displayAngle) - width / 2
            y: parent.height / 2 + dist * Math.sin(displayAngle) - height / 2

            transform: Rotation {
                origin.x: width / 2
                origin.y: height / 2
                angle: index * 6
            }
        }
    }

    // ── Hour Numbers ──
    Repeater {
        model: showNumbers ? 12 : 0
        Label {
            required property int index
            property real angle: (index + 1) * 30 * Math.PI / 180 - Math.PI / 2
            property real dist: winSize / 2 - ampScaled - numOffset

            x: parent.width / 2 + dist * Math.cos(angle) - width / 2
            y: parent.height / 2 + dist * Math.sin(angle) - height / 2

            text: index + 1
            color: primaryColor
            font.pixelSize: winSize * 0.075
            font.weight: Font.Bold
            font.family: "sans-serif"
        }
    }

    // ── Day Label (curved text under 12 o'clock) ──
    Canvas {
        id: dayCanvas
        visible: showDayLabel
        anchors.fill: parent
        anchors.margins: winSize * 0.03
        antialiasing: true

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var cx = width / 2;
            var cy = height / 2;
            var dayText = currentTime.toLocaleDateString(Qt.locale("en_US"), "dddd");

            var textRadius = winSize * 0.22;
            var fontSize = winSize * 0.055;
            ctx.font = "bold " + Math.round(fontSize) + "px sans-serif";
            ctx.fillStyle = primaryColor;
            ctx.textAlign = "center";
            ctx.textBaseline = "middle";

            var totalAngle = dayText.length * 0.14;
            var startAngle = -Math.PI / 2 - totalAngle / 2;

            for (var i = 0; i < dayText.length; i++) {
                var charAngle = startAngle + i * (totalAngle / (dayText.length - 1 || 1));
                var charX = cx + textRadius * Math.cos(charAngle);
                var charY = cy + textRadius * Math.sin(charAngle);

                ctx.save();
                ctx.translate(charX, charY);
                ctx.rotate(charAngle + Math.PI / 2);
                ctx.fillText(dayText[i], 0, 0);
                ctx.restore();
            }
        }

        Connections {
            target: root
            function onCurrentTimeChanged() { dayCanvas.requestPaint() }
            function onWinSizeChanged() { dayCanvas.requestPaint() }
        }

        Component.onCompleted: requestPaint()
    }

    // ── Digital Time Display (large, behind hands) ──
    Item {
        visible: showDigitalTime
        anchors.centerIn: parent
        width: winSize * 0.7
        height: winSize * 0.7

        // Hours (12-hour format)
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.verticalCenter
            anchors.bottomMargin: winSize * 0.005
            text: {
                var h = currentTime.getHours() % 12;
                if (h === 0) h = 12;
                return (h < 10 ? "0" : "") + h;
            }
            color: Qt.rgba(primaryColor.r, primaryColor.g, primaryColor.b, 0.15)
            font.pixelSize: winSize * 0.32
            font.weight: Font.Black
            font.family: "sans-serif"
        }

        // Minutes
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.verticalCenter
            anchors.topMargin: -winSize * 0.04
            text: {
                var m = currentTime.getMinutes();
                if (m === 0) m = 0;
                return (m < 10 ? "0" : "") + m;
            }
            color: Qt.rgba(primaryColor.r, primaryColor.g, primaryColor.b, 0.15)
            font.pixelSize: winSize * 0.32
            font.weight: Font.Black
            font.family: "sans-serif"
        }
    }

    // ── Date Badge (right side) ──
    Rectangle {
        visible: showDateBadge
        anchors.right: parent.right
        anchors.rightMargin: winSize * 0.14
        anchors.verticalCenter: parent.verticalCenter
        width: winSize * 0.14
        height: winSize * 0.08
        radius: height / 2
        color: Qt.rgba(0, 0, 0, 0.1)

        Text {
            anchors.centerIn: parent
            text: {
                var d = currentTime.getDate();
                return (d < 10 ? "0" : "") + d;
            }
            color: primaryColor
            font.pixelSize: parent.height * 0.7
            font.weight: Font.Bold
            font.family: "sans-serif"
        }
    }

    // ── Clock Hands ──
    Item {
        id: handsContainer
        anchors.centerIn: parent
        width: parent.width; height: parent.height

        // Hand 1 (Hour)
        Rectangle {
            id: hand1
            anchors.horizontalCenter: parent.horizontalCenter
            width: winSize * hourThickness
            height: width + hand1Len
            radius: width / 2
            color: primaryColor
            y: winSize / 2 - height + width / 2
            antialiasing: true
            transform: Rotation {
                origin.x: hand1.width / 2
                origin.y: hand1.height - hand1.width / 2
                angle: (currentTime.getHours() % 12 + currentTime.getMinutes() / 60) * 30
            }
        }

        // Hand 2 (Minute)
        Rectangle {
            id: hand2
            anchors.horizontalCenter: parent.horizontalCenter
            width: winSize * minuteThickness
            height: width + hand2Len
            radius: width / 2
            color: accentColor
            y: winSize / 2 - height + width / 2
            antialiasing: true
            transform: Rotation {
                origin.x: hand2.width / 2
                origin.y: hand2.height - hand2.width / 2
                angle: (currentTime.getMinutes() + currentTime.getSeconds() / 60) * 6
            }
        }

        // Hand 3 (Second)
        Item {
            id: secondHandGroup
            visible: showSecondHand
            anchors.centerIn: parent
            width: parent.width; height: parent.height
            
            transform: Rotation {
                origin.x: winSize / 2
                origin.y: winSize / 2
                angle: currentTime.getSeconds() * 6
            }

            // The Line
            Rectangle {
                visible: showSecondHandLine
                anchors.horizontalCenter: parent.horizontalCenter
                width: winSize * secondThickness
                height: hand3Len
                color: Qt.rgba(primaryColor.r, primaryColor.g, primaryColor.b, 0.15)
                y: winSize / 2 - height
                antialiasing: true
            }

            // The Dot (at the tip)
            Rectangle {
                visible: !showSecondHandLine
                anchors.horizontalCenter: parent.horizontalCenter
                width: winSize * secondThickness * 2.5 // Make dot slightly larger for visibility
                height: width
                radius: width / 2
                color: Qt.rgba(primaryColor.r, primaryColor.g, primaryColor.b, 0.25)
                y: winSize / 2 - hand3Len - height / 2
                antialiasing: true
            }
        }

        // Center Pin
        Rectangle {
            anchors.centerIn: parent
            width: winSize * 0.04
            height: width
            radius: width / 2
            color: accentColor
        }
    }
}
