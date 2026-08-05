package backend.input;

import backend.Controls;
import flixel.input.keyboard.FlxKey;
import flixel.util.FlxSignal.FlxTypedSignal;
import haxe.Int64;
import lime.ui.KeyCode;
import lime.ui.KeyModifier;
import openfl.ui.Keyboard;
import openfl.events.TouchEvent;
#if FEATURE_MOBILE_CONTROLS
import flixel.input.FlxPointer;
import flixel.math.FlxPoint;
import mobile.objects.TouchButton;
#end

/**
 * Precise, frame-independent note-lane input.
 *
 * PlayState's regular keyboard handling (onKeyPress) gates on
 * `FlxG.keys.checkStatus(key, JUST_PRESSED)`, and Flixel only flips that flag
 * once per rendered frame. Two real key-down edges landing inside the same
 * frame collapse into a single JUST_PRESSED, so the second is silently
 * dropped - meaning very dense/fast note patterns (two taps a couple ms
 * apart) are architecturally unhittable as separate notes no matter how
 * fast the actual keyboard input is, human or otherwise.
 *
 * This listens to Lime's `onKeyDownPrecise`/`onKeyUpPrecise` instead. Those
 * fire directly off the native input backend with their own nanosecond
 * timestamp and are NOT tied to the render loop, so two edges inside the
 * same frame can still be seen and dispatched as two separate presses.
 *
 * Ported from FunkinCrew/Funkin's `funkin.input.PreciseInputManager`,
 * adapted to this engine's plain `Map<String, Array<FlxKey>>` control
 * bindings (`Controls.keyboardBinds`) instead of Funkin's
 * `FlxActionDigital`-based control system, and to this engine's lane-index
 * note model (`keysArray` order: left, down, up, right) instead of Funkin's
 * `NoteDirection` enum.
 *
 * Also covers mobile touch buttons, scoped to the plain case only: a real
 * touch landing on a button, dead zones respected. `flixel.input.touch.
 * FlxTouchManager` has the exact same frame-buffering problem as `FlxG.keys`
 * (its own `TouchEvent.TOUCH_BEGIN`/`TOUCH_END` listeners already fire in
 * real time, but `TouchButton` only reads the frame-buffered `justPressed`
 * flag derived from them) - so this adds its own real-time listener for that
 * side too. Deliberately NOT covered: swipe-to-press and the
 * `maxInputMovement` cancel-tracking behavior in `TouchButton`, both of which
 * need continuous per-frame movement tracking that a one-shot press/release
 * event can't provide - those two still only work through the original
 * per-frame poll, which keeps running unmodified alongside this.
 */
class PreciseInputManager
{
	public static var instance(get, null):PreciseInputManager;

	static function get_instance():PreciseInputManager
		return instance ?? (instance = new PreciseInputManager());

	public var onInputPressed:FlxTypedSignal<PreciseInputEvent->Void>;
	public var onInputReleased:FlxTypedSignal<PreciseInputEvent->Void>;

	// note lane index (matches PlayState.keysArray order) -> bound keys
	var _laneKeys:Array<Array<FlxKey>> = [];

	// FlxKey -> whether WE think it's currently down. Tracked independently of
	// FlxG.keys, since that's frame-buffered and reading it from a sub-frame
	// callback like this one wouldn't be safe/meaningful.
	var _keyDown:Map<FlxKey, Bool> = [];

	var _bound:Bool = false;

	#if FEATURE_MOBILE_CONTROLS
	// touch buttons currently in play, and a single reusable FlxPointer used
	// purely for its geometry math (setRawPositionUnsafe -> getWorldPosition),
	// not a real registered touch - see hitTestButtons
	var _touchButtons:Array<TouchButton> = [];
	var _touchPointer:FlxPointer = new FlxPointer();
	var _touchBound:Bool = false;

	// touchPointID -> the button it pressed, so release always resolves back
	// to the same button regardless of where the finger ends up by TOUCH_END
	// (matches how a physical button works - lift anywhere, it still releases)
	var _touchDownButtons:Map<Int, TouchButton> = [];
	#end

	function new()
	{
		onInputPressed = new FlxTypedSignal<PreciseInputEvent->Void>();
		onInputReleased = new FlxTypedSignal<PreciseInputEvent->Void>();
	}

	/**
	 * Call whenever keybinds might have changed (rebinding, or entering a
	 * fresh PlayState) to refresh which physical keys map to which note lane.
	 * `keysArray` should be PlayState's own `keysArray`
	 * (`['note_left', 'note_down', 'note_up', 'note_right']`).
	 */
	public function initializeKeys(keysArray:Array<String>):Void
	{
		_laneKeys = [for (i in 0...keysArray.length) []];
		_keyDown = [];

		for (lane in 0...keysArray.length)
		{
			var bound:Array<FlxKey> = Controls.instance.keyboardBinds[keysArray[lane]];
			if (bound != null)
				_laneKeys[lane] = bound;
		}

		bind();
	}

	#if FEATURE_MOBILE_CONTROLS
	/**
	 * Call after mobile controls are fully set up (after dead zones are
	 * assigned, so `mobileControls.instance.members` reflects everything the
	 * plain per-frame poll would also see) to hand this the buttons it should
	 * hit-test real touches against.
	 */
	public function initializeTouchButtons(buttons:Iterable<TouchButton>):Void
	{
		_touchButtons = [for (b in buttons) b];
		_touchDownButtons = [];
		bindTouch();
	}
	#end

