package backend;

import flixel.addons.transition.FlxTransitionableState;
import flixel.input.keyboard.FlxKey;
import debug.codename.Framerate;
import flixel.FlxGame;
import haxe.io.Path;
import openfl.Lib;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.display.StageScaleMode;
import lime.system.System as LimeSystem;
import states.InitState;
import openfl.events.KeyboardEvent;

class Main extends Sprite
{
	public static final game = {
		width: 1280, // game width
		height: 720, // game height
		initialState: InitState, // initial game state
		zoom: -1.0, // game state bounds
		framerate: 60, // default framerate
		skipSplash: true, // if the flixel splash screen should be skipped
		startFullscreen: false // if the game should start at fullscreen mode
	};

	public static var fpsVar:Framerate;

	public static function main():Void
	{
		Lib.current.addChild(new Main());
		#if cpp
		cpp.NativeGc.enable(true);
		#end
	}

	public function new()
	{
		backend.CrashHandler.init();
		#if mobile
		Sys.setCwd(StorageUtil.getStorageDirectory());
		#if android
		StorageUtil.requestPermissions();
		#end
		mobile.backend.io.Assets.init();
		#end
		super();

		if (stage != null)
		{
			init();
		}
		else
		{
			addEventListener(Event.ADDED_TO_STAGE, init);
		}
	}

	private function init(?E:Event):Void
	{
		if (hasEventListener(Event.ADDED_TO_STAGE))
		{
			removeEventListener(Event.ADDED_TO_STAGE, init);
		}

		#if android
		if (!FileSystem.exists(haxe.io.Path.addTrailingSlash(LimeSystem.applicationStorageDirectory) + "useExternal.txt"))
		{
			File.saveContent(haxe.io.Path.addTrailingSlash(LimeSystem.applicationStorageDirectory) + "useExternal.txt", 'false');
			Sys.setCwd(StorageUtil.getStorageDirectory());
		}
		#end

		setupGame();
	}

	private function setupGame():Void
	{
		if (game.zoom == -1.0)
			game.zoom = 1.0;

		untyped FlxG.cameras = new backend.rendering.ShadowCameraFrontEnd();

		final funkinGame:FlxGame = new FlxGame(game.width, game.height, game.initialState, game.framerate, game.framerate, game.skipSplash,
			game.startFullscreen);

		#if !html5
		@:privateAccess
		funkinGame._customSoundTray = objects.CustomSoundTray;
		#end

		addChild(funkinGame);

		@:privateAccess
		FlxG.game.addChildAt(fpsVar = new Framerate(), FlxG.game.getChildIndex(FlxG.game._inputContainer) + 1);
		debug.codename.SystemInfo.init();

		final mouseSprite:Sprite = new Sprite();
        FlxG.game.addChildAt(mouseSprite, FlxG.game.getChildIndex(fpsVar) + 1);
        untyped FlxG.mouse.cursorContainer = mouseSprite;

		Lib.current.stage.align = "tl";
		Lib.current.stage.scaleMode = StageScaleMode.NO_SCALE;
		#if mobile
		//FlxG.game.stage.quality = openfl.display.StageQuality.LOW;
		#end
		if (fpsVar != null)
			fpsVar.visible = true;

		#if desktop
		FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, toggleFullScreen);
		FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, emergencyEject);
		FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, hotReload);
		#end

		// shader coords fix
		FlxG.signals.gameResized.add(function(w, h)
		{
			if (FlxG.cameras != null)
			{
				for (cam in FlxG.cameras.list)
				{
					if (cam != null && cam.filters != null)
						resetSpriteCache(cam.flashSprite);
				}
			}

			if (FlxG.game != null)
				resetSpriteCache(FlxG.game);
		});
	}

	static function resetSpriteCache(sprite:Sprite):Void
	{
		@:privateAccess
		{
			sprite.__cacheBitmap = null;
			sprite.__cacheBitmapData = null;
		}
	}

	function toggleFullScreen(event:KeyboardEvent):Void
	{
		if (Controls.instance?.justReleased('fullscreen'))
			FlxG.fullscreen = !FlxG.fullscreen;
	}

	function emergencyEject(event:KeyboardEvent):Void
	{
		if (event.shiftKey && event.keyCode == FlxKey.F4)
		{
			FlxTransitionableState.skipNextTransIn = FlxTransitionableState.skipNextTransOut = true;
			Paths.clearStoredMemory();
			Funkin.switchState(states.MainMenuState);
		}
	}

	function hotReload(event:KeyboardEvent):Void
	{
		if (event.shiftKey && event.keyCode == FlxKey.F5)
		{
			// SHADOW TODO: maybe do some real hot reloading in the future...
			FlxG.resetState();
		}
	}
}
