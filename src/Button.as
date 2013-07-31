package
{
	import flash.display.Sprite;
	
	public class Button extends Sprite
	{
		public function Button(dir:String) {
			mouseChildren = false;
			buttonMode = true;
			initTriangle();
			position(dir);
		}
		
		private function initTriangle():void {
			graphics.lineStyle(0.3, 0);
			graphics.beginFill(0x888888, 0.3);
			graphics.moveTo(-20, -10);
			graphics.lineTo(20, -10);
			graphics.lineTo(0, 10);
			graphics.lineTo(-20, -10);
			graphics.endFill();
			alpha = 0.3;
		}
		
		private function position(dir:String):void {
			switch(dir) {
				case "up":
					rotation = 180;
					break;
				case "down":
					rotation = 0;
					break;
				case "left":
					rotation = 90;
					break;
				case "right":
					rotation = 270;
					break;
				default:
					// do nothing
			}
		}
	}
}