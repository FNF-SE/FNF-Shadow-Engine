package backend;

import backend.scripting.*;
import flixel.addons.transition.FlxTransitionableState;
import flixel.util.FlxSave;
import backend.rendering.PsychCamera;
import haxe.io.Path;

class MusicBeatState extends FlxTransitionableState implements IMusicState
{
	public var stateInstance:FlxState = null;

	private var curSection:Int = 0;
	private var stepsToDo:Int = 0;

	private var curStep:Int = 0;
	private var curBeat:Int = 0;

	private var curDecStep:Float = 0;
	private var curDecBeat:Float = 0;

	public var scripts(default, null):ScriptManager;

	#if FEATURE_HSCRIPT
	public var hscriptArray(get, never):Array<HScript>;
	inline function get_hscriptArray() return scripts.hscriptArray;
	#end

	public var modchartTweens:Map<String, FlxTween> = new Map<String, FlxTween>();
	public var modchartSprites:Map<String, ModchartSprite> = new Map<String, ModchartSprite>();
	public var modchartTimers:Map<String, FlxTimer> = new Map<String, FlxTimer>();
	public var modchartSounds:Map<String, FlxSound> = new Map<String, FlxSound>();
	public var modchartTexts:Map<String, FlxText> = new Map<String, FlxText>();
	public var modchartSaves:Map<String, FlxSave> = new Map<String, FlxSave>();
	public var modchartCameras:Map<String, FlxCamera> = new Map<String, FlxCamera>();

	#if FEATURE_LUA
	public var luaArray(get, never):Array<FunkinLua>;
	inline function get_luaArray() return scripts.luaArray;
	#end

	#if (FEATURE_LUA || FEATURE_HSCRIPT)
	private var luaDebugGroup:FlxTypedGroup<psychlua.DebugLuaText>;
	private var luaDebugCam:ShadowCamera;
	private var currentClassName:String;
	#end

	public var variables:Map<String, Dynamic> = new Map<String, Dynamic>();

	@:deprecated("`MusicBeatState.controls` is deprecated. Use `Funkin.controls` instead.")
	public var controls(get, never):Controls;

	private function get_controls()
	{
		return Funkin.controls;
	}

	#if FEATURE_MOBILE_CONTROLS
	public var touchPad:TouchPad;
	public var touchPadCam:ShadowCamera;
	public var luaTouchPad:TouchPad;
	public var luaTouchPadCam:ShadowCamera;
	public var mobileControls:IMobileControls;
	public var mobileControlsCam:ShadowCamera;

	public function addTouchPad(DPad:String, Action:String)
	{
		touchPad = new TouchPad(DPad, Action);
		add(touchPad);
	}

	public function removeTouchPad()
	{
		if (touchPad != null)
		{
			remove(touchPad);
			touchPad = FlxDestroyUtil.destroy(touchPad);
		}

		if (touchPadCam != null)
		{
			FlxG.cameras.remove(touchPadCam);
			touchPadCam = FlxDestroyUtil.destroy(touchPadCam);
		}
	}

	public function addMobileControls(defaultDrawTarget:Bool = false):Void
	{
		var extraMode = MobileData.extraActions.get(ClientPrefs.data.extraButtons);

		switch (MobileData.mode)
		{
			case 0: // RIGHT_FULL
				mobileControls = new TouchPad('RIGHT_FULL', 'NONE', extraMode);
			case 1: // LEFT_FULL
				mobileControls = new TouchPad('LEFT_FULL', 'NONE', extraMode);
			case 2: // CUSTOM
				mobileControls = MobileData.getTouchPadCustom(new TouchPad('RIGHT_FULL', 'NONE', extraMode));
			case 3: // HITBOX
				mobileControls = new Hitbox(extraMode);
		}

		mobileControls.instance = MobileData.setButtonsColors(mobileControls.instance);
		mobileControlsCam = new ShadowCamera();
		mobileControlsCam.bgColor.alpha = 0;
		FlxG.cameras.add(mobileControlsCam, defaultDrawTarget);

		mobileControls.instance.cameras = [mobileControlsCam];
		mobileControls.instance.visible = false;
		add(mobileControls.instance);
	}

