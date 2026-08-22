package psychlua;

import backend.IMusicState;
import backend.scripting.ScriptResult;
import backend.WeekData;
import backend.Highscore;
import backend.Song;
import openfl.Lib;
import openfl.utils.Assets;
import flixel.FlxBasic;
import flixel.FlxObject;
import flixel.addons.transition.FlxTransitionableState;
import flixel.addons.display.FlxRuntimeShader;
import flixel.util.typeLimit.OneOfTwo;
import cutscenes.DialogueBoxPsych;
import effects.RetroCameraFade;
import objects.StrumNote;
import objects.Note;
import objects.NoteSplash;
import objects.Character;
import states.MainMenuState;
import substates.PauseSubState;
import substates.GameOverSubstate;
import psychlua.LuaUtils;
import psychlua.LuaUtils.LuaTweenOptions;
#if FEATURE_HSCRIPT
import psychlua.HScript;
#end
import psychlua.DebugLuaText;
import psychlua.ModchartSprite;
import flixel.input.keyboard.FlxKey;
import flixel.input.gamepad.FlxGamepadInputID;
import mobile.psychlua.Functions;

class FunkinLua
{
	private var game(get, never):Dynamic;

	inline private function get_game()
		return cast FunkinLua.getCurrentMusicState();

	#if FEATURE_LUA
	public var lua:State = null;
	#end

	public var camTarget:FlxCamera;
	public var scriptName:String = '';
	public var modFolder:String = null;
	public var closed:Bool = false;

	#if FEATURE_HSCRIPT
	public var hscript:HScript = null;
	#end

	public var callbacks:Map<String, Dynamic> = new Map<String, Dynamic>();

	public static var customFunctions:Map<String, Dynamic> = new Map<String, Dynamic>();

	#if !HXLUAU_DISABLE_REQUIRE
	/*public static final MOD_REQUIRE_ALIASES:Map<String, String> = [
		'curmod' => '',
		'scripts' => 'scripts',
		'extra' => 'extra_scripts',
		'events' => 'custom_events',
		'notetypes' => 'custom_notetypes',
		'characters' => 'characters',
		'stages' => 'stages',
		'data' => 'data'
	];*/
	#end

