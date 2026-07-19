#!/system/bin/sh
MODDIR=${0%/*}

ui_print " "
ui_print "=========================================="
ui_print "  T10 Unlock v3 - Cloud Deception Module"
ui_print "=========================================="
ui_print " "
ui_print "Strategy: Keep iFLYTEK MDM/HwcService running"
ui_print "for server compliance, but disable the"
ui_print "IFlytekService watchdog and counter all"
ui_print "restrictions locally via daemon."
ui_print " "

pm disable com.android.iflytek 2>/dev/null
pm disable com.iflytek.cbg.aistudy.logservice 2>/dev/null

dpm remove-active com.iflytek.ebg.aistudy.mdm/com.iflytek.ebg.aistudy.mdm.screen.ScreenOffAdminReceiver 2>/dev/null

content delete --uri content://com.iflytek.ebg.aistudy.mdm_sdk/business_control/ 2>/dev/null
content delete --uri content://com.iflytek.ebg.aistudy.mdm_sdk/control/control_data/ 2>/dev/null

for ipt in iptables ip6tables; do
    for chn in FORWARD INPUT OUTPUT; do
        $ipt -D $chn -p udp --dport 53 -j DROP 2>/dev/null
        $ipt -D $chn -p tcp --dport 853 -j DROP 2>/dev/null
    done
done

rm -rf /data/ylog/* 2>/dev/null
rm -rf /cache/ylog/* 2>/dev/null

set_perm_recursive $MODDIR 0 0 0755 0644
set_perm $MODDIR/post-fs-data.sh 0 0 0755
set_perm $MODDIR/service.sh 0 0 0755
set_perm $MODDIR/daemon.sh 0 0 0755
