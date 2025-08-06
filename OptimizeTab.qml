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
        var endSegmentExists = curScore.selection.endSegment

        for (var segment = curScore.selection.startSegment; segment && (!endSegmentExists || segment.tick < curScore.selection.endSegment.tick); segment = segment.next) {
            if (!curScore.staves[selectedStaffIdx].isTabStaff(segment.fraction)) {
                error("Selection contains non-tab segment, select a range in a single tab staff")
                quit()
            }
        }
    }

    function applyOptimizeTab() {
        curScore.startCmd()
        var result = optimizeTab()
        curScore.endCmd()
        return result
    }

    function optimizeTab() {
        var noteToFrets = calculateFretPositions()
        var result = []
        switch (optimizationStrategyDropdown.currentText) {
            case "Highest String":
                result = optimizeHighestString(noteToFrets)
                break
            case "Graph Greedy":
                result = optimizeGraphGreedy(noteToFrets)
                break
            case "Graph Shortest Path":
                result = optimizeGraphDAGShortestPath(noteToFrets)
                break
            default:
                error("No optimization strategy selected")
                return 1
        }
        applyTabChanges(result)
        return 1
    }

    function applyTabChanges(result) {
        var stringCount = curScore.staves[curScore.selection.startStaff].part.instrumentAtTick(curScore.selection.startSegment.tick).stringData.strings.length
        var selection = curScore.selection
        var startSegment = selection.startSegment
        var endSegment = selection.endSegment
        var noteNumber = 0
        for (var segment = startSegment; segment && (!endSegment || segment.tick < endSegment.tick); segment = segment.next) {
            if (segment.segmentType == Segment.ChordRest) {
                var chord = segment.elementAt(curScore.selection.startStaff*4)
                if (chord) {
                    if (chord.type == Element.CHORD) {
                        if (chord.notes.length == 1) {
                            // printLog(`changed note ${noteNumber} from\t${chord.notes[0].string} ${chord.notes[0].fret} to\t${stringCount - result[noteNumber].string - 1} ${result[noteNumber].fret}, pitch: ${chord.notes[0].pitch}`)
                            chord.notes[0].fret = result[noteNumber].fret
                            chord.notes[0].string = stringCount - result[noteNumber].string - 1
                        } else if (chord.notes.length > 1) {
                            // TODO: How to handle chords?
                            // - find possible ways to play chord and use some fret to represent chord (bottom note fret, average fret, etc.)
                            // - ignore (might be better to deal with manually)
                        }
                        noteNumber++
                    } else if (chord.type == Element.REST) {
                        // printLog(`rest`)
                    }
                }
            }
        }
    }

    function printNotes() {
        var selection = curScore.selection
        var startSegment = selection.startSegment
        var endSegment = selection.endSegment
        var noteNumber = 0
        for (var segment = startSegment; segment && (!endSegment || segment.tick < endSegment.tick); segment = segment.next) {
            if (segment.segmentType == Segment.ChordRest) {
                var chord = segment.elementAt(curScore.selection.startStaff*4)
                if (chord) {
                    if (chord.type == Element.CHORD) {
                        if (chord.notes.length == 1) {
                            printLog(`note ${noteNumber}:\t${chord.notes[0].pitch}`)
                        } else if (chord.notes.length > 1) {
                            var temp = `note ${noteNumber}:\t`
                            for (var note of chord.notes) {
                                temp += `${note.pitch} `
                            }
                            printLog(temp)
                        }
                    } else if (chord.type == Element.REST) {
                        printLog(`rest`)
                    }
                    noteNumber++
                }
            }
        }
    }

    function calculateFretPositions() {
        var staff = curScore.staves[curScore.selection.startStaff]
        var transpose = staff.transpose(curScore.selection.startSegment.fraction).chromatic
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

    function optimizeHighestString(noteToFrets) {
        var result = []
        var selection = curScore.selection
        var startSegment = selection.startSegment
        var endSegment = selection.endSegment
        for (var segment = startSegment; segment && (!endSegment || segment.tick < endSegment.tick); segment = segment.next) {
            if (segment.segmentType == Segment.ChordRest) {
                var chord = segment.elementAt(curScore.selection.startStaff*4)
                if (chord) {
                    if (chord.type == Element.CHORD) {
                        if (chord.notes.length == 1) {
                            var l = noteToFrets.get(chord.notes[0].pitch)
                            result.push(l[l.length-1])
                        } else {
                            // TODO: how to handle chords?
                            result.push({})
                        }
                    }
                }
            }
        }
        return result
    }

    function createGraph(noteToFrets) {
        var selection = curScore.selection
        var startSegment = selection.startSegment
        var endSegment = selection.endSegment
        var noteNumber = 0

        // map of vertices for note n:  g[n]
        // vertex:                      g[noteNumber].get((string,)) = {pos, neighbors}
        // vertex.pos:                  {string, fret}
        // vertex.neighbors:            [neighbor1, ...]
        // neighbor:                    {ptr = (string, ), weight}
        // neighbor vertex:             g[n+1].get(neighbor.ptr)

        // create vertices
        var g = [new Map()]     // source vertex
        g[0].set((0), {pos: undefined, neighbors: []})
        for (var segment = startSegment; segment && (!endSegment || segment.tick < endSegment.tick); segment = segment.next) {
            if (segment.segmentType == Segment.ChordRest) {
                var chord = segment.elementAt(curScore.selection.startStaff*4)
                if (chord) {
                    if (chord.type == Element.CHORD) {
                        if (chord.notes.length == 1) {
                            g.push(new Map())
                            for (var pos of noteToFrets.get(chord.notes[0].pitch)) {
                                g[g.length-1].set((pos.string), {pos: pos, neighbors: []})
                            }
                            noteNumber++
                        }
                    }
                }
            }
        }
        g.push(new Map())       // sink vertex
        g[g.length-1].set(0, {pos: undefined, neighbors: []})

        // create edges
        // add zero-weight edges from source
        for (var v of g[1].values()) {
            g[0].get(0).neighbors.push({ptr: (v.pos.string), weight: 0})
        }
        
        // add other edges
        for (var i = 1; i < g.length-1; ++i) {
            for (var u of g[i].values()) {
                for (var v of g[i+1].values()) {
                    if (v.pos) {
                        var weight = calculateEdgeWeight(u.pos, v.pos)
                        u.neighbors.push({ptr: (v.pos.string), weight: weight})
                    } else {
                        u.neighbors.push({ptr: (0), weight: 0})
                    }
                }
            }
        }
        return g
    }

    function calculateEdgeWeight(pos1, pos2) {
        // TODO: needs tweaking
        
        var openStringCost = 0
        var stringCrossingCost = 2

        var weight = 0

        if (pos2.fret == 0 || pos1.fret == 0) {
            // open string
            weight += openStringCost
        } else {
            // fret distance
            var diff = Math.abs(pos1.fret - pos2.fret)
            if (diff > 4) {
                weight += diff
            }
        }
        if (pos1.string != pos2.string) {
            // string crossing
            var diff = Math.abs(pos1.string-pos2.string)
            if (diff > 1) {
                weight += stringCrossingCost * diff
            }
        }

        return weight
    }

    function optimizeGraphGreedy(noteToFrets) {
        var g = createGraph(noteToFrets)
        var result = []
        for (var note of g[1].values()) {
            result.push(note.pos)
            break;
        }
        for (var i = 1; i < g.length-2; ++i) {
            var u = g[i].get(result[i-1].string)
            var minValue = u.neighbors[0].weight
            var minPtr = u.neighbors[0].ptr
            for (var neighbor of u.neighbors) {
                if (neighbor.weight < minValue) {
                    minValue = neighbor.weight
                    minString = neighbor.ptr
                }
            }
            var minPos = g[i+1].get(minPtr).pos
            result.push(minPos)
        }
        return result
    }
    
    function optimizeGraphDAGShortestPath(noteToFrets) {
        var g = createGraph(noteToFrets)
        g[0].get(0).minValue = 0
        g[0].get(0).predPtr = undefined
        for (var i = 0; i < g.length-1; ++i) {
            printLog(`Note ${i-1} ----------------`)
            for (var u of g[i].values()) {
                for (var neighbor of u.neighbors) {
                    var val = u.minValue + neighbor.weight
                    var v = g[i+1].get(neighbor.ptr)
                    if (v.minValue == undefined || val < v.minValue) {
                        g[i+1].get(neighbor.ptr).minValue = val
                        g[i+1].get(neighbor.ptr).predPtr = u.pos ? (u.pos.string) : 0
                    }
                }
            }
            // for (var v of g[i+1].values()) {
            //     if (v.pos) {
            //         printLog(`\t${v.pos.string} ${v.pos.fret} minVal: ${v.minValue}`)
            //     } else {
            //         printLog(`\tend minVal: ${v.minValue}`)
            //     }
            // }
        }

        // backtrack
        var result = Array(g.length-2)
        for (var i = g.length - 2; i > 0; --i) {
            result[i-1] = g[i].get(g[i+1].get(0).predPtr).pos
        }
        for (var i = 0; i < result.length; ++i) {
            printLog(`Note ${i}: ${result[i].string} ${result[i].fret}`)
        }
        return result
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

    ListModel {
        id: optimizationStrategyListModel
        ListElement {
            text: "Highest String"
            value: "Highest String"
        }
        ListElement {
            text: "Graph Greedy"
            value: "Graph Greedy"
        }
        ListElement {
            text: "Graph Shortest Path"
            value: "Graph Shortest Path"
        }
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
            StyledDropdown {
                id: optimizationStrategyDropdown
                model: [
                    {text: "Highest String", value: "Highest String"},
                    {text: "Graph Greedy", value: "Graph Greedy"},
                    {text: "Graph Shortest Path", value: "Graph Shortest Path"}
                ]
                currentIndex: 0
                onActivated: function(index, value) {
                    currentIndex = index
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
            FlatButton {
                id: testButton
                width: 90
                text: "Print notes"
                onClicked: {
                    printNotes()
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
