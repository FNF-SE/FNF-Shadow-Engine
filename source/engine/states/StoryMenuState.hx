package states;

import backend.WeekData;
import backend.Highscore;
import backend.Song;
import flixel.group.FlxGroup;
import objects.MenuItem;
import objects.MenuCharacter;
import substates.GameplayChangersSubstate;
import substates.ResetScoreSubState;

class StoryMenuState extends MusicBeatState
{
	public static var weekCompleted:Map<String, Bool> = new Map<String, Bool>();
	static var curWeek:Int = 0;
	static var curDifficulty:Int = -1; //read freeplay for more info
	var grpWeekText:FlxTypedGroup<MenuItem>;
	var grpWeekCharacters:FlxTypedGroup<MenuCharacter>;
	var grpLocks:FlxTypedGroup<FlxSprite>;
	var difficultySelectors:FlxGroup;
	var scoreText:FlxText;
	var txtWeekTitle:FlxText;
	var txtTracklist:FlxText;
	var bgSprite:FlxSprite;
	var sprDifficulty:FlxSprite;
	var leftArrow:FlxSprite;
	var rightArrow:FlxSprite;
	var tweenDifficulty:FlxTween;
	var loadedWeeks:Array<WeekData> = [];
	var blockInput:Bool = false;
	var lerpScore:Int = 0;
	var intendedScore:Int = 0;

	override function create():Void
	{
		#if FEATURE_DISCORD_RPC
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		Paths.clearStoredMemory();

		PlayState.isStoryMode = true;
		WeekData.reloadWeekFiles(true);

		if (curWeek >= WeekData.weeksList.length)
			curWeek = 0;

		persistentUpdate = persistentDraw = true;

		final ui_tex:flixel.graphics.frames.FlxAtlasFrames = Paths.getSparrowAtlas('campaign_menu_UI_assets');

		bgSprite = new FlxSprite(0, 56);

		add(grpWeekText = new FlxTypedGroup<MenuItem>());

		add(new FlxSprite().makeGraphic(FlxG.width, 56, FlxColor.BLACK));

		grpWeekCharacters = new FlxTypedGroup<MenuCharacter>();

		add(grpLocks = new FlxTypedGroup<FlxSprite>());

		var num:Int = 0;
		for (i in 0...WeekData.weeksList.length)
		{
			final weekFile:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
			final isLocked:Bool = weekIsLocked(WeekData.weeksList[i]);
			if (isLocked && weekFile.hiddenUntilUnlocked) continue;

			loadedWeeks.push(weekFile);
			WeekData.setDirectoryFromWeek(weekFile);

			final weekThing:MenuItem = new MenuItem(0, bgSprite.y + 396, WeekData.weeksList[i]);
			weekThing.y += (weekThing.height + 20) * num;
			weekThing.targetY = num;
			weekThing.screenCenter(X);
			grpWeekText.add(weekThing);

			if (isLocked)
			{
				final lock:FlxSprite = new FlxSprite(weekThing.width + 10 + weekThing.x);
				lock.antialiasing = ClientPrefs.data.antialiasing;
				lock.frames = ui_tex;
				lock.animation.addByPrefix('lock', 'lock');
				lock.animation.play('lock');
				lock.ID = i;
				grpLocks.add(lock);
			}
			num++;
		}

		WeekData.setDirectoryFromWeek(loadedWeeks[0]);

		for (char in 0...3)
		{
			final weekCharacterThing:MenuCharacter = new MenuCharacter((FlxG.width * 0.25) * (1 + char) - 150, loadedWeeks[0].weekCharacters[char]);
			weekCharacterThing.y += 70;
			grpWeekCharacters.add(weekCharacterThing);
		}

		add(difficultySelectors = new FlxGroup());

		final weekTxt:MenuItem = grpWeekText.members[0];

		difficultySelectors.add(leftArrow = new FlxSprite(weekTxt.x + weekTxt.width + 10, weekTxt.y + 10));
		leftArrow.antialiasing = ClientPrefs.data.antialiasing;
		leftArrow.frames = ui_tex;
		leftArrow.animation.addByPrefix('idle', "arrow left");
		leftArrow.animation.addByPrefix('press', "arrow push left");
		leftArrow.animation.play('idle');

		Difficulty.resetList();

		difficultySelectors.add(sprDifficulty = new FlxSprite(0, leftArrow.y));
		sprDifficulty.antialiasing = ClientPrefs.data.antialiasing;

		difficultySelectors.add(rightArrow = new FlxSprite(leftArrow.x + 376, leftArrow.y));
		rightArrow.antialiasing = ClientPrefs.data.antialiasing;
		rightArrow.frames = ui_tex;
		rightArrow.animation.addByPrefix('idle', 'arrow right');
		rightArrow.animation.addByPrefix('press', "arrow push right", 24, false);
		rightArrow.animation.play('idle');

		add(new FlxSprite(0, 56).makeGraphic(FlxG.width, 386, 0xFFF9CF51));

		add(bgSprite);
		add(grpWeekCharacters);

		final tracksSprite:FlxSprite = new FlxSprite(FlxG.width * 0.07, bgSprite.y + 425, Paths.image('Menu_Tracks'));
		tracksSprite.antialiasing = ClientPrefs.data.antialiasing;
		add(tracksSprite);

		add(txtTracklist = new FlxText(FlxG.width * 0.05, tracksSprite.y + 60, 0, "", 32));
		txtTracklist.setFormat(Paths.font("vcr.ttf"), 32, 0xFFE55777, CENTER);

		add(scoreText = new FlxText(10, 10, 0, "WEEK SCORE: 0", 36));
		scoreText.setFormat(Paths.font("vcr.ttf"), 32);

		add(txtWeekTitle = new FlxText(FlxG.width * 0.7, 10, 0, "", 32));
		txtWeekTitle.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);
		txtWeekTitle.alpha = 0.7;

