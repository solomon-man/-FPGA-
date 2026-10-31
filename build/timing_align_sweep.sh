#!/bin/sh
cd "G:/ANLU_Project/digital photo frame3.0"
R=TD_project/timing_verified_Runs/phy_1
for s in ${SEEDS:-9 6 12 7 10 13 14 15}; do
  TD_PLACE_SEED=$s E:/TD_Engineer/bin/run.exe build/timing_align_owner_reg.tcl > build/timing_align_seed$s.log 2>&1
  if [ -f $R/final_timing.rpt ]; then
    cp $R/final_timing.rpt build/timing_align_seed$s.rpt
    sw=$(sed -n 's/.*SWNS: \(-\?[0-9.]*\)ns.*/\1/p' $R/final_timing.rpt | head -1)
    hw=$(sed -n 's/.*HWNS: \(-\?[0-9.]*\)ns.*/\1/p' $R/final_timing.rpt | head -1)
    echo "seed $s SWNS $sw HWNS $hw"
    case "$sw$hw" in *-*) ;; *) [ -f $R/timing_verified.bit ] && { echo "PASS seed $s"; exit 0; } ;; esac
  else echo "seed $s route failed"; fi
done
exit 1
