package polymod.backends;

import haxe.xml.Fast;
import haxe.xml.Printer;
import polymod.Polymod;
import polymod.Polymod.PolymodError;
import polymod.PolymodAssets.PolymodAssetType;
import polymod.library.Util.MergeRules;
import polymod.library.PolymodAssetLibrary;
import polymod.backends.IBackend.Fallback;
import polymod.fs.PolymodFileSystem;
import polymod.library.Util;
#if unifill
import unifill.Unifill;
#end
#if openfl
	import lime.app.Future;
	import lime.utils.Assets in LimeAssets;
	import openfl.errors.Error;
	import openfl.utils.Assets in OpenFLAssets;
	import openfl.utils.AssetLibrary;
	import openfl.display.BitmapData;
	import lime.net.HTTPRequest;
	import lime.graphics.Image;
	import lime.text.Font;
	import lime.utils.Bytes;
	#if (openfl >= "8.0.0")
	import lime.utils.AssetLibrary;
	import lime.media.AudioBuffer;
	import lime.utils.AssetType;
	#else
	import lime.Assets.AssetType;
	import lime.Assets.AssetLibrary;
	import lime.audio.AudioBuffer;
	#end
#else
	typedef AssetLibrary = Dynamic;
#end

class OpenFLBackend implements IBackend
{
	//STATIC:
	private static var defaultAssetLibrary:AssetLibrary = null;
	private static function getDefaultAssetLibrary()
	{
		if(defaultAssetLibrary == null)
		{
			defaultAssetLibrary = LimeAssets.getLibrary("default");
		}
		return defaultAssetLibrary;
	}

	private static function restoreDefaultAssetLibrary()
	{
		if(defaultAssetLibrary != null)
		{
			LimeAssets.registerLibrary("default", defaultAssetLibrary);
		}
	}


	//Instance:
	public var polymodLibrary:PolymodAssetLibrary;
	public var modLibrary(default, null):AssetLibrary;
	public var fallback(default, null):AssetLibrary;
	
	public function new ()
	{
		#if !openfl
		Polymod.error(FAILED_CREATE_BACKEND, "OpenFLBackend requested, but openfl library wasn't found!");
		#end
	}

	public function init()
	{
		fallback = getDefaultAssetLibrary();
		modLibrary = new OpenFLModLibrary(this);
		LimeAssets.registerLibrary("default", modLibrary);
	}

	public function exists(id:String, type:PolymodAssetType):Bool
	{
		return modLibrary.exists(id, OpenFLModLibrary.PolyToLime(type));
	}

	public function getPath(id:String):String
	{
		return modLibrary.getPath(id);
	}

	public function getBytes(id:String):Bytes
	{
		return modLibrary.getBytes(id);
	}

	public function getText(id:String):String
	{
		return modLibrary.getText(id);
	}

	public function clearCache()
	{
		if (defaultAssetLibrary != null)
		{
			for (key in LimeAssets.cache.audio.keys())
			{
				LimeAssets.cache.audio.remove(key);
			}
			for (key in LimeAssets.cache.font.keys())
			{
				LimeAssets.cache.font.remove(key);
			}
			for (key in LimeAssets.cache.image.keys())
			{
				LimeAssets.cache.image.remove(key);
			}
		}
	}
}

class OpenFLModLibrary extends AssetLibrary
{
	public static function LimeToPoly(type:AssetType):PolymodAssetType
	{
		return switch(type)
		{
			case AssetType.BINARY: PolymodAssetType.BYTES;
			case AssetType.FONT: PolymodAssetType.FONT;
			case AssetType.IMAGE: PolymodAssetType.IMAGE;
			case AssetType.MUSIC: PolymodAssetType.AUDIO_MUSIC;
			case AssetType.SOUND: PolymodAssetType.AUDIO_SOUND;
			case AssetType.MANIFEST: PolymodAssetType.MANIFEST;
			case AssetType.TEMPLATE: PolymodAssetType.TEMPLATE;
			case AssetType.TEXT: PolymodAssetType.TEXT;
			default: PolymodAssetType.UNKNOWN;
		}
	}

	public static function PolyToLime(type:PolymodAssetType):AssetType
	{
		return switch(type)
		{
			case PolymodAssetType.BYTES: AssetType.BINARY;
			case PolymodAssetType.FONT : AssetType.FONT;
			case PolymodAssetType.IMAGE : AssetType.IMAGE;
			case PolymodAssetType.AUDIO_MUSIC : AssetType.MUSIC;
			case PolymodAssetType.AUDIO_SOUND : AssetType.SOUND;
			case PolymodAssetType.MANIFEST : AssetType.MANIFEST;
			case PolymodAssetType.TEMPLATE : AssetType.TEMPLATE;
			case PolymodAssetType.TEXT : AssetType.TEXT;
			default: AssetType.BINARY;
		}
	}

	var b:OpenFLBackend;
	var p:PolymodAssetLibrary;
	var fallback:AssetLibrary;
	var hasFallback:Bool = false;
	
	public function new(backend:OpenFLBackend)
	{
		b = backend;
		p = b.polymodLibrary;
		fallback = b.fallback;
		hasFallback = fallback != null;
		super();
	}

