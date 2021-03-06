package yukkuplayer;

import flash.Lib;
import flash.events.Event;
import flash.display.MovieClip;
import flash.display.Stage;
import flash.events.EventDispatcher;
import flash.media.Video;
import flash.net.NetConnection;
import flash.net.NetStream;
import flash.display.MovieClip;
import flash.net.NetStreamPlayOptions;
import flash.events.NetStatusEvent;
import flash.events.AsyncErrorEvent;
import flash.media.StageVideo;
import flash.media.StageVideoAvailability;
import flash.events.StageVideoAvailabilityEvent;
import flash.display.Sprite;
import flash.text.TextField;
import flash.events.MouseEvent;
import flash.events.FullScreenEvent;
import flash.media.SoundTransform;
import flash.geom.Rectangle;
import flash.display.StageDisplayState;
import flash.system.Capabilities;
import flash.net.SharedObject;
import flash.net.URLRequest;
import flash.display.Loader;
import flash.display.Bitmap;
import flash.display.LoaderInfo;
import flash.system.LoaderContext;
import flash.external.ExternalInterface;

import openfl.net.URLLoader;
import openfl.net.URLLoaderDataFormat;
import openfl.net.URLRequest;

import com.yagp.GifDecoder;
import com.yagp.Gif;
import com.yagp.GifPlayer;
import com.yagp.GifPlayerWrapper;

import yukkuplayer.controls.VolumeSlider;
import yukkuplayer.controls.VolumeIcon;
import yukkuplayer.controls.PauseIcon;
import yukkuplayer.controls.FullscreenIcon;

class VideoPlayer extends EventDispatcher {
    private var m_persist : SharedObject;
    private var m_buffer : Float;
    private var m_stage : Stage;
    private var m_movieClip : MovieClip;
    private var m_rtmpApp : String;
    private var m_playOptions : NetStreamPlayOptions;
    private var m_connection : NetConnection;
    private var m_stream : NetStream;
    private var m_accel : Bool;
    private var m_width : Float;
    private var m_height : Float;
    private var m_oldwidth : Float;
    private var m_oldheight : Float;
    private var m_volume : Float;

    private var m_muted : Bool;
    private var m_paused : Bool;
    private var m_playing : Bool;
    private var m_connOk : Bool;

    private var m_accelVideo: StageVideo;
    private var m_plainVideo: Video;
    private var m_iconBottom : Sprite;
    private var m_iconTop : Sprite;
    private var m_volumeSlider : VolumeSlider;
    private var m_volumeIcon : VolumeIcon;
    private var m_pauseIcon : PauseIcon;
    private var m_fullscreenIcon : FullscreenIcon;
    private var m_infoDigest : TextField;
    private var m_idleImage : GifPlayerWrapper;
    private var m_idleOverlay : Sprite;
    private var m_loadedImage : Bool;
    private var m_idleWidth : Float;
    private var m_idleHeight : Float;
    private var m_stub : Bool;

