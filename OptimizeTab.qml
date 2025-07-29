import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

import MuseScore 3.0
import Muse.Ui
import Muse.UiComponents 1.0

MuseScore {
    version: "0.0.1"
    title: "Optimize Tab"
    description: "Optimize tablature by accounting for factors such as fret distance, position shifts, string crossings, etc."
    pluginType: "dialog"
    categoryCode: ""
    thumbnailName: ""
    requiresScore: true

    width: 500

    property var debug: true
    property var logText: ""

    onRun: {
        if (!curScore.selection) {
            error("Invalid selection, select a range in a single TAB staff")
            quit()
        }
        if (!curScore.selection.isRange) {
            error("Invalid selection, select a range in a single TAB staff")
            quit()
        }
        if (curScore.selection.endStaff - curScore.selection.startStaff != 1) {
            error("Too many staves selected, select a range in a single tab staff")
            quit()
        }
        var targetStaffIdx = curScore.selection.startStaff

        if (!curScore.staves[targetStaffIdx].isTabStaff()) {
            error("Non-tab staff selected, select a range in a single tab staff");
            quit()
        }
    }

    function applyOptimizeTab() {
        curScore.startCmd()
        optimizeTab()
        curScore.endCmd()
    }

    function optimizeTab() {
        // var parts = curScore.parts
        // var staves = parts[selectedIndex].staves
        return
    }

    function printLog(s) {
        if (debug) {
            logText = s
        }
    }
    function error(errorMessage) {
        errorDialog.text = errorMessage
        errorDialog.open()
    }


    Column {
        topPadding: 10
        width: 500
        spacing: 10

        Grid {
            id: controlButtons
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter
            rows: 2
            columns: 2
            spacing: 10
            FlatButton {
                width: 90
            }
            FlatButton {
                width: 90
            }
            FlatButton {
                width: 90
            }
            FlatButton {
                width: 90
            }
        }

        Row {
            id: buttonRow
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10
            FlatButton {
                id: quitButton
                width: 90
                text: "Cancel"
                onClicked: {
                    quit()
                }
            }
            FlatButton {
                id: generateButton
                width: 90
                text: "Generate"
                accentButton: true
                onClicked: {
                    if (!generateTab()) {
                        quit()
                    }
                }
            }
        }

        Row {
            Layout.alignment: Qt.AlignHCenter
            StyledTextLabel { text: "Log: " }
            StyledTextLabel {
                id: logTextBox
                horizontalAlignment: Text.AlignLeft
                text: logText
            }
        }
    }

    MessageDialog {
        id: errorDialog
        title: "Error"
        text: ""
        onAccepted: {
            quit()
        }
        visible: false
    }
}
