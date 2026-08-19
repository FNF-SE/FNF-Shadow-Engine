package backend;

import flixel.util.FlxSave;
import flixel.input.keyboard.FlxKey;
import flixel.input.gamepad.FlxGamepadInputID;
import states.TitleState;

// Add a variable here and it will get automatically saved
@:structInit class SaveVariables
{
	// Mobile and Mobile Controls Releated
	public var extraButtons:String = "NONE"; // mobile extra button option
	public var hitboxPos:Bool = true; // hitbox extra button position option
	public var dynamicColors:Bool = true; // yes cause its cool -Karim
	public var controlsAlpha:Float = #if web 0.6 #else FlxG.onMobile ? 0.6 : 0 #end;
	#if mobile
	public var screensaver:Bool = false;
	#end
	#if android
	public var useExternalStorage:Bool = false;
	#end
	public var hitboxType:String = "Gradient";
	// public var gameOverVibration:Bool = false;
	// end of Mobile and Mobile Controls Releated

	public var downScroll:Bool = false;
	public var middleScroll:Bool = false;
	public var opponentStrums:Bool = true;
	public var flashing:Bool = true;
	public var autoPause:Bool = true;
	public var antialiasing:Bool = true;
	public var noteSkin:String = 'Default';
	public var splashSkin:String = 'Psych';
	public var splashAlpha:Float = 0.6;
	public var lowQuality:Bool = false;
	public var shaders:Bool = true;
	public var framerate:Int = 60;
	public var camZooms:Bool = true;
	public var hideHud:Bool = false;
	public var uiTheme:String = 'dark';
	public var noteOffset:Int = 0;
	public var disableRGBNotes:Bool = false;
	public var arrowHSV:Array<Array<Int>> = [[0, 0, 0], [0, 0, 0], [0, 0, 0], [0, 0, 0]];
	public var arrowRGB:Array<Array<FlxColor>> = [
		[0xFFC24B99, 0xFFFFFFFF, 0xFF3C1F56],
		[0xFF00FFFF, 0xFFFFFFFF, 0xFF1542B7],
		[0xFF12FA05, 0xFFFFFFFF, 0xFF0A4447],
		[0xFFF9393F, 0xFFFFFFFF, 0xFF651038]
	];
	public var arrowRGBPixel:Array<Array<FlxColor>> = [
		[0xFFE276FF, 0xFFFFF9FF, 0xFF60008D],
		[0xFF3DCAFF, 0xFFF4FFFF, 0xFF003060],
		[0xFF71E300, 0xFFF6FFE6, 0xFF003100],
		[0xFFFF884E, 0xFFFFFAF5, 0xFF6C0000]
	];

	public var ghostTapping:Bool = true;
	public var timeBarType:String = 'Time Left';
	public var scoreZoom:Bool = true;
	public var noReset:Bool = false;
	public var healthBarAlpha:Float = 1;
	public var hitsoundVolume:Float = 0;
	public var pauseMusic:String = 'Tea Time';
	public var comboStacking:Bool = true;
	public var gameplaySettings:Map<String, Dynamic> = [
		'scrollspeed' => 1.0,
		'scrolltype' => 'multiplicative',
		// anyone reading this, amod is multiplicative speed mod, cmod is constant speed mod, and xmod is bpm based speed mod.
		// an amod example would be chartSpeed * multiplier
		// cmod would just be constantSpeed = chartSpeed
		// and xmod basically works by basing the speed on the bpm.
		// iirc (beatsPerSecond * (conductorToNoteDifference / 1000)) * noteSize (110 or something like that depending on it, prolly just use note.height)
		// bps is calculated by bpm / 60
		// oh yeah and you'd have to actually convert the difference to seconds which I already do, because this is based on beats and stuff. but it should work
		// just fine. but I wont implement it because I don't know how you handle sustains and other stuff like that.
		// oh yeah when you calculate the bps divide it by the songSpeed or rate because it wont scroll correctly when speeds exist.
		// -kade
		'songspeed' => 1.0,
		'healthgain' => 1.0,
		'healthloss' => 1.0,
		'instakill' => false,
		'practice' => false,
		'botplay' => false,
		'opponentplay' => false
	];

	public var comboOffset:Array<Int> = [0, 0, 0, 0];
	public var ratingOffset:Int = 0;
	public var sickWindow:Int = 45;
	public var goodWindow:Int = 90;
	public var badWindow:Int = 135;
	public var safeFrames:Float = 10;
	public var guitarHeroSustains:Bool = false;
	public var discordRPC:Bool = true;
	public var loadingScreen:Bool = true;

	public var popUpRating:Bool = true;
	#if native
	public var vsync:Bool = false;
	#if android
	public var downscaleGame:Bool = false;
	#end
	#end
	public var showNoteTiming:Bool = false;
}

