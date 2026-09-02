package objects;

import flixel.animation.FlxAnimationController;
import flixel.util.FlxSort;
import flixel.util.FlxDestroyUtil;
import openfl.utils.AssetType;
import openfl.utils.Assets;
import backend.Song;
import backend.Section;

typedef CharacterFile =
{
	var animations:Array<AnimArray>;
	var image:flixel.util.typeLimit.OneOfTwo<String, Array<String>>;
	var scale:Float;
	var sing_duration:Float;
	var healthicon:String;

	var position:Array<Float>;
	var camera_position:Array<Float>;

	var flip_x:Bool;
	var no_antialiasing:Bool;
	var healthbar_colors:Array<Int>;
	var vocals_file:String;
	@:optional
	var _editor_isPlayer:Null<Bool>;
}

typedef AnimArray =
{
	var anim:String;
	var name:String;
	var fps:Int;
	var loop:Bool;
	var indices:Array<Int>;
	var offsets:Array<Int>;
	@:optional
	var isFrameLabel:Bool;
	@:optional
	var isAnimate:Null<Bool>;
	@:optional
	var flipX:Null<Bool>;
	@:optional
	var flipY:Null<Bool>;
}

enum CharacterSpriteType
{
	SPRITE;
	MULTI_ATLAS;
	TEXTURE_ATLAS;
}

class Character extends FlxAnimate
{
	/**
	 * In case a character is missing, it will use this on its place
	**/
	public static final DEFAULT_CHARACTER:String = 'bf';

	public var animOffsets:Map<String, Array<Dynamic>>;
	public var debugMode:Bool = false;
	public var extraData:Map<String, Dynamic> = new Map<String, Dynamic>();

	public var isPlayer:Bool = false;
	public var isMultiAtlas:Bool = false; // for psychlua smh
	public var curCharacter:String = DEFAULT_CHARACTER;

	public var holdTimer:Float = 0;
	public var heyTimer:Float = 0;
	public var specialAnim:Bool = false;
	public var animationNotes:Array<Dynamic> = [];
	public var stunned:Bool = false;
	public var singDuration:Float = 4; // Multiplier of how long a character holds the sing pose
	public var idleSuffix:String = '';
	public var danceIdle:Bool = false; // Character use "danceLeft" and "danceRight" instead of "idle"
	public var skipDance:Bool = false;

	public var healthIcon:String = 'face';
	public var animationsArray:Array<AnimArray> = [];

	public var positionArray:Array<Float> = [0, 0];
	public var cameraPosition:Array<Float> = [0, 0];
	public var healthColorArray:Array<Int> = [255, 0, 0];

	public var hasMissAnimations:Bool = false;
	public var vocalsFile:String = '';

	// Used on Character Editor
	public var imageFile:String = '';
	public var imageFiles:Array<String> = [];
	public var jsonScale:Float = 1;
	public var noAntialiasing:Bool = false;
	public var originalFlipX:Bool = false;
	public var editorIsPlayer:Null<Bool> = null;
	public var isAnimateAtlas:Bool = false;

	public var spriteType:CharacterSpriteType = SPRITE;

	public function new(x:Float, y:Float, ?character:String = 'bf', ?isPlayer:Bool = false)
	{
		super(x, y);

		animOffsets = new Map<String, Array<Dynamic>>();
		curCharacter = character;
		this.isPlayer = isPlayer;
		switch (curCharacter)
		{
			// case 'your character name in case you want to hardcode them instead':

			default:
				var characterPath:String = 'characters/$curCharacter.json';

				var path:String = Paths.getPath(characterPath, TEXT, null, true);
				if (!FileSystem.exists(path))
				{
					path = Paths.getSharedPath('characters/' + DEFAULT_CHARACTER +
						'.json'); // If a character couldn't be found, change him to BF just to prevent a crash
					color = FlxColor.BLACK;
					alpha = 0.6;
				}

				try
				{
					loadCharacterFile(Json.parse(File.getContent(path), path));
				}
				catch (e:Dynamic)
				{
					trace('Error loading character file of "$character": $e');
				}
		}

		if (animOffsets.exists('singLEFTmiss') || animOffsets.exists('singDOWNmiss') || animOffsets.exists('singUPmiss') || animOffsets.exists('singRIGHTmiss'))
			hasMissAnimations = true;
		recalculateDanceIdle();
		dance();
	}

