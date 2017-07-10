package;
import haxe.Http;
import haxe.Json;
import haxe.Timer;

/**
 * ...10.03.2017 22:52
 * @author 23rd
 */
class Uptime {
	
	private var recordedAt:String;
	private var recorderLength:Int = 0;
	private var channel:String;
	private var clientId:String;
	private var timer:Timer;

	public function new(channel:String, clientId:String) {
		this.channel = channel;
		this.clientId = clientId;
		timer = new Timer(30 * 1000 * 60); // 30 minutes
		timer.run = loadBroadcastsJson;
		timer.run();
	}
	
	private function loadBroadcastsJson():Void {
		var json:Dynamic = Json.parse(Http.requestUrl("https://api.twitch.tv/kraken/channels/" + channel + "/videos?broadcasts=true&limit=15&client_id=" + clientId));
		if (json.videos.length == 0) {
			recordedAt = "";
			return;
		}
		var recorded_at:String = json.videos[0].recorded_at;
		
		if (json.videos[0].status == "recorded") {
			recorderLength = json.videos[0].length;
		} else {
			recorderLength = 0;
		}
		
		recordedAt = recorded_at.substr(0, recorded_at.length - 1);
	}
	
	public function update():Void {
		timer.stop();
		timer.run();
	}
	
	public function getUptime():String {
		trace(channel, recordedAt);
		if (recordedAt == "") {
			return "Cant get uptime information.";
		}
		var timeString:String = recordedAt;
		timeString = StringTools.replace(timeString, "T", " ");
		timeString = StringTools.replace(timeString, "Z", "");
		
		var startDateDif:Date = Date.fromString(timeString);
		var endDateDif:Date = Date.now();
		var offset:Float = (getTimezoneOffset()) * 60 * 1000;
		var diffVar:Float = (endDateDif.getTime() + offset) - startDateDif.getTime();
		diffVar -= recorderLength * 1000;
		
		var stringResult = "";
		if (recorderLength > 0) {
			stringResult = "Went offline for ";
		} 
		
		stringResult += timeToText(Math.round(diffVar));
		if (recorderLength > 0) {
		   stringResult += "Last stream length: " + timeToText(recorderLength * 1000); 
		}
		return stringResult;
	}
	
	private function addZero(number:Int):String {
		if (number < 10) {
			return "0" + number;
		}
		return Std.string(number);
	}
	
	private function getTimezoneOffset () { 
		var a = DateTools.format(Date.fromTime(0), '%H:%M').split(':');
		var offset = -Std.parseInt(a[0]) * 60 + Std.parseInt(a[1]);
		return offset;
	}
	
	private function timeToText(time:Int):String {
		var diff:Int = Math.floor(time / 1000);
		var hours:Int = Math.floor(diff / 60 / 60);
		diff -= hours * 60 * 60;
		var minutes:Int = Math.floor(diff / 60);
		diff -= minutes * 60;
		var seconds:Int = Math.round(diff);
		return addZero(hours) + "h " + addZero(minutes) + "m " + addZero(seconds) + "s. ";
	}
	
}