	public function new(scriptName:String)
	{
		#if FEATURE_LUA
		var times:Float = Date.now().getTime();
		lua = LuaL.newstate();
		LuaL.openlibs(lua);
		Cffi.register(lua); 

		// trace('Luau version: ' + Lua.VERSION);
		// trace("Luau release: " + Lua.RELEASE);

		// LuaL.dostring(lua, CLENSE);

		// Luau performance tweaks
		Luau.enableCodegen(1);
		Luau.bytecodeCacheSetCapacity(256);
		Luau.setCompileOptions(2, 1, 1);

		this.scriptName = scriptName.trim();
		if (FunkinLua.getCurrentMusicState() != null)
			FunkinLua.getCurrentMusicState().luaArray.push(this);

		var myFolder:Array<String> = this.scriptName.split('/');
		#if FEATURE_MODS
		if (myFolder[0] + '/' == Paths.mods()
			&& (Mods.currentModDirectory == myFolder[1] || Mods.getGlobalMods().contains(myFolder[1]))) // this is inside mods folder
			this.modFolder = myFolder[1];
		#end

		#if !HXLUAU_DISABLE_REQUIRE
		// Give the script `require`. Scripts loaded from a file resolve relative
		// paths against their own folder; the root below is what scripts loaded
		// from a string fall back to, and what the aliases hang off of.
		/*var requireRoot:String = (modFolder != null) ? Paths.mods(modFolder) : Paths.mods();
		Require.open(lua, requireRoot);
		if (modFolder != null)
		{
			for (alias => folder in MOD_REQUIRE_ALIASES)
				Require.setAlias(lua, alias, folder.length > 0 ? '$requireRoot/$folder' : requireRoot);
		}*/
		#end

		// Lua shit
		set('Function_StopLua', ScriptResult.StopLua);
		set('Function_StopHScript', ScriptResult.StopHScript);
		set('Function_StopAll', ScriptResult.StopAll);
		set('Function_Stop', ScriptResult.Stop);
		set('Function_Continue', ScriptResult.Continue);
		set('luaDebugMode', false);
		set('luaDeprecatedWarnings', true);
		set('inChartEditor', false);

		if (FunkinLua.getCurrentMusicState() is PlayState)
		{
			set('bpm', PlayState.SONG.bpm);
			set('scrollSpeed', PlayState.SONG.speed);
			set('songName', PlayState.SONG.song);
			set('songPath', Paths.formatToSongPath(PlayState.SONG.song));
			set('curStage', PlayState.SONG.stage);

			set('isStoryMode', PlayState.isStoryMode);

			set('difficulty', PlayState.storyDifficulty);
			set('songLength', FlxG.sound.music.length);
			set('startedCountdown', false);

			set('difficultyName', Difficulty.diffToString(Difficulty.getByIndex()));
			set('difficultyPath', Paths.formatToSongPath(Difficulty.diffToString(Difficulty.getByIndex())));
			set('isErect', game.isErect);
			set('weekRaw', PlayState.storyWeek);
			set('week', WeekData.weeksList[PlayState.storyWeek]);
			set('seenCutscene', PlayState.seenCutscene);
			set('hasVocals', PlayState.SONG.needsVoices);

			set('inGameOver', false);
			set('mustHitSection', false);
			set('altAnim', false);
			set('gfSection', false);

			// Gameplay settings
			set('healthGainMult', game.healthGain);
			set('healthLossMult', game.healthLoss);

			set('playbackRate', game.playbackRate);
			set('guitarHeroSustains', game.guitarHeroSustains);
			set('instakillOnMiss', game.instakillOnMiss);
			set('botPlay', game.cpuControlled);
			set('practice', game.practiceMode);

			set('score', 0);
			set('misses', 0);
			set('hits', 0);
			set('combo', 0);

			set('rating', 0);
			set('ratingName', '');
			set('ratingFC', '');

			for (i in 0...4)
			{
				set('defaultPlayerStrumX' + i, 0);
				set('defaultPlayerStrumY' + i, 0);
				set('defaultOpponentStrumX' + i, 0);
				set('defaultOpponentStrumY' + i, 0);
			}

			// Default character
			set('defaultBoyfriendX', game.BF_X);
			set('defaultBoyfriendY', game.BF_Y);
			set('defaultOpponentX', game.DAD_X);
			set('defaultOpponentY', game.DAD_Y);
			set('defaultGirlfriendX', game.GF_X);
			set('defaultGirlfriendY', game.GF_Y);

			// Character shit
			set('boyfriendName', PlayState.SONG.player1);
			set('dadName', PlayState.SONG.player2);
			set('gfName', PlayState.SONG.gfVersion);

			// precaching
			set("addCharacterToList", function(name:String, type:String)
			{
				var charType:Int = 0;
				switch (type.toLowerCase())
				{
					case 'dad':
						charType = 1;
					case 'gf' | 'girlfriend':
						charType = 2;
				}
				cast(game, PlayState).addCharacterToList(name, charType);
			});

			// others
			set("triggerEvent", function(name:String, arg1:Dynamic, arg2:Dynamic)
			{
				var value1:String = arg1;
				var value2:String = arg2;
				cast(game, PlayState).triggerEvent(name, value1, value2, Conductor.songPosition);
				// trace('Triggered event: ' + name + ', ' + value1 + ', ' + value2);
				return true;
			});

			set("startCountdown", cast(game, PlayState).startCountdown);
			set("endSong", function()
			{
				cast(game, PlayState).KillNotes();
				cast(game, PlayState).endSong();
				return true;
			});
			set("restartSong", function(?skipTransition:Bool = false)
			{
				cast(game, PlayState).persistentUpdate = false;
				FlxG.camera.followLerp = 0;
				PlayState.startOnTime = 0;
				if (PlayState.isPixelStage && !skipTransition)
				{
					for (cam in FlxG.cameras.list)
						RetroCameraFade.fadeToBlack(cam, 10, 2);
					new FlxTimer().start(2, function(_)
					{
						Funkin.resetState();
					});
				}
				else
				{
					if (skipTransition)
					{
						FlxTransitionableState.skipNextTransIn = true;
						FlxTransitionableState.skipNextTransOut = true;
					}
					Funkin.resetState();
				}
				return true;
			});
			set("exitSong", function(?skipTransition:Bool = false)
			{
				if (skipTransition)
				{
					FlxTransitionableState.skipNextTransIn = true;
					FlxTransitionableState.skipNextTransOut = true;
				}

				Funkin.switchState(states.FreeplayState);

				#if FEATURE_DISCORD_RPC DiscordClient.resetClientID(); #end

				FlxG.sound.playMusic(Paths.music('freakyMenu'));
				PlayState.changedDifficulty = false;
				PlayState.chartingMode = false;
				cast(game, PlayState).transitioning = true;
				FlxG.camera.followLerp = 0;
				Mods.loadTopMod();
				return true;
			});
			set("getSongPosition", function()
			{
				return Conductor.songPosition;
			});

			set("getCharacterX", function(type:String)
			{
				switch (type.toLowerCase())
				{
					case 'dad' | 'opponent':
						return cast(game, PlayState).dadGroup.x;
					case 'gf' | 'girlfriend':
						return cast(game, PlayState).gfGroup.x;
					default:
						return cast(game, PlayState).boyfriendGroup.x;
				}
			});
			set("setCharacterX", function(type:String, value:Float)
			{
				switch (type.toLowerCase())
				{
					case 'dad' | 'opponent':
						cast(game, PlayState).dadGroup.x = value;
					case 'gf' | 'girlfriend':
						cast(game, PlayState).gfGroup.x = value;
					default:
						cast(game, PlayState).boyfriendGroup.x = value;
				}
			});
			set("getCharacterY", function(type:String)
			{
				switch (type.toLowerCase())
				{
					case 'dad' | 'opponent':
						return cast(game, PlayState).dadGroup.y;
					case 'gf' | 'girlfriend':
						return cast(game, PlayState).gfGroup.y;
					default:
						return cast(game, PlayState).boyfriendGroup.y;
				}
			});
			set("setCharacterY", function(type:String, value:Float)
			{
				switch (type.toLowerCase())
				{
					case 'dad' | 'opponent':
						cast(game, PlayState).dadGroup.y = value;
					case 'gf' | 'girlfriend':
						cast(game, PlayState).gfGroup.y = value;
					default:
						cast(game, PlayState).boyfriendGroup.y = value;
				}
			});
			set("cameraSetTarget", function(target:String)
			{
				var isDad:Bool = false;
				if (target == 'dad')
				{
					isDad = true;
				}
				cast(game, PlayState).moveCamera(isDad);
				return isDad;
			});
			set("setRatingPercent", function(value:Float)
			{
				cast(game, PlayState).ratingPercent = value;
			});
			set("setRatingName", function(value:String)
			{
				cast(game, PlayState).ratingName = value;
			});
			set("setRatingFC", function(value:String)
			{
				cast(game, PlayState).ratingFC = value;
			});

			set("characterDance", function(character:String)
			{
				switch (character.toLowerCase())
				{
					case 'dad':
						cast(game, PlayState).dad.dance();
					case 'gf' | 'girlfriend':
						if (cast(game, PlayState).gf != null)
							cast(game, PlayState).gf.dance();
					default:
						cast(game, PlayState).boyfriend.dance();
				}
			});

			set("setHealthBarColors", function(left:String, right:String)
			{
				cast(game, PlayState).healthBar.setColors(CoolUtil.colorFromString(left), CoolUtil.colorFromString(right));
			});
			set("setTimeBarColors", function(left:String, right:String)
			{
				cast(game, PlayState).timeBar.setColors(CoolUtil.colorFromString(left), CoolUtil.colorFromString(right));
			});

			set("startDialogue", function(dialogueFile:String, music:String = null)
			{
				var path:String;
				var formattedSong = Paths.formatToSongPath(PlayState.SONG.song);
				#if FEATURE_MODS
				var modPath:String = Paths.modsJson(formattedSong + '/' + dialogueFile);
				if (FileSystem.exists(modPath))
					path = modPath;
				else
				#end
					path = Paths.json(formattedSong + '/' + dialogueFile);

				luaTrace('startDialogue: Trying to load dialogue: ' + path);

				if (FileSystem.exists(path))
				{
					var shit:DialogueFile = DialogueBoxPsych.parseDialogue(path);
					if (shit.dialogue.length > 0)
					{
						cast(game, PlayState).startDialogue(shit, music);
						luaTrace('startDialogue: Successfully loaded dialogue', false, false, FlxColor.GREEN);
						return true;
					}
					else
					{
						luaTrace('startDialogue: Your dialogue file is badly formatted!', false, false, FlxColor.RED);
					}
				}
				else
				{
					luaTrace('startDialogue: Dialogue file not found', false, false, FlxColor.RED);
					if (cast(game, PlayState).endingSong)
					{
						cast(game, PlayState).endSong();
					}
					else
					{
						cast(game, PlayState).startCountdown();
					}
				}
				return false;
			});
			set("startVideo", function(videoFile:String, ?canSkip:Bool = true, ?forMidSong:Bool = false, ?shouldLoop:Bool = false, ?playOnLoad:Bool = true)
			{
				#if FEATURE_VIDEOS
				if (FileSystem.exists(Paths.video(videoFile)))
				{
					if (cast(game, PlayState).videoCutscene != null)
					{
						cast(game, PlayState).remove(cast(game, PlayState).videoCutscene);
						cast(game, PlayState).videoCutscene.destroy();
					}
					cast(game, PlayState).videoCutscene = cast(game, PlayState).startVideo(videoFile, forMidSong, canSkip, shouldLoop, playOnLoad);
					return true;
				}
				else
				{
					luaTrace('startVideo: Video file not found: ' + videoFile, false, false, FlxColor.RED);
				}
				return false;
				#else
				PlayState.instance.inCutscene = true;
				new FlxTimer().start(0.1, function(tmr:FlxTimer)
				{
					PlayState.instance.inCutscene = false;
					if (cast(game, PlayState).endingSong)
						cast(game, PlayState).endSong();
					else
						cast(game, PlayState).startCountdown();
				});
				return true;
				#end
			});
		}

		// Song/Week shit
		set('curBpm', Conductor.bpm);
		set('crochet', Conductor.crochet);
		set('stepCrochet', Conductor.stepCrochet);

		// Camera poo
		set('cameraX', 0);
		set('cameraY', 0);

		// Screen stuff
		set('screenWidth', FlxG.width);
		set('screenHeight', FlxG.height);

		set('curSection', 0);
		set('curBeat', 0);
		set('curStep', 0);
		set('curDecBeat', 0);
		set('curDecStep', 0);

		set('version', MainMenuState.psychEngineVersion.trim());
		set('shadowVersion', MainMenuState.shadowEngineVersion.trim());

		// Other settings
		set('downscroll', ClientPrefs.data.downScroll);
		set('middlescroll', ClientPrefs.data.middleScroll);
		set('framerate', ClientPrefs.data.framerate);
		set('ghostTapping', ClientPrefs.data.ghostTapping);
		set('hideHud', ClientPrefs.data.hideHud);
		set('timeBarType', ClientPrefs.data.timeBarType);
		set('cameraZoomOnBeat', ClientPrefs.data.camZooms);
		set('flashingLights', ClientPrefs.data.flashing);
		set('noteOffset', ClientPrefs.data.noteOffset);
		set('healthBarAlpha', ClientPrefs.data.healthBarAlpha);
		set('noResetButton', ClientPrefs.data.noReset);
		set('lowQuality', ClientPrefs.data.lowQuality);
		set('shadersEnabled', ClientPrefs.data.shaders);
		set('scriptName', scriptName);
		set('currentModDirectory', Mods.currentModDirectory);

		// Noteskin/Splash
		set('noteSkin', ClientPrefs.data.noteSkin);
		set('noteSkinPostfix', Note.getNoteSkinPostfix());
		set('splashSkin', ClientPrefs.data.splashSkin);
		set('splashSkinPostfix', NoteSplash.getSplashSkinPostfix());
		set('splashAlpha', ClientPrefs.data.splashAlpha);

		// build target (windows, mac, linux, etc.)
		set('buildTarget', LuaUtils.getBuildTarget());

		for (name => func in customFunctions)
		{
			if (func != null)
				set(name, func);
		}

		set("getRunningScripts", function()
		{
			var runningScripts:Array<String> = [];
			for (script in cast(game.luaArray, Array<Dynamic>))
			{
				final funk:FunkinLua = cast(script, FunkinLua);
				runningScripts.push(funk.scriptName);
			}

			return runningScripts;
		});

		addLocalCallback("setOnScripts", function(varName:String, arg:Dynamic, ?ignoreSelf:Bool = false, ?exclusions:Array<String> = null)
		{
			if (exclusions == null)
				exclusions = [];
			if (ignoreSelf && !exclusions.contains(scriptName))
				exclusions.push(scriptName);
			game.setOnScripts(varName, arg, exclusions);
		});
		addLocalCallback("setOnHScript", function(varName:String, arg:Dynamic, ?ignoreSelf:Bool = false, ?exclusions:Array<String> = null)
		{
			if (exclusions == null)
				exclusions = [];
			if (ignoreSelf && !exclusions.contains(scriptName))
				exclusions.push(scriptName);
			game.setOnHScript(varName, arg, exclusions);
		});
		addLocalCallback("setOnLuas", function(varName:String, arg:Dynamic, ?ignoreSelf:Bool = false, ?exclusions:Array<String> = null)
		{
			if (exclusions == null)
				exclusions = [];
			if (ignoreSelf && !exclusions.contains(scriptName))
				exclusions.push(scriptName);
			game.setOnLuas(varName, arg, exclusions);
		});

		addLocalCallback("callOnScripts",
			function(funcName:String, ?args:Array<Dynamic> = null, ?ignoreStops = false, ?ignoreSelf:Bool = true, ?excludeScripts:Array<String> = null,
					?excludeValues:Array<Dynamic> = null)
			{
				if (excludeScripts == null)
					excludeScripts = [];
				if (ignoreSelf && !excludeScripts.contains(scriptName))
					excludeScripts.push(scriptName);
				game.callOnScripts(funcName, args, ignoreStops, excludeScripts, excludeValues);
				return true;
			});
		addLocalCallback("callOnLuas",
			function(funcName:String, ?args:Array<Dynamic> = null, ?ignoreStops = false, ?ignoreSelf:Bool = true, ?excludeScripts:Array<String> = null,
					?excludeValues:Array<Dynamic> = null)
			{
				if (excludeScripts == null)
					excludeScripts = [];
				if (ignoreSelf && !excludeScripts.contains(scriptName))
					excludeScripts.push(scriptName);
				game.callOnLuas(funcName, args, ignoreStops, excludeScripts, excludeValues);
				return true;
			});
		addLocalCallback("callOnHScript",
			function(funcName:String, ?args:Array<Dynamic> = null, ?ignoreStops = false, ?ignoreSelf:Bool = true, ?excludeScripts:Array<String> = null,
					?excludeValues:Array<Dynamic> = null)
			{
				if (excludeScripts == null)
					excludeScripts = [];
				if (ignoreSelf && !excludeScripts.contains(scriptName))
					excludeScripts.push(scriptName);
				game.callOnHScript(funcName, args, ignoreStops, excludeScripts, excludeValues);
				return true;
			});

		set("callScript", function(luaFile:String, funcName:String, ?args:Array<Dynamic> = null)
		{
			if (args == null)
			{
				args = [];
			}

			var foundScript:String = findScript(luaFile);
			if (foundScript != null)
				for (luaInstance in cast(game.luaArray, Array<Dynamic>))
				{
					final funk:FunkinLua = cast(luaInstance, FunkinLua);
					if (funk.scriptName == foundScript)
					{
						funk.call(funcName, args);
						return;
					}
				}
		});

		set("getGlobalFromScript", function(luaFile:String, global:String):Dynamic // returns the global from a script
		{
			var foundScript:String = findScript(luaFile);
			if (foundScript != null)
				for (_luaInstance in cast(game.luaArray, Array<Dynamic>))
				{
					final funk:FunkinLua = cast(_luaInstance, FunkinLua);
					if (funk.scriptName == foundScript)
					{
						Lua.getglobal(funk.lua, global);
						var value:Dynamic = Convert.fromLua(funk.lua, -1);
						Lua.pop(funk.lua, 1); // remove the global from funk.lua
						return value; // return the value
					}
				}
			return null;
		});
		set("setGlobalFromScript", function(luaFile:String, global:String, val:Dynamic) // returns the global from a script
		{
			var foundScript:String = findScript(luaFile);
			if (foundScript != null)
				for (luaInstance in cast(game.luaArray, Array<Dynamic>))
				{
					final funk:FunkinLua = cast(luaInstance, FunkinLua);
					if (funk.scriptName == foundScript)
						funk.set(global, val);
				}
		});
		set("isRunning", function(luaFile:String)
		{
			var foundScript:String = findScript(luaFile);
			if (foundScript != null)
				for (luaInstance in cast(game.luaArray, Array<Dynamic>))
				{
					final funk:FunkinLua = cast(luaInstance, FunkinLua);
					if (funk.scriptName == foundScript)
						return true;
				}
			return false;
		});

		set("setVar", function(varName:String, value:Dynamic)
		{
			FunkinLua.getCurrentMusicState().variables.set(varName, value);
			return value;
		});
		set("getVar", FunkinLua.getCurrentMusicState().variables.get);

		set("addLuaScript", function(luaFile:String, ?ignoreAlreadyRunning:Bool = false) // would be dope asf.
		{
			#if FEATURE_LUA
			FunkinLua.getCurrentMusicState().startLuasNamed(luaFile, function(file:String)
			{
				var luaToLoad:String = '';
				#if FEATURE_MODS
				luaToLoad = Paths.modFolders(file);
				if (!FileSystem.exists(luaToLoad))
				#end
					luaToLoad = Paths.getSharedPath(file);

				if (FileSystem.exists(luaToLoad))
				{
					if (!ignoreAlreadyRunning)
						for (script in cast(FunkinLua.getCurrentMusicState().luaArray, Array<Dynamic>))
						{
							final funk:FunkinLua = cast(script, FunkinLua);
							if (funk.scriptName == luaToLoad)
							{
								luaTrace('addLuaScript: The script "' + luaFile + '" is already running!');
								return false;
							}
						}

					new FunkinLua(luaToLoad);
					return true;
				}
				else
				{
					luaTrace("addLuaScript: Script doesn't exist!", false, false, FlxColor.RED);
					return false;
				}
			});
			#end
		});
		set("addHScript", function(hscriptFile:String, ?ignoreAlreadyRunning:Bool = false)
		{
			#if FEATURE_HSCRIPT
			FunkinLua.getCurrentMusicState().startHScriptsNamed(hscriptFile, function(file:String)
			{
				var scriptToLoad:String = '';
				#if FEATURE_MODS
				scriptToLoad = Paths.modFolders(file);
				if (!FileSystem.exists(scriptToLoad))
				#end
				scriptToLoad = Paths.getSharedPath(file);

				if (FileSystem.exists(scriptToLoad))
				{
					if (SScript.global.exists(scriptToLoad) && !ignoreAlreadyRunning)
					{
						luaTrace('addHScript: The script "' + hscriptFile + '" is already running!');
						return false;
					}

					FunkinLua.getCurrentMusicState().initHScript(scriptToLoad);
					return true;
				}
				else
				{
					luaTrace("addHScript: Script doesn't exist!", false, false, FlxColor.RED);
					return false;
				}
			});
			#else
			luaTrace("addHScript: HScript is not supported on this platform!", false, false, FlxColor.RED);
			#end
		});
		set("removeLuaScript", function(luaFile:String)
		{
			var foundScript:String = findScript(luaFile);
			if (foundScript != null)
			{
				for (luaInstance in cast(game.luaArray, Array<Dynamic>))
				{
					final funk:FunkinLua = cast(luaInstance, FunkinLua);
					if (funk.scriptName == foundScript)
					{
						funk.stop();
						trace('Closing script ' + funk.scriptName);
						return true;
					}
				}
			}
			luaTrace('removeLuaScript: Script $luaFile isn\'t running!', false, false, FlxColor.RED);
			return false;
		});
		set("removeHScript", function(hscriptFile:String)
		{
			#if FEATURE_HSCRIPT
			function huntHScript(name:String)
			{
				for (script in cast(game.hscriptArray, Array<Dynamic>))
				{
					final hs:HScript = cast(script, HScript);
					if (hs.origin == name)
					{
						trace('Closing script ' + (hs.origin));
						hs.destroy();
						return true;
					}
				}
				return false;
			}
			var hscriptFileExt:String = haxe.io.Path.extension(hscriptFile);
			if (hscriptFileExt != null && hscriptFileExt.length > 0)
				return huntHScript(findScript(hscriptFile, hscriptFileExt));

			var huntedScripts:Bool = false;
			for (dynamicExt in cast(FunkinLua.getCurrentMusicState().scripts.hscriptExtensions, Array<Dynamic>))
			{
				final ext:String = cast(dynamicExt, String);
				if (huntHScript(findScript(hscriptFile, ext)))
					huntedScripts = true;
			}
			return huntedScripts;
			#else
			luaTrace("removeHScript: HScript is not supported on this platform!", false, false, FlxColor.RED);
			#end
		});

		set("loadSong", function(?name:String = null, ?difficultyNum:Int = -1)
		{
			if (name == null || name.length < 1)
				name = PlayState.SONG.song;
			if (difficultyNum == -1)
				difficultyNum = PlayState.storyDifficulty;

			var poop = Highscore.formatSong(name, difficultyNum);
			PlayState.SONG = Song.loadFromJson(poop, name);
			PlayState.storyDifficulty = difficultyNum;
			game.persistentUpdate = false;
			LoadingState.loadAndSwitchState(PlayState);

			FlxG.sound.music.pause();
			FlxG.sound.music.volume = 0;
			if (game.vocals != null)
			{
				game.vocals.pause();
				game.vocals.volume = 0;
			}
			FlxG.camera.followLerp = 0;
		});

		set("loadGraphic", function(variable:String, image:String, ?gridX:Int = 0, ?gridY:Int = 0)
		{
			var split:Array<String> = variable.split('.');
			var spr:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			var animated = gridX != 0 || gridY != 0;

			if (split.length > 1)
			{
				spr = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			}

			if (spr != null && image != null && image.length > 0)
			{
				spr.loadGraphic(Paths.image(image), animated, gridX, gridY);
			}
		});
		set("loadFrames", function(variable:String, image:String, spriteType:String = "sparrow")
		{
			var split:Array<String> = variable.split('.');
			var spr:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if (split.length > 1)
			{
				spr = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			}

			if (spr != null && image != null && image.length > 0)
			{
				LuaUtils.loadFrames(spr, image, spriteType);
			}
		});

		// shitass stuff for epic coders like me B)  *image of obama giving himself a medal*
		// You ain't no epic coda i am :3
		set("getObjectOrder", function(obj:String, ?group:String = null)
		{
			//if (group != null)
				//luaTrace('getObjectOrder: Second optional argument "group" argument is deprecated.', false, true, FlxColor.YELLOW);
	
			var leObj:FlxBasic = LuaUtils.getObjectDirectly(obj);
			if (leObj != null)
			{
				if (leObj.zIndex == -1)
					luaTrace('getObjectOrder: Object $obj doesn\'t belong to any group!', false, false, FlxColor.RED);

				return leObj.zIndex;
			}
			luaTrace('getObjectOrder: Object $obj doesn\'t exist!', false, false, FlxColor.RED);
			return -1;
		});
		set("setObjectOrder", function(obj:String, ?position:Int, ?group:String)
		{
			if (position != null && position < 0) position = 0;
			if (position == null) position = -1;
			var leObj:FlxBasic = LuaUtils.getObjectDirectly(obj);
			if (leObj != null)
			{
				if (group != null)
				{
					var groupOrArray:Dynamic = Reflect.getProperty(LuaUtils.getTargetInstance(), group);
					if (groupOrArray != null)
					{
						switch (Type.typeof(groupOrArray))
						{
							case TClass(Array): // Is Array
								function sortZIndex(order:Int, a:FlxBasic, b:FlxBasic):Int
								{
									if (a == null || b == null) return 0;
									return flixel.util.FlxSort.byValues(order, a.zIndex, b.zIndex);
								}
								leObj.zIndex = position;
								groupOrArray.sort(sortZIndex.bind(flixel.util.FlxSort.ASCENDING));
							default: // Is Group
								leObj.zIndex = position;
								groupOrArray.refresh();
						}
					}
					else
						luaTrace('setObjectOrder: Group $group doesn\'t exist!', false, false, FlxColor.RED);
				}
				else
				{
					var inst:Dynamic = LuaUtils.getTargetInstance();
					leObj.zIndex = position;
					inst.refresh();
				}
				return;
			}
			luaTrace('setObjectOrder: Object $obj doesn\'t exist!', false, false, FlxColor.RED);
		});

		set("mouseClicked", function(button:String)
		{
			var click:Bool = FlxG.mouse.justPressed;
			switch (button.trim().toLowerCase())
			{
				case 'middle':
					click = FlxG.mouse.justPressedMiddle;
				case 'right':
					click = FlxG.mouse.justPressedRight;
			}
			return click;
		});
		set("mousePressed", function(button:String)
		{
			var press:Bool = FlxG.mouse.pressed;
			switch (button.trim().toLowerCase())
			{
				case 'middle':
					press = FlxG.mouse.pressedMiddle;
				case 'right':
					press = FlxG.mouse.pressedRight;
			}
			return press;
		});
		set("mouseReleased", function(button:String)
		{
			var released:Bool = FlxG.mouse.justReleased;
			switch (button.trim().toLowerCase())
			{
				case 'middle':
					released = FlxG.mouse.justReleasedMiddle;
				case 'right':
					released = FlxG.mouse.justReleasedRight;
			}
			return released;
		});

		// Identical functions
		set("FlxColor", FlxColor.fromString);
		set("getColorFromName", FlxColor.fromString);
		set("getColorFromString", FlxColor.fromString);
		set("getColorFromHex", function(color:String) return FlxColor.fromString('#$color'));

		// precaaching
		set("precacheImage", function(name:String)
		{
			Paths.image(name);
		});
		set("precacheSound", Paths.sound);
		set("precacheMusic", Paths.music);

		set("cameraShake", function(camera:String, intensity:Float, duration:Float)
		{
			LuaUtils.cameraFromString(camera).shake(intensity, duration);
		});

		set("cameraFlash", function(camera:String, color:String, duration:Float, forced:Bool)
		{
			LuaUtils.cameraFromString(camera).flash(CoolUtil.colorFromString(color), duration, null, forced);
		});
		set("cameraFade", function(camera:String, color:String, duration:Float, forced:Bool)
		{
			LuaUtils.cameraFromString(camera).fade(CoolUtil.colorFromString(color), duration, false, null, forced);
		});
		set("getMouseX", function(camera:String)
		{
			var cam:FlxCamera = LuaUtils.cameraFromString(camera);
			return FlxG.mouse.getViewPosition(cam).x;
		});
		set("getMouseY", function(camera:String)
		{
			var cam:FlxCamera = LuaUtils.cameraFromString(camera);
			return FlxG.mouse.getViewPosition(cam).y;
		});

		set("getMidpointX", function(variable:String)
		{
			var split:Array<String> = variable.split('.');
			var obj:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if (split.length > 1)
			{
				obj = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			}
			if (obj != null)
				return obj.getMidpoint().x;

			return 0;
		});
		set("getMidpointY", function(variable:String)
		{
			var split:Array<String> = variable.split('.');
			var obj:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if (split.length > 1)
			{
				obj = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			}
			if (obj != null)
				return obj.getMidpoint().y;

			return 0;
		});
		set("getGraphicMidpointX", function(variable:String)
		{
			var split:Array<String> = variable.split('.');
			var obj:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if (split.length > 1)
			{
				obj = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			}
			if (obj != null)
				return obj.getGraphicMidpoint().x;

			return 0;
		});
		set("getGraphicMidpointY", function(variable:String)
		{
			var split:Array<String> = variable.split('.');
			var obj:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if (split.length > 1)
			{
				obj = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			}
			if (obj != null)
				return obj.getGraphicMidpoint().y;

			return 0;
		});
		set("getScreenPositionX", function(variable:String, ?camera:String)
		{
			var split:Array<String> = variable.split('.');
			var obj:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if (split.length > 1)
			{
				obj = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			}
			if (obj != null)
				return obj.getScreenPosition().x;

			return 0;
		});
		set("getScreenPositionY", function(variable:String, ?camera:String)
		{
			var split:Array<String> = variable.split('.');
			var obj:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if (split.length > 1)
			{
				obj = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			}
			if (obj != null)
				return obj.getScreenPosition().y;

			return 0;
		});

		// mod settings
		#if FEATURE_MODS
		addLocalCallback("getModSetting", function(saveTag:String, ?modName:String = null)
		{
			if (modName == null)
			{
				if (this.modFolder == null)
				{
					FunkinLua.luaTrace('getModSetting: Argument #2 is null and script is not inside a packed Mod folder!', false, false, FlxColor.RED);
					return null;
				}
				modName = this.modFolder;
			}
			return LuaUtils.getModSetting(saveTag, modName);
		});
		addLocalCallback("setModSetting", function(saveTag:String, value:Dynamic, ?modName:String = null)
		{
			if (modName == null)
			{
				if (this.modFolder == null)
				{
					FunkinLua.luaTrace('setModSetting: Argument #3 is null and script is not inside a packed Mod folder!', false, false, FlxColor.RED);
					return null;
				}
				modName = this.modFolder;
			}
			return LuaUtils.setModSetting(saveTag, value, modName);
		});
		#end

		set("debugPrint", function(text:Dynamic = '', color:String = 'WHITE') FunkinLua.getCurrentMusicState().addTextToDebug(text, CoolUtil.colorFromString(color)));

		addLocalCallback("close", function()
		{
			closed = true;
			trace('Closing script $scriptName');
			return closed;
		});

		#if FEATURE_DISCORD_RPC DiscordClient.addLuaCallbacks(this); #end
		#if FEATURE_HSCRIPT HScript.implement(this); #end
		ScriptedState.implement(this);
		ReflectionFunctions.implement(this);
		TextFunctions.implement(this);
		ExtraFunctions.implement(this);
		ShaderFunctions.implement(this);
		DeprecatedFunctions.implement(this);
		MobileFunctions.implement(this);
		FlixelAnimateFunctions.implement(this);
		VideoFunctions.implement(this);
		LuaSpriteFunctions.implement(this);
		TweenFunctions.implement(this);
		SoundFunctions.implement(this);
		ScoreFunctions.implement(this);
		NoteTweenFunctions.implement(this);
		#if android AndroidFunctions.implement(this); #end

		try
		{
			var isString:Bool = !FileSystem.exists(scriptName);
			var status:Int = 0;
			if (!isString)
				status = #if FEATURE_MODS sys.FileSystem.exists(scriptName) ? LuaL.dofile(lua, scriptName) : #end LuaL.dostring(lua, File.getContent(scriptName));
			else
				status = LuaL.dostring(lua, scriptName);

			if (status != 0)
			{
				var errorMsg:String = getErrorMessage(status);
				trace(errorMsg);
				CoolUtil.showPopUp(errorMsg, 'Error on lua script!');
				luaTrace('$scriptName\n$errorMsg', true, false, FlxColor.RED);
				lua = null;
				return;
			}
			if (isString)
				scriptName = 'unknown';
		}
		catch (e:Dynamic)
		{
			trace('$scriptName: $e');
			return;
		}
		call('onCreate', []);
		trace('lua file loaded succesfully: $scriptName (${Std.int(Date.now().getTime() - times)}ms)');
		#end
	}

