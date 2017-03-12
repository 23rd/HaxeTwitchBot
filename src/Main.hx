package;

import haxe.Json;
import haxe.MainLoop;
import haxe.Timer;
import haxe.ds.StringMap;
import sys.FileSystem;
import sys.io.File;
import sys.net.Host;
import sys.ssl.Socket;

typedef BotConfig = {
	var nick:String;
	var user:String;
	var realName:String;
	var owner:String;
	var server:String;
	var port:Int;
	var serverPass:String;
	var channels:Array<String>;
	var clientId:String;
}

/**
 * ...10.03.2017 13:56
 * @author 23rd
 */
class Main {
	
	private inline static var MAIN_LOOP_DELAY:Float = 0.1;
	
	private var socket:Socket;

	private var config:BotConfig;

	// The MainEvent received from the MainLoop.
	// Used for delaying and stopping the loop.
	private var mLoopEvt:MainEvent;
	
	private var mapUptime:StringMap<Uptime>;
	
	private var commands:Dynamic;
	
	private var internetCounter:Int = 0;
	
	private var triesOfReconnect:Int = 0;

	static function main() {
		new Main();
	}
	
	public function new() {
		// default config
		config = {
			nick:"haxebot", user:"hxbot", realName:"Me Mow", owner:"slipyx",
			server:"chat.freenode.net", port:6697, serverPass:"", channels:["#ganymede"], clientId:""
		};
		
		if (FileSystem.exists("./config.json")) {
			config = Json.parse(File.getContent("./config.json"));
		}
		
		if (FileSystem.exists("./commands.json")) {
			commands = Json.parse(File.getContent("./commands.json"));
		}
		
		mapUptime = new StringMap<Uptime>();
		
		connectToIRC();
	}
	
	private function mainLoopFunction():Void {
		var responce;
		try {
			responce = sys.net.Socket.select([socket], null, null, 0);
		} catch (e:Dynamic) {
			connectToIRC();
			trace("ERROR"); 
			responce = sys.net.Socket.select([socket], null, null, 0);
		};
		if (responce.read.length > 0)
			for (s in responce.read)
				while (true)
					try {
						var msg = s.input.readLine();
						handleMessage(msg);
					} catch (e:Dynamic) {
						internetCounter = 0;
						break; 
					}
		mLoopEvt.delay(MAIN_LOOP_DELAY);
		
		// This is for check internet.
		// Twitch ping to client every 5 minutes.
		// If no messages have been received in five minutes, then the Internet has disappeared.
		if (internetCounter > 310 * (1 / MAIN_LOOP_DELAY)) {
			Sys.println("RECONNECTING...");
			internetCounter -= Math.round(10 * (1 / MAIN_LOOP_DELAY));
			mLoopEvt.stop();
			reconnect();
			updateUptimes();
		}
		internetCounter++;
	}
	
	private function updateUptimes():Void {
		for (i in mapUptime.keys()) {
			mapUptime.get(i).update();
		}
	}
	
	private function reconnect():Void {
		socket.shutdown(true, true);
		socket.close();
		connectToIRC();
	}
	
	private function connectToIRC():Void {
		socket = new Socket();
		try {
			socket.verifyCert = false;
			socket.connect(new Host(config.server), config.port);
			socket.setBlocking(false);
			
			if (config.serverPass != "") {
				send("PASS " + config.serverPass);
			}
			send("NICK " + config.nick);
			send("USER " + config.user + " 0 * :" + config.realName);
			send("CAP REQ :twitch.tv/membership");
			send("CAP REQ :twitch.tv/commands");
			send("CAP REQ :twitch.tv/tags");
			
			triesOfReconnect = 0;
			
			mLoopEvt = MainLoop.add(mainLoopFunction);
		} catch (e:Dynamic) {
			Sys.println("Trying to reconnect... [" + (++triesOfReconnect) + "]");
			Timer.delay(connectToIRC, 1000);
		}
	}

	private function sendMessage(string:String, channel:String) {
		//for (c in config.channels)
		send("PRIVMSG #" + channel + " :" + string);
	}

	public function send(string:String) {
		// truncate over 510
		if (string.length > 510) string = string.substr(0, 510);

		// strip newline chars
		string = string.split("\r").join(" ");
		string = string.split("\n").join(" ");

		Sys.println(">> " + string);

		socket.output.writeString(string + "\r\n");
		socket.output.flush();
	}
	
	private function tagToJson(string:String):Dynamic {
		string = string.substr(1);
		var array:Array<String> = string.split(";");
		var resultString:String = "";
		var temp:Array<String>;
		for (i in array) {
			temp = i.split("=");
			resultString += '"' + temp[0] + '":"' + temp[1] + '",';
		}
		resultString = "{" + resultString.substr(0, resultString.length - 1) + "}";
		return Json.parse(resultString);
	}
	
	private function mapUptimeAdd(channel:String):Void {
		var c:String = channel.substr(1);
		if (mapUptime.get(c) == null) {
			mapUptime.set(c, new Uptime(c, config.clientId));
		}
	}

	private function handleMessage(message:String) {
		// Chop up the message for easier parsing.
		trace("[" + Date.now() + "] " + message);
		
		if (message.indexOf("tmi.twitch.tv 376") > -1) {
			Sys.println("CONNECTED!");
			for (c in config.channels) {
				send("JOIN " + c);
				mapUptimeAdd(c);
			}
			return;
		}
		
		if (message.indexOf("PRIVMSG") > -1) {
			var messageArray:Array<String> = message.split(":");
			var userInfo:Dynamic = tagToJson(messageArray[0]);
			var channel:String = getChannel(messageArray[1]);
			var userMessage:String = messageArray[messageArray.length - 1];
			var commandsOfChannel:Array<Dynamic> = Reflect.getProperty(commands.channels, channel);
			var regExp:EReg;
			var resultString:String;
			
			for (i in commandsOfChannel) {
				regExp = new EReg(i.command, "u");
				if (regExp.match(userMessage)) {
					if (i.message == "/timeout" || i.message == "/ban") {
						var time:Int = (i.random ? (Math.round(Math.random() * 500000 + 5000)) : 600);
						var banMessage:String = (i.banMessage != null ? i.banMessage : "");
						resultString = i.message + " " + Reflect.getProperty(userInfo, "display-name") + (i.message == "/ban" ? "" : " " + time) + " " + banMessage;
					} else if (i.message == "/uptime") {
						resultString = mapUptime.get(channel).getUptime();
					} else {
						resultString = i.message;
					}
					sendMessage(resultString, channel);
					return;
				}
			}
		}
	}
	
	private function getChannel(message:String):String {
		var channelRegEx = new EReg("#([a-z0-9_-]){2,}", "");
		if (channelRegEx.match(message)) {
			return channelRegEx.matched(0).substr(1);
		}
		return "";
	}
	
}