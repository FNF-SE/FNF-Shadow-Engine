package backend.scripting;

import haxe.io.Path;
import hscript.SScript;
import psychlua.FunkinLua;
import psychlua.LuaUtils;
import psychlua.HScript;
import backend.IMusicState;

typedef CallOptions =
{
	?ignoreStops:Bool,
	?exclusions:Array<String>,
	?excludeValues:Array<Dynamic>
}

class ScriptManager
{
	public var luaArray:Array<FunkinLua> = [];
	public var hscriptArray:Array<HScript> = [];
	public var instancesExclude:Array<String> = [];
	public var publicVariables:Map<String, Dynamic> = new Map();

	public final hscriptExtensions:Array<String> = ['hx', 'hscript', 'hxs', 'hxc'];
	public final luaExtensions:Array<String> = ['lua', 'luau'];

	var state:IMusicState;

	public function new(state:IMusicState)
	{
		this.state = state;
	}

	public function call(funcToCall:String, args:Array<Dynamic> = null, ?opts:CallOptions):Dynamic
	{
		if (luaArray.length == 0 && hscriptArray.length == 0)
			return ScriptResult.Continue;

		if (opts == null)
			opts = {};
		if (args == null)
			args = [];
		if (opts.exclusions == null)
			opts.exclusions = [];
		if (opts.excludeValues == null)
			opts.excludeValues = [ScriptResult.Continue];

		var luaResult = callOnLuas(funcToCall, args, opts);
		var hsResult = callOnHScript(funcToCall, args, opts);
		if (hsResult != null && !opts.excludeValues.contains(hsResult))
			return hsResult;
		return luaResult;
	}

	public function callOnLuas(funcToCall:String, args:Array<Dynamic> = null, ?opts:CallOptions):Dynamic
	{
		var returnVal:Dynamic = ScriptResult.Continue;
		#if FEATURE_LUA
		if (luaArray.length == 0)
			return returnVal;

		if (opts == null)
			opts = {};
		if (args == null)
			args = [];
		if (opts.exclusions == null)
			opts.exclusions = [];
		if (opts.excludeValues == null)
			opts.excludeValues = [ScriptResult.Continue];

		var toRemove:Array<FunkinLua> = [];
		for (script in luaArray)
		{
			if (script.closed)
			{
				toRemove.push(script);
				continue;
			}

			if (opts.exclusions.contains(script.scriptName))
				continue;

			var myValue:Dynamic = script.call(funcToCall, args);
			if ((myValue == ScriptResult.StopLua || myValue == ScriptResult.StopAll)
				&& !opts.excludeValues.contains(myValue)
				&& !opts.ignoreStops)
			{
				returnVal = myValue;
				break;
			}

			if (myValue != null && !opts.excludeValues.contains(myValue))
				returnVal = myValue;

			if (script.closed)
				toRemove.push(script);
		}

		for (script in toRemove)
			luaArray.remove(script);
		#end
		return returnVal;
	}

	public function callOnHScript(funcToCall:String, args:Array<Dynamic> = null, ?opts:CallOptions):Dynamic
	{
		var returnVal:Dynamic = ScriptResult.Continue;

		#if FEATURE_HSCRIPT
		if (hscriptArray.length == 0)
			return returnVal;

		if (opts == null)
			opts = {};
		if (args == null)
			args = [];
		if (opts.exclusions == null)
			opts.exclusions = [];
		if (opts.excludeValues == null)
			opts.excludeValues = [ScriptResult.Continue];
		opts.excludeValues.push(ScriptResult.Continue);

		for (script in hscriptArray)
		{
			if (script == null || !script.exists(funcToCall) || opts.exclusions.contains(script.origin))
				continue;

			try
			{
				var callValue = script.call(funcToCall, args);
				if (!callValue.succeeded)
				{
					var e = callValue.exceptions[0];
					if (e != null)
						state.addTextToDebug('ERROR (${callValue.calledFunction}) - ' + e.details(), FlxColor.RED);
				}
				else
				{
					var myValue = callValue.returnValue;
					if ((myValue == ScriptResult.StopHScript || myValue == ScriptResult.StopAll)
						&& !opts.excludeValues.contains(myValue)
						&& !opts.ignoreStops)
					{
						returnVal = myValue;
						break;
					}
					if (myValue != null && !opts.excludeValues.contains(myValue))
						returnVal = myValue;
				}
			}
		}
		#end

		return returnVal;
	}

	public function set(variable:String, arg:Dynamic, exclusions:Array<String> = null)
	{
		if (exclusions == null)
			exclusions = [];
		setOnLuas(variable, arg, exclusions);
		setOnHScript(variable, arg, exclusions);
	}

	public function setOnLuas(variable:String, arg:Dynamic, exclusions:Array<String> = null)
	{
		#if FEATURE_LUA
		if (exclusions == null)
			exclusions = [];
		for (script in luaArray)
		{
			if (exclusions.contains(script.scriptName))
				continue;
			script.set(variable, arg);
		}
		#end
	}