	// main
	public var lastCalledFunction:String = '';

	public static var lastCalledScript:FunkinLua = null;

	public function call(func:String, args:Array<Dynamic>):Dynamic
	{
		if (closed)
			return ScriptResult.Continue;

		lastCalledFunction = func;
		lastCalledScript = this;
		#if FEATURE_LUA
		try
		{
			if (lua == null)
				return ScriptResult.Continue;

			Lua.getglobal(lua, func);
			var type:Int = Lua.type(lua, -1);

			if (type != Lua.TFUNCTION)
			{
				if (type > Lua.TNIL)
					luaTrace("ERROR (" + func + "): attempt to call a " + LuaUtils.typeToString(type) + " value", false, false, FlxColor.RED);

				Lua.pop(lua, 1);
				return ScriptResult.Continue;
			}

			for (arg in args)
				Convert.toLua(lua, arg);
			var status:Int = Lua.pcall(lua, args.length, 1, 0);

			// Checks if it's not successful, then show a error.
			if (status != Lua.OK)
			{
				var errorStr:String;
				final rawErr = Lua.tostring(lua, -1);
				var error:String = rawErr != null ? rawErr.toString() : null;
				if (error != null)
				{
					LuaL.traceback(lua, lua, error, 2);
					final rawStr = Lua.tostring(lua, -1);
					errorStr = rawStr != null ? rawStr.toString() : getErrorMessage(status);
					Lua.pop(lua, 2);
				}
				else
				{
					errorStr = getErrorMessage(status);
				}
				luaTrace("ERROR (" + func + "): " + errorStr, false, false, FlxColor.RED);
				return ScriptResult.Continue;
			}

			// If successful, pass and then return the result.
			var result:Dynamic = cast Convert.fromLua(lua, -1);
			if (result == null)
				result = ScriptResult.Continue;

			Lua.pop(lua, 1);
			if (closed)
				stop();
			return result;
		}
		catch (e:Dynamic)
		{
			trace(e);
		}
		#end
		return ScriptResult.Continue;
	}

