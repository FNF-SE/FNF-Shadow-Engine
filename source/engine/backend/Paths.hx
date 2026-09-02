package backend;

import flixel.system.FlxAssets;
import flixel.graphics.frames.FlxFrame.FlxFrameAngle;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.FlxGraphic;
import flixel.math.FlxRect;
import openfl.display.BitmapData;
import openfl.display3D.textures.RectangleTexture;
import openfl.utils.AssetType;
import openfl.utils.Assets;
import openfl.system.System;
import openfl.geom.Rectangle;
import openfl.media.Sound;

class Paths
{
	public static final IMAGE_EXT:String = "png";
	#if USING_GPU_TEXTURES
	public static final GPU_IMAGE_EXTS:Array<String> = [#if desktop 'dds', 'astc' #else 'astc', 'dds' #end];
	#end
	#if FEATURE_VIDEOS
	public static final VIDEO_EXT:String = "mp4";
	#end
	public static final SOUND_EXTS:Array<String> = ['ogg', 'mp3']; // ['ogg', 'opus', 'mp3', 'flac', 'wav']

	public static final dumpExclusions:Array<String> = [
		'assets/shared/images/touchpad/bg.$IMAGE_EXT',
		#if USING_GPU_TEXTURES
		#if BC
		'assets/shared/images/touchpad/bg.dds',
		#elseif ASTC
		'assets/shared/images/touchpad/bg.astc',
		#end
		#end
		'assets/shared/images/ui/cursor.png',
		'assets/shared/images/ui/cursorCross.png',
		'assets/shared/music/freakyMenu.ogg'
	];

	public static final currentTrackedAssets:Map<String, FlxGraphic> = [];
	public static final currentTrackedSounds:Map<String, Sound> = [];
	public static var localTrackedAssets:Array<String> = [];

	// `localTrackedAssets` is scanned on every Paths.image()/Paths.sound() call, and it grows to
	// hundreds of entries during a song. A linear `Array.contains` there costs a string compare per
	// entry on hot paths like the per-note hitsound, so keep an O(1) membership index next to it.
	// The array stays public and in sync so mod scripts reflecting into it keep working.
	static var localTrackedSet:Map<String, Bool> = [];

	inline static function trackLocalAsset(key:String):Void
	{
		if (!localTrackedSet.exists(key))
		{
			localTrackedSet.set(key, true);
			localTrackedAssets.push(key);
		}
	}

	inline public static function isLocallyTracked(key:String):Bool
		return localTrackedSet.exists(key);

	// haya I love you for the base cache dump I took to the max
	public static function excludeAsset(key:String):Void
	{
		if (!dumpExclusions.contains(key))
			dumpExclusions.push(key);
	}

	public static function clearUnusedMemory():Void
	{
		// clears non local assets in the tracked assets list
		for (key in currentTrackedAssets.keys())
		{
			// if it is not currently contained within the used local assets
			if (!localTrackedSet.exists(key) && !dumpExclusions.contains(key))
			{
				final obj:FlxGraphic = currentTrackedAssets.get(key);
				if (obj == null)
					continue;
				obj.persist = false;
				obj.destroyOnNoUse = true;
				FlxG.bitmap.remove(obj);
				currentTrackedAssets.remove(key);
			}
		}

		// run the garbage collector after
		System.gc();
		#if cpp
		cpp.NativeGc.run(true);
		#end
	}

	public static function clearStoredMemory():Void
	{
		final keysToRemove:Array<String> = [];
		// clears anything not in the tracked assets list
		@:privateAccess
		for (key in FlxG.bitmap._cache.keys())
		{
			if (!currentTrackedAssets.exists(key))
				keysToRemove.push(key);
		}

		for (key in keysToRemove)
			FlxG.bitmap.removeByKey(key);

		// clear all sounds that are cached
		for (key => asset in currentTrackedSounds)
		{
			if (!localTrackedSet.exists(key) && !dumpExclusions.contains(key) && asset != null)
			{
				Assets.cache.clear(key);
				currentTrackedSounds.remove(key);
			}
		}

		localTrackedAssets = [];
		localTrackedSet = [];
		openfl.Assets.cache.clear("songs");
	}

	public static function getPath(file:String, ?type:AssetType = TEXT, ?library:Null<String> = null, ?modsAllowed:Bool = false):String
	{
		#if USING_GPU_TEXTURES
		// Guard on the extension *before* building the candidate paths - this runs for every
		// getPath() call including sounds/text, and the old order allocated a string per GPU
		// extension every time only to throw them away.
		if (file.endsWith(IMAGE_EXT))
		{
			final base:String = haxe.io.Path.withoutExtension(file);
			for (ext in GPU_IMAGE_EXTS)
			{
				var gpuPath:String = '$base.$ext';
				if (FileSystem.exists(gpuPath))
				{
					file = gpuPath;
					break;
				}
			}
		}
		#end

		#if FEATURE_MODS
		if (modsAllowed)
		{
			var customFile:String = file;
			if (library != null)
				customFile = '$library/$file';

			var modded:String = modFolders(customFile);
			if (FileSystem.exists(modded))
				return modded;
		}
		#end

		if (library == "mobile")
			return getSharedPath('mobile/$file');

		if (library != null)
			return getLibraryPath(file, library);

		return getSharedPath(file);
	}

	public static function getLibraryPath(file:String, library:String = "shared"):String
	{
		return (library == "shared") ? getSharedPath(file) : getLibraryPathForce(file, library);
	}

	static function getLibraryPathForce(file:String, library:String, ?level:String):String
	{
		if (level == null)
			level = library;
		return '$library:assets/$level/$file';
	}

	inline public static function getSharedPath(file:String = ''):String
	{
		return 'assets/shared/$file';
	}

	inline public static function getFolderPath(file:String, folder:String = "shared"):String
	{
		return 'assets/$folder/$file';
	}

	inline public static function txt(key:String, ?library:String):String
	{
		return getPath('data/$key.txt', TEXT, library);
	}

	inline public static function xml(key:String, ?library:String):String
	{
		return getPath('data/$key.xml', TEXT, library);
	}

	inline public static function json(key:String, ?library:String):String
	{
		return getPath('data/$key.json', TEXT, library);
	}

	inline public static function shaderFragment(key:String, ?library:String):String
	{
		return getPath('shaders/$key.frag', TEXT, library);
	}

	inline public static function shaderVertex(key:String, ?library:String):String
	{
		return getPath('shaders/$key.vert', TEXT, library);
	}

	inline public static function lua(key:String, ?library:String):String
	{
		return getPath('$key.lua', TEXT, library);
	}

	inline public static function luau(key:String, ?library:String):String
	{
		return getPath('$key.luau', TEXT, library);
	}

	#if FEATURE_VIDEOS
	public static function video(key:String):String
	{
		#if FEATURE_MODS
		var file:String = modsVideo(key);
		if (FileSystem.exists(file))
			return file;
		#end
		return 'assets/videos/$key.$VIDEO_EXT';
	}
	#end

	inline public static function font(key:String):String
	{
		#if FEATURE_MODS
		var file:String = modsFont(key);
		if (FileSystem.exists(file))
			return file;
		#end
		return 'assets/fonts/$key';
	}

	public static function fileExists(key:String, type:AssetType, ?ignoreMods:Bool = false, ?library:String = null):Bool
	{
		var path:String = getPath(key, type, library, false);

		#if FEATURE_MODS
		if (!ignoreMods)
		{
			var modKey:String = key;
			for (mod in Mods.getGlobalMods())
				if (FileSystem.exists(mods('$mod/$modKey')))
					return true;

			if (FileSystem.exists(mods(Mods.currentModDirectory + '/' + modKey)) || FileSystem.exists(mods(modKey)))
				return true;

			#if USING_GPU_TEXTURES
			if (modKey.endsWith(IMAGE_EXT))
			{
				for (ext in GPU_IMAGE_EXTS)
				{
					var gpuModKey:String = haxe.io.Path.withoutExtension(modKey) + '.$ext';

					for (mod in Mods.getGlobalMods())
						if (FileSystem.exists(mods('$mod/$gpuModKey')))
							return true;

					if (FileSystem.exists(mods(Mods.currentModDirectory + '/' + gpuModKey)) || FileSystem.exists(mods(gpuModKey)))
						return true;
				}
			}
			#end
		}
		#end

		#if USING_GPU_TEXTURES
		if (path.endsWith(IMAGE_EXT))
		{
			for (ext in GPU_IMAGE_EXTS)
				if (FileSystem.exists(haxe.io.Path.withoutExtension(path) + '.$ext'))
					return true;
		}
		#end

		return FileSystem.exists(path);
	}

	public static function getImageAssetType(ext:String):AssetType
	{
		return switch (ext.toLowerCase())
		{
			case 'png' | 'jpg' | 'jpeg': IMAGE;
			default: BINARY;
		}
	}

	#if USING_GPU_TEXTURES
	public static function isGpuImageExt(file:String):Bool
	{
		for (ext in GPU_IMAGE_EXTS)
			if (file.endsWith('.$ext'))
				return true;
		return false;
	}
	#end

	public static function image(key:String, ?library:String = null):FlxGraphic
	{
		var bitmap:BitmapData = null;
		var file:String = null;

		#if FEATURE_MODS
		file = modsImages(key);
		if (currentTrackedAssets.exists(file))
		{
			trackLocalAsset(file);
			return currentTrackedAssets.get(file);
		}
		else if (FileSystem.exists(file))
		{
			bitmap = BitmapData.fromBytes(File.getBytes(file));
		}
		else
		#end
		{
			var exts:Array<String> = [];
			#if USING_GPU_TEXTURES
			for (e in GPU_IMAGE_EXTS)
				exts.push(e);
			#end
			exts.push(IMAGE_EXT);
			for (ext in exts)
			{
				file = getPath('images/$key.$ext', getImageAssetType(ext), library);
				if (currentTrackedAssets.exists(file))
				{
					trackLocalAsset(file);
					return currentTrackedAssets.get(file);
				}
				else if (FileSystem.exists(file))
					bitmap = #if html5 openfl.Assets.getBitmapData(file) #else BitmapData.fromBytes(File.getBytes(file)) #end;

				if (bitmap != null)
					break;
			}
		}

		if (bitmap != null)
		{
			var retVal = cacheBitmap(file, bitmap);
			if (retVal != null)
				return retVal;
		}

		trace('Failed to load image: $file');

		if (currentTrackedAssets.exists('__no_texture'))
		{
			trackLocalAsset('__no_texture');
			return currentTrackedAssets.get('__no_texture');
		}

		return cacheBitmap('__no_texture', FlxAssets.getBitmapFromClass(NoTexture));
	}

	public static function cacheBitmap(file:String, ?bitmap:BitmapData = null):FlxGraphic
	{
		if (bitmap == null)
		{
			if (FileSystem.exists(file))
				bitmap = BitmapData.fromBytes(File.getBytes(file));

			if (bitmap == null)
				return null;
		}

		trackLocalAsset(file);
		/*if (bitmap.readable)
		{
			var texture:RectangleTexture = FlxG.stage.context3D.createRectangleTexture(bitmap.width, bitmap.height, BGRA, true);
			texture.uploadFromBitmapData(bitmap);
			bitmap.image.data = null;
			bitmap.dispose();
			bitmap.disposeImage();
			bitmap = BitmapData.fromTexture(texture);
		}*/
		var newGraphic:FlxGraphic = FlxGraphic.fromBitmapData(bitmap, false, file);
		newGraphic.persist = true;
		newGraphic.destroyOnNoUse = false;
		currentTrackedAssets.set(file, newGraphic);
		return newGraphic;
	}

	public static function getTextFromFile(key:String, ?ignoreMods:Bool = false):String
	{
		#if FEATURE_MODS
		if (!ignoreMods)
		{
			var modPath:String = modFolders(key);
			if (FileSystem.exists(modPath))
				return File.getContent(modPath);
		}
		#end

		var sharedPath:String = getSharedPath(key);
		if (FileSystem.exists(sharedPath))
			return File.getContent(sharedPath);

		return null;
	}

	public static function sound(key:String, ?library:String):Sound
	{
		return returnSound('sounds', key, library);
	}

	inline public static function soundRandom(key:String, min:Int, max:Int, ?library:String):Sound
	{
		return sound(key + FlxG.random.int(min, max), library);
	}

	inline public static function music(key:String, ?library:String):Sound
	{
		return returnSound('music', key, library);
	}

	inline public static function voices(song:String, postfix:String = null):Any
	{
		var songKey:String = 'songs/${formatToSongPath(song)}/Voices${postfix != null ? '-$postfix' : ''}';
		return returnSound(null, songKey);
	}

	inline public static function inst(song:String, postfix:String = null):Sound
	{
		var songKey:String = 'songs/${formatToSongPath(song)}/Inst${postfix != null ? '-$postfix' : ''}';
		return returnSound(null, songKey);
	}

	public static function returnSound(path:Null<String>, key:String, ?library:String):Sound
	{
		#if FEATURE_MODS
		var modLibPath:String = '';
		if (library != null)
			modLibPath = '$library/';
		if (path != null)
			modLibPath += '$path';

		var file:String = modsSounds(modLibPath, key);
		if (FileSystem.exists(file))
		{
			if (!currentTrackedSounds.exists(file))
				currentTrackedSounds.set(file, Sound.fromFile(file));
			trackLocalAsset(file);
			return currentTrackedSounds.get(file);
		}
		#end

		for (ext in SOUND_EXTS)
		{
			var gottenPath:String = '$key.$ext';
			if (path != null)
				gottenPath = '$path/$gottenPath';
			gottenPath = getPath(gottenPath, SOUND, library);
			gottenPath = gottenPath.substring(gottenPath.indexOf(':') + 1, gottenPath.length);

			if (!currentTrackedSounds.exists(gottenPath))
			{
				var retKey:String = (path != null) ? '$path/$key' : key;
				retKey = getPath('$retKey.$ext', SOUND, library);
				if (FileSystem.exists(retKey))
					currentTrackedSounds.set(gottenPath, #if html5 openfl.Assets.getSound(retKey) #else Sound.fromBytes(File.getBytes(retKey)) #end);
			}

			if (currentTrackedSounds.exists(gottenPath))
			{
				trackLocalAsset(gottenPath);
				return currentTrackedSounds.get(gottenPath);
			}
		}

		return null;
	}

	public static function getAtlas(key:String, ?library:String = null):FlxAtlasFrames
	{
		var imageLoaded:FlxGraphic = image(key, library);

		var xmlPath:String = getPath('images/$key.xml', TEXT, library, true);
		#if FEATURE_MODS
		var modXml:String = modsXml(key);
		if (FileSystem.exists(modXml))
			return FlxAtlasFrames.fromSparrow(imageLoaded, File.getContent(modXml));
		#end

		if (FileSystem.exists(xmlPath))
			return FlxAtlasFrames.fromSparrow(imageLoaded, File.getContent(xmlPath));

		var jsonPath:String = getPath('images/$key.json', TEXT, library, true);
		#if FEATURE_MODS
		var modJson:String = modsImagesJson(key);
		if (FileSystem.exists(modJson))
			return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, File.getContent(modJson));
		#end

		if (FileSystem.exists(jsonPath))
			return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, File.getContent(jsonPath));

		return getPackerAtlas(key, library);
	}

