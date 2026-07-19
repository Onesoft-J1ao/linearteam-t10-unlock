#!/system/bin/sh
MODDIR=${0%/*}

wait_boot() {
    until [ "$(getprop sys.boot_completed)" = "1" ]; do
        sleep 5
    done
    sleep 15
}

log() {
    log -t "T10V3" "$1" 2>/dev/null
}

wait_boot
log "Boot complete, starting v3 initialization"

resetprop ro.debuggable 1
resetprop ro.adb.secure 0
resetprop ro.secure 0
resetprop persist.vendor.iflytek.install_whitelist_enable false
resetprop persist.hwc.zenmode.intercepted 1
resetprop persist.sys.usb.config mtp,adb
resetprop ro.default.home.component ""
setprop service.adb.tcp.port 5555
log "Properties set"

stop adbd
sleep 2
start adbd
log "adbd restarted with ro.adb.secure=0"

stop blank_screen 2>/dev/null
log "blank_screen stopped"

pm disable com.android.iflytek 2>/dev/null
log "IFlytekService watchdog DISABLED"

dpm remove-active com.iflytek.ebg.aistudy.mdm/com.iflytek.ebg.aistudy.mdm.screen.ScreenOffAdminReceiver 2>/dev/null
log "MDM device admin removed"

content delete --uri content://com.iflytek.ebg.aistudy.mdm_sdk/business_control/ 2>/dev/null
content delete --uri content://com.iflytek.ebg.aistudy.mdm_sdk/control/control_data/ 2>/dev/null
log "MDM control data cleared"

service call com.toycloud.launcher.model.launcher.appcontrol.ControlAppService 1 s16 "com.iflytek.ebg.aistudy.mdm_sdk.apps.IControlApp" i32 0 2>/dev/null
am broadcast -a com.toycloud.launcher.action.CLEAR_LOCKED_APPS 2>/dev/null
am broadcast -a com.toycloud.launcher.action.UPDATE_LOCKED_APPS --esa locked_apps "" 2>/dev/null
log "TyeLauncher locked apps cleared via AIDL + broadcast"

settings put global zen_mode 0 2>/dev/null
settings put secure zen_mode 0 2>/dev/null
log "zen_mode forced off"

for ipt in iptables ip6tables; do
    for chn in FORWARD INPUT OUTPUT; do
        $ipt -D $chn -p udp --dport 53 -j DROP 2>/dev/null
        $ipt -D $chn -p tcp --dport 853 -j DROP 2>/dev/null
    done
done
log "DNS firewall cleared"

stop ylog 2>/dev/null
stop log_service 2>/dev/null
stop collect_apr 2>/dev/null
stop slogmodem 2>/dev/null
stop modemlog_connmgr_service 2>/dev/null
stop dataLogDaemon 2>/dev/null
stop cmd_services 2>/dev/null
stop performancemanager 2>/dev/null
log "Log/monitor services stopped"

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
    log "pm enable: $pkg"
done

nohup "$MODDIR/daemon.sh" > /dev/null 2>&1 &
log "Daemon launched"
