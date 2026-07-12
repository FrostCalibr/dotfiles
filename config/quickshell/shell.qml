import Quickshell
import QtQuick
import Quickshell.Services.Mpris

FloatingWindow{
    visible:true
    implicitHeight: 1000
    implicitWidth: 1000
    Rectangle{
        id: mainbox
        anchors.centerIn: parent
        property int isClicked : 0
        width : playertext.contentWidth + 20
        height : playertext.contentHeight + 30
        color : '#2fcf20'
        MouseArea {
            anchors.fill : mainbox
            onClicked : {
                if (mainbox.isClicked == 0){
                    mainbox.color = "#5555bb"
                    mainbox.isClicked = 1
                }
                else {
                    mainbox.color = "#666666"
                    mainbox.isClicked = 0
                }
            }
        }
        Text{
            id : playertext
            property var player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
            text: player ? player.trackTitle : "nothing playing"
            color : '#c21313'
            font.pixelSize: 24
            anchors.centerIn: parent
            MouseArea{
                anchors.fill : playertext
                onClicked : {
                    playertext.color = "#933fff"
                }
            }
        }
    }
    
}