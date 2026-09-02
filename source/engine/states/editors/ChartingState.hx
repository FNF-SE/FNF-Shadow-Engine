package states.editors;

import haxe.format.JsonParser;
import haxe.io.Bytes;
import haxe.io.Path;
import flixel.FlxCamera;
import flixel.FlxObject;
import flixel.addons.display.FlxGridOverlay;
import flixel.group.FlxGroup;
import flixel.util.FlxSort;
import lime.media.AudioBuffer;
import openfl.utils.Assets;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.media.Sound;
import openfl.geom.Rectangle;
import openfl.net.FileReference;
import backend.Song;
import backend.Section;
import backend.StageData;
import states.FreeplayState;
import objects.Note;
import objects.StrumNote;
import objects.NoteSplash;
import objects.HealthIcon;
import objects.AttachedSprite;
import objects.Character;
import substates.Prompt;

@:access(flixel.sound.FlxSound._sound)
@:access(openfl.media.Sound.__buffer)
class ChartingState extends MusicBeatState
{
	public static var noteTypeList:Array<String> = // Used for backwards compatibility with 0.1 - 0.3.2 charts, though, you should add your hardcoded custom note types here too.
		['', 'Alt Animation', 'Hey!', 'Hurt Note', 'GF Sing', 'No Animation'];

	public var ignoreWarnings:Bool = false;

	var curNoteTypes:Array<String> = [];
	var undos = [];
	var redos = [];
	var eventStuff:Array<Dynamic> = [
		[
			'',
			"Nothing. Yep, that's right."
		],
		[
			'Hey!',
			"Plays the \"Hey!\" animation from Bopeebo,\nValue 1: BF = Only Boyfriend, GF = Only Girlfriend,\nSomething else = Both.\nValue 2: Custom animation duration,\nleave it blank for 0.6s"
		],
		[
			'Set GF Speed',
			"Sets GF head bopping speed,\nValue 1: 1 = Normal speed,\n2 = 1/2 speed, 4 = 1/4 speed etc.\nUsed on Fresh during the beatbox parts.\n\nWarning: Value must be integer!"
		],
		[
			'Add Camera Zoom',
			"Used on MILF on that one \"hard\" part\nValue 1: Camera zoom add (Default: 0.015)\nValue 2: UI zoom add (Default: 0.03)\nLeave the values blank if you want to use Default."
		],
		[
			'Play Animation',
			"Plays an animation on a Character,\nonce the animation is completed,\nthe animation changes to Idle\n\nValue 1: Animation to play.\nValue 2: Character (Dad, BF, GF)"
		],
		[
			'Camera Follow Pos',
			"Value 1: X\nValue 2: Y\n\nThe camera won't change the follow point\nafter using this, for getting it back\nto normal, leave both values blank."
		],
		[
			'Alt Idle Animation',
			"Sets a specified postfix after the idle animation name.\nYou can use this to trigger 'idle-alt' if you set\nValue 2 to -alt\n\nValue 1: Character to set (Dad, BF or GF)\nValue 2: New postfix (Leave it blank to disable)"
		],
		[
			'Screen Shake',
			"Value 1: Camera shake\nValue 2: HUD shake\n\nEvery value works as the following example: \"1, 0.05\".\nThe first number (1) is the duration.\nThe second number (0.05) is the intensity."
		],
		[
			'Change Character',
			"Value 1: Character to change (Dad, BF, GF)\nValue 2: New character's name"
		],
		[
			'Change Scroll Speed',
			"Value 1: Scroll Speed Multiplier (1 is default)\nValue 2: Time it takes to change fully in seconds."
		],
		[
			'Set Property',
			"Value 1: Variable name\nValue 2: New value"
		],
		[
			'Play Sound',
			"Value 1: Sound file name\nValue 2: Volume (Default: 1), ranges from 0 to 1"
		],
		[
			'Set Camera Bopping',
			"Sets how camera should bop.\nValue 1: Frequency (in beats)\nValue 2: Intensity scale (1 for default)"
		],
		[
			'Zoom Camera',
			"An attempt to emulate V-slice camera zoom.\nNot really accurate, but oh well.\n\nValue 1: Zoom length (in steps) and zoom scale.\n[separated with ',']\n\nValue 2: Zooming ease"
		],
		[
			'Focus Camera',
			"Focus camera on the specific point.\nThis will also lock the camera (like Camera Follow Pos)\n\nValue1:character to focus\nValue2: separated with ',' x, y, duration, ease"
		],
		[
			'Dadbattle Spotlight',
			"Exclusive to Week 1's \"stage\" (and its Erect variant).\n\nValue 1: Spotlight to target\n(Dad, BF, GF, BG, Smoke)\nNote: it won't disable the other spotlights\nunless you set their Value 2 alpha too.\n\nValue 2: separated with ',' Alpha, Duration (in steps), Ease\nLeave the ease blank (or \"classic\") to change instantly."
		]
	];

	var _file:FileReference;

	var UI_box:ShadowTabMenu;
	var UI_help:ShadowPanel;
	var UI_helpOverlay:FlxSprite;
	var UI_infoPanel:ShadowPanel;

	private var camMain:ShadowCamera;
	private var camOther:ShadowCamera;

	public static var goToPlayState:Bool = false;

	/**
	 * Array of notes showing when each section STARTS in STEPS
	 * Usually rounded up??
	 */
	public static var curSec:Int = 0;

	public static var lastSection:Int = 0;
	private static var lastSong:String = '';

	var bpmTxt:FlxText;

	var camPos:FlxObject;
	var strumLine:FlxSprite;
	var quant:AttachedSprite;
	var strumLineNotes:FlxTypedGroup<StrumNote>;
	var curSong:String = 'Test';
	var amountSteps:Int = 0;
	var bullshitUI:FlxGroup;

	var highlight:FlxSprite;

	public static var GRID_SIZE:Int = 40;

	var CAM_OFFSET:Int = 360;

	var dummyArrow:FlxSprite;

	var curRenderedSustains:FlxTypedGroup<FlxSprite>;
	var curRenderedNotes:FlxTypedGroup<Note>;
	var curRenderedNoteType:FlxTypedGroup<FlxText>;

	var nextRenderedSustains:FlxTypedGroup<FlxSprite>;
	var nextRenderedNotes:FlxTypedGroup<Note>;

	var gridBG:FlxSprite;
	var nextGridBG:FlxSprite;

	var curEventSelected:Int = 0;
	var _song:SwagSong;
	/*
	 * WILL BE THE CURRENT / LAST PLACED NOTE
	**/
	var curSelectedNote:Array<Dynamic> = null;

	var playbackSpeed:Float = 1;

	var vocals:FlxSound = null;
	var opponentVocals:FlxSound = null;

	var leftIcon:HealthIcon;
	var rightIcon:HealthIcon;

	var value1InputText:ShadowTextInput;
	var value2InputText:ShadowTextInput;
	var currentSongName:String;

	var zoomTxt:FlxText;

	var zoomList:Array<Float> = [0.25, 0.5, 1, 2, 3, 4, 6, 8, 12, 16, 24];
	var curZoom:Int = 2;

	var waveformSprite:FlxSprite;
	var gridLayer:FlxTypedGroup<FlxSprite>;
	var blockPressWhileTypingOn:Array<ShadowInputText> = [];

	function registerBlockerInput(input:ShadowTextInput):Void
	{
		if (input == null || input.input == null)
			return;
		if (blockPressWhileTypingOn.indexOf(input.input) == -1)
			blockPressWhileTypingOn.push(input.input);
	}

	function isEditorInputBlocked():Bool
	{
		if (ShadowDropdown.isAnyOpen() || ShadowDropdown.isClickCaptured())
			return true;
		for (inputText in blockPressWhileTypingOn)
			if (inputText != null && inputText.hasFocus)
				return true;
		return false;
	}

	public static var quantization:Int = 16;
	public static var curQuant:Int = 3;

	public var quantizations:Array<Int> = [4, 8, 12, 16, 20, 24, 32, 48, 64, 96, 192];

	public static var vortex:Bool = false;

	public var mouseQuant:Bool = false;

	private final isDiffErect:Bool = Difficulty.getByIndex(PlayState.storyDifficulty) == ERECT || Difficulty.getByIndex(PlayState.storyDifficulty) == NIGHTMARE;

	override function create()
	{
		if (PlayState.SONG != null)
			_song = PlayState.SONG;
		else
		{
			Difficulty.resetList();
			_song = {
				song: 'Test',
				notes: [],
				events: [],
				bpm: 150.0,
				needsVoices: true,
				player1: 'bf',
				player2: 'dad',
				gfVersion: 'gf',
				speed: 1,
				stage: 'stage'
			};
			addSection();
			PlayState.SONG = _song;
		}

		#if FEATURE_DISCORD_RPC
		// Updating Discord Rich Presence
		DiscordClient.changePresence("Chart Editor", StringTools.replace(_song.song, '-', ' '));
		#end

		camMain = initPsychCamera();

		vortex = FlxG.save.data.chart_vortex;
		ignoreWarnings = FlxG.save.data.ignoreWarnings;
		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.scrollFactor.set();
		bg.color = 0xFF222222;
		add(bg);

		gridLayer = new FlxTypedGroup<FlxSprite>();
		add(gridLayer);

		waveformSprite = new FlxSprite(GRID_SIZE, 0).makeGraphic(1, 1, 0x00FFFFFF);
		add(waveformSprite);

		var eventIcon:FlxSprite = new FlxSprite(-GRID_SIZE - 5, -90).loadGraphic(Paths.image('eventArrow'));
		eventIcon.antialiasing = ClientPrefs.data.antialiasing;
		leftIcon = new HealthIcon('bf');
		rightIcon = new HealthIcon('dad');
		eventIcon.scrollFactor.set(1, 1);
		leftIcon.scrollFactor.set(1, 1);
		rightIcon.scrollFactor.set(1, 1);

		eventIcon.setGraphicSize(30, 30);
		leftIcon.setGraphicSize(0, 45);
		rightIcon.setGraphicSize(0, 45);

		add(eventIcon);
		add(leftIcon);
		add(rightIcon);

		leftIcon.setPosition(GRID_SIZE + 10, -100);
		rightIcon.setPosition(GRID_SIZE * 5.2, -100);

		curRenderedSustains = new FlxTypedGroup<FlxSprite>();
		curRenderedNotes = new FlxTypedGroup<Note>();
		curRenderedNoteType = new FlxTypedGroup<FlxText>();

		nextRenderedSustains = new FlxTypedGroup<FlxSprite>();
		nextRenderedNotes = new FlxTypedGroup<Note>();

		FlxG.mouse.visible = true;
		// FlxG.save.bind('funkin', CoolUtil.getSavePath());

		// addSection();

		// sections = _song.notes;

		updateJsonData();
		editorPlayerArrowSkin = (_song.playerArrowSkin != null) ? _song.playerArrowSkin : '';
		editorOpponentArrowSkin = (_song.opponentArrowSkin != null) ? _song.opponentArrowSkin : '';
		currentSongName = Paths.formatToSongPath(_song.song);
		loadSong();
		reloadGridLayer();
		Conductor.bpm = _song.bpm;
		Conductor.mapBPMChanges(_song);
		if (curSec >= _song.notes.length)
			curSec = _song.notes.length - 1;

		strumLine = new FlxSprite(0, 50).makeGraphic(Std.int(GRID_SIZE * 9), 4);
		add(strumLine);

		quant = new AttachedSprite('chart_quant', 'chart_quant');
		quant.animation.addByPrefix('q', 'chart_quant', 0, false);
		quant.animation.play('q', true, false, 0);
		quant.sprTracker = strumLine;
		quant.xAdd = -32;
		quant.yAdd = 8;
		add(quant);

		strumLineNotes = new FlxTypedGroup<StrumNote>();
		for (i in 0...8)
		{
			var note:StrumNote = new StrumNote(GRID_SIZE * (i + 1), strumLine.y, i % 4, 0, null);
			note.setGraphicSize(GRID_SIZE, GRID_SIZE);
			note.updateHitbox();
			note.playAnim('static', true);
			strumLineNotes.add(note);
			note.scrollFactor.set(1, 1);
		}
		add(strumLineNotes);

		camPos = new FlxObject(0, 0, 1, 1);
		camPos.setPosition(strumLine.x + CAM_OFFSET, strumLine.y);

		dummyArrow = new FlxSprite().makeGraphic(GRID_SIZE, GRID_SIZE);
		dummyArrow.antialiasing = ClientPrefs.data.antialiasing;
		add(dummyArrow);

		var infoPanelW:Int = 200;
		var infoPanelH:Int = 150;
		UI_infoPanel = new ShadowPanel(ShadowStyle.SPACING_LG, ShadowStyle.SPACING_LG, infoPanelW, infoPanelH);
		UI_infoPanel.scrollFactor.set();

		zoomTxt = new FlxText(ShadowStyle.SPACING_SM, ShadowStyle.SPACING_SM, infoPanelW - ShadowStyle.SPACING_SM * 2, "Zoom: 1 / 1", 16);
		zoomTxt.setFormat(Paths.font(ShadowStyle.FONT_DEFAULT), ShadowStyle.FONT_SIZE_MD, ShadowStyle.TEXT_PRIMARY);
		zoomTxt.scrollFactor.set();
		UI_infoPanel.add(zoomTxt);

		bpmTxt = new FlxText(ShadowStyle.SPACING_SM, ShadowStyle.SPACING_SM + 26, infoPanelW - ShadowStyle.SPACING_SM * 2, "", 16);
		bpmTxt.setFormat(Paths.font(ShadowStyle.FONT_DEFAULT), ShadowStyle.FONT_SIZE_LG, ShadowStyle.TEXT_SECONDARY);
		bpmTxt.scrollFactor.set();
		UI_infoPanel.add(bpmTxt);

		var tabs:Array<TabDef> = [
			{name: "Song", label: 'Song'},
			{name: "Section", label: 'Section'},
			{name: "Note", label: 'Note'},
			{name: "Events", label: 'Events'},
			{name: "Charting", label: 'Charting'},
			{name: "Data", label: 'Data'},
		];

		var tabMenuW:Int = 380;
		var tabMenuH:Int = 400;
		UI_box = new ShadowTabMenu(0, 0, tabs, tabMenuW, tabMenuH);
		UI_box.x = FlxG.width - tabMenuW - ShadowStyle.SPACING_LG;
		UI_box.y = ShadowStyle.SPACING_LG;
		UI_box.scrollFactor.set();

		UI_infoPanel.x = (FlxG.width - UI_infoPanel.width - UI_box.width) - (ShadowStyle.SPACING_LG * 2);

		var tipText:FlxText = new FlxText(FlxG.width - 300, FlxG.height - 24, 300, 'Press ${(Funkin.controls.mobileC) ? "F" : "F1"} for Help', 16);
		tipText.setFormat(null, 16, FlxColor.WHITE, RIGHT, OUTLINE_FAST, FlxColor.BLACK);
		tipText.borderColor = FlxColor.BLACK;
		tipText.scrollFactor.set();
		tipText.borderSize = 1;
		tipText.active = false;

		addSongUI();
		addSectionUI();
		addNoteUI();
		addEventsUI();
		addChartingUI();
		addDataUI();
		makeHelpUI();
		updateHeads();
		updateWaveform();
		// UI_box.selected_tab = 4;

		add(curRenderedSustains);
		add(curRenderedNotes);
		add(curRenderedNoteType);
		add(nextRenderedSustains);
		add(nextRenderedNotes);

		
		add(UI_box);

		// RAAAHH ⚔💀🛡 -- mrchaoss
		add(UI_infoPanel);
		add(tipText);

		if (lastSong != currentSongName)
		{
			changeSection();
		}
		lastSong = currentSongName;

		updateGrid();

		#if FEATURE_MOBILE_CONTROLS
		addTouchPad("LEFT_FULL", "CHART_EDITOR");
		#end

		super.create();
	}

	var check_mute_inst:ShadowCheckbox = null;
	var check_mute_vocals:ShadowCheckbox = null;
	var check_mute_vocals_opponent:ShadowCheckbox = null;
	var check_vortex:ShadowCheckbox = null;
	var check_warnings:ShadowCheckbox = null;
	var playSoundBf:ShadowCheckbox = null;
	var playSoundDad:ShadowCheckbox = null;
	var UI_songTitle:ShadowTextInput;
	var stageDropDown:ShadowDropdown;
	var sliderRate:ShadowSlider;