class ClientPrefs
{
	public static var data:SaveVariables = {};
	public static var defaultData:SaveVariables = {};

	// Every key has two binds, add your key bind down here and then add your control on options/ControlsSubState.hx and Controls.hx
	public static var keyBinds:Map<String, Array<FlxKey>> = [
		// Key Bind, Name for ControlsSubState
		'note_up' => [J, UP],
		'note_left' => [D, LEFT],
		'note_down' => [F, DOWN],
		'note_right' => [K, RIGHT],
		'ui_up' => [W, UP],
		'ui_left' => [A, LEFT],
		'ui_down' => [S, DOWN],
		'ui_right' => [D, RIGHT],
		'accept' => [SPACE, ENTER],
		'back' => [BACKSPACE, ESCAPE],
		'pause' => [ENTER, ESCAPE],
		'reset' => [R],
		'volume_mute' => [ZERO],
		'volume_up' => [NUMPADPLUS, PLUS],
		'volume_down' => [NUMPADMINUS, MINUS],
		'debug_1' => [SEVEN],
		'debug_2' => [EIGHT],
		'fullscreen' => [F11],
		'fpsCounter' => #if web [THREE] #else [F3] #end
	];
	public static var gamepadBinds:Map<String, Array<FlxGamepadInputID>> = [
		'note_up' => [DPAD_UP, Y],
		'note_left' => [DPAD_LEFT, X],
		'note_down' => [DPAD_DOWN, A],
		'note_right' => [DPAD_RIGHT, B],
		'ui_up' => [DPAD_UP, LEFT_STICK_DIGITAL_UP],
		'ui_left' => [DPAD_LEFT, LEFT_STICK_DIGITAL_LEFT],
		'ui_down' => [DPAD_DOWN, LEFT_STICK_DIGITAL_DOWN],
		'ui_right' => [DPAD_RIGHT, LEFT_STICK_DIGITAL_RIGHT],
		'accept' => [A],
		'back' => [B],
		'pause' => [START],
		'reset' => [BACK],
		'fullscreen' => [LEFT_STICK_CLICK],
		'fpsCounter' => [RIGHT_STICK_CLICK]
	];
	#if FEATURE_MOBILE_CONTROLS
	public static var mobileBinds:Map<String, Array<MobileInputID>> = [
		'note_up' => [MobileInputID.NOTE_UP, MobileInputID.UP2],
		'note_left' => [MobileInputID.NOTE_LEFT, MobileInputID.LEFT2],
		'note_down' => [MobileInputID.NOTE_DOWN, MobileInputID.DOWN2],
		'note_right' => [MobileInputID.NOTE_RIGHT, MobileInputID.RIGHT2],
		'ui_up' => [MobileInputID.UP, MobileInputID.NOTE_UP],
		'ui_left' => [MobileInputID.LEFT, MobileInputID.NOTE_LEFT],
		'ui_down' => [MobileInputID.DOWN, MobileInputID.NOTE_DOWN],
		'ui_right' => [MobileInputID.RIGHT, MobileInputID.NOTE_RIGHT],
		'accept' => [MobileInputID.A],
		'back' => [MobileInputID.B],
		'pause' => [#if android MobileInputID.NONE #else MobileInputID.P #end],
		'reset' => [MobileInputID.NONE],
		'fullscreen' => [MobileInputID.NONE],
		'fpsCounter' => [MobileInputID.NONE]
	];
	public static var defaultMobileBinds:Map<String, Array<MobileInputID>> = null;
	#end
	public static var defaultKeys:Map<String, Array<FlxKey>> = null;
	public static var defaultButtons:Map<String, Array<FlxGamepadInputID>> = null;

	public static function resetKeys(controller:Null<Bool> = null) // Null = both, False = Keyboard, True = Controller
	{
		if (controller != true)
			for (key in keyBinds.keys())
				if (defaultKeys.exists(key))
					keyBinds.set(key, defaultKeys.get(key).copy());

		if (controller != false)
			for (button in gamepadBinds.keys())
				if (defaultButtons.exists(button))
					gamepadBinds.set(button, defaultButtons.get(button).copy());
	}

	public static function clearInvalidKeys(key:String)
	{
		var keyBind:Array<FlxKey> = keyBinds.get(key);
		var gamepadBind:Array<FlxGamepadInputID> = gamepadBinds.get(key);
		#if FEATURE_MOBILE_CONTROLS
		var mobileBind:Array<MobileInputID> = mobileBinds.get(key);
		while (mobileBind != null && mobileBind.contains(NONE))
			mobileBind.remove(NONE);
		#end
		while (keyBind != null && keyBind.contains(NONE))
			keyBind.remove(NONE);
		while (gamepadBind != null && gamepadBind.contains(NONE))
			gamepadBind.remove(NONE);
	}

	public static function loadDefaultKeys()
	{
		defaultKeys = keyBinds.copy();
		defaultButtons = gamepadBinds.copy();
		#if FEATURE_MOBILE_CONTROLS
		defaultMobileBinds = mobileBinds.copy();
		#end
	}

	public static function saveSettings()
	{
		for (key in Reflect.fields(data))
			Reflect.setField(FlxG.save.data, key, Reflect.field(data, key));

		FlxG.save.flush();

		// Placing this in a separate save so that it can be manually deleted without removing your Score and stuff
		var save:FlxSave = new FlxSave();
		save.bind('controls_v3', CoolUtil.getSavePath());
		save.data.keyboard = keyBinds;
		save.data.gamepad = gamepadBinds;
		#if FEATURE_MOBILE_CONTROLS
		save.data.mobile = mobileBinds;
		#end
		save.flush();
		FlxG.log.add("Settings saved!");
	}

	public static function loadPrefs()
	{
		for (key in Reflect.fields(data))
			if (key != 'gameplaySettings' && Reflect.hasField(FlxG.save.data, key))
				Reflect.setField(data, key, Reflect.field(FlxG.save.data, key));

		FlxG.autoPause = ClientPrefs.data.autoPause;

		if (FlxG.save.data.framerate == null)
		{
			final refreshRate:Int = FlxG.stage.application.window.displayMode.refreshRate;
			data.framerate = Std.int(FlxMath.bound(refreshRate, 60, 240));
		}

		if (data.framerate > FlxG.drawFramerate)
		{
			FlxG.updateFramerate = data.framerate;
			FlxG.drawFramerate = data.framerate;
		}
		else
		{
			FlxG.drawFramerate = data.framerate;
			FlxG.updateFramerate = data.framerate;
		}

		if (FlxG.save.data.gameplaySettings != null)
		{
			var savedMap:Map<String, Dynamic> = FlxG.save.data.gameplaySettings;
			for (name => value in savedMap)
				data.gameplaySettings.set(name, value);
		}

		// flixel automatically saves your volume!
		if (FlxG.save.data.volume != null)
			FlxG.sound.volume = FlxG.save.data.volume;
		if (FlxG.save.data.mute != null)
			FlxG.sound.muted = FlxG.save.data.mute;

		#if FEATURE_DISCORD_RPC
		DiscordClient.check();
		#end

		// controls on a separate save file
		var save:FlxSave = new FlxSave();
		save.bind('controls_v3', CoolUtil.getSavePath());
		if (save != null)
		{
			if (save.data.keyboard != null)
			{
				var loadedControls:Map<String, Array<FlxKey>> = save.data.keyboard;
				for (control => keys in loadedControls)
					if (keyBinds.exists(control))
						keyBinds.set(control, keys);
			}
			if (save.data.gamepad != null)
			{
				var loadedControls:Map<String, Array<FlxGamepadInputID>> = save.data.gamepad;
				for (control => keys in loadedControls)
					if (gamepadBinds.exists(control))
						gamepadBinds.set(control, keys);
			}
			#if FEATURE_MOBILE_CONTROLS
			if (save.data.mobile != null)
			{
				var loadedControls:Map<String, Array<MobileInputID>> = save.data.mobile;
				for (control => keys in loadedControls)
					if (mobileBinds.exists(control))
						mobileBinds.set(control, keys);
			}
			#end
			reloadVolumeKeys();
		}
	}

	inline public static function getGameplaySetting(name:String, defaultValue:Dynamic = null, ?customDefaultValue:Bool = false):Dynamic
	{
		if (!customDefaultValue)
			defaultValue = defaultData.gameplaySettings.get(name);
		return /*PlayState.isStoryMode ? defaultValue : */ (data.gameplaySettings.exists(name) ? data.gameplaySettings.get(name) : defaultValue);
	}

	public static function reloadVolumeKeys()
	{
		TitleState.muteKeys = keyBinds.get('volume_mute').copy();
		TitleState.volumeDownKeys = keyBinds.get('volume_down').copy();
		TitleState.volumeUpKeys = keyBinds.get('volume_up').copy();
		toggleVolumeKeys(true);
	}

	public static function toggleVolumeKeys(?turnOn:Bool = true)
	{
		FlxG.sound.muteKeys = (turnOn && !Controls.instance.mobileC) ? TitleState.muteKeys : [];
		FlxG.sound.volumeDownKeys = (turnOn && !Controls.instance.mobileC) ? TitleState.volumeDownKeys : [];
		FlxG.sound.volumeUpKeys = (turnOn && !Controls.instance.mobileC) ? TitleState.volumeUpKeys : [];
	}
}