	public function setOnHScript(variable:String, arg:Dynamic, exclusions:Array<String> = null)
	{
		#if FEATURE_HSCRIPT
		if (exclusions == null)
			exclusions = [];
		for (script in hscriptArray)
		{
			if (exclusions.contains(script.origin))
				continue;
			if (!instancesExclude.contains(variable))
				instancesExclude.push(variable);
			script.set(variable, arg);
		}
		#end
	}

	#if FEATURE_LUA
	public function startLuasNamed(luaFile:String, ?doFileMethod:String->Bool):Bool
	{
		function doFile(file:String):Bool
		{
			if (!luaExtensions.contains(Path.extension(file)))
				return false;

			if (doFileMethod != null)
				return doFileMethod(luaFile);

			var luaToLoad:String = file;
			if (!FileSystem.exists(luaToLoad))
			{
				#if FEATURE_MODS
				luaToLoad = Paths.modFolders(file);
				if (!FileSystem.exists(luaToLoad))
				#end
				luaToLoad = Paths.getSharedPath(file);
			}

			if (FileSystem.exists(luaToLoad))
			{
				for (script in luaArray)
					if (script.scriptName == luaToLoad)
						return false;

				new FunkinLua(luaToLoad);
				return true;
			}
			return false;
		}

		var ext = Path.extension(luaFile);
		if (ext != null && ext.length > 0 && luaExtensions.contains(ext))
			return doFile(luaFile);

		var loaded = false;
		for (ext in luaExtensions)
			if (doFile(Path.withExtension(luaFile, ext)))
				loaded = true;
		return loaded;
	}
	#end

	#if FEATURE_HSCRIPT
	public function startHScriptsNamed(scriptFile:String, ?doFileMethod:String->Bool):Bool
	{
		function doFile(file:String):Bool
		{
			if (!hscriptExtensions.contains(Path.extension(file)))
				return false;

			if (doFileMethod != null)
				return doFileMethod(scriptFile);

			var scriptToLoad:String = file;
			if (!FileSystem.exists(scriptToLoad))
			{
				#if FEATURE_MODS
				scriptToLoad = Paths.modFolders(file);
				if (!FileSystem.exists(scriptToLoad))
				#end
				scriptToLoad = Paths.getSharedPath(file);
			}

			if (FileSystem.exists(scriptToLoad))
			{
				if (SScript.global.exists(scriptToLoad))
					return false;
				initHScript(scriptToLoad);
				return true;
			}
			return false;
		}

		var ext = Path.extension(scriptFile);
		if (ext != null && ext.length > 0 && hscriptExtensions.contains(ext))
			return doFile(scriptFile);

		var loaded = false;
		for (ext in hscriptExtensions)
			if (doFile(Path.withExtension(scriptFile, ext)))
				loaded = true;
		return loaded;
	}

	public function initHScript(file:String):Void
	{
		try
		{
			var times:Float = Date.now().getTime();
			var newScript = new HScript(null, file, null, publicVariables);
			if (newScript.parsingException != null)
			{
				state.addTextToDebug('ERROR ON LOADING: ${newScript.parsingException.message}', FlxColor.RED);
				newScript.destroy();
				return;
			}

			trace('initialized hscript interp successfully: $file (${Std.int(Date.now().getTime() - times)}ms)');
			hscriptArray.push(newScript);
			if (newScript.exists('onCreate'))
			{
				var callValue = newScript.call('onCreate');
				if (!callValue.succeeded)
				{
					for (e in callValue.exceptions)
					{
						if (e != null)
							state.addTextToDebug('ERROR ($file: onCreate) - ${e.details()}', FlxColor.RED);
					}
					newScript.destroy();
					hscriptArray.remove(newScript);
				}
			}
		}
		catch (e)
		{
			state.addTextToDebug('ERROR - ' + e.details(), FlxColor.RED);
			var old = cast(SScript.global.get(file), HScript);
			if (old != null)
			{
				old.destroy();
				hscriptArray.remove(old);
			}
		}
	}
	#end

	public function stop():Void
	{
		#if FEATURE_LUA
		for (lua in luaArray)
			lua.stop();
		#end

		#if FEATURE_HSCRIPT
		for (script in hscriptArray)
		{
			if (script != null)
				script.stop();
		}
		#end
	}

	public function destroy():Void
	{
		#if FEATURE_LUA
		for (lua in luaArray)
		{
			lua.call('onDestroy', []);
			lua.stop();
		}
		luaArray = [];
		FunkinLua.customFunctions.clear();
		#end

		#if FEATURE_HSCRIPT
		for (script in hscriptArray)
		{
			if (script != null)
			{
				script.call('onDestroy');
				script.destroy();
			}
		}
		hscriptArray.resize(0);
		HScript.sharedStaticVariables.clear();
		#end
	}
}
