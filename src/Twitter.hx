package;

import haxe.Constraints.Function;
import haxe.Http;
import haxe.Timer;
import htmlparser.HtmlDocument;

/**
 * ...10.07.2017 22:47
 * @author 23rd
 */
class Twitter {
	
	private var username:String;
	private var channel:String;
	private var timestamp:Float = 0;
	private var tweetText:String;
	private var timer:Timer;
	
	private var sendFunc:Function;

	public function new(username:String, channel:String, func:Function) {
		this.channel = channel;
		sendFunc = func;
		this.username = username;
		
		timer = new Timer(1 * 1000 * 60); // 5 minutes
		timer.run = checkNewTweet;
		timer.run();
	}
	
	private function checkNewTweet():Void {
		if (timestamp == 0) {
			loadLastTweet();
			return;
		}
		var time:Float = timestamp;
		loadLastTweet();
		if (time != timestamp) {
			Reflect.callMethod(this, sendFunc, [toString(), channel]);
		}
	}
	
	function loadLastTweet() {
		var html:HtmlDocument = new HtmlDocument(Http.requestUrl("https://twitter.com/" + username), true);
		var pinned:Int = html.find(".user-pinned").length;
		timestamp = Std.parseFloat(html.find(".tweet-timestamp")[pinned].find("span")[0].getAttribute("data-time-ms"));
		tweetText = html.find(".TweetTextSize")[pinned].innerText;
		
		var regPic:EReg = new EReg(" (pic.twitter.com/)[a-zA-Z0-9-_]{0,}", "g");
		tweetText = regPic.replace(tweetText, "");
	}
	
	public function toString():String {
		return tweetText + " (" + Date.fromTime(timestamp).toString() + ").";
	}
	
}