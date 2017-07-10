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
	private var timeBetweenVods:Float;

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
		
		timeBetweenVods = checkDiffBetweenVods(json, 0);
		
		if (json.videos[0].status == "recorded") {
			recorderLength = json.videos[0].length;
		} else {
			recorderLength = 0;
		}
	}
	
	public function update():Void {
		timer.stop();
		timer.run();
	}
	
	private function checkDiffBetweenVods(json:Dynamic, index:Int):Float {
		if (json.videos.length <= index + 1) {
			return 0;
		}
		var at:String = json.videos[index].recorded_at;
		var at2:String = json.videos[index + 1].recorded_at;
		var length2:Float = json.videos[index + 1].length * 1000;
		
		var diff:Float = diffOfDates(Date.fromString(removeTZ(at2)), Date.fromString(removeTZ(at)));
		//20 minutes
		if (diff - length2 < 1000 * 60 * 20) {
			return length2 + checkDiffBetweenVods(json, index + 1);
		}
		return 0;
	}
	
	private function diffOfDates(startDate:Date, endDate:Date, makeOffset:Bool = false):Float {
		var offset:Float = 0;
		if (makeOffset) {
			offset = (getTimezoneOffset()) * 60 * 1000;
		}
		return (endDate.getTime() + offset) - startDate.getTime();
	}
	
	public function getUptime():String {
		trace(channel, recordedAt);
		if (recordedAt == "") {
			return "Cant get uptime information.";
		}
		var timeString:String = removeTZ(recordedAt);
		
		var startDateDif:Date = Date.fromString(timeString);
		var endDateDif:Date = Date.now();
		var offset:Float = (getTimezoneOffset()) * 60 * 1000;
		var diffVar:Float = diffOfDates(startDateDif, endDateDif, true);
		diffVar -= recorderLength * 1000;
		
		var stringResult = "";
		if (recorderLength > 0) {
			stringResult = "Went offline for ";
		} else {
			diffVar += timeBetweenVods;
		}
		
		stringResult += timeToText(Math.round(diffVar));
		if (recorderLength > 0) {
		   stringResult += "Last stream length: " + timeToText(recorderLength * 1000 + timeBetweenVods); 
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
	
	private function timeToText(time:Float):String {
		var diff:Int = Math.floor(time / 1000);
		var hours:Int = Math.floor(diff / 60 / 60);
		diff -= hours * 60 * 60;
		var minutes:Int = Math.floor(diff / 60);
		diff -= minutes * 60;
		var seconds:Int = Math.round(diff);
		return addZero(hours) + "h " + addZero(minutes) + "m " + addZero(seconds) + "s. ";
	}
	
	private function removeTZ(str:String):String {
		str = StringTools.replace(str, "T", " ");
		str = StringTools.replace(str, "Z", "");
		return str;
	}
	
}