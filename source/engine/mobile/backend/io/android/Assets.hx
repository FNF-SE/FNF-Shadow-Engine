package mobile.backend.io.android;

/**
 * The code for this class is mostly taken from SDL2.
 * This class implements IO methods from the Android NDK's AAssetManager to read bundled app assets.
 */
#if android
import cpp.UInt8;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import lime.system.JNI;
import sys.FileStat;

@:cppFileCode('
#ifndef INCLUDED_Date
#include <Date.h>
#endif
#include <vector>
#include <string>
')
@:cppNamespaceCode('
#include <jni.h>
#include <android/log.h>
#include <android/asset_manager_jni.h>
#include <unistd.h>

static jmethodID midGetContext;
static jclass mActivityClass;
static AAssetManager *asset_manager = NULL;
static jobject javaAssetManagerRef = 0;

struct LocalReferenceHolder
{
	JNIEnv *m_env;
	const char *m_func;
};

static struct LocalReferenceHolder LocalReferenceHolder_Setup(const char *func)
{
	struct LocalReferenceHolder refholder;
	refholder.m_env = NULL;
	refholder.m_func = func;
	__android_log_print(ANDROID_LOG_DEBUG, "Shadow Engine", "Entering function %s", func);
	return refholder;
}

static bool LocalReferenceHolder_Init(struct LocalReferenceHolder *refholder, JNIEnv *env)
{
	const int capacity = 16;
	if ((*env).PushLocalFrame(capacity) < 0)
	{
		__android_log_print(ANDROID_LOG_ERROR, "Shadow Engine", "Failed to allocate enough JVM local references");
		return false;
	}
	refholder->m_env = env;
	return true;
}

static void LocalReferenceHolder_Cleanup(struct LocalReferenceHolder *refholder)
{
	__android_log_print(ANDROID_LOG_DEBUG, "Shadow Engine", "Leaving function %s", refholder->m_func);
	if (refholder->m_env)
	{
		JNIEnv *env = refholder->m_env;
		(*env).PopLocalFrame(NULL);
	}
}

void Assets_obj::native_init(::Dynamic jni_env)
{
	JNIEnv* env = (JNIEnv*)(uintptr_t)jni_env;
	jclass cls = env->FindClass("org/libsdl/app/SDLActivity");
	mActivityClass = (jclass)((*env).NewGlobalRef(cls));

	struct LocalReferenceHolder refs = LocalReferenceHolder_Setup(__FUNCTION__);
	jmethodID mid;
	jobject context;
	jobject javaAssetManager;

	if (!LocalReferenceHolder_Init(&refs, env))
	{
		LocalReferenceHolder_Cleanup(&refs);
		return;
	}

	// context = SDLActivity.getContext();
	midGetContext = (*env).GetStaticMethodID(mActivityClass, "getContext", "()Landroid/content/Context;");
	context = (*env).CallStaticObjectMethod(mActivityClass, midGetContext);

	// javaAssetManager = context.getAssets();
	mid = (*env).GetMethodID((*env).GetObjectClass(context), "getAssets", "()Landroid/content/res/AssetManager;");
	javaAssetManager = (*env).CallObjectMethod(context, mid);

	/**
	 * Given a Dalvik AssetManager object, obtain the corresponding native AAssetManager
	 * object. Note that the caller is responsible for obtaining and holding a VM reference
	 * to the jobject to prevent its being garbage collected while the native object is
	 * in use.
	 */
	javaAssetManagerRef = (*env).NewGlobalRef(javaAssetManager);
	asset_manager = AAssetManager_fromJava(env, javaAssetManagerRef);

	if (asset_manager == NULL)
	{
		(*env).DeleteGlobalRef(javaAssetManagerRef);
		__android_log_print(ANDROID_LOG_ERROR, "Shadow Engine", "Failed to create Android Assets Manager");
	}

	LocalReferenceHolder_Cleanup(&refs);
}

void Assets_obj::native_destroy(::Dynamic jni_env)
{
	JNIEnv* env = (JNIEnv*)(uintptr_t)jni_env;

	if (asset_manager)
	{
		(*env).DeleteGlobalRef(javaAssetManagerRef);
		asset_manager = NULL;
	}
}

bool Assets_obj::native_exists(::String path)
{
	if (!asset_manager)
		return false;

	hx::EnterGCFreeZone();

	AAsset* file = AAssetManager_open(asset_manager, path.__s, AASSET_MODE_UNKNOWN);
	if (file != NULL)
	{
		AAsset_close(file);
		hx::ExitGCFreeZone();
		return true;
	}

	AAssetDir* dir = AAssetManager_openDir(asset_manager, path.__s);
	if (dir && AAssetDir_getNextFileName(dir) != NULL)
	{
		AAssetDir_close(dir);
		hx::ExitGCFreeZone();
		return true;
	}

	if (dir)
		AAssetDir_close(dir);

	hx::ExitGCFreeZone();
	return false;
}

::String Assets_obj::native_getContent(::String file)
{
	if (!asset_manager)
		return ::String(null());

	hx::EnterGCFreeZone();
	AAsset* asset = AAssetManager_open(asset_manager, file.__s, AASSET_MODE_BUFFER);

	if (!asset)
	{
		hx::ExitGCFreeZone();
		return ::String(null());
	}

	off64_t len = AAsset_getLength64(asset);
	if (len <= 0)
	{
		AAsset_close(asset);
		hx::ExitGCFreeZone();
		return ::String::emptyString;
	}

	std::vector<char> buffer((size_t)len);

	const char* src = (const char*)AAsset_getBuffer(asset);
	if (src != NULL)
	{
		memcpy(&buffer[0], src, (size_t)len);
	}
	else
	{
		off64_t totalRead = 0;
		while (totalRead < len)
		{
			int bytesRead = AAsset_read(asset, &buffer[totalRead], (size_t)(len - totalRead));
			if (bytesRead <= 0)
			{
				AAsset_close(asset);
				hx::ExitGCFreeZone();
				return ::String(null());
			}
			totalRead += bytesRead;
		}
	}

	AAsset_close(asset);
	hx::ExitGCFreeZone();

	return ::String::create(&buffer[0], (int)buffer.size());
}

Array<unsigned char> Assets_obj::native_getBytes(::String file)
{
	if (!asset_manager)
		return null();

	hx::EnterGCFreeZone();
	AAsset* asset = AAssetManager_open(asset_manager, file.__s, AASSET_MODE_STREAMING);

	if (!asset)
	{
		hx::ExitGCFreeZone();
		return null();
	}

	off64_t len = AAsset_getLength64(asset);
	if (len == 0)
	{
		AAsset_close(asset);
		hx::ExitGCFreeZone();
		return Array_obj<unsigned char>::__new(0, 0);
	}
	if (len < 0)
	{
		AAsset_close(asset);
		hx::ExitGCFreeZone();
		return null();
	}

	hx::ExitGCFreeZone();
	Array<unsigned char> buffer = Array_obj<unsigned char>::__new((int)len, (int)len);
	hx::EnterGCFreeZone();

	int fd;
	off_t outStart;
	off_t outLength;
	fd = AAsset_openFileDescriptor(asset, &outStart, &outLength);

	if (fd >= 0)
	{
		if (lseek(fd, outStart, SEEK_SET) == -1)
		{
			close(fd);
			AAsset_close(asset);
			hx::ExitGCFreeZone();
			return null();
		}

		off64_t totalRead = 0;
		while (totalRead < len)
		{
			int bytesRead = read(fd, buffer->getBase() + totalRead, (size_t)(len - totalRead));
			if (bytesRead <= 0)
			{
				close(fd);
				AAsset_close(asset);
				hx::ExitGCFreeZone();
				return null();
			}
			totalRead += bytesRead;
		}
		close(fd);
	}
	else
	{
		off64_t totalRead = 0;
		while (totalRead < len)
		{
			int bytesRead = AAsset_read(asset, buffer->getBase() + totalRead, (size_t)(len - totalRead));
			if (bytesRead <= 0)
			{
				AAsset_close(asset);
				hx::ExitGCFreeZone();
				return null();
			}
			totalRead += bytesRead;
		}
	}

	AAsset_close(asset);
	hx::ExitGCFreeZone();
	return buffer;
}

bool Assets_obj::native_isDirectory(::String path)
{
	if (!asset_manager)
		return false;

	hx::EnterGCFreeZone();
	AAssetDir* dir = AAssetManager_openDir(asset_manager, path.__s);

	if (dir && AAssetDir_getNextFileName(dir) != NULL)
	{
		AAssetDir_close(dir);
		hx::ExitGCFreeZone();
		return true;
	}

	if (dir)
		AAssetDir_close(dir);

	hx::ExitGCFreeZone();
	return false;
}

Array<::String> Assets_obj::native_readDirectory(::String path)
{
	if (!asset_manager)
		return Array_obj<::String>::__new(0, 0);

	std::vector<std::string> names;

	hx::EnterGCFreeZone();
	AAssetDir* dir = AAssetManager_openDir(asset_manager, path.__s);

	if (dir)
	{
		const char* filename;
		while ((filename = AAssetDir_getNextFileName(dir)) != NULL)
			names.push_back(filename);
		AAssetDir_close(dir);
	}
	hx::ExitGCFreeZone();

	Array<::String> result = Array_obj<::String>::__new(0, 0);
	for (size_t i = 0; i < names.size(); i++)
		result->push(::String(names[i].c_str()));

	return result;
}

::Dynamic Assets_obj::native_stat(::String path)
{
	hx::Anon anon = hx::Anon_obj::Create();
	bool isDir = native_isDirectory(path);
	int fileSize = 0;
	int mode = isDir ? 0x4000 : 0x8000;

	if (!isDir && asset_manager)
	{
		hx::EnterGCFreeZone();
		AAsset* asset = AAssetManager_open(asset_manager, path.__s, AASSET_MODE_UNKNOWN);
		if (asset)
		{
			fileSize = (int)AAsset_getLength64(asset);
			AAsset_close(asset);
		}
		hx::ExitGCFreeZone();
	}

	anon->Add(HX_CSTRING("gid"),   0);
	anon->Add(HX_CSTRING("uid"),   0);
	anon->Add(HX_CSTRING("atime"), ::Date_obj::fromTime(0.0));
	anon->Add(HX_CSTRING("mtime"), ::Date_obj::fromTime(0.0));
	anon->Add(HX_CSTRING("ctime"), ::Date_obj::fromTime(0.0));
	anon->Add(HX_CSTRING("size"),  fileSize);
	anon->Add(HX_CSTRING("dev"),   0);
	anon->Add(HX_CSTRING("ino"),   0);
	anon->Add(HX_CSTRING("nlink"), 0);
	anon->Add(HX_CSTRING("rdev"),  0);
	anon->Add(HX_CSTRING("mode"),  mode);

	return anon;
}
')
@:headerClassCode('
	static void native_init(::Dynamic jni_env);
	static void native_destroy(::Dynamic jni_env);
	static bool native_exists(::String path);
	static ::String native_getContent(::String file);
	static Array<unsigned char> native_getBytes(::String file);
	static bool native_isDirectory(::String path);
	static Array<::String> native_readDirectory(::String path);
	static ::Dynamic native_stat(::String path);
')
class Assets
{
	public static function init():Void
	{
		__init(JNI.getEnv());
	}

	public static function destroy():Void
	{
		__destroy(JNI.getEnv());
	}

	public static function getContent(file:String):String
	{
		final content:String = __getContent(file);

		if (content == null)
			throw 'file_contents, $file';

		return content;
	}

	public static function getBytes(file:String):Bytes
	{
		final data:Array<UInt8> = __getBytes(file);

		if (data == null)
			throw 'file_contents, $file';

		return Bytes.ofData(data);
	}

	/*public static function read(file:String, ?binary:Bool):BytesInput
	{
		return new BytesInput(getBytes(file));
	}*/

	public static function exists(path:String):Bool
	{
		return __exists(path);
	}

	public static function isDirectory(path:String):Bool
	{
		return __isDirectory(path);
	}

	public static function readDirectory(path:String):Array<String>
	{
		return __readDirectory(path);
	}

	public static function stat(path:String):FileStat
	{
		return __stat(path);
	}

	@:noCompletion
	@:native('mobile::backend::io::android::Assets_obj::native_init')
	private static function __init(jni_env:Dynamic):Void
		return;

	@:noCompletion
	@:native('mobile::backend::io::android::Assets_obj::native_destroy')
	private static function __destroy(jni_env:Dynamic):Void
		return;

	@:noCompletion
	@:native('mobile::backend::io::android::Assets_obj::native_exists')
	private static function __exists(path:String):Bool
		return false;

	@:noCompletion
	@:native('mobile::backend::io::android::Assets_obj::native_getContent')
	private static function __getContent(file:String):String
		return null;

	@:noCompletion
	@:native('mobile::backend::io::android::Assets_obj::native_getBytes')
	private static function __getBytes(file:String):Array<UInt8>
		return null;

	@:noCompletion
	@:native('mobile::backend::io::android::Assets_obj::native_isDirectory')
	private static function __isDirectory(path:String):Bool
		return false;

	@:noCompletion
	@:native('mobile::backend::io::android::Assets_obj::native_readDirectory')
	private static function __readDirectory(path:String):Array<String>
		return null;

	@:noCompletion
	@:native('mobile::backend::io::android::Assets_obj::native_stat')
	private static function __stat(path:String):Dynamic
		return null;
}
#end