	public function set(variable:String, data:Dynamic)
	{
		#if FEATURE_LUA
		if (lua == null)
			return;

		if (Type.typeof(data) == TFunction)
		{
			Convert.addCallback(lua, variable, data);
			return;
		}

		Convert.toLua(lua, data);
		Lua.setglobal(lua, variable);
		#end
	}

	public function stop()
	{
		closed = true;

		#if FEATURE_LUA
		if (lua == null)
		{
			return;
		}
		Lua.close(lua);
		lua = null;
		#end
		#if FEATURE_HSCRIPT
		if (hscript != null)
		{
			hscript.destroy();
			hscript = null;
		}
		#end
	}

	public static function luaTrace(text:String, ignoreCheck:Bool = false, deprecated:Bool = false, color:FlxColor = FlxColor.WHITE)
	{
		if (ignoreCheck || getBool('luaDebugMode'))
		{
			if (deprecated && !getBool('luaDeprecatedWarnings'))
			{
				return;
			}
			#if (FEATURE_LUA || FEATURE_HSCRIPT)
			FunkinLua.getCurrentMusicState().addTextToDebug(text, color);
			#end
		}
	}

	public static function getBool(variable:String)
	{
		if (lastCalledScript == null)
			return false;

		#if FEATURE_LUA
		var lua:State = lastCalledScript.lua;
		if (lua == null)
			return false;

		Lua.getglobal(lua, variable);
		final result:Bool = Lua.toboolean(lua, -1) == 1;
		Lua.pop(lua, 1);
		return result;
		#else
		return false;
		#end
	}