		changeWeek();

		#if FEATURE_MOBILE_CONTROLS
		addTouchPad("LEFT_FULL", "A_B_X_Y");
		#end

		super.create();
		
		Paths.clearUnusedMemory();
	}

	override function closeSubState():Void
	{
		persistentUpdate = true;
		changeWeek();
		super.closeSubState();

		#if FEATURE_MOBILE_CONTROLS
		removeTouchPad();
		addTouchPad("LEFT_FULL", "A_B_X_Y");
		#end
	}

	override function update(elapsed:Float):Void
	{
		lerpScore = Math.floor(FlxMath.lerp(intendedScore, lerpScore, Math.exp(-elapsed * 30)));
		if (Math.abs(intendedScore - lerpScore) < 10)
			lerpScore = intendedScore;

		scoreText.text = 'WEEK SCORE: ${FlxStringUtil.formatMoney(lerpScore, false)}';

		if (!blockInput)
		{
			if(loadedWeeks.length >= 1)
			{
				if (Funkin.controls.UI_UP_P || Funkin.controls.UI_DOWN_P)
					changeWeek(Funkin.controls.UI_UP_P ? -1 : 1, true);

				if (FlxG.mouse.deltaWheel.y != 0)
					changeWeek(-Math.round(FlxG.mouse.deltaWheel.y));
			}

			rightArrow.animation.play(Funkin.controls.UI_RIGHT ? 'press' : 'idle');
			leftArrow.animation.play(Funkin.controls.UI_LEFT ? 'press' : 'idle');

			if (Funkin.controls.UI_LEFT_P || Funkin.controls.UI_RIGHT_P)
				changeDifficulty(Funkin.controls.UI_LEFT_P ? -1 : 1, true);

			if (FlxG.keys.justPressed.CONTROL #if FEATURE_MOBILE_CONTROLS || touchPad.buttonX.justPressed #end)
			{
				persistentUpdate = false;
				switchSubState(GameplayChangersSubstate);

				#if FEATURE_MOBILE_CONTROLS
				removeTouchPad();
				#end
			}
			else if (Funkin.controls.RESET #if FEATURE_MOBILE_CONTROLS || touchPad.buttonY.justPressed #end)
			{
				persistentUpdate = false;
				switchSubState(ResetScoreSubState, ['', curDifficulty, '', curWeek]);

				#if FEATURE_MOBILE_CONTROLS
				removeTouchPad();
				#end
			}
			else if (Funkin.controls.ACCEPT)
				selectWeek();

			if (Funkin.controls.BACK)
			{
				FlxG.sound.play(Paths.sound('cancelMenu'));
				blockInput = true;
				Funkin.switchState(MainMenuState);
			}
		}

		super.update(elapsed);

		grpLocks.forEach((lock:FlxSprite) ->
		{
			lock.y = grpWeekText.members[lock.ID].y;
			lock.visible = lock.y > FlxG.height / 2;
		});
	}

	function selectWeek():Void
	{
		if (!weekIsLocked(loadedWeeks[curWeek].fileName))
		{
			try
			{
				PlayState.storyPlaylist = loadedWeeks[curWeek].songs.map((s:Dynamic) -> s[0]);
				PlayState.isStoryMode = blockInput = true;

				callOnScripts('onSelectWeek');

				PlayState.storyDifficulty = curDifficulty;
				PlayState.SONG = Song.loadFromJson(PlayState.storyPlaylist[0].toLowerCase() + Difficulty.getFilePath(curDifficulty), PlayState.storyPlaylist[0].toLowerCase());
				PlayState.campaignScore = PlayState.campaignMisses = 0;
			}
			catch (e:Dynamic)
			{
				trace('ERROR! $e');
				blockInput = false;
				return;
			}

			FlxG.sound.play(Paths.sound('confirmMenu'));

			grpWeekText.members[curWeek].isFlashing = true;
			for (char in grpWeekCharacters.members)
			{
				if (char.character != '' && char.hasConfirmAnimation)
					char.animation.play('confirm');
			}

			new FlxTimer().start(1, (tmr:FlxTimer) ->
			{
				LoadingState.prepareToSong();
				LoadingState.loadAndSwitchState(PlayState, true);
				FreeplayState.destroyFreeplayVocals();
			});

			#if (FEATURE_MODS && FEATURE_DISCORD_RPC)
			DiscordClient.loadModRPC();
			#end
		}
		else
			FlxG.sound.play(Paths.sound('cancelMenu'));
	}

	function changeDifficulty(change:Int = 0, tween:Bool = false):Void
	{
		//read changeDiff function in freeplay for more info
		if (curDifficulty == -1)
		{
			final normalIndex:Int = Difficulty.list.indexOf(NORMAL);
			curDifficulty = normalIndex != -1 ? normalIndex : 0;
		}
		else
			curDifficulty = (curDifficulty + change + Difficulty.list.length) % Difficulty.list.length;

		callOnScripts('onChangeDifficulty');
		WeekData.setDirectoryFromWeek(loadedWeeks[curWeek]);

		final diff:String = Difficulty.diffToString(Difficulty.list[curDifficulty]);
		final spriteSheetExists:Bool = Paths.fileExists('images/menudifficulties/$diff.xml', TEXT);

		if (spriteSheetExists)
		{
			sprDifficulty.frames = Paths.getSparrowAtlas('menudifficulties/$diff');
			sprDifficulty.animation.addByPrefix('idle', 'idle', 24, true);
			sprDifficulty.animation.play('idle');
		}
		else
			sprDifficulty.loadGraphic(Paths.image('menudifficulties/${Paths.formatToSongPath(diff)}'));

		final baseX:Float = leftArrow.x + (spriteSheetExists ? 50 : 60);
		final centerOffset:Float = (310 - sprDifficulty.width) * 0.33;

		sprDifficulty.setPosition(baseX + centerOffset, leftArrow.y + (spriteSheetExists ? 5 : 15));
		sprDifficulty.updateHitbox();

		if(tween)
		{
			sprDifficulty.y -= 30;
			sprDifficulty.alpha = 0;

			tweenDifficulty?.cancel();
			tweenDifficulty = FlxTween.tween(sprDifficulty, {y: leftArrow.y + (spriteSheetExists ? 5 : 15), alpha: 1}, 0.1, {
				ease: FlxEase.quadOut,
				onComplete: (twn:FlxTween) -> tweenDifficulty = null
			});
		}

		intendedScore = Highscore.getWeekScore(loadedWeeks[curWeek].fileName, curDifficulty);
	}

	function changeWeek(change:Int = 0, playSound:Bool = false):Void
	{
		if(playSound)
			FlxG.sound.play(Paths.sound('scrollMenu'));

		curWeek = (curWeek + change + loadedWeeks.length) % loadedWeeks.length;

		callOnScripts('onChangeWeek');

		final leWeek:WeekData = loadedWeeks[curWeek];
		WeekData.setDirectoryFromWeek(leWeek);

		txtWeekTitle.text = leWeek.storyName.toUpperCase();
		txtWeekTitle.x = FlxG.width - (txtWeekTitle.width + 10);

		var bullShit:Int = 0;

		final unlocked:Bool = !weekIsLocked(leWeek.fileName);
		for (item in grpWeekText.members)
		{
			item.targetY = bullShit - curWeek;
			item.alpha = item.targetY == Std.int(0) && unlocked ? 1 : 0.6;
			bullShit++;
		}

		final assetName:String = leWeek.weekBackground;
		if (assetName == null || assetName.length < 1)
			bgSprite.visible = false;
		else {
			bgSprite.visible = true;
			bgSprite.loadGraphic(Paths.image('menubackgrounds/menu_$assetName'));
		}

		PlayState.storyWeek = curWeek;

		Difficulty.loadFromWeek();
		difficultySelectors.visible = unlocked;
		updateText();

		changeDifficulty();
	}

	function weekIsLocked(name:String):Bool
	{
		final leWeek:WeekData = WeekData.weeksLoaded.get(name);
		return !leWeek.startUnlocked && leWeek.weekBefore.length > 0 && (!weekCompleted.exists(leWeek.weekBefore) || !weekCompleted.get(leWeek.weekBefore));
	}

	function updateText():Void
	{
		final week:WeekData = loadedWeeks[curWeek];

		for (i in 0...grpWeekCharacters.length)
			grpWeekCharacters.members[i].changeCharacter(week.weekCharacters[i]);

		txtTracklist.text = week.songs.map((s:Dynamic) -> s[0]).join('\n').toUpperCase();
		txtTracklist.screenCenter(X);
		txtTracklist.x -= FlxG.width * 0.35;

		intendedScore = Highscore.getWeekScore(loadedWeeks[curWeek].fileName, curDifficulty);
	}
}