	public function removeMobileControls()
	{
		if (mobileControls != null)
		{
			remove(mobileControls.instance);
			mobileControls.instance = FlxDestroyUtil.destroy(mobileControls.instance);
			mobileControls = null;
		}

		if (mobileControlsCam != null)
		{
			FlxG.cameras.remove(mobileControlsCam);
			mobileControlsCam = FlxDestroyUtil.destroy(mobileControlsCam);
		}
	}

	public function addTouchPadCamera(defaultDrawTarget:Bool = false):Void
	{
		if (touchPad != null)
		{
			touchPadCam = new ShadowCamera();
			touchPadCam.bgColor.alpha = 0;
			FlxG.cameras.add(touchPadCam, defaultDrawTarget);
			touchPad.cameras = [touchPadCam];
		}
	}

	public function makeLuaTouchPad(DPadMode:String, ActionMode:String)
	{
		if (members.contains(luaTouchPad))
			return;

		if (!variables.exists("luaTouchPad"))
			variables.set("luaTouchPad", luaTouchPad);

		luaTouchPad = new TouchPad(DPadMode, ActionMode, NONE);
		luaTouchPad.alpha = ClientPrefs.data.controlsAlpha;
	}

	public function addLuaTouchPad()
	{
		if (luaTouchPad == null || members.contains(luaTouchPad))
			return;

		var target = LuaUtils.getTargetInstance();
		target.insert(target.members.length + 1, luaTouchPad);
	}

	public function addLuaTouchPadCamera(defaultDrawTarget:Bool = false)
	{
		if (luaTouchPad != null)
		{
			luaTouchPadCam = new ShadowCamera();
			luaTouchPadCam.bgColor.alpha = 0;
			FlxG.cameras.add(luaTouchPadCam, defaultDrawTarget);
			luaTouchPad.cameras = [luaTouchPadCam];
		}
	}

	public function removeLuaTouchPad()
	{
		if (luaTouchPad != null)
		{
			luaTouchPad.kill();
			luaTouchPad.destroy();
			remove(luaTouchPad);
			luaTouchPad = null;
		}
	}

	public function luaTouchPadPressed(button:Dynamic):Bool
	{
		if (luaTouchPad != null)
		{
			if (Std.isOfType(button, String))
				return luaTouchPad.buttonPressed(MobileInputID.fromString(button));
			else if (Std.isOfType(button, Array))
			{
				var FUCK:Array<String> = button; // haxe said "You Can't Iterate On A Dyanmic Value Please Specificy Iterator or Iterable *insert nerd emoji*" so that's the only i found to fix
				var idArray:Array<MobileInputID> = [];
				for (strId in FUCK)
					idArray.push(MobileInputID.fromString(strId));
				return luaTouchPad.anyPressed(idArray);
			}
			else
				return false;
		}
		return false;
	}

	public function luaTouchPadJustPressed(button:Dynamic):Bool
	{
		if (luaTouchPad != null)
		{
			if (Std.isOfType(button, String))
				return luaTouchPad.buttonJustPressed(MobileInputID.fromString(button));
			else if (Std.isOfType(button, Array))
			{
				var FUCK:Array<String> = button;
				var idArray:Array<MobileInputID> = [];
				for (strId in FUCK)
					idArray.push(MobileInputID.fromString(strId));
				return luaTouchPad.anyJustPressed(idArray);
			}
			else
				return false;
		}
		return false;
	}

	public function luaTouchPadJustReleased(button:Dynamic):Bool
	{
		if (luaTouchPad != null)
		{
			if (Std.isOfType(button, String))
				return luaTouchPad.buttonJustReleased(MobileInputID.fromString(button));
			else if (Std.isOfType(button, Array))
			{
				var FUCK:Array<String> = button;
				var idArray:Array<MobileInputID> = [];
				for (strId in FUCK)
					idArray.push(MobileInputID.fromString(strId));
				return luaTouchPad.anyJustReleased(idArray);
			}
			else
				return false;
		}
		return false;
	}

