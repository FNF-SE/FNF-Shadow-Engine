package debug.codename;

import backend.codename.MemoryUtil;
import backend.codename.RegisteryUtil;
import lime.utils.Log;
#if android
import android.os.Build;
import android.os.Build.VERSION;
#end
#if sys
import sys.io.Process;
#end
#if cpp
import cpp.Float64;
import cpp.UInt64;
#end

using StringTools;

#if cpp
#if windows
@:cppFileCode('#include <windows.h>')
#elseif (mac || ios)
@:cppFileCode('#include <mach-o/arch.h>')
#else
@:headerInclude('sys/utsname.h')
#end
#end
class SystemInfo extends FramerateCategory
{
	public static var osInfo:String = "Unknown";
	public static var gpuName:String = "Unknown";
	public static var vRAM:String = "Unknown";
	public static var cpuName:String = "Unknown";
	public static var totalMem:String = "Unknown";
	public static var totalSwapMem:String = "Unknown";
	public static var memType:String = "Unknown";

	static var __formattedSysText:String = "";

	public static function init()
	{
		Log.throwErrors = false;

		#if linux
		var process = new Process("cat", ["/etc/os-release"]);
		if (process.exitCode() != 0)
			Log.error('Unable to grab OS Label');
		else
		{
			var osName = "";
			var osVersion = "";
			for (line in process.stdout.readAll().toString().split("\n"))
			{
				if (line.startsWith("NAME="))
				{
					var index = line.indexOf('"');
					if (index != -1)
						osName = line.substring(index + 1, line.lastIndexOf('"'));
					else
					{
						var arr = line.split("=");
						arr.shift();
						osName = arr.join("=");
					}
				}
				if (line.startsWith("VERSION="))
				{
					var index = line.indexOf('"');
					if (index != -1)
						osVersion = line.substring(index + 1, line.lastIndexOf('"'));
					else
					{
						var arr = line.split("=");
						arr.shift();
						osVersion = arr.join("=");
					}
				}
			}
			if (osName != "")
				osInfo = '${osName} ${osVersion}'.trim();
		}
		#elseif windows
		var windowsCurrentVersionPath = "SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion";
		var buildNumber = Std.parseInt(RegistryUtil.get(HKEY_LOCAL_MACHINE, windowsCurrentVersionPath, "CurrentBuildNumber"));
		var edition = RegistryUtil.get(HKEY_LOCAL_MACHINE, windowsCurrentVersionPath, "ProductName");

		var lcuKey = "WinREVersion"; // Last Cumulative Update Key On Older Windows Versions
		if (buildNumber >= 22000) // Windows 11 Initial Release Build Number
		{
			edition = edition.replace("Windows 10", "Windows 11");
			lcuKey = "LCUVer"; // Last Cumulative Update Key On Windows 11
		}

		var lcuVersion = RegistryUtil.get(HKEY_LOCAL_MACHINE, windowsCurrentVersionPath, lcuKey);

		osInfo = edition;

		if (lcuVersion != null && lcuVersion != "")
			osInfo += ' ${lcuVersion}';
		else if (lime.system.System.platformVersion != null && lime.system.System.platformVersion != "")
			osInfo += ' ${lime.system.System.platformVersion}';
		#elseif web
			osInfo = '${lime.system.System.platformLabel}';
		#else
		if (lime.system.System.platformLabel != null
			&& lime.system.System.platformLabel != ""
			&& lime.system.System.platformVersion != null
			&& lime.system.System.platformVersion != "")
			osInfo = '${lime.system.System.platformLabel.replace(lime.system.System.platformVersion, "").trim()} ${lime.system.System.platformVersion}';
		else
			Log.error('Unable to grab OS Label');
		#end

		try
		{
			#if windows
			cpuName = RegistryUtil.get(HKEY_LOCAL_MACHINE, "HARDWARE\\DESCRIPTION\\System\\CentralProcessor\\0", "ProcessorNameString");
			#elseif mac
			var process = new Process("sysctl -a | grep brand_string"); // Somehow this isn't able to use the args but it still works
			if (process.exitCode() != 0)
				throw 'Could not fetch CPU information';

			cpuName = process.stdout.readAll().toString().trim().split(":")[1].trim();
			#elseif linux
			var process = new Process("lscpu", []);
			if (process.exitCode() != 0)
				throw 'Could not fetch CPU information';

			for (line in process.stdout.readAll().toString().split("\n"))
			{
				var trimmedLine = line.trim();
				if (trimmedLine.startsWith("Model name:"))
				{
					cpuName = trimmedLine.substr(trimmedLine.indexOf(":") + 1).trim();
					break;
				}
			}
			#elseif android
			cpuName = (VERSION.SDK_INT >= VERSION_CODES.S) ? Build.SOC_MODEL : Build.HARDWARE;
			#elseif ios
			cpuName = "Apple SoC";
			#end
		}
		catch (e)
		{
			Log.error('Unable to grab CPU Name: $e');
		}
		@:privateAccess
		if (FlxG.renderTile) // Blit doesn't enable the gpu. Idk if we should fix this
		{
			if (flixel.FlxG.stage.context3D != null && flixel.FlxG.stage.context3D.gl != null)
			{
				gpuName = Std.string(flixel.FlxG.stage.context3D.gl.getParameter(flixel.FlxG.stage.context3D.gl.RENDERER)).split("/")[0].trim();

				if (openfl.display3D.Context3D.__glMemoryTotalAvailable != -1)
				{
					var vRAMBytes:Int = cast flixel.FlxG.stage.context3D.gl.getParameter(openfl.display3D.Context3D.__glMemoryTotalAvailable);
					if (vRAMBytes == 1000 || vRAMBytes == 1 || vRAMBytes <= 0)
						Log.error('Unable to grab GPU VRAM');
					else
					{
						vRAM = getSizeString(vRAMBytes / 1024);
					}
				}
			}
			else
				Log.error('Unable to grab GPU Info');
		}

		#if cpp
		totalMem = getSizeString(MemoryUtil.getTotalMem());
		#end

		try
		{
			memType = MemoryUtil.getMemType();
		}
		catch (e)
		{
			Log.error('Unable to grab RAM Type: $e');
		}

		Log.throwErrors = true;

		totalSwapMem = getSizeString(MemoryUtil.getTotalSwapMem());
		formatSysInfo();
	}