	var stepperBPM:ShadowStepper;
	var stepperSpeed:ShadowStepper;
	var characters:Array<String> = [];
	var stageList:Array<String> = [];

	function addSongUI():Void
	{
		var tab_group:FlxSpriteGroup = UI_box.getTabGroup("Song");
		if (tab_group == null)
			return;

		var pad:Int = ShadowStyle.SPACING_MD;
		var rowGap:Int = ShadowStyle.SPACING_SM;
		var labelOffset:Int = ShadowStyle.FONT_SIZE_SM + 4;
		var rowStep:Int = labelOffset + ShadowStyle.HEIGHT_INPUT + rowGap;
		var buttonWidth:Int = 80;
		var buttonGap:Int = ShadowStyle.SPACING_SM;
		var dropdownWidth:Int = 120;

		// Build character list
		var directories:Array<String> = [];
		#if FEATURE_MODS
		if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
			directories.push(Paths.mods(Mods.currentModDirectory + '/characters/'));
		for (mod in Mods.getGlobalMods())
			directories.push(Paths.mods(mod + '/characters/'));
		directories.push(Paths.getSharedPath('characters/'));
		#else
		directories.push(Paths.getSharedPath('characters/'));
		#end

		var tempArray:Array<String> = [];
		characters = Mods.mergeAllTextsNamed('data/characterList.txt', Paths.getSharedPath());
		for (character in characters)
		{
			if (character.trim().length > 0)
				tempArray.push(character);
		}

		for (i in 0...directories.length)
		{
			var directory:String = directories[i];
			if (FileSystem.exists(directory))
			{
				for (file in FileSystem.readDirectory(directory))
				{
					var path:String = Path.join([directory, file]);
					if (!FileSystem.isDirectory(path) && file.endsWith('.json'))
					{
						var charToCheck:String = file.substr(0, file.length - 5);
						if (charToCheck.trim().length > 0 && !charToCheck.endsWith('-dead') && !tempArray.contains(charToCheck))
						{
							tempArray.push(charToCheck);
							characters.push(charToCheck);
						}
					}
				}
			}
		}
		tempArray = [];

		// Build stage list
		var stageDirectories:Array<String> = [];
		#if FEATURE_MODS
		if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
			stageDirectories.push(Paths.mods(Mods.currentModDirectory + '/stages/'));
		for (mod in Mods.getGlobalMods())
			stageDirectories.push(Paths.mods(mod + '/stages/'));
		stageDirectories.push(Paths.getSharedPath('stages/'));
		#else
		stageDirectories.push(Paths.getSharedPath('stages/'));
		#end

		var stageFile:Array<String> = Mods.mergeAllTextsNamed('data/stageList.txt', Paths.getSharedPath());
		stageList = [];
		for (stage in stageFile)
		{
			if (stage.trim().length > 0)
			{
				stageList.push(stage);
			}
			tempArray.push(stage);
		}
		for (i in 0...stageDirectories.length)
		{
			var directory:String = stageDirectories[i];
			if (FileSystem.exists(directory))
			{
				for (file in FileSystem.readDirectory(directory))
				{
					var path:String = Path.join([directory, file]);
					if (!FileSystem.isDirectory(path) && file.endsWith('.json'))
					{
						var stageToCheck:String = file.substr(0, file.length - 5);
						if (stageToCheck.trim().length > 0 && !tempArray.contains(stageToCheck))
						{
							tempArray.push(stageToCheck);
							stageList.push(stageToCheck);
						}
					}
				}
			}
		}
		if (stageList.length < 1)
			stageList.push('stage');

		var row0:Int = pad;
		tab_group.add(new ShadowLabel(pad, row0, "Song Title:", ShadowStyle.FONT_SIZE_SM, ShadowStyle.TEXT_SECONDARY));
		UI_songTitle = new ShadowTextInput(pad, row0 + labelOffset, 90, _song.song);
		tab_group.add(UI_songTitle);
		registerBlockerInput(UI_songTitle);

		var saveButton:ShadowButton = new ShadowButton(pad + 95 + buttonGap, row0 + labelOffset, "Save", function()
		{
			saveLevel();
		}, 50);
		tab_group.add(saveButton);

		var reloadSong:ShadowButton = new ShadowButton(saveButton.x + 55, row0 + labelOffset, "Reload Audio", function()
		{
			currentSongName = Paths.formatToSongPath(UI_songTitle.text);
			updateJsonData();
			loadSong();
			updateWaveform();
		}, 80);
		tab_group.add(reloadSong);

		var row1:Int = row0 + rowStep;
		tab_group.add(new ShadowLabel(pad, row1, "BPM:", ShadowStyle.FONT_SIZE_SM, ShadowStyle.TEXT_SECONDARY));
		stepperBPM = new ShadowStepper(pad, row1 + labelOffset, 1, Conductor.bpm, 1, 400, 3, function(value:Float)
		{
			_song.bpm = value;
			Conductor.mapBPMChanges(_song);
			Conductor.bpm = value;
			if (stepperSusLength != null)
				stepperSusLength.step = Math.ceil(Conductor.stepCrochet / 2);
			updateGrid();
		}, 70);
		tab_group.add(stepperBPM);

		tab_group.add(new ShadowLabel(pad + 80, row1, "Speed:", ShadowStyle.FONT_SIZE_SM, ShadowStyle.TEXT_SECONDARY));
		stepperSpeed = new ShadowStepper(pad + 80, row1 + labelOffset, 0.1, _song.speed, 0.1, 10, 2, function(value:Float)
		{
			_song.speed = value;
		}, 60);
		tab_group.add(stepperSpeed);

		var check_voices:ShadowCheckbox = new ShadowCheckbox(pad + 150, row1 + labelOffset + 4, "Voices", _song.needsVoices, function(checked:Bool)
		{
			_song.needsVoices = checked;
		});
		tab_group.add(check_voices);

		var row2:Int = row1 + rowStep;
		tab_group.add(new ShadowLabel(pad, row2, "Boyfriend:", ShadowStyle.FONT_SIZE_SM, ShadowStyle.TEXT_SECONDARY));
		var player1DropDown:ShadowDropdown = new ShadowDropdown(pad, row2 + labelOffset, characters, function(index:Int)
		{
			_song.player1 = characters[index];
			updateJsonData();
			updateHeads();
		}, dropdownWidth);
		player1DropDown.selectedIndex = characters.indexOf(_song.player1);

		tab_group.add(new ShadowLabel(pad + dropdownWidth + pad, row2, "Stage:", ShadowStyle.FONT_SIZE_SM, ShadowStyle.TEXT_SECONDARY));
		stageDropDown = new ShadowDropdown(pad + dropdownWidth + pad, row2 + labelOffset, stageList, function(index:Int)
		{
			_song.stage = stageList[index];
		}, dropdownWidth);
		stageDropDown.selectedIndex = stageList.indexOf(_song.stage);

		var row3:Int = row2 + rowStep;
		tab_group.add(new ShadowLabel(pad, row3, "Girlfriend:", ShadowStyle.FONT_SIZE_SM, ShadowStyle.TEXT_SECONDARY));
		var gfVersionDropDown:ShadowDropdown = new ShadowDropdown(pad, row3 + labelOffset, characters, function(index:Int)
		{
			_song.gfVersion = characters[index];
			updateJsonData();
			updateHeads();
		}, dropdownWidth);
		gfVersionDropDown.selectedIndex = characters.indexOf(_song.gfVersion);

		var row4:Int = row3 + rowStep;
		tab_group.add(new ShadowLabel(pad, row4, "Opponent:", ShadowStyle.FONT_SIZE_SM, ShadowStyle.TEXT_SECONDARY));
		var player2DropDown:ShadowDropdown = new ShadowDropdown(pad, row4 + labelOffset, characters, function(index:Int)
		{
			_song.player2 = characters[index];
			updateJsonData();
			updateHeads();
		}, dropdownWidth);
		player2DropDown.selectedIndex = characters.indexOf(_song.player2);

		var row5:Int = row4 + rowStep;
		var reloadSongJson:ShadowButton = new ShadowButton(pad, row5, "Reload JSON", function()
		{
			switchSubState(Prompt, ['This action will clear current progress.\n\nProceed?', 0, function()
			{
				loadJson(_song.song.toLowerCase());
			}, null, ignoreWarnings]);
		}, buttonWidth);
		tab_group.add(reloadSongJson);

		var loadAutosaveBtn:ShadowButton = new ShadowButton(pad + buttonWidth + buttonGap, row5, "Load Auto", function()
		{
			PlayState.SONG = Song.parseJSONshit(FlxG.save.data.autosave);
			Funkin.resetState();
		}, 70);
		tab_group.add(loadAutosaveBtn);

		var loadEventJson:ShadowButton = new ShadowButton(pad + buttonWidth + buttonGap + 75, row5, "Load Events", function()
		{
			var songName:String = Paths.formatToSongPath(_song.song);
			var baseFile:String = Paths.json(songName + '/events' + (isDiffErect ? '-erect' : ""));
			var exists:Bool = false;
			#if FEATURE_MODS
			var modFile:String = Paths.modsJson(songName + '/events' + (isDiffErect ? '-erect' : ""));
			if (FileSystem.exists(modFile))
				exists = true;
			else if (FileSystem.exists(baseFile))
				exists = true;
			#else
			if (FileSystem.exists(baseFile))
				exists = true;
			#end

			if (exists)
			{
				clearEvents();
				var events:SwagSong = Song.loadFromJson("events" + (isDiffErect ? '-erect' : ""), songName);
				_song.events = events.events;
				changeSection(curSec);
			}
		}, buttonWidth);
		tab_group.add(loadEventJson);

		var row6:Int = row5 + ShadowStyle.HEIGHT_BUTTON + rowGap;
		var saveEvents:ShadowButton = new ShadowButton(pad, row6, "Save Events", function()
		{
			saveEvents();
		}, buttonWidth);
		tab_group.add(saveEvents);

		var clear_events:ShadowButton = new ShadowButton(pad + buttonWidth + buttonGap, row6, "Clear Events", function()
		{
			switchSubState(Prompt, ['This action will clear current progress.\n\nProceed?', 0, clearEvents, null, ignoreWarnings]);
		}, buttonWidth);
		tab_group.add(clear_events);

		var clear_notes:ShadowButton = new ShadowButton(pad + (buttonWidth + buttonGap) * 2, row6, "Clear Notes", function()
		{
			switchSubState(Prompt, ['This action will clear current progress.\n\nProceed?', 0, function()
			{
				for (sec in 0..._song.notes.length)
				{
					_song.notes[sec].sectionNotes = [];
				}
				updateGrid();
			}, null, ignoreWarnings]);
		}, buttonWidth);
		tab_group.add(clear_notes);

		// dropdowns
		tab_group.add(stageDropDown);
		tab_group.add(player2DropDown);
		tab_group.add(gfVersionDropDown);
		tab_group.add(player1DropDown);

		initPsychCamera().follow(camPos, LOCKON, 999);

		camOther = new ShadowCamera();
		camOther.bgColor.alpha = 0;
		camOther.visible = false;
		FlxG.cameras.add(camOther, false);
	}

	var stepperBeats:ShadowStepper;
	var check_mustHitSection:ShadowCheckbox;
	var check_gfSection:ShadowCheckbox;
	var check_changeBPM:ShadowCheckbox;
	var stepperSectionBPM:ShadowStepper;
	var check_altAnim:ShadowCheckbox;
	var check_notesSec:ShadowCheckbox;
	var check_eventsSec:ShadowCheckbox;
	var stepperCopy:ShadowStepper;

	var sectionToCopy:Int = 0;
	var notesCopied:Array<Dynamic>;

	function addSectionUI():Void
	{
		var tab_group:FlxSpriteGroup = UI_box.getTabGroup("Section");
		if (tab_group == null)
			return;

		var pad:Int = ShadowStyle.SPACING_MD;
		var rowGap:Int = ShadowStyle.SPACING_SM;
		var labelOffset:Int = ShadowStyle.FONT_SIZE_SM + 4;
		var rowStep:Int = labelOffset + ShadowStyle.HEIGHT_INPUT + rowGap;
		var buttonWidth:Int = 80;
		var buttonGap:Int = ShadowStyle.SPACING_SM;
		var checkboxOffset:Int = Std.int((ShadowStyle.HEIGHT_INPUT - ShadowStyle.HEIGHT_CHECKBOX) / 2);

		var row0:Int = pad;
		check_mustHitSection = new ShadowCheckbox(pad, row0, "Must Hit Section", _song.notes[curSec].mustHitSection, function(checked:Bool)
		{
			_song.notes[curSec].mustHitSection = checked;
			updateGrid();
			updateHeads();
		});
		tab_group.add(check_mustHitSection);

		check_gfSection = new ShadowCheckbox(pad + 130, row0, "GF Section", _song.notes[curSec].gfSection, function(checked:Bool)
		{
			_song.notes[curSec].gfSection = checked;
			updateGrid();
			updateHeads();
		});
		tab_group.add(check_gfSection);

		var row1:Int = row0 + ShadowStyle.HEIGHT_CHECKBOX + rowGap;
		check_altAnim = new ShadowCheckbox(pad, row1, "Alt Animation", _song.notes[curSec].altAnim, function(checked:Bool)
		{
			_song.notes[curSec].altAnim = checked;
		});
		tab_group.add(check_altAnim);

		var row2:Int = row1 + ShadowStyle.HEIGHT_CHECKBOX + rowGap + 4;
		tab_group.add(new ShadowLabel(pad, row2, "Beats per Section:", ShadowStyle.FONT_SIZE_SM, ShadowStyle.TEXT_SECONDARY));
		stepperBeats = new ShadowStepper(pad, row2 + labelOffset, 1, getSectionBeats(), 1, 7, 2, function(value:Float)
		{
			_song.notes[curSec].sectionBeats = value;
			reloadGridLayer();
		}, 60);
		tab_group.add(stepperBeats);

		var row3:Int = row2 + rowStep;
		check_changeBPM = new ShadowCheckbox(pad, row3 + labelOffset + checkboxOffset, "Change BPM", _song.notes[curSec].changeBPM, function(checked:Bool)
		{
			_song.notes[curSec].changeBPM = checked;
		});
		tab_group.add(check_changeBPM);

		var sectionBpmValue:Float = check_changeBPM.checked ? _song.notes[curSec].bpm : Conductor.bpm;
		stepperSectionBPM = new ShadowStepper(pad + 110, row3 + labelOffset, 1, sectionBpmValue, 0, 999, 1, function(value:Float)
		{
			_song.notes[curSec].bpm = value;
			updateGrid();
		}, 70);
		tab_group.add(stepperSectionBPM);

		var row4:Int = row3 + rowStep;
		var copyButton:ShadowButton = new ShadowButton(pad, row4, "Copy", function()
		{
			notesCopied = [];
			sectionToCopy = curSec;
			for (i in 0..._song.notes[curSec].sectionNotes.length)
			{
				var note:Array<Dynamic> = _song.notes[curSec].sectionNotes[i];
				notesCopied.push(note);
			}

			var startThing:Float = sectionStartTime();
			var endThing:Float = sectionStartTime(1);
			for (event in _song.events)
			{
				var strumTime:Float = event[0];
				if (endThing > event[0] && event[0] >= startThing)
				{
					var copiedEventArray:Array<Dynamic> = [];
					for (i in 0...event[1].length)
					{
						var eventToPush:Array<Dynamic> = event[1][i];
						copiedEventArray.push([eventToPush[0], eventToPush[1], eventToPush[2]]);
					}
					notesCopied.push([strumTime, -1, copiedEventArray]);
				}
			}
		}, 60);
		tab_group.add(copyButton);

		var pasteButton:ShadowButton = new ShadowButton(pad + 65, row4, "Paste", function()
		{
			if (notesCopied == null || notesCopied.length < 1)
				return;

			var addToTime:Float = Conductor.stepCrochet * (getSectionBeats() * 4 * (curSec - sectionToCopy));

			for (note in notesCopied)
			{
				var copiedNote:Array<Dynamic> = [];
				var newStrumTime:Float = note[0] + addToTime;
				if (note[1] < 0)
				{
					if (check_eventsSec.checked)
					{
						var copiedEventArray:Array<Dynamic> = [];
						for (i in 0...note[2].length)
						{
							var eventToPush:Array<Dynamic> = note[2][i];
							copiedEventArray.push([eventToPush[0], eventToPush[1], eventToPush[2]]);
						}
						_song.events.push([newStrumTime, copiedEventArray]);
					}
				}
				else
				{
					if (check_notesSec.checked)
					{
						if (note[4] != null)
							copiedNote = [newStrumTime, note[1], note[2], note[3], note[4]];
						else
							copiedNote = [newStrumTime, note[1], note[2], note[3]];

						_song.notes[curSec].sectionNotes.push(copiedNote);
					}
				}
			}
			updateGrid();
		}, 60);
		tab_group.add(pasteButton);

		var clearSectionButton:ShadowButton = new ShadowButton(pad + 130, row4, "Clear", function()
		{
			if (check_notesSec.checked)
				_song.notes[curSec].sectionNotes = [];

			if (check_eventsSec.checked)
			{
				var i:Int = _song.events.length - 1;
				var startThing:Float = sectionStartTime();
				var endThing:Float = sectionStartTime(1);
				while (i > -1)
				{
					var event:Array<Dynamic> = _song.events[i];
					if (event != null && endThing > event[0] && event[0] >= startThing)
						_song.events.remove(event);
					--i;
				}
			}
			updateGrid();
			updateNoteUI();
		}, 60);
		tab_group.add(clearSectionButton);

		var swapSection:ShadowButton = new ShadowButton(pad + 195, row4, "Swap", function()
		{
			for (i in 0..._song.notes[curSec].sectionNotes.length)
			{
				var note:Array<Dynamic> = _song.notes[curSec].sectionNotes[i];
				note[1] = (note[1] + 4) % 8;
				_song.notes[curSec].sectionNotes[i] = note;
			}
			updateGrid();
		}, 50);
		tab_group.add(swapSection);

		var row5:Int = row4 + ShadowStyle.HEIGHT_BUTTON + rowGap;
		check_notesSec = new ShadowCheckbox(pad, row5, "Notes", true);
		tab_group.add(check_notesSec);
		check_eventsSec = new ShadowCheckbox(pad + 70, row5, "Events", true);
		tab_group.add(check_eventsSec);

		var row6:Int = row5 + ShadowStyle.HEIGHT_CHECKBOX + rowGap + 4;
		var copyLastButton:ShadowButton = new ShadowButton(pad, row6, "Copy Last", function()
		{
			var value:Int = Std.int(stepperCopy.value);
			if (value == 0)
				return;

			var daSec:Int = FlxMath.maxInt(curSec, value);

			for (note in _song.notes[daSec - value].sectionNotes)
			{
				var strum = note[0] + Conductor.stepCrochet * (getSectionBeats(daSec) * 4 * value);
				var copiedNote:Array<Dynamic> = [strum, note[1], note[2], note[3]];
				_song.notes[daSec].sectionNotes.push(copiedNote);
			}

			var startThing:Float = sectionStartTime(-value);
			var endThing:Float = sectionStartTime(-value + 1);
			for (event in _song.events)
			{
				var strumTime:Float = event[0];
				if (endThing > event[0] && event[0] >= startThing)
				{
					strumTime += Conductor.stepCrochet * (getSectionBeats(daSec) * 4 * value);
					var copiedEventArray:Array<Dynamic> = [];
					for (i in 0...event[1].length)
					{
						var eventToPush:Array<Dynamic> = event[1][i];
						copiedEventArray.push([eventToPush[0], eventToPush[1], eventToPush[2]]);
					}
					_song.events.push([strumTime, copiedEventArray]);
				}
			}
			updateGrid();
		}, 70);
		tab_group.add(copyLastButton);

		stepperCopy = new ShadowStepper(pad + 80, row6, 1, 1, -999, 999, 0, null, 60);
		tab_group.add(stepperCopy);

		var row7:Int = row6 + ShadowStyle.HEIGHT_INPUT + rowGap;
		var duetButton:ShadowButton = new ShadowButton(pad, row7, "Duet", function()
		{
			var duetNotes:Array<Array<Dynamic>> = [];
			for (note in _song.notes[curSec].sectionNotes)
			{
				var boob = note[1];
				if (boob > 3)
					boob -= 4;
				else
					boob += 4;

				var copiedNote:Array<Dynamic> = [note[0], boob, note[2], note[3]];
				duetNotes.push(copiedNote);
			}

			for (i in duetNotes)
				_song.notes[curSec].sectionNotes.push(i);

			updateGrid();
		}, 60);
		tab_group.add(duetButton);

		var mirrorButton:ShadowButton = new ShadowButton(pad + 65, row7, "Mirror", function()
		{
			for (note in _song.notes[curSec].sectionNotes)
			{
				var boob = note[1] % 4;
				boob = 3 - boob;
				if (note[1] > 3)
					boob += 4;
				note[1] = boob;
			}
			updateGrid();
		}, 60);
		tab_group.add(mirrorButton);
	}