	public function luaTouchPadReleased(button:Dynamic):Bool
	{
		if (luaTouchPad != null)
		{
			if (Std.isOfType(button, String))
				return luaTouchPad.buttonJustReleased(MobileInputID.fromString(button));
			else if (Std.isOfType(button, Array))
			{
				var FUCK:Array<String> = button;
				var idArray:Array<MobileInputID> = [];
				for (strId in FUCK)
					idArray.push(MobileInputID.fromString(strId));
				return luaTouchPad.anyReleased(idArray);
			}
			else
				return false;
		}
		return false;
	}
	#end

	override function destroy()
	{
		#if FEATURE_MOBILE_CONTROLS
		removeTouchPad();
		removeLuaTouchPad();
		removeMobileControls();
		#end

		scripts.destroy();

		#if (FEATURE_LUA || FEATURE_HSCRIPT)
		if (luaDebugCam != null)
		{
			if (FlxG.cameras.list.contains(luaDebugCam))
				FlxG.cameras.remove(luaDebugCam);
			luaDebugCam = null;
		}
		#end

		super.destroy();
	}

	var _psychCameraInitialized:Bool = false;

	public function new()
	{
		stateInstance = this;
		scripts = new ScriptManager(this);

		#if (FEATURE_LUA || FEATURE_HSCRIPT)
		currentClassName = Std.string(Type.getClassName(Type.getClass(this))).replace('states.', '').replace('.', '/');
		#end
		callOnScripts('onNew');
		super();
		callOnScripts('onNewPost');
	}

	override function create()
	{
		var skip:Bool = FlxTransitionableState.skipNextTransOut;
		#if FEATURE_MODS
		Mods.updatedOnState = false;
		#end

		if (!_psychCameraInitialized)
			initPsychCamera();

		#if (FEATURE_LUA || FEATURE_HSCRIPT)
		ensureDebugGroup();
		#end

		#if FEATURE_LUA
		scripts.startLuasNamed('statescripts/' + currentClassName);
		#end
		#if FEATURE_HSCRIPT
		scripts.startHScriptsNamed('statescripts/' + currentClassName);
		#end

		super.create();

		callOnScripts('onCreatePost');

		if (!skip)
		{
			switchSubState(CustomFadeTransition, [0.6, true]);
		}
		FlxTransitionableState.skipNextTransOut = false;
		timePassedOnState = 0;
	}

	@:deprecated("`MusicBeatState.openSubState` is deprecated. Use `Funkin.switchSubState` or `MusicBeatState.switchSubState` instead.")
	override function openSubState(subState:FlxSubState)
	{
		callOnScripts('onOpenSubState');
		super.openSubState(subState);
	}

	public function switchSubState(subState:Class<FlxSubState>, ?args:Array<Dynamic>):Void
	{
		Funkin.switchSubState(this, subState, args);
	}

	override function closeSubState()
	{
		Funkin.controls.isInSubstate = false;
		callOnScripts('onCloseSubState');
		super.closeSubState();
	}

	public function initPsychCamera():PsychCamera
	{
		var camera = new PsychCamera();
		FlxG.cameras.reset(camera);
		FlxG.cameras.setDefaultDrawTarget(camera, true);
		_psychCameraInitialized = true;
		// trace('initialized psych camera ' + Sys.cpuTime());
		return camera;
	}

	public static var timePassedOnState:Float = 0;

	override function update(elapsed:Float)
	{
		var oldStep:Int = curStep;
		timePassedOnState += elapsed;

		updateCurStep();
		updateBeat();

		if (Funkin.controls.isInSubstate)
			Funkin.controls.isInSubstate = false;

		if (oldStep != curStep)
		{
			if (curStep > 0)
				stepHit();

			if (PlayState.SONG != null)
			{
				if (oldStep < curStep)
					updateSection();
				else
					rollbackSection();
			}
		}

		if (FlxG.save.data != null)
			FlxG.save.data.fullscreen = FlxG.fullscreen;

		// Inlined from stagesFunc() - that took a closure, which was allocated every frame.
		for (stage in stages)
			if (stage != null && stage.exists && stage.active)
				stage.update(elapsed);

		if (hasScripts)
		{
			callOnScripts('onUpdate', [elapsed]);

			setOnScripts('curDecStep', curDecStep);
			setOnScripts('curDecBeat', curDecBeat);
		}

		super.update(elapsed);

		if (hasScripts)
			callOnScripts('onUpdatePost', [elapsed]);
	}