	public static function getSparrowAtlas(key:String, ?library:String = null):FlxAtlasFrames
	{
		var imageLoaded:FlxGraphic = image(key, library);

		#if FEATURE_MODS
		var modXml:String = modsXml(key);
		if (FileSystem.exists(modXml))
			return FlxAtlasFrames.fromSparrow(imageLoaded, File.getContent(modXml));
		#end

		var xmlPath:String = getPath('images/$key.xml', library);
		return FlxAtlasFrames.fromSparrow(imageLoaded, File.getContent(xmlPath));
	}

	public static function getPackerAtlas(key:String, ?library:String = null):FlxAtlasFrames
	{
		var imageLoaded:FlxGraphic = image(key, library);

		#if FEATURE_MODS
		var modTxt:String = modsTxt(key);
		if (FileSystem.exists(modTxt))
			return FlxAtlasFrames.fromSpriteSheetPacker(imageLoaded, File.getContent(modTxt));
		#end

		var txtPath:String = getPath('images/$key.txt', library);
		return FlxAtlasFrames.fromSpriteSheetPacker(imageLoaded, File.getContent(txtPath));
	}

	public static function getAsepriteAtlas(key:String, ?library:String = null):FlxAtlasFrames
	{
		var imageLoaded:FlxGraphic = image(key, library);

		#if FEATURE_MODS
		var modJson:String = modsImagesJson(key);
		if (FileSystem.exists(modJson))
			return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, File.getContent(modJson));
		#end

