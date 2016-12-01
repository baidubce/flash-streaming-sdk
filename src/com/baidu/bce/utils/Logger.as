package com.baidu.bce.utils {
    import flash.external.ExternalInterface;

    public class Logger {
        static private var _consoleLog:XML = <script><![CDATA[
                function() {
                    if (typeof console.log === 'object') {
                        console.log(Array.prototype.slice.call(arguments, 0));
                        return;
                    }
                    console.log.apply(console, arguments);
                }]]></script>;

        public static function log(...args):void {
            trace.apply(null, ['<<'].concat(args));
            if (ExternalInterface.available) {
                try {
                    ExternalInterface.call.apply(null, [_consoleLog].concat(args));
                } catch(err:Error) {
                    trace(err.getStackTrace());
                }
            }
        }
    }
}