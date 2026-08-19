package substates;

import objects.Character;
import flixel.FlxObject;
import states.StoryMenuState;
import states.FreeplayState;
//import lime.ui.Haptic;
import effects.RetroCameraFade;
import backend.StageData;
import haxe.Json;

class GameOverSubstate extends MusicBeatSubstate
{
	public var boyfriend:Character;

	var camFollow:FlxObject;
	var targetZoom:Float = 1;
	var suffix:String = '';

	var camOffsetX:Float = 0;
	var camOffsetY:Float = 0;

	var usingLiveBoyfriend:Bool = false;

	public static var characterName:String = 'bf';
	public static var deathSoundName:String = 'fnf_loss_sfx';
	public static var loopSoundName:String = 'gameOver';
	public static var endSoundName:String = 'gameOverEnd';

	public static var instance:GameOverSubstate;

	public static function resetVariables()
	{
		//characterName = PlayState.SONG.player1.startsWith("pico") ? 'pico-dead' : 'bf-dead';
		deathSoundName = 'fnf_loss_sfx';
		loopSoundName = 'gameOver';
		endSoundName = 'gameOverEnd';

		var _song = PlayState.SONG;
		if (_song != null)
		{
			if (_song.gameOverChar != null && _song.gameOverChar.trim().length > 0)
				characterName = _song.gameOverChar;
			if (_song.gameOverSound != null && _song.gameOverSound.trim().length > 0)
				deathSoundName = _song.gameOverSound;
			if (_song.gameOverLoop != null && _song.gameOverLoop.trim().length > 0)
				loopSoundName = _song.gameOverLoop;
			if (_song.gameOverEnd != null && _song.gameOverEnd.trim().length > 0)
				endSoundName = _song.gameOverEnd;
		}
	}

	override function create()
	{
		instance = this;

		/*if (ClientPrefs.data.gameOverVibration)
			Haptic.vibrate(0, 500);*/

		Conductor.songPosition = 0;

		var game:PlayState = PlayState.instance;
		suffix = game.boyfriend.idleSuffix;

		for (name in game.boyfriend.animOffsets.keys())
		{
			if (name.startsWith('firstDeath'))
			{
				usingLiveBoyfriend = true;
				break;
			}
		}

		if (usingLiveBoyfriend)
		{
			game.remove(game.boyfriendGroup);
			add(game.boyfriendGroup);
			boyfriend = game.boyfriend;
		}
		else
		{
			boyfriend = new Character(game.boyfriend.x, game.boyfriend.y, characterName, true);
			boyfriend.x += boyfriend.positionArray[0] - game.boyfriend.positionArray[0];
			boyfriend.y += boyfriend.positionArray[1] - game.boyfriend.positionArray[1];
			add(boyfriend);
		}

		boyfriend.shader = null;
		boyfriend.color = FlxColor.WHITE;
		boyfriend.skipDance = true;
		for (cam in FlxG.cameras.list)
			cam.filters = [];

		playDeathAnim('firstDeath');
		FlxG.sound.play(Paths.sound(checkFile(deathSoundName, 'sounds')));

		targetZoom = StageData.getStageFile(PlayState.curStage)?.defaultZoom ?? 1;

		var json:Dynamic = Json.parse(Paths.getTextFromFile('characters/' + boyfriend.curCharacter + '.json'));
		if (json != null && json.gameover != null)
		{
			if (json.gameover.offsets != null)
			{
				camOffsetX = json.gameover.offsets[0];
				camOffsetY = json.gameover.offsets[1];
			}
			if (json.gameover.zoom != null)
				targetZoom *= json.gameover.zoom;
		}

		camFollow = new FlxObject(0, 0, 1, 1);
		updateCamFollow();
		add(camFollow);

		FlxG.camera.follow(camFollow, LOCKON, 0.6);

		setOnScripts('inGameOver', true);
		setOnScripts('boyfriend', boyfriend);
		callOnScripts('onGameOverStart', []);

		#if FEATURE_MOBILE_CONTROLS
		addTouchPad("NONE", "A_B");
		addTouchPadCamera(false);
		#end

		super.create();
	}

	var startedDeath:Bool = false;

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		callOnScripts('onUpdate', [elapsed]);

		if (Funkin.controls.ACCEPT)
			endBullshit();

		if (Funkin.controls.BACK)
		{
			#if FEATURE_DISCORD_RPC DiscordClient.resetClientID(); #end
			FlxG.sound.music.stop();
			PlayState.deathCounter = 0;
			PlayState.seenCutscene = false;
			PlayState.chartingMode = false;

			Mods.loadTopMod();
			if (PlayState.isStoryMode)
				Funkin.switchState(StoryMenuState);
			else
				Funkin.switchState(FreeplayState);

			FlxG.sound.playMusic(Paths.music('freakyMenu'));
			callOnScripts('onGameOverConfirm', [false]);
		}

