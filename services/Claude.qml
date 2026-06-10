pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Models
import qs.utils

Singleton {
    id: root

    readonly property string sessionsDir: `${Paths.state}/claude/sessions`
    readonly property int sessions: markers.entries.length
    readonly property bool working: sessions > 0

    FileSystemModel {
        id: markers

        // path is set once the dir exists, otherwise the watcher silently fails
        filter: FileSystemModel.Files
    }

    Process {
        running: true
        command: ["mkdir", "-p", root.sessionsDir]
        onExited: markers.path = root.sessionsDir // qmllint disable signal-handler-parameters
    }

    Timer {
        // markers of crashed sessions are never removed by hooks, so prune while visible
        running: root.working
        interval: 60000
        repeat: true
        onTriggered: Quickshell.execDetached([Quickshell.shellPath("scripts/claude-state.sh"), "prune"])
    }
}