	var stepperSusLength:ShadowStepper;
	var strumTimeInputText:ShadowTextInput;
	var noteTypeDropDown:ShadowDropdown;
	var currentType:Int = 0;

	function addNoteUI():Void
	{
		var tab_group:FlxSpriteGroup = UI_box.getTabGroup("Note");
		if (tab_group == null)
			return;

		var pad:Int = ShadowStyle.SPACING_MD;
		var rowGap:Int = ShadowStyle.SPACING_SM;
		var labelOffset:Int = ShadowStyle.FONT_SIZE_SM + 4;
		var rowStep:Int = labelOffset + ShadowStyle.HEIGHT_INPUT + rowGap;

		// Build note types list
		var key:Int = 0;
		while (key < noteTypeList.length)
		{
			curNoteTypes.push(noteTypeList[key]);
			key++;
		}

		var foldersToCheck:Array<String> = Mods.directoriesWithFile(Paths.getSharedPath(), 'custom_notetypes/');
		for (folder in foldersToCheck)
			for (file in FileSystem.readDirectory(folder))
			{
				var fileName:String = file.toLowerCase().trim();

				var extLen:Int = 4;
				var isValid:Bool = false;

				#if FEATURE_LUA
				if (fileName.endsWith('.lua') || fileName.endsWith('.luau'))
					isValid = true;
				#end

				#if FEATURE_HSCRIPT
				if (!isValid)
				{
					for (dynamicExt in cast(scripts.hscriptExtensions, Array<Dynamic>))
					{
						final ext:String = cast(dynamicExt, String);
						if (fileName.endsWith(ext))
						{
							extLen = ext.length;
							isValid = true;
							break;
						}
					}
				}
				#end

				if (!isValid && fileName.endsWith('.txt'))
					isValid = true;

				if (isValid && fileName != 'readme.txt')
				{
					var fileToCheck:String = file.substr(0, file.length - extLen);
					if (!curNoteTypes.contains(fileToCheck))
					{
						curNoteTypes.push(fileToCheck);
						key++;
					}
				}
			}

		var displayNameList:Array<String> = curNoteTypes.copy();
		for (i in 1...displayNameList.length)
		{
			displayNameList[i] = i + '. ' + displayNameList[i];
		}

		var row0:Int = pad;
		tab_group.add(new ShadowLabel(pad, row0, "Sustain length:", ShadowStyle.FONT_SIZE_SM, ShadowStyle.TEXT_SECONDARY));
		stepperSusLength = new ShadowStepper(pad, row0 + labelOffset, Conductor.stepCrochet / 2, 0, 0, Conductor.stepCrochet * 64, 0, function(value:Float)
		{
			if (curSelectedNote != null && curSelectedNote[2] != null)
			{
				curSelectedNote[2] = value;
				updateGrid();
			}
		}, 120);
		tab_group.add(stepperSusLength);

		var row1:Int = row0 + rowStep;
		tab_group.add(new ShadowLabel(pad, row1, "Strum time (ms):", ShadowStyle.FONT_SIZE_SM, ShadowStyle.TEXT_SECONDARY));
		strumTimeInputText = new ShadowTextInput(pad, row1 + labelOffset, 180, "0", function(text:String)
		{
			if (curSelectedNote != null)
			{
				var value:Float = Std.parseFloat(text);
				if (Math.isNaN(value))
					value = 0;
				curSelectedNote[0] = value;
				updateGrid();
			}
		});
		tab_group.add(strumTimeInputText);
		registerBlockerInput(strumTimeInputText);

		var row2:Int = row1 + rowStep;
		tab_group.add(new ShadowLabel(pad, row2, "Note type:", ShadowStyle.FONT_SIZE_SM, ShadowStyle.TEXT_SECONDARY));
		noteTypeDropDown = new ShadowDropdown(pad, row2 + labelOffset, displayNameList, function(index:Int)
		{
			currentType = index;
			if (curSelectedNote != null && curSelectedNote[1] > -1)
			{
				curSelectedNote[3] = curNoteTypes[currentType];
				updateGrid();
			}
		}, 200);
		tab_group.add(noteTypeDropDown);

		var row3:Int = row2 + rowStep;
		var check_disableNoteCustomColor:ShadowCheckbox = new ShadowCheckbox(pad, row3, "Disable Note Custom Color", (_song.disableNoteCustomColor == true), function(checked:Bool)
		{
			_song.disableNoteCustomColor = checked;
			updateGrid();
		});
		tab_group.add(check_disableNoteCustomColor);

		var row4:Int = row3 + ShadowStyle.HEIGHT_CHECKBOX + rowGap + 4;
		tab_group.add(new ShadowLabel(pad, row4, "Note Texture (Player):", ShadowStyle.FONT_SIZE_SM, ShadowStyle.TEXT_SECONDARY));
		noteSkinInputText = new ShadowTextInput(pad, row4 + labelOffset, 250, editorPlayerArrowSkin != null ? editorPlayerArrowSkin : '', function(text:String)
		{
			editorPlayerArrowSkin = text;
		});
		tab_group.add(noteSkinInputText);
		registerBlockerInput(noteSkinInputText);

		var row5:Int = row4 + rowStep;
		tab_group.add(new ShadowLabel(pad, row5, "Note Texture (Opponent):", ShadowStyle.FONT_SIZE_SM, ShadowStyle.TEXT_SECONDARY));
		noteSkinInputText2 = new ShadowTextInput(pad, row5 + labelOffset, 250, editorOpponentArrowSkin != null ? editorOpponentArrowSkin : '',
			function(text:String)
			{
				editorOpponentArrowSkin = text;
			});
		tab_group.add(noteSkinInputText2);
		registerBlockerInput(noteSkinInputText2);

		var row6:Int = row5 + rowStep;
		tab_group.add(new ShadowLabel(pad, row6, "Note Splashes Texture:", ShadowStyle.FONT_SIZE_SM, ShadowStyle.TEXT_SECONDARY));
		noteSplashesInputText = new ShadowTextInput(pad, row6 + labelOffset, 150, _song.splashSkin != null ? _song.splashSkin : '', function(text:String)
		{
			_song.splashSkin = text;
		});
		tab_group.add(noteSplashesInputText);
		registerBlockerInput(noteSplashesInputText);

		var reloadNotesButton:ShadowButton = new ShadowButton(pad + 160, row6 + labelOffset, "Reload Notes", function()
		{
			editorPlayerArrowSkin = noteSkinInputText.text;
			editorOpponentArrowSkin = noteSkinInputText2.text;
			updateGrid();
		}, 90);
		tab_group.add(reloadNotesButton);
	}

	var eventDropDown:ShadowDropdown;
	var descText:ShadowLabel;
	var selectedEventText:ShadowLabel;
	var leEvents:Array<String> = [];

	function addEventsUI():Void
	{
		var tab_group:FlxSpriteGroup = UI_box.getTabGroup("Events");
		if (tab_group == null)
			return;

		var pad:Int = ShadowStyle.SPACING_MD;
		var rowGap:Int = ShadowStyle.SPACING_SM;
		var labelOffset:Int = ShadowStyle.FONT_SIZE_SM + 4;
		var rowStep:Int = labelOffset + ShadowStyle.HEIGHT_INPUT + rowGap;
		var buttonWidth:Int = 30;
		var buttonGap:Int = ShadowStyle.SPACING_SM;

		#if (FEATURE_HSCRIPT || FEATURE_LUA)
		var eventPushedMap:Map<String, Bool> = new Map<String, Bool>();
		var directories:Array<String> = [];

		#if FEATURE_MODS
		directories.push(Paths.mods('custom_events/'));
		directories.push(Paths.mods(Mods.currentModDirectory + '/custom_events/'));
		for (mod in Mods.getGlobalMods())
			directories.push(Paths.mods(mod + '/custom_events/'));
		#end
		directories.push(Paths.getSharedPath('custom_events/'));

		for (i in 0...directories.length)
		{
			var directory:String = directories[i];
			if (FileSystem.exists(directory))
			{
				for (file in FileSystem.readDirectory(directory))
				{
					var path:String = Path.join([directory, file]);
					if (!FileSystem.isDirectory(path) && file != 'readme.txt' && file.endsWith('.txt'))
					{
						var fileToCheck:String = file.substr(0, file.length - 4);
						if (!eventPushedMap.exists(fileToCheck))
						{
							eventPushedMap.set(fileToCheck, true);
							eventStuff.push([fileToCheck, File.getContent(path)]);
						}
					}
				}
			}
		}
		eventPushedMap.clear();
		eventPushedMap = null;
		#end

		leEvents = [];
		for (i in 0...eventStuff.length)
		{
			leEvents.push(eventStuff[i][0]);
		}

		var row0:Int = pad;
		tab_group.add(new ShadowLabel(pad, row0, "Event:", ShadowStyle.FONT_SIZE_SM, ShadowStyle.TEXT_SECONDARY));
		eventDropDown = new ShadowDropdown(pad, row0 + labelOffset, leEvents, function(index:Int)
		{
			descText.text = eventStuff[index][1];
			if (curSelectedNote != null && eventStuff != null)
			{
				if (curSelectedNote != null && curSelectedNote[2] == null)
				{
					curSelectedNote[1][curEventSelected][0] = eventStuff[index][0];
				}
				updateGrid();
			}
		}, 150);

		var btnX:Int = pad + 160;
		var removeButton:ShadowButton = new ShadowButton(btnX, row0 + labelOffset, "-", function()
		{
			if (curSelectedNote != null && curSelectedNote[2] == null)
			{
				if (curSelectedNote[1].length < 2)
				{
					_song.events.remove(curSelectedNote);
					curSelectedNote = null;
				}
				else
				{
					curSelectedNote[1].remove(curSelectedNote[1][curEventSelected]);
				}

				var eventsGroup:Array<Dynamic>;
				--curEventSelected;
				if (curEventSelected < 0)
					curEventSelected = 0;
				else if (curSelectedNote != null && curEventSelected >= (eventsGroup = curSelectedNote[1]).length)
					curEventSelected = eventsGroup.length - 1;

				changeEventSelected();
				updateGrid();
			}
		}, buttonWidth);
		tab_group.add(removeButton);

		var addButton:ShadowButton = new ShadowButton(btnX + buttonWidth + buttonGap, row0 + labelOffset, "+", function()
		{
			if (curSelectedNote != null && curSelectedNote[2] == null)
			{
				var eventsGroup:Array<Dynamic> = curSelectedNote[1];
				eventsGroup.push(['', '', '']);
				changeEventSelected(1);
				updateGrid();
			}
		}, buttonWidth);
		tab_group.add(addButton);

		var moveLeftButton:ShadowButton = new ShadowButton(btnX + (buttonWidth + buttonGap) * 2 + 10, row0 + labelOffset, "<", function()
		{
			changeEventSelected(-1);
		}, buttonWidth);
		tab_group.add(moveLeftButton);

		var moveRightButton:ShadowButton = new ShadowButton(btnX + (buttonWidth + buttonGap) * 3 + 10, row0 + labelOffset, ">", function()
		{
			changeEventSelected(1);
		}, buttonWidth);
		tab_group.add(moveRightButton);

		var row1:Int = row0 + rowStep;
		selectedEventText = new ShadowLabel(pad, row1, "Selected Event: None");
		tab_group.add(selectedEventText);

		var row2:Int = row1 + ShadowStyle.FONT_SIZE_MD + rowGap;
		tab_group.add(new ShadowLabel(pad, row2, "Value 1:", ShadowStyle.FONT_SIZE_SM, ShadowStyle.TEXT_SECONDARY));
		value1InputText = new ShadowTextInput(pad, row2 + labelOffset, 250, "", function(text:String)
		{
			if (curSelectedNote != null && curSelectedNote[1][curEventSelected] != null)
			{
				curSelectedNote[1][curEventSelected][1] = text;
				updateGrid();
			}
		});
		tab_group.add(value1InputText);
		registerBlockerInput(value1InputText);

		var row3:Int = row2 + rowStep;
		tab_group.add(new ShadowLabel(pad, row3, "Value 2:", ShadowStyle.FONT_SIZE_SM, ShadowStyle.TEXT_SECONDARY));
		value2InputText = new ShadowTextInput(pad, row3 + labelOffset, 250, "", function(text:String)
		{
			if (curSelectedNote != null && curSelectedNote[1][curEventSelected] != null)
			{
				curSelectedNote[1][curEventSelected][2] = text;
				updateGrid();
			}
		});
		tab_group.add(value2InputText);
		registerBlockerInput(value2InputText);

		var row4:Int = row3 + rowStep;
		tab_group.add(new ShadowLabel(pad, row4, "Description:", ShadowStyle.FONT_SIZE_SM, ShadowStyle.TEXT_SECONDARY));
		descText = new ShadowLabel(pad, row4 + labelOffset, eventStuff[0][1], ShadowStyle.FONT_SIZE_SM, ShadowStyle.TEXT_SECONDARY);
		tab_group.add(descText);

		// dropdown
		tab_group.add(eventDropDown);
	}

