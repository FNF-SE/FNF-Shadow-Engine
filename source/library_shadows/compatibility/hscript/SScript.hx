package hscript;

import haxe.ds.*;
import haxe.Constraints.IMap;
import haxe.Exception;
import haxe.Timer;
import hscript.Expr;
import backend.io.FileSystem;
import backend.io.File;

using StringTools;

@:structInit
@:access(hscript.Interp)
@:access(hscript.Parser)
@:keepSub
class SScript
{
	public static var IGNORE_RETURN(default, never):Dynamic = "###SSCRIPT_IGNORE_RETURN";
	public static var STOP_RETURN(default, never):Dynamic = "###SSCRIPT_STOP_RETURN";

	public static var defaultTypeCheck(default, set):Null<Bool> = true;
	public static var defaultDebug(default, set):Null<Bool> = #if debug true #else null #end;

	public static var globalVariables:SScriptGlobalMap = new SScriptGlobalMap();
	public static var global(default, null):Map<String, SScript> = [];

	static var IDCount(default, null):Int = 0;
	static var BlankReg(get, never):EReg;

	public var customOrigin(default, set):String;
	public var returnValue(default, null):Null<Dynamic> = null;
	public var ID(default, null):Null<Int> = null;
	public var typeCheck:Bool = false;
	public var lastReportedTime(default, null):Float = -1;
	public var lastReportedCallTime(default, null):Float = -1;
	public var notAllowedClasses(default, null):Array<Class<Dynamic>> = [];
	public var variables(get, never):Map<String, Dynamic>;

	public var interp(default, null):Interp;
	public var parser(default, null):Parser;
	public var script(default, null):String = "";
	public var active:Bool = true;
	public var scriptFile(default, null):String = "";
	public var traces:Bool = false;
	public var debugTraces:Bool = #if debug true #else false #end;
	public var parsingException(default, null):SScriptException;
	public var packagePath(get, null):String = "";

	@:deprecated("parsingExceptions are deprecated, use parsingException instead")
	var parsingExceptions(get, never):Array<Exception>;

	@:noPrivateAccess var _destroyed(default, null):Bool = false;

	public function new(?scriptPath:String = "", ?preset:Bool = true, ?startExecute:Bool = true)
	{
		var time = Timer.stamp();

		if (defaultTypeCheck != null)
			typeCheck = defaultTypeCheck;
		if (defaultDebug != null)
			debugTraces = defaultDebug;

		interp = new Interp();
		interp.setScr(this);

		parser = new Parser();
		parser.allowTypes = true;
		parser.allowMetadata = true;

		if (preset)
		{
			if (debugTraces)
				trace('SScript constructor: calling preset()');
			this.preset();
		}
		else
		{
			if (debugTraces)
				trace('SScript constructor: preset skipped');
		}

		for (i => k in globalVariables)
		{
			if (i != null)
				set(i, k);
		}

		try
		{
			doFile(scriptPath);
			if (startExecute)
			{
				if (debugTraces)
					trace('SScript constructor: calling execute()');
				execute();
			}
			else
			{
				if (debugTraces)
					trace('SScript constructor: execute skipped (will be called later)');
			}
			lastReportedTime = Timer.stamp() - time;

			if (debugTraces && scriptPath != null && scriptPath.length > 0)
			{
				if (lastReportedTime == 0)
					trace('SScript instance created instantly (0s)');
				else
					trace('SScript instance created in ${lastReportedTime}s');
			}
		}
		catch (e:Dynamic)
		{
			lastReportedTime = -1;
			parsingException = SScriptException.fromDynamic(e);
			if (debugTraces)
				trace('SScript constructor error: $e');
		}
	}

	public function execute():Void
	{
		if (_destroyed)
		{
			if (traces)
				trace('SScript execute: destroyed');
			return;
		}

		if (interp == null || !active)
		{
			if (traces)
				trace('SScript execute: interp null or not active');
			return;
		}

		var origin:String =
			{
				if (customOrigin != null && customOrigin.length > 0)
					customOrigin;
				else if (scriptFile != null && scriptFile.length > 0)
					scriptFile;
				else
					"SScript";
			};

		if (script != null && script.length > 0)
		{
			if (traces)
				trace('SScript execute: about to run script, origin=' + origin);
			resetInterp();

			try
			{
				var expr:Expr = parser.parseString(script, origin);
				var r = interp.execute(expr);
				returnValue = r;
				if (traces)
					trace('SScript execute: success');
			}
			catch (e:Dynamic)
			{
				parsingException = SScriptException.fromDynamic(e);
				returnValue = null;
				if (traces)
					trace('SScript execute error: $e');
			}
		}
		else
		{
			if (traces)
				trace('SScript execute: no script');
		}
	}

