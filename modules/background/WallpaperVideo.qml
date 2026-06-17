import QtQuick
import QtMultimedia
import Quickshell
import qs.services

VideoOutput {
    id: root

    required property string path
    // Latched imperatively (not a binding) so play()/pause() side effects on
    // mediaStatus can't form a binding loop back into this property.
    property bool ready: false
    readonly property bool shouldPlay: Wallpapers.animationsActiveOn((QsWindow.window as QsWindow)?.screen ?? null)

    function syncPlayback(): void {
        if (!ready)
            return;

        if (shouldPlay)
            player.play();
        else
            player.pause();
    }

    fillMode: VideoOutput.PreserveAspectCrop

    onReadyChanged: syncPlayback()
    onShouldPlayChanged: syncPlayback()

    MediaPlayer {
        id: player

        source: root.path
        videoOutput: root
        loops: MediaPlayer.Infinite

        onMediaStatusChanged: {
            if (!root.ready && (mediaStatus === MediaPlayer.LoadedMedia || mediaStatus === MediaPlayer.BufferingMedia || mediaStatus === MediaPlayer.BufferedMedia))
                root.ready = true;
        }
    }
}