	function findScript(scriptFile:String, ext:String = '.lua')
	{
		if (!scriptFile.endsWith(ext))
			scriptFile += ext;

		var sharedPath:String = Paths.getSharedPath(scriptFile);

		#if FEATURE_MODS
		var modPath:String = Paths.modFolders(scriptFile);
		if (FileSystem.exists(modPath))
			return modPath;
		#end

		if (FileSystem.exists(sharedPath))
			return sharedPath;

		if (ext == '.lua')
		{
			var luauFile:String = scriptFile.substr(0, scriptFile.length - 4) + '.luau';
			var sharedLuauPath:String = Paths.getSharedPath(luauFile);
			#if FEATURE_MODS
			var modLuauPath:String = Paths.modFolders(luauFile);
			if (FileSystem.exists(modLuauPath))
				return modLuauPath;
			#end
			if (FileSystem.exists(sharedLuauPath))
				return sharedLuauPath;
		}

		return null;
	}

	public function getErrorMessage(status:Int):String
	{
		#if FEATURE_LUA
		final rawV = Lua.tostring(lua, -1);
		var v:String = rawV != null ? rawV.toString() : null;
		Lua.pop(lua, 1);

		if (v != null)
			v = v.trim();
		if (v == null || v == "")
		{
			switch (status)
			{
				case type if (type == Lua.ERRRUN):
					return "Runtime Error";
				case type if (type == Lua.ERRMEM):
					return "Memory Allocation Error";
				case type if (type == Lua.ERRERR):
					return "Critical Error";
			}
			return "Unknown Error";
		}

		return v;
		#else
		return null;
		#end
	}