	public function set(key:String, obj:Dynamic):SScript
	{
		if (_destroyed)
			return null;

		if (obj != null && (obj is Class) && notAllowedClasses.contains(obj))
			throw 'Tried to set ${Type.getClassName(obj)} which is not allowed.';

		function setVar(key:String, obj:Dynamic):Void
		{
			if (key == null)
				return;

			if (Tools.keys.contains(key))
				throw '$key is a keyword, set something else';

			if (!active)
				return;

			if (interp == null || !active)
			{
				if (traces)
				{
					if (interp == null)
						trace("This script is unusable!");
					else
						trace("This script is not active!");
				}
			}
			else
				interp.variables[key] = obj;
		}

		setVar(key, obj);
		return this;
	}

	public function setClass(cl:Class<Dynamic>):SScript
	{
		if (_destroyed)
			return null;

		if (cl == null)
		{
			if (traces)
				trace('Class cannot be null');
			return null;
		}

		var clName:String = Type.getClassName(cl);
		if (clName != null)
		{
			var splitCl:Array<String> = clName.split('.');
			if (splitCl.length > 1)
				clName = splitCl[splitCl.length - 1];
			set(clName, cl);
		}
		return this;
	}

	public function setClassString(cl:String):SScript
	{
		if (_destroyed)
			return null;

		if (cl == null || cl.length < 1)
		{
			if (traces)
				trace('Class cannot be null');
			return null;
		}

		var cls:Class<Dynamic> = Type.resolveClass(cl);
		if (cls != null)
		{
			if (cl.split('.').length > 1)
				cl = cl.split('.')[cl.split('.').length - 1];
			set(cl, cls);
		}
		return this;
	}

	public function setSpecialObject(obj:Dynamic, ?includeFunctions:Bool = true, ?exclusions:Array<String>):SScript
	{
		if (_destroyed)
			return null;
		if (!active)
			return this;
		if (obj == null)
			return this;
		if (exclusions == null)
			exclusions = new Array();

		var types:Array<Dynamic> = [Int, String, Float, Bool, Array];
		for (i in types)
			if (Std.isOfType(obj, i))
				throw 'Special object cannot be ${i}';

		interp.specialObject = {obj: obj, includeFunctions: includeFunctions, exclusions: exclusions.copy()};
		return this;
	}

	public function locals():Map<String, Dynamic>
	{
		if (_destroyed)
			return null;

		if (!active)
			return [];

		var newMap:Map<String, Dynamic> = new Map();
		if (interp.locals != null)
		{
			for (i in interp.locals.keys())
			{
				var v = interp.locals[i];
				if (v != null)
					newMap[i] = v.r;
			}
		}
		return newMap;
	}

	public function unset(key:String):SScript
	{
		if (_destroyed)
			return null;

		if (interp == null || !active || key == null || !interp.variables.exists(key))
			return null;

		interp.variables.remove(key);
		return this;
	}

	public function get(key:String):Dynamic
	{
		if (_destroyed)
			return null;

		if (interp == null || !active)
		{
			if (traces)
			{
				if (interp == null)
					trace("This script is unusable!");
				else
					trace("This script is not active!");
			}
			return null;
		}

		// Same as exists(): read the scopes directly rather than building a throwaway copy of the
		// local scope (and then building it a second time inside exists()).
		if (interp.locals != null)
		{
			final declared = interp.locals.get(key);
			if (declared != null)
				return declared.r;
		}

		return interp.variables.get(key);
	}

