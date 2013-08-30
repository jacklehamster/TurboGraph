package com.dobuki
{
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.DisplayObject;
	import flash.display.DisplayObjectContainer;
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.display.Stage;
	import flash.events.Event;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.utils.Dictionary;

	public class TurboGraph
	{
		static private var _instance:TurboGraph = new TurboGraph();
		private var master:Sprite, _overlay:Sprite = new Sprite();
		private var dico:Dictionary = new Dictionary();
		private var topOverlays:Vector.<Sprite> = new<Sprite> [ _overlay ];
		static private var _active:Boolean;
		
		private const notransform:Matrix = new Matrix();
		
		private var recycle:Vector.<Bitmap> = new Vector.<Bitmap>();
		private var displayed:Vector.<Bitmap> = new Vector.<Bitmap>();
		
		public function TurboGraph()
		{
			_instance = this;
		}
		
		private function get stage():Stage {
			return master.stage;
		}
		
		static public function get active():Boolean {
			return _active;
		}
		
		static public function set active(value:Boolean):void {
			_active = value;
			if(_instance && _instance.master) {
				_instance.master.visible = !_active;
			}
		}
		
		static public function initialize(root:Sprite):void {
			_instance.master = root;
			_instance.master.addEventListener(Event.ENTER_FRAME,_instance.loop);
			_instance.master.visible = !_active;
			_instance.master.stage.addChild(_instance._overlay);
			active = true;
		}
		
		static public function get instance():TurboGraph {
			return _instance;
		}
		
		public function getTopOverlay(index:int):Sprite {
			if(master) {
				while(topOverlays.length<=index) {
					var overlay:Sprite = new Sprite();
					stage.addChild(overlay);
					topOverlays.push(overlay);
				}
				return topOverlays[index];
			}
			return null;
		}
		
		private function loop(e:Event):void {
			if(!_active)
				return;
			
			for each (var obj:Object in dico) {
				if(obj && obj.Replicator) {
					obj.index = 0;
					for each(var mc:MovieClip in obj.recycle) {
						mc.visible = false;
					}
				}
			}
			
			_overlay.graphics.clear();
			_overlay.graphics.lineStyle(1,0xFF0000);
			
			var temp:Vector.<Bitmap> = displayed;
			displayed = recycle;
			recycle = temp;
			
			dig(master);
			
			while(recycle.length) {
				var bmp:Bitmap = recycle.pop();
				bmp.visible =false;
				displayed.push(bmp);
			}
			
			for each (obj in dico) {
				if(obj && obj.Replicator) {
					for each(mc in obj.recycle) {
						if(mc.parent)
							mc.parent.removeChild(mc);
					}
				}
			}
			
		}
		
		private function dig(container:DisplayObjectContainer,depth:int=0):void {
			
			if(container!=master && !container.visible) {
				return;
			}
			
			var Constructor:Class = Object(container).constructor;
			
			if(!dico[Constructor]) {
				for(var i:int=0;i<container.numChildren;i++) {
					var child:DisplayObject = container.getChildAt(i);
					if(child is CacheSprite) {
						dico[Constructor] = { 
							cacheSprite:child,
							mcrect: child.getBounds(container),
							isBox:child is CacheBox
						};
						child.visible = false;
//						container.removeChild(child);
						break;
					}
					var childContainer:DisplayObjectContainer = child as DisplayObjectContainer;
					if(childContainer) {
						dig(childContainer,depth+1);
					}
				}
			}
			
			var obj:Object = dico[Constructor];
			if(obj) {
				var topIndex:int = container is ITopMost ? (container as ITopMost).index : 0;
				var overlay:Sprite = getTopOverlay(topIndex);
				
				var mc:MovieClip = container as MovieClip;
				var rect:Rectangle = mc.getBounds(master);
				if(rect.width && rect.height) {
					if(!obj.frames) {
						obj.frames = [];
					}
					var snapshotIndex:String = (mc is ICacheable) ? (mc as ICacheable).snapshotIndex : mc.hasOwnProperty("snapshotIndex") ?  mc.snapshotIndex : mc.currentFrame+"";
					var bmpd:BitmapData = obj.frames[snapshotIndex];
					if(!bmpd) {
						if(!obj.isBox)
							obj.mcrect = mc.getBounds(mc);
						if(!obj.mcrect.width || !obj.mcrect.height) {
							return;
						}
						bmpd = new BitmapData(obj.mcrect.width,obj.mcrect.height,true,0);
						bmpd.draw(mc,new Matrix(1,0,0,1,-obj.mcrect.left,-obj.mcrect.top));
						obj.frames[snapshotIndex] = bmpd;
					}
					var bmp:Bitmap = recycle.pop();
					if(!bmp) {
						bmp = new Bitmap(bmpd,"auto",true);
					}
					else {
						bmp.visible = true;
					}
					overlay.addChild(bmp);
					displayed.push(bmp);
					bmp.bitmapData = bmpd;
					if(!obj.isBox) {
						bmp.transform.matrix = notransform;
						bmp.x = rect.x;
						bmp.y = rect.y;
						bmp.width = rect.width;
						bmp.height = rect.height;
						bmp.rotation = 0;
					}
					else {
						var point:Point = mc.localToGlobal(obj.mcrect.topLeft);
						var transformMatrix:Matrix = mc.transform.concatenatedMatrix;
						bmp.transform.matrix = transformMatrix;
						bmp.x = point.x;
						bmp.y = point.y;
					}
				}
			}
		}		
	}
}