	private function updateSection():Void
	{
		if (stepsToDo < 1)
			stepsToDo = Math.round(getBeatsOnSection() * 4);
		while (curStep >= stepsToDo)
		{
			curSection++;
			var beats:Float = getBeatsOnSection();
			stepsToDo += Math.round(beats * 4);
			sectionHit();
		}
	}

	private function rollbackSection():Void
	{
		if (curStep < 0)
			return;

		var lastSection:Int = curSection;
		curSection = 0;
		stepsToDo = 0;
		for (i in 0...PlayState.SONG.notes.length)
		{
			if (PlayState.SONG.notes[i] != null)
			{
				stepsToDo += Math.round(getBeatsOnSection() * 4);
				if (stepsToDo > curStep)
					break;

				curSection++;
			}
		}

		if (curSection > lastSection)
			sectionHit();
	}

	private function updateBeat():Void
	{
		curBeat = Math.floor(curStep / 4);
		curDecBeat = curDecStep / 4;
	}

	private function updateCurStep():Void
	{
		var lastChange = Conductor.getBPMFromSeconds(Conductor.songPosition);

		var shit = ((Conductor.songPosition - ClientPrefs.data.noteOffset) - lastChange.songTime) / lastChange.stepCrochet;
		curDecStep = lastChange.stepTime + shit;
		curStep = lastChange.stepTime + Math.floor(shit);
	}

	@:deprecated("`MusicBeatState.switchState` is deprecated. Use `Funkin.switchState` instead.")
	public static function switchState(nextState:FlxState = null)
	{
		Funkin.switchState(Type.getClass(nextState));
	}

	@:deprecated("`MusicBeatState.resetState` is deprecated. Use `Funkin.resetState` instead.")
	public static function resetState()
	{
		Funkin.resetState();
	}

	@:deprecated("`MusicBeatState.startTransition` is deprecated. Use `Funkin.startTransition` instead.")
	public static function startTransition(nextState:FlxState = null)
	{
		Funkin.startTransition(nextState);
	}

	public static function getState():MusicBeatState
	{
		return cast(FlxG.state, MusicBeatState);
	}

	public function stepHit():Void
	{
		stagesFunc(function(stage:BaseStage)
		{
			stage.curStep = curStep;
			stage.curDecStep = curDecStep;
			stage.stepHit();
		});

		if (curStep % 4 == 0)
			beatHit();

		setOnScripts('curStep', curStep);
		callOnScripts('onStepHit');
	}

	public var stages:Array<BaseStage> = [];

	public function beatHit():Void
	{
		// trace('Beat: ' + curBeat);
		stagesFunc(function(stage:BaseStage)
		{
			stage.curBeat = curBeat;
			stage.curDecBeat = curDecBeat;
			stage.beatHit();
		});

		setOnScripts('curBeat', curBeat);
		callOnScripts('onBeatHit');
	}

	public function sectionHit():Void
	{
		// trace('Section: ' + curSection + ', Beat: ' + curBeat + ', Step: ' + curStep);
		stagesFunc(function(stage:BaseStage)
		{
			stage.curSection = curSection;
			stage.sectionHit();
		});

		setOnScripts('curSection', curSection);
		callOnScripts('onSectionHit');
	}

	function stagesFunc(func:BaseStage->Void)
	{
		for (stage in stages)
			if (stage != null && stage.exists && stage.active)
				func(stage);
	}

	public function getBeatsOnSection()
	{
		var val:Null<Float> = 4;
		if (PlayState.SONG != null && PlayState.SONG.notes[curSection] != null)
			val = PlayState.SONG.notes[curSection].sectionBeats;
		return val == null ? 4 : val;
	}

	#if (FEATURE_LUA || FEATURE_HSCRIPT)
	function ensureDebugGroup():Void
	{
		if (luaDebugGroup != null)
			return;

		luaDebugGroup = new FlxTypedGroup<psychlua.DebugLuaText>();
		luaDebugCam = new ShadowCamera();
		luaDebugCam.bgColor.alpha = 0;
		FlxG.cameras.add(luaDebugCam, false);
		luaDebugGroup.cameras = [luaDebugCam];
		add(luaDebugGroup);
	}