	public function call(func:String, ?args:Array<Dynamic>):FunctionCall
	{
		if (_destroyed)
			return {
				exceptions: [
					new SScriptException(new Exception((if (scriptFile != null && scriptFile.length > 0) scriptFile else "SScript instance")
						+ " is destroyed."))
				],
				calledFunction: func,
				succeeded: false,
				returnValue: null
			};

		if (!active)
			return {
				exceptions: [
					new SScriptException(new Exception((if (scriptFile != null && scriptFile.length > 0) scriptFile else "SScript instance")
						+ " is not active."))
				],
				calledFunction: func,
				succeeded: false,
				returnValue: null
			};

		// Restructured for the hot path. This function is invoked for every scripted event, on every
		// loaded script, every frame (onUpdate/onUpdatePost) plus several times per note hit, so the
		// original version's fixed overhead added up fast. It used to, on *every* call:
		//   - build the result structure plus an empty exceptions array up front,
		//   - allocate a `pushedExceptions` array and a `pushException` closure that the happy path
		//     never touches,
		//   - resolve the function via get() and then re-check exists() twice more - and back when
		//     get()/exists() went through locals(), each of those copied the whole local scope into
		//     a freshly allocated Map,
		//   - allocate a second result structure on success.
		// Now the happy path is: one scope lookup, one Reflect.callMethod, one result structure.
		final time:Float = Timer.stamp();
		final scriptFile:String = if (scriptFile != null && scriptFile.length > 0) scriptFile else "";

		if (args == null)
			args = new Array();

		// Only materialised when something actually goes wrong.
		var exceptions:Null<Array<SScriptException>> = null;
		var pushedExceptions:Null<Array<String>> = null;

		inline function pushException(e:String)
		{
			if (exceptions == null)
			{
				exceptions = new Array();
				pushedExceptions = new Array();
			}
			if (!pushedExceptions.contains(e))
				exceptions.push(new SScriptException(new Exception(e)));
			pushedExceptions.push(e);
		}

		inline function result(succeeded:Bool, returnValue:Dynamic):FunctionCall
		{
			lastReportedCallTime = Timer.stamp() - time;
			return {
				exceptions: exceptions != null ? exceptions : [],
				calledFunction: func,
				succeeded: succeeded,
				returnValue: returnValue
			};
		}

		if (func == null)
		{
			if (traces)
				trace('Function name cannot be null for $scriptFile!');
			pushException('Function name cannot be null for $scriptFile!');
			return result(false, null);
		}

		if (interp == null)
		{
			if (traces)
				trace('Interpreter is null!');
			pushException('Interpreter is null!');
			return result(false, null);
		}

		// One lookup instead of get() + exists() + exists(). A non-null value means the name is
		// bound, so exists() is only consulted to tell "bound to null" apart from "not bound".
		final fun:Dynamic = get(func);
		if (fun == null && !exists(func))
		{
			if (traces)
				trace('Function $func does not exist in $scriptFile.');
			if (scriptFile != null && scriptFile.length > 1)
				pushException('Function $func does not exist in $scriptFile.');
			else
				pushException('Function $func does not exist in SScript instance.');
			return result(false, null);
		}

		if (Type.typeof(fun) != TFunction)
		{
			if (traces)
				trace('$func is not a function');
			pushException('$func is not a function');
			return result(false, null);
		}

		var succeeded:Bool = false;
		var returnValue:Dynamic = null;
		try
		{
			returnValue = Reflect.callMethod(this, fun, args);
			succeeded = true;
		}
		catch (e)
		{
			if (exceptions == null)
			{
				exceptions = new Array();
				pushedExceptions = new Array();
			}
			exceptions.insert(0, SScriptException.fromDynamic(e));
		}

		return result(succeeded, returnValue);
	}

	public function clear():SScript
	{
		if (_destroyed)
			return null;
		if (!active)
			return this;

		if (interp == null)
			return this;

		var importantThings:Array<String> = ['true', 'false', 'null', 'trace'];

		for (i in interp.variables.keys())
			if (!importantThings.contains(i))
				interp.variables.remove(i);

		return this;
	}

	public function exists(key:String):Bool
	{
		if (_destroyed)
			return false;
		if (!active)
			return false;
		if (interp == null)
			return false;

		// This used to go through `locals()`, which allocates a fresh Map and copies every entry of
		// `interp.locals` into it - just to answer a membership question. exists() is on the hottest
		// path in the engine (ScriptManager.callOnHScript calls it for every event, on every script,
		// and call() below used to call it up to three more times), so query the scope directly.
		if (interp.locals != null && interp.locals.exists(key))
			return true;

		return interp.variables.exists(key);
	}

	public function preset():Void
	{
		if (_destroyed)
			return;
		if (!active)
			return;

		setClass(Date);
		setClass(DateTools);
		setClass(EReg);
		setClass(Math);
		setClass(Reflect);
		setClass(Std);
		setClass(SScript);
		setClass(StringTools);
		setClass(Type);
		setClass(List);
		setClass(StringBuf);
		setClass(Xml);
		setClass(haxe.Http);
		setClass(haxe.Json);
		setClass(haxe.Log);
		setClass(haxe.Serializer);
		setClass(haxe.Unserializer);
		setClass(haxe.Timer);

		#if sys
		setClass(Sys);
		setClass(sys.FileSystem);
		setClass(sys.io.File);
		setClass(sys.io.Process);
		setClass(sys.io.FileInput);
		setClass(sys.io.FileOutput);
		#end
	}

