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

        var selectedStaffIdx = curScore.selection.startStaff
        var selectedPart = curScore.staves[selectedStaffIdx].part
        // var instrumentId = selectedPart.instrumentIdAtTick(curScore.selection.startSegment.tick)
        var endSegmentExists = curScore.selection.endSegment

        // var count = 0
        for (var segment = curScore.selection.startSegment; segment && (!endSegmentExists || segment.tick < curScore.selection.endSegment.tick); segment = segment.next) {
            if (!curScore.staves[selectedStaffIdx].isTabStaff(segment.fraction)) {
                error("Selection contains non-tab segment, select a range in a single tab staff")
                quit()
            }
            // if (selectedPart.instrumentIdAtTick(segment.tick) != instrumentId) {
            //     error("Selection containing multiple instruments not supported, select a range with only one instrument")
            //     quit()
            // }
            // if (segment.segmentType == Segment.ChordRest) {
            //     var el = segment.elementAt(selectedStaffIdx*4)
            //     if (el) {
            //         if (el.type == Element.CHORD) {
            //             printLog(`segment ${count}: note ${el.notes[0].pitch}`)
            //         } else {
            //             printLog(`segment ${count}: ${el.subtypeName()}`)
            //         }
            //     } else {
            //         printLog(`segment ${count}: NULL`)
            //     }
            // }
            // count += 1
        }
    }

    function applyOptimizeTab() {
        curScore.startCmd()
        optimizeTab()
        curScore.endCmd()
        return 1
    }

    function optimizeTab() {
        var noteToFrets = calculateFretPositions()
        // for (const [note, l] of noteToFrets) {
        //     var temp = `Note ${note}: `
        //     for (var pos of l) {
        //         temp += `(String ${pos.string} Fret ${pos.fret})`
        //     }
        //     printLog(temp)
        // }
        
        // note.fret
        // note.string
        var count = 0
        for (var segment = curScore.selection.startSegment;
            segment && (!curScore.selection.endSegment || segment.tick < curScore.selection.endSegment.tick);
            segment = segment.next) {
            if (segment.segmentType == Segment.ChordRest) {
                var chord = segment.elementAt(curScore.selection.startStaff*4)
                if (chord.type == Element.CHORD) {
                    if (chord.notes.length == 1) {
                        var temp = `Note ${count}: ${chord.notes[0].pitch}\t${chord.notes[0].tpc1}\t${chord.notes[0].tpc2}\t${chord.notes[0].tpc}`
                        for (var pos of noteToFrets.get(chord.notes[0].pitch)) {
                            temp += `(String ${pos.string} Fret ${pos.fret})`
                        }
                        printLog(temp)
                    } else {
                        // printLog(`Note ${count}: chord`)

                        // TODO: How to handle chords?
                        // - find possible ways to play chord and use some fret to represent chord (bottom note fret, average fret, etc.)
                        // - ignore (might be better to deal with manually)
                    }
                    count += 1
                }
            }
        }
        return
    }

    function calculateFretPositions() {
        var staff = curScore.staves[curScore.selection.startStaff]
        var transpose = staff.transpose(curScore.selection.startSegment.fraction).chromatic
        // printLog(`transpose: ${staff.transpose(curScore.selection.startSegment.fraction).chromatic}`)
        var instrument = staff.part.instrumentAtTick(curScore.selection.startSegment.tick)
        var strings = instrument.stringData.strings
        var frets = instrument.stringData.frets
        var stringIndices = new Array(strings.length)
        for (var i = 0; i < strings.length; ++i) {
            stringIndices[i] = i
        }
        stringIndices.sort((a,b)=>strings[a].pitch-strings[b].pitch)

        var map = new Map()
        var minStringId = 0
        var maxStringId = 1
        for (var note = strings[stringIndices[0]].pitch; note < strings[stringIndices[strings.length-1]].pitch+frets; ++note) {
            map.set(note+transpose, [])
            if (maxStringId < strings.length && strings[stringIndices[maxStringId]].pitch == note) {
                maxStringId += 1
            }
            if (note - (strings[stringIndices[minStringId]].pitch) > frets) {
                minStringId += 1
            }
            for (var stringId = minStringId; stringId < maxStringId; ++stringId) {
                map.get(note+transpose).push({string: stringIndices[stringId], fret: note-strings[stringIndices[stringId]].pitch})
            }
        }
        return map
    }

    function printLog(s) {
        if (debug) {
            var date = new Date()
            logText += `${date.getHours()}:${date.getMinutes()}:${date.getSeconds()}\t| ` + s + "\n"
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
                onClicked: {
                    printLog("button 1")
                }
            }
            FlatButton {
                width: 90
                onClicked: {
                    printLog("button 2")
                }
            }
            FlatButton {
                width: 90
                onClicked: {
                    printLog("button 3")
                }
            }
            FlatButton {
                width: 90
                onClicked: {
                    printLog("button 4")
                }
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
                id: optimizeButton
                width: 90
                text: "Optimize"
                accentButton: true
                onClicked: {
                    if (!applyOptimizeTab()) {
                        quit()
                    }
                }
            }
        }

        Column {
            Label {
                text: "Log:"
            }
            ScrollView {
                Layout.alignment: Qt.AlignHCenter
                width: 500
                height: 300

                contentWidth: availableWidth

                TextArea {
                    id: logTextArea
                    horizontalAlignment: Text.AlignLeft

                    readOnly: true
                    text: logText

                    onTextChanged: {
                        cursorPosition = length
                    }
                }
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
