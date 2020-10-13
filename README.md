# ECDRT
ECN and RTT Combined Congestion Control Scheme for Data Centers.
The RTT signal used in delay based congestion control scheme as a queuing delay increasing indication or signal and on other side the ECN signal which mark packet in queue when the queue reached the threshold as congestion. Due to this congestion indication sender reduce the send rate. I have Combine RTT and ECN Signals which used for congestion Indication. After combining both signals I wrote an Algorithm which name is “ECRT”.

Algorithm:

     •	 The Sender send packet with enabled ECT (ECN Capable Transport) bit. Because for ECN signal both sender and receiver is ECN Capable.

     •	 On switch side the packet marking threshold similar to DCTCP. The receiver set the CE (Congestion Experienced) bit in packet header. 
		 DCTCP marked Packets with this formula:
                                           K > ( RTT * C ) / 7
             Here C is Link rate in packets per second.

     •	 On receiver Side, if the packet marked with CE (Congestion Experienced) bit the receiver set the ECE (Echo Congesiton Experience) bit in packet header.

     •	Now after successfully receiving packet measure RTT of every packet. 

     •	On receiver, if the packet marked ECE bit set then by combination of ECN signal and measured RTT reduce the congestion window according to RTT specific range and ECN value (0,1). 

Algorithm and sudo code explained below.