	public override function getAsset(id:String, type:String):Dynamic {

		trace("getAsset("+id+","+type+")");
		return super.getAsset(id,type);
	}

	public override function exists (id:String, type:String):Bool
	{
		var e = p.check(id, LimeToPoly(cast type));
		if (!e && hasFallback) return fallback.exists(id, type);
		return e;
	}

	public override function getAudioBuffer (id:String):AudioBuffer
	{
		if (p.check(id))
			return AudioBuffer.fromBytes(PolymodFileSystem.getFileBytes(p.file(id)));
		else if(hasFallback)
			return fallback.getAudioBuffer(id);
		return null;
	}

	public override function getBytes (id:String):Bytes
	{
		trace("getBytes("+id+") check = " + p.check(id));
		var file = p.file(id);
		trace("file = " + file + " FileSystem.exists("+file+") = " + sys.FileSystem.exists(file));
		if (p.check(id))
			return PolymodFileSystem.getFileBytes(p.file(id));
		else if(hasFallback)
			return fallback.getBytes(id);
		return null;
	}

	public override function getFont (id:String):Font
	{
		if (p.check(id))
			return Font.fromBytes(PolymodFileSystem.getFileBytes(p.file(id)));
		else if(hasFallback)
			return fallback.getFont(id);
		return null;
	}

	public override function getImage (id:String):Image
	{
		trace("getImage("+id+") p.check("+id+") = " + p.check(id));
		if (p.check(id)){
			return Image.fromBytes(PolymodFileSystem.getFileBytes(p.file(id)));
		}
		else if(hasFallback)
		{
			return fallback.getImage(id);
		}
		return null;
	}

	public override function getPath (id:String):String
	{
		if (p.check(id))
			return p.file(id);
		else if(hasFallback)
			return fallback.getPath(id);
		return null;
	}

	public override function getText (id:String):String
	{
		var modText = null;
		if (p.check(id))
			modText = super.getText(id);
		else if(hasFallback)
			modText = fallback.getText(id);
		
		if (modText != null)
			modText = p.mergeAndAppendText(modText, id);
		
		return modText;
	}

	public override function loadBytes (id:String):Future<Bytes> 
	{
		//TODO: filesystem
		if (p.check(id))
		{
			return Bytes.loadFromFile (p.file(id));
		}
		else if(hasFallback)
		{
			return fallback.loadBytes(id);
		}
		return Bytes.loadFromFile("");
	}

	public override function loadFont(id:String):Future<Font>
	{
		//TODO: filesystem
		if (p.check(id))
		{
			#if (js && html5)
			return Font.loadFromName (paths.get (p.file(id)));
			#else
			return Font.loadFromFile (paths.get (p.file(id)));
			#end
		}
		else if(hasFallback)
		{
			return fallback.loadFont(id);
		}
		#if (js && html5)
		return Font.loadFromName (paths.get (""));
		#else
		return Font.loadFromFile (paths.get (""));
		#end
	}

	public override function loadImage(id:String):Future<Image>
	{
		//TODO: filesystem
		if (p.check(id))
		{
			return Image.loadFromFile(p.file(id));
		}
		else if(hasFallback)
		{
			return fallback.loadImage(id);
		}
		return Image.loadFromFile("");
	}

	public override function loadAudioBuffer(id:String)
	{
		//TODO: filesystem
		if (p.check(id))
		{
			//return 
			if (pathGroups.exists(p.file(id)))
			{
				return AudioBuffer.loadFromFiles (pathGroups.get(p.file(id)));
			}
			else
			{
				return AudioBuffer.loadFromFile(paths.get(p.file(id)));
			}
		}
		else if(hasFallback)
		{
			return fallback.loadAudioBuffer(id);
		}
		return AudioBuffer.loadFromFile("");
	}

	public override function loadText(id:String):Future<String>
	{
		//TODO: FileSystem
		if (p.check(id))
		{
			var request = new HTTPRequest<String> ();
			return request.load (paths.get (p.file(id)));
		}
		else if(hasFallback)
		{	
			return fallback.loadText(id);
		}
		var request = new HTTPRequest<String> ();
		return request.load ("");
	}

	public override function isLocal (id:String, type:String):Bool
	{
		if (p.check(id))
			return true;
		else if(hasFallback)
			return fallback.isLocal(id, type);
		return false;
	}

	public override function list (type:String):Array<String>
	{
		trace("list("+type+") " + hasFallback);
		var otherList = hasFallback ? fallback.list(type) : [];
		
		var requestedType = type != null ? cast (type, AssetType) : null;
		var items = [];
		
		trace("otherList = " + otherList);

		for (id in p.type.keys ())
		{
			trace("id = " + id);
			if (id.indexOf("_append") == 0 || id.indexOf("_merge") == 0) continue;
			if (requestedType == null || exists (id, requestedType))
			{
				items.push (id);
			}
		}
		
		for (otherId in otherList)
		{
			if (items.indexOf(otherId) == -1)
			{
				if (requestedType == null || fallback.exists(otherId, type))
				{
					items.push(otherId);
				}
			}
		}
		
		return items;
	}
}