    public function new(videoUrl : String, buffer: Float, idleImageUrl : String, stub : Bool) {
        super();

        m_stub = stub;

        m_buffer = buffer;
        m_stage = Lib.current.stage;
        m_movieClip = Lib.current;

        m_width = 0;
        m_height = 0;

        m_muted = false;
        m_paused = false;
        m_playing = false;
        m_connOk = false;

        m_persist = null;
        m_volume = 1.0;

        m_loadedImage = false;

        m_idleOverlay = new Sprite();
        m_idleOverlay.visible = !m_stub;
        m_movieClip.addChild(m_idleOverlay);



        var l = new URLLoader();
        l.dataFormat = URLLoaderDataFormat.BINARY;
        l.addEventListener(Event.COMPLETE, function(e : Event) {
            var gif : Gif = GifDecoder.parseByteArray(l.data);
            m_idleImage = new GifPlayerWrapper(new GifPlayer(gif));

            m_idleOverlay.addChild(m_idleImage);
            m_loadedImage = true;
            m_idleWidth = m_idleImage.width;
            m_idleHeight = m_idleImage.height;
            positionIdle();
        });

        l.load(new URLRequest(idleImageUrl));


        initUrls(videoUrl);
        initNet();

        m_stage.addEventListener(StageVideoAvailabilityEvent.STAGE_VIDEO_AVAILABILITY, onStageVideoState);
        m_stage.addEventListener(Event.RESIZE, onResize);
        m_stage.addEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);

    }

    private function displayOnline() {
        ExternalInterface.call("flash_online");
    }

    private function displayOffline() {
        ExternalInterface.call("flash_offline");
        /*
        if (m_accel) {
            //m_accelVideo.clear();
        } else {
            m_plainVideo.clear();
        }
        */
    }

    private function initPersist() {
        m_persist = SharedObject.getLocal("yukkuplayer");
        var vol:Float = m_persist.data.volume;

        if (Math.isNaN(vol)) {
            vol = m_volume;
        }

        setVolume(vol);
    }

    private function initUrls(videoUrl : String) {
        var r = ~/^(.*\/)([^\/]+)$/;

        r.match(videoUrl);

        m_rtmpApp = r.matched(1);

        m_playOptions = new NetStreamPlayOptions();
        m_playOptions.oldStreamName = null;
        m_playOptions.streamName = r.matched(2);
        m_playOptions.len = -1;
        m_playOptions.offset = -1;
        m_playOptions.start = -2;
        m_playOptions.transition = "reset";
    }

    private function initNet() {
        m_connOk = false;
        m_connection = new NetConnection();
        m_connection.addEventListener(NetStatusEvent.NET_STATUS, onNetStatus);
        m_connection.addEventListener(AsyncErrorEvent.ASYNC_ERROR, onAsyncError);
        m_connection.client = this;
        m_connection.connect(m_rtmpApp);
    }

    private function initStream() {
        m_stream = new NetStream(m_connection);
        m_stream.addEventListener(NetStatusEvent.NET_STATUS, onNetStatus);
        m_stream.bufferTime = m_buffer;
        m_stream.bufferTimeMax = m_buffer * 2;
        m_stream.backBufferTime = m_buffer;
        m_stream.dataReliable = false;
        m_stream.audioReliable = false;
        m_stream.videoReliable = false;
        m_stream.client = this;
        initPersist();
    }

    private function initGUI() {
        m_iconBottom = new Sprite();
        m_iconBottom.visible = false;

        m_pauseIcon = new PauseIcon(0, 0, 32, 32, 0xFFFFFF, 0x4c4c4c);
        m_pauseIcon.addEventListener(MouseEvent.CLICK, onPauseClick);
        m_iconBottom.addChild(m_pauseIcon);

        m_fullscreenIcon = new FullscreenIcon(0, 0, 32, 32, 0xFFFFFF, 0x4c4c4c);
        m_fullscreenIcon.addEventListener(MouseEvent.CLICK, onFullscreenIcon);
        m_iconBottom.addChild(m_fullscreenIcon);

        m_volumeIcon = new VolumeIcon(0, 0, 32, 32, 0xFFFFFF, 0x4c4c4c);
        m_volumeIcon.addEventListener(MouseEvent.CLICK, onVolumeClick);
        m_iconBottom.addChild(m_volumeIcon);

        m_volumeSlider = new VolumeSlider(0, 0, 64, 16);
        m_volumeSlider.addEventListener(MouseEvent.CLICK, onVolumeSliderClick);
        m_iconBottom.addChild(m_volumeSlider);

        m_iconTop = new Sprite();
        m_iconTop.visible = false;

        m_infoDigest = new TextField();
        m_infoDigest.height= 20;
        m_infoDigest.thickness = 1;
        m_infoDigest.selectable = false;
        m_infoDigest.textColor = 0xFFFFFF;
        m_infoDigest.mouseEnabled = false;
        m_iconTop.addChild(m_infoDigest);


        var offt = new haxe.Timer(5000);
        offt.run = function() {
            if (!m_paused) {
                if (m_stream.info.currentBytesPerSecond == 0) {
                    if (!m_stub) {
                        displayOffline();
                    }
                } else {
                    //displayOnline();
                }
            }
        };


        var tt:haxe.Timer = new haxe.Timer(1000);
        tt.run = function() {
            m_infoDigest.text = "Accel: " + m_accel + " with " + Math.round(m_stream.currentFPS) + " FPS at " + m_width + "x" + m_height + " delay: " + m_stream.liveDelay + " buffer: " + m_stream.bufferTime +"s kbps: " + Math.round(m_stream.info.currentBytesPerSecond/1024) + " drop: " + m_stream.info.droppedFrames;
        };

        m_movieClip.addChild(m_iconTop);
        m_movieClip.addChild(m_iconBottom);

        positionGui();
    }

    private function positionGui():Void {
        m_infoDigest.width = m_stage.stageWidth;
        m_infoDigest.x = 10;
        m_infoDigest.y = 2;

        m_idleOverlay.graphics.clear();
        m_idleOverlay.graphics.beginFill(0x000000, 1.0);
        m_idleOverlay.graphics.drawRect(0, 0, m_stage.stageWidth, m_stage.stageHeight);
        m_idleOverlay.graphics.endFill();

        m_iconTop.graphics.clear();
        m_iconTop.graphics.beginFill(0x000000, 0.3);
        m_iconTop.graphics.drawRect(0, 0, m_stage.stageWidth, m_infoDigest.height);
        m_iconTop.graphics.endFill();

        m_iconBottom.graphics.clear();
        m_iconBottom.graphics.beginFill(0x000000, 0.3);
        m_iconBottom.graphics.drawRect(0, m_stage.stageHeight-128, m_stage.stageWidth, 128);
        m_iconBottom.graphics.endFill();

        m_volumeSlider.setPosition(m_stage.stageWidth/3*2+32, m_stage.stageHeight-64-8);
        m_volumeIcon.setPosition(m_stage.stageWidth/3*2-16,m_stage.stageHeight-64-16);
        m_pauseIcon.setPosition(m_stage.stageWidth/3*1-16,m_stage.stageHeight-64-16);
        m_fullscreenIcon.setPosition(m_stage.stageWidth/2,m_stage.stageHeight-64-16);
    }

    private function playVideo() {
        if (m_accel) {
            m_accelVideo.attachNetStream(m_stream);
        } else {
            m_plainVideo.attachNetStream(m_stream);
        }

        if (m_muted) {
          setVolume(0.0);
        }

        if (!m_paused) {
            m_stream.play2(m_playOptions);
        }
    }

    private function positionIdle() {
        if (m_loadedImage) {
            var mw : Float;
            var mh : Float;
            var mx : Float;
            var my : Float;

            //mw = m_idleWidth * m_stage.stageHeight / m_idleHeight;
            //mh = m_stage.stageHeight;
            mw = m_idleWidth;
            mh = m_idleHeight;
            mx = (m_stage.stageWidth / 2) - (mw / 2);
            my = (m_stage.stageHeight / 2) - (mh / 2);

            if (mw > m_stage.stageWidth) {
                //mw = m_stage.stageWidth;
                //mh = m_idleHeight * m_stage.stageWidth / m_idleWidth;
                mw = m_idleWidth;
                mh = m_idleHeight;
                mx = 0;
                my = (m_stage.stageHeight / 2) - (mh / 2);
            } else {
            }

            m_idleImage.x = mx;
            m_idleImage.y = my;
            m_idleImage.width = mw;
            m_idleImage.height = mh;
        }
    }

    private function resizeAndCenter() {
        var mw : Float;
        var mh : Float;
        var mx : Float;
        var my : Float;

        mw = m_width * m_stage.stageHeight / m_height;
        mh = m_stage.stageHeight;
        mx = (m_stage.stageWidth / 2) - (mw / 2);
        my = 0;

        if (mw > m_stage.stageWidth) {
            mw = m_stage.stageWidth;
            mh = m_height * m_stage.stageWidth / m_width;
            mx = 0;
            my = (m_stage.stageHeight / 2) - (mh / 2);
        } else {
        }

        if (m_accel) {
            m_accelVideo.viewPort = new Rectangle(mx, my, mw, mh);
        } else {
            m_plainVideo.width = mw;
            m_plainVideo.height = mh;
            m_plainVideo.x = mx;
            m_plainVideo.y = my;
        }
    }

    private function onNetStatus(event : Dynamic) {
        switch (event.info.code) {
            case "NetConnection.Connect.Failed":
                initNet();
            case "NetConnection.Connect.Success":
                initStream();
                playVideo();
            case "NetStream.Play.Start":
                //m_idleOverlay.visible = false;
                if (!m_paused) {
                }
            case "NetStream.Play.Stop":
                //m_idleOverlay.visible = true;
                if (!m_paused) {
                    //displayOffline();
                }
            case "NetConnection.Connect.Closed":
                initNet();
            case "NetStream.Buffer.Full":
                //m_stream.bufferTime += 0.001;
            case "NetStream.Buffer.Empty":
                /*
                if (m_stream.bufferTime < 0.001) {
                    m_stream.bufferTime = 0;
                } else {
                    m_stream.bufferTime -= 0.001;
                }
                */
        }
    }

    private function onPlayStatus(item : Dynamic) {
    }

    private function onSeekPoint(item : Dynamic) {
    }

    private function onMetaData(data : Dynamic) {
        if (m_stub) {
            displayOnline();
            m_stream.pause();
            return;
        }
        m_connOk = true;
        //displayOnline();
        m_width = data.width;
        m_height = data.height;
        resizeAndCenter();
    }

    private function onAsyncError(event : AsyncErrorEvent) {
    }

    private function onStageVideoState(event : StageVideoAvailabilityEvent) {
        if (m_iconBottom == null) {
            m_accel = event.availability == StageVideoAvailability.AVAILABLE && false;
            if (m_accel) {
                m_accelVideo = m_stage.stageVideos[0];
            } else {
                m_plainVideo = new Video(m_stage.stageWidth, m_stage.stageHeight);
                m_plainVideo.smoothing = true;
                m_plainVideo.deblocking = 5;
                m_movieClip.addChild(m_plainVideo);
            }
            initGUI();
        }
    }

    private function onResize(event : Event) {
        positionGui();
        resizeAndCenter();
        positionIdle();
    }

    private function onMouseMove(event : MouseEvent) {
        if (m_stage.mouseY < 32) {
            m_iconTop.visible = true;
        } else {
            m_iconTop.visible = false;
        }

        if (m_stage.mouseY > m_stage.stageHeight - 128) {
            m_iconBottom.visible = true;
        } else {
            m_iconBottom.visible = false;
        }
    }

    private function onPauseClick(event : MouseEvent) {
        if (m_paused) {
            m_pauseIcon.setNormalColor(0xffffff);
            m_pauseIcon.setHoverColor(0x4c4c4c);
            m_paused = false;
            m_stream.resume();
        } else {
            m_pauseIcon.setHoverColor(0xffaaaa);
            m_pauseIcon.setNormalColor(0xff4c4c);
            m_paused = true;
            m_stream.pause();
        }
    }
    private function onFullscreenIcon(event : MouseEvent) {
        if (m_stage.displayState == StageDisplayState.FULL_SCREEN) {
            m_stage.displayState = StageDisplayState.NORMAL;
        } else {
            m_stage.fullScreenSourceRect = new Rectangle(0, 0, Capabilities.screenResolutionX ,Capabilities.screenResolutionY);
            m_stage.displayState = StageDisplayState.FULL_SCREEN;
        }
        m_stage.focus = m_stage;
        resizeAndCenter();
        positionGui();
    }
    private function onVolumeClick(event : MouseEvent) {
        if (m_muted) {
            setVolume(1.0);
        } else {
            setVolume(0.0);
        }
    }
    private function onVolumeSliderClick(event : MouseEvent) {
        var pos = event.localX;
        if (pos < 4) {
            pos = 0;
        } else if (pos > 60) {
            pos = 64;
        }
        var vol = pos / 64;

        setVolume(vol);
    }

    private function setVolume(vol : Float) {
        if (vol == 0.0) {
            m_volumeIcon.setHoverColor(0xffaaaa);
            m_volumeIcon.setNormalColor(0xff4c4c);
            m_muted = true;
        } else {
            m_volumeIcon.setNormalColor(0xffffff);
            m_volumeIcon.setHoverColor(0x4c4c4c);
            m_muted = false;
        }

        m_persist.data.volume = vol;
        m_volumeSlider.setFilled(vol);

        if (vol > 0.0) {
          if (vol < 0.3) {
            vol /= 4.0;
          } else if (vol < 0.5) {
            vol /= 3.0;
          } else if (vol < 0.7) {
            vol /= 2.0;
          }
        }
        m_stream.soundTransform = new SoundTransform(vol);
    }
}
