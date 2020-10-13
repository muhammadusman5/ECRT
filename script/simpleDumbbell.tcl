set N 50
set B 85
set K 30
set RTT 0.0001

set simulationTime 1.0

set startMeasurementTime 1
set stopMeasurementTime 2
set flowClassifyTime 0.001

set sourceAlg DC-TCP-Sack
set switchAlg RED
set lineRate 10Gb
set inputLineRate 11Gb

set ackRatio 1 
set packetSize 1460
 
set traceSamplingInterval 0.0001
set throughputSamplingInterval 0.01
set enableNAM 0

set ns [new Simulator]

Agent/TCP set ecn_ 1
Agent/TCP set old_ecn_ 1
Agent/TCP set packetSize_ $packetSize
Agent/TCP/FullTcp set segsize_ $packetSize
Agent/TCP set window_ 1256
Agent/TCP set slow_start_restart_ false
Agent/TCP set tcpTick_ 0.01
Agent/TCP set minrto_ 0.2 ; # minRTO = 200ms
Agent/TCP set windowOption_ 0

# ECRT
Agent/TCP set timestamps_ true;
Agent/TCP set alphaval_ 0.2;
Agent/TCP set betaval_ 0.01;
Agent/TCP set decr_val_ 0.08;       
Agent/TCP set rtt_low_ 0.000160;
Agent/TCP set rtt_medium_ 0.000450;
Agent/TCP set rtt_high_ 0.001050;


if {[string compare $sourceAlg "DC-TCP-Sack"] == 0} {
    Agent/TCP set ECRT_ true
}
Agent/TCP/FullTcp set segsperack_ $ackRatio; 
Agent/TCP/FullTcp set spa_thresh_ 3000;
Agent/TCP/FullTcp set interval_ 0.04 ; #delayed ACK interval = 40ms

Queue set limit_ 1000

Queue/RED set bytes_ false
Queue/RED set queue_in_bytes_ true
Queue/RED set mean_pktsize_ $packetSize
Queue/RED set setbit_ true
Queue/RED set gentle_ false
Queue/RED set q_weight_ 1.0
Queue/RED set mark_p_ 1.0
Queue/RED set thresh_ [expr $K]
Queue/RED set maxthresh_ [expr $K]
			 
DelayLink set avoidReordering_ true

if {$enableNAM != 0} {
    set namfile [open out.nam w]
    $ns namtrace-all $namfile
}

set mytrace [open out.tr w]
$ns trace-all $mytrace

set mytracefile [open mytracefile.tr w]
set throughputfile [open thrfile.tr w]

proc finish {} {
        global ns enableNAM namfile mytracefile throughputfile
        $ns flush-trace
        close $mytracefile
        close $throughputfile
        if {$enableNAM != 0} {
	    close $namfile
	    exec nam out.nam &
	}
        exec xgraph cwndwin.xg -geometry 300*300 &
	exit 0
}

# Usman code (plot congestion window)
set cwndfile [open "cwndwin.xg" w]

proc cwnddraw {cwndfile} {
    global ns N tcp 
    set now [$ns now]

    for {set i 0} {$i < $N} {incr i} {
	set cwnd($i) [$tcp($i) set cwnd_]
    }
    puts $cwndfile "$now $pdrops_"
    for {set i 1} {$i < $N} {incr i} {
	puts $cwndfile "$now $cwnd($i)"
    }
    
    $ns at [expr $now+0.01] "cwnddraw $cwndfile"
}

proc myTrace {file} {
    global ns N traceSamplingInterval tcp qfile MainLink nbow nclient packetSize enableBumpOnWire
    
    set now [$ns now]
    
    for {set i 0} {$i < $N} {incr i} {
	set cwnd($i) [$tcp($i) set cwnd_]
	set dctcp_alpha($i) [$tcp($i) set dctcp_alpha_]
    }
    
    $qfile instvar parrivals_ pdepartures_ pdrops_ bdepartures_
  
    puts -nonewline $file "$now $cwnd(0)"
    for {set i 1} {$i < $N} {incr i} {
	puts -nonewline $file " $cwnd($i)"
    }
    for {set i 0} {$i < $N} {incr i} {
	puts -nonewline $file " $dctcp_alpha($i)"
    }
 
    puts -nonewline $file " [expr $parrivals_-$pdepartures_-$pdrops_]"    
    puts $file "$now $pdrops_"
     
    $ns at [expr $now+$traceSamplingInterval] "myTrace $file"
}