		updateCamFollow();
		FlxG.camera.zoom = smoothLerpPrecision(FlxG.camera.zoom, targetZoom, elapsed, 0.5);

		if (!startedDeath && boyfriend.getAnimationName().startsWith('firstDeath') && boyfriend.isAnimationFinished())
		{
			startedDeath = true;
			playDeathAnim('deathLoop');
			FlxG.sound.playMusic(Paths.music(checkFile(loopSoundName, 'music')), 0.2);

			var quote:String = deathQuote();
			if (quote != '')
				FlxG.sound.play(Paths.sound(quote), 1, false, null, true, () -> FlxG.sound.music.fadeIn(4, 0.2, 1));
			else
				FlxG.sound.music.fadeIn(4, 0.2, 1);

			callOnScripts('onGameOverMusicStart');
		}

		if (FlxG.sound.music.playing)
			Conductor.songPosition = FlxG.sound.music.time;

		callOnScripts('onUpdatePost', [elapsed]);
	}

	var isEnding:Bool = false;

	function endBullshit():Void
	{
		if (isEnding)
			return;

		isEnding = true;
		playDeathAnim('deathConfirm');
		FlxG.sound.music.stop();
		FlxG.sound.playMusic(Paths.music(checkFile(endSoundName, 'music')), 1, false);

		final fade:Float = FlxG.sound.music.length / 7000;
		new FlxTimer().start(fade, function(tmr:FlxTimer)
		{
			if (PlayState.isPixelStage)
			{
				RetroCameraFade.fadeToBlack(FlxG.camera, 10, 2);
				new FlxTimer().start(2.05, function(_)
				{
					releaseBoyfriend();
					Funkin.resetState();
				});
			}
			else
			{
				FlxG.camera.fade(FlxColor.BLACK, 2, false, function()
				{
					releaseBoyfriend();
					Funkin.resetState();
				});
			}
		});
		callOnScripts('onGameOverConfirm', [true]);
	}

	function updateCamFollow():Void
	{
		var midpoint:FlxPoint = boyfriend.getMidpoint();
		var stageOffset:Array<Float> = PlayState.instance != null ? PlayState.instance.boyfriendCameraOffset : [0, 0];
		camFollow.setPosition(midpoint.x - 100, midpoint.y - 100);
		camFollow.x -= boyfriend.cameraPosition[0] - stageOffset[0] - camOffsetX;
		camFollow.y += boyfriend.cameraPosition[1] + stageOffset[1] + camOffsetY;
		midpoint.put();
	}

	function playDeathAnim(anim:String):Void
	{
		if (boyfriend.animOffsets.exists(anim + suffix))
			boyfriend.playAnim(anim + suffix, true);
		else
			boyfriend.playAnim(anim, true);
	}

	function smoothLerpPrecision(base:Float, target:Float, deltaTime:Float, duration:Float, precision:Float = 1 / 100):Float
	{
		if (deltaTime == 0 || base == target)
			return target;
		return FlxMath.lerp(target, base, Math.pow(precision, deltaTime / duration));
	}

	var released:Bool = false;

	function releaseBoyfriend():Void
	{
		if (released)
			return;
		released = true;

		if (usingLiveBoyfriend)
		{
			var group:FlxSpriteGroup = PlayState.instance.boyfriendGroup;
			remove(group);
			PlayState.instance.add(group);
		}
		else
		{
			remove(boyfriend);
			boyfriend.destroy();
		}
	}

	function deathQuote():String
	{
		var path:String = 'data/' + Paths.formatToSongPath(PlayState.SONG.song);
		var variant:String = PlayState.SONG.variant;
		if (variant != null && variant != '')
			path += '/' + variant;
		path += '/deathQuote.txt';

		var contents:String = Paths.getTextFromFile(path);
		if (contents == null)
			return '';

		var quotes:Array<String> = contents.split('\n');
		return quotes[FlxG.random.int(0, quotes.length - 1)];
	}

	function checkFile(file:String, folder:String):String
	{
		if (!PlayState.isPixelStage)
			return file;

		var pixelName:String = file + '-pixel';
		for (ext in Paths.SOUND_EXTS)
			if (Paths.fileExists('$folder/$pixelName.$ext', SOUND))
				return pixelName;
		return file;
	}

	override function destroy()
	{
		instance = null;
		releaseBoyfriend();
		super.destroy();
	}
}
