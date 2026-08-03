package hscript;

class Config {
	// Runs support for custom classes in these
	public static final ALLOWED_CUSTOM_CLASSES = [
		"flixel",
		"flixel.addons",
		"openfl",
		"animate",
		"haxe",
		#if FEATURE_VIDEOS
		//"hxvlc",
		#end
		"backend",
		"cutscenes",
		"debug",
		"macros",
		"mobile",
		"objects",
		"options",
		"psychlua",
		"shaders",
		"states",
		"substates",
	];

	// Runs support for abstract support in these
	public static final ALLOWED_ABSTRACT_AND_ENUM = [
		"flixel",
		"flixel.addons",
		"openfl",
		"haxe",
		"haxe.xml",
		"haxe.CallStack",
		"animate",
		#if FEATURE_VIDEOS
		//"hxvlc",
		#end
		"backend",
		"cutscenes",
		"debug",
		"macros",
		"mobile",
		"objects",
		"options",
		"psychlua",
		"shaders",
		"states",
		"substates",
	];

	// Runs support for typedef support in these
	public static final ALLOWED_TYPEDEFS = [
		"flixel",
		"flixel.addons",
		"openfl",
	];

	// Incase any of your files fail
	// These are the module names
	public static final DISALLOW_CUSTOM_CLASSES = [

	];

	// Incase any of your files fail
	// These are the module names
	public static final DISALLOW_ABSTRACT_AND_ENUM = [

	];

	// Incase any of your files fail
	// These are the module names
	public static final DISALLOW_TYPEDEFS = [

	];

	@:unreflective
	public static final IMPORT_BLACKLIST:Array<String> = [

	];
}