	function changeEventSelected(change:Int = 0)
	{
		if (curSelectedNote != null && curSelectedNote[2] == null)
		{
			curEventSelected += change;
			if (curEventSelected < 0)
				curEventSelected = Std.int(curSelectedNote[1].length) - 1;
			else if (curEventSelected >= curSelectedNote[1].length)
				curEventSelected = 0;
			selectedEventText.text = 'Selected Event: ' + (curEventSelected + 1) + ' / ' + curSelectedNote[1].length;
		}
		else
		{
			curEventSelected = 0;
			selectedEventText.text = 'Selected Event: None';
		}
		updateNoteUI();
	}

	var metronome:ShadowCheckbox;
	var mouseScrollingQuant:ShadowCheckbox;
	var metronomeStepper:ShadowStepper;
	var metronomeOffsetStepper:ShadowStepper;
	var disableAutoScrolling:ShadowCheckbox;
	var instVolume:ShadowStepper;
	var voicesVolume:ShadowStepper;
	var voicesOppVolume:ShadowStepper;
	#if lime_openal
	var waveformUseInstrumental:ShadowCheckbox;
	var waveformUseVoices:ShadowCheckbox;
	var waveformUseOppVoices:ShadowCheckbox;
	#end

	function addChartingUI()
	{
		var tab_group:FlxSpriteGroup = UI_box.getTabGroup("Charting");
		if (tab_group == null)
			return;

		var pad:Int = ShadowStyle.SPACING_MD;
		var rowGap:Int = ShadowStyle.SPACING_SM;
		var labelOffset:Int = ShadowStyle.FONT_SIZE_SM + 4;
		var rowStep:Int = labelOffset + ShadowStyle.HEIGHT_INPUT + rowGap;
		var checkboxRowHeight:Int = ShadowStyle.HEIGHT_CHECKBOX + rowGap;
		var checkboxColumnSpacing:Int = 120;
		var currentRow:Float = pad;

		inline function columnX(column:Int):Float
		{
			return pad + (column - 1) * checkboxColumnSpacing;
		}

		inline function nextCheckboxRow(extra:Float = 0):Float
		{
			currentRow += extra;
			var y:Float = currentRow;
			currentRow += checkboxRowHeight;
			return y;
		}

		inline function nextInputRow(extra:Float = 0):Float
		{
			currentRow += extra;
			var y:Float = currentRow;
			currentRow += rowStep;
			return y;
		}

		var row0:Float = nextCheckboxRow();
		var row1:Float = nextInputRow();
		var row2:Float = nextCheckboxRow();
		var row3:Float = nextInputRow(4);
		var row4:Float = nextCheckboxRow();
		var row5:Float = nextCheckboxRow();
		var row6:Float = nextInputRow(4);
		var row7:Float = nextCheckboxRow();
		var row8:Float = nextCheckboxRow();

		// Initialize save data
		#if lime_openal
		if (FlxG.save.data.chart_waveformInst == null)
			FlxG.save.data.chart_waveformInst = false;
		if (FlxG.save.data.chart_waveformVoices == null)
			FlxG.save.data.chart_waveformVoices = false;
		if (FlxG.save.data.chart_waveformOppVoices == null)
			FlxG.save.data.chart_waveformOppVoices = false;
		#end
		if (FlxG.save.data.mouseScrollingQuant == null)
			FlxG.save.data.mouseScrollingQuant = false;
		if (FlxG.save.data.chart_vortex == null)
			FlxG.save.data.chart_vortex = false;
		if (FlxG.save.data.ignoreWarnings == null)
			FlxG.save.data.ignoreWarnings = false;
		if (FlxG.save.data.chart_metronome == null)
			FlxG.save.data.chart_metronome = false;
		if (FlxG.save.data.chart_noAutoScroll == null)
			FlxG.save.data.chart_noAutoScroll = false;
		if (FlxG.save.data.chart_playSoundBf == null)
			FlxG.save.data.chart_playSoundBf = false;
		if (FlxG.save.data.chart_playSoundDad == null)
			FlxG.save.data.chart_playSoundDad = false;

		metronome = new ShadowCheckbox(columnX(1), row0, "Metronome", FlxG.save.data.chart_metronome, function(checked:Bool)
		{
			FlxG.save.data.chart_metronome = checked;
		});
		tab_group.add(metronome);

		disableAutoScrolling = new ShadowCheckbox(columnX(2), row0, "No Autoscroll", FlxG.save.data.chart_noAutoScroll, function(checked:Bool)
		{
			FlxG.save.data.chart_noAutoScroll = checked;
		});
		tab_group.add(disableAutoScrolling);

		tab_group.add(new ShadowLabel(pad, row1, "BPM:", ShadowStyle.FONT_SIZE_SM, ShadowStyle.TEXT_SECONDARY));
		metronomeStepper = new ShadowStepper(pad, row1 + labelOffset, 5, _song.bpm, 1, 1500, 1, null, 70);
		tab_group.add(metronomeStepper);

		tab_group.add(new ShadowLabel(pad + 80, row1, "Offset (ms):", ShadowStyle.FONT_SIZE_SM, ShadowStyle.TEXT_SECONDARY));
		metronomeOffsetStepper = new ShadowStepper(pad + 80, row1 + labelOffset, 25, 0, 0, 1000, 1, null, 70);
		tab_group.add(metronomeOffsetStepper);

		#if lime_openal
		waveformUseInstrumental = new ShadowCheckbox(columnX(1), row2, "Wave Inst", FlxG.save.data.chart_waveformInst, function(checked:Bool)
		{
			waveformUseVoices.checked = false;
			waveformUseOppVoices.checked = false;
			FlxG.save.data.chart_waveformVoices = false;
			FlxG.save.data.chart_waveformOppVoices = false;
			FlxG.save.data.chart_waveformInst = checked;
			updateWaveform();
		});
		tab_group.add(waveformUseInstrumental);

		waveformUseVoices = new ShadowCheckbox(columnX(2), row2, "Wave Vocals", FlxG.save.data.chart_waveformVoices, function(checked:Bool)
		{
			waveformUseInstrumental.checked = false;
			waveformUseOppVoices.checked = false;
			FlxG.save.data.chart_waveformInst = false;
			FlxG.save.data.chart_waveformOppVoices = false;
			FlxG.save.data.chart_waveformVoices = checked;
			updateWaveform();
		});
		tab_group.add(waveformUseVoices);

		waveformUseOppVoices = new ShadowCheckbox(columnX(3), row2, "Wave Opp", FlxG.save.data.chart_waveformOppVoices, function(checked:Bool)
		{
			waveformUseInstrumental.checked = false;
			waveformUseVoices.checked = false;
			FlxG.save.data.chart_waveformInst = false;
			FlxG.save.data.chart_waveformVoices = false;
			FlxG.save.data.chart_waveformOppVoices = checked;
			updateWaveform();
		});
		tab_group.add(waveformUseOppVoices);
		#end

		tab_group.add(new ShadowLabel(pad, row3, "Playback Rate:", ShadowStyle.FONT_SIZE_SM, ShadowStyle.TEXT_SECONDARY));
		sliderRate = new ShadowSlider(pad, row3 + labelOffset, 0.5, 3, 1, function(value:Float)
		{
			playbackSpeed = value;
		}, 200, 2, true);
		tab_group.add(sliderRate);

		check_warnings = new ShadowCheckbox(columnX(1), row4, "Ignore Warnings", FlxG.save.data.ignoreWarnings, function(checked:Bool)
		{
			FlxG.save.data.ignoreWarnings = checked;
			ignoreWarnings = checked;
		});
		tab_group.add(check_warnings);

		check_vortex = new ShadowCheckbox(columnX(2), row4, "Vortex Editor", FlxG.save.data.chart_vortex, function(checked:Bool)
		{
			FlxG.save.data.chart_vortex = checked;
			vortex = checked;
			reloadGridLayer();
		});
		tab_group.add(check_vortex);

		mouseScrollingQuant = new ShadowCheckbox(columnX(1), row5, "Mouse Scroll Quant", FlxG.save.data.mouseScrollingQuant, function(checked:Bool)
		{
			FlxG.save.data.mouseScrollingQuant = checked;
			mouseQuant = checked;
		});
		tab_group.add(mouseScrollingQuant);

		tab_group.add(new ShadowLabel(pad, row6, "Inst Vol:", ShadowStyle.FONT_SIZE_SM, ShadowStyle.TEXT_SECONDARY));
		instVolume = new ShadowStepper(pad, row6 + labelOffset, 0.1, FlxG.sound.music.volume, 0, 1, 1, function(value:Float)
		{
			FlxG.sound.music.volume = check_mute_inst.checked ? 0 : value;
		}, 60);
		tab_group.add(instVolume);

		tab_group.add(new ShadowLabel(pad + 70, row6, "Main Vol:", ShadowStyle.FONT_SIZE_SM, ShadowStyle.TEXT_SECONDARY));
		voicesVolume = new ShadowStepper(pad + 70, row6 + labelOffset, 0.1, vocals.volume, 0, 1, 1, function(value:Float)
		{
			if (vocals != null)
				vocals.volume = check_mute_vocals.checked ? 0 : value;
		}, 60);
		tab_group.add(voicesVolume);

		tab_group.add(new ShadowLabel(pad + 140, row6, "Opp Vol:", ShadowStyle.FONT_SIZE_SM, ShadowStyle.TEXT_SECONDARY));
		voicesOppVolume = new ShadowStepper(pad + 140, row6 + labelOffset, 0.1, vocals.volume, 0, 1, 1, function(value:Float)
		{
			if (opponentVocals != null)
				opponentVocals.volume = check_mute_vocals_opponent.checked ? 0 : value;
		}, 60);
		tab_group.add(voicesOppVolume);

		check_mute_inst = new ShadowCheckbox(columnX(1), row7, "Mute Inst", false, function(checked:Bool)
		{
			FlxG.sound.music.volume = checked ? 0 : instVolume.value;
		});
		tab_group.add(check_mute_inst);

		check_mute_vocals = new ShadowCheckbox(columnX(2), row7, "Mute Vocals", false, function(checked:Bool)
		{
			if (vocals != null)
				vocals.volume = checked ? 0 : voicesVolume.value;
		});
		tab_group.add(check_mute_vocals);

		check_mute_vocals_opponent = new ShadowCheckbox(columnX(3), row7, "Mute Opp", false, function(checked:Bool)
		{
			if (opponentVocals != null)
				opponentVocals.volume = checked ? 0 : voicesOppVolume.value;
		});
		tab_group.add(check_mute_vocals_opponent);

		playSoundBf = new ShadowCheckbox(columnX(1), row8, "Play BF Sound", FlxG.save.data.chart_playSoundBf, function(checked:Bool)
		{
			FlxG.save.data.chart_playSoundBf = checked;
		});
		tab_group.add(playSoundBf);

		playSoundDad = new ShadowCheckbox(columnX(2), row8, "Play Dad Sound", FlxG.save.data.chart_playSoundDad, function(checked:Bool)
		{
			FlxG.save.data.chart_playSoundDad = checked;
		});
		tab_group.add(playSoundDad);
	}

	var gameOverCharacterInputText:ShadowTextInput;
	var gameOverSoundInputText:ShadowTextInput;
	var gameOverLoopInputText:ShadowTextInput;
	var gameOverEndInputText:ShadowTextInput;
	var noteSkinInputText:ShadowTextInput;
	var noteSkinInputText2:ShadowTextInput;
	var noteSplashesInputText:ShadowTextInput;

	// Editor-only note skins (do NOT store inside song data)
	var editorPlayerArrowSkin:String = '';
	var editorOpponentArrowSkin:String = '';

	function addDataUI()
	{
		var tab_group:FlxSpriteGroup = UI_box.getTabGroup("Data");
		if (tab_group == null)
			return;

		var pad:Int = ShadowStyle.SPACING_MD;
		var rowGap:Int = ShadowStyle.SPACING_SM;
		var labelOffset:Int = ShadowStyle.FONT_SIZE_SM + 4;
		var rowStep:Int = labelOffset + ShadowStyle.HEIGHT_INPUT + rowGap;
		var inputWidth:Int = 250;

		var row0:Int = pad;
		tab_group.add(new ShadowLabel(pad, row0, "Game Over Character:", ShadowStyle.FONT_SIZE_SM, ShadowStyle.TEXT_SECONDARY));
		gameOverCharacterInputText = new ShadowTextInput(pad, row0 + labelOffset, inputWidth, _song.gameOverChar != null ? _song.gameOverChar : '',
			function(text:String)
			{
				_song.gameOverChar = text;
			});
		tab_group.add(gameOverCharacterInputText);
		registerBlockerInput(gameOverCharacterInputText);

		var row1:Int = row0 + rowStep;
		tab_group.add(new ShadowLabel(pad, row1, "Death Sound (sounds/):", ShadowStyle.FONT_SIZE_SM, ShadowStyle.TEXT_SECONDARY));
		gameOverSoundInputText = new ShadowTextInput(pad, row1 + labelOffset, inputWidth, _song.gameOverSound != null ? _song.gameOverSound : '',
			function(text:String)
			{
				_song.gameOverSound = text;
			});
		tab_group.add(gameOverSoundInputText);
		registerBlockerInput(gameOverSoundInputText);

		var row2:Int = row1 + rowStep;
		tab_group.add(new ShadowLabel(pad, row2, "Loop Music (music/):", ShadowStyle.FONT_SIZE_SM, ShadowStyle.TEXT_SECONDARY));
		gameOverLoopInputText = new ShadowTextInput(pad, row2 + labelOffset, inputWidth, _song.gameOverLoop != null ? _song.gameOverLoop : '',
			function(text:String)
			{
				_song.gameOverLoop = text;
			});
		tab_group.add(gameOverLoopInputText);
		registerBlockerInput(gameOverLoopInputText);

		var row3:Int = row2 + rowStep;
		tab_group.add(new ShadowLabel(pad, row3, "Retry Music (music/):", ShadowStyle.FONT_SIZE_SM, ShadowStyle.TEXT_SECONDARY));
		gameOverEndInputText = new ShadowTextInput(pad, row3 + labelOffset, inputWidth, _song.gameOverEnd != null ? _song.gameOverEnd : '',
			function(text:String)
			{
				_song.gameOverEnd = text;
			});
		tab_group.add(gameOverEndInputText);
		registerBlockerInput(gameOverEndInputText);
	}