	override public function isOnScreen(?camera:FlxCamera):Bool
	{
		if (isMultiAtlas)
			return true; // flixel is stoobid

		if (camera == null)
			camera = FlxG.camera;

		return camera.containsRect(getScreenBounds(_rect, camera));
	}

	public function loadCharacterFile(json:Dynamic)
	{
		scale.set(1, 1);
		updateHitbox();

		if (json.animations != null && json.animations.length > 0 && json.animations[0].prefix != null)
		{
			trace('V-Slice character JSON detected for character ' + curCharacter);

			if (json.assetPath != null)
			{
				var cleanPath:String = json.assetPath;
				if (cleanPath.startsWith('shared:'))
					cleanPath = cleanPath.substring(7);

				json.image = cleanPath;
			}

			if (json.flipX != null)
				json.flip_x = json.flipX;
			if (json.cameraOffsets != null)
				json.camera_position = json.cameraOffsets;
			if (json.singTime != null)
				json.sing_duration = json.singTime;
			if (json.isPixel != null)
				json.no_antialiasing = json.isPixel;

			if (json.healthIcon != null && json.healthIcon.id != null)
				json.healthicon = json.healthIcon.id;

			if (json.offsets != null)
				json.position = json.offsets;

			if (json.animations != null)
			{
				var anims:Array<Dynamic> = (json.animations : Array<Dynamic>);
				var newAnims:Array<Dynamic> = new Array<Dynamic>();
				var assetPaths:Array<String> = [];

				for (a in anims)
				{
					var na:Dynamic = {
						anim: (a.name != null && a.name != '') ? a.name : (a.anim != null ? a.anim : ''),
						name: (a.prefix != null && a.prefix != '') ? a.prefix : (a.animation != null ? a.animation : ''),
						fps: (a.frameRate != null) ? a.frameRate : (a.fps != null ? a.fps : 24),
						loop: (a.looped != null) ? a.looped : (a.loop != null ? a.loop : false),
						indices: (a.frameIndices != null) ? a.frameIndices : (a.indices != null ? a.indices : []),
						offsets: (a.offsets != null) ? a.offsets : [0, 0]
					};

					if (a.assetPath != null)
					{
						var cleanPath:String = a.assetPath;
						if (cleanPath.startsWith('shared:'))
							cleanPath = cleanPath.substring(7);
						if (assetPaths.indexOf(cleanPath) < 0)
							assetPaths.push(cleanPath);
					}

					newAnims.push(na);
				}

				json.animations = newAnims;

				if (assetPaths.length > 0)
				{
					var imgs:Array<String> = [];
					if (json.image is String)
						imgs.push(json.image);
					else if (json.image != null)
						imgs = imgs.concat(json.image);
					for (p in assetPaths)
						if (imgs.indexOf(p) < 0)
							imgs.push(p);
					json.image = imgs;
				}
			}
		}

		var images:Array<String>;
		if (json.image is String)
			images = [json.image];
		else
			images = json.image;
		frames = Paths.getMixedAtlas(images);

		isAnimateAtlas = (frames is FlxAnimateFrames);
		isMultiAtlas = images.length > 1;
		spriteType = isAnimateAtlas ? TEXTURE_ATLAS : (isMultiAtlas ? MULTI_ATLAS : SPRITE);
		imageFiles = images;
		imageFile = images[0];

		jsonScale = json.scale;
		if (json.scale != 1)
		{
			scale.set(jsonScale, jsonScale);
			updateHitbox();
		}

		// positioning
		positionArray = json.position;
		cameraPosition = json.camera_position;

		// data
		healthIcon = json.healthicon;
		singDuration = json.sing_duration;
		flipX = (json.flip_x != isPlayer);
		healthColorArray = (json.healthbar_colors != null && json.healthbar_colors.length > 2) ? json.healthbar_colors : [161, 161, 161];
		vocalsFile = json.vocals_file != null ? json.vocals_file : '';
		originalFlipX = (json.flip_x == true);
		editorIsPlayer = json._editor_isPlayer;

		// antialiasing
		noAntialiasing = (json.no_antialiasing == true);
		antialiasing = ClientPrefs.data.antialiasing ? !noAntialiasing : false;

		// animations
		animationsArray = json.animations;
		if (animationsArray != null && animationsArray.length > 0)
		{
			for (anim in animationsArray)
			{
				addAnimByType(anim);

				if (anim.offsets != null && anim.offsets.length > 1)
					addOffset(anim.anim, anim.offsets[0], anim.offsets[1]);
				else
					addOffset(anim.anim, 0, 0);
			}
		}
		// trace('Loaded file to character ' + curCharacter);
	}

