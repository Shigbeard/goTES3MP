package main

import (
	"encoding/json"
	"fmt"
	"regexp"
	"strings"

	log "github.com/sirupsen/logrus"

	"github.com/spf13/viper"
)

type PlayerStruct struct {
	Name     string `json:"user"`
	Method   string `json:"method"`
	Responce string `json:"responce"`
	Pid      int    `json:"pid"`
}

func tes3mpOutputHandler(s string) {

	// initHandler(Context)
	// initHandler(&Context)

	// debugToggle := viper.GetBool("debug")
	enable_ServerOutput := viper.GetBool("enable_ServerOutput")
	if enable_ServerOutput {
		// This shouldnt not contain tes3mp log
		fmt.Println(s)
	}

	var isTrue bool
	isTrue, _ = regexp.MatchString(`TES3MP dedicated server`, s)
	if isTrue {
		dedicatedServerInfo := strings.Split(s, " ")
		build := dedicatedServerInfo[4] + " " + dedicatedServerInfo[5]
		build = strings.Replace(strings.Replace(build, ")", "", -1), "(", "", -1)
		if dedicatedServerInfo[3] == "------------------------------------------------------------" {
			log.Warnln(tes3mpLogMessage, "Malformed Version was caught")
			TES3MPVersion = "Unknown"
		} else {
			log.Infoln(tes3mpLogMessage, "TES3MP Version:", dedicatedServerInfo[3], build)
			TES3MPVersion = dedicatedServerInfo[3] + " " + build
		}
		// log.Infoln(tes3mpLogMessage, "TES3MPBuild:", build)
		// TES3MPBuild = build

	}
	isTrue, _ = regexp.MatchString(`\[User\]`, s)
	if isTrue {
		var player PlayerStruct
		userarr := strings.Split(s, " ")
		json.Unmarshal([]byte(userarr[5]), &player)

		switch player.Responce {
		case "Connected":
			log.Infoln(tes3mpLogMessage, "Player", player.Name, player.Responce)
			CurrentPlayers = CurrentPlayers + 1
			Players = AppendIfMissing(Players, player.Name)
			DiscordSendMessage("[EventHandler] " + player.Name + " joined the server.")

		case "Disconnected":
			log.Infoln(tes3mpLogMessage, "Player", player.Name, player.Responce)
			CurrentPlayers = CurrentPlayers - 1
			Players = RemoveEntryFromArray(Players, player.Name)
			DiscordSendMessage("[EventHandler] " + player.Name + " left the server.")
		}
	}
	// isTrue, _ = regexp.MatchString(`\[Chat\]`, s)
	// if isTrue {
	// 	// responce = name, pid, message
	// 	// responce := tes3mpOnPlayerSendMessage(s)
	// 	// relayProcess(responce)
	// 	// Context
	// 	// fmt.Println("[EVENT-TEST]", "Recieved the following:", responce)
	// 	// Context.CallbacksCall("tes3mp.OnPlayerSendMessage", TestFunction1)
	// 	// Context.CallbacksCall("irc.sendMessage", onIRCSendMessage)

	// }

	isTrue, _ = regexp.MatchString(`Called "OnServerPostInit"`, s)
	if isTrue {
		log.Infoln(tes3mpLogMessage, "Tes3mp server is now online")
		ServerRunning = true
	}

	// if debugToggle {
	// 	fmt.Println(s)
	// }
}