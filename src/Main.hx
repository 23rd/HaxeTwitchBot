package;

import haxe.Json;
import haxe.MainLoop;
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
	
	private var socket:Socket;

	private var config:BotConfig;

	// The MainEvent received from the MainLoop.
	// Used for delaying and stopping the loop.
	private var mLoopEvt:MainEvent;
	
	private var uptime:Uptime;

	static function main() {
		new Main();
	}
	
	public inline function printSomethingInline() {
        //untyped __cpp__('std::setlocale(0, "");');
    }
	
	public function new() {
		// default config
		config = {
			nick:"haxebot", user:"hxbot", realName:"Me Mow", owner:"slipyx",
			server:"chat.freenode.net", port:6697, serverPass:"", channels:["#ganymede"], clientId:""
		};
		
		if (FileSystem.exists("./cfg.json")) {
			config = Json.parse(File.getContent("./cfg.json"));
		}
		
		uptime = new Uptime("twitch", config.clientId);
		
		socket = new Socket();
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
		
		// Add function for reading socket to MainLoop
		mLoopEvt = MainLoop.add(function() {
			var responce = sys.net.Socket.select([socket], null, null, 0);
			// check if socket has incoming data and read each line in turn until EOF
			if (responce.read.length > 0)
				for (s in responce.read)
					// loop will break when readLine throws EOF
					while (true)
						try {
							var msg = s.input.readLine();
							handleMessage(msg);
							/*var a = Sys.stdin().readLine();
							trace(a);*/
						} catch (e:Dynamic) { break; }
			// dont loop faster than 10 times per second
			mLoopEvt.delay(0.1);
		});
		// grace please
		//sock.shutdown(true, true);
		//sock.close();
	}

	private function sendMessage(string:String) {
		for (c in config.channels)
			send("PRIVMSG " + c + " :" + string);
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

	private function handleMessage(message:String) {
		// Chop up the message for easier parsing.
		
		if (message.indexOf("PRIVMSG") > -1) {
			var messageArray:Array<String> = message.split(":");
			var userInfo:Dynamic = tagToJson(messageArray[0]);
			
			if (messageArray[messageArray.length - 1] == "!up") {
				sendMessage(uptime.getUptime());
			}
		}
		var ix = message.indexOf( ":", 1 );
		var words = message.substr(0, ix).split(" ");
		message = message.substr(ix + 1);
		
		if (words[0] == "PING") {
			Sys.print('PING [' + Date.now() + '] ');
			send("PONG :" + message);
		} else if (words[1] == "001") {
			Sys.println("CONNECTED!");
			for (c in config.channels) {
				send("JOIN " + c);
				//send("PRIVMSG " + c + " :meow");
			}
		} else if (words[1] == "PRIVMSG") {
			// channel or pm user
			var src = words[2];

			// nick!user@host.name
			var nick = words[0].substr(1, words[0].indexOf("!") - 1);

			// first word of message interpreted as a command, rest as parameters
			var cix = message.indexOf(" ");
			var cmd = message.substr(0, cix);
			message = message.substr(cix + 1);
			Sys.println("(" + src + ") <" + nick + "> " + cmd + " " + message);

			// commands

			// preliminary join/part support
			// TODO:update cfg.channels dynamically as well
			if (nick == config.owner && cmd == ";join") {
				send("JOIN " + message);
			} else if (nick == config.owner && cmd == ";part") {
				send("PART " + message);
			}
		}
	}
	
}