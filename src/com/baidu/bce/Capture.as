package com.baidu.bce {
    // import com.baidu.bce.utils.Logger;

    import flash.display.Sprite;
    import flash.display.StageScaleMode;
    import flash.events.Event;
    import flash.events.NetStatusEvent;
    import flash.events.SecurityErrorEvent;
    import flash.events.StatusEvent;
    import flash.media.Camera;
    import flash.media.Microphone;
    import flash.media.Video;
    import flash.media.H264VideoStreamSettings;
    import flash.net.NetConnection;
    import flash.net.NetStream;
    import flash.utils.*;
    import flash.system.SecurityPanel;
    import flash.system.Security;

    public class Capture extends Sprite {
        // 麦克风列表
        private var _microphones:Array = Microphone.names;
        // 摄像头列表
        private var _cameras:Array = Camera.names;

        private var _config:Object;

        private var _connection:NetConnection;
        private var _stream:NetStream;
        private var _video:Video;
        private var _camera:Camera;
        private var _microphone:Microphone;
        private var _application:String;
        private var _applicationId:String;

        private var _interval:Number;

        private var screen_w:int;
        private var screen_h:int;

        public function Capture() {
            SwfEventRouter.initExternalCall(this);
            stage.scaleMode = StageScaleMode.SHOW_ALL;

            SwfEventRouter.triggerJsEvent('microphones', _microphones);
            SwfEventRouter.triggerJsEvent('cameras', _cameras);
            SwfEventRouter.triggerJsEvent('log', 'Capture.Ready');
        }

        /**
         * 初始化
         */
        public function setup(config:Object):void {
            _config = config;

            initCamera();
            initMicrophone();
        }

        /**
         * 开始推流
         * @param  {Object} config 配置项
         * @param {String} config.remote rtmp推流地址
         */
        public function publish(config:Object):void {
            initNetConnection();
            connect(config.remote);

            _interval = setInterval(upStreamInfo, 1000);
        }

        /**
         * 停止推流
         */
        public function stop():void {

            _video.attachCamera(null);
            removeChild(_video);

            // _stream.attachCamera(null);
            // _stream.attachAudio(null);
            _stream.close();
            _stream = null;

            _connection.close();
            _camera = null;
            _microphone = null;
            _connection = null;

            _video = null;
            clearInterval(_interval);

            SwfEventRouter.triggerJsEvent('streamInfo', {
                fps: 0,
                quality: 0,
                audioQuality: 0,
                videoQuality: 0,
                KeyFrameInterval: 0,
                byteCount: 0,
                audioCodec: 'null',
                videoCodec: 'null',
                width: 0,
                height: 0,
                micName: 'null',
                cameraName: 'null'
            });
        }

        private function upStreamInfo():void {
            if (!_stream) {
                return;
            }
            // 当前帧率:   0.00
            // 音频码率:   0.00(kbps)
            // 视频码率:   0.00(kbps)
            // 当前码率:   0.00(kbps)
            // 关键帧间隔:  0
            // 发送字节数：0(byte)
            // 音频编码:   Speex
            // 视频编码:   h264
            // 原始视频宽度: 320
            // 原始视频高度: 240
            // 音频设备:   内建麦克风
            // 视频设备:   FaceTime 高清摄像头
            SwfEventRouter.triggerJsEvent('streamInfo', {
                fps: _stream.currentFPS,
                quality: _stream.info.currentBytesPerSecond / 1000 * 8,
                audioQuality: _stream.info.audioBytesPerSecond / 1000 * 8,
                videoQuality: _stream.info.videoBytesPerSecond / 1000 * 8,
                KeyFrameInterval: _camera.keyFrameInterval,
                byteCount: _stream.info.byteCount,
                audioCodec: _microphone.codec,
                videoCodec: 'h264',
                width: _camera.width,
                height: _camera.height,
                micName: _microphone.name,
                cameraName: _camera.name
            });
        }

        private function initNetConnection():void {
            _connection = new NetConnection();
            _connection.client = {};
            _connection.client.onMetaData = this.onMetaData;

            _connection.addEventListener(NetStatusEvent.NET_STATUS, statusHandler);
            _connection.addEventListener(SecurityErrorEvent.SECURITY_ERROR, errorHandler);
        }

        private function connect(remote:String):void {
            if (remote.substr(0, 4) == 'rtmp') {
                var slash:Number = remote.lastIndexOf('/');

                _application = remote.substr(0, slash + 1);
                _applicationId = remote.substr(slash + 1);
            }
            _connection.connect(_application);
        }

        public function onBWDone():void {

        }

        private function onMetaData(obj:Object):void {
            trace(obj);
        }

        private function errorHandler(e:Event):void {
            // Logger.log(e);
        }

        private function statusHandler(event:NetStatusEvent):void {
            // Logger.log(event.info.code);
            SwfEventRouter.triggerJsEvent('log', event.info.code);

            switch (event.info.code) {
                case 'NetConnection.Connect.Success':
                    createStream();
                    break;

                case 'NetStream.Publish.Failed':
                    SwfEventRouter.triggerJsEvent('error', event.info.code);
                    break;

                case 'NetStream.Publish.Start':
                    break;
            }
        }

        private function createStream():void {
            var h264Settings:H264VideoStreamSettings = new H264VideoStreamSettings();
            _stream = new NetStream(_connection);
            _stream.addEventListener(NetStatusEvent.NET_STATUS, statusHandler);
            _stream.client = {};
            _stream.client.onMetaData = this.onMetaData;
            _stream.attachCamera(_camera);
            _stream.attachAudio(_microphone);
            _stream.videoStreamSettings = h264Settings;
            _stream.publish(_applicationId);
        }

        private function initCamera():void {
            // TODO 判断摄像头是否正常返回引用
            _camera = Camera.getCamera(this._config.camera.index);
            _camera.setMode(_config.camera.width, _config.camera.height, _config.camera.fps);
            _camera.setKeyFrameInterval(_config.camera.keyframeInterval);
            _camera.setQuality(_config.camera.kbps * 1000 / 8, 80);
            if (_camera && _camera.muted) {
                Security.showSettings(SecurityPanel.PRIVACY);
            } else if (_camera && !_camera.muted) {
                displayCameraVideo();
                SwfEventRouter.triggerJsEvent('cameraAccess');
                SwfEventRouter.triggerJsEvent('log', 'camera: ' + _camera.name + ' ready');
            }
            _camera.addEventListener(StatusEvent.STATUS, cameraStatusHandler);
        }

        private function cameraStatusHandler(e:StatusEvent):void {
            var _config:Object = this._config;
            if (e.code.toLowerCase() == 'camera.muted') {
                // 用户拒绝访问摄像头
                // Logger.log('用户拒绝访问摄像头');
                SwfEventRouter.triggerJsEvent('cameraAccessDeny');
                SwfEventRouter.triggerJsEvent('log', 'camera: ' + _camera.name + ' access deny');
            } else {
                displayCameraVideo();
                SwfEventRouter.triggerJsEvent('cameraAccess');
                SwfEventRouter.triggerJsEvent('log', 'camera: ' + _camera.name + ' ready');
            }
        }

        private function initMicrophone():void {
            _microphone = Microphone.getMicrophone(this._config.mic.index);
            _microphone.encodeQuality = 9;
            _microphone.codec = _config.mic.codec;  // 压缩音频的编解码器
            _microphone.rate = _config.mic.rate;    // 捕获声音的频率
            _microphone.gain = _config.mic.gain;    // 音量
            _microphone.encodeQuality = GetAudioQualityofSpeex(_config.mic.kbps);         // 使用 Speex 编解码器时的编码语音品质
            _microphone.setUseEchoSuppression(true);
            _microphone.setLoopBack(false);
            // _microphone.addEventListener(StatusEvent.STATUS, microphoneStatusHandler);
        }

        private function microphoneStatusHandler(e:StatusEvent):void {
            var _config:Object = this._config;
            if (e.code.toLowerCase() == 'microphone.muted') {
                // 用户拒绝访问麦克风
                // Logger.log('用户拒绝访问麦克风');
                SwfEventRouter.triggerJsEvent('microphoneAccessDeny');
                SwfEventRouter.triggerJsEvent('log', 'microphone: ' + _microphone.name + ' access deny');
            } else {
                SwfEventRouter.triggerJsEvent('microphoneAccess');
                SwfEventRouter.triggerJsEvent('log', 'microphone: ' + _microphone.name + ' ready');
            }
        }

        private function displayCameraVideo():void {
            if (_video) {
                return;
            }
            _video = new Video(stage.stageWidth, stage.stageHeight);
            _video.x = 0;
            _video.y = 0;
            _video.attachCamera(_camera);
            addChild(_video);
        }

        private function GetAudioQualityofSpeex(bitrate:uint):int
        {
            if (bitrate <= 4)
            {
                return 0;
            }
            if (bitrate <= 6)
            {
                return 1;
            }
            if (bitrate <= 8)
            {
                return 2;
            }
            if (bitrate <= 10)
            {
                return 3;
            }
            if (bitrate <= 13)
            {
                return 4;
            }
            if (bitrate <= 17)
            {
                return 5;
            }
            if (bitrate <= 21)
            {
                return 6;
            }
            if (bitrate <= 24)
            {
                return 7;
            }
            if (bitrate <= 28)
            {
                return 8;
            }
            if (bitrate <= 34)
            {
                return 9;
            }
            return 10;
        }
    }
}

class NetClient {
    private var callback:Object;
    public function NetClient(cbk:Object) {
        callback = cbk;
    }

    public function onBWDone():void {
    }

    public function onMetaData(obj:Object):void {
        trace(obj);
        callback.onMetaData(obj);
    }
}
