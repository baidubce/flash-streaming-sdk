package com.baidu.bce {

    import com.baidu.bce.Capture;

    import flash.external.ExternalInterface;

    public class SwfEventRouter {

        private static var _instance:Capture;

        public static function initExternalCall(instance:Capture):void {
            _instance = instance;
            if (ExternalInterface.available) {
                try {
                    ExternalInterface.addCallback('__externalCall', _externalJsEvent);
                } catch (e:Error) {
                    // 以字符串形式输出调用堆栈
                    trace(e.getStackTrace());
                }
            }
        }

        static private function _externalJsEvent(name:String, json:String = null):void {
            var args:Array = null;

            if (json) {
                args = JSON.parse(json) as Array;
            }

            try {
                if (args) {
                    _instance[name].apply(_instance, args);
                } else {
                    _instance[name].apply(_instance);
                }
            } catch (e:Error) {
                // 以字符串形式输出调用堆栈
                trace(e.getStackTrace());
            }

        }

        /**
     * SwfEventRouter.triggerJsEvent() will fire a backbone event on the swf element
     * Any instance in the Flash app can fire an event
     *
     * Since Sprites cannot dispatch events of the same type as native events, we need
     * to prefix some events like "error" with "jw-". These are renamed before triggering.
     */

    static private var _sendScript:XML = <script><![CDATA[
        function(id, name, json) {
            return setTimeout(function() {
                var swf = document.getElementById(id);
                if (swf && typeof swf.trigger === 'function') {
                    if (json) {
                        var data = JSON.parse(decodeURIComponent(json));
                        return swf.trigger(name, data);
                    } else {
                        return swf.trigger(name);
                    }
                }
                console.log('Unhandled event from "' + id +'": ', name, json);
            }, 0);
        }]]></script>;

    static public function triggerJsEvent(name:String, data:Object = null):void {
        var id:String = ExternalInterface.objectID;
        if (ExternalInterface.available) {
            var jsTimeout:Number = -1;
            if (data !== null) {
                var json:String;
                try {
                    if (data is String || data is Number) {
                        // do nothing
                    } else if ('toJsObject' in data && data.toJsObject is Function) {
                        data = data.toJsObject();
                    } else if ('clone' in data && data.clone is Function) {
                        // event object targets often have Cyclic structure
                        data = data.clone();
                        delete data.target;
                        delete data.currentTarget;
                    }
                    json = encodeURIComponent(JSON.stringify(data));
                } catch(err:Error) {
                    trace(err.getStackTrace());
                }
                try {
                    jsTimeout = ExternalInterface.call(_sendScript, id, name, json);
                } catch(err:Error) {
                    trace(err.getStackTrace());
                }
            } else {
                try {
                    jsTimeout = ExternalInterface.call(_sendScript, id, name);
                } catch(err:Error) {
                    trace(err.getStackTrace());
                }
            }
            return;
        }
        trace('Could not dispatch event "' + id + '":', name, json);
    }
    }
}