	function makeHelpUI()
	{
		UI_helpOverlay = new FlxSprite();
		UI_helpOverlay.makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		UI_helpOverlay.alpha = 0.6;
		UI_helpOverlay.cameras = [camOther];
		UI_helpOverlay.scrollFactor.set();
		UI_helpOverlay.visible = false;
		add(UI_helpOverlay);

		var panelWidth:Int = 750;
		var panelHeight:Int = 500;
		var panelX:Float = (FlxG.width - panelWidth) / 2;
		var panelY:Float = (FlxG.height - panelHeight) / 2;

		UI_help = new ShadowPanel(panelX, panelY, panelWidth, panelHeight);
		UI_help.cameras = [camOther];
		UI_help.scrollFactor.set();
		UI_help.visible = false;
		UI_help.active = false;
		add(UI_help);

		var pad:Int = ShadowStyle.SPACING_LG;

		var titleLabel:ShadowLabel = new ShadowLabel(pad, pad, "Controls Help", 24, ShadowStyle.TEXT_PRIMARY);
		UI_help.add(titleLabel);

		var helpStr:String;
		if (Funkin.controls.mobileC)
		{
			helpStr = "Up/Down - Change Conductor's strum time\nLeft/Right - Go to the previous/next section\n"
				+ "G - Reset Song Playback Rate\n"
				+ "Hold Y to move 4x faster\nHold H and touch on an arrow to select it\nV/D - Zoom in/out\n\n" +
				"C - Test your chart inside Chart Editor\nA - Play your chart\n" +
				"Up/Down (On The Right) - Decrease/Increase Note Sustain Length\nX - Stop/Resume Song";
		}
		else
		{
			helpStr = "W/S or Mouse Wheel - Change Conductor's strum time\nA/D - Go to the previous/next section\n"
				+ "Left/Right - Change Snap\nUp/Down - Change Conductor's Strum Time with Snapping\n"
				+ "Left Bracket / Right Bracket - Change Song Playback Rate (SHIFT to go Faster)\n"
				+ "ALT + Left Bracket / Right Bracket - Reset Song Playback Rate\n"
				+ "Hold Shift to move 4x faster\nHold Control and click on an arrow to select it\nZ/X - Zoom in/out\n\n" +
				"Esc - Test your chart inside Chart Editor\nEnter - Play your chart\n" + "Q/E - Decrease/Increase Note Sustain Length\nSpace - Stop/Resume song";
		}

		var helpText:ShadowLabel = new ShadowLabel(pad, pad + 40, helpStr, ShadowStyle.FONT_SIZE_LG, ShadowStyle.TEXT_PRIMARY, panelWidth - (pad * 2));
		UI_help.add(helpText);

		var closeText:ShadowLabel = new ShadowLabel(pad, panelHeight - pad - 24, 'Press ${Funkin.controls.mobileC ? "F" : "ESC or F1"} to close', ShadowStyle.FONT_SIZE_MD, ShadowStyle.TEXT_SECONDARY);
		UI_help.add(closeText);
	}

	function loadSong():Void
	{
		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();

		if (vocals != null)
		{
			vocals.stop();
			vocals.destroy();
		}
		if (opponentVocals != null)
		{
			opponentVocals.stop();
			opponentVocals.destroy();
		}

		vocals = new FlxSound();
		opponentVocals = new FlxSound();
		try
		{
			var playerVocals = Paths.voices(currentSongName,
				(characterData.vocalsP1 == null || characterData.vocalsP1.length < 1) ? 'Player' : characterData.vocalsP1 + Difficulty.getSongPrefix());
			vocals.loadEmbedded(playerVocals != null ? playerVocals : Paths.voices(currentSongName, Difficulty.getSongPrefix(null, false)));
		}
		vocals.autoDestroy = false;
		FlxG.sound.list.add(vocals);

		opponentVocals = new FlxSound();
		try
		{
			var oppVocals = Paths.voices(currentSongName,
				(characterData.vocalsP2 == null || characterData.vocalsP2.length < 1) ? 'Opponent' : characterData.vocalsP2 + Difficulty.getSongPrefix());
			if (oppVocals != null)
				opponentVocals.loadEmbedded(oppVocals);
		}
		opponentVocals.autoDestroy = false;
		FlxG.sound.list.add(opponentVocals);

		generateSong();
		FlxG.sound.music.pause();
		Conductor.songPosition = sectionStartTime();
		FlxG.sound.music.time = Conductor.songPosition;

		var curTime:Float = 0;
		// trace(_song.notes.length);
		if (_song.notes.length <= 1) // First load ever
		{
			// trace('first load ever!!');
			while (curTime < FlxG.sound.music.length)
			{
				addSection();
				curTime += (60 / _song.bpm) * 4000;
			}
		}
	}

	var playtesting:Bool = false;
	var playtestingTime:Float = 0;
	var playtestingOnComplete:Void->Void = null;

	override function closeSubState()
	{
		if (playtesting)
		{
			FlxG.sound.music.pause();
			FlxG.sound.music.time = playtestingTime;
			FlxG.sound.music.onComplete = playtestingOnComplete;
			if (instVolume != null)
				FlxG.sound.music.volume = instVolume.value;
			if (check_mute_inst != null && check_mute_inst.checked)
				FlxG.sound.music.volume = 0;

			if (vocals != null)
			{
				vocals.pause();
				vocals.time = playtestingTime;
				if (voicesVolume != null)
					vocals.volume = voicesVolume.value;
				if (check_mute_vocals != null && check_mute_vocals.checked)
					vocals.volume = 0;
			}

			if (opponentVocals != null)
			{
				opponentVocals.pause();
				opponentVocals.time = playtestingTime;
				if (voicesOppVolume != null)
					opponentVocals.volume = voicesOppVolume.value;
				if (check_mute_vocals_opponent != null && check_mute_vocals_opponent.checked)
					opponentVocals.volume = 0;
			}

			#if FEATURE_DISCORD_RPC
			// Updating Discord Rich Presence
			DiscordClient.changePresence("Chart Editor", StringTools.replace(_song.song, '-', ' '));
			#end
		}
		persistentUpdate = true;
		#if FEATURE_MOBILE_CONTROLS
		removeTouchPad();
		addTouchPad("LEFT_FULL", "CHART_EDITOR");
		#end
		super.closeSubState();
	}

	function generateSong()
	{
		FlxG.sound.playMusic(Paths.inst(currentSongName, Difficulty.getSongPrefix(null, false)), 0.6 /*, false*/);
		FlxG.sound.music.autoDestroy = false;
		if (instVolume != null)
			FlxG.sound.music.volume = instVolume.value;
		if (check_mute_inst != null && check_mute_inst.checked)
			FlxG.sound.music.volume = 0;

		FlxG.sound.music.onComplete = function()
		{
			FlxG.sound.music.pause();
			Conductor.songPosition = 0;
			if (vocals != null)
			{
				vocals.pause();
				vocals.time = 0;
			}
			if (opponentVocals != null)
			{
				opponentVocals.pause();
				opponentVocals.time = 0;
			}
			changeSection();
			curSec = 0;
			updateGrid();
			updateSectionUI();
			if (vocals != null)
				vocals.play();
			if (opponentVocals != null)
				opponentVocals.play();
		};
	}

	function generateUI():Void
	{
		while (bullshitUI.members.length > 0)
		{
			bullshitUI.remove(bullshitUI.members[0], true);
		}

		// general shit
		var title:FlxText = new FlxText(UI_box.x + 20, UI_box.y + 20, 0);
		bullshitUI.add(title);
	}

	var updatedSection:Bool = false;

	function sectionStartTime(add:Int = 0):Float
	{
		var daBPM:Float = _song.bpm;
		var daPos:Float = 0;
		for (i in 0...curSec + add)
		{
			if (_song.notes[i] != null)
			{
				if (_song.notes[i].changeBPM)
				{
					daBPM = _song.notes[i].bpm;
				}
				daPos += getSectionBeats(i) * (1000 * 60 / daBPM);
			}
		}
		return daPos;
	}

	var lastConductorPos:Float;
	var colorSine:Float = 0;