	public function addTextToDebug(text:String, color:FlxColor)
	{
		ensureDebugGroup();

		var newText:psychlua.DebugLuaText = luaDebugGroup.recycle(psychlua.DebugLuaText);
		newText.text = text;
		newText.color = color;
		newText.disableTime = 6;
		newText.alpha = 1;
		newText.setPosition(10, 8 - newText.height);

		luaDebugGroup.forEachAlive(function(spr:psychlua.DebugLuaText)
		{
			spr.y += newText.height + 2;
		});
		luaDebugGroup.add(newText);
		#if sys
		Sys.println(text);
		#else
		trace(text);
		#end
	}
	#end

	public function getLuaObject(tag:String, text:Bool = true):FlxSprite
	{
		#if FEATURE_LUA
		if (modchartSprites.exists(tag))
			return modchartSprites.get(tag);
		if (text && modchartTexts.exists(tag))
			return modchartTexts.get(tag);
		if (variables.exists(tag))
			return variables.get(tag);
		#end
		return null;
	}

	// ── Script delegation ─────────────────────────────────────────

	/** True when this state has at least one Lua or HScript script loaded. */
	public var hasScripts(get, never):Bool;

	inline function get_hasScripts():Bool
		return scripts != null && scripts.hasScripts;

	// The `{ignoreStops: ..., exclusions: ..., excludeValues: ...}` structure below is built by the
	// *caller*, so it was allocated on every one of these calls even when no scripts were loaded at
	// all and ScriptManager was about to bail out immediately. Gameplay makes a dozen-plus of these
	// per frame plus several per note, so check first and allocate nothing in the common case.
	public function callOnScripts(funcToCall:String, args:Array<Dynamic> = null, ignoreStops = false, exclusions:Array<String> = null,
			excludeValues:Array<Dynamic> = null):Dynamic
	{
		if (!hasScripts)
			return ScriptResult.Continue;

		return scripts.call(funcToCall, args, {
			ignoreStops: ignoreStops,
			exclusions: exclusions,
			excludeValues: excludeValues
		});
	}

	public function callOnLuas(funcToCall:String, args:Array<Dynamic> = null, ignoreStops = false, exclusions:Array<String> = null,
			excludeValues:Array<Dynamic> = null):Dynamic
	{
		if (scripts == null || scripts.luaArray.length == 0)
			return ScriptResult.Continue;

		return scripts.callOnLuas(funcToCall, args, {
			ignoreStops: ignoreStops,
			exclusions: exclusions,
			excludeValues: excludeValues
		});
	}

	public function callOnHScript(funcToCall:String, args:Array<Dynamic> = null, ?ignoreStops:Bool = false, exclusions:Array<String> = null,
			excludeValues:Array<Dynamic> = null):Dynamic
	{
		if (scripts == null || scripts.hscriptArray.length == 0)
			return ScriptResult.Continue;

		return scripts.callOnHScript(funcToCall, args, {
			ignoreStops: ignoreStops,
			exclusions: exclusions,
			excludeValues: excludeValues
		});
	}

	public function setOnScripts(variable:String, arg:Dynamic, exclusions:Array<String> = null)
	{
		if (!hasScripts)
			return;

		scripts.set(variable, arg, exclusions);
	}

	public function setOnLuas(variable:String, arg:Dynamic, exclusions:Array<String> = null)
	{
		if (scripts != null)
			scripts.setOnLuas(variable, arg, exclusions);
	}

	public function setOnHScript(variable:String, arg:Dynamic, exclusions:Array<String> = null)
	{
		if (scripts != null)
			scripts.setOnHScript(variable, arg, exclusions);
	}

	public function startLuasNamed(luaFile:String, ?doFileMethod:String->Bool):Bool
	{
		#if FEATURE_LUA
		return scripts.startLuasNamed(luaFile, doFileMethod);
		#else
		return false;
		#end
	}

	public function startHScriptsNamed(scriptFile:String, ?doFileMethod:String->Bool):Bool
	{
		#if FEATURE_HSCRIPT
		return scripts.startHScriptsNamed(scriptFile, doFileMethod);
		#else
		return false;
		#end
	}

	public function initHScript(file:String):Void
	{
		#if FEATURE_HSCRIPT
		scripts.initHScript(file);
		#end
	}
}
