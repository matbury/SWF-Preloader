/**
 * This file is part of the SWF Activity Module for Moodle
 * Moodle is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * The SWF Activity Module and Moodle are distributed in the hope that
 * it will be useful, but WITHOUT ANY WARRANTY; without even the implied
 * warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See
 * the GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with Moodle.  If not, see <http://www.gnu.org/licenses/>.
 */

/**
 * Preloader app loads and displays external Flash applications/animations
 * Listens for grade events from loaded apps to send grades to AMFPHP services
 * 
 * IMPORTANT: Do not compile this a browser application for versions of Flash
 * Player later than 11.2, which is the latest version supported by Linux and
 * mobile devices. Consider compiling for Adobe AIR for later versions.
 * 
 * Copyright Matt Bury 2013
 * @author Matt Bury <matt@matbury.com>
 * @version 2013072900
 * @see https://github.com/matbury
 */
package
{
	import flash.display.Loader;
	import flash.display.MovieClip;
	import flash.display.DisplayObject;
	import flash.display.Sprite;
	import flash.display.Stage;
	import flash.display.StageScaleMode;
	import flash.display.StageAlign;
	//import flash.system.Security;
	import flash.events.*;
	import flash.net.URLRequest;
	import flash.text.*;
	import flash.utils.Timer;
	import com.matbury.sam.data.Amf;
	import com.matbury.sam.data.FlashVars;
	
	public class Main extends Sprite
	{
		private var _amf:Amf; // Flash remoting class communicates with AMFPHP services
		private var _t:TextField; // Displays messages for load progress, errors, etc.
		private var _bar:Sprite; // Load progess bar
		private var _loader:Loader; // Loads the external .swf file
		private var _bytes:String; // Total bytes in loading .swf file
		private var _content:MovieClip; // If loaded .swf is compatible, this references it
		private var _flashVars:String;
		private var _timer:Timer;
		private var _sessionTimer:Timer; // Warn users when server session is about to timeout
		private var _countdown:uint = 30;
		private var _centered:Boolean = false;
		private var _controls:Boolean = false;
		private var _up:Button;
		private var _down:Button;
		private var _left:Button;
		private var _right:Button;
		private var _step:int = 20;

		public function Main() {
			stage.scaleMode = StageScaleMode.NO_SCALE;
			stage.align = StageAlign.TOP_LEFT;
			stage.addEventListener(Event.RESIZE, resize);
			FlashVars.vars = this.root.loaderInfo.parameters; // Get FlashVars passed in from HTML embed code
			
			// The following commented out lines are for rapid testing in your Actionscript IDE
			// Edit and uncomment them to load apps for testing
			//FlashVars.xmlurl = "../../../../../moodle2data/repository/swfcontent/mixedmedia/butane.swf";
			//FlashVars.xmlurl = "../../../../../moodle2data/repository/swfcontent/mixedmedia/3d_cloud.swf";
			//FlashVars.xmlurl = "../../../../../moodle2data/repository/swfcontent/mixedmedia/cube_grid.swf";
			//FlashVars.xmlurl = "../../../../../moodle2data/repository/swfcontent/mixedmedia/engestrom_activity_theory.swf";
			//FlashVars.xmlurl = "../../../../../moodle2data/repository/swfcontent/mixedmedia/liquid_layout_demo.swf";
			//FlashVars.xmlurl = "../../../../../moodle2data/repository/swfcontent/mixedmedia/pv3d_cube.swf";
			//FlashVars.xmlurl = "../../../../../moodle2data/repository/swfcontent/mixedmedia/things_i_like.swf";
			//FlashVars.xmlurl = "../../../../../moodle2data/repository/swfcontent/mixedmedia/tubemap_inner.swf";
			//FlashVars.sessiontimeout = 40;
			
			if (this.root.loaderInfo.parameters.centered && this.root.loaderInfo.parameters.centered == "true") {
				_centered = true;
			}
			if (this.root.loaderInfo.parameters.controls && this.root.loaderInfo.parameters.controls == "true") {
				_controls = true;
			}
			initSessionTimer();
			initText();
			initBar();
			loadContent();
			resize();
		}
		
		/**
		 * Reposition objects if stage is resized
		 * @param	event
		 */
		private function resize(event:Event = null):void {
			positionText();
			positionBar();
			positionContent();
			positionButtons();
		}
		
		/*
		############################ SESSION TIMER ############################
		*/
		/**
		 * Initialise a timer that warns users when server session timeout is about to occur
		 */
		private function initSessionTimer():void {
			if(FlashVars.sessiontimeout != 0) {
				_sessionTimer = new Timer(1000,FlashVars.sessiontimeout - (_countdown + 5)); // Allow a little extra time for "brinksmanship" and slow connections
				_sessionTimer.addEventListener(TimerEvent.TIMER_COMPLETE, sessionTimerComplete);
				_sessionTimer.start();
			}
		}
		
		/**
		 * Session timeout is about to occur so warn user
		 * @param	event:flash.events.TimerEvent
		 */
		private function sessionTimerComplete(event:TimerEvent):void {
			_sessionTimer.removeEventListener(TimerEvent.TIMER_COMPLETE, sessionTimerComplete);
			initText();
			_sessionTimer = new Timer(1000,_countdown);
			_sessionTimer.addEventListener(TimerEvent.TIMER, sessionTimerCountdown);
			_sessionTimer.addEventListener(TimerEvent.TIMER_COMPLETE, sessionTimerCountdownComplete);
			_sessionTimer.start();
		}
		
		/**
		 * Display countdown to session timeout
		 * @param	event:flash.events.TimerEvent
		 */
		private function sessionTimerCountdown(event:TimerEvent):void {
			_countdown--;
			_t.text = "Your user session will timeout and you will not\n be able to save your grade in " + _countdown + " seconds.";
			positionText();
		}
		
		/**
		 * Session has timed out
		 * @param	event:flash.events.TimerEvent
		 */
		private function sessionTimerCountdownComplete(event:TimerEvent):void {
			_sessionTimer.removeEventListener(TimerEvent.TIMER, sessionTimerCountdown);
			_sessionTimer.removeEventListener(TimerEvent.TIMER_COMPLETE, sessionTimerCountdownComplete);
			_sessionTimer = null;
			_t.text = "Your user session has timed out.\nYou cannot save your grade.";
			positionText();
		}
		
		private function deleteSessionTimer():void {
			if(_sessionTimer) {
				_sessionTimer.stop();
				if(_sessionTimer.hasEventListener(TimerEvent.TIMER_COMPLETE)) {
				   _sessionTimer.removeEventListener(TimerEvent.TIMER_COMPLETE, sessionTimerComplete);
				}
				if(_sessionTimer.hasEventListener(TimerEvent.TIMER_COMPLETE)) {
				   _sessionTimer.removeEventListener(TimerEvent.TIMER_COMPLETE, sessionTimerCountdown);
				   _sessionTimer.removeEventListener(TimerEvent.TIMER_COMPLETE, sessionTimerCountdownComplete);
				}
				_sessionTimer = null;
			}
		}
		
		/*
		############################ TEXT ############################
		*/
		/**
		 * Initialise text area
		 */
		private function initText():void {
			if(!_t) { // prevent duplicates
				var f:TextFormat = new TextFormat("Trebuchet MS",14,0x444444,true);
				f.align = TextFormatAlign.CENTER;
				_t = new TextField();
				_t.defaultTextFormat = f;
				_t.multiline = true;
				_t.wordWrap = true;
				_t.autoSize = TextFieldAutoSize.CENTER;
				_t.background = true;
				_t.text = "Loading... ";
				addChild(_t);
			}
		}
		
		/**
		 * Position text area
		 */
		private function positionText():void {
			if(_t) {
				_t.width = stage.stageWidth;
				_t.y = stage.stageHeight * 0.5;
			}
		}
		
		/**
		 * Delete text area
		 */
		private function deleteText():void {
			if(_t) {
				removeChild(_t);
				_t = null;
			}
		}
		
		/*
		################################ BAR ################################
		*/
		/**
		 * Initialise load progress bar
		 */
		private function initBar():void {
			if(!_bar) {
				_bar = new Sprite();
				_bar.graphics.beginFill(0x444444,1);
				_bar.graphics.drawRect(0,0,170,3);
				_bar.graphics.endFill();
				addChild(_bar);
			}
		}
		
		/**
		 * Position load progresss bar
		 */
		private function positionBar():void {
			if(_bar && _t) {
				_bar.x = (stage.stageWidth * 0.5) - 85;
				_bar.y = _t.y + _t.height;
			}
		}
		
		/**
		 * Delete load progress bar
		 */
		private function deleteBar():void {
			if(_bar) {
				removeChild(_bar);
				_bar = null;
			}
		}
		
		/*
		############################ LOAD CONTENT ############################
		*/
		/**
		 * Load app/movie
		 */
		private function loadContent():void {
			var url:String = FlashVars.xmlurl;
			if(url.indexOf(".swf") == -1) {
				_t.text = "Error: No Flash application URL was provided at xmlurl. Filetype must be .swf";
			} else {
				var request:URLRequest = new URLRequest(url);
				_loader = new Loader();
				addChild(_loader);
				configureListeners(_loader.contentLoaderInfo);
				_loader.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, uncaughtError);
				_loader.load(request);
			}
		}
		
		/**
		 * Add listeners to loader
		 * @param	dispatcher:flash.events.IEventDispatcher
		 */
		private function configureListeners(dispatcher:IEventDispatcher):void {
			dispatcher.addEventListener(ProgressEvent.PROGRESS, firstProgress);
			dispatcher.addEventListener(ProgressEvent.PROGRESS, progress);
			dispatcher.addEventListener(IOErrorEvent.IO_ERROR, ioError);
			dispatcher.addEventListener(SecurityErrorEvent.SECURITY_ERROR, securityError);
			dispatcher.addEventListener(Event.COMPLETE, complete);
		}
		
		/**
		 * Remove listeners from loader
		 * @param	dispatcher:flash.events.IEventDispatcher
		 */
		private function removeListeners(dispatcher:IEventDispatcher):void {
			dispatcher.removeEventListener(ProgressEvent.PROGRESS, progress);
			dispatcher.removeEventListener(IOErrorEvent.IO_ERROR, ioError);
			dispatcher.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, securityError);
			dispatcher.removeEventListener(Event.COMPLETE, complete);
		}
		
		/**
		 * Catch uncaught errors generated by loaded app
		 * @param	event:flash.events.UncaughtErrorEvent
		 */
		private function uncaughtError(event:UncaughtErrorEvent):void {
			// do nothing
		}
		
		/**
		 * Calculate total bytes in app to be loaded
		 * @param	event:flash.events.ProgressEvent
		 */
		private function firstProgress(event:ProgressEvent):void {
			_loader.contentLoaderInfo.removeEventListener(ProgressEvent.PROGRESS, firstProgress);
			if(event.bytesTotal >= 1048576) {
				_bytes = "of " + (Math.floor(event.bytesTotal / 1024) / 1000) + "MB";
			} else {
				_bytes = "of " + (Math.floor(event.bytesTotal / 1024)) + "KB";
			}
			//Security.allowDomain(_loader.contentLoaderInfo.url); // Beware: This can be insecure!
		}
		
		/**
		 * Display load progress
		 * @param	event:flash.events.ProgressEvent
		 */
		private function progress(event:ProgressEvent):void {
			var percent:Number = Math.floor(event.bytesLoaded / event.bytesTotal * 100);
			_t.text = "Loading... " + percent + "% " + _bytes;
			_bar.scaleX = percent * 0.01;
			positionText();
			positionBar();
		}
		
		/**
		 * Load failed so display error message
		 * @param	event:flash.events.IOErrorEvent
		 */
		private function ioError(event:IOErrorEvent):void {
			removeListeners(_loader.contentLoaderInfo);
			displayMessage(event.text);
		}
		
		/**
		 * Load failed so display error message
		 * @param	event:flash.events.SecurityErrorEvent
		 */
		private function securityError(event:SecurityErrorEvent):void {
			removeListeners(_loader.contentLoaderInfo);
			displayMessage(event.text);
		}
		
		/**
		 * Initialise loaded app and look for grading capabilities
		 * @param	event:flash.events.Event
		 */
		private function complete(event:Event):void {
			removeListeners(_loader.contentLoaderInfo);
			deleteText();
			deleteBar();
			// Detect loaded SWF version
			if (_loader.content.loaderInfo.actionScriptVersion == 3) {
				try {
					_content = _loader.content as MovieClip;
					// Is there access to grade book data?
					if(_content.rawgrade == 0) {
						_content.addEventListener("sendGrade", sendGrade);
						displayMessage("This app can save grades.");
					}
				} catch (e:Error) {
					displayMessage(e.message);
				}
			} else {
				// AVM1 Movies (AS1.0 and AS2.0) cannot interact with AVM2 (AS 3.0) applications reliably
				// Consider using SWFBridge: http://gskinner.com/blog/archives/2007/07/swfbridge_easie.html
				//trace(_loader.content.loaderInfo.swfVersion);
			}
			positionContent();
			if (_controls) {
				initButtons();
				positionButtons();
			}
			initTimer();
		}
		
		/**
		 * Position loaded app/movie to centre of stage
		 */
		private function positionContent():void {
			if (_loader && _centered) {
				_loader.x = stage.stageWidth * 0.5 - (_loader.width * 0.5);
				_loader.y = stage.stageHeight * 0.5 - (_loader.height * 0.45);
			}
		}
		
		/**
		 * Display text message
		 * @param	message:String
		 */
		private function displayMessage(message:String):void {
			initText();
			_t.text = message;
			positionText();
		}
		
		/*
		############################## BUTTONS ###############################
		*/
		private function initButtons():void {
			_up = new Button("up");
			_up.addEventListener(MouseEvent.MOUSE_UP, upUp);
			addChild(_up);
			_down = new Button("down");
			_down.addEventListener(MouseEvent.MOUSE_UP, downUp);
			addChild(_down);
			_left = new Button("left");
			_left.addEventListener(MouseEvent.MOUSE_UP, leftUp);
			addChild(_left);
			_right = new Button("right");
			_right.addEventListener(MouseEvent.MOUSE_UP, rightUp);
			addChild(_right);
		}
		
		private function positionButtons():void {
			if (_up) {
				_up.x = stage.stageWidth * 0.5;
				_up.y = 10;
				addChild(_up);
			}
			if (_down) {
				_down.x = stage.stageWidth * 0.5;
				_down.y = stage.stageHeight - 10;
				addChild(_down);
			}
			if (_left) {
				_left.x = 10;
				_left.y = stage.stageHeight * 0.5;
				addChild(_left);
			}
			if (_right) {
				_right.x = stage.stageWidth - 10;
				_right.y = stage.stageHeight * 0.5;
				addChild(_right);
			}
		}
		
		private function deleteButtons():void {
			if (_up) {
				removeChild(_up);
				_up.removeEventListener(MouseEvent.MOUSE_UP, upUp);
				_up = null;
			}
			if (_down) {
				removeChild(_down);
				_down.removeEventListener(MouseEvent.MOUSE_UP, downUp);
				_down = null;
			}
			if (_left) {
				removeChild(_left);
				_left.removeEventListener(MouseEvent.MOUSE_UP, leftUp);
				_left = null;
			}
			if (_right) {
				removeChild(_right);
				_right.removeEventListener(MouseEvent.MOUSE_UP, rightUp);
				_right = null;
			}
		}
		
		private function upUp(event:MouseEvent):void {
			_loader.y -= _step;
		}
		
		private function downUp(event:MouseEvent):void {
			_loader.y += _step;
		}
		
		private function leftUp(event:MouseEvent):void {
			_loader.x -= _step;
		}
		
		private function rightUp(event:MouseEvent):void {
			_loader.x += _step;
		}
		
		/*
		############################ SEND GRADE #############################
		*/
		/**
		 * 
		 * @param	event:flash.events.Event
		 */
		private function sendGrade(event:Event = null):void {
			//trace("Preloader has caught sendGrade event");
			deleteSessionTimer();
			initText();
			positionText();
			_t.text = "Sending grade... ";
			_amf = new Amf(); // create Flash Remoting API object
			_amf.addEventListener(Amf.GOT_DATA, gotDataHandler); // listen for server response
			_amf.addEventListener(Amf.FAULT, faultHandler); // listen for server fault
			var obj:Object = new Object(); // create an object to hold data sent to the server
			obj.gateway = FlashVars.gateway; // (String) AMFPHP gateway URL
			obj.swfid = FlashVars.swfid; // (int) activity ID
			obj.instance = FlashVars.instance; // (int) Moodle instance ID
			try {
				obj.feedback = _content.feedback; // (String) optional
			} catch(error:Error) {
				obj.feedback = "No feedback recorded.";
			}
			try {
				obj.feedbackformat = _content.feedbackformat; // deprecated
				obj.timeelapsed = _content.feedbackformat; // (int) elapsed time in seconds
			} catch(error:Error) {
				obj.feedbackformat = 0; // deprecated
				obj.timeelapsed = 0;
			}
			try {
				obj.rawgrade = _content.rawgrade; // (Number) grade, normally 0 - 100 but depends on grade book
			} catch(error:Error) {
				obj.rawgrade = 0;
			}
			_flashVars += "\n gateway = " + obj.gateway;
			_flashVars += "\n swfid = " + obj.swfid;
			_flashVars += "\n instance = " + obj.instance;
			_flashVars += "\n feedback = " + obj.feedback;
			_flashVars += "\n feedbackformat = " + obj.feedbackformat;
			_flashVars += "\n rawgrade = " + obj.rawgrade;
			//_t.appendText(_flashVars);
			obj.servicefunction = "Grades.amf_grade_update"; // (String) ClassName.method_name
			_amf.getObject(obj); // send the data to the server
		}
		
		/**
		 * Connection to AMFPHP succeeded
		 * Manage returned data and inform user
		 * @param	event:flash.events.Event
		 */
		private function gotDataHandler(event:Event):void {
			// Clean up listeners
			_amf.removeEventListener(Amf.GOT_DATA, gotDataHandler);
			_amf.removeEventListener(Amf.FAULT, faultHandler);
			// Check if grade was sent successfully
			try {
				switch(_amf.obj.result) {
					//
					case "SUCCESS":
					_t.appendText("\n Your grade has been saved.");
					initTimer();
					break;
					//
					case "NO_PERMISSION":
					_t.appendText("\n You do not have permission to save grades.");
					break;
					//
					default:
					_t.appendText("\n Unknown error.");
				}
			} catch(e:Error) {
				_t.appendText("\n Unknown error.");
			}
		}
		
		/**
		 * Display server errors
		 * @param	event:flash.events.TimerEvent
		 */
		private function faultHandler(event:Event):void {
			// clean up listeners
			_amf.removeEventListener(Amf.GOT_DATA, gotDataHandler);
			_amf.removeEventListener(Amf.FAULT, faultHandler);
			var msg:String = "AMF3 Error:";
			for(var s:String in _amf.obj.info) { // trace out returned data
				msg += "\n" + s + "=" + _amf.obj.info[s];
			}
			_t.text = msg + _flashVars;
		}
		
		/**
		 * Countdown timer to delete text messages
		 */
		private function initTimer():void {
			if(_t) {
				_timer = new Timer(1000,5);
				_timer.addEventListener(TimerEvent.TIMER_COMPLETE, timerComplete);
				_timer.start();
			}
		}
		
		/**
		 * Delete text message
		 * @param	event:flash.events.TimerEvent
		 */
		private function timerComplete(event:TimerEvent = null):void {
			_timer.removeEventListener(TimerEvent.TIMER_COMPLETE, timerComplete);
			_timer = null;
			removeChild(_t);
			_t = null;
		}
	}
} // End of class