	override function update(elapsed:Float)
	{
		if (UI_help != null && UI_help.visible)
		{
			ClientPrefs.toggleVolumeKeys(false);
			FlxG.mouse.enabled = false;

			if ((FlxG.keys.justPressed.F1 #if FEATURE_MOBILE_CONTROLS || touchPad.buttonF.justPressed #end) || FlxG.keys.justPressed.ESCAPE)
			{
				#if FEATURE_MOBILE_CONTROLS
				if (Funkin.controls.mobileC)
				{
					touchPad.forEachAlive(function(button:TouchButton)
					{
						if (button.tag != 'F')
							button.visible = !button.visible;
					});
				}
				#end
				UI_help.visible = false;
				UI_help.active = false;
				UI_helpOverlay.visible = false;
				camOther.visible = false;
				FlxG.mouse.enabled = true;
			}
			super.update(elapsed);
			return;
		}

		if (FlxG.keys.justPressed.F1 #if FEATURE_MOBILE_CONTROLS || touchPad.buttonF.justPressed #end)
		{
			#if FEATURE_MOBILE_CONTROLS
			if (Funkin.controls.mobileC)
			{
				touchPad.forEachAlive(function(button:TouchButton)
				{
					if (button.tag != 'F')
						button.visible = !button.visible;
				});
			}
			#end
			UI_help.visible = true;
			UI_help.active = true;
			UI_helpOverlay.visible = true;
			camOther.visible = true;
			FlxG.mouse.enabled = false;
		}

		curStep = recalculateSteps();

		if (FlxG.sound.music.time < 0)
		{
			FlxG.sound.music.pause();
			FlxG.sound.music.time = 0;
		}
		else if (FlxG.sound.music.time > FlxG.sound.music.length)
		{
			FlxG.sound.music.pause();
			FlxG.sound.music.time = 0;
			changeSection();
		}
		Conductor.songPosition = FlxG.sound.music.time;
		_song.song = UI_songTitle.text;

		strumLineUpdateY();
		for (i in 0...8)
		{
			strumLineNotes.members[i].y = strumLine.y;
		}

		FlxG.mouse.visible = true; // cause reasons. trust me
		camPos.y = strumLine.y;
		if (!disableAutoScrolling.checked)
		{
			if (Math.ceil(strumLine.y) >= gridBG.height)
			{
				if (_song.notes[curSec + 1] == null)
				{
					addSection();
				}

				changeSection(curSec + 1, false);
			}
			else if (strumLine.y < -10)
			{
				changeSection(curSec - 1, false);
			}
		}
		FlxG.watch.addQuick('daBeat', curBeat);
		FlxG.watch.addQuick('daStep', curStep);

		if (Funkin.controls.mobileC)
		{
			for (touch in FlxG.touches.list)
			{
				if (touch.justReleased)
				{
					if (touch.overlaps(curRenderedNotes))
					{
						curRenderedNotes.forEachAlive(function(note:Note)
						{
							if (touch.overlaps(note))
							{
								#if FEATURE_MOBILE_CONTROLS
								if (touchPad.buttonF.pressed)
								{
									selectNote(note);
								}
								else #end if (FlxG.keys.pressed.ALT)
								{
									selectNote(note);
									curSelectedNote[3] = curNoteTypes[currentType];
									updateGrid();
								}
								else
								{
									// trace('tryin to delete note...');
									deleteNote(note);
								}
							}
						});
					}
					else if (#if FEATURE_MOBILE_CONTROLS !touchPad.buttonF.pressed #else true #end)
					{
						if (touch.x > gridBG.x
							&& touch.x < gridBG.x + gridBG.width
							&& touch.y > gridBG.y
							&& touch.y < gridBG.y + (GRID_SIZE * getSectionBeats() * 4) * zoomList[curZoom])
						{
							FlxG.log.add('added note');
							addNote();
						}
					}
				}

				if (touch.x > gridBG.x
					&& touch.x < gridBG.x + gridBG.width
					&& touch.y > gridBG.y
					&& touch.y < gridBG.y + (GRID_SIZE * getSectionBeats() * 4) * zoomList[curZoom])
				{
					dummyArrow.visible = true;
					dummyArrow.x = Math.floor(touch.x / GRID_SIZE) * GRID_SIZE;
					if (FlxG.keys.pressed.SHIFT #if FEATURE_MOBILE_CONTROLS || touchPad.buttonY.pressed #end)
						dummyArrow.y = touch.y;
					else
						dummyArrow.y = Math.floor(touch.y / GRID_SIZE) * GRID_SIZE;
				}
				else
				{
					dummyArrow.visible = false;
				}
			}
		}
		else
		{
			if (FlxG.mouse.justPressed)
			{
				if (FlxG.mouse.overlaps(curRenderedNotes))
				{
					curRenderedNotes.forEachAlive(function(note:Note)
					{
						if (FlxG.mouse.overlaps(note))
						{
							if (FlxG.keys.pressed.CONTROL)
							{
								selectNote(note);
							}
							else if (FlxG.keys.pressed.ALT)
							{
								selectNote(note);
								curSelectedNote[3] = curNoteTypes[currentType];
								updateGrid();
							}
							else
							{
								// trace('tryin to delete note...');
								deleteNote(note);
							}
						}
					});
				}
				else
				{
					if (FlxG.mouse.x > gridBG.x
						&& FlxG.mouse.x < gridBG.x + gridBG.width
						&& FlxG.mouse.y > gridBG.y
						&& FlxG.mouse.y < gridBG.y + (GRID_SIZE * getSectionBeats() * 4) * zoomList[curZoom])
					{
						FlxG.log.add('added note');
						addNote();
					}
				}
			}

			if (FlxG.mouse.x > gridBG.x
				&& FlxG.mouse.x < gridBG.x + gridBG.width
				&& FlxG.mouse.y > gridBG.y
				&& FlxG.mouse.y < gridBG.y + (GRID_SIZE * getSectionBeats() * 4) * zoomList[curZoom])
			{
				dummyArrow.visible = true;
				dummyArrow.x = Math.floor(FlxG.mouse.x / GRID_SIZE) * GRID_SIZE;
				if (FlxG.keys.pressed.SHIFT)
					dummyArrow.y = FlxG.mouse.y;
				else
					dummyArrow.y = Math.floor(FlxG.mouse.y / GRID_SIZE) * GRID_SIZE;
			}
			else
			{
				dummyArrow.visible = false;
			}
		}

		var blockInput:Bool = isEditorInputBlocked();
		ClientPrefs.toggleVolumeKeys(!blockInput);

		if (!blockInput)
		{
			if (FlxG.keys.justPressed.ESCAPE #if FEATURE_MOBILE_CONTROLS || touchPad.buttonC.justPressed #end)
			{
				if (FlxG.sound.music != null)
					FlxG.sound.music.stop();

				if (vocals != null)
				{
					vocals.pause();
					vocals.volume = 0;
				}
				if (opponentVocals != null)
				{
					opponentVocals.pause();
					opponentVocals.volume = 0;
				}

				autosaveSong();
				playtesting = true;
				playtestingTime = Conductor.songPosition;
				playtestingOnComplete = FlxG.sound.music.onComplete;
				#if FEATURE_MOBILE_CONTROLS
				touchPad.alpha = 0;
				#end
				persistentUpdate = false;
				switchSubState(states.editors.EditorPlayState, [playbackSpeed]);
			}
			else if (FlxG.keys.justPressed.ENTER #if FEATURE_MOBILE_CONTROLS || touchPad.buttonA.justPressed #end)
			{
				autosaveSong();
				FlxG.mouse.visible = false;
				PlayState.SONG = _song;
				FlxG.sound.music.stop();
				if (vocals != null)
					vocals.stop();
				if (opponentVocals != null)
					opponentVocals.stop();

				// if(_song.stage == null) _song.stage = stageDropDown.selectedLabel;
				StageData.loadDirectory(_song);
				LoadingState.loadAndSwitchState(PlayState);
			}

			if (curSelectedNote != null && curSelectedNote[1] > -1)
			{
				if (#if FEATURE_MOBILE_CONTROLS touchPad.buttonDown2.justPressed || #end FlxG.keys.justPressed.E)
				{
					changeNoteSustain(Conductor.stepCrochet);
				}
				if (#if FEATURE_MOBILE_CONTROLS touchPad.buttonUp2.justPressed || #end FlxG.keys.justPressed.Q)
				{
					changeNoteSustain(-Conductor.stepCrochet);
				}
			}

			if (FlxG.keys.justPressed.BACKSPACE #if FEATURE_MOBILE_CONTROLS || touchPad.buttonB.justPressed #end)
			{
				// Protect against lost data when quickly leaving the chart editor.
				autosaveSong();
				persistentUpdate = PlayState.chartingMode = FlxG.mouse.visible = false;
				Funkin.switchState(states.editors.MasterEditorMenu);
				FlxG.sound.playMusic(Paths.music('freakyMenu'));
				return;
			}

			if (#if FEATURE_MOBILE_CONTROLS touchPad.buttonZ.justPressed || #end (FlxG.keys.justPressed.Z && FlxG.keys.pressed.CONTROL))
			{
				undo();
			}

			if (FlxG.keys.justPressed.Y && FlxG.keys.pressed.CONTROL)
			{
				redo();
			}

			if (((FlxG.keys.justPressed.Z && !FlxG.keys.pressed.CONTROL) #if FEATURE_MOBILE_CONTROLS || touchPad.buttonV.justPressed #end) && curZoom > 0)
			{
				--curZoom;
				updateZoom();
			}
			if ((FlxG.keys.justPressed.X #if FEATURE_MOBILE_CONTROLS || touchPad.buttonD.justPressed #end) && curZoom < zoomList.length - 1)
			{
				curZoom++;
				updateZoom();
			}

			if (FlxG.keys.justPressed.TAB)
			{
				if (FlxG.keys.pressed.SHIFT)
				{
					UI_box.selectedTab -= 1;
					if (UI_box.selectedTab < 0)
						UI_box.selectedTab = 2;
				}
				else
				{
					UI_box.selectedTab += 1;
					if (UI_box.selectedTab >= 3)
						UI_box.selectedTab = 0;
				}
			}

			if (FlxG.keys.justPressed.SPACE #if FEATURE_MOBILE_CONTROLS || touchPad.buttonX.justPressed #end)
			{
				if (vocals != null)
					vocals.play();
				if (opponentVocals != null)
					opponentVocals.play();
				pauseAndSetVocalsTime();
				if (!FlxG.sound.music.playing)
				{
					FlxG.sound.music.play();
					if (vocals != null)
						vocals.play();
					if (opponentVocals != null)
						opponentVocals.play();
				}
				else
					FlxG.sound.music.pause();
			}

			if (!FlxG.keys.pressed.ALT && FlxG.keys.justPressed.R)
			{
				if (FlxG.keys.pressed.SHIFT)
					resetSection(true);
				else
					resetSection();
			}

			if (!Funkin.controls.mobileC)
			{
				if (FlxG.mouse.deltaWheel.y != 0)
				{
					FlxG.sound.music.pause();
					if (!mouseQuant)
						FlxG.sound.music.time -= (FlxG.mouse.deltaWheel.y * Conductor.stepCrochet * 0.8);
					else
					{
						var time:Float = FlxG.sound.music.time;
						var beat:Float = curDecBeat;
						var snap:Float = quantization / 4;
						var increase:Float = 1 / snap;
						if (FlxG.mouse.deltaWheel.y > 0)
						{
							var fuck:Float = CoolUtil.quantize(beat, snap) - increase;
							FlxG.sound.music.time = Conductor.beatToSeconds(fuck);
						}
						else
						{
							var fuck:Float = CoolUtil.quantize(beat, snap) + increase;
							FlxG.sound.music.time = Conductor.beatToSeconds(fuck);
						}
					}
					pauseAndSetVocalsTime();
				}
			}

			// ARROW VORTEX SHIT NO DEADASS

			if ((FlxG.keys.pressed.W || FlxG.keys.pressed.S) #if FEATURE_MOBILE_CONTROLS || (touchPad.buttonUp.pressed || touchPad.buttonDown.pressed) #end)
			{
				FlxG.sound.music.pause();

				var holdingShift:Float = 1;
				if (FlxG.keys.pressed.CONTROL)
					holdingShift = 0.25;
				else if (FlxG.keys.pressed.SHIFT #if FEATURE_MOBILE_CONTROLS || touchPad.buttonY.pressed #end)
					holdingShift = 4;

				var daTime:Float = 700 * FlxG.elapsed * holdingShift;

				FlxG.sound.music.time += daTime * ((FlxG.keys.pressed.W #if FEATURE_MOBILE_CONTROLS || touchPad.buttonUp.pressed #end) ? -1 : 1);

				pauseAndSetVocalsTime();
			}

			if (!vortex)
			{
				if (FlxG.keys.justPressed.UP || FlxG.keys.justPressed.DOWN)
				{
					FlxG.sound.music.pause();
					updateCurStep();
					pauseAndSetVocalsTime();
					var time:Float = FlxG.sound.music.time;
					var beat:Float = curDecBeat;
					var snap:Float = quantization / 4;
					var increase:Float = 1 / snap;
					if (FlxG.keys.pressed.UP)
					{
						var fuck:Float = CoolUtil.quantize(beat, snap) - increase; // (Math.floor((beat+snap) / snap) * snap);
						FlxG.sound.music.time = Conductor.beatToSeconds(fuck);
					}
					else
					{
						var fuck:Float = CoolUtil.quantize(beat, snap) + increase; // (Math.floor((beat+snap) / snap) * snap);
						FlxG.sound.music.time = Conductor.beatToSeconds(fuck);
					}
				}
			}

			var style:Int = currentType;

			if (FlxG.keys.pressed.SHIFT #if FEATURE_MOBILE_CONTROLS || touchPad.buttonY.pressed #end)
			{
				style = 3;
			}

			var conductorTime:Float = Conductor.songPosition; // + sectionStartTime();Conductor.songPosition / Conductor.stepCrochet;

			// AWW YOU MADE IT SEXY <3333 THX SHADMAR

			if (!blockInput)
			{
				if (FlxG.keys.justPressed.RIGHT)
				{
					curQuant++;
					if (curQuant > quantizations.length - 1)
						curQuant = 0;

					quantization = quantizations[curQuant];
				}

				if (FlxG.keys.justPressed.LEFT)
				{
					curQuant--;
					if (curQuant < 0)
						curQuant = quantizations.length - 1;

					quantization = quantizations[curQuant];
				}
				quant.animation.play('q', true, false, curQuant);
			}
			if (vortex && !blockInput)
			{
				var controlArray:Array<Bool> = [
					 FlxG.keys.justPressed.ONE, FlxG.keys.justPressed.TWO, FlxG.keys.justPressed.THREE, FlxG.keys.justPressed.FOUR,
					FlxG.keys.justPressed.FIVE, FlxG.keys.justPressed.SIX, FlxG.keys.justPressed.SEVEN, FlxG.keys.justPressed.EIGHT
				];

				if (controlArray.contains(true))
				{
					for (i in 0...controlArray.length)
					{
						if (controlArray[i])
							doANoteThing(conductorTime, i, style);
					}
				}

				var feces:Float;
				if (FlxG.keys.justPressed.UP || FlxG.keys.justPressed.DOWN)
				{
					FlxG.sound.music.pause();

					updateCurStep();
					// FlxG.sound.music.time = (Math.round(curStep/quants[curQuant])*quants[curQuant]) * Conductor.stepCrochet;

					// (Math.floor((curStep+quants[curQuant]*1.5/(quants[curQuant]/2))/quants[curQuant])*quants[curQuant]) * Conductor.stepCrochet;//snap into quantization
					var time:Float = FlxG.sound.music.time;
					var beat:Float = curDecBeat;
					var snap:Float = quantization / 4;
					var increase:Float = 1 / snap;
					if (FlxG.keys.pressed.UP)
					{
						var fuck:Float = CoolUtil.quantize(beat, snap) - increase;
						feces = Conductor.beatToSeconds(fuck);
					}
					else
					{
						var fuck:Float = CoolUtil.quantize(beat, snap) + increase; // (Math.floor((beat+snap) / snap) * snap);
						feces = Conductor.beatToSeconds(fuck);
					}
					FlxTween.tween(FlxG.sound.music, {time: feces}, 0.1, {ease: FlxEase.circOut});
					pauseAndSetVocalsTime();

					var dastrum = 0;

					if (curSelectedNote != null)
					{
						dastrum = curSelectedNote[0];
					}

					var secStart:Float = sectionStartTime();
					var datime:Float = (feces - secStart) - (dastrum - secStart); // idk math find out why it doesn't work on any other section other than 0
					if (curSelectedNote != null)
					{
						var controlArray:Array<Bool> = [
							 FlxG.keys.pressed.ONE, FlxG.keys.pressed.TWO, FlxG.keys.pressed.THREE, FlxG.keys.pressed.FOUR,
							FlxG.keys.pressed.FIVE, FlxG.keys.pressed.SIX, FlxG.keys.pressed.SEVEN, FlxG.keys.pressed.EIGHT
						];

						if (controlArray.contains(true))
						{
							for (i in 0...controlArray.length)
							{
								if (controlArray[i])
									if (curSelectedNote[1] == i)
										curSelectedNote[2] += datime - curSelectedNote[2] - Conductor.stepCrochet;
							}
							updateGrid();
							updateNoteUI();
						}
					}
				}
			}
			var shiftThing:Int = 1;
			if (FlxG.keys.pressed.SHIFT #if FEATURE_MOBILE_CONTROLS || touchPad.buttonY.pressed #end)
				shiftThing = 4;

			if (FlxG.keys.justPressed.D #if FEATURE_MOBILE_CONTROLS || touchPad.buttonRight.justPressed #end)
				changeSection(curSec + shiftThing);
			if (FlxG.keys.justPressed.A #if FEATURE_MOBILE_CONTROLS || touchPad.buttonLeft.justPressed #end)
			{
				if (curSec <= 0)
				{
					changeSection(_song.notes.length - 1);
				}
				else
				{
					changeSection(curSec - shiftThing);
				}
			}
		}
		else if (FlxG.keys.justPressed.ENTER)
		{
			for (i in 0...blockPressWhileTypingOn.length)
			{
				if (blockPressWhileTypingOn[i].hasFocus)
				{
					blockPressWhileTypingOn[i].hasFocus = false;
				}
			}
		}

		strumLineNotes.visible = quant.visible = vortex;

		if (FlxG.sound.music.time < 0)
		{
			FlxG.sound.music.pause();
			FlxG.sound.music.time = 0;
		}
		else if (FlxG.sound.music.time > FlxG.sound.music.length)
		{
			FlxG.sound.music.pause();
			FlxG.sound.music.time = 0;
			changeSection();
		}
		Conductor.songPosition = FlxG.sound.music.time;
		strumLineUpdateY();
		camPos.y = strumLine.y;
		for (i in 0...8)
		{
			strumLineNotes.members[i].y = strumLine.y;
			strumLineNotes.members[i].alpha = FlxG.sound.music.playing ? 1 : 0.35;
		}

		// PLAYBACK SPEED CONTROLS
		var holdingShift:Bool = FlxG.keys.pressed.SHIFT;
		var holdingLB:Bool = FlxG.keys.pressed.LBRACKET;
		var holdingRB:Bool = FlxG.keys.pressed.RBRACKET;
		var pressedLB:Bool = FlxG.keys.justPressed.LBRACKET;
		var pressedRB:Bool = FlxG.keys.justPressed.RBRACKET;

		if (!holdingShift && pressedLB || holdingShift && holdingLB)
			playbackSpeed -= 0.01;
		if (!holdingShift && pressedRB || holdingShift && holdingRB)
			playbackSpeed += 0.01;
		if (#if FEATURE_MOBILE_CONTROLS touchPad.buttonG.justPressed || #end (FlxG.keys.pressed.ALT && (pressedLB || pressedRB || holdingLB || holdingRB)))
			playbackSpeed = 1;

		if (playbackSpeed <= 0.5)
			playbackSpeed = 0.5;
		if (playbackSpeed >= 3)
			playbackSpeed = 3;

		FlxG.sound.music.pitch = playbackSpeed;
		vocals.pitch = playbackSpeed;
		opponentVocals.pitch = playbackSpeed;

		bpmTxt.text = Std.string(FlxMath.roundDecimal(Conductor.songPosition / 1000, 2))
			+ " / "
			+ Std.string(FlxMath.roundDecimal(FlxG.sound.music.length / 1000, 2))
			+ "\n\nSection: "
			+ curSec
			+ "\nBeat: "
			+ Std.string(Math.floor(curDecBeat * 10) / 10)
			+ "\nStep: "
			+ Std.string(Math.floor(curDecStep * 10) / 10)
			+ "\n\nBeat Snap: "
			+ quantization
			+ "th";

		var playedSound:Array<Bool> = [false, false, false, false]; // Prevents ouchy GF sex sounds
		curRenderedNotes.forEachAlive(function(note:Note)
		{
			note.alpha = 1;
			if (curSelectedNote != null)
			{
				var noteDataToCheck:Int = note.noteData;
				if (noteDataToCheck > -1 && note.mustPress != _song.notes[curSec].mustHitSection)
					noteDataToCheck += 4;

				if (curSelectedNote[0] == note.strumTime
					&& ((curSelectedNote[2] == null && noteDataToCheck < 0)
						|| (curSelectedNote[2] != null && curSelectedNote[1] == noteDataToCheck)))
				{
					colorSine += elapsed;
					var colorVal:Float = 0.7 + Math.sin(Math.PI * colorSine) * 0.3;
					note.color = FlxColor.fromRGBFloat(colorVal, colorVal, colorVal,
						0.999); // Alpha can't be 100% or the color won't be updated for some reason, guess i will die
				}
			}

			if (note.strumTime <= Conductor.songPosition)
			{
				note.alpha = 0.4;
				if (note.strumTime > lastConductorPos && FlxG.sound.music.playing && note.noteData > -1)
				{
					var data:Int = note.noteData % 4;
					var noteDataToCheck:Int = note.noteData;
					if (noteDataToCheck > -1 && note.mustPress != _song.notes[curSec].mustHitSection)
						noteDataToCheck += 4;
					strumLineNotes.members[noteDataToCheck].playAnim('confirm', true);
					strumLineNotes.members[noteDataToCheck].resetAnim = ((note.sustainLength / 1000) + 0.15) / playbackSpeed;
					if (!playedSound[data])
					{
						if (note.hitsoundChartEditor
							&& ((playSoundBf.checked && note.mustPress) || (playSoundDad.checked && !note.mustPress)))
						{
							final soundToPlay:String = note.mustPress ? 'snap' : 'clap';
							FlxG.sound.play(Paths.sound(soundToPlay)).pan = note.noteData < 4 ? -0.3 : 0.3; // would be coolio
							playedSound[data] = true;
						}

						data = note.noteData;
						if (note.mustPress != _song.notes[curSec].mustHitSection)
						{
							data += 4;
						}
					}
				}
			}
		});

		if (metronome.checked && lastConductorPos != Conductor.songPosition)
		{
			var metroInterval:Float = 60 / metronomeStepper.value;
			var metroStep:Int = Math.floor(((Conductor.songPosition + metronomeOffsetStepper.value) / metroInterval) / 1000);
			var lastMetroStep:Int = Math.floor(((lastConductorPos + metronomeOffsetStepper.value) / metroInterval) / 1000);
			if (metroStep != lastMetroStep)
			{
				FlxG.sound.play(Paths.sound('Metronome_Tick'));
				// trace('Ticked');
			}
		}
		lastConductorPos = Conductor.songPosition;
		super.update(elapsed);
	}

	function pauseAndSetVocalsTime()
	{
		if (vocals != null)
		{
			vocals.pause();
			vocals.time = FlxG.sound.music.time;
		}

		if (opponentVocals != null)
		{
			opponentVocals.pause();
			opponentVocals.time = FlxG.sound.music.time;
		}
	}

	function updateZoom()
	{
		var daZoom:Float = zoomList[curZoom];
		var zoomThing:String = '1 / ' + daZoom;
		if (daZoom < 1)
			zoomThing = Math.round(1 / daZoom) + ' / 1';
		zoomTxt.text = 'Zoom: ' + zoomThing;
		reloadGridLayer();
	}

	override function destroy()
	{
		Note.globalRgbShaders = [];
		Note.globalColorSwaps = [];
		backend.NoteTypesConfig.clearNoteTypesData();
		super.destroy();
	}

	var lastSecBeats:Float = 0;
	var lastSecBeatsNext:Float = 0;
	var columns:Int = 9;

	function reloadGridLayer()
	{
		gridLayer.clear();
		gridBG = FlxGridOverlay.create(1, 1, columns, Std.int(getSectionBeats() * 4 * zoomList[curZoom]));
		gridBG.antialiasing = false;
		gridBG.scale.set(GRID_SIZE, GRID_SIZE);
		gridBG.updateHitbox();

		#if lime_openal
		if (FlxG.save.data.chart_waveformInst || FlxG.save.data.chart_waveformVoices || FlxG.save.data.chart_waveformOppVoices)
		{
			updateWaveform();
		}
		#end

		var leHeight:Int = Std.int(gridBG.height);
		var foundNextSec:Bool = false;
		if (sectionStartTime(1) <= FlxG.sound.music.length)
		{
			nextGridBG = FlxGridOverlay.create(1, 1, columns, Std.int(getSectionBeats(curSec + 1) * 4 * zoomList[curZoom]));
			nextGridBG.antialiasing = false;
			nextGridBG.scale.set(GRID_SIZE, GRID_SIZE);
			nextGridBG.updateHitbox();
			leHeight = Std.int(gridBG.height + nextGridBG.height);
			foundNextSec = true;
		}
		else
			nextGridBG = new FlxSprite().makeGraphic(1, 1, FlxColor.TRANSPARENT);
		nextGridBG.y = gridBG.height;

		gridLayer.add(nextGridBG);
		gridLayer.add(gridBG);

		if (foundNextSec)
		{
			var gridBlack:FlxSprite = new FlxSprite(0, gridBG.height).makeGraphic(1, 1, FlxColor.BLACK);
			gridBlack.setGraphicSize(Std.int(GRID_SIZE * 9), Std.int(nextGridBG.height));
			gridBlack.updateHitbox();
			gridBlack.antialiasing = false;
			gridBlack.alpha = 0.4;
			gridLayer.add(gridBlack);
		}

		var gridBlackLine:FlxSprite = new FlxSprite(gridBG.x + gridBG.width - (GRID_SIZE * 4)).makeGraphic(1, 1, FlxColor.BLACK);
		gridBlackLine.setGraphicSize(2, leHeight);
		gridBlackLine.updateHitbox();
		gridBlackLine.antialiasing = false;
		gridLayer.add(gridBlackLine);

		for (i in 1...Std.int(getSectionBeats()))
		{
			var beatsep:FlxSprite = new FlxSprite(gridBG.x, (GRID_SIZE * (4 * zoomList[curZoom])) * i).makeGraphic(1, 1, 0x44FF0000);
			beatsep.scale.x = gridBG.width;
			beatsep.updateHitbox();
			if (vortex)
				gridLayer.add(beatsep);
		}

		var gridBlackLine:FlxSprite = new FlxSprite(gridBG.x + GRID_SIZE).makeGraphic(1, 1, FlxColor.BLACK);
		gridBlackLine.setGraphicSize(2, leHeight);
		gridBlackLine.updateHitbox();
		gridBlackLine.antialiasing = false;
		gridLayer.add(gridBlackLine);
		updateGrid();

		lastSecBeats = getSectionBeats();
		if (sectionStartTime(1) > FlxG.sound.music.length)
			lastSecBeatsNext = 0;
		else
			getSectionBeats(curSec + 1);
	}

	function strumLineUpdateY()
	{
		strumLine.y = getYfromStrum((Conductor.songPosition - sectionStartTime()) / zoomList[curZoom] % (Conductor.stepCrochet * 16)) / (getSectionBeats() / 4);
	}

	var waveformPrinted:Bool = true;
	var wavData:Array<Array<Array<Float>>> = [[[0], [0]], [[0], [0]]];

	var lastWaveformHeight:Int = 0;

	function updateWaveform()
	{
		#if lime_openal
		if (waveformPrinted)
		{
			var width:Int = Std.int(GRID_SIZE * 8);
			var height:Int = Std.int(gridBG.height);
			if (lastWaveformHeight != height && waveformSprite.pixels != null)
			{
				waveformSprite.pixels.dispose();
				waveformSprite.pixels.disposeImage();
				waveformSprite.makeGraphic(width, height, 0x00FFFFFF);
				lastWaveformHeight = height;
			}
			waveformSprite.pixels.fillRect(new Rectangle(0, 0, width, height), 0x00FFFFFF);
		}
		waveformPrinted = false;

		if (!FlxG.save.data.chart_waveformInst && !FlxG.save.data.chart_waveformVoices && !FlxG.save.data.chart_waveformOppVoices)
		{
			// trace('Epic fail on the waveform lol');
			return;
		}

		wavData[0][0] = [];
		wavData[0][1] = [];
		wavData[1][0] = [];
		wavData[1][1] = [];

		var steps:Int = Math.round(getSectionBeats() * 4);
		var st:Float = sectionStartTime();
		var et:Float = st + (Conductor.stepCrochet * steps);

		var sound:FlxSound = FlxG.sound.music;
		if (FlxG.save.data.chart_waveformVoices)
			sound = vocals;
		else if (FlxG.save.data.chart_waveformOppVoices)
			sound = opponentVocals;

		if (sound != null && sound._sound != null && sound._sound.__buffer != null && sound._sound.__buffer.data != null)
		{
			var bytes:Bytes = sound._sound.__buffer.data.toBytes();

			wavData = waveformData(sound._sound.__buffer, bytes, st, et, 1, wavData, Std.int(gridBG.height));
		}

		// Draws
		var gSize:Int = Std.int(GRID_SIZE * 8);
		var hSize:Int = Std.int(gSize / 2);
		var size:Float = 1;

		var leftLength:Int = (wavData[0][0].length > wavData[0][1].length ? wavData[0][0].length : wavData[0][1].length);
		var rightLength:Int = (wavData[1][0].length > wavData[1][1].length ? wavData[1][0].length : wavData[1][1].length);

		var length:Int = leftLength > rightLength ? leftLength : rightLength;

		for (index in 0...length)
		{
			var lmin:Float = FlxMath.bound(((index < wavData[0][0].length && index >= 0) ? wavData[0][0][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;
			var lmax:Float = FlxMath.bound(((index < wavData[0][1].length && index >= 0) ? wavData[0][1][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;

			var rmin:Float = FlxMath.bound(((index < wavData[1][0].length && index >= 0) ? wavData[1][0][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;
			var rmax:Float = FlxMath.bound(((index < wavData[1][1].length && index >= 0) ? wavData[1][1][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;

			waveformSprite.pixels.fillRect(new Rectangle(hSize - (lmin + rmin), index * size, (lmin + rmin) + (lmax + rmax), size), FlxColor.BLUE);
		}

		waveformPrinted = true;
		#end
	}

	function waveformData(buffer:AudioBuffer, bytes:Bytes, time:Float, endTime:Float, multiply:Float = 1, ?array:Array<Array<Array<Float>>>,
			?steps:Float):Array<Array<Array<Float>>>
	{
		#if lime_openal
		if (buffer == null || buffer.data == null)
			return [[[0], [0]], [[0], [0]]];

		var khz:Float = (buffer.sampleRate / 1000);
		var channels:Int = buffer.channels;

		var index:Int = Std.int(time * khz);

		var samples:Float = ((endTime - time) * khz);

		if (steps == null)
			steps = 1280;

		var samplesPerRow:Float = samples / steps;
		var samplesPerRowI:Int = Std.int(samplesPerRow);

		var gotIndex:Int = 0;

		var lmin:Float = 0;
		var lmax:Float = 0;

		var rmin:Float = 0;
		var rmax:Float = 0;

		var rows:Float = 0;

		var simpleSample:Bool = true; // samples > 17200;
		var v1:Bool = false;

		if (array == null)
			array = [[[0], [0]], [[0], [0]]];

		while (index < (bytes.length - 1))
		{
			if (index >= 0)
			{
				var byte:Int = bytes.getUInt16(index * channels * 2);

				if (byte > 65535 / 2)
					byte -= 65535;

				var sample:Float = (byte / 65535);

				if (sample > 0)
					if (sample > lmax)
						lmax = sample;
					else if (sample < 0)
						if (sample < lmin)
							lmin = sample;

				if (channels >= 2)
				{
					byte = bytes.getUInt16((index * channels * 2) + 2);

					if (byte > 65535 / 2)
						byte -= 65535;

					sample = (byte / 65535);

					if (sample > 0)
					{
						if (sample > rmax)
							rmax = sample;
					}
					else if (sample < 0)
					{
						if (sample < rmin)
							rmin = sample;
					}
				}
			}

			v1 = samplesPerRowI > 0 ? (index % samplesPerRowI == 0) : false;
			while (simpleSample ? v1 : rows >= samplesPerRow)
			{
				v1 = false;
				rows -= samplesPerRow;

				gotIndex++;

				var lRMin:Float = Math.abs(lmin) * multiply;
				var lRMax:Float = lmax * multiply;

				var rRMin:Float = Math.abs(rmin) * multiply;
				var rRMax:Float = rmax * multiply;

				if (gotIndex > array[0][0].length)
					array[0][0].push(lRMin);
				else
					array[0][0][gotIndex - 1] = array[0][0][gotIndex - 1] + lRMin;

				if (gotIndex > array[0][1].length)
					array[0][1].push(lRMax);
				else
					array[0][1][gotIndex - 1] = array[0][1][gotIndex - 1] + lRMax;

				if (channels >= 2)
				{
					if (gotIndex > array[1][0].length)
						array[1][0].push(rRMin);
					else
						array[1][0][gotIndex - 1] = array[1][0][gotIndex - 1] + rRMin;

					if (gotIndex > array[1][1].length)
						array[1][1].push(rRMax);
					else
						array[1][1][gotIndex - 1] = array[1][1][gotIndex - 1] + rRMax;
				}
				else
				{
					if (gotIndex > array[1][0].length)
						array[1][0].push(lRMin);
					else
						array[1][0][gotIndex - 1] = array[1][0][gotIndex - 1] + lRMin;

					if (gotIndex > array[1][1].length)
						array[1][1].push(lRMax);
					else
						array[1][1][gotIndex - 1] = array[1][1][gotIndex - 1] + lRMax;
				}

				lmin = 0;
				lmax = 0;

				rmin = 0;
				rmax = 0;
			}

			index++;
			rows++;
			if (gotIndex > steps)
				break;
		}

		return array;
		#else
		return [[[0], [0]], [[0], [0]]];
		#end
	}

	function changeNoteSustain(value:Float):Void
	{
		saveState();
		if (curSelectedNote != null)
		{
			if (curSelectedNote[2] != null)
			{
				curSelectedNote[2] += Math.ceil(value);
				curSelectedNote[2] = Math.max(curSelectedNote[2], 0);
			}
		}

		updateNoteUI();
		updateGrid();
	}

	function applyNoteSkin(note:Note, isPlayer:Bool)
	{
		var skinPath:String = isPlayer ? editorPlayerArrowSkin : editorOpponentArrowSkin;
		// Fallback for old charts / nulls
		if (skinPath == null)
			skinPath = '';
		note.texture = skinPath;
		note.setGraphicSize(GRID_SIZE, GRID_SIZE);
		note.updateHitbox();
		note.inEditor = true;
	}

	function recalculateSteps(add:Float = 0):Int
	{
		var lastChange:BPMChangeEvent = {
			stepTime: 0,
			songTime: 0,
			bpm: 0
		}
		for (i in 0...Conductor.bpmChangeMap.length)
		{
			if (FlxG.sound.music.time > Conductor.bpmChangeMap[i].songTime)
				lastChange = Conductor.bpmChangeMap[i];
		}

		curStep = lastChange.stepTime + Math.floor((FlxG.sound.music.time - lastChange.songTime + add) / Conductor.stepCrochet);
		updateBeat();

		return curStep;
	}

	function resetSection(songBeginning:Bool = false):Void
	{
		updateGrid();

		FlxG.sound.music.pause();
		// Basically old shit from changeSection???
		FlxG.sound.music.time = sectionStartTime();

		if (songBeginning)
		{
			FlxG.sound.music.time = 0;
			curSec = 0;
		}

		pauseAndSetVocalsTime();
		updateCurStep();

		updateGrid();
		updateSectionUI();
		updateWaveform();
	}

	function changeSection(sec:Int = 0, ?updateMusic:Bool = true):Void
	{
		var waveformChanged:Bool = false;
		if (_song.notes[sec] != null)
		{
			curSec = sec;
			if (updateMusic)
			{
				FlxG.sound.music.pause();

				FlxG.sound.music.time = sectionStartTime();
				pauseAndSetVocalsTime();
				updateCurStep();
			}

			var blah1:Float = getSectionBeats();
			var blah2:Float = getSectionBeats(curSec + 1);
			if (sectionStartTime(1) > FlxG.sound.music.length)
				blah2 = 0;

			if (blah1 != lastSecBeats || blah2 != lastSecBeatsNext)
			{
				reloadGridLayer();
				waveformChanged = true;
			}
			else
			{
				updateGrid();
			}
			updateSectionUI();
		}
		else
		{
			changeSection();
		}
		Conductor.songPosition = FlxG.sound.music.time;
		if (!waveformChanged)
			updateWaveform();
	}

	function updateSectionUI():Void
	{
		var sec = _song.notes[curSec];

		stepperBeats.value = getSectionBeats();
		check_mustHitSection.checked = sec.mustHitSection;
		check_gfSection.checked = sec.gfSection;
		check_altAnim.checked = sec.altAnim;
		check_changeBPM.checked = sec.changeBPM;
		stepperSectionBPM.value = sec.bpm;

		updateHeads();
	}

	var characterData:Dynamic = {
		iconP1: null,
		iconP2: null,
		vocalsP1: null,
		vocalsP2: null
	};

	function updateJsonData():Void
	{
		for (i in 1...3)
		{
			var data:CharacterFile = loadCharacterFile(Reflect.field(_song, 'player$i'));
			Reflect.setField(characterData, 'iconP$i', !characterFailed ? data.healthicon : 'face');
			Reflect.setField(characterData, 'vocalsP$i', data.vocals_file != null ? data.vocals_file : '');
		}
	}

	function updateHeads():Void
	{
		if (_song.notes[curSec].mustHitSection)
		{
			leftIcon.changeIcon(characterData.iconP1);
			rightIcon.changeIcon(characterData.iconP2);
			if (_song.notes[curSec].gfSection)
				leftIcon.changeIcon('gf');
		}
		else
		{
			leftIcon.changeIcon(characterData.iconP2);
			rightIcon.changeIcon(characterData.iconP1);
			if (_song.notes[curSec].gfSection)
				leftIcon.changeIcon('gf');
		}
	}

	var characterFailed:Bool = false;

	function loadCharacterFile(char:String):CharacterFile
	{
		characterFailed = false;

		var characterPath:String = 'characters/' + char + '.json';
		var path:String;

		#if FEATURE_MODS
		var modPath:String = Paths.modFolders(characterPath);
		if (FileSystem.exists(modPath))
			path = modPath;
		else
			path = Paths.getSharedPath(characterPath);
		#else
		path = Paths.getSharedPath(characterPath);
		#end

		if (!FileSystem.exists(path))
		{
			path = Paths.getSharedPath('characters/' + Character.DEFAULT_CHARACTER + '.json');
			characterFailed = true;
		}

		var rawJson:String = File.getContent(path);
		return cast Json.parse(rawJson, path);
	}

	function updateNoteUI():Void
	{
		if (curSelectedNote != null)
		{
			if (curSelectedNote[2] != null)
			{
				stepperSusLength.value = curSelectedNote[2];
				if (curSelectedNote[3] != null)
				{
					currentType = curNoteTypes.indexOf(curSelectedNote[3]);
					// ShadowDropdown's label is read-only; drive it via selectedIndex.
					if (currentType < 0)
						currentType = 0;
					noteTypeDropDown.selectedIndex = currentType;
				}
			}
			else
			{
				var evName:String = curSelectedNote[1][curEventSelected][0];
				var idx:Int = leEvents.indexOf(evName);
				if (idx < 0)
					idx = 0;
				eventDropDown.selectedIndex = idx;
				if (idx >= 0 && idx < eventStuff.length)
					descText.text = eventStuff[idx][1];
				value1InputText.text = curSelectedNote[1][curEventSelected][1];
				value2InputText.text = curSelectedNote[1][curEventSelected][2];
			}
			strumTimeInputText.text = '' + curSelectedNote[0];
		}
	}

	function updateGrid():Void
	{
		curRenderedNotes.forEachAlive(function(spr:Note) spr.destroy());
		curRenderedNotes.clear();
		curRenderedSustains.forEachAlive(function(spr:FlxSprite) spr.destroy());
		curRenderedSustains.clear();
		curRenderedNoteType.forEachAlive(function(spr:FlxText) spr.destroy());
		curRenderedNoteType.clear();
		nextRenderedNotes.forEachAlive(function(spr:Note) spr.destroy());
		nextRenderedNotes.clear();
		nextRenderedSustains.forEachAlive(function(spr:FlxSprite) spr.destroy());
		nextRenderedSustains.clear();

		if (_song.notes[curSec].changeBPM && _song.notes[curSec].bpm > 0)
		{
			Conductor.bpm = _song.notes[curSec].bpm;
			// trace('BPM of this section:');
		}
		else
		{
			// get last bpm
			var daBPM:Float = _song.bpm;
			for (i in 0...curSec)
				if (_song.notes[i].changeBPM)
					daBPM = _song.notes[i].bpm;
			Conductor.bpm = daBPM;
		}

		// CURRENT SECTION
		var beats:Float = getSectionBeats();
		for (i in _song.notes[curSec].sectionNotes)
		{
			var note:Note = setupNoteData(i, false);
			curRenderedNotes.add(note);
			if (note.sustainLength > 0)
			{
				curRenderedSustains.add(setupSusNote(note, beats));
			}

			if (i[3] != null && note.noteType != null && note.noteType.length > 0)
			{
				var typeInt:Int = curNoteTypes.indexOf(i[3]);
				var theType:String = '' + typeInt;
				if (typeInt < 0)
					theType = '?';

				var daText:AttachedFlxText = new AttachedFlxText(0, 0, 100, theType, 24);
				daText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE_FAST, FlxColor.BLACK);
				daText.xAdd = -32;
				daText.yAdd = 6;
				daText.borderSize = 1;
				curRenderedNoteType.add(daText);
				daText.sprTracker = note;
			}
			note.mustPress = _song.notes[curSec].mustHitSection;
			if (i[1] > 3)
				note.mustPress = !note.mustPress;

			applyNoteSkin(note, note.mustPress);
		}

		// CURRENT EVENTS
		var startThing:Float = sectionStartTime();
		var endThing:Float = sectionStartTime(1);
		for (i in _song.events)
		{
			if (endThing > i[0] && i[0] >= startThing)
			{
				var note:Note = setupNoteData(i, false);
				curRenderedNotes.add(note);

				var text:String = 'Event: ' + note.eventName + ' (' + Math.floor(note.strumTime) + ' ms)' + '\nValue 1: ' + note.eventVal1 + '\nValue 2: '
					+ note.eventVal2;
				if (note.eventLength > 1)
					text = note.eventLength + ' Events:\n' + note.eventName;

				var daText:AttachedFlxText = new AttachedFlxText(0, 0, 400, text, 12);
				daText.setFormat(Paths.font("vcr.ttf"), 12, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE_FAST, FlxColor.BLACK);
				daText.xAdd = -410;
				daText.borderSize = 1;
				if (note.eventLength > 1)
					daText.yAdd += 8;
				curRenderedNoteType.add(daText);
				daText.sprTracker = note;
				// trace('test: ' + i[0], 'startThing: ' + startThing, 'endThing: ' + endThing);
			}
		}

		// NEXT SECTION
		var beats:Float = getSectionBeats(1);
		if (curSec < _song.notes.length - 1)
		{
			for (i in _song.notes[curSec + 1].sectionNotes)
			{
				var note:Note = setupNoteData(i, true);
				note.alpha = 0.6;
				nextRenderedNotes.add(note);
				if (note.sustainLength > 0)
				{
					nextRenderedSustains.add(setupSusNote(note, beats));
				}

				note.mustPress = _song.notes[curSec + 1].mustHitSection;
				if (i[1] > 3)
					note.mustPress = !note.mustPress;
				applyNoteSkin(note, note.mustPress);
			}
		}

		// NEXT EVENTS
		var startThing:Float = sectionStartTime(1);
		var endThing:Float = sectionStartTime(2);
		for (i in _song.events)
		{
			if (endThing > i[0] && i[0] >= startThing)
			{
				var note:Note = setupNoteData(i, true);
				note.alpha = 0.6;
				nextRenderedNotes.add(note);
			}
		}
	}

	function setupNoteData(i:Array<Dynamic>, isNextSection:Bool):Note
	{
		var daNoteInfo = i[1];
		var daStrumTime = i[0];
		var daSus:Dynamic = i[2];

		var note:Note = new Note(daStrumTime, daNoteInfo % 4, null, null, true);
		if (daSus != null) // Common note
		{
			if (!Std.isOfType(i[3], String)) // Convert old note type to new note type format
			{
				i[3] = curNoteTypes[i[3]];
			}
			if (i.length > 3 && (i[3] == null || i[3].length < 1))
			{
				i.remove(i[3]);
			}
			note.sustainLength = daSus;
			note.noteType = i[3];
		}
		else // Event note
		{
			note.loadGraphic(Paths.image('eventArrow'));
			if (note.rgbShader != null)
				note.rgbShader.enabled = false;
			note.eventName = getEventName(i[1]);
			note.eventLength = i[1].length;
			if (i[1].length < 2)
			{
				note.eventVal1 = i[1][0][1];
				note.eventVal2 = i[1][0][2];
			}
			note.noteData = -1;
			daNoteInfo = -1;
		}

		note.setGraphicSize(GRID_SIZE, GRID_SIZE);
		note.updateHitbox();
		note.x = Math.floor(daNoteInfo * GRID_SIZE) + GRID_SIZE;
		if (isNextSection && _song.notes[curSec].mustHitSection != _song.notes[curSec + 1].mustHitSection)
		{
			if (daNoteInfo > 3)
			{
				note.x -= GRID_SIZE * 4;
			}
			else if (daSus != null)
			{
				note.x += GRID_SIZE * 4;
			}
		}

		var beats:Float = getSectionBeats(isNextSection ? 1 : 0);
		note.y = getYfromStrumNotes(daStrumTime - sectionStartTime(), beats);
		// if(isNextSection) note.y += gridBG.height;
		if (note.y < -150)
			note.y = -150;
		return note;
	}

	function getEventName(names:Array<Dynamic>):String
	{
		var retStr:String = '';
		var addedOne:Bool = false;
		for (i in 0...names.length)
		{
			if (addedOne)
				retStr += ', ';
			retStr += names[i][0];
			addedOne = true;
		}
		return retStr;
	}

	function setupSusNote(note:Note, beats:Float):FlxSprite
	{
		var height:Int = Math.floor(FlxMath.remapToRange(note.sustainLength, 0, Conductor.stepCrochet * 16, 0, GRID_SIZE * 16 * zoomList[curZoom])
			+ (GRID_SIZE * zoomList[curZoom])
			- GRID_SIZE / 2);
		var minHeight:Int = Std.int((GRID_SIZE * zoomList[curZoom] / 2) + GRID_SIZE / 2);
		if (height < minHeight)
			height = minHeight;
		if (height < 1)
			height = 1; // Prevents error of invalid height

		var spr:FlxSprite = new FlxSprite(note.x + (GRID_SIZE * 0.5) - 4, note.y + GRID_SIZE / 2).makeGraphic(8, height);
		return spr;
	}

	private function addSection(sectionBeats:Float = 4):Void
	{
		var sec:SwagSection = {
			sectionBeats: sectionBeats,
			bpm: _song.bpm,
			changeBPM: false,
			mustHitSection: true,
			gfSection: false,
			sectionNotes: [],
			altAnim: false
		};

		_song.notes.push(sec);
	}

	function selectNote(note:Note):Void
	{
		var noteDataToCheck:Int = note.noteData;

		if (noteDataToCheck > -1)
		{
			if (note.mustPress != _song.notes[curSec].mustHitSection)
				noteDataToCheck += 4;
			for (i in _song.notes[curSec].sectionNotes)
			{
				if (i != curSelectedNote && i.length > 2 && i[0] == note.strumTime && i[1] == noteDataToCheck)
				{
					curSelectedNote = i;
					break;
				}
			}
		}
		else
		{
			for (i in _song.events)
			{
				if (i != curSelectedNote && i[0] == note.strumTime)
				{
					curSelectedNote = i;
					curEventSelected = Std.int(curSelectedNote[1].length) - 1;
					break;
				}
			}
		}
		changeEventSelected();

		updateGrid();
		updateNoteUI();
	}

	function deleteNote(note:Note):Void
	{
		saveState();

		var noteDataToCheck:Int = note.noteData;
		if (noteDataToCheck > -1 && note.mustPress != _song.notes[curSec].mustHitSection)
			noteDataToCheck += 4;

		if (note.noteData > -1) // Normal Notes
		{
			for (i in _song.notes[curSec].sectionNotes)
			{
				if (i[0] == note.strumTime && i[1] == noteDataToCheck)
				{
					if (i == curSelectedNote)
						curSelectedNote = null;
					// FlxG.log.add('FOUND EVIL NOTE');
					_song.notes[curSec].sectionNotes.remove(i);
					break;
				}
			}
		}
		else // Events
		{
			for (i in _song.events)
			{
				if (i[0] == note.strumTime)
				{
					if (i == curSelectedNote)
					{
						curSelectedNote = null;
						changeEventSelected();
					}
					// FlxG.log.add('FOUND EVIL EVENT');
					_song.events.remove(i);
					break;
				}
			}
		}

		updateGrid();
	}

	public function doANoteThing(cs, d, style)
	{
		var delnote:Bool = false;
		if (strumLineNotes.members[d].overlaps(curRenderedNotes))
		{
			curRenderedNotes.forEachAlive(function(note:Note)
			{
				if (note.overlapsPoint(new FlxPoint(strumLineNotes.members[d].x + 1, strumLine.y + 1)) && note.noteData == d % 4)
				{
					// trace('tryin to delete note...');
					if (!delnote)
						deleteNote(note);
					delnote = true;
				}
			});
		}

		if (!delnote)
		{
			addNote(cs, d, style);
		}
	}

	function clearSong():Void
	{
		for (daSection in 0..._song.notes.length)
		{
			_song.notes[daSection].sectionNotes = [];
		}

		updateGrid();
	}

	private function addNote(strum:Null<Float> = null, data:Null<Int> = null, type:Null<Int> = null):Void
	{
		saveState();

		var noteStrum = getStrumTime(dummyArrow.y * (getSectionBeats() / 4), false) + sectionStartTime();
		var noteData = 0;
		if (Funkin.controls.mobileC)
			for (touch in FlxG.touches.list)
				noteData = Math.floor((touch.x - GRID_SIZE) / GRID_SIZE);
		else
			noteData = Math.floor((FlxG.mouse.x - GRID_SIZE) / GRID_SIZE);
		var noteSus = 0;
		var daAlt = false;
		var daType = currentType;

		if (strum != null)
			noteStrum = strum;
		if (data != null)
			noteData = data;
		if (type != null)
			daType = type;

		if (noteData > -1)
		{
			_song.notes[curSec].sectionNotes.push([noteStrum, noteData, noteSus, curNoteTypes[daType]]);
			curSelectedNote = _song.notes[curSec].sectionNotes[_song.notes[curSec].sectionNotes.length - 1];
		}
		else
		{
			var event = eventStuff[eventDropDown.selectedIndex][0];
			var text1 = value1InputText.text;
			var text2 = value2InputText.text;
			_song.events.push([noteStrum, [[event, text1, text2]]]);
			curSelectedNote = _song.events[_song.events.length - 1];
			curEventSelected = 0;
		}
		changeEventSelected();

		if (FlxG.keys.pressed.CONTROL && noteData > -1)
		{
			_song.notes[curSec].sectionNotes.push([noteStrum, (noteData + 4) % 8, noteSus, curNoteTypes[daType]]);
		}

		// trace(noteData + ', ' + noteStrum + ', ' + curSec);
		strumTimeInputText.text = '' + curSelectedNote[0];

		updateGrid();
		updateNoteUI();
	}

	function redo()
	{
		if (redos.length > 0)
		{
			undos.push(Json.stringify(_song));
			_song = Json.parse(redos.pop());
			updateGrid();
			updateSectionUI();
			updateNoteUI();
			updateHeads();
			updateWaveform();
			changeSection(curSec, false);
		}
	}

	function undo()
	{
		if (undos.length > 0)
		{
			redos.push(Json.stringify(_song));
			_song = Json.parse(undos.pop());
			updateGrid();
			updateSectionUI();
			updateNoteUI();
			updateHeads();
			updateWaveform();
			changeSection(curSec, false);
		}
	}

	function saveState()
	{
		undos.push(Json.stringify(_song));
		redos = [];
	}

	function getStrumTime(yPos:Float, doZoomCalc:Bool = true):Float
	{
		var leZoom:Float = zoomList[curZoom];
		if (!doZoomCalc)
			leZoom = 1;
		return FlxMath.remapToRange(yPos, gridBG.y, gridBG.y + gridBG.height * leZoom, 0, 16 * Conductor.stepCrochet);
	}

	function getYfromStrum(strumTime:Float, doZoomCalc:Bool = true):Float
	{
		var leZoom:Float = zoomList[curZoom];
		if (!doZoomCalc)
			leZoom = 1;
		return FlxMath.remapToRange(strumTime, 0, 16 * Conductor.stepCrochet, gridBG.y, gridBG.y + gridBG.height * leZoom);
	}

	function getYfromStrumNotes(strumTime:Float, beats:Float):Float
	{
		var value:Float = strumTime / (beats * 4 * Conductor.stepCrochet);
		return GRID_SIZE * beats * 4 * zoomList[curZoom] * value + gridBG.y;
	}

	function getNotes():Array<Dynamic>
	{
		var noteData:Array<Dynamic> = [];

		for (i in _song.notes)
		{
			noteData.push(i.sectionNotes);
		}

		return noteData;
	}

	var missingText:FlxText;
	var missingTextTimer:FlxTimer;

	function loadJson(song:String):Void
	{
		// shitty null fix, i fucking hate it when this happens
		// make it look sexier if possible
		try
		{
			final fuckinDiff:String = Difficulty.getByIndex() != NORMAL ? '-${PlayState.storyDifficulty}' : '';
			PlayState.SONG = Song.loadFromJson(song.toLowerCase() + fuckinDiff, song.toLowerCase());
			Funkin.resetState();
		}
		catch (e)
		{
			trace('ERROR! $e');

			var errorStr:String = e.toString();
			if (errorStr.startsWith('[lime.utils.Assets] ERROR:'))
				errorStr = 'Missing file: '
					+ errorStr.substring(errorStr.indexOf(Paths.formatToSongPath(PlayState.SONG.song)), errorStr.length - 1); // Missing chart
			if (errorStr.startsWith('[file_contents,assets/data/'))
				errorStr = 'Missing file: ' + errorStr.substring(27, errorStr.length - 1); // Missing chart

			if (missingText == null)
			{
				missingText = new FlxText(50, 0, FlxG.width - 100, '', 24);
				missingText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
				missingText.scrollFactor.set();
				add(missingText);
			}
			else
				missingTextTimer.cancel();

			missingText.text = 'ERROR WHILE LOADING CHART:\n$errorStr';
			missingText.screenCenter(Y);

			missingTextTimer = new FlxTimer().start(5, function(tmr:FlxTimer)
			{
				remove(missingText);
				missingText.destroy();
			});
			FlxG.sound.play(Paths.sound('cancelMenu'));
		}
	}

	function autosaveSong():Void
	{
		FlxG.save.data.autosave = Json.stringify({
			"song": _song
		});
		FlxG.save.flush();
	}

	function clearEvents()
	{
		_song.events = [];
		updateGrid();
	}

	private function saveLevel()
	{
		if (_song.events != null && _song.events.length > 1)
			_song.events.sort(sortByTime);
		var json = {
			"song": _song
		};

		var data:String = Json.stringify(json, "\t");

		if ((data != null) && (data.length > 0))
		{
			_file = new FileReference();
			_file.addEventListener(Event.COMPLETE, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data.trim(), Paths.formatToSongPath(_song.song) + ".json");
		}
	}

	function sortByTime(Obj1:Array<Dynamic>, Obj2:Array<Dynamic>):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1[0], Obj2[0]);
	}

	private function saveEvents()
	{
		if (_song.events != null && _song.events.length > 1)
			_song.events.sort(sortByTime);
		var eventsSong:Dynamic = {
			events: _song.events
		};
		var json = {
			"song": eventsSong
		}

		var data:String = Json.stringify(json, "\t");

		if ((data != null) && (data.length > 0))
		{
			_file = new FileReference();
			_file.addEventListener(Event.COMPLETE, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data.trim(), "events" + (isDiffErect ? '-erect' : "") + ".json");
		}
	}

	function onSaveComplete(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.notice("Successfully saved LEVEL DATA.");
	}

	/**
	 * Called when the save file dialog is cancelled.
	 */
	function onSaveCancel(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
	}

	/**
	 * Called if there is an error while saving the gameplay recording.
	 */
	function onSaveError(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.error("Problem saving Level data");
	}

	function getSectionBeats(?section:Null<Int> = null)
	{
		if (section == null)
			section = curSec;
		var val:Null<Float> = null;

		if (_song.notes[section] != null)
			val = _song.notes[section].sectionBeats;
		return val != null ? val : 4;
	}
}

class AttachedFlxText extends FlxText
{
	public var sprTracker:FlxSprite;
	public var xAdd:Float = 0;
	public var yAdd:Float = 0;

	public function new(X:Float = 0, Y:Float = 0, FieldWidth:Float = 0, ?Text:String, Size:Int = 8, EmbeddedFont:Bool = true)
	{
		super(X, Y, FieldWidth, Text, Size, EmbeddedFont);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (sprTracker != null)
		{
			setPosition(sprTracker.x + xAdd, sprTracker.y + yAdd);
			angle = sprTracker.angle;
			alpha = sprTracker.alpha;
		}
	}
}
