package states;

import backend.EaseUtil;
import backend.Highscore;
import backend.StageData;
import backend.WeekData;
import backend.Song;
import backend.Section;
import backend.Rating;
import backend.scripting.ScriptResult;
import flixel.FlxBasic;
import flixel.FlxObject;
import flixel.addons.transition.FlxTransitionableState;
import flixel.util.FlxSort;
import flixel.input.keyboard.FlxKey;
import flixel.animation.FlxAnimationController;
import openfl.utils.Assets;
import openfl.events.KeyboardEvent;
import cutscenes.CutsceneHandler;
import cutscenes.DialogueBoxPsych;
import states.editors.CharacterEditorState;
import states.editors.ChartingState;
import substates.PauseSubState;
import substates.GameOverSubstate;
import flixel.addons.display.FlxRuntimeShader;
import objects.Note.EventNote;
import objects.*;
import states.stages.objects.*;
import substates.ResultsScreen;
import effects.RetroCameraFade;
#if (target.threaded)
import sys.thread.Thread;
import sys.thread.Mutex;
#end

/**
 * This is where all the Gameplay stuff happens and is managed
 *
 * here's some useful tips if you are making a mod in source:
 *
 * If you want to add your stage to the game, copy states/stages/Template.hx,
 * and put your stage code there, then, on PlayState, search for
 * "switch (curStage)", and add your stage to that list.
 *
 * If you want to code Events, you can either code it on a Stage file or on PlayState, if you're doing the latter, search for:
 *
 * "function eventPushed" - Only called *one time* when the game loads, use it for precaching events that use the same assets, no matter the values
 * "function eventPushedUnique" - Called one time per event, use it for precaching events that uses different assets based on its values
 * "function eventEarlyTrigger" - Used for making your event start a few MILLISECONDS earlier
 * "function triggerEvent" - Called when the song hits your event's timestamp, this is probably what you were looking for
**/
class PlayState extends MusicBeatState
{
	public static var STRUM_X = 48;
	public static var STRUM_X_MIDDLESCROLL = -278;

	public static var ratingStuff:Array<Dynamic> = [
		['You Suck!', 0.2], // From 0% to 19%
		['Shit', 0.4], // From 20% to 39%
		['Bad', 0.5], // From 40% to 49%
		['Bruh', 0.6], // From 50% to 59%
		['Meh', 0.69], // From 60% to 68%
		['Nice', 0.7], // 69%
		['Good', 0.8], // From 70% to 79%
		['Great', 0.9], // From 80% to 89%
		['Sick!', 1], // From 90% to 99%
		['Perfect!!', 1] // The value on this one isn't used actually, since Perfect is always "1"
	];

	// event variables
	private var isCameraOnForcedPos:Bool = false;

	public var boyfriendMap:Map<String, Character> = new Map<String, Character>();
	public var dadMap:Map<String, Character> = new Map<String, Character>();
	public var gfMap:Map<String, Character> = new Map<String, Character>();

	public var BF_X:Float = 770;
	public var BF_Y:Float = 100;
	public var DAD_X:Float = 100;
	public var DAD_Y:Float = 100;
	public var GF_X:Float = 400;
	public var GF_Y:Float = 130;

	public var songSpeedTween:FlxTween;
	public var songSpeed(default, set):Float = 1;
	public var songSpeedType:String = "multiplicative";
	public var noteKillOffset:Float = 350;

	public var playbackRate(default, set):Float = 1;

	public var boyfriendGroup:FlxSpriteGroup;
	public var dadGroup:FlxSpriteGroup;
	public var gfGroup:FlxSpriteGroup;

	public static var curStage:String = '';
	public static var stageUI:String = "normal";
	public static var isPixelStage(get, never):Bool;

	@:noCompletion
	static function get_isPixelStage():Bool
		return stageUI == "pixel" || stageUI.endsWith("-pixel");

	public static var SONG:SwagSong = null;
	public static var isStoryMode:Bool = false;
	public static var storyWeek:Int = 0;
	public static var storyPlaylist:Array<String> = [];
	public static var storyDifficulty:Int = 1;

	public var spawnTime:Float = 2000;

	public var inst:FlxSound;
	public var vocals:FlxSound;
	public var opponentVocals:FlxSound;

	public var intro3Sound:FlxSound;
	public var intro2Sound:FlxSound;
	public var intro1Sound:FlxSound;
	public var introGoSound:FlxSound;
	public var missnoteSound:FlxSound;
	public var hitsoundSound:FlxSound;

	public var dad:Character = null;
	public var gf:Character = null;
	public var boyfriend:Character = null;

	public var notes:FlxTypedGroup<Note>;
	public var unspawnNotes:Array<Note> = [];
	public var eventNotes:Array<EventNote> = [];

	public var camFollow:FlxObject;

	private static var prevCamFollow:FlxObject;

	public var strumLineNotes:FlxTypedGroup<StrumNote>;
	public var opponentStrums:FlxTypedGroup<StrumNote>;
	public var playerStrums:FlxTypedGroup<StrumNote>;
	public var grpNoteSplashes:FlxTypedGroup<NoteSplash>;
	public var grpHoldSplashes:FlxTypedGroup<SustainSplash>;

	public var camZooming:Bool = false;
	public var camZoomingMult:Float = 1;
	public var camZoomingFrequency:Float = 4;
	public var camZoomingDecay:Float = 1;

	private var curSong:String = "";

	public var gfSpeed:Int = 1;
	public var health(default, set):Float = 1;
	public var combo:Int = 0;
	public var maxCombo:Int = 0;

	public var healthBar:Bar;
	public var timeBar:Bar;

	var songPercent:Float = 0;

	public var ratingsData:Array<Rating> = Rating.loadDefault();
	public var isErect:Bool;

	private var generatedMusic:Bool = false;

	public var endingSong:Bool = false;
	public var startingSong:Bool = false;

	private var updateTime:Bool = true;

	public static var changedDifficulty:Bool = false;
	public static var chartingMode:Bool = false;

	// Gameplay settings
	public var healthGain:Float = 1;
	public var healthLoss:Float = 1;

	public var guitarHeroSustains:Bool = false;
	public var instakillOnMiss:Bool = false;
	public var cpuControlled:Bool = false;
	public var practiceMode:Bool = false;

	public var botplaySine:Float = 0;
	public var botplayTxt:FlxText;

	public var iconP1:HealthIcon;
	public var iconP2:HealthIcon;
	public var camHUD:ShadowCamera;
	public var camGame:ShadowCamera;
	public var camOther:ShadowCamera;
	public var cameraSpeed:Float = 1;

	public var songScore:Int = 0;

	public var songHits:Int = 0;
	public var songMisses:Int = 0;
	public var scoreTxt:FlxText;

	var timeTxt:FlxText;
	var scoreTxtTween:FlxTween;

	var zoomTween:FlxTween;
	var camTween:FlxTween;

	public static var campaignScore:Int = 0;
	public static var campaignMisses:Int = 0;
	public static var seenCutscene:Bool = false;
	public static var deathCounter:Int = 0;

	public var defaultCamZoom:Float = 1.05;

	// how big to stretch the pixel art assets
	public static var daPixelZoom:Float = 6;

	private var singAnimations:Array<String> = ['singLEFT', 'singDOWN', 'singUP', 'singRIGHT'];

	public var inCutscene:Bool = false;
	public var skipCountdown:Bool = false;

	var songLength:Float = 0;

	public var boyfriendCameraOffset:Array<Float> = null;
	public var opponentCameraOffset:Array<Float> = null;
	public var girlfriendCameraOffset:Array<Float> = null;

	#if FEATURE_DISCORD_RPC
	// Discord RPC variables
	var storyDifficultyText:String = "";
	var detailsText:String = "";
	var detailsPausedText:String = "";
	#end

	// Lua shi
	public static var instance:PlayState;

	public var introSoundsSuffix:String = '';

	// Less laggy controls
	private var keysArray:Array<String>;

	public var songName:String;

	// Callbacks for stages
	public var startCallback:Void->Void = null;
	public var endCallback:Void->Void = null;

	#if (target.threaded)
	private var shutdownThread:Bool = false;
	private var gameFroze:Bool = false;
	private var requiresSyncing:Bool = false;
	private var lastCorrectSongPos:Float = -1.0;
	private var syncMutex:Mutex;
	#end

	public var noteSkin:String;
	public var noteSkin1:String; // for opponent bleh
	public var allowedNotes:Array<String> = [null, 'Alt Animation', 'No Animation', 'GF Sing', ''];

	// for results screen
	public var totalSick:Int = 0;
	public var totalGood:Int = 0;
	public var totalBad:Int = 0;
	public var totalShit:Int = 0;
	public var anas:Array<Ana> = [null, null, null, null];
	public var anaArray:Array<Ana> = [];
	public var songSaveNotes:Array<Dynamic> = [];
	public var songJudges:Array<String> = [];

	// from gacha horror recreation
	public var characterPlayingAsDad:Bool = false;