	function resetInterp():Void
	{
		if (_destroyed)
			return;
		if (interp == null)
			return;

		interp.locals = new Map();
		while (interp.declared.length > 0)
			interp.declared.pop();
	}

	function doFile(scriptPath:String):Void
	{
		parsingException = null;

		if (_destroyed)
			return;

		if (scriptPath == null || scriptPath.length < 1 || BlankReg.match(scriptPath))
		{
			ID = IDCount + 1;
			IDCount++;
			global[Std.string(ID)] = this;
			return;
		}

		if (scriptPath != null && scriptPath.length > 0)
		{
			if (FileSystem.exists(scriptPath))
			{
				scriptFile = scriptPath;
				script = File.getContent(scriptPath);
			}
			else
			{
				scriptFile = "";
				script = scriptPath;
			}

			if (scriptFile != null && scriptFile.length > 0)
				global[scriptFile] = this;
			else if (script != null && script.length > 0)
				global[script] = this;
		}
	}

	public function doString(string:String, ?origin:String):SScript
	{
		if (_destroyed)
			return null;
		if (!active)
			return null;
		if (string == null || string.length < 1 || BlankReg.match(string))
			return this;

		parsingException = null;

		var time = Timer.stamp();
		try
		{
			var og:String = origin;
			if (og != null && og.length > 0)
				customOrigin = og;
			if (og == null || og.length < 1)
				og = customOrigin;
			if (og == null || og.length < 1)
				og = "SScript";

			if (!active || interp == null)
				return null;

			resetInterp();

			try
			{
				script = string;

				if (scriptFile != null && scriptFile.length > 0)
				{
					if (ID != null)
						global.remove(Std.string(ID));
					global[scriptFile] = this;
				}
				else if (script != null && script.length > 0)
				{
					if (ID != null)
						global.remove(Std.string(ID));
					global[script] = this;
				}

				var expr:Expr = parser.parseString(script, og);
				var r = interp.execute(expr);
				returnValue = r;

				if (traces)
				{
					var execTime = Timer.stamp() - time;
					if (execTime == 0)
						trace('SScript doString executed instantly');
					else
						trace('SScript doString executed in ${execTime}s');
				}
			}
			catch (e:Dynamic)
			{
				script = "";
				parsingException = SScriptException.fromDynamic(e);
				returnValue = null;
				if (traces)
				{
					trace('SScript doString error: $e');
				}
			}

			lastReportedTime = Timer.stamp() - time;
		}
		catch (e:Dynamic)
		{
			lastReportedTime = -1;
			parsingException = SScriptException.fromDynamic(e);
			if (traces)
			{
				trace('SScript doString fatal error: $e');
			}
		}

		return this;
	}

	inline function toString():String
	{
		if (_destroyed)
			return "null";
		if (scriptFile != null && scriptFile.length > 0)
			return scriptFile;
		return "[SScript SScript]";
	}

	public static function listScripts(path:String, ?extensions:Array<String>):Array<SScript>
	{
		if (!path.endsWith('/'))
			path += '/';

		if (extensions == null || extensions.length < 1)
			extensions = ['hx'];

		var list:Array<SScript> = [];
		if (FileSystem.exists(path) && FileSystem.isDirectory(path))
		{
			var files:Array<String> = FileSystem.readDirectory(path);
			for (i in files)
			{
				var hasExtension:Bool = false;
				for (l in extensions)
				{
					if (i.endsWith(l))
					{
						hasExtension = true;
						break;
					}
				}
				if (hasExtension && FileSystem.exists(path + i))
					list.push(new SScript(path + i));
			}
		}

		return list;
	}

	public function stop():Void
	{
		active = false;
		clear();
		resetInterp();
	}

	public function destroy():Void
	{
		if (_destroyed)
			return;

		if (global.exists(script) && script != null && script.length > 0)
			global.remove(script);
		if (global.exists(scriptFile) && scriptFile != null && scriptFile.length > 0)
			global.remove(scriptFile);

		clear();
		resetInterp();

		customOrigin = null;
		parser = null;
		interp = null;
		script = null;
		scriptFile = null;
		active = false;
		notAllowedClasses = null;
		lastReportedCallTime = -1;
		lastReportedTime = -1;
		ID = null;
		parsingException = null;
		returnValue = null;
		_destroyed = true;
	}