	static inline function row(key:String, value:String):String
		return '<font color="#8A7E72">$key </font><font color="#E8E2D6">$value</font>';

	static function formatSysInfo()
	{
		var lines:Array<String> = [];

		#if android
		lines.push(row("Device:", '${Build.BRAND.charAt(0).toUpperCase() + Build.BRAND.substring(1)} ${Build.MODEL} (${Build.BOARD})'));
		#end
		if (osInfo != "Unknown")
			lines.push(row("System:", osInfo));
		if (cpuName != "Unknown")
			lines.push(row("CPU:", '$cpuName ${getCPUArch()}'));

		var gpuNameKnown = gpuName != "Unknown" && gpuName != cpuName;
		var vramKnown = vRAM != "Unknown";
		if (gpuNameKnown || vramKnown)
		{
			var gpuVal = "";
			if (gpuNameKnown)
				gpuVal += gpuName;
			if (gpuNameKnown && vramKnown)
				gpuVal += " | ";
			if (vramKnown)
				gpuVal += 'VRAM: $vRAM'; // 1000 bytes of vram (apus)
			lines.push(row("GPU:", gpuVal));
		}
		if (totalMem != "Unknown" && memType != "Unknown")
			lines.push(row("Total MEM:", '$totalMem $memType ${totalSwapMem != "Unknown" ? '+ $totalSwapMem SWAP' : ""}'));

		__formattedSysText = lines.join("\n");
	}

	static function getSizeString(size:Float):String
	{
		if (size < 1024)
			return Std.int(size) + " MB";
		else if (size < 1024 * 1024)
			return Std.int(size / 1024) + " GB";
		else
		{
			var tb = size / (1024 * 1024);
			return Std.int(tb) + "." + CoolUtil.addZeros(Std.string(Std.int((tb % 1) * 100)), 2) + " TB";
		}
	}

	public function new()
	{
		super("System Info");
	}

	public override function __enterFrame(t:Float)
	{
		if (alpha <= 0.05)
			return;

		_text = __formattedSysText;
		#if (cpp || hl)
		//_text += '${__formattedSysText == "" ? "" : "\n"}Garbage Collector: ${MemoryUtil.disableCount ? "OFF" : "ON"} (${MemoryUtil.disableCount})';
		#end

		this.text.htmlText = _text;
		super.__enterFrame(t);
	}

	#if windows
	@:functionCode('
		SYSTEM_INFO osInfo;

		GetSystemInfo(&osInfo);

		switch(osInfo.wProcessorArchitecture)
		{
			case 9:
				return ::String("x86_64");
			case 5:
				return ::String("ARM");
			case 12:
				return ::String("ARM64");
			case 6:
				return ::String("IA-64");
			case 0:
				return ::String("x86");
			default:
				return ::String("Unknown");
		}
	')
	#elseif (mac || ios)
	@:functionCode('
		const NXArchInfo *archInfo = NXGetLocalArchInfo();
    	return ::String(archInfo == NULL ? "Unknown" : archInfo->name);
	')
	#elseif cpp
	@:functionCode('
		struct utsname osInfo{};
		uname(&osInfo);
		return ::String(osInfo.machine);
	')
	#end
	@:noCompletion
	private static function getCPUArch():String
	{
		return "Unknown";
	}
}