	override function update(elapsed:Float)
	{
		if (debugMode || isAnimationNull())
		{
			super.update(elapsed);
			return;
		}

		if (heyTimer > 0)
		{
			var rate:Float = (PlayState.instance != null ? PlayState.instance.playbackRate : 1.0);
			heyTimer -= elapsed * rate;
			if (heyTimer <= 0)
			{
				var anim:String = getAnimationName();
				if (specialAnim && (anim == 'hey' || anim == 'cheer'))
				{
					specialAnim = false;
					dance();
				}
				heyTimer = 0;
			}
		}
		else if (specialAnim && isAnimationFinished())
		{
			specialAnim = false;
			dance();
		}
		else if (getAnimationName().endsWith('miss') && isAnimationFinished())
		{
			dance();
			finishAnimation();
		}

		// Resolved once instead of the five separate getAnimationName() calls this used to make per
		// character per frame (each one walking into the animation controller).
		final animName:String = getAnimationName();

		if (animName.startsWith('sing'))
			holdTimer += elapsed;
		else if (isPlayer)
			holdTimer = 0;

		if (!isPlayer
			&& holdTimer >= Conductor.stepCrochet * (0.0011 #if FLX_PITCH / (FlxG.sound.music != null ? FlxG.sound.music.pitch : 1) #end) * singDuration)
		{
			dance();
			holdTimer = 0;
		}

		if (isAnimationFinished() && animOffsets.exists('$animName-loop'))
			playAnim('$animName-loop');

		super.update(elapsed);
	}

	inline public function isAnimationNull():Bool
		return anim.curAnim == null;

	inline public function getAnimationName():String
	{
		var name:String = '';
		@:privateAccess
		if (!isAnimationNull())
			name = anim.curAnim.name;
		return (name != null) ? name : '';
	}

	public function isAnimationFinished():Bool
	{
		if (isAnimationNull())
			return false;
		return anim.curAnim.finished;
	}

	public function finishAnimation():Void
	{
		if (isAnimationNull())
			return;

		anim.curAnim.finish();
	}

	public var animPaused(get, set):Bool;

	private function get_animPaused():Bool
	{
		if (isAnimationNull())
			return false;
		return anim.curAnim.paused;
	}

	private function set_animPaused(value:Bool):Bool
	{
		if (isAnimationNull())
			return value;

		anim.curAnim.paused = value;

		return value;
	}

	public var danced:Bool = false;

	/**
	 * FOR GF DANCING SHIT
	 */
	public function dance()
	{
		if (!debugMode && !skipDance && !specialAnim)
		{
			if (danceIdle)
			{
				danced = !danced;

				if (danced)
					playAnim('danceRight' + idleSuffix);
				else
					playAnim('danceLeft' + idleSuffix);
			}
			else if (animOffsets.exists('idle' + idleSuffix))
			{
				playAnim('idle' + idleSuffix);
			}
		}
	}

	public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0):Void
	{
		specialAnim = false;
		anim.play(AnimName, Force, Reversed, Frame);

		if (animOffsets.exists(AnimName))
		{
			var daOffset = animOffsets.get(AnimName);
			offset.set(daOffset[0], daOffset[1]);
		}
		// else offset.set(0, 0);

		if (curCharacter.startsWith('gf-') || curCharacter == 'gf')
		{
			if (AnimName == 'singLEFT')
				danced = true;
			else if (AnimName == 'singRIGHT')
				danced = false;

			if (AnimName == 'singUP' || AnimName == 'singDOWN')
				danced = !danced;
		}
	}

	function loadMappedAnims():Void
	{
		try
		{
			var noteData:Array<SwagSection> = Song.loadFromJson('picospeaker', Paths.formatToSongPath(PlayState.SONG.song)).notes;
			for (section in noteData)
			{
				for (songNotes in section.sectionNotes)
				{
					animationNotes.push(songNotes);
				}
			}
			animationNotes.sort(sortAnims);
		}
		catch (e:Dynamic)
		{
		}
	}

	function sortAnims(Obj1:Array<Dynamic>, Obj2:Array<Dynamic>):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1[0], Obj2[0]);
	}

	public var danceEveryNumBeats:Int = 2;

	private var settingCharacterUp:Bool = true;

	public function recalculateDanceIdle()
	{
		var lastDanceIdle:Bool = danceIdle;
		danceIdle = (animOffsets.exists('danceLeft' + idleSuffix) && animOffsets.exists('danceRight' + idleSuffix));

		if (settingCharacterUp)
		{
			danceEveryNumBeats = (danceIdle ? 1 : 2);
		}
		else if (lastDanceIdle != danceIdle)
		{
			var calc:Float = danceEveryNumBeats;
			if (danceIdle)
				calc /= 2;
			else
				calc *= 2;

			danceEveryNumBeats = Math.round(Math.max(calc, 1));
		}
		settingCharacterUp = false;
	}

	public function addOffset(name:String, x:Float = 0, y:Float = 0)
	{
		animOffsets[name] = [x, y];
	}

	public function quickAnimAdd(name:String, anim:String)
	{
		if (isAnimateAtlas && (!isMultiAtlas || symbolExists(name)))
			this.anim.addBySymbol(name, name, 24, false);
		else
			this.anim.addByPrefix(name, anim, 24, false);
	}

	public function addAnimByType(anim:AnimArray):Void
	{
		var animAnim:String = '' + anim.anim;
		var animName:String = '' + anim.name;
		var animFps:Int = anim.fps;
		var animLoop:Bool = !!anim.loop; // bruh?
		var animIndices:Array<Int> = anim.indices;
		var animFlipX:Bool = anim.flipX == true;
		var animFlipY:Bool = anim.flipY == true;

		var asAnimate:Bool;
		if (anim.isAnimate != null)
			asAnimate = (anim.isAnimate == true) && isAnimateAtlas;
		else if (anim.isFrameLabel == true)
			asAnimate = isAnimateAtlas;
		else if (!isMultiAtlas)
			asAnimate = isAnimateAtlas;
		else
			asAnimate = isAnimateAtlas && symbolExists(animName);

		if (asAnimate)
		{
			if (anim.isFrameLabel == true)
			{
				if (animIndices != null && animIndices.length > 0)
					this.anim.addByFrameLabelIndices(animAnim, animName, animIndices, animFps, animLoop, animFlipX, animFlipY);
				else
					this.anim.addByFrameLabel(animAnim, animName, animFps, animLoop, animFlipX, animFlipY);
			}
			else
			{
				if (animIndices != null && animIndices.length > 0)
					this.anim.addBySymbolIndices(animAnim, animName, animIndices, animFps, animLoop, animFlipX, animFlipY);
				else
					this.anim.addBySymbol(animAnim, animName, animFps, animLoop, animFlipX, animFlipY);
			}
		}
		else
		{
			if (animIndices != null && animIndices.length > 0)
				this.anim.addByIndices(animAnim, animName, animIndices, "", animFps, animLoop, animFlipX, animFlipY);
			else
				this.anim.addByPrefix(animAnim, animName, animFps, animLoop, animFlipX, animFlipY);
		}
	}

	public function symbolExists(name:String):Bool
	{
		if (!(frames is FlxAnimateFrames))
			return false;
		return cast(frames, FlxAnimateFrames).getSymbol(name) != null;
	}
}
