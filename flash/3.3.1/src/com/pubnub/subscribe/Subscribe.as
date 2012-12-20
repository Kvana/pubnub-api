package com.pubnub.subscribe {
	import com.pubnub.*;
	import com.pubnub.connection.*;
	import com.pubnub.environment.*;
	import com.pubnub.json.*;
	import com.pubnub.net.*;
	import com.pubnub.operation.*;
	import flash.events.*;
	import flash.utils.*;
	import org.casalib.util.*;
	use namespace pn_internal;
	
	/**
	 * ...
	 * @author firsoff maxim, support@pubnub.com
	 */
	public class Subscribe extends EventDispatcher {
		static public const PNPRES_PREFIX:String = '-pnpres';
		static public const SUBSCRIBE:String = 'subscribe';
		static public const INIT_SUBSCRIBE:String = 'init_subscribe';
		static public const LEAVE:String = 'leave';
		
		public var subscribeKey:String;
		public var sessionUUID:String;
		public var cipherKey:String;
		
		protected var _origin:String = "";
		protected var _connected:Boolean;
		
		protected var _connectionUID:String;
		protected var lastToken:String;
		protected var factory:Dictionary;
		protected var _destroyed:Boolean;
		protected var _channels:Array;
		
		protected var connection:AsyncConnection;
		
		public function Subscribe() {
			super(null);
			init();	
		}
		
		protected function init():void {
			_channels = [];
			factory = new Dictionary();
			factory[INIT_SUBSCRIBE] = 	getSubscribeInitOperation;
			factory[SUBSCRIBE] = 		getSubscribeOperation;
			factory[LEAVE] = 			getLeaveOperation;
			
			connection = new AsyncConnection();
		}
		
		/**
		 * Subscibe to a channel or multiple channels (use format: "ch1,ch2,ch3...")
		 * @param	channel
		 * @return	Boolean  result of subcribe (true if is subscribe to one channel or more channels)
		 */
		public function subcribe(channel:String):Boolean {
			if (isChannelCorrect(channel) == false) {
				return false;
			}
			// search of channels
			var addCh:Array = [];
			var temp:Array = channel.split(',');
			var ch:String;
			for (var i:int = 0; i < temp.length; i++) {
				ch = StringUtil.removeWhitespace(temp[i]);
				if (hasChannel(ch)) {
					dispatchEvent(new SubscribeEvent(SubscribeEvent.ERROR, [ -1, Errors.ALREADY_CONNECTED, ch]));
				}else {
					addCh.push(ch);
				}
			}
			process(addCh);
			return addCh.length > 0;
		}
		
		public function unsubscribe(channel:String, reason:Object = null):Boolean {
			if (isChannelCorrect(channel) == false) {
				dispatchEvent(new SubscribeEvent(SubscribeEvent.ERROR, [ -1, Errors.NOT_CONNECTED, ch]));
				return false;
			}
			// search of channels
			var removeCh:Array = [];
			var temp:Array = channel.split(',');
			var ch:String;
			for (var i:int = 0; i < temp.length; i++) {
				ch = StringUtil.removeWhitespace(temp[i]);
				if (hasChannel(ch)) {
					removeCh.push(ch);
				}else {
					dispatchEvent(new SubscribeEvent(SubscribeEvent.ERROR, [ -1, Errors.NOT_CONNECTED, ch]));
				}
			}
			process(null, removeCh, reason);
			return removeCh.length > 0;
		}
		
		public function unsubscribeAll(reason:Object = null):void {
			var allChannels:String = _channels.join(',');
			unsubscribe(allChannels, reason);
		}
		
		private function process(addCh:Array = null, removeCh:Array = null, reason:Object = null):void {
			var needAdd:Boolean = addCh && addCh.length > 0;
			var needRemove:Boolean = removeCh && removeCh.length > 0;
			if (needAdd || needRemove) {
				connection.close();
				if (needRemove) {
					var removeChStr:String = removeCh.join(',');
					leave(removeCh.join(removeChStr));
					ArrayUtil.removeItems(_channels, removeCh);
					dispatchEvent(new SubscribeEvent(SubscribeEvent.DISCONNECT, { channel:removeChStr, reason : (reason ? reason : '') } ));	
				}
				
				if (needAdd) {
					_channels = _channels.concat(addCh);
				}
				
				if (_channels.length > 0) {
					if (lastToken) {
						doSubscribe();
					}else {
						subscribeInit();
					}
				}else {
					lastToken = null;
				}
			}
		}
		
		private function isChannelCorrect(channel:String):Boolean{
			// if destroyd it is allways false
			var result:Boolean = !_destroyed;
			// check String
			if (channel ==  null || channel.length > int.MAX_VALUE) {
				dispatchEvent(new SubscribeEvent(SubscribeEvent.ERROR, [ -1, Errors.SUBSCRIBE_CHANNEL_ERROR, channel]));
				result = false;
			}
			return result;
		}
		
		/*---------------------------INIT---------------------------*/
		protected function subscribeInit():void {
			//trace('subscribeInit');
			_connectionUID = PnUtils.getUID();
			var operation:Operation = getOperation(INIT_SUBSCRIBE);
			connection.sendOperation(operation);	
		}
		
		protected function onSubscribeInit(e:OperationEvent):void {
			lastToken =  e.data[1];
			//trace(this, ' onConnectInit : ' + lastToken);
			_connected = true;
			dispatchEvent(new SubscribeEvent(SubscribeEvent.CONNECT,  { channel:_channels.join(',') } ));
			destroyOperation(e.target as Operation);
			doSubscribe();
		}
		
		protected function onSubscribeInitError(e:OperationEvent):void {
			dispatchEvent(new SubscribeEvent(SubscribeEvent.ERROR, [ -1, Errors.SUBSCRIBE_INIT_ERROR]));
			destroyOperation(e.target as Operation);
		}
		
		/*---------------------------SUBSCRIBE---------------------------*/
		private function doSubscribe():void {
			var operation:Operation = getOperation(SUBSCRIBE);
			connection.sendOperation(operation);
		}
		
		protected function onConnect(e:OperationEvent):void {
			var responce:Object = e.data;
			
			// something is wrong
			if (responce == null) {
				doSubscribe();
				return;
			}
			
			var messages:Array = responce[0] as Array;
		
			lastToken = responce[1];
			var chStr:String = responce[2];
			/*
			 * MX (array.length = 3)
			 * responce = [['m1', 'm2', 'm3', 'm4'], lastToken, ['ch1', 'ch2', 'ch2', 'ch3']];
			 * 
			 * ch1 - m1
			 * ch2 - m2,m3
			 * ch3 - m4
			 * 
			 * Single channel responce (array.length = 2)
			 * responce = [['m1', 'm2', 'm3', 'm4'], lastToken];
			*/
			
			var multiplexResponce:Boolean = chStr && chStr.length > 0 && chStr.indexOf(',') > -1;
			var presenceResponce:Boolean = chStr && chStr.indexOf(PNPRES_PREFIX) > -1;
			var channel:String;
			
			if (presenceResponce) {
				dispatchEvent(new SubscribeEvent(SubscribeEvent.PRESENCE, {channel:chStr, message : messages}));
			}else {
				if (!messages) return;
				decryptMessages(messages);
				
				if (multiplexResponce) {
					var chArray:Array = chStr.split(',');
					for (var i:int = 0; i < messages.length; i++) {
						channel = chArray[i];
						var message:* = messages[i]
						if (hasChannel(channel)) {
							dispatchEvent(new SubscribeEvent(SubscribeEvent.DATA, {channel:channel, message : message}));
						}
					}
				}else {
					channel = chStr;
					dispatchEvent(new SubscribeEvent(SubscribeEvent.DATA, {channel:channel, message : messages}));
				}
			}
			doSubscribe();
        }
		
		private function decryptMessages(messages:Array):void {
			 if (messages) {
                for (var i:int = 0; i < messages.length; i++) {
                    var msg:* = cipherKey.length > 0 ? PnJSON.parse(PnCrypto.decrypt(cipherKey, messages[i])) : messages[i];
					messages[i] = msg;
                }
            }
		}
		
		protected function onConnectError(e:OperationEvent):void {
			trace('onSubscribeError!');
			dispatchEvent(new SubscribeEvent(SubscribeEvent.ERROR, [ -1, Errors.SUBSCRIBE_CHANNEL_ERROR] ));
			destroyOperation(e.target as Operation);
		}
		
		/*---------------------------LEAVE---------------------------------*/
		protected function leave(channel:String):void {
			//trace('LEAVE : ' + channel);
			var operation:Operation = getOperation(LEAVE, channel);
			Pn.pn_internal::syncConnection.sendOperation(operation);
		}
		
		protected function getOperation(type:String, ...rest):Operation {
			return factory[type].apply(null, rest);
		}
		
		protected function destroyOperation(op:Operation):void {
			op.destroy();
		}
		
		protected function getSubscribeInitOperation(args:Object = null):Operation {
			var operation:SubscribeInitOperation = new SubscribeInitOperation(origin);
			operation.setURL(null, {
				channel:this.channelsString,
				subscribeKey : subscribeKey,
				uid:sessionUUID} );
			operation.addEventListener(OperationEvent.RESULT, 	onSubscribeInit);
			operation.addEventListener(OperationEvent.FAULT, 	onSubscribeInitError);
			return operation;
		}
		
		protected function getSubscribeOperation():Operation {
			var operation:SubscribeOperation = new SubscribeOperation(origin);
			operation.setURL(null, {
				timetoken: lastToken,
				subscribeKey : subscribeKey,
				channel:this.channelsString, 
				uid:sessionUUID} );
			operation.addEventListener(OperationEvent.RESULT, onConnect);
			operation.addEventListener(OperationEvent.FAULT, onConnectError);
			return operation;
		}
		
		protected function getLeaveOperation(channel:String):Operation {
			var operation:LeaveOperation = new LeaveOperation(origin);
			operation.setURL(null, {
				channel:channel,
				uid: sessionUUID,
				subscribeKey : subscribeKey
			});
			return operation;
		}
			
		public function get connected():Boolean {
			return _connected;
		}
		
		public function get origin():String {
			return _origin;
		}
		
		public function set origin(value:String):void {
			_origin = value;
		}
		
		public function get connectionUID():String {
			return _connectionUID;
		}
		
		public function set connectionUID(value:String):void {
			_connectionUID = value;
		}
		
		public function get destroyed():Boolean {
			return _destroyed;
		}
		
		public function destroy():void {
			if (_destroyed) return;
			_destroyed = true;
			close();
			connection.destroy();
			connection = null;
		}
		
		public function reconnect():void {
			if (lastToken) {
				doSubscribe();
			}else {
				subscribeInit();
			}	
		}
		
		public function close(reason:String = null):void {
			unsubscribeAll(reason);
			connection.close();
			if (_channels.length > 0) {
				leave(_channels.join(','));
			}
			_channels.length = 0;
			_connected = false;
			lastToken = null;
		}
		
		protected function get channelsString():String {
			var result:String = '';
			var len:int = _channels.length;
			var comma:String = ',';
			for (var i:int = 0; i < len; i++) {
                if (i == (len - 1)) {
					result += _channels[i]
				}else {
					result += _channels[i] + comma;
                }
			}
			return result; 
		}
		
		public function get channels():Array {
			return _channels;
		}
		
		private function hasChannel(ch:String):Boolean{
			return (ch != null && _channels.indexOf(ch) > -1);
		}
	}
}