package;

#if macro
import haxe.macro.Compiler;
import haxe.macro.Context;
import haxe.macro.Expr;
#end

#if !macro
@:build(DocumentClass.build())
@:keep @:dox(hide) class DocumentClass extends ::APP_MAIN:: {}
#else
class DocumentClass
{
	macro public static function build():Array<Field>
	{
		var classType = Context.getLocalClass().get();
		var searchTypes = classType;

		while (searchTypes != null)
		{
			if (searchTypes.module == "openfl.display.DisplayObject")
			{
				var fields = Context.getBuildFields();

				var method = macro
				{
					current.addChild(this);
					super();
					dispatchEvent(new openfl.events.Event(openfl.events.Event.ADDED_TO_STAGE, false, false));
				}

				fields.push({ name: "new", access: [ APublic ], kind: FFun({ args: [ { name: "current", opt: false, type: macro :openfl.display.DisplayObjectContainer, value: null } ], expr: method, params: [], ret: macro :Void }), pos: Context.currentPos() });

				return fields;
			}

			if (searchTypes.superClass != null)
			{
				searchTypes = searchTypes.superClass.t.get();
			}
			else
			{
				searchTypes = null;
			}
		}

		return null;
	}
}
#end