	function get_variables():Map<String, Dynamic>
	{
		if (_destroyed)
			return null;
		return interp.variables;
	}

	function get_packagePath():String
	{
		if (_destroyed)
			return null;
		return packagePath;
	}

	static function get_BlankReg():EReg
	{
		return ~/^[\n\r\t]$/;
	}

	function set_customOrigin(value:String):String
	{
		if (_destroyed)
			return null;
		#if hscriptPos
		@:privateAccess parser.origin = value;
		#end
		return customOrigin = value;
	}

	static function set_defaultTypeCheck(value:Null<Bool>):Null<Bool>
	{
		for (i in global)
		{
			i.typeCheck = value == null ? false : value;
		}
		return defaultTypeCheck = value;
	}

	static function set_defaultDebug(value:Null<Bool>):Null<Bool>
	{
		for (i in global)
		{
			i.debugTraces = value == null ? false : value;
		}
		return defaultDebug = value;
	}

	function get_parsingExceptions():Array<Exception>
	{
		if (_destroyed)
			return null;
		if (parsingException == null)
			return [];
		return [parsingException.toException()];
	}
}

abstract SScriptException(Exception)
{
	public var message(get, never):String;

	public function new(exception:Exception)
		this = exception;

	@:from
	public static function fromException(exception:Exception):SScriptException
		return new SScriptException(exception);

	public static function fromDynamic(e:Dynamic):SScriptException
	{
		if (Std.isOfType(e, Exception))
			return new SScriptException(cast e);
		return new SScriptException(new Exception(Std.string(e)));
	}

	@:to
	public function toString():String
		return message;

	public function details():String
		return this.details();

	function get_message():String
		return Std.string(this);

	public function toException():Exception
		return this;
}

typedef SScriptGlobalMap = SScriptTypedGlobalMap<String, Dynamic>;

@:transitive
@:multiType(@:followWithAbstracts K)
abstract SScriptTypedGlobalMap<K, V>(IMap<K, V>)
{
	public function new();

	public inline function set(key:K, value:V)
	{
		this.set(key, value);

		var key:String = cast key;
		var value:Dynamic = cast value;
		for (i in SScript.global)
		{
			@:privateAccess
			if (!i._destroyed)
				i.set(key, value);
		}
	}

	@:arrayAccess public inline function get(key:K)
		return this.get(key);

	public inline function exists(key:K)
		return this.exists(key);

	public inline function remove(key:K)
		return this.remove(key);

	public inline function keys():Iterator<K>
		return this.keys();

	public inline function iterator():Iterator<V>
		return this.iterator();

	public inline function keyValueIterator():KeyValueIterator<K, V>
		return this.keyValueIterator();

	public inline function copy():Map<K, V>
		return cast this.copy();

	public inline function toString():String
		return this.toString();

	public inline function clear():Void
		this.clear();

	@:arrayAccess @:noCompletion public inline function arrayWrite(k:K, v:V):V
	{
		this.set(k, v);
		var key:String = cast k;
		var value:Dynamic = cast v;
		for (i in SScript.global)
		{
			@:privateAccess
			if (!i._destroyed)
				i.set(key, value);
		}
		return v;
	}

	@:to static inline function toStringMap<K:String, V>(t:IMap<K, V>):StringMap<V>
		return new StringMap<V>();

	@:to static inline function toIntMap<K:Int, V>(t:IMap<K, V>):IntMap<V>
		return new IntMap<V>();

	@:to static inline function toEnumValueMapMap<K:EnumValue, V>(t:IMap<K, V>):EnumValueMap<K, V>
		return new EnumValueMap<K, V>();

	@:to static inline function toObjectMap<K:{}, V>(t:IMap<K, V>):ObjectMap<K, V>
		return new ObjectMap<K, V>();

	@:from static inline function fromStringMap<V>(map:StringMap<V>):SScriptTypedGlobalMap<String, V>
		return cast map;

	@:from static inline function fromIntMap<V>(map:IntMap<V>):SScriptTypedGlobalMap<Int, V>
		return cast map;

	@:from static inline function fromObjectMap<K:{}, V>(map:ObjectMap<K, V>):SScriptTypedGlobalMap<K, V>
		return cast map;
}

typedef FunctionCall =
{
	public var succeeded(default, null):Bool;
	public var calledFunction(default, null):String;
	public var returnValue(default, null):Null<Dynamic>;
	public var exceptions(default, null):Array<SScriptException>;
}