	function bind():Void
	{
		if (_bound) return;
		_bound = true;
		FlxG.stage.application.window.onKeyDownPrecise.add(handleKeyDown);
		FlxG.stage.application.window.onKeyUpPrecise.add(handleKeyUp);
	}

	/**
	 * Call from PlayState's destroy/cleanup so the listener doesn't outlive
	 * the state (this class is a singleton, so it otherwise would).
	 */
	public function destroy():Void
	{
		if (_bound)
		{
			_bound = false;
			FlxG.stage.application.window.onKeyDownPrecise.remove(handleKeyDown);
			FlxG.stage.application.window.onKeyUpPrecise.remove(handleKeyUp);
		}

		#if FEATURE_MOBILE_CONTROLS
		if (_touchBound)
		{
			_touchBound = false;
			FlxG.stage.removeEventListener(TouchEvent.TOUCH_BEGIN, handleTouchBeginPrecise);
			FlxG.stage.removeEventListener(TouchEvent.TOUCH_END, handleTouchEndPrecise);
		}
		_touchButtons = [];
		_touchDownButtons = [];
		#end
	}

	#if FEATURE_MOBILE_CONTROLS
	function bindTouch():Void
	{
		if (_touchBound) return;
		_touchBound = true;
		FlxG.stage.addEventListener(TouchEvent.TOUCH_BEGIN, handleTouchBeginPrecise);
		FlxG.stage.addEventListener(TouchEvent.TOUCH_END, handleTouchEndPrecise);
	}

	/**
	 * Same geometry Flixel's own `TouchButton.checkTouchOverlap`/`checkInput`
	 * use (per-camera `overlapsPoint` against the touch's world position, dead
	 * zones vetoing a hit first) - just run immediately off the raw event
	 * instead of waiting for the next per-frame poll. `setRawPositionUnsafe`
	 * is `FlxPointer`'s own public, documented entry point for exactly this -
	 * "manually dispatch low-level mouse/touch events" - so this reuses
	 * Flixel's real scale-mode/camera transform math rather than
	 * reimplementing it.
	 */
	function hitTestButtons(stageX:Float, stageY:Float):TouchButton
	{
		for (button in _touchButtons)
		{
			if (button == null || !button.exists || !button.alive || !button.visible)
				continue;

			for (camera in button.cameras)
			{
				_touchPointer.setRawPositionUnsafe(stageX, stageY);
				var worldPos:FlxPoint = _touchPointer.getWorldPosition(camera);

				var blocked:Bool = false;
				for (zone in button.deadZones)
				{
					if (zone != null && zone.overlapsPoint(worldPos, true, camera))
					{
						blocked = true;
						break;
					}
				}

				if (!blocked && button.overlapsPoint(worldPos, true, camera))
					return button;
			}
		}
		return null;
	}

	function handleTouchBeginPrecise(event:TouchEvent):Void
	{
		var button:TouchButton = hitTestButtons(event.stageX, event.stageY);
		if (button == null) return;

		_touchDownButtons.set(event.touchPointID, button);
		button.firePreciseDown();
	}

	function handleTouchEndPrecise(event:TouchEvent):Void
	{
		var button:TouchButton = _touchDownButtons.get(event.touchPointID);
		if (button == null) return;

		_touchDownButtons.remove(event.touchPointID);
		button.firePreciseUp();
	}
	#end

	function laneForKey(key:FlxKey):Int
	{
		for (lane in 0..._laneKeys.length)
			if (_laneKeys[lane].indexOf(key) != -1)
				return lane;
		return -1;
	}

	function handleKeyDown(keyCode:KeyCode, _:KeyModifier, timestamp:Int64):Void
	{
		var key:FlxKey = convertKeyCode(keyCode);
		var lane:Int = laneForKey(key);
		if (lane == -1) return;

		// our own debounce - only dispatch on a genuine down edge (same idea
		// as Flixel's JUST_PRESSED), just not gated behind a render frame
		if (_keyDown.get(key) == true) return;
		_keyDown.set(key, true);

		onInputPressed.dispatch({noteData: lane, timestamp: timestamp, key: key});
	}

	function handleKeyUp(keyCode:KeyCode, _:KeyModifier, timestamp:Int64):Void
	{
		var key:FlxKey = convertKeyCode(keyCode);
		var lane:Int = laneForKey(key);
		if (lane == -1) return;

		if (_keyDown.get(key) != true) return;
		_keyDown.set(key, false);

		onInputReleased.dispatch({noteData: lane, timestamp: timestamp, key: key});
	}

	static function convertKeyCode(input:KeyCode):FlxKey
	{
		@:privateAccess
		{
			return Keyboard.__convertKeyCode(input);
		}
	}
}

typedef PreciseInputEvent =
{
	/** Note lane index, matching PlayState.keysArray order (0 = left, 1 = down, 2 = up, 3 = right). */
	noteData:Int,

	/** The timestamp of the input, in nanoseconds. Only meaningful compared against another such timestamp. */
	timestamp:Int64,

	/** The physical key that triggered this event. */
	key:FlxKey
}