	override public function create()
	{
		// trace('Playback Rate: ' + playbackRate);
		Paths.clearStoredMemory();

		Note.clearPool();

		startCallback = startCountdown;
		endCallback = endSong;

		// for lua
		instance = this;

		PauseSubState.songName = null; // Reset to default
		playbackRate = ClientPrefs.getGameplaySetting('songspeed');
		characterPlayingAsDad = ClientPrefs.getGameplaySetting('playAsOpponent');

		keysArray = ['note_left', 'note_down', 'note_up', 'note_right'];

		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();

		// Gameplay settings
		healthGain = ClientPrefs.getGameplaySetting('healthgain');
		healthLoss = ClientPrefs.getGameplaySetting('healthloss');
		instakillOnMiss = ClientPrefs.getGameplaySetting('instakill');
		practiceMode = ClientPrefs.getGameplaySetting('practice');
		cpuControlled = ClientPrefs.getGameplaySetting('botplay');
		guitarHeroSustains = ClientPrefs.data.guitarHeroSustains;

		// var gameCam:ShadowCamera = FlxG.camera;
		camGame = initPsychCamera();
		camHUD = new ShadowCamera();
		camOther = new ShadowCamera();
		camHUD.bgColor.alpha = 0;
		camOther.bgColor.alpha = 0;
		FlxG.cameras.add(camHUD, false);
		FlxG.cameras.add(camOther, false);
		grpNoteSplashes = new FlxTypedGroup<NoteSplash>();
		NoteSplash.mainGroup = grpNoteSplashes;
		grpHoldSplashes = new FlxTypedGroup<SustainSplash>();

		persistentUpdate = true;
		persistentDraw = true;

		if (SONG == null)
			SONG = Song.loadFromJson('tutorial');

		Conductor.mapBPMChanges(SONG);
		Conductor.bpm = SONG.bpm;
		noteSkin1 = (!characterPlayingAsDad) ? SONG.opponentArrowSkin : SONG.playerArrowSkin;
		if (noteSkin1 == null)
			noteSkin1 = Note.defaultNoteSkin;
		noteSkin = (!characterPlayingAsDad) ? SONG.playerArrowSkin : SONG.opponentArrowSkin;
		if (noteSkin == null)
			noteSkin = Note.defaultNoteSkin;

		#if FEATURE_DISCORD_RPC
		storyDifficultyText = Difficulty.diffToString(Difficulty.getByIndex());

		if (isStoryMode)
			detailsText = "Story Mode: " + WeekData.getCurrentWeek().weekName;
		else
			detailsText = "Freeplay";

		// String for when the game is paused
		detailsPausedText = "Paused - " + detailsText;
		#end

		songName = Paths.formatToSongPath(SONG.song);
		if (SONG.stage == null || SONG.stage.length < 1)
		{
			SONG.stage = StageData.vanillaSongStage(songName);
		}
		curStage = SONG.stage;

		// P-Slice compatibility
		if (curStage == "mainStageErect")
			curStage = "stageErect";

		var stageData:StageFile = StageData.getStageFile(curStage);
		if (stageData == null) // Stage couldn't be found, create a dummy stage for preventing a crash
		{
			stageData = StageData.dummy();
		}

		defaultCamZoom = stageData.defaultZoom;

		stageUI = "normal";
		if (stageData.stageUI != null && stageData.stageUI.trim().length > 0)
			stageUI = stageData.stageUI;
		else
		{
			if (stageData.isPixelStage)
				stageUI = "pixel";
		}

		GameOverSubstate.resetVariables();

		BF_X = stageData.boyfriend[0];
		BF_Y = stageData.boyfriend[1];
		GF_X = stageData.girlfriend[0];
		GF_Y = stageData.girlfriend[1];
		DAD_X = stageData.opponent[0];
		DAD_Y = stageData.opponent[1];

		if (stageData.camera_speed != null)
			cameraSpeed = stageData.camera_speed;

		boyfriendCameraOffset = stageData.camera_boyfriend;
		if (boyfriendCameraOffset == null) // Fucks sake should have done it since the start :rolling_eyes:
			boyfriendCameraOffset = [0, 0];

		opponentCameraOffset = stageData.camera_opponent;
		if (opponentCameraOffset == null)
			opponentCameraOffset = [0, 0];

		girlfriendCameraOffset = stageData.camera_girlfriend;
		if (girlfriendCameraOffset == null)
			girlfriendCameraOffset = [0, 0];

		boyfriendGroup = new FlxSpriteGroup(BF_X, BF_Y);
		dadGroup = new FlxSpriteGroup(DAD_X, DAD_Y);
		gfGroup = new FlxSpriteGroup(GF_X, GF_Y);

		switch (curStage)
		{
			case 'stage':
				new states.stages.Stage();
			case 'stageErect':
				new states.stages.StageErect();
			case 'nothing':
				new states.stages.Nothing();
		}

		if (isPixelStage)
		{
			introSoundsSuffix = '-pixel';
		}

		if (stageData.objects != null && stageData.objects.length > 0)
		{
			var list:Map<String, FlxSprite> = StageData.addObjectsToState(stageData.objects, !stageData.hide_girlfriend ? gfGroup : null, dadGroup,
				boyfriendGroup, this);
			for (key => spr in list)
				if (!StageData.reservedNames.contains(key))
					modchartSprites.set(key, cast spr);
		}
		else
		{
			add(gfGroup);
			add(dadGroup);
			add(boyfriendGroup);
		}

		// "GLOBAL" SCRIPTS
		#if (FEATURE_LUA || FEATURE_HSCRIPT)
		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'scripts/'))
		{
			for (file in FileSystem.readDirectory(folder))
			{
				#if FEATURE_LUA
				startLuasNamed(folder + file);
				#end

				#if FEATURE_HSCRIPT
				startHScriptsNamed(folder + file);
				#end
			}
		}
		#end

		// STAGE SCRIPTS
		#if FEATURE_LUA
		startLuasNamed('stages/' + curStage);
		#end

		#if FEATURE_HSCRIPT
		startHScriptsNamed('stages/' + curStage);
		#end

		if (SONG.gfVersion == null || SONG.gfVersion.length < 1)
			SONG.gfVersion = 'gf'; // Fix for the Chart Editor
		if (!stageData.hide_girlfriend && !ClientPrefs.data.lowQuality)
			gf = new Character(0, 0, SONG.gfVersion);
		else
			gf = new Character(0, 0, 'gf-empty');
		startCharacterPos(gf);
		gf.scrollFactor.set(0.95, 0.95);
		gfGroup.add(gf);
		startCharacterScripts(gf.curCharacter);

		dad = new Character(0, 0, SONG.player2, characterPlayingAsDad);
		if (characterPlayingAsDad)
			dad.flipX = !dad.flipX;
		startCharacterPos(dad, true);
		dadGroup.add(dad);
		startCharacterScripts(dad.curCharacter);

		boyfriend = new Character(0, 0, SONG.player1, !characterPlayingAsDad);
		if (characterPlayingAsDad)
			boyfriend.flipX = !boyfriend.flipX;
		startCharacterPos(boyfriend);
		boyfriendGroup.add(boyfriend);
		startCharacterScripts(boyfriend.curCharacter);

		var camPos:FlxPoint = FlxPoint.get(girlfriendCameraOffset[0], girlfriendCameraOffset[1]);
		if (gf != null)
		{
			camPos.x += gf.getGraphicMidpoint().x + gf.cameraPosition[0];
			camPos.y += gf.getGraphicMidpoint().y + gf.cameraPosition[1];
		}

		if (dad.curCharacter.startsWith('gf'))
		{
			dad.setPosition(GF_X, GF_Y);
			if (gf != null)
				gf.visible = false;
		}
		stagesFunc(function(stage:BaseStage) stage.createPost());

		comboGroup = new FlxSpriteGroup();
		add(comboGroup);
		uiGroup = new FlxSpriteGroup();
		add(uiGroup);
		noteGroup = new FlxTypedGroup<FlxBasic>();
		add(noteGroup);

		Conductor.songPosition = -5000 / Conductor.songPosition;
		var showTime:Bool = (ClientPrefs.data.timeBarType != 'Disabled');
		timeTxt = new FlxText(STRUM_X + (FlxG.width / 2) - 248, 19, 400, "", 32);
		timeTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		timeTxt.scrollFactor.set();
		timeTxt.alpha = 0;
		timeTxt.borderSize = 2;
		timeTxt.visible = updateTime = showTime;
		if (ClientPrefs.data.downScroll)
			timeTxt.y = FlxG.height - 44;
		if (ClientPrefs.data.timeBarType == 'Song Name')
			timeTxt.text = SONG.song;

		timeBar = new Bar(0, timeTxt.y + (timeTxt.height / 4), 'timeBar', function() return songPercent, 0, 1);
		timeBar.scrollFactor.set();
		timeBar.screenCenter(X);
		timeBar.alpha = 0;
		timeBar.visible = showTime;
		uiGroup.add(timeBar);
		uiGroup.add(timeTxt);

		strumLineNotes = new FlxTypedGroup<StrumNote>();
		strumLineNotes.autoRefresh = strumLineNotes.useZIndex = false;
		noteGroup.add(strumLineNotes);

		if (ClientPrefs.data.timeBarType == 'Song Name')
		{
			timeTxt.size = 24;
			timeTxt.y += 3;
		}

		var splash:NoteSplash = new NoteSplash(100, 100);
		grpNoteSplashes.add(splash);
		SustainSplash.init(grpHoldSplashes, Conductor.stepCrochet * 1.25 / 1000 / playbackRate, Math.floor((isPixelStage ? 20 : 24) / 100 * PlayState.SONG.bpm));

		opponentStrums = new FlxTypedGroup<StrumNote>();
		playerStrums = new FlxTypedGroup<StrumNote>();

		generateSong(SONG.song);

		noteGroup.add(grpNoteSplashes);
		noteGroup.add(grpHoldSplashes);

		camFollow = new FlxObject(0, 0, 1, 1);
		camFollow.setPosition(camPos.x, camPos.y);
		camPos.put();

		if (prevCamFollow != null)
		{
			camFollow = prevCamFollow;
			prevCamFollow = null;
		}
		add(camFollow);

		FlxG.camera.follow(camFollow, LOCKON, 0);
		FlxG.camera.zoom = defaultCamZoom;
		FlxG.camera.snapToTarget();

		FlxG.worldBounds.set(0, 0, FlxG.width, FlxG.height);
		moveCameraSection();

		healthBar = new Bar(0, FlxG.height * (!ClientPrefs.data.downScroll ? 0.89 : 0.11), 'healthBar', function() return health, 0, 2);
		healthBar.screenCenter(X);
		healthBar.leftToRight = characterPlayingAsDad;
		healthBar.flipX = false;
		healthBar.scrollFactor.set();
		healthBar.visible = !ClientPrefs.data.hideHud;
		healthBar.alpha = ClientPrefs.data.healthBarAlpha;
		reloadHealthBarColors();
		uiGroup.add(healthBar);

		iconP1 = new HealthIcon(boyfriend.healthIcon, true);
		iconP1.y = healthBar.y - 75;
		iconP1.visible = !ClientPrefs.data.hideHud;
		iconP1.alpha = ClientPrefs.data.healthBarAlpha;
		uiGroup.add(iconP1);

		iconP2 = new HealthIcon(dad.healthIcon, false);
		iconP2.y = healthBar.y - 75;
		iconP2.visible = !ClientPrefs.data.hideHud;
		iconP2.alpha = ClientPrefs.data.healthBarAlpha;
		uiGroup.add(iconP2);

		scoreTxt = new FlxText(0, healthBar.y + 40, FlxG.width, "", 20);
		scoreTxt.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scoreTxt.scrollFactor.set();
		scoreTxt.borderSize = 1.25;
		scoreTxt.visible = (!ClientPrefs.data.hideHud && !cpuControlled);
		updateScore();
		uiGroup.add(scoreTxt);

		botplayTxt = new FlxText(400, healthBar.y - 90, FlxG.width - 800, "BOTPLAY", 32);
		botplayTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		botplayTxt.scrollFactor.set();
		botplayTxt.borderSize = 1.25;
		botplayTxt.visible = cpuControlled;
		uiGroup.add(botplayTxt);
		if (ClientPrefs.data.downScroll)
			botplayTxt.y = healthBar.y + 70;

		noteGroup.cameras = [camHUD];
		uiGroup.cameras = [camHUD];
		comboGroup.cameras = [camHUD];

		startingSong = true;

		#if FEATURE_LUA
		for (notetype in noteTypes)
			startLuasNamed('custom_notetypes/' + notetype);
		for (event in eventsPushed)
			startLuasNamed('custom_events/' + event);
		#end

		#if FEATURE_HSCRIPT
		for (notetype in noteTypes)
			startHScriptsNamed('custom_notetypes/' + notetype);
		for (event in eventsPushed)
			startHScriptsNamed('custom_events/' + event);
		#end
		noteTypes = null;
		eventsPushed = null;

		if (eventNotes.length > 1)
		{
			for (event in eventNotes)
				event.strumTime -= eventEarlyTrigger(event);
			eventNotes.sort(sortByTime);
		}

		// SONG SPECIFIC SCRIPTS
		#if (FEATURE_LUA || FEATURE_HSCRIPT)
		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'data/$songName/'))
		{
			for (file in FileSystem.readDirectory(folder))
			{
				#if FEATURE_LUA
				startLuasNamed(folder + file);
				#end

				#if FEATURE_HSCRIPT
				startHScriptsNamed(folder + file);
				#end
			}
		}
		#end

		if (isPixelStage)
			for (cam in FlxG.cameras.list)
				RetroCameraFade.fadeBlack(cam, 10, 1);

		startCallback();

		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
		FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, onKeyRelease);

		// PRECACHING THINGS THAT GET USED FREQUENTLY TO AVOID LAGSPIKES
		if (ClientPrefs.data.hitsoundVolume > 0)
			Paths.sound('hitsound');
		for (i in 1...4)
			Paths.sound('missnote$i');
		Paths.image('alphabet');

		if (PauseSubState.songName != null)
			Paths.music(PauseSubState.songName);
		else if (Paths.formatToSongPath(ClientPrefs.data.pauseMusic) != 'none')
			Paths.music(Paths.formatToSongPath(ClientPrefs.data.pauseMusic));

		resetRPC();

		cacheCountdown();
		cachePopUpScore();

		#if FEATURE_MOBILE_CONTROLS
		addMobileControls(false);
		mobileControls.instance.visible = true;
		mobileControls.onButtonDown.add(onButtonPress);
		mobileControls.onButtonUp.add(onButtonRelease);
		addTouchPad("NONE", "P");
		addTouchPadCamera(false);
		mobileControls.instance.forEachAlive((button) ->
		{
			if (touchPad.buttonP != null)
				button.deadZones.push(touchPad.buttonP);
		});
		#end

		super.create();
		Paths.clearUnusedMemory();

		if (eventNotes.length < 1)
			checkEventNote();
	}

	function set_songSpeed(value:Float):Float
	{
		if (generatedMusic)
		{
			var ratio:Float = value / songSpeed; // funny word huh
			if (ratio != 1)
			{
				for (note in notes.members)
					note.resizeByRatio(ratio);
				for (note in unspawnNotes)
					note.resizeByRatio(ratio);
			}
		}
		songSpeed = value;
		noteKillOffset = Math.max(Conductor.stepCrochet, 350 / songSpeed * playbackRate);
		return value;
	}

	function set_playbackRate(value:Float):Float
	{
		if (generatedMusic)
		{
			vocals.pitch = value;
			@:privateAccess
			if (opponentVocals._sound != null)
				opponentVocals.pitch = value;
			FlxG.sound.music.pitch = value;
			for (intro in [intro3Sound, intro2Sound, intro1Sound, introGoSound, missnoteSound])
				if (intro != null) intro.pitch = value;

			var ratio:Float = playbackRate / value; // funny word huh
			if (ratio != 1)
			{
				for (note in notes.members)
					note.resizeByRatio(ratio);
				for (note in unspawnNotes)
					note.resizeByRatio(ratio);
			}
		}
		playbackRate = value;
		FlxG.animationTimeScale = value;
		Conductor.safeZoneOffset = (ClientPrefs.data.safeFrames / 60) * 1000 * value;
		#if FEATURE_VIDEOS
		if (videoCutscene?.videoSprite?.bitmap != null)
			videoCutscene.videoSprite.bitmap.rate = value;
		#end
		setOnScripts('playbackRate', playbackRate);
		return playbackRate;
	}

	public function reloadHealthBarColors()
	{
		healthBar.setColors(FlxColor.fromRGB(dad.healthColorArray[0], dad.healthColorArray[1], dad.healthColorArray[2]),
			FlxColor.fromRGB(boyfriend.healthColorArray[0], boyfriend.healthColorArray[1], boyfriend.healthColorArray[2]));
	}

	public function addCharacterToList(newCharacter:String, type:Int)
	{
		switch (type)
		{
			case 0:
				if (!boyfriendMap.exists(newCharacter))
				{
					var newBoyfriend:Character = new Character(0, 0, newCharacter, !characterPlayingAsDad);
					if (characterPlayingAsDad)
						newBoyfriend.flipX = !newBoyfriend.flipX;
					boyfriendMap.set(newCharacter, newBoyfriend);
					boyfriendGroup.add(newBoyfriend);
					startCharacterPos(newBoyfriend);
					newBoyfriend.alpha = 0.00001;
					startCharacterScripts(newBoyfriend.curCharacter);
				}

			case 1:
				if (!dadMap.exists(newCharacter))
				{
					var newDad:Character = new Character(0, 0, newCharacter, characterPlayingAsDad);
					if (characterPlayingAsDad)
						newDad.flipX = !newDad.flipX;
					dadMap.set(newCharacter, newDad);
					dadGroup.add(newDad);
					startCharacterPos(newDad, true);
					newDad.alpha = 0.00001;
					startCharacterScripts(newDad.curCharacter);
				}

			case 2:
				if (gf != null && !gfMap.exists(newCharacter))
				{
					var newGf:Character = new Character(0, 0, newCharacter);
					newGf.scrollFactor.set(0.95, 0.95);
					gfMap.set(newCharacter, newGf);
					gfGroup.add(newGf);
					startCharacterPos(newGf);
					newGf.alpha = 0.00001;
					startCharacterScripts(newGf.curCharacter);
				}
		}
	}

	function startCharacterScripts(name:String)
	{
		#if FEATURE_LUA
		startLuasNamed('characters/$name');
		#end
		#if FEATURE_HSCRIPT
		startHScriptsNamed('characters/$name');
		#end
	}

	function startCharacterPos(char:Character, ?gfCheck:Bool = false)
	{
		if (gfCheck && char.curCharacter.startsWith('gf')) // IF DAD IS GIRLFRIEND, HE GOES TO HER POSITION
		{
			char.setPosition(GF_X, GF_Y);
			char.scrollFactor.set(0.95, 0.95);
			char.danceEveryNumBeats = 2;
		}
		char.x += char.positionArray[0];
		char.y += char.positionArray[1];
	}

	public var videoCutscene:VideoSprite = null;
	public function startVideo(name:String, forMidSong:Bool = false, canSkip:Bool = true, loop:Bool = false, playOnLoad:Bool = true)
	{
		#if FEATURE_VIDEOS
		inCutscene = !forMidSong;
		canPause = forMidSong;

		var foundFile:Bool = false;
		var fileName:String = Paths.video(name);

		if (FileSystem.exists(fileName))
			foundFile = true;

		if (foundFile)
		{
			videoCutscene = new VideoSprite(fileName, forMidSong, canSkip, loop);
			if (forMidSong)
				videoCutscene.videoSprite.bitmap.rate = playbackRate;

			// Finish callback
			if (!forMidSong)
			{
				function onVideoEnd()
				{
					if (!isDead
						&& generatedMusic
						&& PlayState.SONG.notes[Std.int(curStep / 16)] != null
						&& !endingSong
						&& !isCameraOnForcedPos)
					{
						moveCameraSection();
						FlxG.camera.snapToTarget();
					}
					videoCutscene = null;
					canPause = true;
					inCutscene = false;
					startAndEnd();
				}
				videoCutscene.finishCallback = onVideoEnd;
				videoCutscene.onSkip = onVideoEnd;
			}
			if (GameOverSubstate.instance != null && isDead)
				GameOverSubstate.instance.add(videoCutscene);
			else
				add(videoCutscene);

			if (playOnLoad)
				videoCutscene.play();
			return videoCutscene;
		}
		#if (FEATURE_LUA || FEATURE_HSCRIPT)
		else
			addTextToDebug("Video not found: " + fileName, FlxColor.RED);
		#else
		else
			FlxG.log.error("Video not found: " + fileName);
		#end
		#else
		FlxG.log.warn('Platform not supported!');
		startAndEnd();
		#end
		return null;
	}

	function startAndEnd()
	{
		if (endingSong)
		{
			endSong();
		}
		else
			startCountdown();
	}

	var dialogueCount:Int = 0;

	public var psychDialogue:DialogueBoxPsych;

	// You don't have to add a song, just saying. You can just do "startDialogue(DialogueBoxPsych.parseDialogue(Paths.json(songName + '/dialogue')))" and it should load dialogue.json
	public function startDialogue(dialogueFile:DialogueFile, ?song:String = null):Void
	{
		// TO DO: Make this more flexible, maybe?
		if (psychDialogue != null)
			return;

		if (dialogueFile.dialogue.length > 0)
		{
			inCutscene = true;
			psychDialogue = new DialogueBoxPsych(dialogueFile, song);
			psychDialogue.scrollFactor.set();
			if (endingSong)
			{
				psychDialogue.finishThing = function()
				{
					psychDialogue = null;
					endSong();
				}
			}
			else
			{
				psychDialogue.finishThing = function()
				{
					psychDialogue = null;
					startCountdown();
				}
			}
			psychDialogue.nextDialogueThing = startNextDialogue;
			psychDialogue.skipDialogueThing = skipDialogue;
			psychDialogue.cameras = [camHUD];
			add(psychDialogue);
		}
		else
		{
			FlxG.log.warn('Your dialogue file is badly formatted!');
			startAndEnd();
		}
	}

	var startTimer:FlxTimer;
	var finishTimer:FlxTimer = null;

	// For being able to mess with the sprites on Lua
	public var countdownReady:FlxSprite;
	public var countdownSet:FlxSprite;
	public var countdownGo:FlxSprite;

	public static var startOnTime:Float = 0;

	function cacheCountdown()
	{
		var introAssets:Map<String, Array<String>> = new Map<String, Array<String>>();
		var introImagesArray:Array<String> = switch (stageUI)
		{
			case "pixel": ['${stageUI}UI/ready-pixel', '${stageUI}UI/set-pixel', '${stageUI}UI/date-pixel'];
			case "normal": ["ready", "set", "go"];
			default: ['${stageUI}UI/ready', '${stageUI}UI/set', '${stageUI}UI/go'];
		}
		introAssets.set(stageUI, introImagesArray);
		var introAlts:Array<String> = introAssets.get(stageUI);
		for (asset in introAlts)
			Paths.image(asset);

		Paths.sound('intro3' + introSoundsSuffix);
		Paths.sound('intro2' + introSoundsSuffix);
		Paths.sound('intro1' + introSoundsSuffix);
		Paths.sound('introGo' + introSoundsSuffix);
	}

	public function startCountdown()
	{
		if (startedCountdown)
		{
			callOnScripts('onStartCountdown');
			return false;
		}

		seenCutscene = true;
		inCutscene = false;
		var ret:Dynamic = callOnScripts('onStartCountdown', null, true);
		if (ret != ScriptResult.Stop)
		{
			if (skipCountdown || startOnTime > 0)
				skipArrowStartTween = true;

			if (!characterPlayingAsDad)
			{
				generateStaticArrows(0, SONG.opponentArrowSkin);
				generateStaticArrows(1, SONG.playerArrowSkin);
			}
			else
			{
				generateStaticArrows(1, SONG.opponentArrowSkin);
				generateStaticArrows(0, SONG.playerArrowSkin);
			}

			if (characterPlayingAsDad && !ClientPrefs.data.middleScroll)
				for (i in 0...opponentStrums.members.length)
				{
					final oppoX:Float = opponentStrums.members[i].x;
					opponentStrums.members[i].x = playerStrums.members[i].x;
					playerStrums.members[i].x = oppoX;
				}

			for (i in 0...playerStrums.length)
			{
				setOnScripts('defaultPlayerStrumX' + i, playerStrums.members[i].x);
				setOnScripts('defaultPlayerStrumY' + i, playerStrums.members[i].y);
			}
			for (i in 0...opponentStrums.length)
			{
				setOnScripts('defaultOpponentStrumX' + i, opponentStrums.members[i].x);
				setOnScripts('defaultOpponentStrumY' + i, opponentStrums.members[i].y);
				// if(ClientPrefs.data.middleScroll) opponentStrums.members[i].visible = false;
			}

			startedCountdown = true;
			Conductor.songPosition = -Conductor.crochet * 5;
			setOnScripts('startedCountdown', true);
			callOnScripts('onCountdownStarted', null);

			var swagCounter:Int = 0;
			if (startOnTime > 0)
			{
				clearNotesBefore(startOnTime);
				setSongTime(startOnTime - 350);
				return true;
			}
			else if (skipCountdown)
			{
				setSongTime(0);
				return true;
			}
			moveCameraSection();

			startTimer = new FlxTimer().start(Conductor.crochet / 1000 / playbackRate, function(tmr:FlxTimer)
			{
				characterBopper(tmr.loopsLeft);

				var introAssets:Map<String, Array<String>> = new Map<String, Array<String>>();
				var introImagesArray:Array<String> = switch (stageUI)
				{
					case "pixel": ['${stageUI}UI/ready-pixel', '${stageUI}UI/set-pixel', '${stageUI}UI/date-pixel'];
					case "normal": ["ready", "set", "go"];
					default: ['${stageUI}UI/ready', '${stageUI}UI/set', '${stageUI}UI/go'];
				}
				introAssets.set(stageUI, introImagesArray);

				var introAlts:Array<String> = introAssets.get(stageUI);
				var antialias:Bool = (ClientPrefs.data.antialiasing && !isPixelStage);
				var tick:Countdown = THREE;

				switch (swagCounter)
				{
					case 0:
						intro3Sound = FlxG.sound.play(Paths.sound('intro3' + introSoundsSuffix), 0.6);
						if (intro3Sound != null) intro3Sound.pitch = playbackRate;
						tick = THREE;
						
					case 1:
						countdownReady = createCountdownSprite(introAlts[0], antialias);
						intro2Sound = FlxG.sound.play(Paths.sound('intro2' + introSoundsSuffix), 0.6);
						if (intro2Sound != null) intro2Sound.pitch = playbackRate;
						tick = TWO;
						
					case 2:
						countdownSet = createCountdownSprite(introAlts[1], antialias);
						intro1Sound = FlxG.sound.play(Paths.sound('intro1' + introSoundsSuffix), 0.6);
						if (intro1Sound != null) intro1Sound.pitch = playbackRate;
						tick = ONE;
						
					case 3:
						countdownGo = createCountdownSprite(introAlts[2], antialias);
						introGoSound = FlxG.sound.play(Paths.sound('introGo' + introSoundsSuffix), 0.6);
						if (introGoSound != null) introGoSound.pitch = playbackRate;
						tick = GO;
						
					case 4:
						tick = START;
				}

				notes.forEachAlive(function(note:Note)
				{
					if (ClientPrefs.data.opponentStrums || note.mustPress)
					{
						note.copyAlpha = false;
						note.alpha = note.multAlpha;
						if (ClientPrefs.data.middleScroll && !note.mustPress)
							note.alpha *= 0.35;
					}
				});

				stagesFunc(function(stage:BaseStage) stage.countdownTick(tick, swagCounter));
				callOnLuas('onCountdownTick', [swagCounter]);
				final hsArgs:Array<Dynamic> = [tick, swagCounter];
				callOnHScript('onCountdownTick', hsArgs);

				swagCounter += 1;
			}, 5);
		}
		return true;
	}

	inline private function createCountdownSprite(image:String, antialias:Bool):FlxSprite
	{
		var spr:FlxSprite = new FlxSprite().loadGraphic(Paths.image(image));
		spr.cameras = [camHUD];
		spr.scrollFactor.set();
		spr.updateHitbox();

		if (PlayState.isPixelStage)
			spr.setGraphicSize(Std.int(spr.width * daPixelZoom));

		spr.screenCenter();
		spr.antialiasing = antialias;
		insert(members.indexOf(noteGroup), spr);
		FlxTween.tween(spr, {/*y: spr.y + 100,*/ alpha: 0}, Conductor.crochet / 1000, {
			ease: isPixelStage ? EaseUtil.stepped(8) : FlxEase.cubeInOut,
			onComplete: function(twn:FlxTween)
			{
				remove(spr);
				spr.destroy();
			}
		});
		return spr;
	}

	public function addBehindGF(obj:FlxBasic)
	{
		insert(members.indexOf(gfGroup), obj);
	}

	public function addBehindBF(obj:FlxBasic)
	{
		insert(members.indexOf(boyfriendGroup), obj);
	}

	public function addBehindDad(obj:FlxBasic)
	{
		insert(members.indexOf(dadGroup), obj);
	}

	public function clearNotesBefore(time:Float)
	{
		var i:Int = unspawnNotes.length - 1;
		while (i >= 0)
		{
			var daNote:Note = unspawnNotes[i];
			if (daNote.strumTime - 350 < time)
			{
				daNote.active = false;
				daNote.visible = false;
				daNote.ignoreNote = true;

				if (!ClientPrefs.data.lowQuality || !ClientPrefs.data.popUpRating || !cpuControlled)
					daNote.kill();
				unspawnNotes.remove(daNote);
				daNote.recycle();
			}
			--i;
		}

		i = notes.length - 1;
		while (i >= 0)
		{
			var daNote:Note = notes.members[i];
			if (daNote.strumTime - 350 < time)
			{
				daNote.active = false;
				daNote.visible = false;
				daNote.ignoreNote = true;
				invalidateNote(daNote);
			}
			--i;
		}
	}

	// fun fact: Dynamic Functions can be overriden by just doing this
	// `updateScore = function(miss:Bool = false) { ... }
	// its like if it was a variable but its just a function!
	// cool right? -Crow
	public dynamic function updateScore()
	{
		var ret:Dynamic = callOnScripts('preUpdateScore', [], true);
		if (ret == ScriptResult.Stop)
			return;

		var str:String = ratingName;
		if (totalPlayed != 0)
		{
			var percent:Float = CoolUtil.floorDecimal(ratingPercent * 100, 2);
			str += ' (${percent}%) - ${ratingFC}';
		}

		var tempScore:String = 'Score: ${FlxStringUtil.formatMoney(songScore, false)}' + (!instakillOnMiss ? ' | Misses: ${songMisses}' : "") + ' | Rating: ${str}';
		// "tempScore" variable is used to prevent another memory leak, just in case
		// "\n" here prevents the text from being cut off by beat zooms
		scoreTxt.text = '${tempScore}\n';

		callOnScripts('onUpdateScore', []);
	}

	public dynamic function fullComboFunction()
	{
		var sicks:Int = ratingsData[0].hits;
		var goods:Int = ratingsData[1].hits;
		var bads:Int = ratingsData[2].hits;
		var shits:Int = ratingsData[3].hits;

		ratingFC = "";
		if (songMisses == 0)
		{
			if (bads > 0 || shits > 0)
				ratingFC = 'FC';
			else if (goods > 0)
				ratingFC = 'GFC';
			else if (sicks > 0)
				ratingFC = 'SFC';
		}
		else
		{
			if (songMisses < 10)
				ratingFC = 'SDCB';
			else
				ratingFC = 'Clear';
		}
	}

	public function doScoreBop():Void
	{
		if (!ClientPrefs.data.scoreZoom)
			return;

		if (scoreTxtTween != null)
			scoreTxtTween.cancel();

		scoreTxt.scale.x = 1.075;
		scoreTxt.scale.y = 1.075;
		scoreTxtTween = FlxTween.tween(scoreTxt.scale, {x: 1, y: 1}, 0.2, {
			onComplete: function(twn:FlxTween)
			{
				scoreTxtTween = null;
			}
		});
	}

	public function setSongTime(time:Float)
	{
		if (time < 0)
			time = 0;

		FlxG.sound.music.pause();
		vocals.pause();
		@:privateAccess
		if (opponentVocals._sound != null)
			opponentVocals.pause();

		FlxG.sound.music.time = time;
		FlxG.sound.music.pitch = playbackRate;
		FlxG.sound.music.play();

		if (Conductor.songPosition <= vocals.length)
		{
			vocals.time = time;
			@:privateAccess
			if (opponentVocals._sound != null)
				opponentVocals.time = time;
			vocals.pitch = playbackRate;
			@:privateAccess
			if (opponentVocals._sound != null)
				opponentVocals.pitch = playbackRate;
		}
		vocals.play();
		@:privateAccess
		if (opponentVocals._sound != null)
			opponentVocals.play();
		Conductor.songPosition = time;
	}

	public function startNextDialogue()
	{
		dialogueCount++;
		callOnScripts('onNextDialogue', [dialogueCount]);
	}

	public function skipDialogue()
	{
		callOnScripts('onSkipDialogue', [dialogueCount]);
	}

	function startSong():Void
	{
		startingSong = false;

		@:privateAccess
		FlxG.sound.playMusic(inst._sound, 1, false);
		FlxG.sound.music.pitch = playbackRate;
		FlxG.sound.music.onComplete = () -> finishSong();
		vocals.play();
		@:privateAccess
		if (opponentVocals._sound != null)
			opponentVocals.play();

		setSongTime(Math.max(0, startOnTime - 500));
		startOnTime = 0;

		if (paused)
		{
			// trace('Oopsie doopsie! Paused sound');
			FlxG.sound.music.pause();
			vocals.pause();
			@:privateAccess
			if (opponentVocals._sound != null)
				opponentVocals.pause();
		}

		// Song duration in a float, useful for the time left feature
		songLength = FlxG.sound.music.length;
		FlxTween.tween(timeBar, {alpha: 1}, 0.5, {ease: FlxEase.circOut});
		FlxTween.tween(timeTxt, {alpha: 1}, 0.5, {ease: FlxEase.circOut});

		#if FEATURE_DISCORD_RPC
		// Updating Discord Rich Presence (with Time Left)
		if (autoUpdateRPC)
			DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter(), true, songLength);
		#end
		setOnScripts('songLength', songLength);
		callOnScripts('onSongStart');

		#if (target.threaded)
		runSongSyncThread();
		#end
	}

	var debugNum:Int = 0;
	private var noteTypes:Array<String> = [];
	private var eventsPushed:Array<String> = [];

	private function generateSong(dataPath:String):Void
	{
		// FlxG.log.add(ChartParser.parse());
		songSpeed = PlayState.SONG.speed;
		songSpeedType = ClientPrefs.getGameplaySetting('scrolltype');
		switch (songSpeedType)
		{
			case "multiplicative":
				songSpeed = SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed');
			case "constant":
				songSpeed = ClientPrefs.getGameplaySetting('scrollspeed');
		}

		var songData = SONG;
		Conductor.bpm = songData.bpm;

		curSong = songData.song;

		vocals = new FlxSound();
		opponentVocals = new FlxSound();
		try
		{
			if (songData.needsVoices)
			{
				var playerVocals = Paths.voices(curSong, boyfriend.vocalsFile + Difficulty.getSongPrefix());
				if (playerVocals == null)
					playerVocals = Paths.voices(curSong, 'Player' + Difficulty.getSongPrefix());
				vocals.loadEmbedded(playerVocals ?? Paths.voices(curSong, Difficulty.getSongPrefix(null, false)));

				var oppVocals = Paths.voices(curSong, dad.vocalsFile + Difficulty.getSongPrefix());
				if (oppVocals == null)
					oppVocals = Paths.voices(curSong, 'Opponent' + Difficulty.getSongPrefix());
				if (oppVocals != null)
					opponentVocals.loadEmbedded(oppVocals);
			}
		}
		catch (e:Dynamic)
		{
		}

		vocals.pitch = playbackRate;
		@:privateAccess
		if (opponentVocals._sound != null)
			opponentVocals.pitch = playbackRate;
		FlxG.sound.list.add(vocals);
		@:privateAccess
		if (opponentVocals._sound != null)
			FlxG.sound.list.add(opponentVocals);

		inst = new FlxSound();
		try
		{
			inst.loadEmbedded(Paths.inst(songData.song, Difficulty.getSongPrefix(null, false)));
		}
		catch (e:Dynamic)
		{
		}
		FlxG.sound.list.add(inst);

		notes = new FlxTypedGroup<Note>();
		noteGroup.add(notes);

		var noteData:Array<SwagSection>;

		// NEW SHIT
		noteData = songData.notes;

		isErect = Difficulty.list[storyDifficulty] == ERECT || Difficulty.list[storyDifficulty] == NIGHTMARE;
		var file:String = Paths.json(songName + '/events' + (isErect ? '-erect' : ""));

		if (#if FEATURE_MODS FileSystem.exists(Paths.modsJson(songName + '/events' + (isErect ? '-erect' : ""))) || #end FileSystem.exists(file))
		{
			var eventsData:Array<Dynamic> = Song.loadFromJson('events' + (isErect ? '-erect' : ""), songName).events;
			for (event in eventsData) // Event Notes
				for (i in 0...event[1].length)
					makeEvent(event, i);
		}

		final isPsychRelease:Bool = songData.format == 'psych_v1';

		for (section in noteData)
		{
			for (songNotes in section.sectionNotes)
			{
				var daStrumTime:Float = songNotes[0];
				var daNoteData:Int = Std.int(songNotes[1] % 4);
				var gottaHitNote:Bool = section.mustHitSection;

				if (!isPsychRelease)
				{
					if (songNotes[1] > 3)
					{
						gottaHitNote = !section.mustHitSection;
					}
				}
				else
				{
					gottaHitNote = songNotes[1] < 4;
				}

				if (characterPlayingAsDad)
					gottaHitNote = !gottaHitNote;

				var oldNote:Note;
				if (unspawnNotes.length > 0)
					oldNote = unspawnNotes[Std.int(unspawnNotes.length - 1)];
				else
					oldNote = null;

				var swagNote:Note = Note.getNote(daStrumTime, daNoteData, oldNote);
				swagNote.mustPress = gottaHitNote;
				if (!gottaHitNote && allowedNotes.contains(swagNote.noteType))
					swagNote.texture = SONG.opponentArrowSkin;
				swagNote.sustainLength = songNotes[2];
				swagNote.gfNote = (section.gfSection && (songNotes[1] < 4));
				swagNote.noteType = songNotes[3];
				if (!Std.isOfType(songNotes[3], String))
					swagNote.noteType = ChartingState.noteTypeList[songNotes[3]]; // Backward compatibility + compatibility with Week 7 charts

				swagNote.scrollFactor.set();

				unspawnNotes.push(swagNote);

				final susLength:Float = swagNote.sustainLength / Conductor.stepCrochet;
				final floorSus:Int = Math.floor(susLength);

				if (floorSus > 0)
				{
					for (susNote in 0...floorSus + 1)
					{
						oldNote = unspawnNotes[Std.int(unspawnNotes.length - 1)];

						var sustainNote:Note = Note.getNote(daStrumTime + (Conductor.stepCrochet * susNote), daNoteData, oldNote, true);
						sustainNote.mustPress = gottaHitNote;
						sustainNote.gfNote = (section.gfSection && (songNotes[1] < 4));
						sustainNote.noteType = swagNote.noteType;
						sustainNote.scrollFactor.set();
						sustainNote.parent = swagNote;
						if (!gottaHitNote && allowedNotes.contains(sustainNote.noteType))
							sustainNote.texture = SONG.opponentArrowSkin;
						unspawnNotes.push(sustainNote);
						swagNote.tail.push(sustainNote);

						sustainNote.correctionOffset = swagNote.height / 2;
						if (!PlayState.isPixelStage)
						{
							if (oldNote.isSustainNote)
							{
								oldNote.scale.y *= Note.SUSTAIN_SIZE / oldNote.frameHeight;
								oldNote.scale.y /= playbackRate;
								oldNote.updateHitbox();
							}

							if (ClientPrefs.data.downScroll)
								sustainNote.correctionOffset = 0;
						}
						else if (oldNote.isSustainNote)
						{
							oldNote.scale.y /= playbackRate;
							oldNote.updateHitbox();
						}

						if (sustainNote.mustPress)
							sustainNote.x += FlxG.width / 2; // general offset
						else if (ClientPrefs.data.middleScroll)
						{
							sustainNote.x += 310;
							if (daNoteData > 1) // Up and Right
								sustainNote.x += FlxG.width / 2 + 25;
						}
					}
				}

				if (swagNote.mustPress)
				{
					swagNote.x += FlxG.width / 2; // general offset
				}
				else if (ClientPrefs.data.middleScroll)
				{
					swagNote.x += 310;
					if (daNoteData > 1) // Up and Right
					{
						swagNote.x += FlxG.width / 2 + 25;
					}
				}

				if (!noteTypes.contains(swagNote.noteType))
				{
					noteTypes.push(swagNote.noteType);
				}
			}
		}
		for (event in songData.events) // Event Notes
			for (i in 0...event[1].length)
				makeEvent(event, i);

		unspawnNotes.sort(sortByTime);
		generatedMusic = true;
	}

	// called only once per different event (Used for precaching)
	function eventPushed(event:EventNote)
	{
		eventPushedUnique(event);
		if (eventsPushed.contains(event.event))
		{
			return;
		}

		stagesFunc(function(stage:BaseStage) stage.eventPushed(event));
		eventsPushed.push(event.event);
	}

	// called by every event with the same name
	function eventPushedUnique(event:EventNote)
	{
		switch (event.event)
		{
			case "Change Character":
				var charType:Int = 0;
				switch (event.value1.toLowerCase())
				{
					case 'gf' | 'girlfriend' | '1':
						charType = 2;
					case 'dad' | 'opponent' | '0':
						charType = 1;
					default:
						var val1:Int = Std.parseInt(event.value1);
						if (Math.isNaN(val1))
							val1 = 0;
						charType = val1;
				}

				var newCharacter:String = event.value2;
				addCharacterToList(newCharacter, charType);

			case 'Play Sound':
				Paths.sound(event.value1); // Precache sound
		}
		stagesFunc(function(stage:BaseStage) stage.eventPushedUnique(event));
	}

	function eventEarlyTrigger(event:EventNote):Float
	{
		final args:Array<Dynamic> = [event.event, event.value1, event.value2, event.strumTime];
		var returnedValue:Null<Float> = callOnScripts('eventEarlyTrigger', args, true, [], [0]);
		if (returnedValue != null && returnedValue != 0 /*&& returnedValue != ScriptResult.Continue*/)
		{
			return returnedValue;
		}
		return 0;
	}

	public static function sortByTime(Obj1:Dynamic, Obj2:Dynamic):Int
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.strumTime, Obj2.strumTime);

	function makeEvent(event:Array<Dynamic>, i:Int)
	{
		var subEvent:EventNote = {
			strumTime: event[0] + ClientPrefs.data.noteOffset,
			event: event[1][i][0],
			value1: event[1][i][1],
			value2: event[1][i][2]
		};
		eventNotes.push(subEvent);
		eventPushed(subEvent);
		final args:Array<Dynamic> = [
			subEvent.event,
			subEvent.value1 != null ? subEvent.value1 : '',
			subEvent.value2 != null ? subEvent.value2 : '',
			subEvent.strumTime
		];
		callOnScripts('onEventPushed', args);
	}

	public var skipArrowStartTween:Bool = false; // for lua

	private function generateStaticArrows(player:Int, skin:String):Void
	{
		var strumLineX:Float = ClientPrefs.data.middleScroll ? STRUM_X_MIDDLESCROLL : STRUM_X;
		var strumLineY:Float = ClientPrefs.data.downScroll ? (FlxG.height - 150) : 50;
		for (i in 0...4)
		{
			// FlxG.log.add(i);
			var targetAlpha:Float = 1;
			if (player < 1)
			{
				if (!ClientPrefs.data.opponentStrums)
					targetAlpha = 0;
				else if (ClientPrefs.data.middleScroll)
					targetAlpha = 0.35;
			}

			var babyArrow:StrumNote = new StrumNote(strumLineX, strumLineY, i, player, skin);
			babyArrow.downScroll = ClientPrefs.data.downScroll;
			if (!isStoryMode && !skipArrowStartTween)
			{
				// babyArrow.y -= 10;
				babyArrow.alpha = 0;
				FlxTween.tween(babyArrow, {/*y: babyArrow.y + 10,*/ alpha: targetAlpha}, 1, {ease: FlxEase.circOut, startDelay: 0.5 + (0.2 * i)});
			}
			else
				babyArrow.alpha = targetAlpha;

			if (player == 1)
				playerStrums.add(babyArrow);
			else
			{
				if (ClientPrefs.data.middleScroll)
				{
					babyArrow.x += 310;
					if (i > 1) // Up and Right
					{
						babyArrow.x += FlxG.width / 2 + 25;
					}
				}
				opponentStrums.add(babyArrow);
			}

			strumLineNotes.add(babyArrow);
			babyArrow.postAddedToGroup();
		}
	}

	@:haxe.warning("-WDeprecated")
	override function openSubState(SubState:FlxSubState)
	{
		stagesFunc(function(stage:BaseStage) stage.openSubState(SubState));
		if (paused)
		{
			if (FlxG.sound.music != null)
			{
				FlxG.sound.music.pause();
				vocals.pause();
				@:privateAccess
				if (opponentVocals._sound != null)
					opponentVocals.pause();
			}
			FlxTimer.globalManager.forEach(function(tmr:FlxTimer) if (!tmr.finished)
				tmr.active = false);
			FlxTween.globalManager.forEach(function(twn:FlxTween) if (!twn.finished)
				twn.active = false);
		}

		super.openSubState(SubState);
	}

	override function closeSubState()
	{
		stagesFunc(function(stage:BaseStage) stage.closeSubState());
		if (paused && !closedFromPause)
		{
			if (FlxG.sound.music != null && !startingSong)
				resyncVocals();

			FlxTimer.globalManager.forEach(function(tmr:FlxTimer) if (!tmr.finished)
				tmr.active = true);
			FlxTween.globalManager.forEach(function(twn:FlxTween) if (!twn.finished)
				twn.active = true);

			paused = closedFromPause =  false;
			#if FEATURE_MOBILE_CONTROLS
			mobileControls.instance.visible = touchPad.visible = true;
			#end
			resetRPC(startTimer != null && startTimer.finished);
			#if (target.threaded)
			runSongSyncThread();
			#end
		}
		super.closeSubState();
	}

	override public function onFocus():Void
	{
		if (health > 0 && !paused)
			resetRPC(Conductor.songPosition > 0.0);
		#if (target.threaded)
		shutdownThread = false;
		runSongSyncThread();
		#end
		super.onFocus();
	}

	override public function onFocusLost():Void
	{
		#if FEATURE_DISCORD_RPC
		if (health > 0 && !paused && FlxG.autoPause && autoUpdateRPC)
			DiscordClient.changePresence(detailsPausedText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
		#end
		#if (target.threaded)
		shutdownThread = true;
		#end
		super.onFocusLost();
	}

	// Updating Discord Rich Presence.
	public var autoUpdateRPC:Bool = true; // performance setting for custom RPC things

	function resetRPC(?showTime:Bool = false)
	{
		#if FEATURE_DISCORD_RPC
		if (!autoUpdateRPC)
			return;

		if (showTime)
			DiscordClient.changePresence(detailsText, SONG.song
				+ " ("
				+ storyDifficultyText
				+ ")", iconP2.getCharacter(), true,
				songLength
				- Conductor.songPosition
				- ClientPrefs.data.noteOffset);
		else
			DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
		#end
	}

	function resyncVocals():Void
	{
		if (finishTimer != null)
			return;

		//trace('resynced vocals at ' + Math.floor(Conductor.songPosition));

		FlxG.sound.music.play();
		FlxG.sound.music.pitch = playbackRate;
		Conductor.songPosition = FlxG.sound.music.time + Conductor.offset;

		var checkVocals = @:privateAccess (opponentVocals._sound != null) ? [vocals, opponentVocals] : [vocals];
		for (voc in checkVocals)
		{
			if (FlxG.sound.music.time < vocals.length)
			{
				voc.time = FlxG.sound.music.time;
				voc.pitch = playbackRate;
				#if mobile
				//FlxTween.tween(voc, {volume: 1}, 0.05, {ease: FlxEase.linear});
				#end
				voc.play();
			}
			else
				voc.pause();
		}
	}

	public var paused:Bool = false;
	public var closedFromPause:Bool = false;
	public var canReset:Bool = true;

	var startedCountdown:Bool = false;
	var canPause:Bool = true;
	var freezeCamera:Bool = false;
	var allowDebugKeys:Bool = true;

	override public function update(elapsed:Float)
	{
		if (!inCutscene && !paused && !freezeCamera)
			FlxG.camera.followLerp = 2.4 * cameraSpeed * playbackRate;
		else
			FlxG.camera.followLerp = 0;

		super.update(elapsed);

		if (botplayTxt != null && botplayTxt.visible)
		{
			botplaySine += 180 * elapsed;
			botplayTxt.alpha = 1 - Math.sin((Math.PI * botplaySine) / 180);
		}

		if ((Funkin.controls.PAUSE #if android || FlxG.android.justReleased.BACK #end #if FEATURE_MOBILE_CONTROLS || touchPad.buttonP.justPressed #end)
			&& (startedCountdown && canPause))
		{
			var ret:Dynamic = callOnScripts('onPause', null, true);
			if (ret != ScriptResult.Stop)
			{
				openPauseMenu();
			}
		}

		if (!endingSong && !inCutscene && allowDebugKeys)
		{
			if (Funkin.controls.justPressed('debug_1'))
				openChartEditor();
			else if (Funkin.controls.justPressed('debug_2'))
				openCharacterEditor();
		}

		if (healthBar.bounds.max != null && health > healthBar.bounds.max)
			health = healthBar.bounds.max;

		updateIconsScale(elapsed);
		updateIconsPosition();
		updateIconsStatus();

		if (startedCountdown && !paused)
		{
			Conductor.songPosition += elapsed * 1000 * playbackRate;
			if (Conductor.songPosition >= 0)
			{
				var timeDiff:Float = Math.abs(FlxG.sound.music.time - Conductor.songPosition - Conductor.offset);
				Conductor.songPosition = FlxMath.lerp(Conductor.songPosition, FlxG.sound.music.time, FlxMath.bound(elapsed * 2.5, 0, 1));
				if (timeDiff > 1000 * playbackRate)
					Conductor.songPosition = Conductor.songPosition + 1000 * FlxMath.signOf(timeDiff);
			}
		}

		if (startingSong)
		{
			if (startedCountdown && Conductor.songPosition >= 0)
				startSong();
			else if (!startedCountdown)
				Conductor.songPosition = -Conductor.crochet * 5;
		}
		else if (!paused && updateTime)
		{
			var curTime:Float = Math.max(0, Conductor.songPosition - ClientPrefs.data.noteOffset);
			songPercent = (curTime / songLength);

			var songCalc:Float = (songLength - curTime);
			if (ClientPrefs.data.timeBarType == 'Time Elapsed')
				songCalc = curTime;

			var secondsTotal:Int = Math.floor(songCalc / 1000);
			if (secondsTotal < 0)
				secondsTotal = 0;

			if (ClientPrefs.data.timeBarType != 'Song Name')
				timeTxt.text = FlxStringUtil.formatTime(secondsTotal, false);

			recalculateRating();
		}

		if (camZooming)
		{
			FlxG.camera.zoom = FlxMath.lerp(defaultCamZoom, FlxG.camera.zoom, Math.exp(-elapsed * 3.125 * camZoomingDecay * playbackRate));
			camHUD.zoom = FlxMath.lerp(1, camHUD.zoom, Math.exp(-elapsed * 3.125 * camZoomingDecay * playbackRate));
		}

		FlxG.watch.addQuick("secShit", curSection);
		FlxG.watch.addQuick("beatShit", curBeat);
		FlxG.watch.addQuick("stepShit", curStep);

		// RESET = Quick Game Over Screen
		if (!ClientPrefs.data.noReset && Funkin.controls.RESET && canReset && !inCutscene && startedCountdown && !endingSong)
		{
			health = 0;
			trace("Pressed RESET key, go kaboom");
		}
		doDeathCheck();

		if (unspawnNotes[0] != null)
		{
			var time:Float = spawnTime * playbackRate;
			if (songSpeed < 1)
				time /= songSpeed;
			if (unspawnNotes[0].multSpeed < 1)
				time /= unspawnNotes[0].multSpeed;

			while (unspawnNotes.length > 0 && unspawnNotes[0].strumTime - Conductor.songPosition < time)
			{
				var dunceNote:Note = unspawnNotes[0];
				notes.insert(0, dunceNote);
				dunceNote.spawned = true;
				if (dunceNote.mustPress && allowedNotes.contains(dunceNote.noteType))
					dunceNote.texture = noteSkin;
				else if (!dunceNote.mustPress && allowedNotes.contains(dunceNote.noteType))
					dunceNote.texture = noteSkin1;

				final args:Array<Dynamic> = [
					notes.members.indexOf(dunceNote),
					dunceNote.noteData,
					dunceNote.noteType,
					dunceNote.isSustainNote,
					dunceNote.strumTime
				];
				callOnLuas('onSpawnNote', args);
				callOnHScript('onSpawnNote', [dunceNote]);

				var index:Int = unspawnNotes.indexOf(dunceNote);
				unspawnNotes.splice(index, 1);
			}
		}

		if (generatedMusic)
		{
			if (!inCutscene)
			{
				if (!cpuControlled)
					keysCheck();
				else
					playerDance();

				if (notes.length > 0)
				{
					if (startedCountdown)
					{
						var fakeCrochet:Float = (60 / SONG.bpm) * 1000;
						notes.forEachAlive(function(daNote:Note)
						{
							var strumGroup:FlxTypedGroup<StrumNote> = playerStrums;
							if (!daNote.mustPress)
								strumGroup = opponentStrums;

							var strum:StrumNote = strumGroup.members[daNote.noteData];
							daNote.followStrumNote(strum, fakeCrochet, songSpeed / playbackRate);

							if (daNote.mustPress)
							{
								if (cpuControlled
									&& !daNote.blockHit
									&& daNote.canBeHit
									&& (daNote.isSustainNote || daNote.strumTime <= Conductor.songPosition))
								{
									if (anas[daNote.noteData] != null)
									{
										anas[daNote.noteData].hit = true;
										var noteDiff:Float = Math.abs(daNote.strumTime - Conductor.songPosition + ClientPrefs.data.ratingOffset);
										anas[daNote.noteData].hitJudge = judgeNote(noteDiff);
										anas[daNote.noteData].nearestNote = [daNote.strumTime, daNote.noteData, daNote.sustainLength];
									}
									goodNoteHit(daNote);
								}
							}
							else if (daNote.wasGoodHit && !daNote.hitByOpponent && !daNote.ignoreNote)
								opponentNoteHit(daNote);

							if (daNote.isSustainNote && strum.sustainReduce)
								daNote.clipToStrumNote(strum);

							// Kill extremely late notes and cause misses
							if (Conductor.songPosition - daNote.strumTime > noteKillOffset)
							{
								if (daNote.mustPress && !cpuControlled && !daNote.ignoreNote && !endingSong && (daNote.tooLate || !daNote.wasGoodHit))
									noteMiss(daNote);

								daNote.active = daNote.visible = false;
								invalidateNote(daNote);
							}
						});
					}
					else
					{
						notes.forEachAlive(function(daNote:Note)
						{
							daNote.canBeHit = false;
							daNote.wasGoodHit = false;
						});
					}
				}
			}
			checkEventNote();
		}

		#if debug
		if (!endingSong && !startingSong)
		{
			if (FlxG.keys.justPressed.ONE)
			{
				KillNotes();
				FlxG.sound.music.onComplete();
			}
			if (FlxG.keys.justPressed.TWO) // Go 10 seconds into the future!! :OOO
			{
				setSongTime(Conductor.songPosition + 10000);
				clearNotesBefore(Conductor.songPosition);
			}
		}
		#end

		setOnScripts('cameraX', camFollow.x);
		setOnScripts('cameraY', camFollow.y);
		setOnScripts('botPlay', cpuControlled);
	}

	// Health icon updaters
	public dynamic function updateIconsScale(elapsed:Float)
	{
		var mult:Float = FlxMath.lerp(1, iconP1.scale.x, Math.exp(-elapsed * 9 * playbackRate));
		iconP1.scale.set(mult, mult);
		iconP1.updateHitbox();

		var mult:Float = FlxMath.lerp(1, iconP2.scale.x, Math.exp(-elapsed * 9 * playbackRate));
		iconP2.scale.set(mult, mult);
		iconP2.updateHitbox();
	}

	public dynamic function updateIconsPosition()
	{
		var iconOffset:Int = 26;
		iconP1.x = healthBar.barCenter + (150 * iconP1.scale.x - 150) / 2 - iconOffset;
		iconP2.x = healthBar.barCenter - (150 * iconP2.scale.x) / 2 - iconOffset * 2;
	}

	public dynamic function updateIconsStatus()
	{
		final iconP1HasLoseIcon:Bool = (iconP1.animation.curAnim.frames.length >= 2);
		final iconP1HasWinIcon:Bool = (iconP1.animation.curAnim.frames.length >= 3);
		final iconP2HasLoseIcon:Bool = (iconP2.animation.curAnim.frames.length >= 2);
		final iconP2HasWinIcon:Bool = (iconP2.animation.curAnim.frames.length >= 3);

		inline function setFrameIfDifferent(icon:HealthIcon, frame:Int)
		{
			if (icon.animation.curAnim.curFrame != frame)
				icon.animation.curAnim.curFrame = frame;
		}

		if (characterPlayingAsDad)
		{
			if (healthBar.percent > 80)
			{
				setFrameIfDifferent(iconP1, iconP1HasLoseIcon ? 1 : 0);
				setFrameIfDifferent(iconP2, iconP2HasWinIcon ? 2 : 0);
			}
			else if (healthBar.percent < 20)
			{
				setFrameIfDifferent(iconP2, iconP2HasLoseIcon ? 1 : 0);
				setFrameIfDifferent(iconP1, iconP1HasWinIcon ? 2 : 0);
			}
			else
			{
				setFrameIfDifferent(iconP1, 0);
				setFrameIfDifferent(iconP2, 0);
			}
		}
		else
		{
			if (healthBar.percent < 20)
			{
				setFrameIfDifferent(iconP1, iconP1HasLoseIcon ? 1 : 0);
				setFrameIfDifferent(iconP2, iconP2HasWinIcon ? 2 : 0);
			}
			else if (healthBar.percent > 80)
			{
				setFrameIfDifferent(iconP2, iconP2HasLoseIcon ? 1 : 0);
				setFrameIfDifferent(iconP1, iconP1HasWinIcon ? 2 : 0);
			}
			else
			{
				setFrameIfDifferent(iconP2, 0);
				setFrameIfDifferent(iconP1, 0);
			}
		}
	}

	function set_health(value:Float):Float
	{
		value = FlxMath.roundDecimal(value, 5); // Fix Float imprecision

		if (healthBar == null || !healthBar.enabled || healthBar.valueFunction == null)
		{
			health = value;
			return health;
		}

		// update health bar
		health = value;
		var newPercent:Null<Float> = FlxMath.remapToRange(FlxMath.bound(healthBar.valueFunction(), healthBar.bounds.min, healthBar.bounds.max),
			healthBar.bounds.min, healthBar.bounds.max, 0, 100);
		healthBar.percent = (newPercent != null ? newPercent : 0);
		return health;
	}

	function openPauseMenu()
	{
		FlxG.camera.followLerp = 0;
		persistentUpdate = false;
		persistentDraw = true;
		paused = true;

		if (FlxG.sound.music != null)
		{
			FlxG.sound.music.pause();
			vocals.pause();
			@:privateAccess
			if (opponentVocals._sound != null)
				opponentVocals.pause();
		}
		if (!cpuControlled)
		{
			for (note in playerStrums)
				if (note.animation.curAnim != null && note.animation.curAnim.name != 'static')
				{
					note.playAnim('static');
					note.resetAnim = 0;
				}
		}
		switchSubState(PauseSubState);

		#if FEATURE_DISCORD_RPC
		if (autoUpdateRPC)
			DiscordClient.changePresence(detailsPausedText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
		#end
	}

	public function openChartEditor()
	{
		FlxG.camera.followLerp = 0;
		persistentUpdate = false;
		paused = true;
		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();
		chartingMode = true;

		#if FEATURE_DISCORD_RPC
		DiscordClient.changePresence("Chart Editor", null, null, true);
		DiscordClient.resetClientID();
		#end

		Funkin.switchState(ChartingState);
	}

	public function openCharacterEditor()
	{
		FlxG.camera.followLerp = 0;
		persistentUpdate = false;
		paused = true;
		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();
		#if FEATURE_DISCORD_RPC DiscordClient.resetClientID(); #end
		Funkin.switchState(CharacterEditorState, [SONG.player2]);
	}

	public var isDead:Bool = false; // Don't mess with this on Lua!!!

	function doDeathCheck(?skipHealthCheck:Bool = false)
	{
		if (((skipHealthCheck && instakillOnMiss) || health <= 0) && !practiceMode && !isDead)
		{
			var ret:Dynamic = callOnScripts('onGameOver', null, true);
			if (ret != ScriptResult.Stop)
			{
				FlxG.animationTimeScale = 1;
				boyfriend.stunned = true;
				deathCounter++;

				paused = true;
				canPause = false;
				#if FEATURE_VIDEOS
				if (videoCutscene != null)
				{
					videoCutscene.destroy();
					videoCutscene = null;
				}
				#end

				vocals.stop();
				@:privateAccess
				if (opponentVocals._sound != null)
					opponentVocals.stop();
				FlxG.sound.music.stop();

				persistentUpdate = false;
				persistentDraw = false;
				FlxTimer.globalManager.clear();
				FlxTween.globalManager.clear();
				#if FEATURE_LUA
				modchartTimers.clear();
				modchartTweens.clear();
				#end

				switchSubState(GameOverSubstate);

				// Funkin.switchState(GameOverState, [boyfriend.getScreenPosition().x, boyfriend.getScreenPosition().y]);

				#if FEATURE_DISCORD_RPC
				// Game Over doesn't get his its variable because it's only used here
				if (autoUpdateRPC)
					DiscordClient.changePresence("Game Over - " + detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
				#end
				isDead = true;
				return true;
			}
		}
		return false;
	}

	public function checkEventNote()
	{
		while (eventNotes.length > 0)
		{
			var leStrumTime:Float = eventNotes[0].strumTime;
			if (Conductor.songPosition < leStrumTime)
			{
				return;
			}

			var value1:String = '';
			if (eventNotes[0].value1 != null)
				value1 = eventNotes[0].value1;

			var value2:String = '';
			if (eventNotes[0].value2 != null)
				value2 = eventNotes[0].value2;

			triggerEvent(eventNotes[0].event, value1, value2, leStrumTime);
			eventNotes.shift();
		}
	}

	public function triggerEvent(eventName:String, value1:String, value2:String, strumTime:Float)
	{
		var flValue1:Null<Float> = Std.parseFloat(value1);
		var flValue2:Null<Float> = Std.parseFloat(value2);
		if (Math.isNaN(flValue1))
			flValue1 = null;
		if (Math.isNaN(flValue2))
			flValue2 = null;

		switch (eventName)
		{
			case 'Hey!':
				var value:Int = 2;
				switch (value1.toLowerCase().trim())
				{
					case 'bf' | 'boyfriend' | '0':
						value = 0;
					case 'gf' | 'girlfriend' | '1':
						value = 1;
				}

				if (flValue2 == null || flValue2 <= 0)
					flValue2 = 0.6;

				if (value != 0)
				{
					if (dad.curCharacter.startsWith('gf')) // Tutorial GF is actually Dad, what on my life I'm doing..-
					{
						dad.playAnim('cheer', true);
						dad.specialAnim = true;
						dad.heyTimer = flValue2;
					}
					else if (gf != null)
					{
						gf.playAnim('cheer', true);
						gf.specialAnim = true;
						gf.heyTimer = flValue2;
					}
				}
				if (value != 1)
				{
					boyfriend.playAnim('hey', true);
					boyfriend.specialAnim = true;
					boyfriend.heyTimer = flValue2;
				}

			case 'Set GF Speed':
				if (flValue1 == null || flValue1 < 1)
					flValue1 = 1;
				gfSpeed = Math.round(flValue1);

			case 'Add Camera Zoom':
				if (ClientPrefs.data.camZooms && FlxG.camera.zoom < 1.35)
				{
					if (flValue1 == null)
						flValue1 = 0.015;
					if (flValue2 == null)
						flValue2 = 0.03;

					FlxG.camera.zoom += flValue1;
					camHUD.zoom += flValue2;
				}

			case 'Play Animation':
				// trace('Anim to play: ' + value1);
				var char:Character = dad;
				switch (value2.toLowerCase().trim())
				{
					case 'bf' | 'boyfriend':
						char = boyfriend;
					case 'gf' | 'girlfriend':
						char = gf;
					default:
						if (flValue2 == null)
							flValue2 = 0;
						switch (Math.round(flValue2))
						{
							case 1: char = boyfriend;
							case 2: char = gf;
						}
				}

				if (char != null)
				{
					char.playAnim(value1, true);
					char.specialAnim = true;
				}

			case 'Camera Follow Pos':
				if (camFollow != null)
				{
					isCameraOnForcedPos = false;
					if (flValue1 != null || flValue2 != null)
					{
						isCameraOnForcedPos = true;
						if (flValue1 == null)
							flValue1 = 0;
						if (flValue2 == null)
							flValue2 = 0;

						camTween?.cancel();
						camTween = null;

						camFollow.x = flValue1;
						camFollow.y = flValue2;
					}
				}

			case 'Alt Idle Animation':
				var char:Character = dad;
				switch (value1.toLowerCase().trim())
				{
					case 'gf' | 'girlfriend':
						char = gf;
					case 'boyfriend' | 'bf':
						char = boyfriend;
					default:
						var val:Int = Std.parseInt(value1);
						if (Math.isNaN(val))
							val = 0;

						switch (val)
						{
							case 1: char = boyfriend;
							case 2: char = gf;
						}
				}

				if (char != null)
				{
					char.idleSuffix = value2;
					char.recalculateDanceIdle();
				}

			case 'Screen Shake':
				var valuesArray:Array<String> = [value1, value2];
				var targetsArray:Array<FlxCamera> = [camGame, camHUD];
				for (i in 0...targetsArray.length)
				{
					var split:Array<String> = valuesArray[i].split(',');
					var duration:Float = 0;
					var intensity:Float = 0;
					if (split[0] != null)
						duration = Std.parseFloat(split[0].trim());
					if (split[1] != null)
						intensity = Std.parseFloat(split[1].trim());
					if (Math.isNaN(duration))
						duration = 0;
					if (Math.isNaN(intensity))
						intensity = 0;

					if (duration > 0 && intensity != 0)
					{
						targetsArray[i].shake(intensity, duration);
					}
				}

			case 'Change Character':
				var charType:Int = 0;

				switch (value1.toLowerCase().trim())
				{
					case 'gf' | 'girlfriend':
						charType = 2;
					case 'dad' | 'opponent':
						charType = 1;
					default:
						charType = Std.parseInt(value1);
						if (Math.isNaN(charType)) charType = 0;
				}

				switch (charType)
				{
					case 0:
						if (boyfriend.curCharacter != value2)
						{
							if (!boyfriendMap.exists(value2))
							{
								addCharacterToList(value2, charType);
							}

							var lastAlpha:Float = boyfriend.alpha;
							boyfriend.alpha = 0.00001;
							boyfriend = boyfriendMap.get(value2);
							boyfriend.alpha = lastAlpha;
							iconP1.changeIcon(boyfriend.healthIcon);
						}
						setOnScripts('boyfriendName', boyfriend.curCharacter);

					case 1:
						if (dad.curCharacter != value2)
						{
							if (!dadMap.exists(value2))
							{
								addCharacterToList(value2, charType);
							}

							var wasGf:Bool = dad.curCharacter.startsWith('gf-') || dad.curCharacter == 'gf';
							var lastAlpha:Float = dad.alpha;
							dad.alpha = 0.00001;
							dad = dadMap.get(value2);
							if (!dad.curCharacter.startsWith('gf-') && dad.curCharacter != 'gf')
							{
								if (wasGf && gf != null)
								{
									gf.visible = true;
								}
							}
							else if (gf != null)
							{
								gf.visible = false;
							}
							dad.alpha = lastAlpha;
							iconP2.changeIcon(dad.healthIcon);
						}
						setOnScripts('dadName', dad.curCharacter);

					case 2:
						if (gf != null)
						{
							if (gf.curCharacter != value2)
							{
								if (!gfMap.exists(value2))
								{
									addCharacterToList(value2, charType);
								}

								var lastAlpha:Float = gf.alpha;
								gf.alpha = 0.00001;
								gf = gfMap.get(value2);
								gf.alpha = lastAlpha;
							}
							setOnScripts('gfName', gf.curCharacter);
						}
				}
				reloadHealthBarColors();

			case 'Change Scroll Speed':
				if (songSpeedType != "constant")
				{
					if (flValue1 == null)
						flValue1 = 1;
					if (flValue2 == null)
						flValue2 = 0;

					var newValue:Float = SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed') * flValue1;
					if (flValue2 <= 0)
						songSpeed = newValue;
					else
						songSpeedTween = FlxTween.tween(this, {songSpeed: newValue}, flValue2 / playbackRate, {
							ease: FlxEase.linear,
							onComplete: function(twn:FlxTween)
							{
								songSpeedTween = null;
							}
						});
				}

			case 'Set Property':
				try
				{
					var split:Array<String> = value1.split('.');
					if (split.length > 1)
					{
						LuaUtils.setVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1], value2);
					}
					else
					{
						LuaUtils.setVarInArray(this, value1, value2);
					}
				}
				catch (e:Dynamic)
				{
					var len:Int = e.message.indexOf('\n') + 1;
					if (len <= 0)
						len = e.message.length;
					#if (FEATURE_LUA || FEATURE_HSCRIPT)
					addTextToDebug('ERROR ("Set Property" Event) - ' + e.message.substr(0, len), FlxColor.RED);
					#else
					FlxG.log.warn('ERROR ("Set Property" Event) - ' + e.message.substr(0, len));
					#end
				}

			case 'Play Sound':
				if (flValue2 == null)
					flValue2 = 1;
				FlxG.sound.play(Paths.sound(value1), flValue2);

			case 'Set Camera Bopping':
				var val1:Float = Std.parseFloat(value1);
				var val2:Float = Std.parseFloat(value2);
				camZoomingMult = !Math.isNaN(val2) ? val2 : 1;
				camZoomingFrequency = !Math.isNaN(val1) ? val1 : 4;

			case 'Focus Camera': // P-slice focus camera event notes val1: char val2: x,y,dur,ease
				isCameraOnForcedPos = false;
				var keyValues:Array<String> = value2.split(",");
				if (keyValues.length != 4)
				{
					trace("INVALID EVENT VALUE");
					return;
				}
				var ease:String = keyValues.pop().toLowerCase();
				var floaties:Array<Float> = keyValues.map(s -> Std.parseFloat(s));
				if (findIndex(floaties, s -> Math.isNaN(s)) != -1)
				{
					trace("INVALID FLOATIES");
					return;
				}
				isCameraOnForcedPos = true;

				var targetX:Float = floaties[0];
				var targetY:Float = floaties[1];
				var duration:Float = floaties[2] * (Conductor.stepCrochet / 1000);
				switch (value1.toString().toLowerCase())
				{
					case "bf" | "0": {
						targetX += boyfriend.getMidpoint().x - 100 - boyfriend.cameraPosition[0] + boyfriendCameraOffset[0];
						targetY += boyfriend.getMidpoint().y - 100 + boyfriend.cameraPosition[1] + boyfriendCameraOffset[1];
					}
					case "dad" | "1": {
						targetX += dad.getMidpoint().x + 150 + dad.cameraPosition[0] + opponentCameraOffset[0];
						targetY += dad.getMidpoint().y - 100 + dad.cameraPosition[1] + opponentCameraOffset[1];
					}
					case "gf" | "2": {
						targetX += gf.getMidpoint().x + gf.cameraPosition[0] - girlfriendCameraOffset[0];
						targetY += gf.getMidpoint().y + gf.cameraPosition[1] - girlfriendCameraOffset[1];
					}
				}

				camTween?.cancel();
				camTween = null;

				if (ease == "classic" || ease == "instant")
				{
					camFollow.x = targetX;
					camFollow.y = targetY;
					if (ease == "instant")
						FlxG.camera.snapToTarget();
				}
				else
				{
					var easeFunc = psychlua.LuaUtils.getTweenEaseByString(ease);
					camTween = FlxTween.tween(camFollow, {x: targetX, y: targetY}, duration, {
						ease: easeFunc,
						onComplete: s ->
						{
							camTween = null;
						}
					});
				}

			case 'Zoom Camera': // P-slice zoom camera event notes val1: dur,zoom val2: ease
				var keyValues:Array<String> = value1.split(",");
				if (keyValues.length != 2)
				{
					trace("INVALID EVENT VALUE");
					return;
				}

				var floaties:Array<Float> = keyValues.map(s -> Std.parseFloat(s));
				if (findIndex(floaties, s -> Math.isNaN(s)) != -1)
				{
					trace("INVALID FLOATIES");
					return;
				}

				var targetZoom:Float = floaties[1];
				if (targetZoom <= 0)
				{
					trace("INVALID TARGET ZOOM: " + targetZoom);
					return;
				}

				if (zoomTween != null)
				{
					zoomTween.cancel();
					zoomTween = null;
				}

				var easeStr:String = (value2 != null) ? value2.toLowerCase() : "";
				if (easeStr == "classic" || easeStr == "instant")
				{
					defaultCamZoom = targetZoom;

					if (easeStr == "instant")
						FlxG.camera.zoom = targetZoom;

					return;
				}

				var easeFunc = psychlua.LuaUtils.getTweenEaseByString(value2);

				zoomTween = FlxTween.tween(this, {defaultCamZoom: targetZoom}, (Conductor.stepCrochet / 1000) * floaties[0], {
					onStart: (x) ->
					{
						// camZooming = false;
						camZoomingDecay = 7;
					},
					ease: easeFunc,
					onComplete: (x) ->
					{
						defaultCamZoom = targetZoom;
						camZoomingDecay = 1;
						// camZooming = true;
						zoomTween = null;
					}
				});
		}

		final args:Array<Dynamic> = [eventName, value1, value2, strumTime];
		stagesFunc(function(stage:BaseStage) stage.eventCalled(eventName, value1, value2, flValue1, flValue2, strumTime));
		callOnScripts('onEvent', args);
	}

	private static function findIndex<T>(array:Array<T>, predicate:T->Bool):Int
	{
		for (i in 0...array.length)
			if (predicate(array[i]))
				return i;

		return -1;
	}

	function moveCameraSection(?sec:Null<Int>):Void
	{
		if (sec == null)
			sec = curSection;
		if (sec < 0)
			sec = 0;

		if (SONG.notes[sec] == null)
			return;

		if (gf != null && SONG.notes[sec].gfSection)
		{
			camFollow.setPosition(gf.getMidpoint().x, gf.getMidpoint().y);
			camFollow.x += gf.cameraPosition[0] + girlfriendCameraOffset[0];
			camFollow.y += gf.cameraPosition[1] + girlfriendCameraOffset[1];
			callOnScripts('onMoveCamera', ['gf']);
			return;
		}

		var isDad:Bool = (SONG.notes[sec].mustHitSection != true);
		moveCamera(isDad);
		callOnScripts('onMoveCamera', [isDad ? 'dad' : 'boyfriend']);
	}

	var cameraTwn:FlxTween;

	public function moveCamera(isDad:Bool)
	{
		if (isDad)
		{
			camFollow.setPosition(dad.getMidpoint().x + 150, dad.getMidpoint().y - 100);
			camFollow.x += dad.cameraPosition[0] + opponentCameraOffset[0];
			camFollow.y += dad.cameraPosition[1] + opponentCameraOffset[1];
		}
		else
		{
			camFollow.setPosition(boyfriend.getMidpoint().x - 100, boyfriend.getMidpoint().y - 100);
			camFollow.x -= boyfriend.cameraPosition[0] - boyfriendCameraOffset[0];
			camFollow.y += boyfriend.cameraPosition[1] + boyfriendCameraOffset[1];
		}
	}

	public function finishSong(?ignoreNoteOffset:Bool = false):Void
	{
		updateTime = false;
		FlxG.sound.music.volume = 0;

		vocals.volume = 0;
		vocals.pause();
		@:privateAccess
		if (opponentVocals._sound != null)
		{
			opponentVocals.volume = 0;
			opponentVocals.pause();
		}

		if (ClientPrefs.data.noteOffset <= 0 || ignoreNoteOffset)
			endCallback();
		else
			finishTimer = new FlxTimer().start(ClientPrefs.data.noteOffset / 1000, function(tmr:FlxTimer)
			{
				endCallback();
			});
	}

	public function showResults():Void
	{
		persistentUpdate = false;
		persistentDraw = true;
		paused = true;
		switchSubState(ResultsScreen);
	}

	public var transitioning = false;

	public function endSong()
	{
		#if FEATURE_MOBILE_CONTROLS
		mobileControls.instance.visible = touchPad.visible = false;
		#end
		// Should kill you if you tried to cheat
		if (!startingSong)
		{
			notes.forEach(function(daNote:Note)
			{
				if (daNote.strumTime < songLength - Conductor.safeZoneOffset)
				{
					health -= 0.05 * healthLoss;
				}
			});
			for (daNote in unspawnNotes)
			{
				if (daNote.strumTime < songLength - Conductor.safeZoneOffset)
				{
					health -= 0.05 * healthLoss;
				}
			}

			if (doDeathCheck())
			{
				return false;
			}
		}

		timeBar.visible = false;
		timeTxt.visible = false;
		canPause = false;
		endingSong = true;
		camZooming = false;
		inCutscene = false;
		updateTime = false;
		characterPlayingAsDad = false;

		deathCounter = 0;
		seenCutscene = false;

		var ret:Dynamic = callOnScripts('onEndSong', null, true);
		if (ret != ScriptResult.Stop && !transitioning)
		{
			var percent:Float = ratingPercent;
			if (Math.isNaN(percent))
				percent = 0;
			Highscore.saveScore(SONG.song, songScore, storyDifficulty, percent);

			playbackRate = 1;

			if (chartingMode)
			{
				openChartEditor();
				return false;
			}

			transitioning = true;
			showResults();
		}
		return true;
	}

	public function doTransitionAfterResults():Void
	{
		if (isStoryMode)
		{
			campaignScore += songScore;
			campaignMisses += songMisses;

			storyPlaylist.remove(storyPlaylist[0]);

			if (storyPlaylist.length <= 0)
			{
				Mods.loadTopMod();
				FlxG.sound.playMusic(Paths.music('freakyMenu'));
				#if FEATURE_DISCORD_RPC DiscordClient.resetClientID(); #end

				Funkin.switchState(StoryMenuState);

				if (!ClientPrefs.getGameplaySetting('practice') && !ClientPrefs.getGameplaySetting('botplay'))
				{
					StoryMenuState.weekCompleted.set(WeekData.weeksList[storyWeek], true);
					Highscore.saveWeekScore(WeekData.getWeekFileName(), campaignScore, storyDifficulty);

					FlxG.save.data.weekCompleted = StoryMenuState.weekCompleted;
					FlxG.save.flush();
				}
				changedDifficulty = false;
			}
			else
			{
				var difficulty:String = Difficulty.getFilePath();

				trace('LOADING NEXT SONG');
				trace(Paths.formatToSongPath(PlayState.storyPlaylist[0]) + difficulty);

				FlxTransitionableState.skipNextTransIn = true;
				FlxTransitionableState.skipNextTransOut = true;
				prevCamFollow = camFollow;

				PlayState.SONG = Song.loadFromJson(PlayState.storyPlaylist[0] + difficulty, PlayState.storyPlaylist[0]);
				FlxG.sound.music.stop();

				LoadingState.prepareToSong();
				LoadingState.loadAndSwitchState(PlayState, false, false);
			}
		}
		else
		{
			trace('WENT BACK TO FREEPLAY??');
			Mods.loadTopMod();
			#if FEATURE_DISCORD_RPC DiscordClient.resetClientID(); #end

			Funkin.switchState(FreeplayState);
			FlxG.sound.playMusic(Paths.music('freakyMenu'));
			changedDifficulty = false;
		}
	}

	public function KillNotes()
	{
		while (notes.length > 0)
		{
			var daNote:Note = notes.members[0];
			daNote.active = false;
			daNote.visible = false;
			invalidateNote(daNote);
		}
		unspawnNotes = [];
		eventNotes = [];
	}

	public var totalPlayed:Int = 0;
	public var totalNotesHit:Float = 0.0;

	public var showCombo:Bool = false;
	public var showComboNum:Bool = true;
	public var showRating:Bool = true;
	public var noteTimingRating:FlxText;
	public var noteTimingRatingTween:FlxTween;

	// Stores Ratings and Combo Sprites in a group
	public var comboGroup:FlxSpriteGroup;
	// Stores HUD Objects in a Group
	public var uiGroup:FlxSpriteGroup;
	// Stores Note Objects in a Group
	public var noteGroup:FlxTypedGroup<FlxBasic>;
	// Stores The Cached PopUpRating Sprites As String
	public var ratingsCache:Map<String, FlxSprite> = new Map<String, FlxSprite>();

	private function cachePopUpScore()
	{
		var uiPrefix:String = '';
		var uiSuffix:String = '';
		if (stageUI != "normal")
		{
			uiPrefix = '${stageUI}UI/';
			if (PlayState.isPixelStage)
				uiSuffix = '-pixel';
		}

		for (rating in ratingsData)
		{
			var ratingImage:String = uiPrefix + rating.image + uiSuffix;
			var leRating = new FlxSprite().loadGraphic(Paths.image(ratingImage));
			ratingsCache.set(ratingImage, leRating);
		}

		for (ratingNum in 0...10)
		{
			var ratingImage:String = uiPrefix + 'num' + ratingNum + uiSuffix;
			var leRating = new FlxSprite().loadGraphic(Paths.image(ratingImage));
			ratingsCache.set(ratingImage, leRating);
		}
	}

	private function popUpScore(note:Note = null):Void
	{
		var noteDiffNoAbs:Float = note.strumTime - Conductor.songPosition + ClientPrefs.data.ratingOffset;
		var noteDiff:Float = Math.abs(noteDiffNoAbs);

		if (!ClientPrefs.data.comboStacking && comboGroup.members.length > 0)
		{
			for (spr in comboGroup)
			{
				spr.destroy();
				comboGroup.remove(spr);
			}
		}

		var placement:Float = FlxG.width * 0.35;
		var rating:FlxSprite = new FlxSprite();

		var judgment:String = Rating.judgeNote(noteDiff);
		var score:Int = Rating.scoreNote(noteDiff);

		// tryna do PBOT1 based judgment due to popular demand
		var daRating:Rating = switch (judgment)
		{
			case 'sick':
				ratingsData[0]; // sick
			case 'good':
				ratingsData[1]; // good
			case 'bad':
				ratingsData[2]; // bad
			case 'shit':
				ratingsData[3]; // shit
			default:
				ratingsData[3]; // default to shit
		};

		switch (daRating.image)
		{
			case 'good':
				++totalGood;
			case 'bad':
				++totalBad;
			case 'shit':
				++totalShit;
			default:
				++totalSick;
		}

		totalNotesHit += daRating.ratingMod;
		note.ratingMod = daRating.ratingMod;
		if (!note.ratingDisabled)
			daRating.hits++;
		note.rating = daRating.name;

		if (daRating.noteSplash && !note.noteSplashData.disabled)
			spawnNoteSplashOnNote(note);

		if (!practiceMode && !cpuControlled && !note.ratingDisabled)
		{
			songScore += score;
			songHits++;
			totalPlayed++;
		}

		var uiPrefix:String = "";
		var uiSuffix:String = '';
		var antialias:Bool = ClientPrefs.data.antialiasing;

		if (stageUI != "normal")
		{
			uiPrefix = '${stageUI}UI/';
			if (PlayState.isPixelStage)
				uiSuffix = '-pixel';
			antialias = !isPixelStage;
		}
		if (ClientPrefs.data.popUpRating)
		{
			rating.loadGraphicFromSprite(ratingsCache.get(uiPrefix + daRating.image + uiSuffix));
			rating.screenCenter();
			rating.x = placement - 40;
			rating.y -= 60;
			rating.acceleration.y = 550 * playbackRate * playbackRate;
			rating.velocity.y -= FlxG.random.int(140, 175) * playbackRate;
			rating.velocity.x -= FlxG.random.int(0, 10) * playbackRate;
			rating.visible = (!ClientPrefs.data.hideHud && showRating);
			rating.x += ClientPrefs.data.comboOffset[0];
			rating.y -= ClientPrefs.data.comboOffset[1];
			rating.antialiasing = antialias;
			rating.pixelPerfectRender = !antialias;
			rating.pixelPerfectPosition = !antialias;

			var comboSpr:FlxSprite = new FlxSprite().loadGraphic(Paths.image(uiPrefix + 'combo' + uiSuffix));
			comboSpr.screenCenter();
			comboSpr.x = placement;
			comboSpr.acceleration.y = FlxG.random.int(200, 300) * playbackRate * playbackRate;
			comboSpr.velocity.y -= FlxG.random.int(140, 160) * playbackRate;
			comboSpr.visible = (!ClientPrefs.data.hideHud && showCombo);
			comboSpr.x += ClientPrefs.data.comboOffset[0];
			comboSpr.y -= ClientPrefs.data.comboOffset[1];
			comboSpr.antialiasing = antialias;
			comboSpr.pixelPerfectRender = !antialias;
			comboSpr.pixelPerfectPosition = !antialias;
			comboSpr.y += 60;
			comboSpr.velocity.x += FlxG.random.int(1, 10) * playbackRate;
			comboGroup.add(rating);

			if (!PlayState.isPixelStage)
			{
				rating.setGraphicSize(Std.int(rating.width * 0.7));
				comboSpr.setGraphicSize(Std.int(comboSpr.width * 0.7));
			}
			else
			{
				rating.setGraphicSize(Std.int(rating.width * daPixelZoom * 0.85));
				comboSpr.setGraphicSize(Std.int(comboSpr.width * daPixelZoom * 0.85));
			}

			comboSpr.updateHitbox();
			rating.updateHitbox();

			if (ClientPrefs.data.showNoteTiming && (!ClientPrefs.data.hideHud && showRating) && noteTimingRating == null)
			{
				add(noteTimingRating = new FlxText(0, 0, 0, "0ms"));
			}
			if (noteTimingRating != null)
			{
				switch (daRating.name)
				{
					case 'shit' | 'bad':
						noteTimingRating.color = FlxColor.RED;
					case 'good':
						noteTimingRating.color = FlxColor.LIME;
					case 'sick':
						noteTimingRating.color = FlxColor.CYAN;
				}
				noteTimingRating.borderStyle = OUTLINE;
				noteTimingRating.borderSize = 1;
				noteTimingRating.borderColor = FlxColor.BLACK;
				noteTimingRating.text = FlxMath.roundDecimal(noteDiffNoAbs / playbackRate, 3) + "ms";
				noteTimingRating.size = 20;
				noteTimingRating.camera = camHUD;
				noteTimingRating.alpha = 1;
				noteTimingRating.active = true;

				if (noteTimingRatingTween != null)
				{
					noteTimingRatingTween.cancel();
				}

				noteTimingRating.screenCenter();
				noteTimingRating.x = placement + ClientPrefs.data.comboOffset[0] + 100;
				noteTimingRating.y += -ClientPrefs.data.comboOffset[1] - 80 + (comboSpr?.height ?? 0);
				if (PlayState.isPixelStage)
					noteTimingRating.y += 60;
				noteTimingRating.acceleration.y = 600;
				noteTimingRating.velocity.y -= 150;
				noteTimingRating.velocity.x += comboSpr?.velocity?.x ?? (FlxG.random.int(1, 10) * playbackRate);

				noteTimingRatingTween = FlxTween.tween(noteTimingRating, {alpha: 0}, 0.2 / playbackRate, {
					startDelay: Conductor.crochet * 0.001 / playbackRate,
					onComplete: (t) -> noteTimingRating.active = false,
					ease: isPixelStage ? EaseUtil.stepped(2) : null
				});
			}

			var seperatedScore:Array<Int> = [];

			var comboStr:String = Std.string(combo);

			for (i in 0...comboStr.length)
			{
				var num = Std.parseInt(comboStr.charAt(i));
				if (num != null)
					seperatedScore.push(num);
			}

			var daLoop:Int = 0;
			var xThing:Float = 0;
			if (showCombo)
				comboGroup.add(comboSpr);

			for (i in seperatedScore)
			{
				var numScore:FlxSprite = new FlxSprite();
				numScore.loadGraphicFromSprite(ratingsCache.get(uiPrefix + 'num' + Std.int(i) + uiSuffix));
				numScore.screenCenter();

				var totalNums:Int = seperatedScore.length;
				var numWidth:Int = 43;
				var totalWidth:Int = totalNums * numWidth;
				var centerX:Float = placement - 30 + ClientPrefs.data.comboOffset[2];
				var startX:Float = centerX - (totalWidth / 2);

				numScore.x = startX + (numWidth * daLoop);
				numScore.y += 80 - ClientPrefs.data.comboOffset[3];

				if (!PlayState.isPixelStage)
					numScore.setGraphicSize(Std.int(numScore.width * 0.5));
				else
					numScore.setGraphicSize(Std.int(numScore.width * daPixelZoom));
				numScore.updateHitbox();

				numScore.acceleration.y = FlxG.random.int(200, 300) * playbackRate * playbackRate;
				numScore.velocity.y -= FlxG.random.int(140, 160) * playbackRate;
				numScore.velocity.x = FlxG.random.float(-5, 5) * playbackRate;
				numScore.visible = !ClientPrefs.data.hideHud;
				numScore.antialiasing = antialias;
				numScore.pixelPerfectRender = !antialias;
				numScore.pixelPerfectPosition = !antialias;

				// if (combo >= 10 || combo == 0)
				if (showComboNum)
					comboGroup.add(numScore);

				FlxTween.tween(numScore, {alpha: 0}, 0.2 / playbackRate, {
					onComplete: function(tween:FlxTween)
					{
						numScore.container = null;
						numScore.destroy();
					},
					startDelay: Conductor.crochet * 0.002 / playbackRate,
					ease: isPixelStage ? EaseUtil.stepped(2) : null
				});

				daLoop++;
				if (numScore.x > xThing)
					xThing = numScore.x;
			}
			comboSpr.x = xThing + 50;
			FlxTween.tween(rating, {alpha: 0}, 0.2 / playbackRate, {
				startDelay: Conductor.crochet * 0.001 / playbackRate,
				onComplete: function(tween:FlxTween)
				{
					rating.container = null;
					rating.destroy();
				},
				ease: isPixelStage ? EaseUtil.stepped(2) : null
			});

			FlxTween.tween(comboSpr, {alpha: 0}, 0.2 / playbackRate, {
				onComplete: function(tween:FlxTween)
				{
					comboSpr.container = null;
					comboSpr.destroy();
					rating.destroy();
				},
				startDelay: Conductor.crochet * 0.002 / playbackRate,
				ease: isPixelStage ? EaseUtil.stepped(2) : null
			});
		}
	}

	public var strumsBlocked:Array<Bool> = [];

	private function onKeyPress(event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(keysArray, eventKey);

		if (!Funkin.controls.controllerMode)
		{
			#if debug
			// Prevents crash specifically on debug without needing to try catch shit
			@:privateAccess if (!FlxG.keys._keyListMap.exists(eventKey))
				return;
			#end

			if (FlxG.keys.checkStatus(eventKey, JUST_PRESSED))
				keyPressed(key);
		}
	}

	private function keyPressed(key:Int)
	{
		var char:Character = (!characterPlayingAsDad) ? boyfriend : dad;
		if (cpuControlled || paused || inCutscene || key < 0 || key >= playerStrums.length || !generatedMusic || endingSong || char.stunned)
			return;

		var ret:Dynamic = callOnScripts('onKeyPressPre', [key]);
		if (ret == ScriptResult.Stop)
			return;

		// obtain notes that the player can hit
		var plrInputNotes:Array<Note> = notes.members.filter(function(n:Note):Bool
		{
			var canHit:Bool = !strumsBlocked[n.noteData] && n.canBeHit && n.mustPress && !n.tooLate && !n.wasGoodHit && !n.blockHit;
			return n != null && canHit && !n.isSustainNote && n.noteData == key;
		});
		plrInputNotes.sort(sortHitNotes);

		var shouldMiss:Bool = !ClientPrefs.data.ghostTapping;

		if (plrInputNotes.length != 0) // slightly faster than doing "> 0" lol
		{
			var funnyNote:Note = plrInputNotes[0]; // front note

			if (plrInputNotes.length > 1)
			{
				var doubleNote:Note = plrInputNotes[1];

				if (doubleNote.noteData == funnyNote.noteData)
				{
					// if the note has a 0ms distance (is on top of the current note), kill it
					if (Math.abs(doubleNote.strumTime - funnyNote.strumTime) < 1.0)
						invalidateNote(doubleNote);
					else if (doubleNote.strumTime < funnyNote.strumTime)
					{
						// replace the note if its ahead of time (or at least ensure "doubleNote" is ahead)
						funnyNote = doubleNote;
					}
				}
			}
			goodNoteHit(funnyNote);
		}
		else if (shouldMiss)
		{
			callOnScripts('onGhostTap', [key]);
			noteMissPress(key);
		}

		var spr:StrumNote = playerStrums.members[key];
		if (strumsBlocked[key] != true && spr != null && spr.animation.curAnim.name != 'confirm')
		{
			spr.playAnim('pressed');
			spr.resetAnim = 0;
		}

		callOnScripts('onKeyPress', [key]);
	}

	public static function sortHitNotes(a:Note, b:Note):Int
	{
		if (a.lowPriority && !b.lowPriority)
			return 1;
		else if (!a.lowPriority && b.lowPriority)
			return -1;

		return FlxSort.byValues(FlxSort.ASCENDING, a.strumTime, b.strumTime);
	}

	private function onKeyRelease(event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(keysArray, eventKey);
		if (!Funkin.controls.controllerMode && key > -1)
			keyReleased(key);
	}

	private function keyReleased(key:Int)
	{
		if (cpuControlled || !startedCountdown || paused || key < 0 || key >= playerStrums.length)
			return;

		var ret:Dynamic = callOnScripts('onKeyReleasePre', [key]);
		if (ret == ScriptResult.Stop)
			return;

		var spr:StrumNote = playerStrums.members[key];
		if (spr != null)
		{
			spr.playAnim('static');
			spr.resetAnim = 0;
		}

		callOnScripts('onKeyRelease', [key]);
	}

	public static function getKeyFromEvent(arr:Array<String>, key:FlxKey):Int
	{
		if (key != NONE)
		{
			for (i in 0...arr.length)
			{
				var note:Array<FlxKey> = Controls.instance.keyboardBinds[arr[i]];
				for (noteKey in note)
					if (key == noteKey)
						return i;
			}
		}
		return -1;
	}

	#if FEATURE_MOBILE_CONTROLS
	private function onButtonPress(button:TouchButton):Void
	{
		if (button.IDs.filter(id -> id.toString().startsWith("EXTRA")).length > 0)
			return;

		var buttonCode:Int = (button.IDs[0].toString().startsWith('NOTE')) ? button.IDs[0] : button.IDs[1];
		callOnScripts('onButtonPressPre', [buttonCode]);
		if (button.justPressed)
			keyPressed(buttonCode);
		callOnScripts('onButtonPress', [buttonCode]);
	}

	private function onButtonRelease(button:TouchButton):Void
	{
		if (button.IDs.filter(id -> id.toString().startsWith("EXTRA")).length > 0)
			return;

		var buttonCode:Int = (button.IDs[0].toString().startsWith('NOTE')) ? button.IDs[0] : button.IDs[1];
		callOnScripts('onButtonReleasePre', [buttonCode]);
		if (buttonCode > -1)
			keyReleased(buttonCode);
		callOnScripts('onButtonRelease', [buttonCode]);
	}
	#end

	// Hold notes
	private function keysCheck():Void
	{
		// HOLDING
		var holdArray:Array<Bool> = [];
		var pressArray:Array<Bool> = [];
		var releaseArray:Array<Bool> = [];
		for (key in keysArray)
		{
			holdArray.push(Funkin.controls.pressed(key));
			pressArray.push(Funkin.controls.justPressed(key));
			releaseArray.push(Funkin.controls.justReleased(key));
		}

		for (i in 0...pressArray.length)
			if (pressArray[i])
				anas[i] = new Ana(Conductor.songPosition, null, false, "miss", i);

		// TO DO: Find a better way to handle controller inputs, this should work for now
		if (Funkin.controls.controllerMode && pressArray.contains(true))
			for (i in 0...pressArray.length)
				if (pressArray[i] && strumsBlocked[i] != true)
					keyPressed(i);

		var char:Character = (!characterPlayingAsDad) ? boyfriend : dad;

		if (startedCountdown && !inCutscene && !char.stunned && generatedMusic)
		{
			if (notes.length > 0)
			{
				for (n in notes) // I can't do a filter here, that's kinda awesome
				{
					var canHit:Bool = (n != null && !strumsBlocked[n.noteData] && n.canBeHit && n.mustPress && !n.tooLate && !n.wasGoodHit && !n.blockHit);

					if (guitarHeroSustains)
						canHit = canHit && n.parent != null && n.parent.wasGoodHit;

					if (canHit && n.isSustainNote)
					{
						var released:Bool = !holdArray[n.noteData];

						if (!released)
						{
							if (anas[n.noteData] != null)
							{
								anas[n.noteData].hit = true;
								var noteDiff:Float = Math.abs(n.strumTime - Conductor.songPosition + ClientPrefs.data.ratingOffset);
								anas[n.noteData].hitJudge = judgeNote(noteDiff);
								anas[n.noteData].nearestNote = [n.strumTime, n.noteData, n.sustainLength];
							}
							goodNoteHit(n);
						}
					}
				}
			}

			if (!holdArray.contains(true) || endingSong)
				playerDance();

			for (i => hold in holdArray)
				if (hold)
					SustainSplash.showAtData(i);
				else
					SustainSplash.hideAtData(i);
		}

		// TO DO: Find a better way to handle controller inputs, this should work for now
		if ((Funkin.controls.controllerMode || strumsBlocked.contains(true)) && releaseArray.contains(true))
			for (i in 0...releaseArray.length)
				if (releaseArray[i] || strumsBlocked[i] == true)
					keyReleased(i);
	}

	function noteMiss(daNote:Note):Void // You didn't hit the key and let it go offscreen, also used by Hurt Notes
	{
		// Dupe note remove
		notes.forEachAlive(function(note:Note)
		{
			if (daNote != note
				&& daNote.mustPress
				&& daNote.noteData == note.noteData
				&& daNote.isSustainNote == note.isSustainNote
				&& Math.abs(daNote.strumTime - note.strumTime) < 1)
				invalidateNote(note);
		});
		songSaveNotes.push([
			daNote != null ? daNote.strumTime : Conductor.songPosition,
			0,
			daNote.noteData,
			-(166 * Math.floor((ClientPrefs.data.safeFrames / 60) * 1000) / 166)
		]);
		songJudges.push("miss");

		final end:Note = daNote.isSustainNote ? daNote.parent.tail[daNote.parent.tail.length - 1] : daNote.tail[daNote.tail.length - 1];
		if (end != null && end.extraData['holdSplash'] != null)
			end.extraData['holdSplash'].visible = false;

		noteMissCommon(daNote.noteData, daNote);
		final args:Array<Dynamic> = [
			notes.members.indexOf(daNote),
			daNote.noteData,
			daNote.noteType,
			daNote.isSustainNote
		];
		callOnLuas('noteMiss', args);
		callOnHScript('noteMiss', [daNote]);
	}

	function noteMissPress(direction:Int = 1):Void // You pressed a key when there was no notes to press for this key
	{
		if (ClientPrefs.data.ghostTapping)
			return; // fuck it we ball

		noteMissCommon(direction);
		callOnScripts('noteMissPress', [direction]);
	}

	function noteMissCommon(direction:Int, note:Note = null)
	{
		// score and data
		var subtract:Float = 0.05;
		if (note != null)
			subtract = note.missHealth;

		// GUITAR HERO SUSTAIN CHECK LOL!!!!
		if (note != null && guitarHeroSustains && note.parent == null)
		{
			if (note.tail.length > 0)
			{
				note.alpha = 0.35;
				for (childNote in note.tail)
				{
					childNote.alpha = note.alpha;
					childNote.missed = true;
					childNote.canBeHit = false;
					childNote.ignoreNote = true;
					childNote.tooLate = true;
				}
				note.missed = true;
				note.canBeHit = false;

				// subtract += 0.385; // you take more damage if playing with this gameplay changer enabled.
				// i mean its fair :p -Crow
				subtract *= note.tail.length + 1;
				// i think it would be fair if damage multiplied based on how long the sustain is -Tahir
			}

			if (note.missed)
				return;
		}
		if (note != null && guitarHeroSustains && note.parent != null && note.isSustainNote)
		{
			if (note.missed)
				return;

			var parentNote:Note = note.parent;
			if (parentNote.wasGoodHit && parentNote.tail.length > 0)
			{
				for (child in parentNote.tail)
					if (child != note)
					{
						child.missed = true;
						child.canBeHit = false;
						child.ignoreNote = true;
						child.tooLate = true;
					}
			}
		}

		if (note.mustPress)
		{
			missnoteSound = FlxG.sound.play(Paths.soundRandom('missnote', 1, 3), FlxG.random.float(0.1, 0.2));
			if (missnoteSound != null)
				missnoteSound.pitch = playbackRate;
		}

		if (instakillOnMiss)
		{
			vocals.volume = 0;
			@:privateAccess
			if (opponentVocals._sound != null)
				opponentVocals.volume = 0;
			doDeathCheck(true);
		}

		var lastCombo:Int = combo;
		combo = 0;

		health -= subtract * healthLoss;
		if (!practiceMode)
			songScore -= (note.isSustainNote) ? Rating.SUSTAIN_MISS_SCORE : Rating.MISS_SCORE;
		if (!endingSong)
			songMisses++;
		totalPlayed++;

		// play character anims
		var char:Character = (!characterPlayingAsDad) ? boyfriend : dad;
		if ((note != null && note.gfNote) || (SONG.notes[curSection] != null && SONG.notes[curSection].gfSection))
			char = gf;

		if (char != null && (note == null || !note.noMissAnimation) && char.hasMissAnimations)
		{
			var suffix:String = '';
			if (note != null)
				suffix = note.animSuffix;

			var animToPlay:String = singAnimations[Std.int(Math.abs(Math.min(singAnimations.length - 1, direction)))] + 'miss' + suffix;
			char.playAnim(animToPlay, true);

			if (char != gf && lastCombo > 5 && gf != null && gf.animOffsets.exists('sad'))
			{
				gf.playAnim('sad');
				gf.specialAnim = true;
			}
		}
		@:privateAccess
		if (char == dad && opponentVocals._sound != null)
			opponentVocals.volume = 0;
		else
			vocals.volume = 0;
	}

	function opponentNoteHit(note:Note):Void
	{
		final args:Array<Dynamic> = [
			notes.members.indexOf(note),
			Math.abs(note.noteData),
			note.noteType,
			note.isSustainNote
		];
		callOnLuas('opponentNoteHitPre', args);
		callOnHScript('opponentNoteHitPre', [note]);

		camZooming = true;

		var char:Character = (!characterPlayingAsDad) ? dad : boyfriend;

		if (note.noteType == 'Hey!' && char.animOffsets.exists('hey'))
		{
			char.playAnim('hey', true);
			char.specialAnim = true;
			char.heyTimer = 0.6;
		}
		else if (!note.noAnimation)
		{
			var altAnim:String = note.animSuffix;

			if (SONG.notes[curSection] != null)
				if (SONG.notes[curSection].altAnim && !SONG.notes[curSection].gfSection)
					altAnim = '-alt';

			var animToPlay:String = singAnimations[Std.int(Math.abs(Math.min(singAnimations.length - 1, note.noteData)))] + altAnim;
			if (note.gfNote)
				char = gf;

			if (char != null)
			{
				char.playAnim(animToPlay, true);
				char.holdTimer = 0;
			}
		}
		@:privateAccess
		if (char == dad && opponentVocals._sound != null)
			opponentVocals.volume = 1;
		else
			vocals.volume = 1;

		strumPlayAnim(true, Std.int(Math.abs(note.noteData)), Conductor.stepCrochet * 1.25 / 1000 / playbackRate);
		note.hitByOpponent = true;

		final args2:Array<Dynamic> = [
			notes.members.indexOf(note),
			Math.abs(note.noteData),
			note.noteType,
			note.isSustainNote
		];
		callOnLuas('opponentNoteHit', args2);
		callOnHScript('opponentNoteHit', [note]);

		spawnHoldSplashOnNote(note);

		if (!note.isSustainNote)
			invalidateNote(note);
	}

	public function goodNoteHit(note:Note):Void
	{
		if (note.wasGoodHit)
			return;
		if (cpuControlled && note.ignoreNote)
			return;

		if (!note.noMissAnimation)
		{
			switch (note.noteType)
			{
				case 'Hurt Note': // Hurt note
					if (boyfriend.animOffsets.exists('hurt'))
					{
						boyfriend.playAnim('hurt', true);
						boyfriend.specialAnim = true;
					}
			}
		}

		var isSus:Bool = note.isSustainNote; // GET OUT OF MY HEAD, GET OUT OF MY HEAD, GET OUT OF MY HEAD
		var leData:Int = Math.round(Math.abs(note.noteData));
		var leType:String = note.noteType;
		var char:Character = (!characterPlayingAsDad) ? boyfriend : dad;

		final args:Array<Dynamic> = [notes.members.indexOf(note), leData, leType, isSus];
		callOnLuas('goodNoteHitPre', args);
		callOnHScript('goodNoteHitPre', [note]);

		note.wasGoodHit = true;

		if (ClientPrefs.data.hitsoundVolume > 0 && !note.hitsoundDisabled)
		{
			hitsoundSound = FlxG.sound.play(Paths.sound(note.hitsound), ClientPrefs.data.hitsoundVolume);
			if (hitsoundSound != null)
				hitsoundSound.pitch = playbackRate;
		}

		if (note.hitCausesMiss)
		{
			noteMiss(note);
			if (!note.noteSplashData.disabled && !note.isSustainNote)
				spawnNoteSplashOnNote(note);
			if (!note.isSustainNote)
				invalidateNote(note);
			return;
		}

		if (!note.noAnimation)
		{
			var animToPlay:String = singAnimations[Std.int(Math.abs(Math.min(singAnimations.length - 1, note.noteData)))];

			var animCheck:String = 'hey';
			if (note.gfNote)
			{
				char = gf;
				animCheck = 'cheer';
			}

			if (char != null)
			{
				char.playAnim(animToPlay + note.animSuffix, true);
				char.holdTimer = 0;

				if (note.noteType == 'Hey!')
				{
					if (char.animOffsets.exists(animCheck))
					{
						char.playAnim(animCheck, true);
						char.specialAnim = true;
						char.heyTimer = 0.6;
					}
				}
			}
		}

		if (!cpuControlled)
		{
			var spr = playerStrums.members[note.noteData];
			if (spr != null)
				spr.playAnim('confirm', true);
		}
		else
			strumPlayAnim(false, Std.int(Math.abs(note.noteData)), Conductor.stepCrochet * 1.25 / 1000 / playbackRate);
		@:privateAccess
		if (char == dad && opponentVocals._sound != null)
			opponentVocals.volume = 1;
		else
			vocals.volume = 1;

		var noteDiff:Float = Math.abs(note.strumTime - Conductor.songPosition + ClientPrefs.data.ratingOffset);
		var array = [note.strumTime, note.sustainLength, note.noteData, noteDiff];
		if (note.isSustainNote)
			array[1] = -1;

		if (!note.isSustainNote)
		{
			++combo;
			if (maxCombo < combo)
				++maxCombo;
			//if (combo > 9999)
			//	combo = 9999;
			popUpScore(note);

			for (i in anas)
				if (i != null)
					anaArray.push(i); // put em all there
			songSaveNotes.push(array);
			songJudges.push(note.rating);
		}
		var gainHealth:Bool = true; // prevent health gain, *if* sustains are treated as a singular note
		if (guitarHeroSustains && note.isSustainNote)
			gainHealth = false;
		if (gainHealth)
			health += note.hitHealth * healthGain;

		if (note.isSustainNote && !cpuControlled)
			songScore += Rating.SUSTAIN_SCORE;

		final args:Array<Dynamic> = [notes.members.indexOf(note), leData, leType, isSus];
		callOnLuas('goodNoteHit', args);
		callOnHScript('goodNoteHit', [note]);

		if (!note.isSustainNote && !cpuControlled)
			doScoreBop();

		spawnHoldSplashOnNote(note);

		if (!note.isSustainNote)
			invalidateNote(note);
	}

	public function invalidateNote(note:Note):Void
	{
		if (!ClientPrefs.data.lowQuality || !ClientPrefs.data.popUpRating || !cpuControlled)
			note.kill();
		notes.remove(note, true);
		note.recycle();
	}

	public function spawnHoldSplashOnNote(note:Note)
	{
		if (note == null)
			return;

		if (note.tail.length > 0 && !note.isSustainNote)
		{
			var lastSustain:Note = note.tail[note.tail.length - 1];
			var strumNote:StrumNote = note.mustPress ? playerStrums.members[note.noteData] : opponentStrums.members[note.noteData];
			SustainSplash.generateSustainSplash(strumNote, lastSustain.strumTime, note.mustPress);
		}
		else if(note.isSustainNote && note.parent != null && note.parent.tail.length > 0 && !SustainSplash.hasSplashAtData(note.noteData, note.mustPress))
		{
			var lastSustain:Note = note.parent.tail[note.parent.tail.length - 1];
			var strumNote:StrumNote = note.mustPress ? playerStrums.members[note.noteData] : opponentStrums.members[note.noteData];
			SustainSplash.generateSustainSplash(strumNote, lastSustain.strumTime, note.mustPress);
		}
	}

	public function spawnNoteSplashOnNote(note:Note)
	{
		if (note != null)
		{
			var strum:StrumNote = playerStrums.members[note.noteData];
			if (strum != null)
				spawnNoteSplash(strum.x, strum.y, note.noteData, note);
		}
	}

	public function spawnNoteSplash(x:Float, y:Float, data:Int, ?note:Note = null)
	{
		var splash:NoteSplash = grpNoteSplashes.recycle(NoteSplash);
		splash.setupNoteSplash(x, y, data, note);
		grpNoteSplashes.add(splash);
	}

	override function destroy()
	{
		instance = null;

		FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, onKeyRelease);

		FlxG.animationTimeScale = 1;

		NoteSplash.mainGroup = null;
		NoteSplash.usePixelTextures = StrumNote.usePixelTextures = Note.usePixelTextures = null;
		Note.globalRgbShaders = [];
		SustainSplash.close();
		backend.NoteTypesConfig.clearNoteTypesData();

		@:privateAccess
		FlxG.game._filters = [];
		camGame.filters = camHUD.filters = camOther.filters = [];

		#if (target.threaded)
		shutdownThread = true;
		FlxG.signals.preUpdate.remove(checkForResync);
		#end

		FlxG.sound.music.pitch = 1;

		#if FEATURE_VIDEOS
		if (videoCutscene != null)
		{
			videoCutscene.destroy();
			videoCutscene = null;
		}
		#end

		super.destroy();
	}

	var lastStepHit:Int = -1;

	override function stepHit()
	{
		if (SONG.needsVoices && FlxG.sound.music.time >= -ClientPrefs.data.noteOffset)
		{
			final timeSub:Float = Conductor.songPosition - Conductor.offset;
			#if mobile
			final syncTime:Float = 75 * playbackRate;
			#else
			final syncTime:Float = 20 * playbackRate;
			#end
			@:privateAccess
			if (Math.abs(FlxG.sound.music.time - timeSub) > syncTime || Math.abs(vocals.time - timeSub) > syncTime || (opponentVocals._sound != null && opponentVocals.playing && Math.abs(opponentVocals.time - timeSub) > syncTime))
				resyncVocals();
		}

		super.stepHit();

		if (curStep == lastStepHit)
		{
			return;
		}

		lastStepHit = curStep;
	}

	var lastBeatHit:Int = -1;

	override function beatHit()
	{
		if (lastBeatHit >= curBeat)
		{
			// trace('BEAT HIT: ' + curBeat + ', LAST HIT: ' + lastBeatHit);
			return;
		}

		if (camZooming && FlxG.camera.zoom < 1.35 && ClientPrefs.data.camZooms && (curBeat % camZoomingFrequency) == 0)
		{
			FlxG.camera.zoom += 0.015 * camZoomingMult;
			camHUD.zoom += 0.03 * camZoomingMult;
		}

		if (generatedMusic)
			notes.sort(FlxSort.byY, ClientPrefs.data.downScroll ? FlxSort.ASCENDING : FlxSort.DESCENDING);

		iconP1.scale.set(1.2, 1.2);
		iconP2.scale.set(1.2, 1.2);

		iconP1.updateHitbox();
		iconP2.updateHitbox();

		characterBopper(curBeat);

		super.beatHit();
		lastBeatHit = curBeat;
	}

	public function characterBopper(beat:Int):Void
	{
		var charBf:Character = (!characterPlayingAsDad) ? boyfriend : dad;
		var charDad:Character = (!characterPlayingAsDad) ? dad : boyfriend;
		if (gf != null
			&& beat % Math.round(gfSpeed * gf.danceEveryNumBeats) == 0
			&& !gf.getAnimationName().startsWith('sing')
			&& !gf.stunned)
			gf.dance();
		if (boyfriend != null
			&& beat % charBf.danceEveryNumBeats == 0
			&& !boyfriend.getAnimationName().startsWith('sing')
			&& !charBf.stunned)
			boyfriend.dance();
		if (dad != null && beat % charDad.danceEveryNumBeats == 0 && !dad.getAnimationName().startsWith('sing') && !charDad.stunned)
			dad.dance();
	}

	public function playerDance():Void
	{
		var char:Character = (!characterPlayingAsDad) ? boyfriend : dad;
		var anim:String = char.getAnimationName();
		if (char.holdTimer > Conductor.stepCrochet * (0.0011 / FlxG.sound.music.pitch) * char.singDuration && anim.startsWith('sing')
			&& !anim.endsWith('miss'))
			char.dance();
	}

	override function sectionHit()
	{
		if (SONG.notes[curSection] != null)
		{
			if (generatedMusic && !endingSong && !isCameraOnForcedPos)
				moveCameraSection();

			final vsliceCondition:Bool = (curBeat % camZoomingFrequency) == 0;
			if (camZooming && FlxG.camera.zoom < 1.35 && ClientPrefs.data.camZooms && !vsliceCondition)
			{
				FlxG.camera.zoom += 0.015 * camZoomingMult;
				camHUD.zoom += 0.03 * camZoomingMult;
			}

			if (SONG.notes[curSection].changeBPM)
			{
				Conductor.bpm = SONG.notes[curSection].bpm;
				setOnScripts('curBpm', Conductor.bpm);
				setOnScripts('crochet', Conductor.crochet);
				setOnScripts('stepCrochet', Conductor.stepCrochet);
			}
			setOnScripts('mustHitSection', SONG.notes[curSection].mustHitSection);
			setOnScripts('altAnim', SONG.notes[curSection].altAnim);
			setOnScripts('gfSection', SONG.notes[curSection].gfSection);
		}
		super.sectionHit();
	}

	function strumPlayAnim(isDad:Bool, id:Int, time:Float)
	{
		var spr:StrumNote = null;
		if (isDad)
		{
			spr = opponentStrums.members[id];
		}
		else
		{
			spr = playerStrums.members[id];
		}

		if (spr != null)
		{
			spr.playAnim('confirm', true);
			spr.resetAnim = time;
		}
	}

	public var ratingName:String = '?';
	public var ratingPercent:Float;
	public var ratingFC:String;

	public function recalculateRating()
	{
		setOnScripts('score', songScore);
		setOnScripts('misses', songMisses);
		setOnScripts('hits', songHits);
		setOnScripts('combo', combo);

		var ret:Dynamic = callOnScripts('onRecalculateRating', null, true);
		if (ret != ScriptResult.Stop)
		{
			ratingName = '?';
			if (totalPlayed != 0) // Prevent divide by 0
			{
				// Rating Percent
				ratingPercent = Math.min(1, Math.max(0, totalNotesHit / totalPlayed));
				// trace((totalNotesHit / totalPlayed) + ', Total: ' + totalPlayed + ', notes hit: ' + totalNotesHit);

				// Rating Name
				ratingName = ratingStuff[ratingStuff.length - 1][0]; // Uses last string
				if (ratingPercent < 1)
					for (i in 0...ratingStuff.length - 1)
						if (ratingPercent < ratingStuff[i][1])
						{
							ratingName = ratingStuff[i][0];
							break;
						}
			}
			fullComboFunction();
		}
		updateScore(); // score will only update after rating is calculated, if it's a badHit, it shouldn't bounce
		setOnScripts('rating', ratingPercent);
		setOnScripts('ratingName', ratingName);
		setOnScripts('ratingFC', ratingFC);
	}

	public var runtimeShaders:Map<String, Array<String>> = new Map<String, Array<String>>();

	public function createRuntimeShader(name:String):FlxRuntimeShader
	{
		if (!ClientPrefs.data.shaders)
			return new FlxRuntimeShader();

		if (!runtimeShaders.exists(name) && !initLuaShader(name))
		{
			FlxG.log.warn('Shader $name is missing!');
			return new FlxRuntimeShader();
		}

		var arr:Array<String> = runtimeShaders.get(name);
		return new FlxRuntimeShader(arr[0], arr[1]);
	}

	public function initLuaShader(name:String):Bool
	{
		if (!ClientPrefs.data.shaders)
			return false;

		if (runtimeShaders.exists(name))
		{
			FlxG.log.warn('Shader $name was already initialized!');
			return true;
		}

		var folders:Array<String> = [];
		#if FEATURE_MODS
		if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
			folders.push(Paths.mods(Mods.currentModDirectory + '/shaders/'));
		for (mod in Mods.getGlobalMods())
			folders.push(Paths.mods(mod + '/shaders/'));
		#end
		folders.push(Paths.getSharedPath('shaders/'));

		for (folder in folders)
		{
			if (!FileSystem.exists(folder))
				continue;

			var fragPath = folder + name + '.frag';
			var vertPath = folder + name + '.vert';

			var frag:String = null;
			var vert:String = null;
			var found:Bool = false;

			if (FileSystem.exists(fragPath))
			{
				frag = File.getContent(fragPath);
				found = true;
			}

			if (FileSystem.exists(vertPath))
			{
				vert = File.getContent(vertPath);
				found = true;
			}

			if (found)
			{
				runtimeShaders.set(name, [frag, vert]);
				return true;
			}
		}

		#if (FEATURE_LUA || FEATURE_HSCRIPT)
		addTextToDebug('Missing shader $name .frag AND .vert files!', FlxColor.RED);
		#else
		FlxG.log.warn('Missing shader $name .frag AND .vert files!');
		#end

		return false;
	}

	public function changeNoteSkin(player:Bool, skin:String)
	{
		if (!player)
		{
			if (skin != null || skin != '')
			{
				noteSkin1 = skin;
				opponentStrums.forEachExists(function(strumNote:StrumNote)
				{
					strumNote.texture = skin;
				});
				notes.forEachExists(function(note:Note)
				{
					if (!note.mustPress && allowedNotes.contains(note.noteType))
						note.texture = skin;
				});
			}
			#if (FEATURE_LUA || FEATURE_HSCRIPT)
			else
				addTextToDebug("ERROR!! couldn't change opponent note skin because the inserted value is null.", FlxColor.RED);
			#end
		}
		if (player)
		{
			if (skin != null || skin != '')
			{
				noteSkin = skin;
				playerStrums.forEachExists(function(strumNote:StrumNote)
				{
					strumNote.texture = skin;
				});
				notes.forEachExists(function(note:Note)
				{
					if (note.mustPress && allowedNotes.contains(note.noteType))
						note.texture = skin;
				});
			}
			#if (FEATURE_LUA || FEATURE_HSCRIPT)
			else
				addTextToDebug("ERROR!! couldn't change player note skin because the inserted value is null.", FlxColor.RED);
			#end
		}
	}

	public function changeSustainSplashSkin(player:Bool, skin:String)
	{
		if (skin == null || skin == '')
		{
			#if (FEATURE_LUA || FEATURE_HSCRIPT)
			addTextToDebug("ERROR!! couldn't change sustain splash skin because the inserted value is null.", FlxColor.RED);
			#end
			return;
		}

		if (player)
			SustainSplash.playerTexture = skin;
		else
			SustainSplash.opponentTexture = skin;

		@:privateAccess
		SustainSplash.mainGroup.forEachExists(function(splash:SustainSplash)
		{
			if (splash.mustPress == player)
				splash.reloadSustainSplash(SustainSplash.getTextureNameFromData(splash.noteData, splash.mustPress));
		});
	}

	public static function judgeNote(noteDiff:Float)
	{
		var diff = Math.abs(noteDiff);
		var timingWindows = [ClientPrefs.data.badWindow, ClientPrefs.data.goodWindow, ClientPrefs.data.sickWindow];
		for (index in 0...timingWindows.length) // based on 4 timing windows, will break with anything else
		{
			var time = timingWindows[index];
			var nextTime = index + 1 > timingWindows.length - 1 ? 0 : timingWindows[index + 1];
			if (diff < time && diff >= nextTime)
			{
				switch (index)
				{
					case 0: // bad
						return "bad";
					case 1: // good
						return "good";
					case 2: // sick
						return "sick";
				}
			}
		}
		return "good";
	}

	#if (target.threaded)
	function checkForResync()
	{
		if (endingSong || paused || shutdownThread)
			return;

		syncMutex.acquire();
		try
		{
			if (requiresSyncing)
			{
				requiresSyncing = false;
				setSongTime(lastCorrectSongPos);
			}

			gameFroze = false;
		}
		catch (e:Dynamic)
		{
			trace('Error during resync: $e');
		}
		syncMutex.release();
	}

	public function runSongSyncThread()
	{
		if (syncMutex == null)
			syncMutex = new Mutex();

		Thread.create(function()
		{
			try
			{
				while (!endingSong && !paused && !shutdownThread)
				{
					syncMutex.acquire();
					var shouldContinue:Bool = !requiresSyncing;
					syncMutex.release();

					if (!shouldContinue)
					{
						Sys.sleep(0.01);
						continue;
					}

					syncMutex.acquire();
					gameFroze = true;
					syncMutex.release();

					Sys.sleep(0.25);

					syncMutex.acquire();
					if (gameFroze && !shutdownThread)
					{
						lastCorrectSongPos = Conductor.songPosition;
						requiresSyncing = true;
					}
					syncMutex.release();
				}
			}
			catch (e:Dynamic)
			{
				trace('Song sync thread error: $e');
			}
		});

		if (!FlxG.signals.preUpdate.has(checkForResync))
			FlxG.signals.preUpdate.add(checkForResync);
	}
	#end
}
