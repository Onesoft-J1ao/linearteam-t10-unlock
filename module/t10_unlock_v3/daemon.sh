#!/system/bin/sh
MODDIR=${0%/*}
TAG="T10V3D"
INTERVAL=3

log() {
    echo "$(date '+%m-%d %H:%M:%S') $TAG: $1" > /dev/kmsg 2>/dev/null
    log -t "$TAG" "$1" 2>/dev/null
}

clear_launcher_locked_apps() {
    service call com.toycloud.launcher.model.launcher.appcontrol.ControlAppService 1 s16 "com.iflytek.ebg.aistudy.mdm_sdk.apps.IControlApp" i32 0 2>/dev/null
    am broadcast -a com.toycloud.launcher.action.CLEAR_LOCKED_APPS 2>/dev/null
    am broadcast -a com.toycloud.launcher.action.UPDATE_LOCKED_APPS --esa locked_apps "" 2>/dev/null
}

log "Daemon started (interval=${INTERVAL}s)"

tick=0
last_launcher_clear=0

while true; do
    tick=$((tick + 1))

    if [ "$(getprop init.svc.adbd)" != "running" ]; then
        resetprop ro.adb.secure 0
        resetprop ro.debuggable 1
        start adbd
        log "adbd restarted"
    fi

    if [ "$(getprop persist.adb.tcp.port)" != "5555" ]; then
        resetprop persist.adb.tcp.port 5555
    fi

    if [ $((tick % 2)) -eq 0 ]; then
        if [ "$(getprop init.svc.blank_screen)" = "running" ]; then
            stop blank_screen 2>/dev/null
            log "blank_screen killed"
        fi

        zen=$(settings get global zen_mode 2>/dev/null)
        if [ "$zen" != "0" ]; then
            settings put global zen_mode 0 2>/dev/null
            settings put secure zen_mode 0 2>/dev/null
            log "zen_mode forced off (was $zen)"
        fi

        locked=$(dumpsys window policy 2>/dev/null | grep "isKeyguardLocked=true")
        if [ -n "$locked" ]; then
            input keyevent 82 2>/dev/null
            log "keyguard unlock attempted"
        fi

        power_state=$(dumpsys power 2>/dev/null | grep "mWakefulness=" | head -1)
        if echo "$power_state" | grep -q "Asleep"; then
            input keyevent 26 2>/dev/null
            sleep 1
            input keyevent 82 2>/dev/null
            log "screen wake + unlock"
        fi
    fi

    if [ $((tick % 3)) -eq 0 ]; then
        now=$(date +%s)
        if [ $((now - last_launcher_clear)) -gt 10 ]; then
            clear_launcher_locked_apps >/dev/null 2>&1
            last_launcher_clear=$now
        fi
    fi

    if [ $((tick % 5)) -eq 0 ]; then
        disabled_list=$(pm list packages -d 2>/dev/null | sed 's/^package://')
        for pkg in $disabled_list; do
            case "$pkg" in
                com.android.phone|com.android.systemui|com.android.settings|\
                android|com.android.providers.*|com.android.bluetooth|\
                com.iflytek.ebg.aistudy.mdm|com.iflytek.hwc.service|\
                com.iflytek.server|com.android.iflytek)
                    continue
                    ;;
            esac
            pm enable "$pkg" >/dev/null 2>&1
        done
    fi

    if [ $((tick % 10)) -eq 0 ]; then
        for ipt in iptables ip6tables; do
            for chn in FORWARD INPUT OUTPUT; do
                $ipt -D $chn -p udp --dport 53 -j DROP 2>/dev/null
                $ipt -D $chn -p tcp --dport 853 -j DROP 2>/dev/null
            done
        done

        content delete --uri content://com.iflytek.ebg.aistudy.mdm_sdk/business_control/ 2>/dev/null
        content delete --uri content://com.iflytek.ebg.aistudy.mdm_sdk/control/control_data/ 2>/dev/null
    fi

    if [ $((tick % 20)) -eq 0 ]; then
        wl=$(getprop persist.vendor.iflytek.install_whitelist_enable)
        [ "$wl" = "false" ] || resetprop persist.vendor.iflytek.install_whitelist_enable false

        zi=$(getprop persist.hwc.zenmode.intercepted)
        [ "$zi" = "1" ] || resetprop persist.hwc.zenmode.intercepted 1

        for svc in ylog log_service collect_apr slogmodem modemlog_connmgr_service dataLogDaemon cmd_services performancemanager; do
            if [ "$(getprop init.svc.$svc)" = "running" ]; then
                stop $svc 2>/dev/null
            fi
        done

        dpm_output=$(dpm list-owners 2>/dev/null)
        if echo "$dpm_output" | grep -q "com.iflytek.ebg.aistudy.mdm"; then
            dpm remove-active com.iflytek.ebg.aistudy.mdm/com.iflytek.ebg.aistudy.mdm.screen.ScreenOffAdminReceiver 2>/dev/null
            log "MDM device admin removed"
        fi

        if [ "$(pm list packages -d 2>/dev/null | grep com.android.iflytek)" = "" ]; then
            pm disable com.android.iflytek 2>/dev/null
            log "IFlytekService re-disabled"
        fi
    fi

    if [ $((tick % 100)) -eq 0 ]; then
        for f in blackAppList.xml appPowerSaveConfig.xml ifly_bg_clean_conf.xml ifly_syscomponent_package_list.xml phonedump.conf; do
            mounted=$(mount | grep " /system/etc/$f ")
            if [ -z "$mounted" ]; then
                mount -o bind "$MODDIR/system/etc/$f" "/system/etc/$f" 2>/dev/null
            fi
        done
    fi

    if [ $((tick % 200)) -eq 0 ]; then
        rm -rf /data/ylog/* 2>/dev/null
        rm -rf /cache/ylog/* 2>/dev/null
        rm -rf /data/local/slogmodem/* 2>/dev/null
    fi

    sleep $INTERVAL
done