		var jsonPath:String = getPath('images/$key.json', library);
		return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, File.getContent(jsonPath));
	}

	public static function getTextureAtlas(key:String, ?library:String = null, ?settings:FlxAnimateSettings):FlxAnimateFrames
	{
		if (settings == null)
			settings = {};

		if (settings.filterQuality == null && ClientPrefs.data.lowQuality)
			settings.filterQuality = FilterQuality.LOW;

		var animateFolder:String = getPath('images/$key', library);

		#if FEATURE_MODS
		var modFolder:String = modFolders('images/' + key);
		if (FileSystem.exists(modFolder) && FileSystem.isDirectory(modFolder))
			return FlxAnimateFrames.fromAnimate(modFolder, settings);
		#end

		return FlxAnimateFrames.fromAnimate(animateFolder, settings);
	}

	public static function isTextureAtlas(key:String, ?library:String = null):Bool
	{
		return fileExists('images/$key/Animation.json', TEXT, false, library)
			|| fileExists('images/$key/spritemap1.json', TEXT, false, library);
	}

	public static function getMixedAtlas(keys:Array<String>, ?library:String = null, ?settings:FlxAnimateSettings):FlxAtlasFrames
	{
		var atlases:Array<FlxAtlasFrames> = [];
		for (key in keys)
		{
			var atlas:FlxAtlasFrames = isTextureAtlas(key, library) ? getTextureAtlas(key, library, settings) : getAtlas(key, library);
			if (atlas != null)
				atlases.push(atlas);
		}

		if (atlases.length == 0)
			return null;
		if (atlases.length == 1)
			return atlases[0];

		var base:FlxAtlasFrames = null;
		for (atlas in atlases)
			if (atlas is FlxAnimateFrames)
			{
				base = atlas;
				break;
			}
		if (base == null)
			base = atlases[0];

		for (atlas in atlases)
			if (atlas != base)
				base.addAtlas(atlas);

		return base;
	}

	public static function formatToSongPath(path:String):String
	{
		var invalidChars = ~/[~&\\;:<>#]/;
		var hideChars = ~/[.,'"%?!]/;

		var formattedPath = invalidChars.split(path.replace(' ', '-')).join("-");
		return hideChars.split(formattedPath).join("").toLowerCase();
	}

	#if FEATURE_MODS
	inline public static function mods(key:String = ''):String
	{
		return #if mobile Sys.getCwd() + #end 'mods/' + key;
	}

	inline public static function modsFont(key:String):String
	{
		return modFolders('fonts/' + key);
	}

	inline public static function modsJson(key:String):String
	{
		return modFolders('data/' + key + '.json');
	}

	#if FEATURE_VIDEOS
	inline public static function modsVideo(key:String):String
	{
		return modFolders('videos/' + key + '.' + VIDEO_EXT);
	}
	#end

	public static function modsSounds(path:String, key:String):String
	{
		for (ext in SOUND_EXTS)
		{
			var file:String = modFolders(path + '/' + key + '.' + ext);
			if (FileSystem.exists(file))
				return file;
		}
		return modFolders(path + '/' + key + '.ogg');
	}

	public static function modsImages(key:String):String
	{
		#if USING_GPU_TEXTURES
		for (ext in GPU_IMAGE_EXTS)
		{
			var gpuFile:String = modFolders('images/' + key + '.$ext');
			if (FileSystem.exists(gpuFile))
				return gpuFile;
		}
		#end

		return modFolders('images/' + key + '.${IMAGE_EXT}');
	}

	inline public static function modsXml(key:String):String
	{
		return modFolders('images/' + key + '.xml');
	}

	inline public static function modsTxt(key:String):String
	{
		return modFolders('images/' + key + '.txt');
	}

	inline public static function modsImagesJson(key:String):String
	{
		return modFolders('images/' + key + '.json');
	}

	public static function modFolders(key:String):String
	{
		if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
		{
			var fileToCheck:String = mods(Mods.currentModDirectory + '/' + key);
			if (FileSystem.exists(fileToCheck))
				return fileToCheck;
		}

		for (mod in Mods.getGlobalMods())
		{
			var fileToCheck:String = mods(mod + '/' + key);
			if (FileSystem.exists(fileToCheck))
				return fileToCheck;
		}

		return #if mobile Sys.getCwd() + #end 'mods/' + key;
	}
	#end
}

@:bitmap('assets/embed/images/no_texture.png')
class NoTexture extends BitmapData
{
}