proc throughputTrace {file} {
    global ns throughputSamplingInterval qfile flowstats N flowClassifyTime
    
    set now [$ns now]
    
    $qfile instvar bdepartures_
    
    puts $file "$now [expr $bdepartures_*8/$throughputSamplingInterval/1000000]"
    set bdepartures_ 0
    if {$now <= $flowClassifyTime} {
	for {set i 0} {$i < [expr $N-1]} {incr i} {
	    puts $file " 0"
	}
	puts $file " 0"
    }

    if {$now > $flowClassifyTime} { 
	for {set i 0} {$i < [expr $N-1]} {incr i} {
	    $flowstats($i) instvar barrivals_
	    puts $file " [expr $barrivals_*8/$throughputSamplingInterval/1000000]"
	    set barrivals_ 0
	}
	$flowstats([expr $N-1]) instvar barrivals_
	puts $file " [expr $barrivals_*8/$throughputSamplingInterval/1000000]"
	set barrivals_ 0
    }
    
    $ns at [expr $now+$throughputSamplingInterval] "throughputTrace $file"
}


#$tcpf trace cwnd_

#set tracer [new Tracer/Var]
#$tcpf trace ssthresh_ $tracer

$ns color 0 Red
$ns color 1 Orange
$ns color 2 Yellow
$ns color 3 Green
$ns color 4 Blue
$ns color 5 Violet
$ns color 6 Brown
$ns color 7 Black

for {set i 0} {$i < $N} {incr i} {
    set n($i) [$ns node]
}

set nqueue [$ns node]
set nclient [$ns node]


$nqueue color red
$nqueue shape box
$nclient color blue

for {set i 0} {$i < $N} {incr i} {
    $ns duplex-link $n($i) $nqueue $inputLineRate [expr $RTT/4] DropTail
    $ns duplex-link-op $n($i) $nqueue queuePos 0.25
}


$ns simplex-link $nqueue $nclient $lineRate [expr $RTT/4] $switchAlg
$ns simplex-link $nclient $nqueue $lineRate [expr $RTT/4] DropTail
$ns queue-limit $nqueue $nclient $B

$ns duplex-link-op $nqueue $nclient color "green"
$ns duplex-link-op $nqueue $nclient queuePos 0.25
set qfile [$ns monitor-queue $nqueue $nclient [open queue.tr w] $traceSamplingInterval]


for {set i 0} {$i < $N} {incr i} {
    if {[string compare $sourceAlg "Newreno"] == 0 || [string compare $sourceAlg "DC-TCP-Newreno"] == 0} {
	set tcp($i) [new Agent/TCP/Newreno]
	set sink($i) [new Agent/TCPSink]
    }
    if {[string compare $sourceAlg "Sack"] == 0 || [string compare $sourceAlg "DC-TCP-Sack"] == 0} { 
        set tcp($i) [new Agent/TCP/FullTcp/Sack]
	set sink($i) [new Agent/TCP/FullTcp/Sack]
	$sink($i) listen
    }

    $ns attach-agent $n($i) $tcp($i)
    $ns attach-agent $nclient $sink($i)
    
    $tcp($i) set fid_ [expr $i]
    $sink($i) set fid_ [expr $i]

    $ns connect $tcp($i) $sink($i)       
}

for {set i 0} {$i < $N} {incr i} {
    set ftp($i) [new Application/FTP]
    $ftp($i) attach-agent $tcp($i)    
}

$ns at $traceSamplingInterval "myTrace $mytracefile"
$ns at $throughputSamplingInterval "throughputTrace $throughputfile"

set ru [new RandomVariable/Uniform]
$ru set min_ 0
$ru set max_ 1.0

for {set i 0} {$i < $N} {incr i} {
    $ns at 0.0 "$ftp($i) send 100"
    $ns at [expr 0.1 + $simulationTime * $i / ($N + 0.0001)] "$ftp($i) start"     
    $ns at [expr $simulationTime] "$ftp($i) stop"
}

set flowmon [$ns makeflowmon Fid]
set MainLink [$ns link $nqueue $nclient]

$ns attach-fmon $MainLink $flowmon

set fcl [$flowmon classifier]

$ns at $flowClassifyTime "classifyFlows"

proc classifyFlows {} {
    global N fcl flowstats
    puts "NOW CLASSIFYING FLOWS"
    for {set i 0} {$i < $N} {incr i} {
	set flowstats($i) [$fcl lookup autp 0 0 $i]
    }
} 


set startPacketCount 0
set stopPacketCount 0

proc startMeasurement {} {
global qfile startPacketCount
$qfile instvar pdepartures_   
set startPacketCount $pdepartures_
}
set throughputfile []
proc stopMeasurement {} {
global qfile startPacketCount stopPacketCount packetSize startMeasurementTime stopMeasurementTime simulationTime
$qfile instvar pdepartures_   
set stopPacketCount $pdepartures_
puts "Throughput = [expr ($stopPacketCount-$startPacketCount)/(1024.0*1024*($stopMeasurementTime-$startMeasurementTime))*$packetSize*8] Mbps"
}

$ns at $startMeasurementTime "startMeasurement"
$ns at $stopMeasurementTime "stopMeasurement"
$ns at 0.0 "cwnddraw $cwndfile"
                      
$ns at $simulationTime "finish"

$ns run
