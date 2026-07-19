#!/system/bin/sh
MODDIR=${0%/*}

mount -o rw,remount /system 2>/dev/null

rm -f /system/framework/iflytek-frameworks-service.jar
rm -f /system/framework/iflytek-monitor-lib.jar
rm -f /system/framework/iflytek-prediction.jar
rm -f /system/framework/iflytek-server-lib.jar
rm -f /system/Framework/iflytek-security-lib.jar
rm -f /system/framework/hwc-framework-service.jar
rm -f /system/framework/boot-iflytek-frameworks-service.vdex
rm -f /system/framework/boot-iflytek-monitor-lib.vdex
rm -f /system/framework/boot-iflytek-prediction.vdex
rm -f /system/framework/boot-iflytek-server-lib.vdex
rm -f /system/framework/boot-iflytek-security-lib.vdex
rm -f /system/framework/boot-hwc-framework-service.vdex
rm -f /system/framework/arm/boot-iflytek-frameworks-service.odex
rm -f /system/framework/arm/boot-iflytek-monitor-lib.odex
rm -f /system/framework/arm/boot-iflytek-prediction.odex
rm -f /system/framework/arm/boot-iflytek-server-lib.odex
rm -f /system/framework/arm/boot-iflytek-security-lib.odex
rm -f /system/framework/arm/boot-hwc-framework-service.odex
rm -f /system/framework/arm64/boot-iflytek-frameworks-service.odex
rm -f /system/framework/arm64/boot-iflytek-monitor-lib.odex
rm -f /system/framework/arm64/boot-iflytek-prediction.odex
rm -f /system/framework/arm64/boot-iflytek-server-lib.odex
rm -f /system/framework/arm64/boot-iflytek-security-lib.odex
rm -f /system/framework/arm64/boot-hwc-framework-service.odex

rm -rf /system/app/DocumentsUIXposed

mount -o ro,remount /system 2>/dev/null

mount -o bind "$MODDIR/system/etc/blackAppList.xml" /system/etc/blackAppList.xml 2>/dev/null
mount -o bind "$MODDIR/system/etc/appPowerSaveConfig.xml" /system/etc/appPowerSaveConfig.xml 2>/dev/null
mount -o bind "$MODDIR/system/etc/ifly_bg_clean_conf.xml" /system/etc/ifly_bg_clean_conf.xml 2>/dev/null
mount -o bind "$MODDIR/system/etc/ifly_syscomponent_package_list.xml" /system/etc/ifly_syscomponent_package_list.xml 2>/dev/null
mount -o bind "$MODDIR/system/etc/phonedump.conf" /system/etc/phonedump.conf 2>/dev/null