	public function addLocalCallback(name:String, myFunction:Dynamic)
	{
		#if FEATURE_LUA
		callbacks.set(name, myFunction);
		Convert.addCallback(lua, name, null); // just so that it gets called
		#end
	}

	public var runtimeShaders:Map<String, Array<String>> = new Map<String, Array<String>>();

	public function initLuaShader(name:String)
	{
		if (!ClientPrefs.data.shaders)
			return false;

		if (runtimeShaders.exists(name))
		{
			var shaderData:Array<String> = runtimeShaders.get(name);
			if (shaderData != null && (shaderData[0] != null || shaderData[1] != null))
			{
				luaTrace('Shader $name was already initialized!');
				return true;
			}
		}

		var foldersToCheck:Array<String> = [];
		#if FEATURE_MODS
		if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
			foldersToCheck.push(Paths.mods(Mods.currentModDirectory + '/shaders/'));
		for (mod in Mods.getGlobalMods())
			foldersToCheck.push(Paths.mods(mod + '/shaders/'));
		#end
		foldersToCheck.push(Paths.getSharedPath('shaders/'));

		for (folder in foldersToCheck)
		{
			if (!FileSystem.exists(folder))
				continue;

			var fragPath:String = folder + name + '.frag';
			var vertPath:String = folder + name + '.vert';
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
				// trace('Found shader $name!');
				return true;
			}
		}

		luaTrace('Missing shader $name .frag AND .vert files!', false, false, FlxColor.RED);
		return false;
	}

	private static var lastMusicState:Dynamic = null;
	public static function getCurrentMusicState():IMusicState
	{
		final s = FlxG.state;

		if (Std.isOfType(s, ScriptedSubState) || Std.isOfType(s.subState, ScriptedSubState))
			return lastMusicState;

		if (s.subState != null && Std.isOfType(s.subState, MusicBeatSubstate))
			return lastMusicState = cast(s.subState, MusicBeatSubstate);

		return Std.isOfType(s, MusicBeatState) ? lastMusicState = cast(s, MusicBeatState) : null;
	}
}

#if FEATURE_LUA
typedef State = cpp.RawPointer<Lua_State>;
#end
