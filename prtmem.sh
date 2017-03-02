#!/usr/bin/ksh
#
# prtmem.sh, v1.6, Written by Antoni Sawicki <tenox@tenox.tc>
#
# Print Memory Usage Summary under Solaris 2.6
# This is essencially shell script version of RMC MemTool "prtmem"
# Note: these values are only aproximate and cannot be completely trusted
# 

#
# Some init stuff we need.
#
set -f
exec 2>/dev/null
PAGESIZE=`pagesize`
PMAP="/usr/proc/bin/pmap"
[ `uname -r` = "5.6" ] || { echo "Sorry, Solaris 2.6 [SunOS 5.6] Only..."; exit 1; }

#
# Let's gather some data - please note these are not completely valid!
#

# Lotsfree (minimum free memory)
set -- `netstat -k| grep lotsfree`
shift
LOTS="$(($9*$PAGESIZE/1024/1024))"

# Approx Total Allocated
set -- `netstat -k | grep pagestotal`
shift
ALLOC="$(($9*$PAGESIZE/1024/1024))"

# Approx Kernel Memory
set -- `netstat -k | grep arena_size`
KERNEL="$(($2/1024/1024))"

# Approx Kernel Allocated Memory
KALLOC="$((`sar -k 1 | tail -1 | nawk '{ print $3+$6+$8 }'`/1024/1024))"

#
# Now let's count the real stuff... App private, shared and SYSV shared.
# This is not completely valid method of calculating, but close enough..
#
eval `for PID in \`ps -eo pid| grep -v PID\`; do $PMAP -x $PID; done | nawk '{
	if($1 !~ /total/ && $1 !~ /:/) {
		if($7 ~ /\[shmid=/) shmem[$7]=$5
		else {
			if($4 > libs[$7$6]) libs[$7$6]=$4
			if($6 ~ /write/ && $4 == "-") priv=priv+$5
		}
	}
} END	{
	for (n in libs) 
		libs_total=libs_total+libs[n]
	for (n in shmem) 
		shmem_total = shmem_total+shmem[n]
	if(!shmem_total)
		shmem_total = 0

	print "LIBS=" int(libs_total/1024)
	print "SHMM=" int(shmem_total/1024) 
	print "PRIV=" int(priv/1024)
}'`

# Let's see what's left... While free memory is allways around 0,
# thus all the rest must be file buffers or cache...
BUFF="$(($ALLOC-$KERNEL-$PRIV-$LIBS-$SHMM-$LOTS))"

# Aproximate, total application private memory
TAPP="$((PRIV+$SHMM))"

# OK, let's prinit out:

echo ""
printf "%-30s %4d MB\n" "Total System Memory:" "$ALLOC"
printf "%-30s %4d MB\n" "Kernel Reserved Memory:" "$KERNEL"
printf "%-30s %4d MB\n" "Kernel Allocated Memory:" "$KALLOC"
printf "%-30s %4d MB\n" "Application Private Memory:"   "$PRIV"
printf "%-30s %4d MB\n" "System V Shared Memory:" "$SHMM"
printf "%-30s %4d MB\n" "Total Private Memory:" "$TAPP"
printf "%-30s %4d MB\n" "Shared Executables and Libs:"  "$LIBS"
printf "%-30s %4d MB\n" "File Buffer Memory:" "$BUFF"
printf "%-30s %4d MB\n" "Minimum Free Memory:" "$LOTS"
echo ""
